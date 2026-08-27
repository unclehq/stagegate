You are the primary change architect.

Read:

- CHANGE_PLAN.md
- ADVERSARIAL_REVIEW.md
- CHANGE_SPEC.md

Both CHANGE_PLAN.md and ADVERSARIAL_REVIEW.md have just passed a human gate and
may have been edited during that review. Read both from disk in full.

CHANGE_SPEC.md is for traceability only; consult its behavior and invariant IDs
as needed. You do not need CHANGE_REQUEST.md or BASELINE_REPORT.md: the plan and
the spec already encode them. Open one only if a specific finding turns on
something neither document records.

Create UPDATED_CHANGE_PLAN.md.

Include a disposition for every adversarial finding:

| Finding | Disposition | Reason | Exact plan change |
|---|---|---|---|

Allowed dispositions:

- Accepted
- Partially accepted
- Rejected
- Deferred

Retain and update:

- change scope
- behavior classifications
- invariants
- compatibility strategy
- migration strategy
- rollback strategy
- test strategy
- regression strategy
- observability
- implementation order
- traceability

Add:

1. Frozen change scope
2. Files expected to change
3. Files that must not change
4. Expected behavioral differences
5. Expected unchanged behavior
6. Exact acceptance criteria
7. Pre-implementation checks
8. Post-implementation checks
9. First features to cut if time expires
10. Conditions that require stopping implementation

Do not implement code.

## Output economy

CHANGE_PLAN.md is hash-approved and immutable, so this document may reference
it instead of reproducing it.

- For each retained section that the review did not change, write one line:
  `Unchanged from CHANGE_PLAN.md § <n>`.
- Reproduce in full only the sections the review actually changed, plus the
  ten added sections.
- Omit any added section with no substantive content, and list it directly
  under the title as
  `Omitted sections: <name> (<reason>)`, or write `Omitted sections: none`.
- The disposition table covers every adversarial finding. It is never omitted
  and never abbreviated.
- Frozen change scope, files expected to change, files that must not change,
  and exact acceptance criteria are never omitted. Implementation is bounded
  by them.
- Never omit a section to avoid resolving something. If a section applies but
  you cannot complete it, keep it and mark it UNRESOLVED with the reason.

Write UPDATED_CHANGE_PLAN.md and stop.
