## AR-001: Standalone runs can close the wrong issue from stale origin state

- Severity: Critical
- Affected behavior: BEH-D
- Affected invariant: INV-1 and INV-3
- Affected component: `scripts/change-workflow.sh` direct-run completion path
- Failure scenario: After issue A leaves `.workflow/origin` behind, an operator clears only `.workflow/state`, creates a request for issue B, and runs the driver directly; the planned audit records run id `-` and closes issue A using the stale origin.
- Evidence: Current standalone preflight returns immediately without `STAGEGATE_ORIGIN_*` (`scripts/change-workflow.sh:191-198`), `write_origin` also does nothing (`:220-223`), while CHANGE_PLAN §1/§4 explicitly lets direct runs close from `.workflow/origin`.
- Why current tests may miss it: `direct-run-closes` deliberately supplies an origin and expects closure without proving that origin belongs to the current `CHANGE_REQUEST.md`, thereby validating the unsafe behavior.
- Recommended correction: Require durable close intent freshly created by `from-issue.sh` or an explicit standalone identity plus request binding; never infer close authority from an arbitrary leftover `.workflow/origin`.
- Proposed verification: Start with stale origin A, absent state, and a request for B; complete a direct READY run and assert that neither issue is closed without fresh explicit close authority.
- Blocks implementation: Yes

## AR-002: A transient close failure becomes permanently terminal

- Severity: High
- Affected behavior: BEH-D
- Affected invariant: The originating issue is closed when an eligible workflow completes
- Affected component: `scripts/change-workflow.sh` `FINAL_AUDIT`/`COMPLETE`
- Failure scenario: `gh issue close` fails once, the driver writes `COMPLETE` and exits 0, and every later direct rerun skips closing because `VERDICT_WRITTEN_THIS_RUN` is no longer set.
- Evidence: CHANGE_PLAN §7 and §12 prescribe `COMPLETE` plus exit 0 on close failure, while §1 requires the in-process flag before any close attempt.
- Why current tests may miss it: `direct-run-close-fails-still-completes` blesses the terminal failure but no test retries the completed run.
- Recommended correction: Persist a pending close intent and retry it safely from `COMPLETE`, or represent close failure as a retryable state/nonzero outcome rather than irreversible success.
- Proposed verification: Fail the first close, rerun with healthy `gh`, and assert exactly one eventual successful close with matching run, origin, and audit hash.
- Blocks implementation: Yes

## AR-003: Driver-side closing bypasses the curl-fallback safeguard

- Severity: High
- Affected behavior: BEH-D and backward compatibility of B-9
- Affected invariant: An unauthenticated issue fetch must not authorize a GitHub write
- Affected component: `scripts/from-issue.sh`, `scripts/lib/issue-close.sh`, `scripts/change-workflow.sh`
- Failure scenario: `gh issue view` fails, the issue is fetched with curl, but `gh auth status` and `gh issue close` later succeed; the driver closes an issue that current behavior promises to leave open.
- Evidence: `USED_GH` is local and unexported (`scripts/from-issue.sh:308-319`), only run/origin variables reach the driver (`:115-118`), and the planned driver gate checks live `gh` availability rather than authenticated-fetch provenance.
- Why current tests may miss it: Existing `curl-fallback-skips-close` uses the fake driver, while the proposed direct-driver cases do not traverse the curl path.
- Recommended correction: Persist and pass authenticated close eligibility as part of the close-intent record; the driver must fail closed when that provenance is absent.
- Proposed verification: Use `from-issue.sh` with curl-selected fetch and the real stubbed driver, make later auth/close commands succeed, and assert no close or marker.
- Blocks implementation: Yes

## AR-004: The issue prefix is discarded precisely where mismatch detection is required

- Severity: High
- Affected behavior: BEH-B and BEH-C
- Affected invariant: State belonging to another issue must not be resumed
- Affected component: `scripts/lib/state.sh`, `scripts/from-issue.sh`, `scripts/change-workflow.sh`
- Failure scenario: State contains `99:IMPLEMENT` while origin names `owner/repo	42`; invoking issue 42 strips `99:`, accepts the matching origin, and resumes the contradictory state.
- Evidence: CHANGE_PLAN §1/§6 declares the state issue informational and never used for decisions; planned `state_issue` has no enforcement caller.
- Why current tests may miss it: `seed-gate-prefixed-inflight-refuses` also supplies a foreign origin, so origin mismatch alone makes it pass; no case uses a mismatched prefix with a matching origin.
- Recommended correction: Treat prefix/origin disagreement as corruption and refuse without mutation; keep origin authoritative but require redundant identities to agree.
- Proposed verification: Cover prefix 99 plus origin 42 for both seeder and driver, asserting refusal, unchanged state, no stage execution, and no close.
- Blocks implementation: Yes

## AR-005: The headline model requirement remains unresolved and untested

- Severity: High
- Affected behavior: BEH-A
- Affected invariant: The implemented change must satisfy an approved model/CLI target
- Affected component: Model defaults and agent command configuration
- Failure scenario: B/C/D ship while every workflow continues using the current Sonnet/Opus and Claude defaults, delivering none of the requested Kimi cost reduction or “everything opus” behavior.
- Evidence: CHANGE_REQUEST.md contradicts itself, CHANGE_SPEC §4 marks A unresolved, and CHANGE_PLAN explicitly excludes all model/default edits and tests.
- Why current tests may miss it: Neither existing suite nor the proposed additions inspect resolved commands, models, flags, or wrapper compatibility.
- Recommended correction: Obtain a human choice and compatibility contract before approving this plan, or split A into a separately blocked change and explicitly declare the present delivery partial.
- Proposed verification: After resolution, stub the agent command and assert every stage’s exact executable, model, and flags under defaults and overrides.
- Blocks implementation: Yes

## AR-006: The plan substitutes refusal for an explicit reset request without approved evidence

- Severity: High
- Affected behavior: BEH-C
- Affected invariant: Requirements may only be changed with explicit approval
- Affected component: CHANGE_SPEC and `scripts/from-issue.sh`
- Failure scenario: A user invokes a different issue expecting the requested automatic reset and continuation, but receives exit 1 and must manually mutate workflow state.
- Evidence: CHANGE_REQUEST.md explicitly requests zeroing; CHANGE_SPEC rejects it, while BASELINE_REPORT’s cited `UPDATED_CHANGE_PLAN.md:53` discusses lock interleaving, not a deliberate prohibition on state reset, and its lock-versus-state distinction actually appears at `UPDATED_CHANGE_PLAN.md:164`.
- Why current tests may miss it: Proposed tests assert the substituted refusal behavior rather than the requested observable outcome.
- Recommended correction: Obtain explicit approval for refusal-plus-guidance; if reset is selected, define a lock-aware atomic reset of the complete coherent run state, not just the state file.
- Proposed verification: Test the approved policy against live-lock, stale-lock, foreign-origin, unowned-state, approval, and partial-artifact cases.
- Blocks implementation: Yes

## AR-007: The claimed single-writer guarantee excludes the other production driver

- Severity: High
- Affected behavior: BEH-B and BEH-D
- Affected invariant: INV-2 and INV-3
- Affected component: `scripts/change-workflow.sh`, `scripts/stagegate.sh`, shared `.workflow/state`, and `FINAL_AUDIT.md`
- Failure scenario: `stagegate.sh`, which takes no lock, overwrites shared state or `FINAL_AUDIT.md` while change-workflow validates and closes; mutation before hashing suppresses closure, while mutation after hashing violates the audit-content check at close time.
- Evidence: The change driver alone acquires `.workflow/lock` (`scripts/change-workflow.sh:598`), whereas `stagegate.sh:496-615` reads/writes the same state and audit artifact without consulting that lock.
- Why current tests may miss it: All proposed tests are serial and no automated suite exercises `stagegate.sh`.
- Recommended correction: Either make the lock cover every shared-artifact writer or separate the drivers’ state/artifact namespaces; do not claim the existing mutex makes `.workflow` single-writer.
- Proposed verification: Pause change-workflow immediately before close, run stagegate through state and audit writes, then assert deterministic refusal and no close under either interleaving.
- Blocks implementation: Yes

## AR-008: The network call can hold the workflow mutex indefinitely

- Severity: Medium
- Affected behavior: BEH-D
- Affected invariant: Workflow progress and lock recovery remain bounded
- Affected component: `scripts/change-workflow.sh` completion and `.workflow/lock`
- Failure scenario: `gh issue close` hangs on network or credential I/O, leaving the process and checkout lock held indefinitely and blocking every subsequent change run.
- Evidence: CHANGE_PLAN §11 says the call is “bounded by `gh`’s own timeout,” but specifies no timeout, deadline, or evidence for that guarantee.
- Why current tests may miss it: Stubs return immediately; no test models a hung close or verifies cancellation and lock cleanup.
- Recommended correction: Add an explicit portable deadline and durable retry behavior while retaining immutable inputs for the close decision.
- Proposed verification: Use a blocking `gh` stub, assert bounded termination, no close marker, retryable status, and removal of `.workflow/lock`.
- Blocks implementation: No

## AR-009: Stagegate library wiring is unneeded production refactoring without regression coverage

- Severity: Medium
- Affected behavior: Existing new-application workflow
- Affected invariant: Unrelated standalone workflow behavior remains unchanged
- Affected component: `scripts/stagegate.sh` and `scripts/lib/state.sh`
- Failure scenario: A parser, sourcing, packaging, or Bash-compatibility defect prevents the new-application driver from starting even though that driver has no issue identity and produces exactly the same bare state.
- Evidence: CHANGE_PLAN §4 says stagegate’s prefix is empty in practice, §16 supplies no stagegate test, and §21 admits the edit is symmetry-only and can be cut.
- Why current tests may miss it: The complete automated strategy runs only audit-verdict and close-flow suites; neither executes stagegate state transitions.
- Recommended correction: Remove stagegate from this change unless an actual issue-binding requirement is defined; otherwise add a dedicated hermetic state-machine suite before sharing the parser.
- Proposed verification: If retained, exercise every stagegate state, legacy bare-state resume, unknown state, missing library, invocation from another CWD, and Bash 3.2.
- Blocks implementation: No

- Blocking findings: AR-001, AR-002, AR-003, AR-004, AR-005, AR-006, and AR-007.
- Regression risks: Wrong-issue closure, unauthenticated-path closure, unrecoverable close failures, contradictory state resumption, cross-driver artifact races, and new stagegate startup failures.
- Recommended simplifications: Keep closing in an authenticated durable close-intent flow, separate it from generic `.workflow/origin`, reject prefix/origin disagreement, omit stagegate wiring, and split unresolved model policy from the state/close work.
- Required test additions: Stale-origin direct run, matching-origin/mismatched-prefix, curl fetch with the real driver, close-failure retry, concurrent stagegate mutation, hung-`gh` cleanup, and resolved model-command assertions.
- Overall assessment: Reject the plan pending revision; its new irreversible side effect lacks trustworthy standalone identity, durable recovery, authenticated-fetch provenance, and complete concurrency control.