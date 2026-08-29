# Manual Verification Checklist

Base checks: 24; resolved: 0; added: 4; removed: 0

Check ID: MC-001  
Priority: P0  
Behavior classification: MODIFY  
Related behavior: B-01, B-02; AC-1 — seed, display, confirm, and run the change workflow in one invocation  
Related invariant: I-07 — preserve the human review/editing window before driver execution  
Preconditions: Scratch checkout with empty/absent `.workflow/state`; authenticated `gh`; dedicated open test issue; terminal stdin; capture stdout, stderr, exit code, process tree, and timestamps  
Exact action: Run `./scripts/from-issue.sh <test-issue> --change`; verify the populated `CHANGE_REQUEST.md` is displayed and the process waits at the exact-word prompt; inspect or edit the file before entering the exact confirmation word; confirm and allow the driver to begin  
Expected result: The request is seeded before the prompt; no driver starts before exact confirmation; after confirmation, `change-workflow.sh` starts within the same invocation and its output streams to the caller; the prompt includes the specified pre-flight reminder; the former success-path `Run:` hint is absent  
Evidence to capture: Full transcript, timestamps showing seed/prompt/driver order, process tree, seeded file snapshot, and exit code  
Actual result:  
Status: NOT RUN  

Check ID: MC-002  
Priority: P0  
Behavior classification: ADD  
Related behavior: B-03; AC-2 — decline or abort without invoking the driver or GitHub write  
Related invariant: I-05, I-07 — GitHub mutation remains gated and the review window is effective  
Preconditions: Fresh scratch checkout; dedicated open test issue; GitHub state and comment count recorded; driver invocation observable through a harmless stub or process tracing  
Exact action: Run `from-issue.sh <test-issue> --change` separately with an explicit decline, an empty line, a wrong word, and EOF at the confirmation prompt  
Expected result: Each case is treated as decline, exits 0, leaves the newly written `CHANGE_REQUEST.md` intact, does not invoke `change-workflow.sh`, creates no `.workflow/origin`, makes no GitHub write, and prints the manual `Run: ./scripts/change-workflow.sh` hint  
Evidence to capture: Transcript and exit code for each input, file hashes before/after, invocation trace, `.workflow/` listing, issue state, and comment count  
Actual result:  
Status: NOT RUN  

Check ID: MC-003  
Priority: P0  
Behavior classification: MODIFY / BACKWARD-COMPATIBILITY BREAK  
Related behavior: B-01, B-02 — non-interactive callers receive the same confirmation gate  
Related invariant: I-07 — no TTY-based bypass of confirmation  
Preconditions: Fresh scratch checkout; dedicated test issue; controllable pipe or FIFO for stdin; timeout/process-observation facility  
Exact action: Start `from-issue.sh <test-issue> --change` with stdin supplied through a pipe/FIFO but initially provide no input; observe it beyond normal seed time, then send the exact confirmation word; repeat with EOF  
Expected result: Without a TTY the prompt is emitted and the process waits for input; exact confirmation proceeds to the driver exactly as terminal confirmation does; EOF declines with exit 0 and invokes neither driver nor close; no `--yes` or equivalent bypass is introduced  
Evidence to capture: Timestamped transcript, blocked/running process observation, invocation trace after input, EOF exit code, and CLI help output showing no bypass flag  
Actual result:  
Status: NOT RUN  

Check ID: MC-004  
Priority: P0  
Behavior classification: ADD / SECURITY-SENSITIVE  
Related behavior: B-04, B-10; AC-3 — satisfactory current audit closes the originating issue with an audit comment  
Related invariant: I-05, I-06, I-08, I-11 — controlled GitHub mutation, standalone exit compatibility, fail-closed verdict binding, and correct origin  
Preconditions: Dedicated disposable open GitHub issue; authenticated `gh` with permission to close it; fresh scratch checkout; workflow configured to reach `COMPLETE` with final verdict `READY`; record issue state and comments first  
Exact action: Run `from-issue.sh <test-issue> --change`, confirm, complete every internal gate, and let the workflow finish; inspect `.workflow/origin`, `.workflow/audit-verdict`, and `FINAL_AUDIT.md`; run `gh issue view <test-issue> --json state,comments`  
Expected result: The verdict artifact contains the current run ID, class `READY`, and the SHA-256 of the exact current `FINAL_AUDIT.md`; origin identifies the same repository and issue; the issue becomes `CLOSED` exactly once; a close comment identifies the verdict and points to `FINAL_AUDIT.md` and, if retained, `.workflow/change.diff`; overall exit is 0  
Evidence to capture: Complete transcript, exit code, the three artifacts and independently calculated hash, GitHub state JSON, comment body/author/time, and GitHub audit/event history  
Actual result:  
Status: NOT RUN  

Check ID: MC-005  
Priority: P0  
Behavior classification: ADD / BOUNDARY  
Related behavior: B-04 — `READY WITH NON-BLOCKING ISSUES` is also satisfactory  
Related invariant: I-08 — only the two approved satisfactory classes permit closing  
Preconditions: Same controlled setup as MC-004, using a different disposable issue and a final verdict of exactly `READY WITH NON-BLOCKING ISSUES`  
Exact action: Complete the confirmed workflow and inspect the verdict artifact, audit hash, origin, issue state, and comment  
Expected result: The stored class is `READY_WITH_NON_BLOCKING_ISSUES`; all run-ID, origin, and hash checks agree; the issue closes with a comment and the invocation exits 0  
Evidence to capture: Transcript, exit code, artifacts, independent hash, issue state, and comment  
Actual result:  
Status: NOT RUN  

Check ID: MC-006  
Priority: P0  
Behavior classification: ADD / ERROR  
Related behavior: B-05, B-06; AC-4 — unsatisfactory, unknown, stale, or incomplete results never close an issue  
Related invariant: I-08 — closure fails closed  
Preconditions: Hermetic close-flow environment with `gh` write calls recorded but disabled; distinct fixtures for `NOT READY`, `UNKNOWN`, missing verdict, stale run ID, mismatched audit hash, stale `COMPLETE` state, and a driver exit through a declined internal gate  
Exact action: Execute the close decision once for each fixture without changing other preconditions  
Expected result: Every case leaves the issue open and makes no close/comment call; each prints the specific reason; `NOT_READY` and `UNKNOWN` are distinguished; stale `COMPLETE` and internal-gate decline cannot reuse a prior verdict  
Evidence to capture: Per-case transcript, exit code, fixture contents, invocation log proving no GitHub write, and issue state  
Actual result:  
Status: NOT RUN  

Check ID: MC-007  
Priority: P0  
Behavior classification: ADD / FAILURE PROPAGATION  
Related behavior: B-06 — driver failure or interruption prevents closure and preserves the real status  
Related invariant: I-08 — only a successfully completed current run can close  
Preconditions: Hermetic driver substitutes that exit 1, 7, and 130 after confirmation; open test issue state recorded  
Exact action: Run the confirmed `from-issue.sh --change` flow against each substitute and record the outer process status and GitHub calls  
Expected result: No close or comment is attempted; the output plainly reports driver failure; the outer invocation returns the exact driver status 1, 7, or 130 respectively, without inversion or collapse  
Evidence to capture: Full transcript, inner and outer exit codes, GitHub invocation log, and issue state  
Actual result:  
Status: NOT RUN  

Check ID: MC-008  
Priority: P0  
Behavior classification: ADD / RECOVERY  
Related behavior: B-07; AC-5 — unavailable GitHub write capability is an explicit non-fatal close skip  
Related invariant: I-09 — missing or unauthenticated `gh` never silently no-ops or crashes a completed workflow  
Preconditions: Completed satisfactory workflow fixture; one run fetched through curl fallback; one run loses `gh` before close; one run has installed but unauthenticated `gh`; open disposable issues  
Exact action: Exercise the post-workflow close step in each environment and query issue state through an independent authenticated observer  
Expected result: No close/comment attempt occurs; each issue stays open; an explicit skip reason is printed; the successful workflow completion remains successful with exit 0  
Evidence to capture: Transcripts, exit codes, PATH/auth evidence, command invocation logs, and independently queried issue states  
Actual result:  
Status: NOT RUN  

Check ID: MC-009  
Priority: P0  
Behavior classification: ADD / ERROR / RECOVERY  
Related behavior: GitHub close failure after successful workflow completion  
Related invariant: I-05, I-08 — the sole irreversible write reports failure accurately  
Preconditions: Satisfactory, correctly bound current-run artifacts; authenticated `gh` stub or controlled failure returning a known non-zero status for `issue close`  
Exact action: Allow all close gates to pass, then force `gh issue close --comment` to fail  
Expected result: The invocation exits non-zero, prints the underlying close error, explicitly states that the workflow completed and only closure failed, and does not claim the change workflow itself was incomplete; the issue remains open  
Evidence to capture: Transcript, exit code, exact attempted `gh` arguments with credentials redacted, workflow state, and issue state  
Actual result:  
Status: NOT RUN  

Check ID: MC-010  
Priority: P0  
Behavior classification: ADD / SECURITY-SENSITIVE  
Related behavior: Wrong-issue and foreign-state protection  
Related invariant: I-11 — resumed or auto-invoked state must be provably owned by the current repository and issue  
Preconditions: Scratch checkout with non-empty, non-`COMPLETE` state belonging to issue A; preserve hashes of `CHANGE_REQUEST.md`, state, origin, audit, approvals, and logs; issue B is open  
Exact action: Invoke `from-issue.sh <issue-B> --change`; separately invoke `change-workflow.sh` with issue-B origin environment against issue-A state; repeat with `.workflow/origin` absent  
Expected result: Both entry points refuse with non-zero status before seeding, prompting, dispatch, audit, or GitHub access; the message names the conflicting or unprovable identity; all preserved files remain byte-identical; any acquired lock is released  
Evidence to capture: Before/after hashes and directory listings, transcripts, exit codes, process/invocation trace, lock state, and both GitHub issue states  
Actual result:  
Status: NOT RUN  

Check ID: MC-011  
Priority: P0  
Behavior classification: ADD / FAILURE AND RECOVERY  
Related behavior: Same-origin pause and resume without destroying the reviewed seed  
Related invariant: I-02, I-07, I-11 — approval hashes remain authoritative, the edit window persists, and provenance survives restart  
Preconditions: Issue A seeded and confirmed; driver paused at non-`COMPLETE` state after an internal gate decline; origin names issue A; hand-edited `CHANGE_REQUEST.md` hash recorded  
Exact action: Rerun `from-issue.sh <issue-A> --change`; observe the pre-confirmation path, confirm, and resume to a satisfactory completion  
Expected result: The fetch/seed step does not overwrite `CHANGE_REQUEST.md`; a “resuming existing seed” notice and confirmation appear; the driver resumes from saved state; approval-hash enforcement remains active; eventual closure targets issue A exactly once  
Evidence to capture: Request hashes before/after resume, transcript, state transitions, origin, approval verification output, issue events, and comment count  
Actual result:  
Status: NOT RUN  

Check ID: MC-012  
Priority: P0  
Behavior classification: ADD / CONCURRENCY  
Related behavior: Serialize access to checkout-local workflow state  
Related invariant: I-10 — only one driver may own a checkout’s `.workflow/` at a time  
Preconditions: First driver running in a safe scratch checkout; its PID and state recorded; second invocation available  
Exact action: While the first run is active, start a second `change-workflow.sh` from the same checkout  
Expected result: The second invocation refuses promptly with non-zero status and a lock-held message naming the live PID; it changes no workflow or audit data; the first invocation continues normally; the lock remains until the first exits and is then removed  
Evidence to capture: Concurrent transcripts, PIDs, exit codes, lock directory and PID contents over time, before/after state hashes, and first-run completion evidence  
Actual result:  
Status: NOT RUN  

Check ID: MC-013  
Priority: P1  
Behavior classification: ADD / RESTART RECOVERY  
Related behavior: Recover automatically from a lock whose owning process is dead  
Related invariant: I-10 — stale synchronization data must not permanently block progress  
Preconditions: Scratch checkout with `.workflow/lock/pid` naming a verified dead PID; otherwise valid resumable state  
Exact action: Start `change-workflow.sh` and observe lock handling through process exit  
Expected result: The stale lock is identified and cleared, the driver proceeds, the replacement lock records the current PID, and the lock is removed on normal exit  
Evidence to capture: Dead-PID proof, lock contents before/during/after, transcript, state hashes, and exit code  
Actual result:  
Status: NOT RUN  

Check ID: MC-014  
Priority: P0  
Behavior classification: ADD / STALE-DATA DEFENSE  
Related behavior: Current audit output must replace, not inherit, prior audit output  
Related invariant: I-08 — verdict must be fresh and hash-bound to the exact classified bytes  
Preconditions: Precreate a stale `FINAL_AUDIT.md` ending in `READY`; configure the reviewer call to return 0 without recreating the file; record issue state and verdict artifact  
Exact action: Run the `FINAL_AUDIT` stage through its normal workflow entry point  
Expected result: The stale audit is removed before reviewer execution; absence of newly produced output causes a hard failure before `COMPLETE`; no new verdict artifact authorizing closure is written and no close is attempted  
Evidence to capture: Before/after file listings and hashes, stage transcript, state, exit code, verdict artifact, GitHub invocation trace, and issue state  
Actual result:  
Status: NOT RUN  

Check ID: MC-015  
Priority: P0  
Behavior classification: ADD / BOUNDARY  
Related behavior: Exact-last-line audit verdict classification  
Related invariant: I-08 — ambiguous audit prose cannot authorize closure  
Preconditions: Isolated classifier runner and fixtures covering all specified formats  
Exact action: Classify audits ending respectively in `READY`, `READY WITH NON-BLOCKING ISSUES`, `NOT READY`, `## READY`, emphasized verdict text, trailing blank lines, CRLF, `Rerun until READY`, concatenated verdict phrases, an empty file, and arbitrary trailing signature/prose  
Expected result: Exact approved phrases classify to their normalized classes after permitted heading/emphasis/whitespace cleanup; CRLF and trailing blank lines do not alter the result; all non-exact, concatenated, empty, or trailing-prose cases classify `UNKNOWN`; only the final non-blank line controls classification  
Evidence to capture: Fixture bytes, classifier output and exit code for every fixture, plus automated test transcript  
Actual result:  
Status: NOT RUN  

Check ID: MC-016  
Priority: P1  
Behavior classification: MODIFY / OBSERVABILITY  
Related behavior: B-10 and all close/refusal paths emit usable operational evidence  
Related invariant: I-06, I-09, I-10, I-11 — machine-readable verdict plus explicit safe refusals  
Preconditions: Representative successful, declined, close-skipped, lock-refused, origin-refused, and close-failed scenarios available  
Exact action: Execute each scenario and inspect stdout/stderr plus `.workflow/audit-verdict` and `.workflow/origin`  
Expected result: Output includes `Audit verdict: <class>` and an unambiguous close, skip, or failure line; lock refusal names its PID; origin refusal names the conflicting issue; the verdict artifact is exactly three tab-separated fields `<run-id> <class> <sha256>`; origin is exactly `<repo> <issue>`; no credentials or tokens are emitted; existing logs and `cost.tsv` formats are unchanged  
Evidence to capture: Redacted transcripts, raw artifact bytes, field counts, log/cost hashes or format comparison, and secret scan results  
Actual result:  
Status: NOT RUN  

Check ID: MC-017  
Priority: P0  
Behavior classification: PRESERVE  
Related behavior: B-08; AC-6 — new-project issue flow remains unchanged  
Related invariant: I-04 — scripts remain CWD-independent; change-only dispatch remains isolated  
Preconditions: Identical scratch checkouts at pre-change baseline and candidate revision; representative issue that selects `--new` explicitly and by auto-detection  
Exact action: Run `from-issue.sh <issue> --new` and the auto-detected new-project path in both revisions; compare stdout, stderr, exit code, and resulting `REQUIREMENTS.md` byte-for-byte  
Expected result: Candidate behavior is byte-identical to baseline: it writes the same requirements section, prints the same hint, exits without confirmation, does not invoke `stagegate.sh`, and performs no GitHub write  
Evidence to capture: Commands, transcripts, exit codes, file hashes/diffs, invocation trace, and issue state/comment count  
Actual result:  
Status: NOT RUN  

Check ID: MC-018  
Priority: P1  
Behavior classification: PRESERVE / REGRESSION  
Related behavior: B-09, B-10; AC-7 — established CLI contracts remain unchanged  
Related invariant: I-04, I-06 — CWD independence and standalone driver compatibility  
Preconditions: Candidate revision and frozen baseline expectations from `BASELINE_REPORT.md`; no live workflow execution required  
Exact action: Run `from-issue.sh` with no arguments, `--help`, `abc`, and an unknown flag; run `change-workflow.sh --help`, `--version`, and an unknown argument; repeat each via absolute path from `/tmp`  
Expected result: Existing usage text routing and exit codes match baseline: `from-issue.sh` no-arg/help exits 0 to stdout and invalid input exits 1 with usage to stdout; driver help exits 0 to stdout, version prints `0.1.0` and exits 0, unknown argument sends usage to stderr and exits 1; all work from another CWD  
Evidence to capture: Command matrix with stdout, stderr, and exit codes; baseline comparison; `/tmp` transcripts  
Actual result:  
Status: NOT RUN  

Check ID: MC-019  
Priority: P0  
Behavior classification: PRESERVE / REGRESSION  
Related behavior: Existing workflow stages, gates, approvals, reviewer ownership, state order, and accounting remain unchanged  
Related invariant: I-01, I-02, I-03 — exact-word internal gates, SHA-256 approval pinning, and reviewer-owned artifact control  
Preconditions: Scratch standalone workflow run with no `STAGEGATE_ORIGIN_*`; ability to decline a gate and alter an approved artifact in separate runs  
Exact action: Run the standalone driver through representative stages; decline one internal gate; in a separate run approve an artifact, modify it, and resume; complete a normal single standalone run while observing state order and artifacts  
Expected result: Decline still halts further work; modified approved content still triggers hash verification failure; reviewer-owned artifacts arise only through reviewer stages; state nodes remain `ANALYZE` through `COMPLETE` without additions or reordering; standalone execution does not require or write origin data, still exits 0 at `COMPLETE`, and differs only by the documented verdict line and transient lock; logs and cost accounting continue normally  
Evidence to capture: Transcripts, state history, approval/file hashes, artifact provenance, exit codes, origin/lock observations, logs, and cost ledger  
Actual result:  
Status: NOT RUN  

Check ID: MC-020  
Priority: P1  
Behavior classification: ADD / FRESH-START AND RESTART  
Related behavior: Origin claim lifecycle across absent, empty, and `COMPLETE` state  
Related invariant: I-11 — only active in-progress state prevents a new issue from claiming the checkout  
Preconditions: Three scratch scenarios: absent state/origin, empty state, and `COMPLETE` state previously associated with issue A; dedicated issue B  
Exact action: Start and confirm `from-issue.sh <issue-B> --change` in each scenario; stop safely after origin initialization  
Expected result: Each scenario is accepted as fresh/restartable; issue B becomes the current origin as `ANALYZE` starts; prior completed origin does not cause refusal; no prior in-progress state or audit is incorrectly reused to close issue B  
Evidence to capture: Before/after state and origin bytes, transcript, run IDs, audit artifacts, exit codes, and GitHub invocation trace  
Actual result:  
Status: NOT RUN  

Check ID: MC-021  
Priority: P1  
Behavior classification: ADD / PERSISTENCE COMPATIBILITY  
Related behavior: New workflow metadata coexists with existing state without migration  
Related invariant: I-06, I-10, I-11 — additive metadata must not reinterpret existing formats  
Preconditions: Scratch copies of representative legacy states with no `.workflow/origin`, lock, or audit-verdict; include empty/`COMPLETE` and non-empty/non-`COMPLETE` cases  
Exact action: Invoke the standalone driver on each legacy state; invoke the issue-seeded flow against matching test issues  
Expected result: Standalone execution remains compatible because origin preflight is skipped without origin environment; empty/`COMPLETE` issue-seeded runs create new metadata safely; an issue-seeded run against ownerless in-progress legacy state refuses rather than guessing ownership; existing `state`, approvals, logs, cost ledger, and `CHANGE_REQUEST.md` formats are not migrated or rewritten merely to support metadata  
Evidence to capture: Before/after byte comparisons, transcripts, exit codes, and new metadata listings  
Actual result:  
Status: NOT RUN  

Check ID: MC-022  
Priority: P1  
Behavior classification: REMOVE / DOCUMENTATION  
Related behavior: Remove the old successful `--change` print-and-exit handoff and document the new gate/run/close lifecycle  
Related invariant: I-07, I-09, I-10, I-11 — documented operational behavior matches enforced behavior  
Preconditions: Candidate `README.md` and `scripts/README.md`; execution results from MC-001 through MC-013  
Exact action: Follow the documented “Start from a GitHub issue” procedure literally for confirmation, decline, same-origin resume, curl/auth skip, lock refusal, and origin refusal  
Expected result: Documentation no longer instructs successful change runs to stop after printing a manual command; it accurately describes the blocking prompt, auto-run, conditional commented close, close-skip behavior, origin ownership, lock refusal, no non-interactive bypass, and unchanged `--new` flow; every documented command and expected message agrees with observed behavior  
Evidence to capture: Documentation excerpts, command transcripts, discrepancies list, and reviewer sign-off  
Actual result:  
Status: NOT RUN  

Check ID: MC-023  
Priority: P0  
Behavior classification: REGRESSION / AUTOMATED VERIFICATION  
Related behavior: AC-3 through AC-7 and all specified negative close branches  
Related invariant: I-04, I-08, I-09, I-10, I-11  
Preconditions: Candidate revision with documented shell dependencies; no real GitHub issue mutation permitted during this check  
Exact action: Run `for f in scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh; do bash -n "$f"; done`, then run the specified audit-verdict and hermetic close-flow test scripts, then replay the baseline argument commands  
Expected result: Every syntax check and automated test exits 0; close-flow coverage includes both satisfactory verdicts, `NOT_READY`, `UNKNOWN`, missing/mismatched run ID, origin and hash, driver statuses 1/7/130, curl fallback, unauthenticated `gh`, close failure, prompt decline, lock contention, and foreign origin; no test performs a real GitHub write  
Evidence to capture: Exact commands, complete test output, exit codes, test environment/stub evidence, and baseline command comparison  
Actual result:  
Status: NOT RUN  

Check ID: MC-024  
Priority: P1  
Behavior classification: ROLLBACK  
Related behavior: Revert to seed-and-hint behavior without changing existing workflow state formats  
Related invariant: I-05, I-06 — rollback removes automatic GitHub mutation while preserving pre-change state compatibility  
Preconditions: Disposable branch/checkout containing candidate revision; completed test run with new metadata; disposable issue closed by the feature; approved rollback procedure  
Exact action: Revert the change commits in the disposable checkout, leave new `.workflow/audit-verdict` and `.workflow/origin` present for the first smoke test, then remove only the documented new metadata and rerun pre-change CLI smoke checks  
Expected result: Reverted `from-issue.sh --change` returns to writing the request and printing the manual driver hint without auto-run or close; reverted driver ignores leftover additive metadata; existing state, approval hashes, logs, and cost data require no migration/reset; rollback does not automatically reopen an already closed issue and documentation clearly requires manual reopening when desired  
Evidence to capture: Revert commit/diff, before/after metadata listing, smoke-test transcript and exit codes, retained state hashes, and issue state  
Actual result:  
Status: NOT RUN  

Check ID: MC-025  
Priority: P1  
Behavior classification: ADD / DEVIATION / REGRESSION  
Related behavior: Test-only source hook introduced outside the public CLI contract  
Related invariant: I-04, I-05, I-07 — testability must not create an accidental production bypass  
Preconditions: Scratch checkout; harmless fetch and driver stubs; environment initially free of `STAGEGATE_FROM_ISSUE_SOURCE_ONLY`; implementation at `scripts/from-issue.sh:213-219`  
Exact action: Execute `from-issue.sh <test-issue> --change` normally with the variable unset and with `STAGEGATE_FROM_ISSUE_SOURCE_ONLY=0`; then execute it with `STAGEGATE_FROM_ISSUE_SOURCE_ONLY=1`; separately source it with the variable set and inspect the functions made available  
Expected result: Unset and `0` run the normal CLI; `1` exits before argument parsing, fetch, seeding, prompting, driver execution, and GitHub writes; sourcing with `1` defines the intended helper functions without executing the CLI; the hook is absent from help and accepts no command-line equivalent  
Evidence to capture: Environment, transcripts, exit codes, fetch/driver/GitHub invocation logs, function listing, help output, and filesystem hashes  
Actual result:  
Status: NOT RUN  

Check ID: MC-026  
Priority: P0  
Behavior classification: ADD / CONCURRENCY LIMITATION  
Related behavior: Two independent checkouts can operate on the same originating issue concurrently  
Related invariant: I-05, I-08, I-11 — each checkout must remain bound to its own run, and duplicate irreversible writes must be understood  
Preconditions: Two scratch clones of the same repository; the same dedicated disposable open issue; authenticated `gh`; both workflows controllable at their internal gates; checkout-local lock behavior at `scripts/change-workflow.sh:142-183`; concern recorded at `IMPLEMENTATION_NOTES.md:64-66`  
Exact action: Start `from-issue.sh <test-issue> --change` in both clones, confirm both, hold each after origin initialization, then advance both to satisfactory completion while recording GitHub calls and issue events  
Expected result: Each clone acquires only its own checkout-local lock and preserves its own origin/run/hash binding; neither run reads or overwrites the other clone’s artifacts; record whether both attempt `gh issue close`, how the second close is reported after the first closes the issue, and whether any duplicate comment or misleading success message occurs  
Evidence to capture: Both transcripts, PIDs, lock/origin/verdict bytes, run IDs, independent audit hashes, exact GitHub calls, issue timeline, comment count, and both exit codes  
Actual result:  
Status: NOT RUN  

Check ID: MC-027  
Priority: P1  
Behavior classification: ADD / LOCK RECOVERY LIMITATION  
Related behavior: A stale lock PID reused by an unrelated live process causes a false lock-held refusal  
Related invariant: I-10 — lock recovery must fail safely without corrupting workflow state  
Preconditions: Scratch checkout with valid resumable state; unrelated long-lived process with known PID; `.workflow/lock/pid` containing that live unrelated PID; implementation at `scripts/change-workflow.sh:166-178`; concern recorded at `IMPLEMENTATION_NOTES.md:67-68`  
Exact action: Start `change-workflow.sh` while the unrelated process remains alive; preserve workflow hashes; terminate that unrelated process and invoke the driver again against the unchanged stale lock  
Expected result: The first invocation refuses non-zero, names the recorded PID, and changes no workflow/audit data; after the unrelated process exits, the second invocation identifies and clears the stale lock, acquires a replacement lock, and proceeds; no invocation falsely proceeds while the recorded PID is live  
Evidence to capture: Process identity and liveness evidence, lock contents, both transcripts and exit codes, state/artifact hashes, and replacement-lock lifecycle  
Actual result:  
Status: NOT RUN  

Check ID: MC-028  
Priority: P0  
Behavior classification: ADD / LIVE INTEGRATION GAP  
Related behavior: B-05; AC-4 — a real unsatisfactory audit leaves the originating issue open  
Related invariant: I-05, I-08, I-11 — live pipeline closure remains fail-closed  
Preconditions: Dedicated disposable open GitHub issue; authenticated `gh`; fresh scratch checkout; real agent pipeline configured to reach `COMPLETE` with final verdict exactly `NOT READY`; issue state and comments recorded first; untested area cited at `CHANGE_TEST_REPORT.md:77-80`  
Exact action: Run `from-issue.sh <test-issue> --change`, confirm, complete every internal gate, and allow the real final-audit and post-workflow close decision to finish; inspect `.workflow/origin`, `.workflow/audit-verdict`, `FINAL_AUDIT.md`, and `gh issue view <test-issue> --json state,comments`  
Expected result: The verdict artifact contains the current run ID, class `NOT_READY`, and the SHA-256 of the exact current `FINAL_AUDIT.md`; origin identifies the same repository and issue; the issue remains `OPEN`; no close comment or close event is created; output explicitly reports the `NOT_READY` verdict and open disposition; overall workflow exit is 0  
Evidence to capture: Complete transcript, exit code, artifact bytes, independent audit hash, GitHub state JSON, comment/event history, and exact GitHub invocation trace  
Actual result:  
Status: NOT RUN  

Acceptance-criteria traceability: AC-1 → MC-001, MC-003; AC-2 → MC-002; AC-3 → MC-004, MC-005, MC-015, MC-016; AC-4 → MC-006, MC-007, MC-010, MC-014, MC-028; AC-5 → MC-008; AC-6 → MC-017; AC-7 → MC-018, MC-023  
Preserved-behavior coverage: B-08 → MC-017; B-09 → MC-018; B-10 standalone compatibility → MC-018, MC-019; I-01/I-02/I-03 → MC-019; CWD independence → MC-018; existing state formats → MC-019, MC-021; unchanged out-of-scope `--new` dispatch → MC-017; public CLI isolation from the test-only source hook → MC-025  
Changed-behavior coverage: B-01/B-02 → MC-001, MC-003; B-03 → MC-002; B-04 → MC-004, MC-005; B-05/B-06 → MC-006, MC-007, MC-028; B-07 → MC-008; B-10 signal → MC-004, MC-015, MC-016; origin, freshness, concurrency, resume, and observability additions → MC-010 through MC-016, MC-020; implementation deviations and limitations → MC-025 through MC-027  
Invariant coverage: I-01 → MC-019; I-02 → MC-011, MC-019; I-03 → MC-019; I-04 → MC-017, MC-018, MC-023, MC-025; I-05 → MC-002, MC-004, MC-006 through MC-010, MC-024 through MC-026, MC-028; I-06 → MC-004, MC-016, MC-018, MC-019; I-07 → MC-001 through MC-003, MC-011, MC-025; I-08 → MC-004 through MC-007, MC-010, MC-014 through MC-016, MC-023, MC-026, MC-028; I-09 → MC-008, MC-016; I-10 → MC-012, MC-013, MC-023, MC-026, MC-027; I-11 → MC-004, MC-010, MC-011, MC-020, MC-021, MC-023, MC-026, MC-028  
Regression coverage: CLI and CWD contracts → MC-018, MC-025; `--new` isolation → MC-017; gates, approval hashes, reviewer ownership, state order, logs, and cost ledger → MC-019; legacy/additive-state compatibility → MC-020, MC-021; syntax and automated negative paths → MC-023; documentation and removed handoff behavior → MC-022; rollback and irreversible issue-state caveat → MC-024; requirements requiring live pipeline or real GitHub verification → MC-001, MC-004, MC-005, MC-008 through MC-014, MC-017, MC-019, MC-020, MC-024, MC-026, MC-028; lock false-refusal recovery → MC-027  
Removed checks: None.