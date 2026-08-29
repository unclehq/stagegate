## AR-001: Stale workflow state can close the wrong issue

- Severity: Critical
- Affected behavior: B-04 and B-06
- Affected invariant: I-08
- Affected component: `scripts/from-issue.sh` dispatch and `scripts/change-workflow.sh` state machine
- Failure scenario: Issue B overwrites `CHANGE_REQUEST.md` while `.workflow/state` remains at `IMPLEMENT`, `EXECUTE_CHECKLIST`, or `FINAL_AUDIT` for issue A; the resumed workflow audits A’s artifacts, labels the verdict with B’s new run ID, and closes issue B.
- Evidence: `from-issue.sh:158-205` unconditionally overwrites the request, while `change-workflow.sh:507-669` resumes shared state and only reads `CHANGE_REQUEST.md` in `ANALYZE`; CHANGE_PLAN §22 acknowledges this exact risk but accepts a warning as mitigation.
- Why current tests may miss it: M-09 only checks that a warning appears and never verifies that confirmation is blocked or that the wrong issue cannot close.
- Recommended correction: Bind workflow state to the originating repository, issue, and approved request hash; refuse continuation on any mismatch rather than warning.
- Proposed verification: Seed issue A, advance to every resumable state, then seed issue B and prove the driver cannot run or close either issue until state ownership is resolved.
- Blocks implementation: Yes

## AR-002: A stale audit can be relabeled as current and authorize closure

- Severity: Critical
- Affected behavior: B-04
- Affected invariant: I-08
- Affected component: `run_codex`, `FINAL_AUDIT`, and `.workflow/audit-verdict`
- Failure scenario: An old `FINAL_AUDIT.md` says `READY`; the reviewer command exits successfully without replacing it; `require_file` accepts the stale file, and the new code writes the current run ID beside its verdict and closes the current issue.
- Evidence: `change-workflow.sh:393-420` does not remove or freshness-check the output before `run_codex`, `require_file` at lines 116-120 checks only non-emptiness, while the background equivalent explicitly removes its output at line 443; CHANGE_PLAN §1 writes the run ID only after this unchecked read.
- Why current tests may miss it: The classifier fixtures test file contents, not whether the audit was produced by the current reviewer invocation.
- Recommended correction: Write the audit to a fresh temporary path, require successful production, then atomically publish it and bind the signal to both its hash and the workflow-generation identity.
- Proposed verification: Precreate a `READY` audit, run a reviewer stub that exits 0 without writing output, and assert a hard failure with no verdict signal and no GitHub call.
- Blocks implementation: Yes

## AR-003: Concurrent runs can attach one issue’s verdict to another run ID

- Severity: High
- Affected behavior: B-04 and B-05
- Affected invariant: I-08
- Affected component: Shared `.workflow` state, `FINAL_AUDIT.md`, logs, and verdict signal
- Failure scenario: Two confirmed invocations run `FINAL_AUDIT` concurrently; one overwrites `FINAL_AUDIT.md` between the other invocation’s reviewer return and classification, causing the latter to record its own run ID with the other issue’s verdict and close incorrectly.
- Evidence: `change-workflow.sh:30-37` and 663-669 use fixed shared paths; CHANGE_PLAN §11 claims concurrency can cause only missed closes, but the run ID identifies the classifier process, not the producer or subject of `FINAL_AUDIT.md`.
- Why current tests may miss it: No planned check overlaps two reviewer invocations, and single-process classifier fixtures cannot expose shared-file races.
- Recommended correction: Serialize the entire workflow with an atomic lock or isolate every run’s artifacts and state under a unique directory.
- Proposed verification: Use two coordinated reviewer stubs that interleave output writes and prove that neither invocation can consume or close from the other’s audit.
- Blocks implementation: Yes

## AR-004: Normal pause and resume loses issue-close provenance

- Severity: High
- Affected behavior: B-02, B-03, B-04, and documented resumability
- Affected invariant: I-07 and I-08
- Affected component: `human_gate`, `from-issue.sh`, and run-ID lifecycle
- Failure scenario: A user declines an internal gate, causing the child driver to exit 0; resuming with `change-workflow.sh` has no parent close step and records run ID `-`, while resuming with `from-issue.sh` overwrites the human-edited request and creates a new identity over old state.
- Evidence: `human_gate` exits the driver at `change-workflow.sh:223-225`; README:189-190 promises rerun-based resumption; CHANGE_PLAN persists the ID only when `FINAL_AUDIT` runs and provides no durable originating-issue context before then.
- Why current tests may miss it: M-06 stops after confirming no immediate close and never resumes through completion or checks preservation of edited `CHANGE_REQUEST.md`.
- Recommended correction: Persist origin and workflow-generation metadata before launch and provide a resume path that neither refetches nor rewrites the request.
- Proposed verification: Pause at each human gate, terminate the wrapper, resume using the documented command, and prove the original issue closes exactly once without changing the seeded request.
- Blocks implementation: Yes

## AR-005: Verdict parsing can turn malformed audit prose into READY

- Severity: High
- Affected behavior: B-04 and B-05
- Affected invariant: I-08
- Affected component: `scripts/lib/audit-verdict.sh`
- Failure scenario: An audit concludes `NOT READY` but emits a trailing footer such as “rerun until READY”; the last-phrase algorithm classifies `READY` and closes the issue.
- Evidence: CHANGE_PLAN §1 searches the last line containing a phrase anywhere, although `prompts/change/final-audit.md:54-58` defines the verdict as an exact conclusion line.
- Why current tests may miss it: The proposed fixtures cover verdict phrases inside earlier findings, but not text after the conclusion or a verdict phrase embedded in trailing prose.
- Recommended correction: Accept only the final nonblank line, normalized according to one explicitly documented format, and require an exact match to one allowed verdict.
- Proposed verification: Add fixtures for trailing prose, headings, bold text, multiple conclusion lines, CRLF input, and text after `NOT READY`; every malformed form must return `UNKNOWN`.
- Blocks implementation: Yes

## AR-006: The non-TTY path contradicts the approved specification

- Severity: High
- Affected behavior: B-01 and B-02
- Affected invariant: I-07
- Affected component: `confirm_and_run_workflow`
- Failure scenario: A scripted invocation with piped stdin silently seeds and exits 0 without prompting or running the workflow, despite the specification deliberately defining the new prompt as a compatibility break.
- Evidence: CHANGE_SPEC §8 says non-interactive callers will hit the prompt and block; acceptance criterion 1 requires seed → prompt → run, while CHANGE_PLAN §10 and M-03 replace this with an immediate no-TTY decline.
- Why current tests may miss it: M-03 asserts the plan’s divergent behavior rather than the specification’s acceptance criterion.
- Recommended correction: Implement the approved behavior or revise and reapprove the specification before implementation; do not silently reinterpret lack of a TTY as human rejection.
- Proposed verification: Exercise TTY, EOF, wrong-word, and piped-input cases against one approved behavior table with explicit output and exit-code expectations.
- Blocks implementation: Yes

## AR-007: The close decision has no executable end-to-end test

- Severity: High
- Affected behavior: B-03 through B-07
- Affected invariant: I-05, I-08, and I-09
- Affected component: `close_issue_if_ready` and orchestration tests
- Failure scenario: Argument order, run-ID parsing, status handling, auth fallback, or close gating is wrong while all classifier tests and `bash -n` checks still pass, allowing an unintended live close.
- Evidence: CHANGE_PLAN §16 automates only the pure classifier; M-05 edits a reviewer-owned artifact and then reruns the stage that overwrites it without a `from-issue.sh` parent, while M-07 requires timing-dependent PATH/auth mutation during one long invocation.
- Why current tests may miss it: None of the proposed automated tests executes the code path containing the irreversible `gh issue close` call.
- Recommended correction: Add hermetic shell integration tests using temporary checkout state plus stubbed `gh` and workflow commands; reserve live GitHub verification for one disposable issue.
- Proposed verification: Assert the complete command transcript and exit status for READY, NOT_READY, UNKNOWN, stale/mismatched ID, missing signal, driver failures, auth loss, close failure, decline, and `--new`.
- Blocks implementation: Yes

## AR-008: The prescribed `if !` pattern can erase the driver’s failure status

- Severity: Medium
- Affected behavior: B-06
- Affected invariant: I-08
- Affected component: `confirm_and_run_workflow`
- Failure scenario: Generated code captures `$?` inside `if ! change-workflow.sh; then`; because `!` inverts the status, it records zero and reports success after a failed driver.
- Evidence: Both scripts use `set -euo pipefail` at line 2, and CHANGE_PLAN §20 explicitly prescribes driver invocation via `if ! …; then` without specifying safe status capture.
- Why current tests may miss it: No planned automated test makes the driver return a distinctive nonzero status and checks propagation.
- Recommended correction: Capture status using `status=0; command || status=$?`, then branch on and return that stored value.
- Proposed verification: Run against stubs returning 1, 7, and 130; assert no close attempt and exact status propagation.
- Blocks implementation: No

- Blocking findings: AR-001, AR-002, AR-003, AR-004, AR-005, AR-006, and AR-007.
- Regression risks: Wrong-issue closure, stale-audit closure, broken resumability, overwritten human edits, non-TTY behavior drift, and masked driver failures.
- Recommended simplifications: Refuse auto-run when existing state lacks matching origin metadata, serialize runs, parse only an exact final verdict line, and defer live closing until the hermetic close-gating path passes.
- Required test additions: Stale-state matrix, stale-output test, concurrent-run interleaving, pause/resume coverage, malformed-verdict fixtures, non-TTY contract checks, stubbed GitHub close integration, and nonzero-status propagation.
- Overall assessment: NOT READY; the run ID does not establish that the verdict belongs to the current issue, and the plan can irreversibly close the wrong issue.