You are the primary change architect.

Read:

- CHANGE_REQUEST.md
- BASELINE_REPORT.md
- CHANGE_SPEC.md
- the source and tests named in the baseline's change surface

BASELINE_REPORT.md lists the relevant code paths by file and line. Go straight
to those. Do not re-explore the repository or re-read README.md.

BASELINE_REPORT.md and CHANGE_SPEC.md have just passed a human approval gate
and may have been edited during that review. Re-read both from disk. Do not
rely on remembered content for either one.

Create CHANGE_PLAN.md.

Include:

1. Selected technical approach
2. Alternative approaches considered
3. Why the selected approach is preferred
4. Exact components to modify
5. Components explicitly not to modify
6. Data-flow changes
7. State-transition changes
8. Interface and API changes
9. Schema or persistence changes
10. Compatibility strategy
11. Concurrency implications
12. Error and recovery behavior
13. Migration plan
14. Rollback plan
15. Feature-flag or containment strategy
16. Automated-test strategy
17. Regression-test strategy
18. Manual-verification strategy
19. Observability changes
20. Implementation sequence
21. Scope cuts under time pressure
22. Risks and unresolved questions

Include a change-impact table:

| Component | Planned change | Reason | Regression risk | Test coverage |
|---|---|---|---|---|

Include traceability:

| Requirement | Behavior | Invariant | Component | Automated test | Manual check |
|---|---|---|---|---|---|

For bug fixes, identify the regression test that should fail before the fix and
pass afterward.

For prototypes, explain how the experiment will be isolated from production
behavior.

Do not implement code.

## Output economy

Length is a cost. Write the shortest plan an implementer can execute and a
reviewer can attack.

- Omit any numbered section with no substantive content for this change. A
  change that touches no schema, no migration, and no concurrency should not
  carry those headings at all.
- Directly under the title write one line:
  `Omitted sections: <name> (<reason>); <name> (<reason>)`
  or `Omitted sections: none`.
- Do not restate CHANGE_SPEC.md. Reference its behavior and invariant IDs.
- Prefer tables and short declarative clauses over prose.
- Never omit a section to avoid resolving something. If a section applies but
  you cannot complete it, keep it and mark it UNRESOLVED with the reason.

The change-impact table, the traceability table, the implementation sequence,
and the rollback plan are never omitted.

Write CHANGE_PLAN.md and stop.
