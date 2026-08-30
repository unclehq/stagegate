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

Revise CHANGE_PLAN.md in place. Do not create a second plan document.

Edit only the sections the review actually changes. A section the review did not
touch is left exactly as it is — do not rewrite it, reword it, or restate it.
CHANGE_PLAN.md is the sole plan input to every later stage, so what you leave
behind is what implementation executes.

Insert directly below the title a disposition for every adversarial finding:

| Finding | Disposition | Reason | Exact plan change |
|---|---|---|---|

Allowed dispositions:

- Accepted
- Partially accepted
- Rejected
- Deferred

The `Exact plan change` cell names the section you edited, or `none` for a
rejected or deferred finding. The disposition table covers every finding. It is
never omitted and never abbreviated.

Append these sections:

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

Length is a cost. The revised CHANGE_PLAN.md is read by five later stages and
re-sent on every turn of each of them.

- Budget: the disposition table and the ten appended sections together should
  come to **1,200 words or fewer**. Going over means the appended sections are
  carrying prose that belongs in a table.
- Editing a section means changing the lines the review invalidated. It does
  not mean rewriting the section from scratch.
- Do not summarize what you changed at the end. The disposition table is that
  record.
- Omit any appended section with no substantive content, and list it under the
  disposition table as `Omitted sections: <name> (<reason>)`, or write
  `Omitted sections: none`.
- Frozen change scope, files expected to change, files that must not change,
  and exact acceptance criteria are never omitted. Implementation is bounded
  by them.
- Never omit a section to avoid resolving something. If a section applies but
  you cannot complete it, keep it and mark it UNRESOLVED with the reason.

Save CHANGE_PLAN.md and stop.
