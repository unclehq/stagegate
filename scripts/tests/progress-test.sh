#!/usr/bin/env bash
set -euo pipefail

# Fixture tests for scripts/lib/progress.sh. The rendering is a pure function,
# so the arithmetic and truncation are testable with no terminal at all; the
# escape-sequence writers are exercised only for their no-op behaviour, which
# is the property that matters when the driver's output is redirected.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/scripts/lib/progress.sh"

FAILED=0
COUNT=0

fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }

check_eq() {
    local name="$1" expected="$2" actual="$3"
    COUNT=$((COUNT + 1))
    [[ "$actual" == "$expected" ]] || fail "$name — expected '$expected', got '$actual'"
}

pct_of() { progress_bar_line "$1" "$2" 60 "MC" | grep -oE '[0-9]+%' | head -1; }

# --- percentage arithmetic --------------------------------------------------

check_eq "zero of many"      "0%"   "$(pct_of 0 29)"
check_eq "half"             "50%"   "$(pct_of 10 20)"
check_eq "all"             "100%"   "$(pct_of 29 29)"
check_eq "integer floor"    "24%"   "$(pct_of 7 29)"

# A stage can mention an id more than the checklist holds; never exceed 100.
check_eq "over-count clamps to 100" "100%" "$(pct_of 40 29)"

# --- degenerate totals must not divide by zero ------------------------------

COUNT=$((COUNT + 1))
if ! progress_bar_line 0 0 60 "MC" > /dev/null 2>&1; then
    fail "zero total: should render, not error"
fi
check_eq "zero total reads 0%" "0%" "$(pct_of 0 0)"

# --- the line never exceeds the terminal width ------------------------------
# A wrapped status line scrolls the reserved row away and breaks the region.

for width in 20 40 80 120; do
    COUNT=$((COUNT + 1))
    rendered="$(progress_bar_line 13 29 "$width" "checklist")"
    if [[ "${#rendered}" -gt "$width" ]]; then
        fail "width $width: rendered ${#rendered} chars"
    fi
done

# Very narrow terminals drop the bar rather than truncating the numbers away.
COUNT=$((COUNT + 1))
case "$(progress_bar_line 13 29 24 "checklist")" in
    *"(13/29)"*) ;;
    *) fail "narrow width: the counts must survive when the bar cannot" ;;
esac

# --- the bar tracks the percentage ------------------------------------------

filled_of() { progress_bar_line "$1" "$2" 60 "MC" | tr -cd '#' | wc -c | tr -d ' '; }

check_eq "empty bar at 0%" "0" "$(filled_of 0 29)"
COUNT=$((COUNT + 1))
if [[ "$(filled_of 29 29)" -le "$(filled_of 15 29)" ]]; then
    fail "bar must grow with progress"
fi

# --- no terminal means no output, and no failure ----------------------------
# The driver's stdout is piped and redirected; escape codes in a log corrupt it.

COUNT=$((COUNT + 1))
if progress_supported < /dev/null > /dev/null 2>&1; then
    fail "progress_supported must be false when stdout is not a tty"
fi

for fn in progress_begin progress_end "progress_update 1 2 x"; do
    COUNT=$((COUNT + 1))
    out="$($fn 2>&1 < /dev/null)" || fail "$fn errored with no tty"
    [[ -z "$out" ]] || fail "$fn wrote '$out' to stdout with no tty"
done

if [[ "$FAILED" -ne 0 ]]; then
    echo "progress-test.sh: $FAILED of $COUNT checks failed"
    exit 1
fi
echo "progress-test.sh: $COUNT checks passed"
