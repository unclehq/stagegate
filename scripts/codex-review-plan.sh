#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

test -s REQUIREMENTS.md
test -s PROJECT_PLAN.md
test -s .workflow/approvals/PROJECT_PLAN.sha256

expected="$(cat .workflow/approvals/PROJECT_PLAN.sha256)"
actual="$(shasum -a 256 PROJECT_PLAN.md | awk '{print $1}')"

if [[ "$expected" != "$actual" ]]; then
    echo "PROJECT_PLAN.md changed after approval."
    echo "Review and approve it again before continuing."
    exit 1
fi

REVIEWER_CMD="${WORKFLOW_REVIEWER_CMD:-codex}"

"$REVIEWER_CMD" exec \
    --ephemeral \
    --sandbox read-only \
    --output-last-message ADVERSARIAL_REVIEW.md \
    "$(cat <<'PROMPT'
Act as an independent adversarial principal engineer.

Read REQUIREMENTS.md and PROJECT_PLAN.md.

Do not implement the project.
Do not modify PROJECT_PLAN.md.
Do not assume that compilation proves correctness.

Create an adversarial review covering:

1. Requirements that are omitted, misunderstood, or ambiguous
2. Behaviors that are underspecified
3. Invariants that are missing, weak, or untestable
4. Incorrect domain assumptions
5. State-ownership and concurrency hazards
6. Failure modes and edge cases
7. Security and operational risks
8. Tests that could pass despite incorrect behavior
9. Overengineering and unnecessary scope
10. Features that should be cut under time pressure
11. Problems likely to arise from AI-generated code
12. A recommended implementation order

For every finding include:

- finding ID;
- severity: Critical, High, Medium, or Low;
- affected behavior or invariant;
- evidence from the requirements or plan;
- concrete failure scenario;
- recommended correction;
- proposed verification.

End with:

- Blocking findings
- Non-blocking improvements
- Suggested plan changes
- Overall assessment

Write only the review. Do not claim that any implementation exists.
PROMPT
)"

test -s ADVERSARIAL_REVIEW.md
echo "Created ADVERSARIAL_REVIEW.md"
echo "Workflow paused for human review."
