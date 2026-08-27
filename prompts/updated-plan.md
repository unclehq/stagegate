You are the primary system architect.

Read these in one parallel batch of tool calls:

- REQUIREMENTS.md
- REQUIREMENTS_INTERPRETATION.md
- PROJECT_PLAN.md
- ADVERSARIAL_REVIEW.md

Create UPDATED_PROJECT_PLAN.md.

For every adversarial finding, record:

| Finding | Disposition | Reason | Plan change |
|---|---|---|---|

Allowed dispositions:

- Accepted
- Partially accepted
- Rejected
- Deferred

Do not blindly accept every recommendation.

Retain and update:

- behaviors;
- invariants;
- architecture;
- traceability;
- testing strategy;
- failure handling;
- implementation order;
- time-based priorities;
- explicit non-goals.

Clearly identify changes from PROJECT_PLAN.md.

This document is the sole plan input to implementation, checklist creation, and
the final audit — none of them will read PROJECT_PLAN.md or
ADVERSARIAL_REVIEW.md. So it must stand alone. Standing alone means every
normative row survives, not every sentence:

- carry forward every behavior, invariant, and traceability row, updated — a
  reader must never need the superseded plan to know what to build or what must
  hold;
- drop the narrative around those rows: rationale that no longer drives a
  decision, alternatives considered and rejected, and restated background;
- in the disposition table, cite each finding by its AR-XXX identifier and give
  the reason in a sentence; do not restate the finding;
- reference requirements by identifier rather than restating them;
- no preamble and no closing recap.

UPDATED_PROJECT_PLAN.md must not exceed the combined length of PROJECT_PLAN.md
and ADVERSARIAL_REVIEW.md, both of which you have just read. It supersedes
them, so it replaces their cost rather than adding to it — three later stages
read this file, and one re-sends it on every turn of a long loop, so every
paragraph here is paid many times over. If the rows do not fit in that budget,
cut prose, never rows.

Do not implement code.
Do not invoke another agent.
Do not draft the plan in chat before writing it.

Write only UPDATED_PROJECT_PLAN.md, in a single Write call, and stop.
