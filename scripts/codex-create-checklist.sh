#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

test -s REQUIREMENTS.md
test -s UPDATED_PROJECT_PLAN.md
test -s AUTOMATED_TEST_REPORT.md
test -s .workflow/approvals/UPDATED_PROJECT_PLAN.sha256

expected="$(cat .workflow/approvals/UPDATED_PROJECT_PLAN.sha256)"
actual="$(shasum -a 256 UPDATED_PROJECT_PLAN.md | awk '{print $1}')"

if [[ "$expected" != "$actual" ]]; then
    echo "UPDATED_PROJECT_PLAN.md changed after approval."
    exit 1
fi

REVIEWER_CMD="${WORKFLOW_REVIEWER_CMD:-codex}"

"$REVIEWER_CMD" exec \
    --ephemeral \
    --sandbox read-only \
    --output-last-message MANUAL_CHECKLIST.md \
    "$(cat <<'PROMPT'
Act as an independent release-verification engineer.

Inspect:

- REQUIREMENTS.md
- PROJECT_PLAN.md
- ADVERSARIAL_REVIEW.md
- UPDATED_PROJECT_PLAN.md
- AUTOMATED_TEST_REPORT.md
- implementation source files
- automated tests
- startup and build scripts

Do not modify source code.
Do not claim any check passed.
Do not merely repeat automated tests.

Create MANUAL_CHECKLIST.md.

The checklist must verify:

1. Every documented user-visible behavior
2. Every system behavior
3. Every invariant that can be observed manually
4. Startup and shutdown
5. Backend and frontend integration
6. Invalid inputs
7. Boundary values
8. Stale and out-of-order events
9. Inventory limits
10. Accounting behavior
11. Error visibility
12. Recovery behavior
13. Restart behavior
14. Requirements not covered by automated tests

Each item must contain:

- check ID;
- priority: Critical, Important, or Optional;
- related behavior IDs;
- related invariant IDs;
- prerequisites;
- exact action;
- expected result;
- evidence to capture;
- actual result placeholder;
- status placeholder: NOT RUN.

Separate the checklist into:

- Smoke checks
- Behavior checks
- Invariant checks
- Failure-path checks
- Full-stack checks
- Regression checks
- Optional checks

End with a requirements-to-check traceability table.
PROMPT
)"

test -s MANUAL_CHECKLIST.md
echo "Created MANUAL_CHECKLIST.md"
