# Change Plan

Omitted sections: 13 Migration plan (nothing persisted is migrated; the one
new state file is created fresh and treated as absent-if-missing).

## 1. Selected technical approach

Three edits plus docs, in one commit series:

1. **New pure classifier** `scripts/lib/audit-verdict.sh` — sourceable file
   defining `classify_audit_verdict <file>`, echoing exactly one of
   `READY`, `READY_WITH_NON_BLOCKING_ISSUES`, `NOT_READY`, `UNKNOWN`.
   Algorithm: take the **last** line of `FINAL_AUDIT.md` containing any of the
   three verdict phrases; classify it with an ordered `case`
   (`NOT READY` → `READY WITH NON-BLOCKING ISSUES` → `READY`); if that line
   matches more than one phrase, or no line matches, return `UNKNOWN`.
   Fail-closed: `UNKNOWN` never closes an issue.
2. **`change-workflow.sh`** — source the classifier; in the `FINAL_AUDIT`
   state, immediately after `run_codex` writes `FINAL_AUDIT.md`, write
   `.workflow/audit-verdict` as one TSV line: `<run-id>\t<verdict-class>`,
   where `<run-id>` is `${STAGEGATE_RUN_ID:--}`. `COMPLETE` is otherwise
   untouched and still `exit 0`s (B-10, §8 compat).
3. **`from-issue.sh`** — on the `--change` path only, after
   `write_change_request`: print the seeded file, print the pre-flight
   warnings, require an exact-word confirmation, then run
   `"$ROOT/scripts/change-workflow.sh"` in the foreground with a generated
   `STAGEGATE_RUN_ID` exported; on return, read `.workflow/audit-verdict`
   and close the issue only if the run id matches and the class is
   `READY` or `READY_WITH_NON_BLOCKING_ISSUES`.
4. **Docs** — `README.md:114-133`, `scripts/README.md:63-82`.

The run id is the load-bearing detail. `.workflow/state` is persistent and
`COMPLETE` is re-enterable, so a stale `FINAL_AUDIT.md` from an earlier
change is otherwise indistinguishable from one this run produced. Pairing
the verdict with the id of the run that wrote it makes "did *this*
invocation audit *this* change" decidable without deleting prior state
(core rule 13).

## 2. Alternative approaches considered

| # | Approach | Rejected because |
|---|---|---|
| A | `from-issue.sh` parses `FINAL_AUDIT.md` itself; driver untouched | Cannot tell a fresh audit from a stale one; duplicates verdict vocabulary in a second file; leaves I-06 unstrengthened (spec B-10 requires the signal to come from the driver) |
| B | Exit-code convention (`exit 2` on `NOT READY`) | Breaks §8 compat for standalone callers and any `set -e` wrapper; spec fixes `COMPLETE` at `exit 0` |
| C | `change-workflow.sh --audit-verdict` query subcommand | Breaks the documented "takes no positional arguments" contract (`scripts/README.md:117-124`), which §8 freezes |
| D | Classifier inline in `change-workflow.sh`, no lib, no test | The whole I-08 safety story rests on this ~12-line function; inline in a 700-line state machine it is unreachable by any automated check |
| E | `exec` the driver from `from-issue.sh` | Cannot close the issue afterwards — the process is gone |
| F | Close from inside `change-workflow.sh`'s `COMPLETE` state | Driver has no issue identity (BASELINE §15) and no GitHub capability today; would spread the I-05 relaxation across two scripts instead of one call site (§10) |

## 3. Why the selected approach is preferred

Confines the I-05 relaxation to one call site in one script (§10); leaves the
driver's CLI contract, human gates, and approval hashing untouched (I-01–I-03);
puts the only non-trivial logic in a pure function that a test can drive; and
fails closed at every branch — no verdict file, no run-id match, `UNKNOWN`
class, non-zero driver exit, or missing `gh` all mean "do not close."

## 4. Exact components to modify

| Component | Anchor | Edit |
|---|---|---|
| `scripts/lib/audit-verdict.sh` | new | `classify_audit_verdict()` |
| `scripts/tests/audit-verdict-test.sh` | new | fixture assertions for the classifier |
| `scripts/change-workflow.sh` | after `hash_file`, ~line 114 | source the lib (self-relative, I-04) |
| `scripts/change-workflow.sh` | `FINAL_AUDIT`, 663-670 | write `.workflow/audit-verdict`; echo the class |
| `scripts/from-issue.sh` | `write_change_request`, 206-208 | drop the trailing `Run:` hint from the writer (moves to the decline path) |
| `scripts/from-issue.sh` | fetch block, 94-100 | set `USED_GH=1` only when `fetch_with_gh` produced the JSON |
| `scripts/from-issue.sh` | new fns before dispatch | `confirm_and_run_workflow()`, `close_issue_if_ready()` |
| `scripts/from-issue.sh` | dispatch, 300-303 | `change)` branch calls the two new functions |
| `README.md` | 114-133 | document the confirmation + auto-run + auto-close flow |
| `scripts/README.md` | 63-82 | same, plus the `gh`-required-for-close note |

## 5. Components explicitly not to modify

`scripts/stagegate.sh`, `scripts/workflow.sh`, `scripts/codex-review-plan.sh`,
`scripts/codex-create-checklist.sh`, `prompts/**` (including
`prompts/change/final-audit.md` — the verdict vocabulary is read, not
changed), `human_gate()`, `verify_approval()`, `get_state`/`set_state`, the
`COMPLETE` state's existing output and `exit 0`, `write_new_project_brief()`,
the `CHANGE_REQUEST.md` template body, the argument-handling table
(`scripts/README.md:115-133` — no new flags on any script).

## 6. Data-flow changes

New, one direction only:

```
from-issue.sh: generate RUN_ID ──export STAGEGATE_RUN_ID──> change-workflow.sh
change-workflow.sh FINAL_AUDIT: FINAL_AUDIT.md ──classify──> .workflow/audit-verdict
                                                              ("<RUN_ID>\t<CLASS>")
from-issue.sh (after driver returns) ──read+match RUN_ID──> gh issue close
```

`USED_GH` (set at fetch, read at close) is the second new flow. Nothing else
changes: `CHANGE_REQUEST.md` content, `.workflow/state`, approvals, logs, and
the cost ledger are byte-identical in shape.

## 7. State-transition changes

None to the state machine. `ANALYZE → … → FINAL_AUDIT → COMPLETE` is
unchanged; no state is added, removed, or reordered. `FINAL_AUDIT` gains one
side effect (write the verdict file) after its existing `run_codex` and
before its existing `set_state COMPLETE`.

`from-issue.sh` gains a linear post-write sequence: `seeded → confirm? →
(decline: print hint, exit 0) | (accept: run driver → verdict? → close | skip)`.

## 8. Interface and API changes

| Surface | Change |
|---|---|
| `from-issue.sh` CLI flags | none — no new flags (B-09, §8) |
| `from-issue.sh --change` stdout | `Run:` hint moves from the success path to the decline path; adds the seeded-file echo, warnings, prompt, driver output, close/skip message |
| `from-issue.sh --new` | none (B-08) |
| `from-issue.sh` exit codes | 0 on decline and on completed-run-with-close-skipped; non-zero if the driver fails or `gh issue close` fails |
| `change-workflow.sh` CLI | none (`-h`, `--version`, unknown-arg, no positionals all unchanged) |
| `change-workflow.sh` env | reads new optional `STAGEGATE_RUN_ID`; absent → writes `-` |
| GitHub | new write: `gh issue close --comment` (I-05 RELAXED) |

## 9. Schema or persistence changes

One new file, `.workflow/audit-verdict` (gitignored, alongside `state` and
`cost.tsv`): a single line, `<run-id>TAB<class>`, overwritten each time
`FINAL_AUDIT` runs. No reader other than `from-issue.sh`; absent file is
always valid and means "no verdict from this run." No existing file format
changes.

## 10. Compatibility strategy

- `--new` path untouched (B-08); verified by diffing its output against the
  current script's.
- `change-workflow.sh` standalone: unchanged CLI, unchanged `COMPLETE`
  output apart from one added verdict line, unchanged `exit 0` (B-10).
  Running it by hand never sets `STAGEGATE_RUN_ID`, so the verdict file
  records `-` and can never satisfy a later close check.
- **Non-interactive callers.** Spec §8 anticipates scripted callers of
  `from-issue.sh --change` blocking on the new prompt. This plan instead
  checks `[ -t 0 ]` first: with no TTY, print the seeded-file notice and the
  `Run:` hint and exit 0 — the pre-change behavior. This is the §9 rule
  "EOF/non-exact input → treat as decline (B-03)" applied before the read
  rather than after it, and it is strictly safer than blocking a headless
  job forever. It is *not* a `--yes` bypass (§12 non-goal): the no-TTY
  direction is decline, never auto-run. **Flagged for the reviewer as a
  deliberate softening of §8's stated expectation.**

## 11. Concurrency implications

`.workflow/` was already single-writer — two concurrent drivers in one
checkout share `.workflow/state` and corrupt each other today. The verdict
file inherits that assumption and adds no new sharing. The run-id match means
a concurrent second driver writing the file cannot cause a *false* close (ids
differ); worst case it causes a missed close, which is the safe direction.
Single `printf` write; no locking added.

## 12. Error and recovery behavior

| Condition | Behavior | Spec ref |
|---|---|---|
| No TTY on stdin | print seeded file + `Run:` hint, exit 0, no driver, no close | §10 above, B-03 |
| Prompt gets EOF or non-exact input | decline: hint, exit 0, no driver, no close | §9, B-03 |
| Driver exits non-zero | report the failure plainly, no close, propagate non-zero | §9, B-06 |
| Driver exits 0 via a **declined internal gate** (`change-workflow.sh:226`) | no verdict file for this run id → no close | B-06 |
| Driver exits 0 from a stale `COMPLETE` state | `FINAL_AUDIT` never ran this invocation → no matching verdict → no close | B-06 |
| `.workflow/audit-verdict` missing, malformed, or run id mismatched | no close; print why | I-08 |
| Class is `NOT_READY` or `UNKNOWN` | issue left open; print the verdict and why | B-05, I-08 |
| Fetch used the `curl` fallback (`USED_GH=0`) | skip close, explicit message, exit reflects the successful run | B-07, I-09 |
| `gh` missing or unauthenticated at close time | same as above — skip + message, not a hard failure | §9, I-09 |
| `gh issue close` itself fails | print the error, exit non-zero, and state explicitly that the workflow completed and only the close failed | §9 |

Implementation traps to respect (both are `set -euo pipefail` scripts):
`read` returns non-zero on EOF, and `gh auth status` returns non-zero when
logged out — both must be wrapped in `if !` / `|| true`, never left bare.

## 14. Rollback plan

1. `git revert` the change's commits (or `git checkout <prev> -- scripts/
   README.md scripts/README.md`). `from-issue.sh` returns to
   write-and-print; `change-workflow.sh` returns to a silent `COMPLETE`.
2. Delete `scripts/lib/audit-verdict.sh`, `scripts/tests/`, and
   `.workflow/audit-verdict` if present. Nothing reads the verdict file after
   the revert; leaving it is harmless.
3. No data migration, no `.workflow/state` reset, no approval-hash
   invalidation — none of those formats changed (§9, spec §11).
4. Already-closed GitHub issues are **not** reopened by a rollback; reopen by
   hand if required. This is the only non-code-reversible effect of the
   change.

## 15. Feature-flag or containment strategy

No new flag or env toggle (unrequested surface). Containment is structural:
the auto-run reaches only the `--change` branch of the dispatch; the GitHub
write exists at exactly one call site; and four independent conditions must
all hold to reach it — TTY present, exact-word confirmation, run-id-matched
verdict in `{READY, READY_WITH_NON_BLOCKING_ISSUES}`, and `USED_GH=1` with
live `gh` auth. The pre-existing containment for spend (`WORKFLOW_BUDGET_*`)
and for stage approval (`human_gate`) is unchanged and still applies to the
chained run.

## 16. Automated-test strategy

The repo has no test framework or CI (BASELINE §7); this plan does not add
one. Two levels:

- `scripts/tests/audit-verdict-test.sh` — plain bash, no framework, sources
  the lib and asserts `classify_audit_verdict` over fixtures written to a
  temp dir: a file ending in `READY`; one ending in
  `READY WITH NON-BLOCKING ISSUES`; one ending in `NOT READY`; one whose
  body quotes `NOT READY` in a finding but ends `READY` (must classify
  `READY` — last match wins); one with a single line containing two phrases
  (`UNKNOWN`); one with no verdict (`UNKNOWN`); an empty file (`UNKNOWN`); a
  missing file (`UNKNOWN`, exit non-zero-free). Prints `PASS`/`FAIL` per case
  and exits non-zero on any failure.
- `for f in scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh; do bash -n
  "$f"; done` — must exit 0 for all (AC-7).

Not automatable here: everything requiring a TTY, a live agent pipeline, or a
GitHub write. Those are §18.

## 17. Regression-test strategy

Not a bug fix, so there is no pre-existing failing test to name. The
regression surface (BASELINE §13) is covered by re-executing the BASELINE §8
command set verbatim and diffing against BASELINE §9 results:

| Guard | Command | Expected |
|---|---|---|
| Arg contract, all scripts | BASELINE §8 lines 3-7 | identical output and exit codes |
| `--new` path unchanged (B-08) | `./scripts/from-issue.sh <n> --new` against a scratch checkout, diff stdout and the resulting `REQUIREMENTS.md` vs. the pre-change script | byte-identical |
| Syntax | `bash -n` × all scripts | exit 0 |
| Driver standalone (B-10) | `./scripts/change-workflow.sh --help`, `--version`, `bogus` | unchanged per `scripts/README.md:120` |

## 18. Manual-verification strategy

| ID | Check | Expected |
|---|---|---|
| M-01 | `from-issue.sh <n> --change`, decline at the prompt | file written, hint printed, driver not started, issue still OPEN (B-03) |
| M-02 | Same, press ENTER / type a wrong word / send EOF | treated as decline (§9) |
| M-03 | Same, piped stdin (no TTY) | seeded + hint + exit 0, no prompt, no driver (§10) |
| M-04 | Confirm; let the driver reach `COMPLETE` with a `READY` audit | `.workflow/audit-verdict` holds this run's id; issue CLOSED with a comment; `gh issue view <n> --jq .state` == `CLOSED` (B-04, AC-3) |
| M-05 | Hand-edit `FINAL_AUDIT.md` to `NOT READY`, re-run only the audit stage, re-check | issue OPEN, explanatory message (B-05) |
| M-06 | Confirm, then decline an internal `human_gate` | driver exits 0; no close (B-06) |
| M-07 | Confirm with `PATH` stripped of `gh` at close time / `gh auth logout` | close skipped with a message, run still reports success (B-07, I-09) |
| M-08 | `from-issue.sh <n> --new` | unchanged output, no prompt, no close (B-08) |
| M-09 | Pre-existing `.workflow/state` of `IMPLEMENT` | prompt shows the resume warning; nothing auto-deletes state (core rule 13) |
| M-10 | Run each script from `/tmp` via absolute path | all still work (I-04), including the new `source` of the lib |

## 19. Observability changes

Additive stdout only: the seeded-file echo and pre-flight warnings before the
prompt; one `Audit verdict: <class>` line in `FINAL_AUDIT`; and one
close/skip/failure line at the end. `.workflow/audit-verdict` doubles as the
durable record of what the last audit concluded. No logging framework, no
new log files, no change to `.workflow/logs/` or `cost.tsv`.

## 20. Implementation sequence

1. Write `scripts/tests/audit-verdict-test.sh` first (all cases fail — the
   lib does not exist), then `scripts/lib/audit-verdict.sh` until it passes.
2. `change-workflow.sh`: source the lib; write the verdict file in
   `FINAL_AUDIT`. `bash -n`; confirm `--help`/`--version`/unknown-arg
   unchanged.
3. `from-issue.sh`: `USED_GH` capture, `confirm_and_run_workflow()` with the
   pre-flight display (seeded file, uncommitted-work reminder, spend
   reminder, resume warning if `.workflow/state` is set), TTY check, exact
   word, driver invocation via `if ! …; then`. Verify M-01/M-02/M-03/M-08
   before writing any close code.
4. `from-issue.sh`: `close_issue_if_ready()` — run-id + class + `USED_GH` +
   live-auth checks, then `gh issue close --repo "$OWNER/$REPO" --comment`
   with the class and pointers to `FINAL_AUDIT.md` and `.workflow/change.diff`.
5. Docs: `README.md:114-133`, `scripts/README.md:63-82`.
6. Full check pass: `bash -n` × all, BASELINE §8 replay, M-01…M-10.

Steps 1-3 contain no GitHub write; the I-05 relaxation lands only at step 4,
so everything before it is revertible without touching the issue.

## 21. Scope cuts under time pressure

Cut in this order:

1. Close-comment richness — reduce to the verdict class alone, dropping the
   `change.diff` pointer (AC-3 requires only that a comment exist).
2. The resume warning in the pre-flight display (M-09 becomes advisory).
3. `README.md` prose polish, keeping `scripts/README.md` accurate.

Never cut: the confirmation gate (I-07), the run-id match (I-08), the
`USED_GH`/auth guard (I-09), the classifier test (the sole automated
coverage of the fail-closed logic).

## 22. Risks and unresolved questions

- **Stale-state resume (highest).** `from-issue.sh` chains into a driver whose
  `.workflow/state` may belong to a *different*, in-flight change; the
  chained run then resumes that work under this issue's banner. The run-id
  match prevents a wrong *close* only when `FINAL_AUDIT` does not re-run —
  if the resumed run does reach `FINAL_AUDIT`, its verdict is about the other
  change. Mitigated by the pre-flight warning, not eliminated. Auto-resetting
  state would violate core rule 13. **Raised for the reviewer as the sharpest
  residual risk.**
- **Uncommitted-work capture.** `README.md:106` tells the human to commit or
  stash before starting the driver, because `IMPLEMENT` records
  `git diff` of the whole tree. Chaining removes the natural pause for that
  step; the pre-flight reminder is the only mitigation.
- **Verdict parsing brittleness.** Depends on `FINAL_AUDIT.md` ending with
  one phrase from `prompts/change/final-audit.md:56-58`. A reviewer CLI that
  paraphrases yields `UNKNOWN` → no close (safe, but the feature silently
  stops working). Not fixable from this side without editing the prompt,
  which §12 forbids.
- **Trust-surface change.** `from-issue.sh` goes from one local write plus a
  read-only fetch to a long-running, budget-spending, GitHub-mutating script
  (BASELINE §16). Accepted by the spec; the four-condition containment in
  §15 is the answer.
- **UNRESOLVED — comment authorship.** The close comment is written by a
  script asserting a machine verdict on a public issue. Wording must
  attribute it to the audit, not claim human sign-off. Proposed text:
  "Closed by stagegate: change workflow completed with FINAL_AUDIT.md
  verdict `<CLASS>`. See FINAL_AUDIT.md and .workflow/change.diff in the
  working tree." Confirm at plan approval.
- **UNRESOLVED — `scripts/lib/` precedent.** This adds the repo's first
  non-flat script directory and first test file to a six-script layout. Kept
  because it is the only way to get automated coverage of the fail-closed
  classifier (alternative D). If the reviewer judges it scope creep, the
  fallback is an inline function plus M-05-style manual fixtures only.

## Change-impact table

| Component | Planned change | Reason | Regression risk | Test coverage |
|---|---|---|---|---|
| `scripts/lib/audit-verdict.sh` | new pure classifier | machine-readable verdict (B-10, I-08) | none — new file, no existing caller | `scripts/tests/audit-verdict-test.sh` (8 fixtures) |
| `scripts/tests/audit-verdict-test.sh` | new | first automated check in the repo | none | self |
| `scripts/change-workflow.sh` `FINAL_AUDIT` | write `.workflow/audit-verdict` | expose the verdict without changing exit codes (I-06 STRENGTHENED) | low — additive, after the existing `run_codex`, before the existing `set_state` | `bash -n`; M-04, M-05 |
| `scripts/change-workflow.sh` header | `source` the lib | reuse the classifier | low — must be self-relative or breaks I-04 | M-10; `--help`/`--version` replay |
| `scripts/from-issue.sh` fetch block | set `USED_GH` | close requires `gh`, not `curl` (I-09) | low — flag only, fetch logic unchanged | M-07 |
| `scripts/from-issue.sh` `write_change_request` | drop the trailing `Run:` hint | hint moves to the decline path (B-01/B-03) | low — file content unchanged, stdout changes | M-01 |
| `scripts/from-issue.sh` new confirm fn | prompt + TTY check + driver invocation | B-01, B-02, I-07 | **medium** — `set -e` + bare `read` on EOF is a live trap | M-01, M-02, M-03 |
| `scripts/from-issue.sh` new close fn | `gh issue close --comment` | B-04, I-05 RELAXED | **high** — only irreversible effect in the change | M-04…M-07 |
| `scripts/from-issue.sh` dispatch | call the two fns in `change)` only | keep `--new` untouched (B-08) | medium — a misplaced call would hit `--new` | M-08, `--new` byte-diff |
| `README.md`, `scripts/README.md` | document the new flow | BASELINE §12; docs currently describe a two-step handoff | none functional | M-01…M-08 read against the docs |

## Traceability

| Requirement | Behavior | Invariant | Component | Automated test | Manual check |
|---|---|---|---|---|---|
| AC-1 seed → prompt → run | B-01, B-02 | I-07 | `from-issue.sh` confirm fn | `bash -n` | M-04 |
| AC-2 decline runs nothing | B-03 | I-07 | `from-issue.sh` confirm fn | — | M-01, M-02, M-03 |
| AC-3 READY → closed + comment | B-04, B-10 | I-05, I-06, I-08 | `change-workflow.sh` `FINAL_AUDIT`; `from-issue.sh` close fn; classifier | classifier test | M-04 |
| AC-4 NOT READY / incomplete → open | B-05, B-06 | I-08 | classifier; run-id match | classifier test (`NOT_READY`, `UNKNOWN`) | M-05, M-06, M-09 |
| AC-5 curl fallback → skip + message | B-07 | I-09 | `USED_GH` + auth guard | — | M-07 |
| AC-6 `--new` unchanged | B-08 | I-04 | dispatch `case` | `bash -n`; `--new` byte-diff | M-08 |
| AC-7 `bash -n` + arg contract | B-09 | I-04 | all scripts | `bash -n` × all; BASELINE §8 replay | M-10 |
| Existing gates unweakened | — | I-01, I-02, I-03 | `human_gate`, `verify_approval`, `run_codex` call sites — not modified | — | M-06 (declined gate still halts) |

Bug-fix regression test: not applicable — this is a Feature (CHANGE_SPEC §1);
there is no pre-existing failing behavior to pin. The nearest equivalent is
the classifier's `NOT_READY`/`UNKNOWN` fixtures, which must pass before the
close code at step 4 is written.
