# Manual Verification Checklist

Base checks: 15; resolved: 1; added: 3; removed: 0

Check ID: MC-001
Priority: P0
Behavior classification: MODIFY, ADD, PRESERVE
Related behavior: B-1, B-5
Related invariant: I-2, I-6, I-8
Preconditions: Hermetic scratch repository; `change-workflow.sh` can be driven to each real gate: small-track `WAIT_ANALYSIS_APPROVAL` (`ACKNOWLEDGE`, four files), full-track `WAIT_ANALYSIS_APPROVAL` (`APPROVE`, two files), `WAIT_PLAN_APPROVAL` (`ACKNOWLEDGE`, two files), and `WAIT_UPDATED_PLAN_APPROVAL` (`APPROVE`, one file); gated files have distinct known contents.
Exact action: At each gate, submit the preliminary ENTER followed by `y`; repeat with `Y`; inspect the prompt, exit status, workflow state, and every approval record.
Expected result: Exactly one Y/N question names every gated filename, uses the lowercased actual action rather than inferring it from file count, and ends `[Y/N]`; `y` and `Y` accept, advance normally, and write each captured pre-prompt SHA-256 digest to the correctly mapped `.workflow/approvals/<name>.sha256` file.
Evidence to capture: Complete stdout bytes; exit status; before/after state; independent `shasum -a 256` results; approval paths and contents; file-to-approval-name mapping.
Actual result:
Status: NOT RUN

Check ID: MC-002
Priority: P0
Behavior classification: MODIFY, REMOVE, PRESERVE
Related behavior: B-1, B-7, B-8
Related invariant: I-5, I-6
Preconditions: Hermetic scratch repository positioned at representative single-file and multi-file `change-workflow.sh` gates; no approval records exist.
Exact action: In separate clean runs submit `n`, `N`, `foo`, an empty line, `APPROVE`, `ACKNOWLEDGE`, ` y`, EOF at the Y/N read, and immediate closed stdin at the preliminary read.
Expected result: Every input declines with exit 0, leaves workflow state paused, creates no approval record, and does not advance downstream work; legacy words additionally emit explicit guidance that `y` is now required; old exact-word prompt text is absent; immediate EOF follows the normal decline path.
Evidence to capture: Input fixture, stdout/stderr, exit status, state before/after, approval-directory listing, and proof no downstream command ran.
Actual result:
Status: NOT RUN

Check ID: MC-003
Priority: P0
Behavior classification: MODIFY, ADD, PRESERVE
Related behavior: B-2, B-5
Related invariant: I-2, I-6, I-8
Preconditions: Hermetic scratch application; `stagegate.sh` can be driven independently to `WAIT_REQUIREMENTS_APPROVAL`, `WAIT_PLAN_APPROVAL`, `WAIT_REVIEW_ACKNOWLEDGEMENT`, and `WAIT_UPDATED_PLAN_APPROVAL`; each gated file has known contents.
Exact action: At every gate submit the preliminary ENTER followed by `y`; repeat the matrix with `Y`; inspect the displayed verb and filename, state transition, and approval record.
Expected result: The Y/N question uses the lowercased configured wording, names the actual file, ends `[Y/N]`, and accepts both `y` and `Y`; normal processing continues and the approval file contains exactly the captured digest for the displayed file.
Evidence to capture: Complete stdout bytes; exit status; before/after state; independent file digest; approval path and content.
Actual result:
Status: NOT RUN

Check ID: MC-004
Priority: P0
Behavior classification: MODIFY, REMOVE, PRESERVE
Related behavior: B-2, B-7, B-8
Related invariant: I-3, I-5, I-6
Preconditions: Hermetic scratch application positioned at a representative `stagegate.sh` approval gate; no approval record exists.
Exact action: In separate clean runs submit `n`, `N`, `foo`, an empty line, `APPROVE`, `ACKNOWLEDGE`, ` y`, EOF at the Y/N read, and immediate closed stdin at the preliminary read.
Expected result: Every input declines with exit 0, leaves the workflow paused, creates no approval record, and does not advance downstream work; legacy words emit the explicit `y` migration guidance; old exact-word prompt text is absent; immediate EOF does not escape through `set -e` with exit 1.
Evidence to capture: Inputs, stdout/stderr, exit statuses, before/after state, approval-directory listing, and downstream-command trace.
Actual result:
Status: NOT RUN

Check ID: MC-005
Priority: P0
Behavior classification: MODIFY, ADD, PRESERVE
Related behavior: B-3, B-5
Related invariant: I-2, I-6, I-8
Preconditions: Scratch checkout containing the expected file for each `workflow.sh` subcommand: `approve-plan`, `approve-review`, and `approve-updated-plan`; files have distinct known contents.
Exact action: Invoke each subcommand with `y`; repeat with `Y`; inspect its prompt, exit status, and approval record.
Expected result: Each command prints a Y/N question naming its actual file and ending `[Y/N]`; `y` and `Y` exit 0 and write the captured pre-prompt SHA-256 digest to the unchanged approval path with the correct name mapping.
Evidence to capture: Command lines, stdout bytes, exit statuses, independent digests, and approval paths and contents.
Actual result:
Status: NOT RUN

Check ID: MC-006
Priority: P0
Behavior classification: MODIFY, REMOVE, PRESERVE
Related behavior: B-3, B-7, B-8
Related invariant: I-4, I-6
Preconditions: Scratch checkout with a valid file for each `workflow.sh approve-*` subcommand and no corresponding approval record.
Exact action: For every subcommand, run separate cases using `n`, `N`, `foo`, an empty line, `APPROVE`, `ACKNOWLEDGE`, ` y`, and EOF.
Expected result: Every case prints `Approval cancelled.`, exits 1, and creates no approval record; legacy words also print explicit guidance to use `y`; exact-word approval prompts are absent and no non-`y`/`Y` value is accepted.
Evidence to capture: Input fixtures, stdout/stderr, exit statuses, and approval-directory listings.
Actual result:
Status: NOT RUN

Check ID: MC-007
Priority: P0
Behavior classification: ADD, PRESERVE
Related behavior: B-5, B-6
Related invariant: I-2, I-3
Preconditions: Synchronizable scratch runs for all three affected gate implementations; each reviewed file begins with a recorded known digest.
Exact action: For `workflow.sh`, feed its response through a FIFO, wait until `Ready to approve` appears, mutate the gated file, then write `y` to the FIFO; for `change-workflow.sh`, run the verbatim extracted `human_gate` with the test suite’s `MUTATE_AFTER_HASH_CALL=1` `shasum`-delegating wrapper; for `stagegate.sh`, run the verbatim extracted `review_and_approve` once with `MUTATE_AFTER_HASH_CALL=1` and responses ENTER/`y`/ENTER/`y`, then once with `MUTATE_AFTER_HASH_CALL=2` and ENTER/`y`, as implemented at `scripts/tests/gate-prompt-test.sh:158-175,236-244,310-327,431-440,533-556`.
Expected result: `change-workflow.sh` and `workflow.sh` decline without an approval record; `stagegate.sh` reopens or declines and cancels stale speculation; no approval record ever validates bytes the operator did not review, and any retained record contains the captured reviewed digest only.
Evidence to capture: FIFO and fault-wrapper command transcript; event timestamps/order; wrapper call count; pre- and post-mutation digests; stdout/stderr; exit status; state; `cancel_speculation` invocation trace; approval paths and contents.
Actual result:
Status: NOT RUN

Check ID: MC-008
Priority: P1
Behavior classification: ADD, PRESERVE
Related behavior: B-1, B-2, B-3, B-5, B-7
Related invariant: I-2, I-7, I-8
Preconditions: One affected gate runnable under a real PTY with normal `TERM`, under a PTY with `TERM=dumb`, and with piped/non-TTY stdout.
Exact action: Capture the prompt byte-for-byte in all three environments while declining safely.
Expected result: Normal PTY output contains `ESC[1m` immediately before the complete Y/N prompt and `ESC[0m` immediately after it; `TERM=dumb` and non-TTY output remain readable and contain no ANSI escape bytes; styling causes no fatal error and no escape bytes enter approval, state, or project log files.
Evidence to capture: Hex or escaped-byte captures for each environment; terminal settings; stdout/stderr; exit statuses; scans of approval, state, and `.workflow/logs` content.
Actual result:
Status: NOT RUN

Check ID: MC-009
Priority: P1
Behavior classification: PRESERVE
Related behavior: B-4
Related invariant: I-1a
Preconditions: Hermetic `from-issue.sh --change` setup equivalent to the established close-flow scenarios.
Exact action: Submit `RUN`, then in separate runs submit `y`, `Y`, `APPROVE`, an empty line, and EOF; run `bash scripts/tests/close-flow-test.sh` without modifying that suite.
Expected result: Only exact `RUN` starts the change workflow; all other inputs decline under the existing contract; the prompt remains `Type RUN exactly to start the change workflow:`; the unchanged suite reports exactly 181 checks passed.
Evidence to capture: Inputs, stdout/stderr, exit statuses, launch/no-launch trace, test command, test output, and proof the test file was unchanged.
Actual result:
Status: NOT RUN

Check ID: MC-010
Priority: P1
Behavior classification: MODIFY, REMOVE
Related behavior: B-9
Related invariant: I-8
Preconditions: Release candidate documentation is available.
Exact action: Review all gate instructions in `README.md`, `QUICK_START.md`, and `scripts/README.md`; search repository documentation for `APPROVE`, `ACKNOWLEDGE`, `exact word`, and `requested word`.
Expected result: User-facing instructions for affected gates describe `y`/`Y` acceptance and non-yes decline, with no stale instruction to type `APPROVE`, `ACKNOWLEDGE`, an exact word, or a requested word; any `RUN` instruction is clearly limited to the preserved `from-issue.sh` gate.
Evidence to capture: Search command and complete hits; relevant documentation excerpts; list of every reviewed gate instruction.
Actual result:
Status: NOT RUN

Check ID: MC-011
Priority: P1
Behavior classification: PRESERVE, REGRESSION
Related behavior: B-4, B-5, B-6, B-8
Related invariant: I-1a, I-2, I-3, I-4, I-5
Preconditions: Release candidate checkout with dependencies required by the repository’s hermetic test suites.
Exact action: Run `bash scripts/tests/gate-prompt-test.sh`, `bash scripts/tests/close-flow-test.sh`, `bash scripts/tests/audit-verdict-test.sh`, `bash scripts/tests/agent-kimi-test.sh`, `bash -n scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh`, and `shellcheck scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh`.
Expected result: The gate suite completes successfully; existing suites remain at 181, 26, and 23 checks respectively; syntax validation succeeds; shellcheck introduces no finding beyond the baseline list; unrelated agent behavior remains unchanged.
Evidence to capture: Exact commands, tool versions, complete outputs, exit statuses, check totals, and shellcheck finding comparison with the baseline.
Actual result:
Status: NOT RUN

Check ID: MC-012
Priority: P1
Behavior classification: PRESERVE, RECOVERY
Related behavior: B-5, B-8
Related invariant: I-2, I-4, I-5, I-6
Preconditions: Each affected workflow is positioned at an approval gate with recorded pre-run state and no approval record.
Exact action: Decline once, terminate the process, restart the same command from persisted state, verify the same gate is presented, then answer `y`; restart once more after acceptance.
Expected result: Decline leaves the workflow resumable at the same gate without a partial approval; the subsequent `y` records the exact reviewed digest and advances once; restarting after acceptance does not repeat or bypass the completed gate, and existing state/origin/audit-verdict/lock formats remain unchanged.
Evidence to capture: State and approval snapshots before and after each run; prompts; exit statuses; digest comparison; resumed stage; state-file format comparison.
Actual result:
Status: NOT RUN

Check ID: MC-013
Priority: P1
Behavior classification: PRESERVE, SECURITY
Related behavior: B-5, B-8
Related invariant: I-2, I-6
Preconditions: Representative affected gates with distinct files and clean approval/state/log storage.
Exact action: Submit values containing leading or trailing spaces, tabs, multiple characters, mixed case (`yes`, `YES`, `y `, ` y`, tab-prefixed `y`), ANSI/control bytes, and shell metacharacters.
Expected result: Only the exact single-character values `y` and `Y` accept; all supplied variants decline under the component’s preserved exit-code contract; input is neither executed nor persisted, no unexpected files are created, and approval/state/log content remains uncorrupted.
Evidence to capture: Byte-precise inputs, stdout/stderr, exit statuses, state changes, filesystem diff, and scans of approval/state/log files.
Actual result:
Status: NOT RUN

Check ID: MC-014
Priority: P2
Behavior classification: PRESERVE, OBSERVABILITY
Related behavior: B-5, B-8
Related invariant: I-2
Preconditions: Comparable baseline and release-candidate scratch runs at one accepted and one declined gate for each affected script.
Exact action: Compare externally visible records other than the intentionally changed prompt and legacy-word guidance, including approval path/format, workflow state, origin, audit verdict, lock handling, spend output, cost ledger, and project logs.
Expected result: No schema, path, logging, spend, cost, lock, origin, or verdict change is present; declined responses produce no approval or state advancement; accepted responses differ only in the specified input/prompt contract and strengthened captured-digest integrity.
Evidence to capture: Before/after file inventories and normalized diffs; log excerpts; approval record format; state-contract comparison.
Actual result:
Status: NOT RUN

Check ID: MC-015
Priority: P2
Behavior classification: ROLLBACK, PRESERVE
Related behavior: B-1, B-2, B-3, B-5, B-9
Related invariant: I-1, I-1a, I-2
Preconditions: Disposable checkout containing the release change as an isolated revertible unit and at least one approval record created before rollback.
Exact action: Revert only the three affected scripts, documentation changes, and new gate test; do not revert unrelated work; invoke representative affected gates and validate the pre-existing approval record.
Expected result: Exact-word `APPROVE`/`ACKNOWLEDGE` prompts and acceptance are restored; the `RUN` gate remains unchanged; existing SHA-256 approval records remain valid without state or data migration; unrelated files and work are untouched.
Evidence to capture: Revert target list, before/after diff, gate transcripts, approval validation result, state snapshot, and unrelated-file status.
Actual result:
Status: NOT RUN

Check ID: MC-016
Priority: P1
Behavior classification: ADD, COMPATIBILITY
Related behavior: B-1, B-2, B-3, B-8
Related invariant: I-4, I-5, I-6
Preconditions: Representative live gate in each affected script; no approval record exists; an exit-status-only wrapper and an output-aware wrapper are available.
Exact action: Through each wrapper submit `APPROVE`, `approve`, `ACKNOWLEDGE`, and `acknowledge`; inspect output, exit status, state, approval records, and whether the wrapper attempts downstream work.
Expected result: Every case declines and prints explicit guidance to use `y`, including the case-insensitive variants introduced by IMPLEMENTATION_NOTES.md:36; `workflow.sh` exits 1; both drivers exit 0 but remain paused with no approval, and the output-aware wrapper detects the decline instead of treating exit 0 as advancement.
Evidence to capture: Wrapper source; exact inputs; stdout/stderr; exit statuses; before/after state; approval-directory listing; downstream-command trace.
Actual result:
Status: NOT RUN

Check ID: MC-017
Priority: P1
Behavior classification: ADD, INTEGRATION, PRESERVE
Related behavior: B-1, B-2, B-5, B-6, B-8
Related invariant: I-2, I-3, I-5
Preconditions: Hermetic end-to-end installations of `change-workflow.sh` and `stagegate.sh` with real gate-driving dependencies or behavior-faithful agent CLI stubs; speculation is active before the `stagegate.sh` edit-race case.
Exact action: Drive each complete driver from startup through one real approval gate, decline and resume once, then accept; at the `stagegate.sh` gate repeat after editing the reviewed file before `y` and inspect the real caller-side `cancel_speculation` effects.
Expected result: Driver preflight, lock/origin handling, state dispatch, prompt, approval recording, and resumption operate together under the preserved contracts; the edited `stagegate.sh` review reopens, invokes the real cancellation path, removes or invalidates stale speculative work as designed, and records no stale approval.
Evidence to capture: Commands and dependency versions; full driver transcripts; state/lock/origin snapshots; gated-file digests; approval records; speculation artifacts before and after cancellation; restart results.
Actual result:
Status: NOT RUN

Check ID: MC-018
Priority: P2
Behavior classification: ADD, SCOPE, REGRESSION
Related behavior: B-4, B-9
Related invariant: I-1a
Preconditions: Release-candidate diff, UPDATED_CHANGE_PLAN.md §23–24 file lists, IMPLEMENTATION_NOTES.md, and the pre-implementation worktree inventory are available.
Exact action: Compare every path in `.workflow/change.diff` and `git status --short` with UPDATED_CHANGE_PLAN.md:298-316; inspect unplanned changes in `ADVERSARIAL_REVIEW.md`, `CHANGE_PLAN.md`, `CHANGE_TEST_REPORT.md`, `IMPLEMENTATION_NOTES.md`, `UPDATED_CHANGE_PLAN.md`, `CLAUDE.md`, `GOOD_FIRST_ISSUES.md`, and `prompts/change/*`; independently diff every §24 must-not-change runtime file and contract.
Expected result: The six implementation paths are exactly those authorized by UPDATED_CHANGE_PLAN.md §23; report/plan artifacts contain only workflow evidence or pre-existing work and introduce no runtime behavior; pre-existing unrelated edits are identified without attribution to this implementation; `scripts/from-issue.sh`, protected tests, agent code, libraries, prompt files attributable to the release, and `.workflow` contracts have no release-caused change.
Evidence to capture: Complete path inventories; per-file diff classification as planned implementation, workflow artifact, or pre-existing unrelated work; before/after hashes for §24 files; discrepancies with IMPLEMENTATION_NOTES.md:16-26 and CHANGE_TEST_REPORT.md:53.
Actual result:
Status: NOT RUN

Acceptance-criteria traceability: Criterion 1 → MC-001, MC-003, MC-005, MC-008; Criterion 2 → MC-001, MC-003, MC-005, MC-007; Criterion 3 → MC-002, MC-004, MC-006, MC-013, MC-016; Criterion 4 → MC-007, MC-017; Criterion 5 → MC-009, MC-011, MC-018; Criterion 6 → MC-010; approval-integrity hardening → MC-007; live-driver and cancellation gaps → MC-017; rollback NOT RUN → MC-015.
Preserved-behavior coverage: B-4 → MC-009, MC-011, MC-018; B-5 → MC-001, MC-003, MC-005, MC-007, MC-012, MC-014, MC-017; B-6 → MC-007, MC-011, MC-017; B-8 → MC-002, MC-004, MC-006, MC-012, MC-013, MC-014, MC-016, MC-017.
Changed-behavior coverage: B-1 → MC-001, MC-002, MC-008, MC-016, MC-017; B-2 → MC-003, MC-004, MC-008, MC-016, MC-017; B-3 → MC-005, MC-006, MC-008, MC-016; B-7 → MC-002, MC-004, MC-006, MC-008; B-9 → MC-010, MC-018.
Invariant coverage: I-1 removal → MC-002, MC-004, MC-006, MC-015; I-1a → MC-009, MC-011, MC-015, MC-018; I-2 → MC-001, MC-003, MC-005, MC-007, MC-008, MC-012, MC-013, MC-014, MC-017; I-3 → MC-004, MC-007, MC-011, MC-017; I-4 → MC-006, MC-012, MC-016; I-5 → MC-002, MC-004, MC-012, MC-016, MC-017; I-6 → MC-001 through MC-007, MC-012, MC-013, MC-016; I-7 → MC-008; I-8 → MC-001, MC-003, MC-005, MC-008, MC-010.
Regression coverage: Gate safety and exact digests → MC-001–MC-007, MC-013; unchanged `RUN` flow → MC-009; documentation migration → MC-010; full automated/syntax/static regression → MC-011; restart and recovery → MC-012; state, logs, and compatibility contracts → MC-014, MC-016; rollback compatibility → MC-015; full-driver and speculation integration → MC-017; release-scope and protected-file integrity → MC-018.
Removed checks: None.