# Manual Verification Checklist

Base checks: 28; resolved: 1; added: 7; removed: 1

Check ID: MC-001
Priority: P0
Behavior classification: MODIFY
Related behavior: BEH-B — issue-bound change-workflow state uses `<issue>:<STAGE>`
Related invariant: INV-1
Preconditions: Disposable checkout; authenticated issue binding for issue 42; workflow positioned immediately before a stage transition
Exact action: Run `change-workflow.sh` through one transition, then inspect `.workflow/state`; repeat through completion
Expected result: Each written state is `42:<STAGE>`; stage names and order remain `ANALYZE → PLAN → UPDATED_PLAN → IMPLEMENT → CHECKLIST → EXECUTE_CHECKLIST → FINAL_AUDIT → COMPLETE`
Evidence to capture: Commands, exit codes, and state contents after each transition
Actual result:
Status: NOT RUN

Check ID: MC-002
Priority: P0
Behavior classification: MODIFY / BACKWARD COMPATIBILITY
Related behavior: BEH-B — tolerant reading of legacy bare state
Related invariant: INV-1
Preconditions: Disposable checkout with a valid matching origin; reusable fixtures for each legacy bare stage token
Exact action: Before separate driver invocations, write each bare stage token from `ANALYZE` through `COMPLETE` to `.workflow/state` and resume the workflow
Expected result: Every valid bare token is accepted and dispatches the corresponding stage; bare `FINAL_AUDIT` can complete; bare `COMPLETE` exits normally; subsequent issue-bound writes may use the prefixed format
Evidence to capture: Initial state, invoked command, stage-dispatch output, exit code, and resulting state for each token
Actual result:
Status: NOT RUN

Check ID: MC-003
Priority: P1
Behavior classification: MODIFY / BOUNDARY
Related behavior: BEH-B — conditional state prefix and strict grammar
Related invariant: INV-1
Preconditions: Disposable checkout with no origin file and no `STAGEGATE_ORIGIN_*` variables
Exact action: Run a state transition, inspect `.workflow/state`, then separately attempt to resume from `abc:IMPLEMENT`
Expected result: With no resolvable issue, the driver writes a bare stage token; the nonnumeric prefix is rejected as an unknown workflow state with exit 1 and no stage execution
Evidence to capture: Environment, state before and after, stdout/stderr, and exit codes
Actual result:
Status: NOT RUN

Check ID: MC-004
Priority: P0
Behavior classification: MODIFY / SECURITY
Related behavior: BEH-B — state-prefix/origin corruption detection
Related invariant: INV-1, INV-3
Preconditions: `.workflow/state` contains `99:IMPLEMENT`; `.workflow/origin` identifies issue 42 with valid `gh` provenance
Exact action: Invoke `from-issue.sh --change` for issue 42; restore the fixture and invoke `change-workflow.sh` with explicit issue-42 binding
Expected result: Both entry points refuse with exit 1 and the distinct prefix/origin-corruption message; state remains exactly `99:IMPLEMENT`; no stage runs, issue close, or close marker occurs
Evidence to capture: Both commands and exit codes, exact messages, before/after state hashes, stage-call log, GitHub-call log, and marker absence
Actual result:
Status: NOT RUN

Check ID: MC-005
Priority: P0
Behavior classification: PRESERVE
Related behavior: BEH-C — foreign or unowned in-flight state is refused, not automatically cleared
Related invariant: INV-1, INV-5
Preconditions: Nonempty, non-`COMPLETE` state owned by another issue; second fixture with in-flight state and missing origin
Exact action: Invoke `from-issue.sh --change` for a different issue against each fixture
Expected result: Each invocation exits 1, leaves state and existing artifacts untouched, does not seed or run the workflow, and prints the exact manual state-clear command
Evidence to capture: Commands, exit codes, exact refusal and guidance text, before/after hashes, and absence of seed/stage calls
Actual result:
Status: NOT RUN

Check ID: MC-006
Priority: P1
Behavior classification: MODIFY / REGRESSION
Related behavior: BEH-B — prefixed `COMPLETE` is recognized by both completion gates
Related invariant: INV-1
Preconditions: Seeder fixture with `42:COMPLETE`; driver fixture with `42:COMPLETE`, valid origin, and explicit matching binding
Exact action: Run the seeder for issue 42 and confirm reseeding is permitted; separately run the driver preflight against the completed state
Expected result: The seeder does not misclassify `42:COMPLETE` as in-flight; driver preflight does not reject it as a foreign active run
Evidence to capture: Commands, exit codes, seed-write evidence, and exact output
Actual result:
Status: NOT RUN

Check ID: MC-007
Priority: P0
Behavior classification: MODIFY / SECURITY
Related behavior: BEH-D — direct driver closes an eligible issue at `COMPLETE`
Related invariant: INV-3
Preconditions: Disposable open GitHub issue fetched through authenticated `gh`; explicit matching `STAGEGATE_ORIGIN_REPO`, `STAGEGATE_ORIGIN_ISSUE`, and concrete `STAGEGATE_RUN_ID`; READY audit with matching verdict record and audit hash; closing enabled
Exact action: Run `change-workflow.sh` directly through `COMPLETE`, without `from-issue.sh`
Expected result: Exactly one close targets the bound issue before process exit; exit code is 0; `.workflow/issue-closed` records the matching run and issue; the workflow reports completion
Evidence to capture: Environment, command and exit code, issue event/history, GitHub-call log, verdict/origin/audit hashes, marker contents, and terminal output
Actual result:
Status: NOT RUN

Check ID: MC-008
Priority: P0
Behavior classification: MODIFY / SECURITY
Related behavior: BEH-D — READY_WITH_NON_BLOCKING_ISSUES is close-eligible under the same gate
Related invariant: INV-3
Preconditions: Same as MC-007 except the audit verdict is READY_WITH_NON_BLOCKING_ISSUES
Exact action: Run `change-workflow.sh` directly through `COMPLETE`
Expected result: Exactly one close targets the bound issue; the matching close marker is written; exit code is 0
Evidence to capture: Verdict record, audit hash, GitHub-call log, marker contents, issue state, and exit code
Actual result:
Status: NOT RUN

Check ID: MC-009
Priority: P0
Behavior classification: PRESERVE / SECURITY
Related behavior: BEH-D — ineligible completion must not close
Related invariant: INV-3
Preconditions: Independent fixtures varying one condition at a time: non-READY verdict; missing origin; unauthenticated `gh`; mismatched run ID; mismatched origin; stale audit hash; `WORKFLOW_CLOSE_ISSUE=0`
Exact action: Run the direct driver to `COMPLETE` for each fixture
Expected result: Every run exits 0 and completes locally without a close attempt or marker; each applicable skip reason identifies the failed gate; no issue other than the fixture target is modified
Evidence to capture: Condition matrix, commands, exit codes, stdout/stderr, GitHub-call logs, issue states, and marker absence
Actual result:
Status: NOT RUN

Check ID: MC-010
Priority: P0
Behavior classification: MODIFY / SECURITY
Related behavior: BEH-D — stale on-disk origin cannot authorize a fresh direct run
Related invariant: INV-1, INV-3
Preconditions: Empty state at process start; leftover authenticated-looking origin for issue A; READY result; no explicit `STAGEGATE_ORIGIN_*`
Exact action: Start a fresh direct `change-workflow.sh` run and allow it to reach `COMPLETE`
Expected result: The workflow exits 0 but closes neither issue A nor any other issue; no marker is written; a distinct origin-freshness skip reason is printed
Evidence to capture: Sanitized environment, initial state/origin, command and exit code, exact reason, GitHub-call log, issue states, and marker absence
Actual result:
Status: NOT RUN

Check ID: MC-011
Priority: P0
Behavior classification: MODIFY / BOUNDARY
Related behavior: BEH-D — explicit invocation binding authorizes a fresh direct run
Related invariant: INV-1, INV-3
Preconditions: Empty state at process start; matching `STAGEGATE_ORIGIN_REPO` and `STAGEGATE_ORIGIN_ISSUE` explicitly set; concrete matching run ID; authenticated `gh` provenance; eligible verdict
Exact action: Run `change-workflow.sh` directly through `COMPLETE`
Expected result: Explicit fresh binding satisfies the freshness guard and exactly one close occurs for the bound issue
Evidence to capture: Initial state, explicit environment, origin/verdict records, GitHub-call log, marker, issue state, and exit code
Actual result:
Status: NOT RUN

Check ID: MC-012
Priority: P0
Behavior classification: ADD / SECURITY / MIGRATION
Related behavior: BEH-D — close authority requires authenticated-fetch provenance
Related invariant: INV-3
Preconditions: Three independent origin fixtures: third field `gh`; third field `curl`; legacy two-field origin with no provenance; otherwise identical eligible READY completion and healthy authenticated `gh` at close time
Exact action: Run the direct driver to `COMPLETE` for each fixture
Expected result: The `gh` fixture may close when all other gates pass; `curl` and legacy fixtures exit 0 without a close or marker and print the provenance skip reason
Evidence to capture: Raw origin files, commands, exit codes, exact reasons, GitHub-call logs, marker state, and issue states
Actual result:
Status: NOT RUN

Check ID: MC-013
Priority: P0
Behavior classification: PRESERVE / SECURITY
Related behavior: BEH-D — curl fallback never authorizes a later GitHub write
Related invariant: INV-3
Preconditions: Disposable issue; force `from-issue.sh` to fetch through curl while permitting later `gh auth status` and `gh issue close` calls to succeed
Exact action: Seed and run the real workflow path to an eligible READY completion
Expected result: Origin records `curl`; neither the driver nor the wrapper closes the issue; no marker is created; local workflow completion remains successful
Evidence to capture: Fetch-path log, origin contents, driver/wrapper output and exit codes, GitHub-call log, marker absence, and final issue state
Actual result:
Status: NOT RUN

Check ID: MC-014
Priority: P0
Behavior classification: ADD / FAILURE AND RECOVERY / RESTART
Related behavior: BEH-D — transient close failure is retryable from `COMPLETE`
Related invariant: INV-3
Preconditions: Eligible concrete run ID; first close configured to fail; marker absent; verdict, origin, and audit remain unchanged; second invocation uses the same explicit run ID with healthy `gh`
Exact action: Complete the first run, then rerun from `COMPLETE`
Expected result: First invocation warns, writes no marker, leaves state `COMPLETE`, releases the lock, and exits 0; second invocation performs one successful close, writes the matching marker, and exits 0; total successful closes equal one
Evidence to capture: Both commands and exit codes, state after each run, warnings, GitHub-call log, marker contents, issue history, and lock state
Actual result:
Status: NOT RUN

Check ID: MC-015
Priority: P0
Behavior classification: ADD / RESTART / SECURITY
Related behavior: BEH-D — ambiguous sentinel run IDs never trigger retry
Related invariant: INV-3
Preconditions: State is `COMPLETE`; marker absent; verdict record run ID is `-`; `STAGEGATE_RUN_ID` is unset; all other close inputs appear eligible
Exact action: Rerun `change-workflow.sh`
Expected result: No retry or close attempt occurs, no marker is written, issue remains open, and the driver exits 0
Evidence to capture: Sanitized environment, verdict record, command and exit code, GitHub-call log, marker absence, and issue state
Actual result:
Status: NOT RUN

Check ID: MC-016
Priority: P0
Behavior classification: ADD / IDEMPOTENCY
Related behavior: BEH-D — driver and wrapper do not double-close
Related invariant: INV-3
Preconditions: `from-issue.sh`-launched eligible run in which the driver successfully closes the issue and writes a matching marker
Exact action: Allow control to return to `from-issue.sh` after driver completion
Expected result: The wrapper recognizes the marker and does not issue a second close; exactly one close exists in the GitHub-call log
Evidence to capture: Driver and wrapper output, marker contents, GitHub-call log, issue history, and final exit code
Actual result:
Status: NOT RUN

Check ID: MC-017
Priority: P0
Behavior classification: PRESERVE / SECURITY
Related behavior: BEH-D — stale marker cannot suppress a legitimate gated close
Related invariant: INV-3
Preconditions: Eligible wrapper close with a marker naming a different run or issue
Exact action: Complete the workflow through `from-issue.sh`
Expected result: The stale marker is ignored; the normal gated close executes exactly once for the current issue; resulting durable evidence identifies the current run and issue
Evidence to capture: Stale marker before execution, GitHub-call log, current marker after execution, issue history, and exit code
Actual result:
Status: NOT RUN

Check ID: MC-018
Priority: P1
Behavior classification: ADD / FAILURE AND RECOVERY / PERFORMANCE
Related behavior: BEH-D — close call uses a best-effort bounded deadline
Related invariant: INV-2, INV-3
Preconditions: Environment with `timeout` or `gtimeout`; eligible completion; `gh issue close` stub blocks longer than 30 seconds
Exact action: Run the driver to `COMPLETE` and measure elapsed time
Expected result: Close is terminated at approximately the specified 30-second deadline; warning is printed; no marker is written; state remains `COMPLETE`; driver exits 0 and releases `.workflow/lock/`; later retry remains possible
Evidence to capture: Timeout utility selected, timestamps, elapsed time, stdout/stderr, exit code, state, marker absence, and lock absence
Actual result:
Status: NOT RUN

Check ID: MC-019
Priority: P1
Behavior classification: ADD / PORTABILITY
Related behavior: BEH-D — disclosed timeout fallback when no timeout utility exists
Related invariant: INV-2
Preconditions: Disposable checkout; otherwise eligible completion; controlled `gh` stub that writes an invocation marker and then waits for input; isolated `PATH` containing required shell utilities and the stub but neither `timeout` nor `gtimeout`; external harness deadline of 5 seconds
Exact action: Confirm `command -v timeout` and `command -v gtimeout` both fail inside the isolated environment, start `change-workflow.sh` in a new process group, wait for the `gh` invocation marker, then after 5 seconds terminate the process group and inspect output and artifacts; the exercised branch is `scripts/lib/issue-close.sh:196-203`
Expected result: `gh issue close` is invoked directly without a timeout wrapper; no 30-second-deadline message is printed; before harness termination no close marker is written and `.workflow/lock/` remains held because the unbounded close has not returned; harness termination triggers driver cleanup and removes `.workflow/lock/`
Evidence to capture: Isolated `PATH`, utility lookup output, platform/version, harness command and timestamps, process tree, workflow output, invocation marker, close-marker absence, and lock state before and after termination
Actual result:
Status: NOT RUN

Check ID: MC-020
Priority: P0
Behavior classification: PRESERVE / FAILURE
Related behavior: BEH-E — lock cleanup remains unchanged
Related invariant: INV-2
Preconditions: Independent runs covering successful completion, ordinary close failure, timeout, stage error, and interrupt signal
Exact action: Execute each exit path and inspect `.workflow/lock/` immediately after the process exits
Expected result: The entire `.workflow/lock/` directory and all contents are absent after every driver-controlled exit
Evidence to capture: Commands, exit conditions, exit codes, and post-exit filesystem listing for every path
Actual result:
Status: NOT RUN

Check ID: MC-021
Priority: P0
Behavior classification: PRESERVE / CONCURRENCY
Related behavior: BEH-E — existing single-change-workflow locking behavior
Related invariant: INV-2
Preconditions: One fixture with a live lock-holder PID; another with a stale PID
Exact action: Start a second driver against the live lock, then separately start a driver against the stale lock
Expected result: Live lock prevents concurrent ownership; stale lock is recovered according to existing behavior; neither path weakens lock cleanup
Evidence to capture: Process/PID evidence, commands, output, exit codes, and lock contents before and after
Actual result:
Status: NOT RUN

Check ID: MC-022
Priority: P1
Behavior classification: PRESERVE / REGRESSION
Related behavior: Existing approval integrity and audit-verdict classification
Related invariant: INV-4, INV-3
Preconditions: Approved artifact fixture; separate audit-verdict classification fixtures
Exact action: Mutate an approved artifact after approval and attempt to continue; run the unchanged audit-verdict suite
Expected result: Mutated artifact is rejected pending reapproval; all established verdict classes retain their prior classifications
Evidence to capture: Approval and artifact hashes, rejection output and exit code, and complete audit-verdict suite transcript
Actual result:
Status: NOT RUN

Check ID: MC-024
Priority: P0
Behavior classification: REGRESSION / SCOPE
Related behavior: Frozen change scope and representative PRESERVE behaviors
Related invariant: INV-1, INV-2, INV-4, INV-5
Preconditions: Completed implementation available for review
Exact action: Compare the implementation against the approved baseline and confirm that every must-not-change file and setting is unchanged
Expected result: No changes exist in `scripts/stagegate.sh`, `scripts/workflow.sh`, `scripts/lib/audit-verdict.sh`, `scripts/codex-review-plan.sh`, `scripts/codex-create-checklist.sh`, `prompts/**`, `CHANGE_REQUEST.md`, `QUICK_START.md`, model/effort/turn/tool defaults, agent/reviewer command defaults, cost ledger, lock implementation, `verify_approval`, `scripts/tests/audit-verdict-test.sh`, or reviewer-owned artifacts
Evidence to capture: Path-limited diff, configuration-default comparison, and reviewer sign-off
Actual result:
Status: NOT RUN

Check ID: MC-025
Priority: P1
Behavior classification: MODIFY / OBSERVABILITY
Related behavior: BEH-C and BEH-D — distinct actionable outcome messages and durable close evidence
Related invariant: INV-3, INV-5
Preconditions: Fixtures triggering freshness skip, provenance skip, prefix/origin refusal, close timeout/failure, successful close, and foreign-state refusal
Exact action: Execute each fixture and compare its output and durable artifacts
Expected result: Each new condition has a distinct message; no pre-existing asserted message is reworded; successful close creates a run/issue-specific marker; skipped or failed closes do not
Evidence to capture: Message matrix, marker contents or absence, and comparison with approved pre-existing strings
Actual result:
Status: NOT RUN

Check ID: MC-026
Priority: P1
Behavior classification: MODIFY / DOCUMENTATION / MIGRATION
Related behavior: BEH-B and BEH-D interface changes
Related invariant: INV-1, INV-3
Preconditions: Updated user documentation available
Exact action: Follow documentation to create and resume both `<issue>:<STAGE>` and legacy bare state; inspect documentation for origin provenance, driver-side closing, marker, kill switch, retry, skip guards, and manual-clear guidance
Expected result: Documented commands reproduce supported behavior; README files describe the new state and origin grammars and close flow; `QUICK_START.md` remains correct without modification because bare stage tokens remain valid
Evidence to capture: Documentation excerpts, commands followed, resulting state/origin files, and observed outcomes
Actual result:
Status: NOT RUN

Check ID: MC-027
Priority: P1
Behavior classification: ROLLBACK
Related behavior: BEH-B and BEH-D rollback expectations
Related invariant: INV-1, INV-3
Preconditions: Reversible test deployment containing a prefixed state; disposable issue; ability to disable closing and restore the prior release
Exact action: Set `WORKFLOW_CLOSE_ISSUE=0` and verify immediate containment; restore the prior release; replace any remaining prefixed state with its documented bare equivalent; resume through the legacy wrapper path
Expected result: Kill switch prevents driver-side closing; prior release resumes from the rewritten bare state; legacy `from-issue.sh` close behavior remains available; no automatic reversal of an already-closed issue is attempted
Evidence to capture: Configuration, commands, state before/after rewrite, driver/wrapper logs, issue history, and rollback outcome
Actual result:
Status: NOT RUN

Check ID: MC-028
Priority: P1
Behavior classification: PRESERVE / PROTOTYPE ISOLATION
Related behavior: BEH-A remains unresolved and outside this delivery
Related invariant: Frozen scope
Preconditions: Completed implementation and completion report available
Exact action: Inspect configuration behavior and the completion report for model-related changes or claims
Expected result: Model, effort, turn, tool, `AGENT_CMD`, and `REVIEWER_CMD` defaults remain unchanged; no Kimi wrapper or compatibility claim is introduced; the report explicitly states that CR Motivation-A is not delivered and remains open
Evidence to capture: Defaults comparison and completion-report excerpt
Actual result:
Status: NOT RUN

Check ID: MC-029
Priority: P1
Behavior classification: REGRESSION / AUTOMATED
Related behavior: BEH-B, BEH-C, BEH-D, BEH-E and accepted AR-001/002/003/004/008 guards
Related invariant: INV-1, INV-2, INV-3, INV-5
Preconditions: Clean shell with ambient `STAGEGATE_ORIGIN_REPO`, `STAGEGATE_ORIGIN_ISSUE`, and `STAGEGATE_RUN_ID` sanitized
Exact action: Run `bash scripts/tests/close-flow-test.sh` and `bash scripts/tests/audit-verdict-test.sh`
Expected result: Close-flow reports 181 checks and audit-verdict reports 26 checks, for 207 checks total with no failures; pre-existing asserted output strings remain unchanged as reconciled in `CHANGE_TEST_REPORT.md:87-94`
Evidence to capture: Sanitized environment, exact commands, complete transcripts, exit codes, and reported counts
Actual result:
Status: NOT RUN

Check ID: MC-030
Priority: P1
Behavior classification: REGRESSION / STATIC ANALYSIS
Related behavior: All changed Bash entry points and shared libraries
Related invariant: INV-1, INV-2, INV-3, INV-5
Preconditions: `shellcheck` installed; repository configuration unchanged; changed Bash files identified from `.workflow/change.diff`
Exact action: Run `shellcheck scripts/change-workflow.sh scripts/from-issue.sh scripts/lib/state.sh scripts/lib/issue-close.sh scripts/tests/close-flow-test.sh`
Expected result: No error-severity findings; every warning or informational finding is reviewed against the affected behavior and either corrected before release or recorded with a specific accepted rationale
Evidence to capture: `shellcheck --version`, exact command, complete diagnostics, exit code, and disposition of each finding
Actual result:
Status: NOT RUN

Check ID: MC-031
Priority: P0
Behavior classification: MODIFY / SECURITY / DEVIATION
Related behavior: Driver origin rewrites preserve authenticated provenance only for the same identity
Related invariant: INV-1, INV-3
Preconditions: Three disposable `ANALYZE` fixtures with explicit issue-42 binding: matching `owner/repo<TAB>42<TAB>gh` origin, matching two-field origin, and `other/repo<TAB>99<TAB>gh` origin
Exact action: Run the driver through its `write_origin` call for each fixture and inspect `.workflow/origin`, then exercise an otherwise eligible close; implementation is at `scripts/change-workflow.sh:242-263`
Expected result: The matching three-field fixture remains `owner/repo<TAB>42<TAB>gh` and can satisfy the provenance gate; the matching two-field fixture remains two-field and fails closed; the foreign fixture becomes `owner/repo<TAB>42` without inheriting `gh` and fails closed
Evidence to capture: Origin bytes before and after, explicit environment, close output, GitHub-call log, marker state, and issue state for each fixture
Actual result:
Status: NOT RUN

Check ID: MC-032
Priority: P0
Behavior classification: MODIFY / IDEMPOTENCY / DEVIATION
Related behavior: Shared close gate writes durable evidence for wrapper fallback closes
Related invariant: INV-3
Preconditions: Eligible `from-issue.sh` run where the driver reaches `COMPLETE` but does not close, the wrapper fallback can close, and no marker exists
Exact action: Let the wrapper fallback close the issue, inspect `.workflow/issue-closed`, then invoke the wrapper fallback again with the same run and issue; marker write is at `scripts/lib/issue-close.sh:214-215`
Expected result: The first wrapper close writes `<run-id><TAB><owner/repo><TAB><issue>` and closes exactly once; the second invocation recognizes the same marker and performs no second close; documentation identifies every path capable of writing the shared-gate marker
Evidence to capture: Driver and wrapper output, marker bytes after each invocation, GitHub-call log, issue history, exit codes, and relevant README excerpts
Actual result:
Status: NOT RUN

Check ID: MC-033
Priority: P1
Behavior classification: ADD / CONFIGURATION / FAILURE
Related behavior: `STAGEGATE_CLOSE_TIMEOUT` controls the close deadline
Related invariant: INV-2, INV-3
Preconditions: Eligible completion; available `timeout` or `gtimeout`; blocking `gh` stub; independent fixtures with `STAGEGATE_CLOSE_TIMEOUT=1`, `0`, `bogus`, and `-1`; external harness deadline
Exact action: Invoke each fixture under the external harness and record the exact command constructed at `scripts/lib/issue-close.sh:196-203`
Expected result: Value `1` terminates the blocking close near one second with the deadline message and no marker; `0` passes zero through to the platform timeout utility and may leave the close unbounded until the harness terminates it; invalid values are rejected by the timeout utility, treated as close failures, and write no marker; every driver-controlled exit releases the lock
Evidence to capture: Timeout utility/version, environment values, elapsed times, stdout/stderr, utility exit codes, GitHub-call log, state, marker state, and lock state
Actual result:
Status: NOT RUN

Check ID: MC-034
Priority: P1
Behavior classification: ADD / INTERFACE / REGRESSION
Related behavior: Test-only source mode can bypass the `from-issue.sh` CLI
Related invariant: Frozen command interface
Preconditions: Disposable checkout; `STAGEGATE_FROM_ISSUE_SOURCE_ONLY` independently unset, `0`, and `1`
Exact action: Invoke `scripts/from-issue.sh --help` and a valid disposable `--change` request under each environment; the early return is at `scripts/from-issue.sh:195-200`
Expected result: Unset and `0` preserve the documented CLI behavior; `1` exits successfully before argument parsing, fetching, seeding, or workflow execution and creates no artifacts; production launch environments do not set this test hook unintentionally
Evidence to capture: Environment, commands, stdout/stderr, exit codes, fetch/stage-call logs, filesystem diff, and deployment-environment inspection
Actual result:
Status: NOT RUN

Check ID: MC-035
Priority: P1
Behavior classification: PRESERVE / CONCURRENCY / UNTESTED
Related behavior: Cross-driver access to shared `.workflow/state` and `FINAL_AUDIT.md`
Related invariant: INV-1, INV-2, INV-3
Preconditions: Disposable checkout; instrumented long-running `stagegate.sh`; second instrumented `change-workflow.sh`; no production issue or GitHub close authority
Exact action: Start `stagegate.sh`, pause it while it owns shared artifacts, then start `change-workflow.sh`; repeat in reverse order and inspect shared state, audit, verdict, origin, and lock artifacts
Expected result: Record whether either driver overwrites or consumes the other driver’s artifacts; no GitHub close occurs; any observed cross-driver corruption or unintended dispatch blocks release or is accepted explicitly as the unresolved AR-007 risk recorded in `IMPLEMENTATION_NOTES.md:61-64`
Evidence to capture: Start order, process/PID timeline, commands, complete outputs, artifact hashes and contents at each event, close-call log, and final cleanup state
Actual result:
Status: NOT RUN

Check ID: MC-036
Priority: P1
Behavior classification: PRESERVE / REGRESSION / UNTESTED
Related behavior: Unmodified `stagegate.sh` workflow remains operational beside the new state grammar
Related invariant: Frozen scope, INV-1
Preconditions: Disposable checkout with the normal `stagegate.sh` prerequisites and no ambient `STAGEGATE_ORIGIN_*` or `STAGEGATE_RUN_ID`
Exact action: Run `stagegate.sh` through one controlled stage transition and resume it once from its written state, then compare its stage dispatch and artifacts with the pre-change behavior
Expected result: The unchanged driver accepts and writes its existing bare stage form, dispatches the same stages, and does not read or create `.workflow/origin`, `.workflow/audit-verdict`, or `.workflow/issue-closed`
Evidence to capture: Sanitized environment, commands, output, exit codes, state before and after, artifact listing, and comparison with the prior release
Actual result:
Status: NOT RUN

Acceptance-criteria traceability:
AC-B issue-prefixed state and compatible readers: MC-001, MC-002, MC-003, MC-004, MC-006, MC-026, MC-029
AC-C refuse-not-zero with manual guidance: MC-005, MC-025
AC-D eligible direct completion closes; ineligible completion does not: MC-007 through MC-019, MC-025, MC-031, MC-032, MC-033
AC-E lock removal after every controlled exit: MC-014, MC-018, MC-019, MC-020, MC-021, MC-033
AC automated pass bar and unchanged audit suite: MC-029, MC-030
AC frozen-scope diff: MC-024, MC-028, MC-034, MC-036
AC partial-delivery disclosure for Motivation-A: MC-028

Preserved-behavior coverage:
BEH-C and INV-5 refusal semantics: MC-005
BEH-E lock ownership and cleanup: MC-020, MC-021
Legacy bare-state compatibility and unchanged stage order: MC-001, MC-002, MC-006, MC-036
Existing close skips, wrapper safeguards, and asserted messages: MC-009, MC-013, MC-016, MC-017, MC-025
Approval and verdict behavior: MC-022
Unmodified stagegate, defaults, files, and settings: MC-024, MC-028, MC-035, MC-036

Changed-behavior coverage:
BEH-B state prefix and corruption handling: MC-001 through MC-006
BEH-D driver-side close and strengthened gate: MC-007 through MC-019
Origin provenance schema and legacy migration: MC-012, MC-013, MC-026, MC-031
Retry, marker idempotency, and timeout behavior: MC-014 through MC-019, MC-032, MC-033
New observability and interfaces: MC-025, MC-034

Invariant coverage:
INV-1 origin-bound resume and state consistency: MC-001 through MC-006, MC-010 through MC-013, MC-031, MC-035, MC-036
INV-2 single writer and lock recovery: MC-018 through MC-021, MC-033, MC-035
INV-3 close authorization, integrity, provenance, and idempotency: MC-007 through MC-019, MC-022, MC-031, MC-032, MC-033
INV-4 approved-artifact integrity: MC-022
INV-5 no automatic foreign-state deletion: MC-005

Regression coverage:
State parsing and completed-state gates: MC-002, MC-003, MC-004, MC-006, MC-036
Wrong-issue and unauthenticated closure prevention: MC-009, MC-010, MC-012, MC-013, MC-015, MC-031
Close recovery and double-close prevention: MC-014, MC-016, MC-017, MC-032
Lock cleanup and concurrency: MC-018, MC-019, MC-020, MC-021, MC-033, MC-035
Approval, verdict, existing-suite, static-analysis, scope, and CLI regression: MC-022, MC-024, MC-028, MC-029, MC-030, MC-034, MC-036

Removed checks:
MC-023: Removed because its expected `149` close-flow count is provably inapplicable to the completed suite; `CHANGE_TEST_REPORT.md:87-94` reconciles the implemented count as 181 close-flow plus 26 audit-verdict checks. Replaced by MC-029.