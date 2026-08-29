#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ---------------------------------------------------------------------------
# Change-workflow chaining
#
# These functions run after CHANGE_REQUEST.md is seeded on the --change path:
# they confirm with the human, run the driver, and close the originating issue
# only when that run's own audit says the change is ready. They read the
# globals resolved further down (OWNER, REPO, ISSUE_NUM, USED_GH) at call time.
# ---------------------------------------------------------------------------

STATE_DIR=".workflow"
STATE_FILE="$STATE_DIR/state"
ORIGIN_FILE="$STATE_DIR/origin"
VERDICT_FILE="$STATE_DIR/audit-verdict"
CONFIRM_WORD="RUN"

workflow_state() {
    if [[ -s "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    fi
}

origin_line() {
    if [[ -s "$ORIGIN_FILE" ]]; then
        cat "$ORIGIN_FILE"
    fi
}

this_origin() {
    printf '%s\t%s' "$OWNER/$REPO" "$ISSUE_NUM"
}

# True when this checkout holds a change run that has started and not finished.
run_in_flight() {
    local state
    state="$(workflow_state)"
    [[ -n "$state" && "$state" != "COMPLETE" ]]
}

# An in-flight run this issue cannot prove it owns must not be seeded over,
# resumed, or closed against.
check_origin_or_refuse() {
    local owner
    if ! run_in_flight; then
        return 0
    fi

    owner="$(origin_line)"
    if [[ "$owner" == "$(this_origin)" ]]; then
        return 0
    fi

    echo "Refusing to seed $OWNER/$REPO#$ISSUE_NUM: this checkout has an in-flight"
    echo "change workflow (state: $(workflow_state)) that does not belong to it."
    if [[ -n "$owner" ]]; then
        echo "  $ORIGIN_FILE owner: $owner"
    else
        echo "  $ORIGIN_FILE: absent — the in-flight state has no provable owner"
    fi
    echo "Finish or reset that run before seeding a different issue."
    exit 1
}

# True when the CHANGE_REQUEST.md on disk already belongs to this issue's
# in-flight run, in which case rewriting it would discard hand edits.
seed_is_current() {
    run_in_flight && [[ "$(origin_line)" == "$(this_origin)" ]]
}

confirm_and_run_workflow() {
    local run_id status response

    run_id="$$-$(date +%Y%m%d%H%M%S)"

    echo
    echo "=================================================="
    echo "CHANGE REQUEST READY TO RUN"
    echo "  CHANGE_REQUEST.md  (from $OWNER/$REPO#$ISSUE_NUM)"
    echo "=================================================="
    echo
    echo "Review and edit it now if it needs more than the issue text:"
    echo "  less CHANGE_REQUEST.md"
    echo "  code CHANGE_REQUEST.md"
    echo
    echo "Confirming starts ./scripts/change-workflow.sh here. That runs the"
    echo "multi-stage agent pipeline, spends real budget, and — only on a READY"
    echo "final audit — closes $OWNER/$REPO#$ISSUE_NUM."
    echo "Commit or stash unrelated work first: the driver records git diff of the"
    echo "whole working tree as the change record."
    echo

    # Printed rather than passed to `read -p`: bash suppresses a -p prompt when
    # stdin is not a terminal, and a non-interactive caller must still see what
    # it is blocking on (CHANGE_SPEC §8).
    response=""
    printf '%s' "Type $CONFIRM_WORD exactly to start the change workflow: "
    read -r response || true
    echo

    if [[ "$response" != "$CONFIRM_WORD" ]]; then
        echo "Not confirmed. CHANGE_REQUEST.md is written; nothing else ran."
        echo "Run: ./scripts/change-workflow.sh"
        return 0
    fi

    mkdir -p "$STATE_DIR"
    printf '%s\t%s\n' "$OWNER/$REPO" "$ISSUE_NUM" > "$ORIGIN_FILE"

    status=0
    STAGEGATE_RUN_ID="$run_id" \
    STAGEGATE_ORIGIN_REPO="$OWNER/$REPO" \
    STAGEGATE_ORIGIN_ISSUE="$ISSUE_NUM" \
        "$ROOT/scripts/change-workflow.sh" || status=$?

    if [[ "$status" -ne 0 ]]; then
        echo
        echo "change-workflow.sh exited $status; $OWNER/$REPO#$ISSUE_NUM was not closed."
        exit "$status"
    fi

    close_issue_if_ready "$run_id"
}

# Closes the issue only when this run's own audit verdict, the origin binding,
# and the hash of the audited FINAL_AUDIT.md all agree. Any mismatch leaves the
# issue open with an explanation; none of them is a hard failure.
close_issue_if_ready() {
    local run_id="$1"
    local record file_run_id verdict recorded_hash actual_hash comment

    if [[ ! -s "$VERDICT_FILE" ]]; then
        echo "No audit verdict was recorded ($VERDICT_FILE is absent);"
        echo "leaving $OWNER/$REPO#$ISSUE_NUM open."
        return 0
    fi

    record="$(head -n 1 "$VERDICT_FILE")"
    file_run_id="$(printf '%s' "$record" | awk -F'\t' '{print $1}')"
    verdict="$(printf '%s' "$record" | awk -F'\t' '{print $2}')"
    recorded_hash="$(printf '%s' "$record" | awk -F'\t' '{print $3}')"

    if [[ -z "$file_run_id" || -z "$verdict" || -z "$recorded_hash" ]]; then
        echo "Audit verdict record is malformed; leaving $OWNER/$REPO#$ISSUE_NUM open."
        return 0
    fi

    if [[ "$file_run_id" != "$run_id" ]]; then
        echo "Audit verdict belongs to run '$file_run_id', not this run ('$run_id');"
        echo "leaving $OWNER/$REPO#$ISSUE_NUM open."
        return 0
    fi

    if [[ "$(origin_line)" != "$(this_origin)" ]]; then
        echo "Origin binding no longer names $OWNER/$REPO#$ISSUE_NUM;"
        echo "leaving the issue open."
        return 0
    fi

    if [[ ! -s FINAL_AUDIT.md ]]; then
        echo "FINAL_AUDIT.md is missing; leaving $OWNER/$REPO#$ISSUE_NUM open."
        return 0
    fi

    actual_hash="$(shasum -a 256 FINAL_AUDIT.md | awk '{print $1}')"
    if [[ "$actual_hash" != "$recorded_hash" ]]; then
        echo "FINAL_AUDIT.md changed after it was classified;"
        echo "leaving $OWNER/$REPO#$ISSUE_NUM open."
        return 0
    fi

    case "$verdict" in
        READY|READY_WITH_NON_BLOCKING_ISSUES) ;;
        *)
            echo "Final audit verdict: $verdict — leaving $OWNER/$REPO#$ISSUE_NUM open."
            return 0
            ;;
    esac

    if [[ "${USED_GH:-0}" != "1" ]]; then
        echo "Issue was fetched over the unauthenticated curl fallback, which cannot"
        echo "close issues. Close $OWNER/$REPO#$ISSUE_NUM by hand (verdict: $verdict)."
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        echo "gh is no longer on PATH; skipping the close."
        echo "Close $OWNER/$REPO#$ISSUE_NUM by hand (verdict: $verdict)."
        return 0
    fi

    if ! gh auth status >/dev/null 2>&1; then
        echo "gh is not authenticated; skipping the close."
        echo "Close $OWNER/$REPO#$ISSUE_NUM by hand (verdict: $verdict)."
        return 0
    fi

    comment="Closed by stagegate: change workflow completed with FINAL_AUDIT.md verdict \`$verdict\`. See FINAL_AUDIT.md and .workflow/change.diff in the working tree."

    if ! gh issue close "$ISSUE_NUM" --repo "$OWNER/$REPO" --comment "$comment"; then
        echo "gh issue close failed for $OWNER/$REPO#$ISSUE_NUM."
        echo "The change workflow itself completed; only the close failed."
        exit 1
    fi

    echo "Closed $OWNER/$REPO#$ISSUE_NUM (verdict: $verdict)."
}

# Test hook: sourcing this script with STAGEGATE_FROM_ISSUE_SOURCE_ONLY=1 yields
# the functions above without running the CLI, so scripts/tests/close-flow-test.sh
# can drive them hermetically. Not a command-line flag; the documented argument
# contract is unchanged.
if [[ "${STAGEGATE_FROM_ISSUE_SOURCE_ONLY:-0}" == "1" ]]; then
    return 0 2>/dev/null || exit 0
fi

usage() {
    cat <<'EOF'
Usage: from-issue.sh <issue-number | github-url> [--change | --new]

Fetch a GitHub issue and seed a workflow from it.

  --change   Write CHANGE_REQUEST.md for ./scripts/change-workflow.sh (default
             if CHANGE_REQUEST.md already exists or the repo is not empty).
  --new      Replace the project-brief section of REQUIREMENTS.md for
             ./scripts/stagegate.sh.

The issue can be:
  - a number like 123 (repo read from the current git remote)
  - a full URL like https://github.com/owner/repo/issues/123

Requires either the gh CLI (authenticated) or curl (public repos only).
EOF
}

if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
    exit 0
fi

ISSUE_ARG="$1"
MODE=""
shift || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --change) MODE="change" ;;
        --new) MODE="new" ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Resolve owner/repo and issue number.
# ---------------------------------------------------------------------------

OWNER=""
REPO=""
ISSUE_NUM=""

if [[ "$ISSUE_ARG" =~ ^https?://github\.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    ISSUE_NUM="${BASH_REMATCH[3]}"
elif [[ "$ISSUE_ARG" =~ ^([0-9]+)$ ]]; then
    ISSUE_NUM="${BASH_REMATCH[1]}"
    REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
    if [[ -z "$REMOTE_URL" ]]; then
        echo "No git remote found. Provide a full GitHub URL."
        exit 1
    fi
    # Handle both https and ssh remotes. Strip any trailing slash and the
    # optional .git suffix first: bash uses POSIX ERE, which has no lazy
    # quantifier, so "([^/]+?)(\.git)?$" fails to compile on bash 3.2.
    REMOTE_URL="${REMOTE_URL%/}"
    REMOTE_URL="${REMOTE_URL%.git}"
    if [[ "$REMOTE_URL" =~ github\.com[:/]+([^/]+)/([^/]+)$ ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
    else
        echo "Could not parse GitHub owner/repo from remote: $REMOTE_URL"
        exit 1
    fi
else
    echo "Unrecognized issue argument: $ISSUE_ARG"
    usage
    exit 1
fi

# ---------------------------------------------------------------------------
# Fetch issue metadata.
# ---------------------------------------------------------------------------

fetch_with_gh() {
    gh issue view "$ISSUE_NUM" --repo "$OWNER/$REPO" --json title,body,url,state,labels 2>/dev/null
}

fetch_with_curl() {
    local url="https://api.github.com/repos/$OWNER/$REPO/issues/$ISSUE_NUM"
    curl -fsSL "$url" 2>/dev/null
}

ISSUE_JSON=""
# Only an authenticated gh fetch proves gh can also close the issue later; the
# curl fallback is read-only and public-repo-only.
USED_GH=0
if command -v gh >/dev/null 2>&1; then
    ISSUE_JSON="$(fetch_with_gh || true)"
    if [[ -n "$ISSUE_JSON" ]]; then
        USED_GH=1
    fi
fi
if [[ -z "$ISSUE_JSON" ]] && command -v curl >/dev/null 2>&1; then
    ISSUE_JSON="$(fetch_with_curl || true)"
fi
if [[ -z "$ISSUE_JSON" ]]; then
    echo "Failed to fetch issue $OWNER/$REPO#$ISSUE_NUM."
    echo "Install gh and authenticate, or ensure curl is available for public repos."
    exit 1
fi

# Minimal extraction using Python because jq is optional and bash JSON parsing is brittle.
if command -v python3 >/dev/null 2>&1; then
    TITLE="$(printf '%s' "$ISSUE_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("title",""))')"
    BODY="$(printf '%s' "$ISSUE_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("body",""))')"
    URL="$(printf '%s' "$ISSUE_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("html_url") or d.get("url") or sys.argv[1])' "https://github.com/$OWNER/$REPO/issues/$ISSUE_NUM")"
elif command -v jq >/dev/null 2>&1; then
    TITLE="$(printf '%s' "$ISSUE_JSON" | jq -r '.title // empty')"
    BODY="$(printf '%s' "$ISSUE_JSON" | jq -r '.body // empty')"
    URL="$(printf '%s' "$ISSUE_JSON" | jq -r '.html_url // .url // empty')"
    [[ -n "$URL" ]] || URL="https://github.com/$OWNER/$REPO/issues/$ISSUE_NUM"
else
    echo "Need python3 or jq to parse the GitHub response."
    exit 1
fi

if [[ -z "$TITLE" ]]; then
    echo "Issue title was empty; response may have been rate-limited or unauthorized."
    exit 1
fi

# ---------------------------------------------------------------------------
# Decide mode if not supplied.
# ---------------------------------------------------------------------------

if [[ -z "$MODE" ]]; then
    # If CHANGE_REQUEST.md already exists, assume the user is continuing a
    # change workflow. Otherwise, if the repo contains files beyond the workflow
    # scaffolding, default to change; if it looks like a fresh template, default
    # to new.
    if [[ -s CHANGE_REQUEST.md ]]; then
        MODE="change"
    elif git ls-files 2>/dev/null | grep -q -v \
            -e '^README\.md$' \
            -e '^REQUIREMENTS\.md$' \
            -e '^CLAUDE\.md$' \
            -e '^CHANGE_REQUEST\.md$' \
            -e '^scripts/' \
            -e '^prompts/' \
            -e '^\.claude/' \
            -e '^\.github/' \
            -e '^\.gitignore$'; then
        MODE="change"
    else
        MODE="new"
    fi
fi

# ---------------------------------------------------------------------------
# Write the seed document.
# ---------------------------------------------------------------------------

write_change_request() {
    cat > CHANGE_REQUEST.md <<EOF
# Change Request

Seeded from [$OWNER/$REPO#$ISSUE_NUM]($URL).

## Change Type

Feature | Bug Fix | Prototype | Refactor | Performance | Security | Upgrade

## Summary

$TITLE

## Motivation

$BODY

## Observed Current Behavior

Describe what the system currently does.

## Desired Behavior

Describe what the system should do after the change.

## Reproduction

For a bug, provide exact steps to reproduce it.

For other change types, write "Not applicable."

## Constraints

List compatibility, security, performance, timing, or scope constraints.

## Known Relevant Files

List files or components if known.

## Out of Scope

List behavior or components that must not be changed.

## Success Criteria

Describe the observable evidence that proves the change works.
EOF
    echo "Wrote CHANGE_REQUEST.md"
}

write_new_project_brief() {
    local brief
    brief="$(cat <<EOF
# Project brief

> Seeded from [$OWNER/$REPO#$ISSUE_NUM]($URL).
> Replace the placeholder guidance below with specifics before running the driver.

## Summary

$TITLE

## Problem

$BODY

## Scope

What this project covers. Keep it to what must ship.

## Non-goals

What this project explicitly does not do.

## Functional requirements

| ID | Requirement | Priority |
|---|---|---|
| R-001 | | Must |
| R-002 | | Should |
| R-003 | | Could |

## User-visible behavior

| ID | Trigger | Expected result | On failure |
|---|---|---|---|
| B-001 | | | |

## Domain rules and invariants

| ID | Invariant | Consequence if violated |
|---|---|---|
| I-001 | | |

## Data and state

What the authoritative state is, where it lives, what may hold a cached copy,
and what survives a restart.

## Interfaces

APIs, CLI surface, UI entry points, message formats, external services.

## Constraints

Language, runtime, frameworks, libraries, deployment target, budgets,
compatibility that must not break.

## Failure behavior

What must happen on invalid input, unavailable dependencies, partial writes,
concurrent access, and restart mid-operation.

## Verification

How correctness will be demonstrated: test frameworks, commands, and anything
only checkable by hand.

## Definition of done

The concrete conditions under which this is finished.

## Open questions

Anything genuinely undecided.
EOF
)"

    # Replace the project-brief section (from '# Project brief' to EOF) in REQUIREMENTS.md.
    if ! grep -q '^# Project brief$' REQUIREMENTS.md; then
        echo "REQUIREMENTS.md does not contain a '# Project brief' section; cannot seed new-app workflow."
        exit 1
    fi
    local head
    head="$(awk '/^# Project brief$/{exit} {print}' REQUIREMENTS.md)"
    printf '%s\n%s\n' "$head" "$brief" > REQUIREMENTS.md
    echo "Updated REQUIREMENTS.md project brief from issue $OWNER/$REPO#$ISSUE_NUM"
    echo "Run: ./scripts/stagegate.sh"
}

case "$MODE" in
    change)
        check_origin_or_refuse
        if seed_is_current; then
            echo "Resuming the existing run for $OWNER/$REPO#$ISSUE_NUM; CHANGE_REQUEST.md left as it is."
        else
            write_change_request
        fi
        confirm_and_run_workflow
        ;;
    new) write_new_project_brief ;;
esac
