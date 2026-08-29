#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

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
if command -v gh >/dev/null 2>&1; then
    ISSUE_JSON="$(fetch_with_gh || true)"
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
    echo "Run: ./scripts/change-workflow.sh"
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
    change) write_change_request ;;
    new) write_new_project_brief ;;
esac
