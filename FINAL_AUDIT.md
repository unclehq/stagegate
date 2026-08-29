ID: F-001
Severity: High
Evidence: CHANGE_SPEC.md:42 requires zero-argument `workflow.sh` to exit 0; `.workflow/change.diff`:163-167 omits `0:` and reaches `mkdir -p`; IMPLEMENTATION_NOTES.md:34-58 acknowledges AC-06 remains unmet, while VERIFICATION_REPORT.md:103-108 recommends completion.
Affected behavior: `workflow.sh` with no arguments exits 1 and creates `.workflow/approvals`.
Affected invariant: IV-03; AC-06/BH-13.
Required correction: Obtain the required approval and implement/test the zero-argument branch, or formally revise the acceptance criterion before completion.
Blocks completion: Yes

ID: F-002
Severity: High
Evidence: `.workflow/change.diff`:1-215 adds a link to `scripts/README.md` but contains no diff entry for that new file; IMPLEMENTATION_NOTES.md:24 and VERIFICATION_REPORT.md:49 nevertheless treat AC-08 as delivered and passed.
Affected behavior: Applying the authoritative change produces a documentation link whose target is absent.
Affected invariant: AC-08/BH-17; authoritative change-package completeness.
Required correction: Include `scripts/README.md` in the authoritative diff and rerun verification against exactly that recorded change.
Blocks completion: Yes

ID: F-003
Severity: Medium
Evidence: VERIFICATION_REPORT.md:19 marks MC-008 PASS for APPROVE, missing-file, and REJECT scenarios across all three approval subcommands; `.workflow/logs/execute-checklist.jsonl`:81-99 shows missing-file and REJECT were run only for `approve-plan`, while the other two received only APPROVE checks and no resulting-hash comparison. VERIFICATION_REPORT.md:54-56 repeats the unsupported full-coverage claim.
Affected behavior: Regression preservation of `approve-review` and `approve-updated-plan` failure/rejection paths and approval hashes.
Affected invariant: BH-14; IV-03; AC-06 compatibility.
Required correction: Execute every MC-008 scenario for every approval subcommand, compare generated hashes, and correct the report.
Blocks completion: Yes

ID: F-004
Severity: Medium
Evidence: scripts/README.md:131-133 states recognized flags with trailing arguments are rejected, but scripts/from-issue.sh:26-28 accepts `--help` or `-h` regardless of trailing arguments; VERIFICATION_REPORT.md:22 marks the documentation comparison PASS without testing this exception.
Affected behavior: Documented behavior of `from-issue.sh --help extra` and `from-issue.sh -h extra`.
Affected invariant: BH-16; AC-08 documentation accuracy.
Required correction: Qualify the trailing-argument rule for `from-issue.sh` or obtain approval to change its preserved behavior, then add regression coverage.
Blocks completion: Yes

ID: F-005
Severity: Medium
Evidence: CHANGE_TEST_REPORT.md:126 marks MC-06 PASS and says `.workflow` remained absent after T-14; `.workflow/logs/implementation.jsonl`:130-131 shows T-14 deleted `.workflow` after each zero-argument run without inspecting it, while `.workflow/change.diff`:134-143 shows zero arguments necessarily continue to directory creation.
Affected behavior: Verification of zero-argument driver filesystem and cost-ledger effects.
Affected invariant: Regression-containment evidence for BH-04/BH-08.
Required correction: Remove the unsupported absence claim or rerun T-14 comparing filesystem, logs, and cost-ledger state before cleanup.
Blocks completion: No

ID: F-006
Severity: Medium
Evidence: VERIFICATION_REPORT.md:32 marks MC-022 PASS with “no `.workflow` mutation” across roughly 30 invocations, contradicting its own MC-017 result at line 27; MANUAL_CHECKLIST.md:233-243 required process monitoring and filesystem/log/cost manifests, which were not captured.
Affected behavior: Assurance that guarded help/version/error paths cannot start external work or mutate workflow state.
Affected invariant: IV-07/IV-08.
Required correction: Scope the claim only to the actually checked invocations and execute the prescribed monitoring/manifest checks before marking MC-022 PASS.
Blocks completion: No

NOT READY