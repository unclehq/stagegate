# Updated Change Plan

Omitted sections: none.

This document supersedes CHANGE_PLAN.md only where noted below. CHANGE_PLAN.md
is hash-approved and immutable; sections not listed as changed apply as written
there. Behavior IDs (B-1…B-9), invariant IDs (I-1…I-8), and acceptance criteria
are from CHANGE_SPEC.md; adversarial findings are from ADVERSARIAL_REVIEW.md.

## Disposition of adversarial findings

| Finding | Disposition | Reason | Exact plan change |
|---|---|---|---|
| AR-001 — Immediate EOF bypasses the planned decline path | Accepted | The preliminary `Press ENTER` read is unguarded under `set -e`; closed stdin makes the driver exit 1 before the Y/N prompt, breaking the exit-code contract. | Guard the preliminary `read -r -p "Press ENTER..."` with `|| true` and route immediate EOF/closed stdin to the existing decline path (exit 0, no approval file). Add an automated EOF-at-preliminary-read case to G2 and G3. |
| AR-002 — Multi-file prompt design changes APPROVE into ACKNOWLEDGE and omits targets | Accepted | The cardinality-based prompt rule (one file → `approve`, several → `acknowledge`) contradicts the real full-track `WAIT_ANALYSIS_APPROVAL` call site, which is a multi-file `APPROVE` gate. | Derive the prompt verb from the actual `ACTION`/`wording` argument (lowercased via `tr`) and construct the target text from the actual file list. Update G2 to exercise every real call-site combination and assert both verb and filenames. |
| AR-003 — Approval-integrity invariants contain TOCTOU gaps | Accepted | The README claims approval records the bytes read, but `change-workflow.sh` and `workflow.sh` hash only after the response, and `stagegate.sh` recomputes a different hash after the equality check. | Capture the digest(s) shown to the operator before the Y/N prompt. After a `y` response, re-compute and compare with the captured value(s); write only the captured digest when they match. In `stagegate.sh`, record the already-validated `before` hash. If a mismatch is detected, decline (or re-open in `stagegate.sh`) instead of approving unseen bytes. Add a synchronized edit-race test to G3. |
| AR-004 — Approval tests can pass with corrupt or misassigned hashes | Accepted | The planned G1/G2/G3 checks only verify that approval files exist, not that their contents match the file bytes or that the name mapping is correct. | G1, G2, and G3 now assert each `.workflow/approvals/<name>.sha256` contains the exact `shasum -a 256` of the file bytes shown at the prompt, and assert the correct file-name-to-approval-name mapping at multi-file gates. |
| AR-005 — Legacy automation will fail silently with a successful exit status | Partially accepted | Accepting `APPROVE`/`ACKNOWLEDGE` would violate the new I-6 invariant and the requested one-keystroke safety barrier. The exit-0 decline contract for drivers is preserved, so a wrapper that checks only exit status can still silently advance. | We will not accept legacy words. Instead, detect `APPROVE`/`ACKNOWLEDGE` responses and emit an explicit "the gate now requires 'y' to approve" decline message. Update the compatibility strategy and migration docs to state that wrappers piping the old words must be updated; the new decline message makes the break observable in output. |
| AR-006 — Documentation search stopped before several stale instructions | Accepted | `README.md:96-97`, `README.md:211-212`, and `QUICK_START.md:71` still tell users to type an exact/requested word, which is wrong after the Y/N switch. | Expand documentation edits to those lines (in addition to the planned README.md gate-table cells and QUICK_START.md:20-21). Add repository-wide negative searches for `exact word` and `requested word` to the acceptance criteria and pre-implementation checks. |
| AR-007 — ANSI logging requirements contradict the planned PTY behavior | Partially accepted | The project log files are the `.workflow/logs` captures and non-TTY stdout; the gate prompt is not tee'd into those. Adding a styling configuration knob would violate CHANGE_SPEC §13. | Emit bold only when stdout is a TTY **and** `TERM` is not `dumb`. No new `NO_COLOR`-style configuration is introduced. G4 is updated to assert clean non-TTY/dumb output and bold TTY output; the PTY capture is a test harness, not a persisted log. |

## 1. Selected technical approach

A per-script local gate helper, mirroring the existing `hash_file` duplication
idiom (`scripts/change-workflow.sh:126`, `scripts/stagegate.sh:62`,
`scripts/workflow.sh:24`).

Each of the three affected scripts gets a small local helper that (a) prints one
bold prompt line naming the target and ending `[Y/N]`, (b) reads one response,
(c) returns success only for `y`/`Y`. Each call site keeps its own decline
message and exit code.

Mechanics, identical in all three:

| Concern | Decision | Reason |
|---|---|---|
| Prompt output | `printf '%s'` to stdout, not `read -p` | `read -p` suppresses the prompt when stdin is not a TTY; `scripts/from-issue.sh:124-128` already documents and uses this workaround |
| Bold | `$'\033[1m'` … `$'\033[0m'`, emitted only when `[[ -t 1 && "${TERM:-}" != "dumb" ]]` | I-7 in a real terminal; non-TTY and `TERM=dumb` output stay clean (AR-007) |
| Preliminary read | `IFS= read -r _ack \|\| true`, then test exit status and decline on EOF | AR-001; keeps `set -e` from breaking the exit-code contract |
| Read (Y/N) | `IFS= read -r response \|\| true` | `IFS=` stops `read` from stripping surrounding whitespace, so `" y"` declines (CHANGE_SPEC §10); `\|\| true` keeps EOF from tripping `set -e` and breaking the exit-code contract (I-4, I-5) |
| Acceptance | `case "$response" in y\|Y) ... ;; *) decline ;; esac` | I-6; bash 3.2 has no `${var,,}` |
| Verb | action/wording lowercased via `tr '[:upper:]' '[:lower:]'` | bash 3.2 has no `${var^}`; keeps `human_gate APPROVE/ACKNOWLEDGE` call sites unchanged |
| Target list | actual `${files[@]}` joined with `, ` | AR-002; the prompt names every file the gate covers |
| Captured digest | computed before the prompt, re-checked after `y`, then written | AR-003, AR-004; the approval record matches the bytes the operator saw |

Prompt text:

| Script | Prompt |
|---|---|
| `change-workflow.sh` | `Ready to <verb> <file1>[, <file2>...]? [Y/N] `, where `<verb>` is the lowercased `ACTION` argument |
| `stagegate.sh` | `Ready to <wording> <file>? [Y/N] `, where `<wording>` is the lowercased `wording` argument |
| `workflow.sh` | `Ready to approve <file>? [Y/N] ` |

The preceding `Press ENTER after reviewing...` prompt, the banners, hash
recording, and `stagegate.sh` edit detection are otherwise untouched.

## 2. Alternative approaches considered

Unchanged from CHANGE_PLAN.md § 2.

## 3. Why the selected approach is preferred

Unchanged from CHANGE_PLAN.md § 3.

## 4. Exact components to modify

| Component | Location | Edit |
|---|---|---|
| `human_gate` | `scripts/change-workflow.sh:388-406` | Guard the preliminary read for EOF; capture file hashes before the prompt; replace the exact-word prompt with the bold Y/N prompt; compare post-response hashes with captured hashes; write captured hashes on match; add a local helper near `hash_file` (`:126`) |
| `review_and_approve` | `scripts/stagegate.sh:209-234` | Guard the preliminary read for EOF; replace the exact-word prompt with the bold Y/N prompt; after the before/after hash check passes, write the already-captured `before` hash; add a local helper near `upper`/`hash_file` (`:62`) |
| `approve_file` | `scripts/workflow.sh:37-49` | Capture the file hash before the prompt (the value already printed); replace the exact-word prompt with the bold Y/N prompt; compare post-response hash with the captured hash; write the captured hash on match; add a local helper near `hash_file` (`:24`) |
| `README.md` gate columns | `:167-170`, `:184-186` | Replace `APPROVE`/`ACKNOWLEDGE` cells with `Y/N` |
| `README.md` stale instructions | `:96-97`, `:211-212` | Replace exact-word/requested-word instructions with the Y/N contract |
| `QUICK_START.md` | `:20-21`, `:71` | Replace "Type the requested word..." with the Y/N answer |
| New test suite | `scripts/tests/gate-prompt-test.sh` | §13 |

`scripts/README.md` names no gate word (its `workflow.sh` section, `:45-61`,
describes subcommands only). Confirm with `grep -nE 'APPROVE|ACKNOWLEDGE|exact word|requested word' scripts/README.md` before concluding acceptance criterion 9 is met there; edit only if a hit appears, and record the deviation.

## 5. Components explicitly not to modify

Unchanged from CHANGE_PLAN.md § 5.

## 6. Data-flow changes

Only the operator-input branch changes: gate input is classified as
yes/not-yes. In addition, the approval digest now flows from a pre-prompt
capture through a post-response integrity check to the approval record, rather
than being recomputed after the response. ANSI bytes exist only in the stdout
prompt when stdout is a TTY and `TERM` is not `dumb`; nothing downstream
consumes them (CHANGE_SPEC §10).

## 7. State-transition changes

None. Accepted gates still record hashes and let the caller advance state;
declined gates still exit before `set_state`. `stagegate.sh` still loops back to
re-open the gate when the file changed during review (I-3, B-6). The new
post-response hash check in `change-workflow.sh` and `workflow.sh` only affects
whether a gate with a mutated file transitions to `accept` or `decline`; the set
of reachable states is unchanged.

## 8. Interface and API changes

| Interface | Before | After |
|---|---|---|
| `human_gate ACTION file name ...` | `ACTION` is typed verbatim by the operator | `ACTION` supplies the prompt verb only; signature unchanged |
| `review_and_approve file name [wording]` | `wording` uppercased and typed verbatim | `wording` supplies the prompt verb (lowercased); signature and default unchanged |
| `workflow.sh approve-*` | Requires typed `APPROVE` | Requires `y`/`Y`; subcommands and exit codes unchanged |
| Operator contract | Type `APPROVE`/`ACKNOWLEDGE` | Type `y` or `Y`; anything else declines — intentional UX break (CHANGE_SPEC §8) |
| Legacy-word input | Declined silently | Declined with an explicit "use 'y' to approve" message (AR-005) |

## 9. Compatibility strategy

- Decline exit codes preserved: `0` for the two drivers, `1` for `workflow.sh` (I-4, I-5).
- Approval file path and format unchanged (I-2).
- `from-issue.sh` unchanged, so `close-flow-test.sh` must pass without edits (B-4, acceptance criterion 8).
- Any external script piping `APPROVE`/`ACKNOWLEDGE` into a driver breaks by design; the docs edits and the new legacy-word decline message are the migration notice.
- No new configuration file, environment variable, or styling knob is introduced; `TERM=dumb` and non-TTY output stay free of ANSI (AR-007).

## 10. Error and recovery behavior

| Input | Result |
|---|---|
| `y`, `Y` | Gate accepts; captured hashes recorded |
| `n`, `N`, arbitrary text | Decline message, existing exit code |
| `APPROVE`, `ACKNOWLEDGE` | Decline message plus "the gate now requires 'y' to approve", existing exit code |
| Empty line | Decline |
| EOF / closed stdin at the Y/N read | `read` fails, `\|\| true` keeps `set -e` from firing, empty response declines with the existing exit code |
| EOF / closed stdin at the preliminary read | Preliminary `read` fails, `\|\| true` keeps `set -e` from firing, driver declines with exit 0 and no approval file |
| ` y` (leading space) | Decline — `IFS=` preserves the space |
| Terminal without bold / `TERM=dumb` | `[[ -t 1 && "${TERM:-}" != "dumb" ]]` is false; plain readable prompt, no error |
| File changed between prompt and `y` in `change-workflow.sh`/`workflow.sh` | Decline; no hash file written |
| File changed during `stagegate.sh` review (before response) | Unchanged: gate re-opens, speculation cancelled |
| File changed between response and recording in `stagegate.sh` | The captured `before` hash is written only when it matches the post-response hash; otherwise the gate re-opens |

## 11. Rollback plan

Unchanged from CHANGE_PLAN.md § 11.

## 12. Feature-flag or containment strategy

No flag. A configuration knob for prompt wording, case sensitivity, or styling
is an explicit non-goal (CHANGE_SPEC §13); containment is the single-commit
revert in §11. Existing environment variables (`TERM`) continue to be honored
for terminal capability detection, but no new styling opt-in/opt-out is added.

## 13. Automated-test strategy

New hermetic suite `scripts/tests/gate-prompt-test.sh`, in the style of
`close-flow-test.sh` (scratch repo, stubbed agent CLIs via
`WORKFLOW_AGENT_CMD`/`WORKFLOW_REVIEWER_CMD`, captured stdout):

| Group | Target | Checks |
|---|---|---|
| G1 | `workflow.sh approve-plan` in a temp dir | `y` and `Y` → captured hash file written, exit 0; `n`, `N`, `foo`, empty, EOF, `APPROVE`, and `ACKNOWLEDGE` → "Approval cancelled." plus legacy guidance, exit 1, no hash file; exact digest matches `shasum -a 256`; mutating the file after the prompt declines |
| G2 | `change-workflow.sh` at every real call site (`WAIT_ANALYSIS_APPROVAL` small-track ACKNOWLEDGE 4 files, full-track APPROVE 2 files, `WAIT_PLAN_APPROVAL` ACKNOWLEDGE 2 files, `WAIT_UPDATED_PLAN_APPROVAL` APPROVE 1 file) | Prompt contains the lowercased verb, every filename, and `[Y/N]`; ENTER+`y` records every captured hash with the correct approval-name mapping; `n`/empty/EOF at Y/N and EOF at the preliminary read → "Gate not accepted", exit 0, no hash file; exact digests match `shasum -a 256`; `APPROVE`/`ACKNOWLEDGE` produce legacy guidance |
| G3 | `stagegate.sh` at `WAIT_REQUIREMENTS_APPROVAL`, `WAIT_PLAN_APPROVAL`, `WAIT_REVIEW_ACKNOWLEDgement`, and `WAIT_UPDATED_PLAN_APPROVAL` | Same accept/decline matrix as G2, exit 0 on decline; exact digest matches `shasum -a 256`; file modified before the response re-opens the gate; file modified between response and recording re-opens/declines instead of writing a mismatched hash |
| G4 | Styling | Piped stdout and `TERM=dumb` output contain no `\033`; PTY run (`script -q /dev/null …`) with a normal `TERM` contains `\033[1m` before the prompt and `\033[0m` after |
| G5 | Whitespace strictness | `" y"` declines |

G4 note: `script` argument syntax differs between BSD and GNU. If the PTY
capture is not reliable on the implementation host, the check is recorded NOT
RUN and moved to §15 as a manual PTY check — it is not to be relaxed into a
pass (core rule 10).

Before wiring G3, confirm whether `speculate` at each gate requires a reviewer
stub; if stubbing proves unreliable, invoke `review_and_approve` through a
driver run with the speculation stage already satisfied rather than weakening
the assertion.

## 14. Regression-test strategy

This is a feature change, not a bug fix, so there is no pre-existing failing
test to point at. The equivalent guard: G1-G3 assert the decline path (no hash
file, correct exit code) for `n`, arbitrary text, empty, EOF, and legacy words,
which is where a too-permissive check would show up. Existing suites re-run
unchanged:

```
bash scripts/tests/gate-prompt-test.sh     # new
bash scripts/tests/close-flow-test.sh      # 181 checks — must stay 181, RUN gate untouched
bash scripts/tests/audit-verdict-test.sh   # 26 checks
bash scripts/tests/agent-kimi-test.sh      # 23 checks
bash -n scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh
shellcheck scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh   # no new findings beyond BASELINE §10
```

Also confirm no `close-flow-test.sh` scenario reaches a `human_gate`; if one
does, its piped input must change from the exact word to `y` and that is a
material deviation to record.

## 15. Manual-verification strategy

`scripts/workflow.sh` has no prior automated coverage (BASELINE §13), and bold
is a terminal property, so these run by hand in a real terminal:

| ID | Action | Expected |
|---|---|---|
| M-1 | Run `./scripts/workflow.sh approve-plan` in a scratch checkout, answer `y` | Prompt line renders bold, ends `[Y/N]`, names `PROJECT_PLAN.md`; approval recorded |
| M-2 | Repeat, answer `n`, then repeat and answer `APPROVE` | "Approval cancelled.", exit 1 both times; `APPROVE` run also prints legacy guidance; no hash file |
| M-3 | Drive `change-workflow.sh` to a live gate, answer `y` | Bold prompt names all gated files with the correct verb; hashes recorded; pipeline advances |
| M-4 | At a `stagegate.sh` gate, edit the file in another terminal before answering `y` | Gate re-opens with the changed-file message (I-3) |
| M-5 | Run a gate in a terminal without bold support (or `TERM=dumb`) | Prompt readable, no error, no escape bytes |
| M-6 | `cat` a captured non-TTY gate log | No escape bytes |
| M-7 | Edit a gated file between the prompt and the `y` answer in `workflow.sh`/`change-workflow.sh` | Gate declines, no approval file written |
| M-8 | At a `stagegate.sh` gate, edit the file after answering `y` but before the recording step | Gate re-opens or declines; the approval file does not contain a mismatched hash |

## 16. Observability changes

Unchanged from CHANGE_PLAN.md § 16.

## 17. Implementation sequence

1. Write `scripts/tests/gate-prompt-test.sh` covering G1 against the current `workflow.sh`; confirm it fails on `y` today (proves the suite has teeth).
2. Change `scripts/workflow.sh approve_file` with hash capture; G1 passes.
3. Extend the suite with G2; change `scripts/change-workflow.sh human_gate`; G2 passes.
4. Extend with G3; change `scripts/stagegate.sh review_and_approve`; G3 passes.
5. Add G4 and G5.
6. Add legacy-word guidance decline message to the three gate functions.
7. Update `README.md` and `QUICK_START.md`; grep `scripts/README.md` per §4.
8. Run the full command set in §14; record results in `CHANGE_TEST_REPORT.md`.
9. Execute M-1…M-8; record in `VERIFICATION_REPORT.md`.

Steps 2, 3, and 4 each leave the tree green, so any one can be reverted alone.

## 18. Scope cuts under time pressure

Unchanged from CHANGE_PLAN.md § 18.

## 19. Change-impact table

| Component | Planned change | Reason | Regression risk | Test coverage |
|---|---|---|---|---|
| `scripts/change-workflow.sh` `human_gate` | Bold Y/N prompt; `y`/`Y` acceptance; EOF guard; captured-digest recording | B-1, I-6, I-7, I-8, AR-001, AR-002, AR-003, AR-004 | Medium — core safety gate; a loose check could advance the pipeline on stray input | G2, G5, M-3, M-7 |
| `scripts/stagegate.sh` `review_and_approve` | Same, plus write captured `before` hash | B-2, AR-003 | Medium — must not disturb the re-open loop (I-3) | G3, M-4, M-8 |
| `scripts/workflow.sh` `approve_file` | Same, captured-digest recording | B-3, I-4, AR-003, AR-004 | Medium — no prior automated coverage | G1, M-1, M-2, M-7 |
| Prompt emission (`printf` instead of `read -p`) | Prompt visible under non-TTY stdin | Testability, BASELINE §13 | Low — could double-print if a `-p` string is left behind | G2 output inspection |
| ANSI bold, TTY/dumb-gated | Bold only when stdout is a terminal and `TERM` is not `dumb` | I-7, CHANGE_SPEC §9, AR-007 | Low — escapes leaking into logs | G4, M-5, M-6 |
| Legacy-word decline guidance | Detect `APPROVE`/`ACKNOWLEDGE` and emit guidance | AR-005 | Low — message only | G1, G2, M-2 |
| `README.md`, `QUICK_START.md` | Gate word → Y/N; remove stale exact-word instructions | B-9, AR-006, criterion 9 | None | Doc read + grep |
| `scripts/tests/gate-prompt-test.sh` (new) | New suite | Criteria 1–4, AR-001–AR-004 | None | Self |
| `scripts/from-issue.sh` | None | B-4, I-1a | Regression only if touched | `close-flow-test.sh` unchanged |

## 20. Traceability

| Requirement | Behavior | Invariant | Component | Automated test | Manual check |
|---|---|---|---|---|---|
| Criterion 1 (bold, names target, `[Y/N]`) | B-1, B-2, B-3, B-7 | I-7, I-8 | all three gate functions | G2, G3, G4 | M-1, M-5 |
| Criterion 2 (`y`/`Y` accepts, captured hash recorded) | B-1, B-2, B-3, B-5 | I-2, I-6 | all three gate functions | G1, G2, G3 | M-1, M-3 |
| Criterion 3 (other input declines, exit code kept) | B-8 | I-4, I-5, I-6 | all three gate functions | G1, G2, G3, G5 | M-2 |
| Criterion 4 (edit during review re-opens gate) | B-6 | I-3 | `stagegate.sh` before/after compare | G3 | M-4, M-8 |
| Criterion 5 (`RUN` gate unchanged) | B-4 | I-1a | `scripts/from-issue.sh` | `close-flow-test.sh` | — |
| Criterion 6 (docs) | B-9 | — | `README.md`, `QUICK_START.md`, `scripts/README.md` | — | Doc read + grep |
| Criterion 7 (captured-digest integrity) | B-5 | I-2 | all three gate functions | G1, G2, G3 | M-7, M-8 |
| Criterion 8 (ANSI not in logs/non-TTY) | B-7 | I-7 | prompt emission | G4 | M-5, M-6 |
| AR-001 (EOF at preliminary read declines) | B-8 | I-5 | `change-workflow.sh`, `stagegate.sh` | G2, G3 | — |
| AR-002 (prompt verb from action, names files) | B-1 | I-8 | `change-workflow.sh` | G2 | M-3 |
| AR-005 (legacy-word guidance) | B-8 | I-6 | all three gate functions | G1, G2 | M-2 |

## 21. Risks and unresolved questions

| ID | Risk | Mitigation |
|---|---|---|
| R-1 | A one-keystroke gate makes accidental approval easier than a typed word — this is the requested trade-off, but it weakens the human barrier | The preceding `Press ENTER after reviewing...` prompt stays; only `y`/`Y` accepts; empty/EOF declines |
| R-2 | I-1 is REMOVED for the affected gates, which CLAUDE.md requires human approval for — CHANGE_SPEC §7 carries it and passed the approval gate | No further action; flagged here for the adversarial review |
| R-3 | `set -e` plus a failing `read` at EOF could exit non-zero and break I-4/I-5 | `\|\| true` on both reads; G1/G2/G3 assert exit codes on the EOF case |
| R-4 | Bold escapes corrupt non-TTY captures | TTY/dumb-gated escapes; G4 asserts clean piped output |
| R-5 | Edits near `scripts/agent-kimi.sh` clobber uncommitted work | That file is not in the change surface; stage per-file, never `git checkout -- .` |
| R-6 | A `close-flow-test.sh` scenario silently depends on an exact-word gate | §14 verification step; any needed edit is recorded as a deviation |
| R-7 | PTY capture for G4 may not be portable across BSD/GNU `script` | Falls back to manual M-1/M-5 recorded as NOT RUN, never as PASS |
| R-8 | External wrappers that piped `APPROVE`/`ACKNOWLEDGE` continue after exit 0 | Documented compatibility break; new decline message makes the failure observable in output, but exit-status-only wrappers must be updated (AR-005) |

Unresolved questions: none. BASELINE U-1…U-5 were all resolved by CHANGE_SPEC §14.
The adversarial findings AR-001…AR-007 are resolved in the disposition table
above.

## 22. Frozen change scope

This delivery is bounded to:

- Converting the three affected gate functions (`human_gate`,
  `review_and_approve`, `approve_file`) to bold Y/N prompts that accept only
  `y`/`Y`.
- Guarding EOF/closed stdin at the preliminary `Press ENTER` read so it
  declines cleanly.
- Deriving the prompt verb from the action argument and naming the actual
  gated file(s).
- Hardening approval-hash recording so the written digest matches the bytes
  shown to the operator.
- Updating user-facing gate documentation and adding the new automated test
  suite.

Anything outside this boundary — including changes to `from-issue.sh`, the
`.workflow` state/lock/verdict contracts, the approval hash algorithm or
storage path, or speculative-execution model — is out of scope unless a new
blocker is discovered and recorded.

## 23. Files expected to change

- `scripts/change-workflow.sh`
- `scripts/stagegate.sh`
- `scripts/workflow.sh`
- `README.md`
- `QUICK_START.md`
- `scripts/tests/gate-prompt-test.sh` (new)

## 24. Files that must not change

- `scripts/from-issue.sh`
- `scripts/tests/close-flow-test.sh`
- `scripts/agent-kimi.sh`
- `scripts/tests/agent-kimi-test.sh`
- `scripts/lib/*`
- `.workflow/state`, `.workflow/origin`, `.workflow/audit-verdict`, and `.workflow/lock` contracts
- `prompts/*`
- `scripts/README.md` unless the pre-implementation grep finds stale gate instructions; any such edit is a recorded deviation

## 25. Expected behavioral differences

- The operator answers `y` or `Y` to approve; any other input declines.
- Prompts are bold in a real terminal, plain in non-TTY or `TERM=dumb` mode,
  and explicitly name the action and the gated file(s).
- EOF or closed stdin at the preliminary `Press ENTER` read declines with the
  preserved exit code instead of failing under `set -e`.
- `APPROVE`/`ACKNOWLEDGE` responses produce an explicit "use 'y' to approve"
  decline message.
- If a gated file changes between the prompt and the operator's `y`, the gate
  declines (or re-opens in `stagegate.sh`) rather than recording the changed
  bytes.
- Documentation describes the Y/N contract instead of exact-word typing.

## 26. Expected unchanged behavior

- Exit codes on decline: `0` for `change-workflow.sh` and `stagegate.sh`, `1`
  for `scripts/workflow.sh`.
- Approval hash file path and format: `.workflow/approvals/<name>.sha256`.
- State machine progression, `stagegate.sh` re-open loop, and speculative
  execution.
- `from-issue.sh` `RUN` gate semantics and `close-flow-test.sh` results.
- No ANSI in non-TTY/dumb output or in project log files.
- All other driver behavior not listed in §25.

## 27. Exact acceptance criteria

1. Each affected gate prints exactly one prompt line that is bold when stdout
   is a TTY and `TERM` is not `dumb`, states the action and the gated file(s),
   and ends with `[Y/N]`.
2. Input `y` or `Y` accepts and writes the captured SHA-256 digest to the
   correct approval file(s).
3. Input `n`, `N`, any other text (including `APPROVE`/`ACKNOWLEDGE`), empty
   input, EOF at the Y/N read, and EOF at the preliminary read all decline
   with the preserved exit code.
4. Leading whitespace (` y`) declines.
5. `stagegate.sh` re-opens the gate when the gated file changes before the
   operator responds; no approval file is written for that attempt.
6. `stagegate.sh` re-opens or declines when the gated file changes between the
   response and the recording step; the approval file does not contain a
   mismatched hash.
7. `change-workflow.sh` and `workflow.sh` decline when the gated file changes
   between the prompt and the response.
8. `from-issue.sh` continues to require exact `RUN`, and
   `bash scripts/tests/close-flow-test.sh` passes unchanged.
9. `README.md`, `QUICK_START.md`, and `scripts/README.md` contain no
   instructions to type `APPROVE`, `ACKNOWLEDGE`, `exact word`, or
   `requested word`; they describe the `y`/`Y` contract.
10. Every approval file contains the exact `shasum -a 256` digest of the file
    bytes shown at the prompt and maps to the correct approval name.
11. Non-TTY stdout and `TERM=dumb` output contain no ANSI escape bytes; TTY
    output with a normal `TERM` contains the bold escape sequence around the
    prompt.

## 28. Pre-implementation checks

- Run the new `scripts/tests/gate-prompt-test.sh` against the current tree and
  confirm it fails where expected (proves the suite has teeth).
- Run `bash scripts/tests/close-flow-test.sh` against the current tree and
  confirm it passes.
- Inventory every `human_gate`, `review_and_approve`, and `approve_file` call
  site and record the action/wording and file list for each.
- Grep the repository for `APPROVE`, `ACKNOWLEDGE`, `exact word`, and
  `requested word` and record every user-facing hit.
- Verify `scripts/README.md` gate instructions with the above grep.
- Confirm the implementation host has `bash` 3.2+, `shasum -a 256`, and either
  `script` or an equivalent PTY fallback for G4.

## 29. Post-implementation checks

- Run `bash scripts/tests/gate-prompt-test.sh` and confirm all groups pass.
- Run the regression command set in §14 and confirm results are unchanged or
  deviations are recorded.
- Run the repository-wide doc grep checks in §27 criterion 9 and confirm no
  stale gate instructions remain.
- Execute the manual checks in §15 and record results in
  `VERIFICATION_REPORT.md`.
- Record automated test results in `CHANGE_TEST_REPORT.md`.

## 30. First features to cut if time expires

1. G4 automated PTY bold check → rely on manual M-1 and M-5.
2. G3 `stagegate.sh` edit-race automated coverage → rely on manual M-4 and
   M-8.
3. `README.md` table polish beyond replacing the gate-word cells.

Never cut: the three source changes, G1, the exact-digest assertions, the
EOF-at-preliminary-read handling, the legacy-word decline message, the
doc-stale-instruction acceptance criterion, or the `close-flow-test.sh` run.

## 31. Conditions that require stopping implementation

- Any check shows that input other than `y`/`Y` (including whitespace-trimmed
  input) can advance a gate.
- Any check shows that EOF/closed stdin produces a non-preserved exit code or
  creates an approval file.
- Any check shows ANSI escape bytes in an approval file, state file, non-TTY
  stdout, or `TERM=dumb` output.
- Hardening the approval-hash recording would require changing the approval
  file path/format or any `.workflow` contract.
- `bash scripts/tests/close-flow-test.sh` fails due to a change in this scope
  and the cause cannot be fixed without modifying `from-issue.sh`.
- A human gate decision or spec change contradicts the frozen scope in §22.
- The implementation host lacks a required tool and manual checks cannot cover
  the required surface.
