ID: FA-001
Severity: High
Evidence: `scripts/stagegate.sh:266-279` writes `before` after the final comparison; `scripts/tests/gate-prompt-test.sh:542-553` mutates after that comparison, expects an approval file containing the now-mismatched digest, and treats this as success; `VERIFICATION_REPORT.md:18` marks MC-007 PASS and incorrectly says no approval was recorded for mutated content.
Affected behavior: A mutation between validation and recording can leave a stale approval instead of reopening or declining.
Affected invariant: I-2, I-3, UPDATED_CHANGE_PLAN.md acceptance criterion 6.
Required correction: Detect mutation through the recording boundary, remove any stale approval and reopen/decline, and change the race test to require no mismatched approval.
Blocks completion: Yes

ID: FA-002
Severity: High
Evidence: The `diff --git` inventory in `.workflow/change.diff` omits `scripts/tests/gate-prompt-test.sh`, although `UPDATED_CHANGE_PLAN.md:298-305` and `IMPLEMENTATION_NOTES.md:8-12` identify it as a new required file; this contradicts the MC-018 PASS at `VERIFICATION_REPORT.md:29`.
Affected behavior: The authoritative change record does not contain the changed regression suite and cannot support the claimed six-path scope audit.
Affected invariant: Frozen-scope traceability and authoritative-diff completeness.
Required correction: Regenerate `.workflow/change.diff` from the correct baseline so it includes every implementation and test change, then repeat the scope audit.
Blocks completion: Yes

ID: FA-003
Severity: High
Evidence: MC-001 requires driving the real `change-workflow.sh` gates and inspecting state (`MANUAL_CHECKLIST.md:10-13`), but `VERIFICATION_REPORT.md:12` used an extracted-function harness; `IMPLEMENTATION_NOTES.md` deviation D-1 confirms this substitution.
Affected behavior: Real driver integration, state advancement, and all four actual call sites were not executed as claimed.
Affected invariant: I-2, I-5, I-8.
Required correction: Execute MC-001 through the real driver at every gate or mark MC-001 NOT RUN.
Blocks completion: Yes

ID: FA-004
Severity: High
Evidence: MC-002 requires real-driver state and downstream-command evidence (`MANUAL_CHECKLIST.md:22-25`), while its PASS at `VERIFICATION_REPORT.md:13` comes from extracted-function sentinels.
Affected behavior: Decline behavior was not verified with real state dispatch or downstream execution.
Affected invariant: I-5, I-6.
Required correction: Run the complete input matrix through representative real `change-workflow.sh` gates and capture state/downstream traces, or mark MC-002 NOT RUN.
Blocks completion: Yes

ID: FA-005
Severity: High
Evidence: MC-003 requires independently driving all four real `stagegate.sh` gates (`MANUAL_CHECKLIST.md:34-37`), but `VERIFICATION_REPORT.md:14` reports only extracted-function harness executions.
Affected behavior: Real caller transitions and approval mapping at all stagegate call sites remain unverified.
Affected invariant: I-2, I-3, I-8.
Required correction: Execute all four call sites through the real driver or mark MC-003 NOT RUN.
Blocks completion: Yes

ID: FA-006
Severity: High
Evidence: MC-004 requires real workflow state and downstream-command traces (`MANUAL_CHECKLIST.md:46-49`), but `VERIFICATION_REPORT.md:15` bases PASS on an extracted representative function.
Affected behavior: Real-driver decline and EOF behavior is not established.
Affected invariant: I-3, I-5, I-6.
Required correction: Execute the MC-004 matrix through a real stagegate gate and retain the required evidence, or mark it NOT RUN.
Blocks completion: Yes

ID: FA-007
Severity: High
Evidence: `VERIFICATION_REPORT.md:16` claims all three `workflow.sh` subcommands accepted both `y` and `Y`; the automated suite tests both cases only for `approve-plan` (`scripts/tests/gate-prompt-test.sh:260-267`) and tests the other subcommands only with lowercase `y` (`:296-306`).
Affected behavior: Uppercase acceptance and approval mapping for `approve-review` and `approve-updated-plan` are unsupported.
Affected invariant: I-2, I-6, I-8.
Required correction: Execute and retain distinct uppercase-`Y` evidence for every subcommand, or narrow MC-005 to the cases actually run.
Blocks completion: Yes

ID: FA-008
Severity: High
Evidence: `VERIFICATION_REPORT.md:17` claims the complete decline matrix ran for every `workflow.sh` subcommand; `scripts/tests/gate-prompt-test.sh:274-294` applies that matrix only to `approve-plan`, while `:296-306` only accepts lowercase `y` for the other subcommands.
Affected behavior: Decline, EOF, legacy-word, and uppercase-input behavior is unsupported for two subcommands.
Affected invariant: I-4, I-6.
Required correction: Run the full matrix for all three subcommands or mark the unsupported portions of MC-006 NOT RUN.
Blocks completion: Yes

ID: FA-009
Severity: Medium
Evidence: `scripts/tests/gate-prompt-test.sh:2,22-23,139-145` does not abort when `mktemp -d` fails; an empty `TMP` makes cases resolve to root paths such as `/g1-accept-y`, causing attempted root-level writes.
Affected behavior: The supposedly hermetic test can write outside its scratch directory on a privileged or misconfigured runner.
Affected invariant: Test isolation and safe failure behavior.
Required correction: Fail immediately when scratch-directory creation fails and validate that the resolved case path is beneath the nonempty scratch directory.
Blocks completion: Yes

ID: FA-010
Severity: Medium
Evidence: MC-010 is marked PASS at `VERIFICATION_REPORT.md:21`, but `scripts/README.md:45-61` contains no Y/N contract; this misses B-9 and CHANGE_SPEC.md:85-88, while `scripts/README.md:78` also contradicts UPDATED_CHANGE_PLAN.md:363-365’s unqualified `exact word` prohibition.
Affected behavior: One required user-facing document does not describe the new gate response, and the approved criterion conflicts with the preserved RUN documentation.
Affected invariant: Documentation/migration consistency.
Required correction: Document `y`/`Y` behavior for affected gates in `scripts/README.md` and revise criterion 9 to explicitly exempt the preserved RUN gate.
Blocks completion: Yes

ID: FA-011
Severity: Medium
Evidence: MC-012 requires a restart after acceptance (`MANUAL_CHECKLIST.md:142-145`), but `/tmp/stagegate-verify/resume.sh` runs only one decline followed by one acceptance and performs no post-accept restart; `VERIFICATION_REPORT.md:23` nevertheless marks PASS.
Affected behavior: Re-entry after an accepted gate remains unverified.
Affected invariant: State-transition idempotency and resumability.
Required correction: Perform the required post-accept restart for all affected workflows and capture resulting state, or mark MC-012 NOT RUN.
Blocks completion: Yes

ID: FA-012
Severity: Medium
Evidence: MC-015 requires reverting the isolated release unit and testing all affected scripts and documentation (`MANUAL_CHECKLIST.md:178-181`); `/tmp/stagegate-verify/rollback.sh` merely extracts five parent versions and exercises only `workflow.sh`, while `CHANGE_TEST_REPORT.md` explicitly records the rollback test as NOT RUN.
Affected behavior: Full rollback of both drivers, documentation, and the new test is not verified.
Affected invariant: Rollback completeness and preservation of unrelated work.
Required correction: Perform the planned isolated revert and verify all three gates, docs, test removal, RUN preservation, and unrelated-file status.
Blocks completion: Yes

ID: FA-013
Severity: Medium
Evidence: MC-017 requires end-to-end runs of both drivers (`MANUAL_CHECKLIST.md:202-205`), but `VERIFICATION_REPORT.md:28` reports only a real `stagegate.sh` run.
Affected behavior: `change-workflow.sh` gate integration with preflight, locking, state dispatch, and resumption lacks end-to-end coverage.
Affected invariant: I-2, I-5 and real-driver integration.
Required correction: Add the missing end-to-end `change-workflow.sh` execution or mark MC-017 partial/NOT RUN.
Blocks completion: Yes

ID: FA-014
Severity: Medium
Evidence: MC-008 requires scans of approval, state, and project-log files (`MANUAL_CHECKLIST.md:94-97`), but `/tmp/stagegate-verify/style.sh` inspects only captured stdout; `VERIFICATION_REPORT.md:19` marks the whole check PASS.
Affected behavior: The claim that ANSI never enters persisted artifacts or project logs lacks executed evidence.
Affected invariant: I-7 and CHANGE_SPEC.md security requirement at lines 79-83.
Required correction: Scan the specified persisted artifacts and logs in each mode, or narrow MC-008 and mark the omitted checks NOT RUN.
Blocks completion: Yes

ID: FA-015
Severity: Medium
Evidence: MC-013 requires filesystem and approval/state/log corruption scans (`MANUAL_CHECKLIST.md:149-157`), while `/tmp/stagegate-verify/strict.sh` records only exit codes and approval-file counts; `VERIFICATION_REPORT.md:24` marks PASS.
Affected behavior: Non-persistence and corruption claims for hostile/control-byte inputs are unsupported.
Affected invariant: I-2, I-6.
Required correction: Capture the required filesystem diff and byte-level state/log scans, or limit the reported PASS to strict input rejection.
Blocks completion: No

ID: FA-016
Severity: Medium
Evidence: MC-014 requires baseline/release comparisons for every affected script and all listed records (`MANUAL_CHECKLIST.md:166-169`), but `/tmp/stagegate-verify/observability.sh` exercises only `workflow.sh` and lists `.workflow`; `VERIFICATION_REPORT.md:25` marks the complete check PASS.
Affected behavior: Claims that spend, cost, lock, origin, verdict, and project-log behavior are unchanged in both drivers are unsupported.
Affected invariant: Unchanged observability and persistence contracts.
Required correction: Perform the full three-script comparison or mark the unexecuted portions NOT RUN.
Blocks completion: No

ID: FA-017
Severity: Medium
Evidence: MC-016 requires both exit-status-only and output-aware wrappers (`MANUAL_CHECKLIST.md:190-193`), but `/tmp/stagegate-verify/wrapper-aware.sh` and `VERIFICATION_REPORT.md:27` exercise only output-aware wrappers.
Affected behavior: The known silent-success behavior of legacy exit-status-only wrappers was not executed or reported by the claimed PASS.
Affected invariant: Compatibility and migration transparency.
Required correction: Run the exit-status-only wrapper cases and record their downstream behavior, or mark MC-016 partial while retaining the documented compatibility risk.
Blocks completion: No

NOT READY