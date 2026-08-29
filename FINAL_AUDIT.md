ID: FA-001
Severity: Critical
Evidence: `DEFECTS.md:9-74`; `scripts/change-workflow.sh:207-240,272-301`; `scripts/lib/issue-close.sh:130-135`.
Affected behavior: A `COMPLETE` rerun explicitly bound to `owner/repo#42` can close a stale `.workflow/origin` target such as `other/repo#99`.
Affected invariant: INV-1 and INV-3.
Required correction: Cross-check explicit `STAGEGATE_ORIGIN_*` against the on-disk origin before closing, use the explicit binding as the target when present, and add a divergent-env/origin regression test.
Blocks completion: Yes

ID: FA-002
Severity: Critical
Evidence: `.workflow/change.diff:1,178,314,354,416` contains only reports, documentation, and one test file; `IMPLEMENTATION_NOTES.md:21-27` identifies four source files as changed.
Affected behavior: The authoritative audit input omits the implementation of state parsing and issue closing.
Affected invariant: Frozen-scope and change-traceability integrity.
Required correction: Regenerate `.workflow/change.diff` against the approved pre-change baseline so it includes every source, test, and documentation change, then repeat final audit and scope verification.
Blocks completion: Yes

ID: FA-003
Severity: High
Evidence: `CHANGE_TEST_REPORT.md:26,58-68` marks security PASS and claims INV-3 is satisfied; `DEFECTS.md:33-49` records an executed wrong-issue close.
Affected behavior: The security result certifies a close gate that can target an issue not named by the invocation.
Affected invariant: INV-3.
Required correction: Change this PASS to FAIL, correct FA-001, and rerun the complete security matrix.
Blocks completion: Yes

ID: FA-004
Severity: High
Evidence: `VERIFICATION_REPORT.md:28` reports the mismatched-origin fixture as PASS/no-close, while `DEFECTS.md:33-49` reports the same `mc009-originmismatch3` scenario closing `other/repo#99`.
Affected behavior: MC-009’s origin-mismatch PASS claim contradicts executed evidence.
Affected invariant: INV-1 and INV-3.
Required correction: Record MC-009 as FAIL, preserve the reproduction, fix the gate, and rerun the entire fixture matrix.
Blocks completion: Yes

ID: FA-005
Severity: High
Evidence: `VERIFICATION_REPORT.md:42` marks frozen-scope verification PASS using `git diff HEAD`; `.workflow/change.diff` omits the source changes already present in `HEAD`.
Affected behavior: Protected-file and unchanged-default assertions were compared against the implemented revision rather than the approved baseline.
Affected invariant: Frozen change scope.
Required correction: Reperform MC-024 against the actual pre-change revision or preimplementation hashes and record the complete path-limited diff.
Blocks completion: Yes

ID: FA-006
Severity: High
Evidence: `VERIFICATION_REPORT.md:24` marks MC-005 PASS after invoking only the sourced seed gate; `CHANGE_PLAN.md:253` requires `from-issue.sh --change` and `UPDATED_CHANGE_PLAN.md:380` requires MV-1–MV-8 to be executed.
Affected behavior: The full mismatch-refusal entry point, including its no-seed/no-dispatch effects, was not manually exercised.
Affected invariant: INV-1 and INV-5.
Required correction: Execute MV-3 through the real CLI in a disposable checkout and capture exit status, unchanged hashes, output, and absence of downstream calls.
Blocks completion: Yes

ID: FA-007
Severity: High
Evidence: `VERIFICATION_REPORT.md:6-11,26` marks MC-007 PASS with stubbed `gh`; `CHANGE_PLAN.md:254` requires a direct READY run against a disposable issue with authenticated `gh`.
Affected behavior: Actual GitHub closure and marker behavior were not verified end to end.
Affected invariant: INV-3.
Required correction: Run authorized MV-4 against a disposable issue or record it as NOT RUN; do not count the stubbed fixture as the required manual PASS.
Blocks completion: Yes

ID: FA-008
Severity: High
Evidence: `VERIFICATION_REPORT.md:29` marks MC-010 PASS from an unprefixed `FINAL_AUDIT` fixture; `UPDATED_CHANGE_PLAN.md:220,380` requires MV-7 with cleared state and a fresh direct run.
Affected behavior: The specified fresh-run stale-origin path was not executed from empty state.
Affected invariant: INV-1 and INV-3.
Required correction: Execute MV-7 exactly from cleared state through completion and capture the close log and marker absence.
Blocks completion: Yes

ID: FA-009
Severity: High
Evidence: `VERIFICATION_REPORT.md:32` marks MC-013 PASS while admitting no real curl fetch or issue was exercised; `UPDATED_CHANGE_PLAN.md:221,380` requires forcing curl fallback for a real disposable issue.
Affected behavior: Fetch provenance across the real `from-issue.sh` → driver chain remains unverified.
Affected invariant: INV-3.
Required correction: Execute authorized MV-8 end to end or mark it NOT RUN.
Blocks completion: Yes

ID: FA-010
Severity: High
Evidence: `VERIFICATION_REPORT.md:39` marks MC-020 PASS for SIGINT cleanup; the recorded MC-020 scenario in `.workflow/logs/execute-checklist.jsonl` omitted `CHANGE_REQUEST.md`, allowing the driver to exit before the signal without proving the lock was held.
Affected behavior: Lock cleanup after an actual interrupted in-flight run is unsupported.
Affected invariant: INV-2 and BEH-E.
Required correction: Hold the driver in a confirmed post-lock stage, verify the lock exists, send SIGINT, wait for exit, and verify the whole lock directory is removed.
Blocks completion: Yes

ID: FA-011
Severity: Medium
Evidence: `CHANGE_TEST_REPORT.md:23` calls a fresh `git archive HEAD` baseline-suite run a rollback PASS; it does not revert a migrated checkout or resume from prefixed state as required by `MANUAL_CHECKLIST.md:305-315`.
Affected behavior: Rollback compatibility with persisted prefixed state and the legacy wrapper is unverified.
Affected invariant: Rollback expectations for BEH-B and BEH-D.
Required correction: Revert a disposable implemented checkout, rewrite prefixed state as documented, and verify legacy resume and close behavior.
Blocks completion: No

ID: FA-012
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:45` marks MC-027 PASS while explicitly citing the prior rollback result instead of rerunning the state rewrite and legacy-wrapper resume required by `MANUAL_CHECKLIST.md:305-315`.
Affected behavior: Verification overstates rollback coverage.
Affected invariant: Rollback evidence integrity.
Required correction: Execute the complete MC-027 procedure or change its status to NOT RUN.
Blocks completion: No

ID: FA-013
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:20` marks MC-001 PASS with partial evidence from only ANALYZE, FINAL_AUDIT, and COMPLETE; `MANUAL_CHECKLIST.md:5-15` requires every transition in the ordered state sequence.
Affected behavior: Intermediate stage ordering and prefixed writes were not executed.
Affected invariant: BEH-B and INV-1.
Required correction: Exercise and record every named transition or mark MC-001 partial/NOT RUN.
Blocks completion: No

ID: FA-014
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:21` marks MC-002 PASS after testing only ANALYZE, FINAL_AUDIT, and COMPLETE; `MANUAL_CHECKLIST.md:17-27` requires every legacy bare stage token.
Affected behavior: Backward compatibility for PLAN, UPDATED_PLAN, IMPLEMENT, CHECKLIST, and EXECUTE_CHECKLIST lacks executed evidence.
Affected invariant: BEH-B legacy-state compatibility.
Required correction: Run every bare-token fixture and record dispatch, exit status, and resulting state.
Blocks completion: No

ID: FA-015
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:41` marks MC-022 PASS using an “isolated re-implementation” of `verify_approval`, rather than executing the repository function.
Affected behavior: Approved-artifact tamper rejection is not tied to execution of the shipped code.
Affected invariant: INV-4.
Required correction: Exercise the real driver/function against a mutated approved artifact or mark this portion NOT RUN.
Blocks completion: No

ID: FA-016
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:43` marks MC-025 PASS while admitting a reused reason string; `UPDATED_CHANGE_PLAN.md:225-227,401-403` requires every new guard reason to be distinct.
Affected behavior: The provenance guard does not meet the approved observability requirement.
Affected invariant: Close-gate diagnostic traceability.
Required correction: Add a distinct message or obtain approval for the documented deviation, then update and rerun assertions.
Blocks completion: No

ID: FA-017
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:44` marks MC-026 PASS while reporting missing documentation; `DEFECTS.md:76-88` identifies absent `STAGEGATE_CLOSE_TIMEOUT` and exact corruption/manual-clear guidance.
Affected behavior: User documentation does not fully describe the new configuration and recovery contract.
Affected invariant: Compatibility/documentation requirements for BEH-B and BEH-D.
Required correction: Document the timeout variable and exact corruption-recovery procedure, then repeat MC-026.
Blocks completion: No

ID: FA-018
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:49` marks MC-031 PASS; the MC-031 command in `.workflow/logs/execute-checklist.jsonl` redefined `write_origin()` inline instead of invoking the shipped driver implementation.
Affected behavior: Provenance preservation and foreign-origin rewrite semantics are not tied to executed production code.
Affected invariant: INV-1 and INV-3.
Required correction: Exercise the actual `change-workflow.sh` path through `write_origin` for all three fixtures.
Blocks completion: No

ID: FA-019
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:52` marks MC-034 PASS after testing only `--help`; `MANUAL_CHECKLIST.md:389-399` also requires a valid disposable `--change` invocation and deployment-environment inspection.
Affected behavior: The test-only source-mode hook’s production CLI and environmental-leakage risks remain unverified.
Affected invariant: Frozen command interface.
Required correction: Complete the valid `--change` matrix and confirm production launch environments do not set the hook, or mark MC-034 partial.
Blocks completion: No

ID: FA-020
Severity: Medium
Evidence: `VERIFICATION_REPORT.md:54` marks MC-036 PASS using only static diff and grep; `MANUAL_CHECKLIST.md:413-423` requires a controlled `stagegate.sh` transition and resume.
Affected behavior: Runtime compatibility of the unchanged driver beside the new state grammar was not executed.
Affected invariant: Frozen scope and legacy stagegate behavior.
Required correction: Run the specified transition/resume comparison or change MC-036 to NOT RUN.
Blocks completion: No

NOT READY