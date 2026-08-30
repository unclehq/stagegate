# Change Plan

Omitted sections: Schema or persistence changes (approval-hash path/format untouched, CHANGE_SPEC §8); Concurrency implications (gates are synchronous single-reader prompts; `.workflow/lock` untouched); Migration plan (no data or state migration, CHANGE_SPEC §11; doc edits are in the implementation sequence).

## 1. Selected technical approach

A per-script local gate helper, mirroring the existing `hash_file` duplication idiom (`scripts/change-workflow.sh:126`, `scripts/stagegate.sh:62`, `scripts/workflow.sh:24`).

Each of the three affected scripts gets a small local function that (a) prints one bold prompt line naming the target and ending `[Y/N]`, (b) reads one response, (c) returns success only for `y`/`Y`. Each call site keeps its own decline message and exit code.

Mechanics, identical in all three:

| Concern | Decision | Reason |
|---|---|---|
| Prompt output | `printf '%s'` to stdout, not `read -p` | `read -p` suppresses the prompt when stdin is not a TTY; `scripts/from-issue.sh:124-128` already documents and uses this workaround |
| Bold | `$'\033[1m'` … `$'\033[0m'`, emitted only when `[[ -t 1 ]]` | I-7 in a terminal; BASELINE §13 / CHANGE_SPEC §9 keep piped output clean and readable |
| Read | `IFS= read -r response \|\| true` | `IFS=` stops `read` from stripping surrounding whitespace, so `" y"` declines (CHANGE_SPEC §10); `\|\| true` keeps EOF from tripping `set -e` and breaking the exit-code contract (I-4, I-5) |
| Acceptance | `case "$response" in y\|Y) ... ;; *) decline ;; esac` | I-6; bash 3.2 has no `${var,,}` |
| Verb | action word lowercased via `tr '[:upper:]' '[:lower:]'` | bash 3.2 has no `${var^}`; keeps `human_gate ACKNOWLEDGE` call sites unchanged |

Prompt text (I-8):

| Script | Prompt |
|---|---|
| `change-workflow.sh`, one file | `Ready to approve CHANGE_PLAN.md? [Y/N] ` |
| `change-workflow.sh`, several files | `Ready to acknowledge the documents above? [Y/N] ` |
| `stagegate.sh` | `Ready to approve PROJECT_PLAN.md? [Y/N] ` (verb from the `wording` argument) |
| `workflow.sh` | `Ready to approve PROJECT_PLAN.md? [Y/N] ` |

The preceding `Press ENTER after reviewing...` prompt, the banners, hash recording, and `stagegate.sh` edit detection are untouched.

## 2. Alternative approaches considered

| Alternative | Rejected because |
|---|---|
| Shared `scripts/lib/gate-prompt.sh` sourced by all three | `stagegate.sh` and `workflow.sh` currently source nothing; adding a source line to each creates a new runtime file dependency for a 10-line function, a larger surface than the duplication it removes |
| Keep `read -r -p` and prepend ANSI inside the `-p` string | Prompt disappears entirely under non-TTY stdin, so piped gate tests could not assert prompt text |
| Accept `y`, `Y`, `yes`, `YES` | CHANGE_SPEC §10 and I-6 restrict yes to `y`/`Y` |
| Always emit ANSI regardless of TTY | Escape bytes land in captured logs and test fixtures; CHANGE_SPEC §9 requires readability without a bold-capable terminal |
| Treat empty input as yes (default-yes) | Inverts the safety default of a human gate; CHANGE_SPEC §4 requires empty/EOF to decline |

## 3. Why the selected approach is preferred

It changes only the prompt and acceptance lines of three functions, follows the repo's existing per-script-helper idiom, keeps every hash, exit-code, and edit-detection path byte-identical, and makes the prompt visible under both TTY and piped stdin so the new behavior is automatically testable.

## 4. Exact components to modify

| Component | Location | Edit |
|---|---|---|
| `human_gate` | `scripts/change-workflow.sh:394-400` | Replace `read -r -p "Type $action exactly..."` + string compare with bold Y/N prompt + `y`/`Y` check; add local helper near `hash_file` (`:126`) |
| `review_and_approve` | `scripts/stagegate.sh:211-217` | Same replacement; helper near `upper`/`hash_file` (`:62`) |
| `approve_file` | `scripts/workflow.sh:41-46` | Same replacement; helper near `hash_file` (`:24`) |
| `README.md` | `:167-170`, `:184-186` gate columns | Replace `APPROVE`/`ACKNOWLEDGE` cells with `Y/N` |
| `QUICK_START.md` | `:20-21` | Replace "Type the requested word (`APPROVE` or `ACKNOWLEDGE`)" with the Y/N answer |
| New test suite | `scripts/tests/gate-prompt-test.sh` | §16 |

`scripts/README.md` names no gate word (its `workflow.sh` section, `:45-61`, describes subcommands only). Confirm with `grep -n 'APPROVE\|ACKNOWLEDGE' scripts/README.md` before concluding acceptance criterion 6 is met there; edit only if a hit appears.

## 5. Components explicitly not to modify

- `scripts/from-issue.sh` `RUN` confirmation (`:21`, `:102-136`) — B-4, I-1a.
- `hash_file`, `verify_approval`, `cancel_speculation`, `speculate`, `set_state`, and all `.workflow/*` handling.
- `human_gate` / `review_and_approve` call-site argument lists (`scripts/change-workflow.sh:740,747,772,793`; `scripts/stagegate.sh:510,529,543,564`).
- `scripts/tests/close-flow-test.sh` and its `Type RUN exactly...` assertions (`:252`, `:275`).
- `scripts/agent-kimi.sh` (uncommitted work) and the untracked `scripts/tests/agent-kimi-test.sh` — BASELINE §14, core rule 13.
- Pre-existing shellcheck findings listed in BASELINE §10 (no unrelated cleanup).

## 6. Data-flow changes

Only the operator-input branch changes: gate input was compared to an action word, now it is classified as yes/not-yes. The value read is used solely for that branch — it is never written to a file, a log, or `.workflow/`. ANSI bytes exist only in the stdout prompt; nothing downstream consumes them (CHANGE_SPEC §10).

## 7. State-transition changes

None. Accepted gates still record hashes and let the caller advance state; declined gates still exit before `set_state`. `stagegate.sh` still loops back to re-open the gate when the file changed during review (I-3, B-6).

## 8. Interface and API changes

| Interface | Before | After |
|---|---|---|
| `human_gate ACTION file name ...` | `ACTION` is typed verbatim by the operator | `ACTION` supplies the prompt verb only; signature unchanged |
| `review_and_approve file name [wording]` | `wording` uppercased and typed verbatim | `wording` supplies the prompt verb (lowercased); signature and default unchanged |
| `workflow.sh approve-*` | Requires typed `APPROVE` | Requires `y`/`Y`; subcommands and exit codes unchanged |
| Operator contract | Type `APPROVE`/`ACKNOWLEDGE` | Type `y` or `Y`; anything else declines — intentional UX break (CHANGE_SPEC §8) |

## 9. Compatibility strategy

- Decline exit codes preserved: `0` for the two drivers, `1` for `workflow.sh` (I-4, I-5).
- Approval file path and format unchanged (I-2).
- `from-issue.sh` unchanged, so `close-flow-test.sh` must pass without edits (B-4, acceptance criterion 5).
- Any external script piping `APPROVE`/`ACKNOWLEDGE` into a driver breaks by design; the docs edits are the migration notice.

## 10. Error and recovery behavior

| Input | Result |
|---|---|
| `y`, `Y` | Gate accepts; hashes recorded |
| `n`, `N`, arbitrary text, `APPROVE` | Decline message, existing exit code |
| Empty line | Decline |
| EOF / closed stdin | `read` fails, `\|\| true` keeps `set -e` from firing, empty response declines with the existing exit code |
| ` y` (leading space) | Decline — `IFS=` preserves the space |
| Terminal without bold | `[[ -t 1 ]]` false, or the terminal ignores the escape; plain readable prompt, no error |
| File changed during `stagegate.sh` review | Unchanged: gate re-opens, speculation cancelled |

## 11. Rollback plan

`git revert` / `git checkout` of the three script files and two docs restores exact-word gates; the helper is self-contained with no callers outside the three functions. Existing `.workflow/approvals/*.sha256` files stay valid in both directions, so no state rollback is needed. Roll back the new test file with the same commit. Because `scripts/agent-kimi.sh` carries unrelated uncommitted work, roll back per-file — never `git checkout -- .`.

## 12. Feature-flag or containment strategy

No flag. A configuration knob for prompt wording or case sensitivity is an explicit non-goal (CHANGE_SPEC §13); containment is the single-commit revert in §11.

## 13. Automated-test strategy

New hermetic suite `scripts/tests/gate-prompt-test.sh`, in the style of `close-flow-test.sh` (scratch repo, stubbed agent CLIs via `WORKFLOW_AGENT_CMD`/`WORKFLOW_REVIEWER_CMD`, captured stdout):

| Group | Target | Checks |
|---|---|---|
| G1 | `workflow.sh approve-plan` in a temp dir | `y` and `Y` → hash file written, exit 0; `n`, `N`, `foo`, empty, EOF, and `APPROVE` → "Approval cancelled.", exit 1, no hash file |
| G2 | `change-workflow.sh` at `WAIT_PLAN_APPROVAL` (multi-file `ACKNOWLEDGE` gate) and `WAIT_UPDATED_PLAN_APPROVAL` (single-file `APPROVE` gate) | Prompt contains the target name and `[Y/N]`; ENTER+`y` records every hash; `n`/empty/EOF → "Gate not accepted", exit 0, no hash file |
| G3 | `stagegate.sh` at `WAIT_REQUIREMENTS_APPROVAL` | Same accept/decline matrix, exit 0 on decline |
| G4 | Bold rendering | Piped stdout contains no `\033`; PTY run (`script -q /dev/null …`) contains `\033[1m` before the prompt and `\033[0m` after |
| G5 | Whitespace strictness | `" y"` declines |

G4 note: `script` argument syntax differs between BSD and GNU. If the PTY capture is not reliable on the implementation host, the check is recorded NOT RUN and moved to §15 as a manual PTY check — it is not to be relaxed into a pass (core rule 10).

Before wiring G3, confirm whether `speculate` at `WAIT_REQUIREMENTS_APPROVAL` requires a reviewer stub; if stubbing proves unreliable, invoke `review_and_approve` through a driver run with the speculation stage already satisfied rather than weakening the assertion.

## 14. Regression-test strategy

This is a feature change, not a bug fix, so there is no pre-existing failing test to point at. The equivalent guard: G2/G3 assert the decline path (no hash file, correct exit code) for `n`, arbitrary text, empty, and EOF, which is where a too-permissive check would show up. Existing suites re-run unchanged:

```
bash scripts/tests/close-flow-test.sh      # 181 checks — must stay 181, RUN gate untouched
bash scripts/tests/audit-verdict-test.sh   # 26 checks
bash scripts/tests/agent-kimi-test.sh      # 23 checks
bash scripts/tests/gate-prompt-test.sh     # new
bash -n scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh
shellcheck scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh   # no new findings beyond BASELINE §10
```

Also confirm no `close-flow-test.sh` scenario reaches a `human_gate`; if one does, its piped input must change from the exact word to `y` and that is a material deviation to record.

## 15. Manual-verification strategy

`scripts/workflow.sh` has no prior automated coverage (BASELINE §13), and bold is a terminal property, so these run by hand in a real terminal:

| ID | Action | Expected |
|---|---|---|
| M-1 | Run `./scripts/workflow.sh approve-plan` in a scratch checkout, answer `y` | Prompt line renders bold, ends `[Y/N]`, names `PROJECT_PLAN.md`; approval recorded |
| M-2 | Repeat, answer `n`, then repeat and answer `APPROVE` | "Approval cancelled.", exit 1 both times, no hash file |
| M-3 | Drive `change-workflow.sh` to a live gate, answer `y` | Bold prompt; hashes recorded; pipeline advances |
| M-4 | At a `stagegate.sh` gate, edit the file in another terminal before answering `y` | Gate re-opens with the changed-file message (I-3) |
| M-5 | Run a gate in a terminal without bold support (or `TERM=dumb`) | Prompt readable, no error |
| M-6 | `cat` a captured non-TTY gate log | No escape bytes |

## 16. Observability changes

None beyond the prompt text. No new logging, no change to `show_spend`, the cost ledger, or the state file.

## 17. Implementation sequence

1. Write `scripts/tests/gate-prompt-test.sh` covering G1 against the current `workflow.sh`; confirm it fails on `y` today (proves the suite has teeth).
2. Change `scripts/workflow.sh approve_file`; G1 passes.
3. Extend the suite with G2; change `scripts/change-workflow.sh human_gate`; G2 passes.
4. Extend with G3; change `scripts/stagegate.sh review_and_approve`; G3 passes.
5. Add G4 and G5.
6. Update `README.md` and `QUICK_START.md`; grep `scripts/README.md` per §4.
7. Run the full command set in §14; record results in `CHANGE_TEST_REPORT.md`.
8. Execute M-1…M-6; record in `VERIFICATION_REPORT.md`.

Steps 2, 3, and 4 each leave the tree green, so any one can be reverted alone.

## 18. Scope cuts under time pressure

Cut in this order; anything cut is stated explicitly, never silently:

1. G4 PTY bold check → manual M-1/M-6 only.
2. G3 `stagegate.sh` automated coverage → manual gate walk.
3. `README.md` table polish beyond replacing the gate-word cells.

Never cut: the three source changes, G1, the decline-path assertions in G2, and the unchanged-`close-flow-test.sh` run.

## 19. Change-impact table

| Component | Planned change | Reason | Regression risk | Test coverage |
|---|---|---|---|---|
| `scripts/change-workflow.sh` `human_gate` | Bold Y/N prompt; `y`/`Y` acceptance | B-1, I-6, I-7, I-8 | Medium — core safety gate; a loose check could advance the pipeline on stray input | G2, G5, M-3 |
| `scripts/stagegate.sh` `review_and_approve` | Same | B-2 | Medium — must not disturb the re-open loop (I-3) | G3, M-4 |
| `scripts/workflow.sh` `approve_file` | Same, exit 1 preserved | B-3, I-4 | Medium — no prior automated coverage | G1, M-1, M-2 |
| Prompt emission (`printf` instead of `read -p`) | Prompt visible under non-TTY stdin | Testability, BASELINE §13 | Low — could double-print if a `-p` string is left behind | G2 output inspection |
| ANSI bold, TTY-gated | Bold only when stdout is a terminal | I-7, CHANGE_SPEC §9 | Low — escapes leaking into logs | G4, M-5, M-6 |
| `README.md`, `QUICK_START.md` | Gate word → Y/N | B-9, criterion 6 | None | Doc read |
| `scripts/tests/gate-prompt-test.sh` (new) | New suite | Criteria 1–4 | None | Self |
| `scripts/from-issue.sh` | None | B-4, I-1a | Regression only if touched | `close-flow-test.sh` unchanged |

## 20. Traceability

| Requirement | Behavior | Invariant | Component | Automated test | Manual check |
|---|---|---|---|---|---|
| Criterion 1 (bold, names target, `[Y/N]`) | B-1, B-2, B-3, B-7 | I-7, I-8 | all three gate functions | G2, G3, G4 | M-1, M-5 |
| Criterion 2 (`y`/`Y` accepts, hash recorded) | B-1, B-2, B-3, B-5 | I-2, I-6 | all three gate functions | G1, G2, G3 | M-1, M-3 |
| Criterion 3 (other input declines, exit code kept) | B-8 | I-4, I-5, I-6 | all three gate functions | G1, G2, G3, G5 | M-2 |
| Criterion 4 (edit during review re-opens gate) | B-6 | I-3 | `stagegate.sh:219-231` | G3 (unchanged path) | M-4 |
| Criterion 5 (`RUN` gate unchanged) | B-4 | I-1a | `scripts/from-issue.sh` | `close-flow-test.sh` | — |
| Criterion 6 (docs) | B-9 | — | `README.md`, `QUICK_START.md` | — | Doc read |
| CHANGE_SPEC §10 (no whitespace-trimmed yes) | B-8 | I-6 | all three gate functions | G5 | M-2 |
| CHANGE_SPEC §10 (no ANSI in recorded state) | B-5 | I-2 | prompt emission | G4 | M-6 |

## 21. Risks and unresolved questions

| ID | Risk | Mitigation |
|---|---|---|
| R-1 | A one-keystroke gate makes accidental approval easier than a typed word — this is the requested trade-off, but it weakens the human barrier | The preceding `Press ENTER after reviewing...` prompt stays; only `y`/`Y` accepts; empty/EOF declines |
| R-2 | I-1 is REMOVED for the affected gates, which CLAUDE.md requires human approval for — CHANGE_SPEC §7 carries it and passed the approval gate | No further action; flagged here for the adversarial review |
| R-3 | `set -e` plus a failing `read` at EOF could exit non-zero and break I-4/I-5 | `\|\| true`; G1/G2/G3 assert exit codes on the EOF case |
| R-4 | Bold escapes corrupt non-TTY captures | TTY-gated escapes; G4 asserts clean piped output |
| R-5 | Edits near `scripts/agent-kimi.sh` clobber uncommitted work | That file is not in the change surface; stage per-file, never `git checkout -- .` |
| R-6 | A `close-flow-test.sh` scenario silently depends on an exact-word gate | §14 verification step; any needed edit is recorded as a deviation |
| R-7 | PTY capture for G4 may not be portable across BSD/GNU `script` | Falls back to manual M-1/M-6 recorded as NOT RUN, never as PASS |

Unresolved questions: none. BASELINE U-1…U-5 were all resolved by CHANGE_SPEC §14.
