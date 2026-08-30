# Baseline Report

Omitted sections: none.

## 1. Change-request summary

`CHANGE_REQUEST.md` (seeded from `unclehq/stagegate#4`) asks to replace the human gate confirmation words `APPROVE` and `ACKNOWLEDGE` with a `Y/N` question where the user types `y` or `n`, and to make that prompt line bold. The request does not mention the `RUN` confirmation used by `scripts/from-issue.sh`, nor whether case-insensitivity or empty/EOF input should count as `n`.

## 2. Repository architecture

Stagegate is a set of bash 3.2+ drivers. The change-request pipeline (`scripts/change-workflow.sh`) and the new-application pipeline (`scripts/stagegate.sh`) each contain a human-gate function. A separate manual helper (`scripts/workflow.sh`) and the issue seeder (`scripts/from-issue.sh`) also ask for exact typed confirmation. Approvals are recorded as SHA-256 hashes in `.workflow/approvals/`. There is no compiled build; tests are bash hermetic suites.

## 3. Relevant code paths

| Area | File:lines |
|---|---|
| Change-request gate function | `scripts/change-workflow.sh:355-407` |
| Change-request gate call sites | `scripts/change-workflow.sh:740,747,772,793` |
| New-app gate function | `scripts/stagegate.sh:181-235` |
| New-app gate call sites | `scripts/stagegate.sh:510,529,543,564` |
| Manual approval helper | `scripts/workflow.sh:28-50` |
| Issue-seeder confirmation | `scripts/from-issue.sh:102-145` (`CONFIRM_WORD="RUN"` at `scripts/from-issue.sh:21`) |
| Approval hash helpers | `scripts/change-workflow.sh:126-128`; `scripts/stagegate.sh:62-64`; `scripts/workflow.sh:24-26` |
| Documented gate words | `README.md:167-186`; `QUICK_START.md:21` |

## 4. Current observable behavior

| ID | Trigger | Current result | Evidence | Must preserve? |
|---|---|---|---|---|
| B-1 | `change-workflow.sh` reaches a human gate (`APPROVE` or `ACKNOWLEDGE`) | Prints `Press ENTER after reviewing...`, then `Type $action exactly to continue: `; records hashes only if input equals `$action`; otherwise prints `Gate not accepted. Workflow remains paused.` and exits 0 | `scripts/change-workflow.sh:388-400` | Prompt acceptance must change; hash recording and pause behavior should be preserved |
| B-2 | `stagegate.sh` reaches a human gate | Prints banner with file name, `Press ENTER after reviewing the file...`, then `Type $wording exactly to continue: `; re-checks file hash after input; records hash if input matches and file unchanged; otherwise exits 0 | `scripts/stagegate.sh:192-234` | Prompt acceptance must change; edit detection and hash recording preserved |
| B-3 | `scripts/workflow.sh approve-plan/review/updated-plan` invoked | Prints file/SHA-256, then `Type APPROVE exactly to continue: `; exits 1 if input is not `APPROVE` | `scripts/workflow.sh:37-46` | Prompt acceptance must change; exit code on decline likely should stay 1 |
| B-4 | `from-issue.sh --change` confirms launch | Prints `Type RUN exactly to start the change workflow: `; declines on any input other than `RUN` | `scripts/from-issue.sh:128-135` | Not named in `CHANGE_REQUEST.md`; preserve unless spec extends scope |
| B-5 | Any accepted gate | SHA-256 of the reviewed file is written to `.workflow/approvals/<name>.sha256` | `scripts/change-workflow.sh:403-406`; `scripts/stagegate.sh:233`; `scripts/workflow.sh:48` | Yes |
| B-6 | `stagegate.sh` review with file changed during review | Re-opens gate and cancels speculation instead of recording approval for unseen bytes | `scripts/stagegate.sh:223-231` | Yes |
| B-7 | Gate prompt formatting | Prompt is plain text, not bold; uses exact uppercase action word | `scripts/change-workflow.sh:395`; `scripts/stagegate.sh:212`; `scripts/workflow.sh:41` | Must change per `CHANGE_REQUEST.md` |

## 5. Existing invariants

| ID | Invariant | Current enforcement | Existing test | Confidence |
|---|---|---|---|---|
| I-1 | A gate accepts only the exact configured confirmation word | String equality check (`$response != $action` / `$confirmation != APPROVE` / `$response != $CONFIRM_WORD`) | `close-flow-test.sh` exercises `RUN` exact-match | High for `RUN`; no automated test for `APPROVE`/`ACKNOWLEDGE` |
| I-2 | Approval records the hash of the file bytes present at acceptance | `hash_file` called after the accepted response | Not directly exercised by automated suites | High (code inspection) |
| I-3 | `stagegate.sh` refuses to approve a file that changed during review | `before` and after hashes compared before recording | Not exercised by automated suites | High (code inspection) |
| I-4 | `workflow.sh` declines with exit 1 when approval is not given | `exit 1` on mismatch | No dedicated test | High |
| I-5 | `change-workflow.sh`/`stagegate.sh` decline with exit 0 when gate not accepted | `exit 0` on mismatch | No dedicated test | High |

## 6. Current API, schema, and interface contracts

- `human_gate ACTION file1 name1 [file2 name2 ...]` in `scripts/change-workflow.sh`: `ACTION` is displayed and must be typed verbatim; multi-file gates ask for one ENTER prompt.
- `review_and_approve file name [wording]` in `scripts/stagegate.sh`: `wording` defaults to `approve`; converted to uppercase for display; input must match the uppercase word exactly.
- `scripts/workflow.sh approve-plan|approve-review|approve-updated-plan`: always asks for `APPROVE`.
- `scripts/from-issue.sh --change`: asks for `RUN` via `CONFIRM_WORD="RUN"`.
- Configuration and state contracts (`.workflow/state`, `.workflow/origin`, `.workflow/audit-verdict`, `.workflow/lock`) are unchanged by this request.

## 7. Existing automated-test coverage

| Suite | Scope | Checks |
|---|---|---|
| `scripts/tests/close-flow-test.sh` | Lock, origin binding, seed gate, verdict recording, issue-close decision matrix, hermetic driver runs with stubbed CLIs | 181 |
| `scripts/tests/audit-verdict-test.sh` | Verdict classification | 26 |
| `scripts/tests/agent-kimi-test.sh` | `scripts/agent-kimi.sh` event-stream translation and result synthesis | 23 |

Neither `close-flow-test-test.sh` nor `audit-verdict-test.sh` asserts the `APPROVE`/`ACKNOWLEDGE` prompt text or acceptance logic in the drivers; `scripts/workflow.sh` has no automated tests.

## 8. Exact build and test commands executed

```
bash scripts/tests/audit-verdict-test.sh
bash scripts/tests/close-flow-test.sh
bash scripts/tests/agent-kimi-test.sh
bash -n scripts/change-workflow.sh scripts/stagegate.sh scripts/workflow.sh scripts/from-issue.sh scripts/agent-kimi.sh scripts/lib/*.sh scripts/tests/*.sh
shellcheck scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh
```

No build step exists.

## 9. Baseline test results

```
audit-verdict-test.sh: 26 checks passed
close-flow-test.sh: 181 checks passed
agent-kimi-test.sh: 23 checks passed
```

`bash -n` reported syntax ok for all scripts.

`shellcheck` exited 0 and reported only low-severity/style items (see §10); no errors block execution.

## 10. Existing failures, warnings, and flaky behavior

- No test failures in the three suites.
- `shellcheck` warnings:
  - `SC2034` in `scripts/change-workflow.sh:179`: variable `attempt` appears unused.
  - `SC2317` in `scripts/from-issue.sh:200`: command appears unreachable.
  - `SC2148` in `scripts/lib/audit-verdict.sh:1`: missing shebang/shell directive.
  - `SC1091` in `scripts/lib/issue-close.sh:18`: not following sourced `./state.sh`.
  - `SC2059` info in `scripts/tests/audit-verdict-test.sh:21`: variable used in `printf` format string.
- Pre-existing uncommitted change: `scripts/agent-kimi.sh` has unstaged modifications (result-event synthesis for the kimi path) and `scripts/tests/agent-kimi-test.sh` is untracked. These are unrelated to the gate prompt change.
- Latent test-isolation note: the parent shell exports `STAGEGATE_ORIGIN_REPO`, `STAGEGATE_ORIGIN_ISSUE`, and `STAGEGATE_RUN_ID`. `close-flow-test.sh` sanitizes these internally, so the current run is clean, but running the suite from inside an active stagegate session without that sanitization can produce spurious origin-mismatch failures.

## 11. Reproduction result for the reported behavior

The current exact-word gate behavior was reproduced in isolated temp environments by feeding `y` as input:

| Gate | Input | Result |
|---|---|---|
| `change-workflow.sh` `human_gate APPROVE` | `y` | `Gate not accepted. Workflow remains paused.`; exit 0 |
| `stagegate.sh` `review_and_approve … approve` | `y` | `Gate not accepted. Workflow paused.`; exit 0 |
| `scripts/workflow.sh approve_file` | `y` | `Approval cancelled.`; exit 1 |
| `scripts/from-issue.sh` `confirm_and_run_workflow` | `y` | `Not confirmed.`; exit 0 |

This confirms the behavior described in `CHANGE_REQUEST.md`: users currently cannot answer `y`/`n` and must type the full uppercase word.

## 12. Likely change surface

- `scripts/change-workflow.sh` `human_gate` prompt and acceptance check.
- `scripts/stagegate.sh` `review_and_approve` prompt and acceptance check.
- `scripts/workflow.sh` `approve_file` prompt and acceptance check.
- `README.md`, `QUICK_START.md`, and possibly `scripts/README.md` gate documentation.
- No change expected to `from-issue.sh` unless the spec explicitly broadens the request to the `RUN` confirmation.

## 13. Regression-sensitive components

- `scripts/tests/close-flow-test.sh` asserts `Type RUN exactly to start the change workflow:` for the `from-issue.sh` seed gate. If the spec extends Y/N to that gate, these assertions must be updated.
- `scripts/workflow.sh` has no automated coverage; a change to its prompt/acceptance logic must be verified manually.
- Exit codes on declined gates differ between the drivers (`0`) and `scripts/workflow.sh` (`1`); any Y/N decline path should preserve these contracts.
- The bold ANSI escape must not corrupt the `read -p` prompt on non-TTY stdin (used by `close-flow-test.sh` and by piping `y` to a gate).
- Pre-existing uncommitted changes in `scripts/agent-kimi.sh` must not be accidentally reverted by edits in nearby lines.

## 14. Areas explicitly outside the change

- `scripts/from-issue.sh` `RUN` confirmation (unless spec extends scope).
- Model/effort/turn/tool defaults, `WORKFLOW_AGENT_CMD`/`WORKFLOW_REVIEWER_CMD`.
- `.workflow/state`/`origin`/`audit-verdict`/`lock` formats and close logic.
- The `scripts/agent-kimi.sh` uncommitted modifications and the untracked `scripts/tests/agent-kimi-test.sh`.

## 15. Unknowns and assumptions

| ID | Unknown / assumption | Reason |
|---|---|---|
| U-1 | Does "bold" mean ANSI escape codes in the terminal, markdown `**` wrapping, or both? | `CHANGE_REQUEST.md` says "Make that whole line bold" without specifying output target. |
| U-2 | Should `Y`/`N` be accepted case-insensitively, or only lowercase? | Not specified. |
| U-3 | Should empty input or EOF count as `n` (decline), or as an invalid response? | Current exact-word gates exit 0 on EOF; a Y/N gate should likely treat EOF as `n`. |
| U-4 | Should the `RUN` gate in `scripts/from-issue.sh` also become Y/N? | `CHANGE_REQUEST.md` mentions only `APPROVE`/`ACKNOWLEDGE`. |
| U-5 | Should the prompt still name the action being approved (e.g. "Approve CHANGE_SPEC.md? [Y/N]") or be generic? | Not specified. |

## 16. Initial risk assessment

Low-to-medium. The change is a localized UX improvement in four gate functions, but it touches the core safety mechanism that prevents accidental progression. Risks are:

- A too-permissive acceptance check could open a gate on unintended input.
- A bold escape sequence could break non-TTY test runners or terminal compatibility.
- Diverging exit-code behavior between the drivers and `scripts/workflow.sh` could break manual gate scripts.
- The pre-existing uncommitted `scripts/agent-kimi.sh` changes sit in the same file set; edits must avoid clobbering them.

Mitigation: keep the acceptance check strict (`y`/`Y` only for yes, everything else declines), preserve the existing hash-and-record flow, and test the gates with both TTY and piped stdin.
