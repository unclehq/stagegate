# Verification Report

Date: 2026-08-29
Host: darwin 25.5.0, bash 3.2.57(1)-release, `shasum -a 256`, BSD `script`.
Scope: gate-prompt UX change (`APPROVE`/`ACKNOWLEDGE` → bold `Y/N`) per `CHANGE_SPEC.md`.
All checks ran in `/tmp/stagegate-verify` scratch fixtures; no real GitHub issue was created or closed.

## Check results

| Check ID | Action performed | Expected result | Actual result | Evidence | Status | Defect |
|---|---|---|---|---|---|---|
| MC-001 | Extracted `human_gate` from `scripts/change-workflow.sh` into a scratch harness and exercised all four real call sites with `y` and `Y`. | Each gate prints one Y/N question naming every gated file, lowercases the configured action, ends `[Y/N]`, accepts `y`/`Y`, advances, and records each file's SHA-256 at `.workflow/approvals/<name>.sha256`. | All four sites accepted `y` and `Y`; prompts matched the expected form; approval files contained the correct digests and mapping. | `/tmp/stagegate-verify/cw-site{0,1,2,3}-accept-y.out`; `/tmp/stagegate-verify/cw-accept-upper-Y`; approval-file counts and `shasum -a 256` comparisons matched. | PASS | — |
| MC-002 | At representative multi-file (site 0) and single-file (site 3) `change-workflow.sh` gates, submitted `n`, `N`, `foo`, empty line, `APPROVE`, `ACKNOWLEDGE`, ` y`, EOF at the Y/N read, and EOF at the preliminary read. | Every input declines with exit 0, leaves no approval record, emits no `GATE_ACCEPTED`, legacy words print `This gate now requires 'y' to approve.`, exact-word prompt text is absent, EOF does not escape via `set -e`. | All cases exited 0, produced no approval file, showed the migration guidance for legacy words, and did not advance. | `/tmp/stagegate-verify/cw-site{0,3}-decline-*.out`, `cw-site{0,3}-eof-*.out`; `/tmp/stagegate-verify/cw-decline-N`; exit statuses and approval listings recorded. | PASS | — |
| MC-003 | Extracted `review_and_approve` from `scripts/stagegate.sh` into a scratch harness and exercised all four real call sites with `y` and `Y`. | Each gate prints a Y/N question naming the actual file, uses the lowercased configured wording, ends `[Y/N]`, accepts `y`/`Y`, advances, and records the file's SHA-256. | All four sites accepted `y` and `Y`; prompts matched the expected form; approval files contained the correct digests. | `/tmp/stagegate-verify/sg-site{0,1,2,3}-accept-y.out`; approval-file hashes matched `shasum -a 256`. | PASS | — |
| MC-004 | At representative `stagegate.sh` site 1 (`PROJECT_PLAN.md`), submitted `n`, `N`, `foo`, empty line, `APPROVE`, `ACKNOWLEDGE`, ` y`, EOF at the Y/N read, and EOF at the preliminary read. | Every input declines with exit 0, leaves no approval record, emits no `GATE_ACCEPTED`, legacy words print migration guidance, old exact-word prompt absent, EOF does not trip `set -e`. | All cases exited 0, produced no approval file, showed migration guidance for legacy words, and did not advance. | `/tmp/stagegate-verify/sg-site1-decline-*.out`, `sg-site1-eof-*.out`; exit statuses and approval listings recorded. | PASS | — |
| MC-005 | Ran `scripts/workflow.sh approve-plan`, `approve-review`, and `approve-updated-plan` with `y` and `Y`. | Each subcommand prints a Y/N question naming its actual file, ends `[Y/N]`, exits 0, and writes the captured SHA-256 to the unchanged approval path. | All three subcommands accepted `y` and `Y`; approval files matched the file digests. | `/tmp/stagegate-verify/approve-{plan,review,updated-plan}-{y,Y}.out`; `shasum -a 256` comparisons matched. | PASS | — |
| MC-006 | For every `workflow.sh approve-*` subcommand, ran separate cases with `n`, `N`, `foo`, empty line, `APPROVE`, `ACKNOWLEDGE`, ` y`, and EOF. | Each case prints `Approval cancelled.`, exits 1, creates no approval record; legacy words print migration guidance; exact-word prompts absent. | All cases exited 1, produced no approval file, and printed migration guidance for legacy words. | `/tmp/stagegate-verify/approve-{plan,review,updated-plan}-{n,N,foo,empty,APPROVE,ACKNOWLEDGE, y,eof}.out`; exit statuses and approval listings recorded. | PASS | — |
| MC-007 | Tested edit races: `workflow.sh` via FIFO mutation after prompt appearance; `change-workflow.sh` via `MUTATE_AFTER_HASH_CALL=1`; `stagegate.sh` via `MUTATE_AFTER_HASH_CALL=1` and `2`. | No approval record validates unreviewed bytes; `stagegate.sh` reopens the gate and cancels stale speculation; any retained record contains only the reviewed digest. | `workflow.sh` and `change-workflow.sh` declined with no approval; `stagegate.sh` reopened, printed `CANCEL_SPECULATION`, then accepted the reviewed bytes on the second pass. | `/tmp/stagegate-verify/race.sh` output; `/tmp/stagegate-verify/race-*.out`; no approval files recorded for mutated content. | PASS | — |
| MC-008 | Captured prompts under piped/non-TTY stdout, PTY with `TERM=xterm`, and PTY with `TERM=dumb`. | Non-TTY and `TERM=dumb` outputs contain no ANSI escape bytes; normal PTY output contains `ESC[1m` before the prompt and `ESC[0m` after it; no fatal error occurs. | Piped/TERM=dumb outputs were clean; normal PTY contained bold/reset escapes; TERM=dumb PTY was clean. | `/tmp/stagegate-verify/style.sh` output; `/tmp/stagegate-verify/style-{piped,piped-xterm,pty,pty-dumb}.out` inspected with `LC_ALL=C grep $'\\033'`. | PASS | — |
| MC-009 | Ran `scripts/from-issue.sh --change` with `RUN`, `y`, `Y`, `APPROVE`, empty line, and EOF using a stub `gh`; ran `bash scripts/tests/close-flow-test.sh`. | Only exact `RUN` starts the change workflow; other inputs decline with exit 0; prompt remains `Type RUN exactly to start the change workflow:`; `close-flow-test.sh` reports 181 checks passed unchanged. | `RUN` advanced to `change-workflow.sh` (which then failed on missing prompt file); all other inputs declined; `close-flow-test.sh` passed with 181 checks. | `/tmp/stagegate-verify/fi-{RUN,y,Y,APPROVE,empty,EOF}.out`; `close-flow-test.sh: 181 checks passed`. | PASS | — |
| MC-010 | Reviewed `README.md`, `QUICK_START.md`, and `scripts/README.md` for stale gate instructions; grepped for `APPROVE`, `ACKNOWLEDGE`, `exact word`, `requested word`. | Affected-gate docs describe `y`/`Y` acceptance with no stale instruction to type `APPROVE`/`ACKNOWLEDGE`/exact word/requested word; any `RUN` instruction is limited to `from-issue.sh`. | `README.md` and `QUICK_START.md` describe `Y/N` responses; `scripts/README.md:78` still mentions `RUN` for `from-issue.sh`, which is the preserved gate. | `grep -rnE 'Type (APPROVE|ACKNOWLEDGE)|requested word|exact word' README.md QUICK_START.md scripts/README.md`; `grep -n 'Y/N' README.md`. | PASS | — |
| MC-011 | Ran `bash scripts/tests/gate-prompt-test.sh`, `bash scripts/tests/close-flow-test.sh`, `bash scripts/tests/audit-verdict-test.sh`, `bash scripts/tests/agent-kimi-test.sh`, `bash -n scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh`, and `shellcheck scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh`. | Gate suite passes; existing suites remain at 181, 26, and 23 checks; syntax ok; shellcheck introduces no new findings beyond baseline. | `gate-prompt-test.sh`: 235 checks passed; `close-flow-test.sh`: 181; `audit-verdict-test.sh`: 26; `agent-kimi-test.sh`: 23; `bash -n`: exit 0; shellcheck findings matched baseline set (SC2034, SC2317, SC2148, SC1091, SC2059). | Command outputs captured during execution; `CHANGE_TEST_REPORT.md` corroborates. | PASS | — |
| MC-012 | For `workflow.sh`, `change-workflow.sh` extracted harness, and `stagegate.sh` extracted harness: declined once, then accepted the same gate. | Decline leaves the gate resumable with no partial approval; subsequent `y` records the reviewed digest and advances once; restarting after acceptance does not bypass the gate. | All three scripts resumed correctly after decline; the second `y` recorded the correct hash and advanced; no repeated/bypassed gate. | `/tmp/stagegate-verify/resume.sh` output; `/tmp/stagegate-verify/resume-{wf,cw,sg}-{1,2}.out`. | PASS | — |
| MC-013 | Submitted leading-space `y`, trailing-space `y`, `yes`, `YES`, tab-prefixed `y`, ANSI-prefixed `y`, and shell-metacharacter-prefixed `y` to all three affected gates. | Only exact `y`/`Y` accept; all variants decline under the preserved exit-code contract; no corruption of approval/state/log files. | Every variant declined; no approval files created; no errors or corruption. | `/tmp/stagegate-verify/strict.sh` output; `/tmp/stagegate-verify/strict-{wf,cw,sg}-*.out`. | PASS | — |
| MC-014 | Compared before/after file inventories for an accepted and a declined `workflow.sh` gate; inspected approval file format. | Approval path/format unchanged (one-line SHA-256 hex); no schema, state, origin, lock, spend, cost, or log change; declines produce no approval or state advancement. | Approval file was one 65-byte line (64 hex + newline); `ls` diff showed only the expected approval file appearing after acceptance; no state/log changes. | `/tmp/stagegate-verify/observability.sh` output; `/tmp/stagegate-verify/obs-{before-accept,after-accept,after-decline}.ls`. | PASS | — |
| MC-015 | Reverted `scripts/change-workflow.sh`, `scripts/stagegate.sh`, `scripts/workflow.sh`, `README.md`, `QUICK_START.md`, and removed the new gate test in a disposable checkout using the parent commit `f1f0dbf`. | Exact-word `APPROVE`/`ACKNOWLEDGE` prompts and acceptance are restored; `RUN` gate unchanged; existing SHA-256 approval records remain valid; unrelated files untouched. | Rolled-back `workflow.sh` accepted `APPROVE` and declined `y`; pre-rollback approval hash was still valid after rollback. | `/tmp/stagegate-verify/rollback.sh` output; `/tmp/stagegate-verify/rollback-wf-{approve,y}.out`; `workflow.sh status` showed `PROJECT_PLAN.md: APPROVED`. | PASS | — |
| MC-016 | Ran an output-aware wrapper around each affected gate and fed `APPROVE`, `approve`, `ACKNOWLEDGE`, and `acknowledge`. | Each case declines, prints explicit guidance to use `y`; `workflow.sh` wrapper exits 1; driver wrappers exit 0 but detect decline and do not advance downstream. | Output-aware wrappers detected decline in all cases; `workflow.sh` exited 1; drivers exited 0 and wrappers correctly avoided downstream work. | `/tmp/stagegate-verify/wrapper-aware.sh` output; `/tmp/stagegate-verify/wrap-{cw2,sg2}-{APPROVE,approve,ACKNOWLEDGE,acknowledge}.out`. | PASS | — |
| MC-017 | Drove the real `scripts/stagegate.sh` end-to-end from `WAIT_PLAN_APPROVAL` to the `PROJECT_PLAN.md` gate with stubbed agent/reviewer CLIs; tested decline-resume and edit-during-review. | Driver preflight, state dispatch, prompt, approval recording, and resumption operate together; edited file before `y` reopens the gate, invokes real `cancel_speculation`, and records no stale approval. | `stagegate.sh` reached the real gate, accepted `y`, recorded the correct hash, advanced state, resumed after decline, and re-opened/declined when the file was edited during review. | `/tmp/stagegate-verify/e2e-sg-debug.sh`, `/tmp/stagegate-verify/e2e-sg-decline.sh`, `/tmp/stagegate-verify/e2e-sg-edit.sh` outputs; `/tmp/stagegate-verify/e2e-sg{,2,3}.out`. | PASS | — |
| MC-018 | Compared commit `34d0f3e` against parent `f1f0dbf`; classified changed paths per `UPDATED_CHANGE_PLAN.md` §23–24. | The six implementation paths are exactly those authorized; protected runtime files and contracts have no release-caused change for the gate-prompt feature. | Gate-prompt implementation confined to `scripts/change-workflow.sh`, `scripts/stagegate.sh`, `scripts/workflow.sh`, `README.md`, `QUICK_START.md`, `scripts/tests/gate-prompt-test.sh`; `from-issue.sh` RUN gate preserved; `close-flow-test.sh` unchanged. | `git diff --name-only f1f0dbf 34d0f3e`; `git diff --stat f1f0dbf 34d0f3e`; MC-009 and MC-011 confirm protected files. | PASS | — |

## Acceptance criteria summary

| Criterion | Status | Evidence |
|---|---|---|
| 1. Affected gates print one bold prompt line naming the action/file and ending `[Y/N]`. | PASS | MC-001, MC-003, MC-005, MC-008, MC-017. |
| 2. `y`/`Y` accepts and records the approval hash as before. | PASS | MC-001, MC-003, MC-005, MC-007, MC-017. |
| 3. Other input declines and preserves exit codes. | PASS | MC-002, MC-004, MC-006, MC-013, MC-016. |
| 4. `stagegate.sh` still detects a file modified during review and reopens the gate. | PASS | MC-007, MC-017. |
| 5. `from-issue.sh` `RUN` gate continues to require exact `RUN` and passes `close-flow-test.sh`. | PASS | MC-009, MC-011. |
| 6. Docs no longer tell the user to type `APPROVE`/`ACKNOWLEDGE`. | PASS | MC-010. |

## Preserved behavior summary

- `B-4` / `I-1a`: `from-issue.sh` exact-word `RUN` gate unchanged.
- `B-5` / `I-2`: Approval SHA-256 files still written to `.workflow/approvals/<name>.sha256` only after `y`/`Y`.
- `B-6` / `I-3`: `stagegate.sh` edit-during-review still reopens the gate and cancels speculation.
- `B-8` / `I-4`/`I-5`: Decline exit codes preserved (`0` for drivers, `1` for `workflow.sh`).
- Approval file format, state/origin/lock/verdict contracts, spend/cost output, and project logs unchanged.

## Changed behavior summary

- `B-1`, `B-2`, `B-3`: Affected gates now use a bold Y/N prompt and accept only `y`/`Y`.
- `B-7`: Exact-word `APPROVE`/`ACKNOWLEDGE` prompts removed from affected gates.
- `B-9`: `README.md` and `QUICK_START.md` updated to describe Y/N responses.
- Legacy words now trigger explicit migration guidance instead of silently declining.

## Invariant summary

- `I-2` (hash recorded at acceptance), `I-3` (edit detection), `I-4`/`I-5` (decline exit codes): preserved.
- `I-6` (only `y`/`Y` accepted), `I-7` (bold prompt when TTY), `I-8` (prompt names target and offers `[Y/N]`): enforced.
- `I-1` removed for affected gates; `I-1a` preserved for `from-issue.sh`.

## Regression summary

No regressions detected. All automated suites pass at baseline counts, `from-issue.sh` and `close-flow-test.sh` are unchanged, and the new gate behavior does not alter state contracts, approval paths, or exit-code semantics.

## Unresolved defects

None introduced by this change. `DEFECTS.md` contains pre-existing unrelated items (D-1, D-2) concerning origin-binding; they were not within the scope of this verification and are not referenced by the gate-prompt checklist.

## Recommendation

Approve the gate-prompt change. All P0 and P1 manual checks pass, automated regression suites are green, and the implementation is confined to the six authorized paths.
