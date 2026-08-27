Act as an independent release-verification engineer.

Read:

- CHANGE_REQUEST.md
- BASELINE_REPORT.md
- CHANGE_SPEC.md
- ADVERSARIAL_REVIEW.md
- UPDATED_CHANGE_PLAN.md
- IMPLEMENTATION_NOTES.md
- CHANGE_TEST_REPORT.md
- changed source files
- relevant unchanged source files
- automated tests

Do not modify source code.
Do not claim any check passed.

Create MANUAL_CHECKLIST.md.

Verify:

1. Requested behavior
2. All MODIFY behaviors
3. All ADD behaviors
4. All REMOVE behaviors
5. Representative PRESERVE behaviors
6. Existing invariants
7. New or strengthened invariants
8. Boundary conditions
9. Error behavior
10. Failure and recovery behavior
11. Backward compatibility
12. Migration
13. Rollback
14. Restart behavior
15. Observability
16. Performance-sensitive paths
17. Security-sensitive paths
18. Prototype isolation
19. Regression-sensitive paths
20. Requirements not covered by automated tests

Each check must contain:

- Check ID
- Priority
- Behavior classification
- Related behavior
- Related invariant
- Preconditions
- Exact action
- Expected result
- Evidence to capture
- Actual result: blank
- Status: NOT RUN

End with:

- acceptance-criteria traceability
- preserved-behavior coverage
- changed-behavior coverage
- invariant coverage
- regression coverage

## Output economy

The twenty categories above are search directions, not an output template.

- Emit a check only where there is something specific to verify.
- If a category does not apply to this change, skip it silently.
- One line per field.
- Merge checks that would be executed by the same action against the same
  preconditions. Do not split one action into five near-identical rows.
- Use check IDs MC-001 upward.

Return only the checklist.
