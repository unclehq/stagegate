## AR-001: Immediate EOF bypasses the planned decline path

- Severity: High
- Affected behavior: B-8
- Affected invariant: I-5
- Affected component: `scripts/change-workflow.sh:388-395`; `scripts/stagegate.sh:209-212`
- Failure scenario: With stdin already closed, the unchanged preliminary `Press ENTER` read fails under `set -e`, so either driver exits 1 before displaying the Y/N question instead of declining with exit 0.
- Evidence: Both drivers execute an unguarded preliminary `read` before the proposed `IFS= read -r response || true`; `bash -c 'set -e; read x' </dev/null` exits 1.
- Why current tests may miss it: G2/G3 can mistakenly model EOF as a newline for the preliminary read followed by EOF at the Y/N read, never testing immediate closed stdin.
- Recommended correction: Guard or remove every read preceding the Y/N response, and define whether the preliminary review acknowledgement remains part of the input protocol.
- Proposed verification: Run each driver at a gate with stdin redirected directly from `/dev/null`; assert exit 0, unchanged state, no approval file, and the decline message.
- Blocks implementation: Yes

## AR-002: Multi-file prompt design changes APPROVE into ACKNOWLEDGE and omits targets

- Severity: High
- Affected behavior: B-1
- Affected invariant: I-8
- Affected component: `scripts/change-workflow.sh` prompt helper and `WAIT_ANALYSIS_APPROVAL`
- Failure scenario: The full-track analysis gate calls `human_gate APPROVE` with two files, but the planned cardinality-based prompt says `Ready to acknowledge the documents above?`, naming neither `BASELINE_REPORT.md` nor `CHANGE_SPEC.md`.
- Evidence: `scripts/change-workflow.sh:747-749` is a multi-file APPROVE gate, while `CHANGE_PLAN.md:25-26` assigns `approve` to one file and hardcodes `acknowledge` for several files; this also contradicts criterion 1 and G2’s target-name assertion.
- Why current tests may miss it: G2 covers only a multi-file ACKNOWLEDGE gate and a single-file APPROVE gate, exactly the combinations for which the flawed cardinality rule appears correct.
- Recommended correction: Derive the verb exclusively from the action argument and construct the target text from the actual file list.
- Proposed verification: Exercise every real call-site combination, including full-track multi-file APPROVE, small-track multi-file ACKNOWLEDGE, plan ACKNOWLEDGE, and single-file APPROVE; assert verb and filenames.
- Blocks implementation: Yes

## AR-003: The claimed review-integrity invariants contain TOCTOU gaps

- Severity: High
- Affected behavior: B-5, B-6
- Affected invariant: I-2, I-3
- Affected component: All three approval functions, especially `scripts/stagegate.sh:223-233`
- Failure scenario: In `stagegate.sh`, a file can change after the equality check at line 223 but before the second hash at line 233, causing approval of bytes never covered by the comparison; `human_gate` and `approve_file` have no before/after review comparison at all.
- Evidence: `stagegate.sh` validates one hash and then recomputes a different hash for storage; `change-workflow.sh:403-405` and `workflow.sh:37-48` hash only after the response despite README.md:206 claiming approval covers the exact bytes read.
- Why current tests may miss it: M-4 changes the file before answering, while G3 does not inject a mutation between validation and approval recording; neither probes the final rehash window.
- Recommended correction: Correct the baseline’s overstated invariants and either scope integrity hardening explicitly or capture one post-response digest, compare that digest with the reviewed digest, and write that same value to the approval record.
- Proposed verification: Use synchronization hooks to mutate the file before response, between comparison and recording, and after recording; unseen bytes must never receive a valid approval.
- Blocks implementation: Yes

## AR-004: Approval tests can pass with corrupt or misassigned hashes

- Severity: High
- Affected behavior: B-5
- Affected invariant: I-2
- Affected component: Planned `scripts/tests/gate-prompt-test.sh`
- Failure scenario: An implementation writes a constant, stale digest, or swaps the two multi-file approval hashes; the planned checks see that every hash file exists and report success.
- Evidence: G1 requires only “hash file written,” G2 says “records every hash,” and G3 says “same”; no planned automated assertion compares each stored digest with `shasum -a 256` of its corresponding file.
- Why current tests may miss it: The existing suites do not directly test these approval functions, and the new strategy emphasizes existence and exit status rather than digest content and mapping.
- Recommended correction: Assert exact digest contents for every accepted gate and assert the correct filename-to-approval-name mapping at multi-file gates.
- Proposed verification: Give each input file distinct contents, approve, compare every record with an independently computed digest, then mutate each file separately and confirm downstream verification rejects it.
- Blocks implementation: Yes

## AR-005: Legacy automation will fail silently with a successful exit status

- Severity: High
- Affected behavior: B-1, B-2, B-8
- Affected invariant: I-5
- Affected component: Driver input contract and compatibility strategy
- Failure scenario: An existing wrapper pipes the former review input plus `APPROVE` or `ACKNOWLEDGE`, receives exit 0 from the declined driver, and continues as though the workflow advanced even though state remains paused.
- Evidence: `CHANGE_PLAN.md:87-90` preserves decline exit 0, explicitly breaks full-word callers, and offers only documentation edits as migration; the change request asks for Y/N UX but does not explicitly require immediate rejection of legacy words.
- Why current tests may miss it: Tests intentionally classify the legacy words as decline and validate the preserved zero status, so they encode rather than expose the silent compatibility failure.
- Recommended correction: Obtain an explicit compatibility decision; either accept legacy words during a documented transition or provide a versioned migration notice and a machine-checkable way for callers to distinguish advancement from decline.
- Proposed verification: Run a representative legacy piped invocation and assert its documented transition behavior, including resulting state and approval records rather than exit status alone.
- Blocks implementation: Yes

## AR-006: Documentation search stopped before several stale instructions

- Severity: Medium
- Affected behavior: B-9
- Affected invariant: I-8
- Affected component: `README.md`; `QUICK_START.md`
- Failure scenario: Users follow unchanged instructions to “type the exact word requested” or “type the requested word” after the drivers have switched to a single-character response.
- Evidence: Widening the plan’s documentation search found stale text at `README.md:96-97`, `README.md:211-212`, and `QUICK_START.md:71`; the plan edits only README.md:167-186 and QUICK_START.md:20-21.
- Why current tests may miss it: Verification is an unspecified “Doc read” and the proposed grep searches only literal `APPROVE|ACKNOWLEDGE`, which cannot detect generic “requested word” instructions.
- Recommended correction: Include every user-facing gate explanation in the change-impact table and replace word-based instructions with the exact Y/N contract.
- Proposed verification: Add repository-wide negative searches for `exact word` and `requested word`, followed by a positive check that each gate guide documents `y`/`Y` and decline behavior.
- Blocks implementation: Yes

## AR-007: ANSI logging requirements contradict the planned PTY behavior

- Severity: Medium
- Affected behavior: B-7
- Affected invariant: I-7
- Affected component: Prompt styling and G4
- Failure scenario: A CI system allocates a pseudo-terminal and captures stdout; the prompt emits ANSI bytes into its transcript despite the security requirement prohibiting ANSI in logs.
- Evidence: CHANGE_SPEC.md:82 prohibits ANSI in logs, while CHANGE_PLAN.md:121 requires a `script` PTY capture to contain `\033[1m`; that capture is itself a log of terminal output.
- Why current tests may miss it: G4 treats ANSI in the PTY transcript as success and checks clean output only when stdout is not a TTY.
- Recommended correction: Define “logs” precisely and reconcile the requirement; if external PTY transcripts must remain clean, add an explicit styling opt-out such as `NO_COLOR` and specify its precedence.
- Proposed verification: Capture runs under non-TTY stdout, a PTY, `TERM=dumb`, and the chosen no-color mode; assert the explicitly documented byte-level behavior for each.
- Blocks implementation: Yes

## Blocking findings

AR-001, AR-002, AR-003, AR-004, AR-005, AR-006, and AR-007.

## Regression risks

Silent success for legacy automation, incorrect action wording at the full-track analysis gate, approval of unseen bytes, corrupt approval records passing tests, stale operator documentation, and escape bytes leaking into captured PTY output.

## Recommended simplifications

Use the action argument directly rather than inferring semantics from file count, remove or explicitly incorporate the preliminary ENTER interaction into the input contract, and define one captured digest as the value both validated and recorded.

## Required test additions

Immediate EOF at the first read; every real action/cardinality call-site combination; exact digest and multi-file mapping checks; synchronized edit-race cases; legacy piped-client behavior; repository-wide stale-instruction checks; and explicit PTY/non-TTY/no-color byte assertions.

## Overall assessment

Not ready for implementation: the plan is internally inconsistent on prompt construction and ANSI logging, relies on overstated approval-integrity invariants, and does not safely cover EOF, compatibility, or approval-record correctness.