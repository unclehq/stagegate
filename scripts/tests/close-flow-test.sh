#!/usr/bin/env bash
set -uo pipefail

# Hermetic coverage of the close decision in from-issue.sh and of the lock and
# origin preflight in change-workflow.sh. No network, no real gh, no agent
# calls: every case runs against a scratch copy of the scripts with a stubbed
# gh and a stubbed driver on PATH.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
COUNT=0
CASE_NAME=""
CASE=""
REPO=""
OUT=""
GH_LOG=""
RC=0

fail() {
    echo "FAIL [$CASE_NAME] $1"
    FAILED=$((FAILED + 1))
}

expect_status() {
    COUNT=$((COUNT + 1))
    if [[ "$RC" != "$1" ]]; then
        fail "expected exit $1, got $RC"
        sed 's/^/    /' < "$OUT"
    fi
}

expect_out() {
    COUNT=$((COUNT + 1))
    if ! grep -qF "$1" "$OUT"; then
        fail "expected output to contain: $1"
        sed 's/^/    /' < "$OUT"
    fi
}

expect_not_out() {
    COUNT=$((COUNT + 1))
    if grep -qF "$1" "$OUT"; then
        fail "expected output NOT to contain: $1"
    fi
}

expect_closed() {
    COUNT=$((COUNT + 1))
    if ! grep -qF "issue close" "$GH_LOG"; then
        fail "expected a gh issue close call"
    fi
}

expect_not_closed() {
    COUNT=$((COUNT + 1))
    if grep -qF "issue close" "$GH_LOG"; then
        fail "expected no gh issue close call, got: $(cat "$GH_LOG")"
    fi
}

expect_driver_ran() {
    COUNT=$((COUNT + 1))
    if [[ ! -s "$REPO/.workflow/driver.log" ]]; then
        fail "expected the driver to have run"
    fi
}

expect_driver_not_run() {
    COUNT=$((COUNT + 1))
    if [[ -s "$REPO/.workflow/driver.log" ]]; then
        fail "expected the driver NOT to have run"
    fi
}

# ---------------------------------------------------------------------------
# Scratch fixture
# ---------------------------------------------------------------------------

new_case() {
    CASE_NAME="$1"
    CASE="$TMP/$1"
    REPO="$CASE/repo"
    OUT="$CASE/out.txt"
    GH_LOG="$CASE/gh.log"

    mkdir -p "$REPO/scripts/lib" "$REPO/.workflow" "$CASE/bin" "$CASE/emptybin"
    cp "$ROOT/scripts/from-issue.sh" "$REPO/scripts/from-issue.sh"
    cp "$ROOT/scripts/lib/audit-verdict.sh" "$REPO/scripts/lib/audit-verdict.sh"
    : > "$GH_LOG"
    : > "$OUT"

    cat > "$CASE/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG_FILE"
if [[ "${1:-}" == "auth" ]]; then
    exit "${FAKE_GH_AUTH_RC:-0}"
fi
if [[ "${1:-}" == "issue" && "${2:-}" == "close" ]]; then
    if [[ "${FAKE_GH_CLOSE_RC:-0}" == "0" ]]; then
        echo "stub: closed"
        exit 0
    fi
    echo "stub: close failed" >&2
    exit "${FAKE_GH_CLOSE_RC}"
fi
exit 0
GH
    chmod +x "$CASE/bin/gh"

    cat > "$REPO/scripts/change-workflow.sh" <<'DRV'
#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p .workflow
echo "ran" >> .workflow/driver.log
if [[ -n "${FAKE_DRIVER_ORIGIN:-}" ]]; then
    printf '%s\n' "$FAKE_DRIVER_ORIGIN" > .workflow/origin
fi
if [[ -n "${FAKE_DRIVER_VERDICT_TEXT:-}" ]]; then
    printf '%s\n' "$FAKE_DRIVER_VERDICT_TEXT" > FINAL_AUDIT.md
    . "$ROOT/scripts/lib/audit-verdict.sh"
    class="$(classify_audit_verdict FINAL_AUDIT.md)"
    hash="$(shasum -a 256 FINAL_AUDIT.md | awk '{print $1}')"
    printf '%s\t%s\t%s\n' \
        "${FAKE_DRIVER_RUN_ID:-${STAGEGATE_RUN_ID:--}}" "$class" "$hash" \
        > .workflow/audit-verdict
fi
if [[ "${FAKE_DRIVER_TAMPER:-0}" == "1" ]]; then
    printf 'tampered\n' >> FINAL_AUDIT.md
fi
exit "${FAKE_DRIVER_EXIT:-0}"
DRV
    chmod +x "$REPO/scripts/change-workflow.sh"

    cat > "$REPO/runner.sh" <<'RUN'
#!/usr/bin/env bash
set -uo pipefail
export STAGEGATE_FROM_ISSUE_SOURCE_ONLY=1
. "$(dirname "$0")/scripts/from-issue.sh"
OWNER="${T_OWNER:-owner}"
REPO="${T_REPO:-repo}"
ISSUE_NUM="${T_ISSUE:-42}"
USED_GH="${T_USED_GH:-1}"
case "$1" in
    confirm) confirm_and_run_workflow ;;
    seed_gate)
        check_origin_or_refuse
        if seed_is_current; then echo "SEED_SKIPPED"; else echo "SEED_WRITE"; fi
        ;;
    *) echo "unknown runner action: $1"; exit 2 ;;
esac
RUN
    chmod +x "$REPO/runner.sh"
}

# run_confirm <stdin text> [VAR=VAL ...]
run_runner() {
    local action="$1" input="$2"
    shift 2
    printf '%b' "$input" | env \
        PATH="$CASE/bin:$PATH" \
        GH_LOG_FILE="$GH_LOG" \
        "$@" \
        bash "$REPO/runner.sh" "$action" > "$OUT" 2>&1
    RC=$?
}

# run_driver [VAR=VAL ...] — runs the real change-workflow.sh in the scratch repo
run_driver() {
    cp "$ROOT/scripts/change-workflow.sh" "$REPO/scripts/change-workflow.sh"
    env PATH="$CASE/bin:$PATH" "$@" bash "$REPO/scripts/change-workflow.sh" > "$OUT" 2>&1
    RC=$?
}

# ---------------------------------------------------------------------------
# Confirmation gate (B-01, B-02, B-03; §1.5 no TTY precondition)
# ---------------------------------------------------------------------------

new_case decline-wrong-word
run_runner confirm "nope\n"
expect_status 0
expect_out "Type RUN exactly to start the change workflow:"
expect_out "Not confirmed."
expect_out "Run: ./scripts/change-workflow.sh"
expect_driver_not_run
expect_not_closed

new_case decline-empty-enter
run_runner confirm "\n"
expect_status 0
expect_out "Not confirmed."
expect_driver_not_run

new_case decline-eof
run_runner confirm ""
expect_status 0
expect_out "Not confirmed."
expect_driver_not_run

# The prompt is reached over a pipe, with no TTY anywhere: the approved
# compatibility break (CHANGE_SPEC §8) rather than an early decline.
new_case piped-stdin-proceeds
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="READY"
expect_status 0
expect_out "Type RUN exactly to start the change workflow:"
expect_driver_ran
expect_closed

# ---------------------------------------------------------------------------
# Verdict-gated close (B-04, B-05, I-08)
# ---------------------------------------------------------------------------

new_case ready-closes
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="READY"
expect_status 0
expect_out "Closed owner/repo#42 (verdict: READY)."
expect_closed

new_case ready-with-non-blocking-closes
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="READY WITH NON-BLOCKING ISSUES"
expect_status 0
expect_out "verdict: READY_WITH_NON_BLOCKING_ISSUES"
expect_closed

new_case not-ready-stays-open
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="NOT READY"
expect_status 0
expect_out "Final audit verdict: NOT_READY — leaving owner/repo#42 open."
expect_not_closed

new_case unknown-verdict-stays-open
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="Rerun until READY"
expect_status 0
expect_out "Final audit verdict: UNKNOWN"
expect_not_closed

new_case missing-verdict-file
run_runner confirm "RUN\n"
expect_status 0
expect_out "No audit verdict was recorded"
expect_not_closed

new_case malformed-verdict-file
printf 'garbage\n' > "$REPO/.workflow/audit-verdict"
run_runner confirm "RUN\n"
expect_status 0
expect_out "malformed"
expect_not_closed

new_case run-id-mismatch
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="READY" FAKE_DRIVER_RUN_ID="some-other-run"
expect_status 0
expect_out "Audit verdict belongs to run 'some-other-run'"
expect_not_closed

new_case origin-mismatch-at-close
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="READY" \
    FAKE_DRIVER_ORIGIN="other/repo	99"
expect_status 0
expect_out "Origin binding no longer names owner/repo#42"
expect_not_closed

new_case audit-hash-mismatch
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="READY" FAKE_DRIVER_TAMPER=1
expect_status 0
expect_out "FINAL_AUDIT.md changed after it was classified"
expect_not_closed

# ---------------------------------------------------------------------------
# Driver exit status (AR-008, B-06)
# ---------------------------------------------------------------------------

for rc in 1 7 130; do
    new_case "driver-exit-$rc"
    run_runner confirm "RUN\n" FAKE_DRIVER_EXIT="$rc" FAKE_DRIVER_VERDICT_TEXT="READY"
    expect_status "$rc"
    expect_out "change-workflow.sh exited $rc; owner/repo#42 was not closed."
    expect_not_closed
done

# ---------------------------------------------------------------------------
# gh availability and auth (B-07, I-09, §9)
# ---------------------------------------------------------------------------

new_case curl-fallback-skips-close
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="READY" T_USED_GH=0
expect_status 0
expect_out "unauthenticated curl fallback"
expect_not_closed

new_case gh-unauthenticated-skips-close
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="READY" FAKE_GH_AUTH_RC=1
expect_status 0
expect_out "gh is not authenticated; skipping the close."
expect_not_closed

new_case gh-missing-skips-close
if PATH="$CASE/emptybin:/usr/bin:/bin" command -v gh >/dev/null 2>&1; then
    echo "NOTE [$CASE_NAME] skipped: gh is present in /usr/bin or /bin"
else
    printf 'RUN\n' | env PATH="$CASE/emptybin:/usr/bin:/bin" \
        GH_LOG_FILE="$GH_LOG" FAKE_DRIVER_VERDICT_TEXT="READY" \
        bash "$REPO/runner.sh" confirm > "$OUT" 2>&1
    RC=$?
    expect_status 0
    expect_out "gh is no longer on PATH; skipping the close."
    expect_not_closed
fi

new_case gh-close-fails
run_runner confirm "RUN\n" FAKE_DRIVER_VERDICT_TEXT="READY" FAKE_GH_CLOSE_RC=1
expect_status 1
expect_out "gh issue close failed for owner/repo#42."
expect_out "only the close failed"
expect_closed

# ---------------------------------------------------------------------------
# Seed gate in from-issue.sh (AR-001, AR-004)
# ---------------------------------------------------------------------------

new_case seed-gate-foreign-origin
printf 'IMPLEMENT\n' > "$REPO/.workflow/state"
printf 'other/repo\t99\n' > "$REPO/.workflow/origin"
run_runner seed_gate ""
expect_status 1
expect_out "Refusing to seed owner/repo#42"
expect_out "other/repo"

new_case seed-gate-unowned-state
printf 'IMPLEMENT\n' > "$REPO/.workflow/state"
run_runner seed_gate ""
expect_status 1
expect_out "absent — the in-flight state has no provable owner"

new_case seed-gate-same-origin-resumes
printf 'IMPLEMENT\n' > "$REPO/.workflow/state"
printf 'owner/repo\t42\n' > "$REPO/.workflow/origin"
run_runner seed_gate ""
expect_status 0
expect_out "SEED_SKIPPED"

new_case seed-gate-complete-state-reseeds
printf 'COMPLETE\n' > "$REPO/.workflow/state"
printf 'owner/repo\t42\n' > "$REPO/.workflow/origin"
run_runner seed_gate ""
expect_status 0
expect_out "SEED_WRITE"

new_case seed-gate-fresh-checkout
run_runner seed_gate ""
expect_status 0
expect_out "SEED_WRITE"

# ---------------------------------------------------------------------------
# Driver lock and origin preflight (AR-003, AR-001)
# ---------------------------------------------------------------------------

new_case lock-held-by-live-pid
mkdir -p "$REPO/.workflow/lock"
printf '%s\n' "$$" > "$REPO/.workflow/lock/pid"
printf 'COMPLETE\n' > "$REPO/.workflow/state"
run_driver
expect_status 1
expect_out "another change-workflow.sh run (pid $$) holds this checkout"
COUNT=$((COUNT + 1))
if [[ ! -f "$REPO/.workflow/lock/pid" ]]; then
    fail "the live holder's lock must not be removed"
fi

new_case lock-stale-pid-cleared
DEAD_PID=""
( exit 0 ) &
DEAD_PID=$!
wait "$DEAD_PID" 2>/dev/null
mkdir -p "$REPO/.workflow/lock"
printf '%s\n' "$DEAD_PID" > "$REPO/.workflow/lock/pid"
printf 'COMPLETE\n' > "$REPO/.workflow/state"
run_driver
expect_status 0
expect_out "Clearing stale lock"
expect_out "Change workflow complete."
COUNT=$((COUNT + 1))
if [[ -d "$REPO/.workflow/lock" ]]; then
    fail "lock must be released on exit"
fi

new_case preflight-origin-mismatch
printf 'IMPLEMENT\n' > "$REPO/.workflow/state"
printf 'other/repo\t99\n' > "$REPO/.workflow/origin"
run_driver STAGEGATE_ORIGIN_REPO=owner/repo STAGEGATE_ORIGIN_ISSUE=42
expect_status 1
expect_out "Refusing to resume: this checkout is mid-run"
COUNT=$((COUNT + 1))
if [[ "$(cat "$REPO/.workflow/state")" != "IMPLEMENT" ]]; then
    fail "a refused preflight must not touch the state file"
fi

new_case preflight-origin-absent
printf 'IMPLEMENT\n' > "$REPO/.workflow/state"
run_driver STAGEGATE_ORIGIN_REPO=owner/repo STAGEGATE_ORIGIN_ISSUE=42
expect_status 1
expect_out "cannot be proven to belong to owner/repo#42"

new_case preflight-standalone-unaffected
printf 'IMPLEMENT\n' > "$REPO/.workflow/state"
printf 'other/repo\t99\n' > "$REPO/.workflow/origin"
run_driver WORKFLOW_TRACK=bogus
# No STAGEGATE_ORIGIN_*: the preflight is skipped entirely, so the run fails on
# its own unrelated validation instead of refusing.
expect_status 1
expect_not_out "Refusing to resume"

new_case preflight-complete-state-passes
printf 'COMPLETE\n' > "$REPO/.workflow/state"
printf 'other/repo\t99\n' > "$REPO/.workflow/origin"
run_driver STAGEGATE_ORIGIN_REPO=owner/repo STAGEGATE_ORIGIN_ISSUE=42
expect_status 0
expect_out "Change workflow complete."

# ---------------------------------------------------------------------------
# FINAL_AUDIT freshness and verdict record (AR-002)
# ---------------------------------------------------------------------------

# A reviewer invocation that exits 0 without writing must not leave a stale
# audit readable as this run's verdict.
new_case stale-audit-rejected
mkdir -p "$REPO/prompts/change"
cp "$ROOT/prompts/change/final-audit.md" "$REPO/prompts/change/final-audit.md"
printf 'READY\n' > "$REPO/FINAL_AUDIT.md"
printf 'FINAL_AUDIT\n' > "$REPO/.workflow/state"
run_driver WORKFLOW_REVIEWER_CMD=/usr/bin/true STAGEGATE_RUN_ID=run-1
expect_status 1
expect_out "Required file missing or empty: FINAL_AUDIT.md"
COUNT=$((COUNT + 1))
if [[ -e "$REPO/.workflow/audit-verdict" ]]; then
    fail "no verdict may be recorded when the audit was not produced"
fi
COUNT=$((COUNT + 1))
if [[ "$(cat "$REPO/.workflow/state")" != "FINAL_AUDIT" ]]; then
    fail "state must not advance past a failed audit"
fi

new_case verdict-record-written
mkdir -p "$REPO/prompts/change" "$CASE/bin"
cp "$ROOT/prompts/change/final-audit.md" "$REPO/prompts/change/final-audit.md"
cat > "$CASE/bin/fake-reviewer" <<'REV'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--output-last-message" ]]; then out="$2"; shift; fi
    shift
done
printf 'Audit body.\n\nREADY\n' > "$out"
REV
chmod +x "$CASE/bin/fake-reviewer"
printf 'FINAL_AUDIT\n' > "$REPO/.workflow/state"
run_driver WORKFLOW_REVIEWER_CMD="$CASE/bin/fake-reviewer" STAGEGATE_RUN_ID=run-1
expect_status 0
expect_out "Audit verdict: READY"
COUNT=$((COUNT + 1))
expected_record="$(printf 'run-1\tREADY\t%s' "$(shasum -a 256 "$REPO/FINAL_AUDIT.md" | awk '{print $1}')")"
if [[ "$(cat "$REPO/.workflow/audit-verdict")" != "$expected_record" ]]; then
    fail "verdict record mismatch: $(cat "$REPO/.workflow/audit-verdict")"
fi

if [[ "$FAILED" -ne 0 ]]; then
    echo "close-flow-test.sh: $FAILED of $COUNT checks failed"
    exit 1
fi

echo "close-flow-test.sh: $COUNT checks passed"
