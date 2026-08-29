ID: FA-001
Severity: Critical
Evidence: Authoritative `.workflow/change.diff` has no diff entries for `scripts/lib/audit-verdict.sh`, `scripts/tests/audit-verdict-test.sh`, or `scripts/tests/close-flow-test.sh` (diff headers end with source files at lines 2735 and 2895), although `.workflow/change.diff:2755` makes the driver source the missing library and `IMPLEMENTATION_NOTES.md:18-20` claims all three were added.
Affected behavior: Applying the authoritative change produces a driver that fails during normal startup and omits all new automated coverage.
Affected invariant: I-04, I-08
Required correction: Include the three untracked files in the authoritative diff and rerun verification against the complete, reconstructable change.
Blocks completion: Yes

ID: FA-002
Severity: Critical
Evidence: `scripts/change-workflow.sh:156-179` lets multiple contenders independently observe a stale lock and execute `rm -rf`; one contender can delete a lock newly acquired by another between those operations, allowing both drivers to proceed. Tests at `scripts/tests/close-flow-test.sh:363-390` exercise only one live holder or one stale-lock reclaimer, while `VERIFICATION_REPORT.md:69` claims I-10 PASS.
Affected behavior: Concurrent workflows can again interleave state, audit, verdict, and close operations.
Affected invariant: I-08, I-10
Required correction: Make stale-lock reclamation ownership-safe or fail closed on stale locks, and add a coordinated two-reclaimer concurrency test.
Blocks completion: Yes

ID: FA-003
Severity: High
Evidence: `CHANGE_TEST_REPORT.md:16` claims COMPLETE reseeding is covered, but `scripts/tests/close-flow-test.sh:347-352` asserts only `SEED_WRITE`. In production, `scripts/from-issue.sh:38-43,519-527` accepts and rewrites a request at COMPLETE, while `scripts/change-workflow.sh:601-607,781-798` immediately dispatches COMPLETE and exits without entering ANALYZE.
Affected behavior: After one completed workflow, the next confirmed issue does not run the change pipeline and cannot close.
Affected invariant: I-07, I-08, I-11
Required correction: Define and implement an explicit completed-run restart transition to ANALYZE, then test the real driver reaching ANALYZE and producing a current-run verdict.
Blocks completion: Yes

ID: FA-004
Severity: High
Evidence: `VERIFICATION_REPORT.md:39` marks MC-020 PASS for fresh/restartable COMPLETE state while admitting its only assertion was `SEED_WRITE`; `UPDATED_CHANGE_PLAN.md:34,99,118` requires COMPLETE restart to reach ANALYZE and rewrite origin, which the implementation never does.
Affected behavior: The claimed completed-state restart behavior is unverified and contradicted by dispatch behavior.
Affected invariant: I-11
Required correction: Correct the state transition and execute MC-020 through actual driver dispatch rather than stopping at the seed decision.
Blocks completion: Yes

ID: FA-005
Severity: High
Evidence: `VERIFICATION_REPORT.md:20,23-24,30,38,43,47` records the real pipeline, real close, resume, preserved internal gates, rollback, and real NOT_READY integration as NOT RUN; its recommendation at line 81 explicitly says not to declare the change complete.
Affected behavior: AC-1, AC-3, portions of AC-4, same-origin recovery, and preserved workflow behavior lack required end-to-end evidence.
Affected invariant: I-01, I-02, I-03, I-05, I-08, I-11
Required correction: Run the remaining blocking checks in a disposable checkout and issue with explicit authorization for pipeline cost and GitHub mutation.
Blocks completion: Yes

ID: FA-006
Severity: Medium
Evidence: `CHANGE_SPEC.md:46-50`, `UPDATED_CHANGE_PLAN.md:139`, and `README.md:130-134` require or document printing the populated request, but `scripts/from-issue.sh:80-104` prints only a banner, filenames, and editing commands. `VERIFICATION_REPORT.md:41` nevertheless marks documentation consistency PASS.
Affected behavior: Users are promised an inline display of the seeded request but do not receive it.
Affected invariant: I-07
Required correction: Print `CHANGE_REQUEST.md` before confirmation or revise and reapprove the specification and documentation.
Blocks completion: Yes

ID: FA-007
Severity: Medium
Evidence: `CHANGE_TEST_REPORT.md:55-57` labels an execution of only the pre-change `--new` path as a rollback test, while `VERIFICATION_REPORT.md:43` records MC-024—the actual revert, leftover-metadata, and post-revert smoke check—as NOT RUN.
Affected behavior: Rollback of the changed `--change` and driver paths is not verified.
Affected invariant: I-05, I-06
Required correction: Perform the planned disposable revert with new metadata retained, then smoke-test the restored change workflow and cleanup procedure.
Blocks completion: Yes

ID: FA-008
Severity: Medium
Evidence: `scripts/from-issue.sh:213-219` adds the test-only `STAGEGATE_FROM_ISSUE_SOURCE_ONLY=1` production branch, which silently exits before help, parsing, fetch, or seeding; `IMPLEMENTATION_NOTES.md:47` identifies it as a testing deviation not present in the approved public interface.
Affected behavior: An ambient test variable can silently turn every production invocation into a successful no-op.
Affected invariant: I-04, I-07
Required correction: Extract sourceable flow functions into a library used by both production and tests, eliminating the hidden production bypass.
Blocks completion: No

ID: FA-009
Severity: Medium
Evidence: `CHANGE_TEST_REPORT.md:16` claims piped stdin was verified as blocking, but `scripts/tests/close-flow-test.sh:205-212` queues `RUN` before starting the process and never observes it waiting without input.
Affected behavior: The approved non-interactive compatibility break lacks executed blocking evidence.
Affected invariant: I-07
Required correction: Add a FIFO/process-liveness test that starts with no input, proves the process remains blocked, then supplies `RUN`.
Blocks completion: No

ID: FA-010
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:22` marks MC-003 PASS for blocking behavior while explicitly stating input was already queued; this cannot demonstrate that the process waited.
Affected behavior: Non-TTY prompt blocking is claimed without executing the required wait scenario.
Affected invariant: I-07
Required correction: Execute MC-003 as written with delayed FIFO input and capture process-liveness evidence.
Blocks completion: No

ID: FA-011
Severity: Medium
Evidence: `CHANGE_TEST_REPORT.md:23` claims standalone origin preflight is unaffected based on `preflight-standalone-unaffected`, but that test sets `WORKFLOW_TRACK=bogus` (`scripts/tests/close-flow-test.sh:409-416`), causing validation at `scripts/change-workflow.sh:591-594` to exit before preflight at lines 598-599.
Affected behavior: Standalone compatibility was not exercised through the new preflight.
Affected invariant: I-04, I-11
Required correction: Run a valid standalone state with agent/reviewer stubs and no origin environment through lock acquisition and origin preflight.
Blocks completion: No

ID: FA-012
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:40` marks MC-021 PASS using the same invalid-track early exit and seed-only fixtures; neither demonstrates standalone traversal through preflight nor safe issue-seeded restart from COMPLETE.
Affected behavior: Legacy/additive-state compatibility is overstated.
Affected invariant: I-06, I-11
Required correction: Exercise valid legacy standalone and issue-seeded states through actual driver dispatch and compare preserved state formats.
Blocks completion: No

NOT READY