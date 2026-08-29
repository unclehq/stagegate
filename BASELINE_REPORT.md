# Baseline Report

Omitted sections: none

## 1. Change-request summary

`CHANGE_REQUEST.md` (seeded from `unclehq/stagegate#3`) bundles four
independent asks in its Motivation, plus a Summary that contradicts the first:

- **Summary**: "change everything to use opus."
- **Motivation item A**: "change all scripts to use kimi in the place of
  claude sonnet and claude opus" — directly contradicts the Summary.
- **Motivation item B**: prepend the issue number to `.workflow/state`.
- **Motivation item C**: `from-issue.sh` should zero `.workflow/state` when
  its embedded issue number differs from the current invocation, so
  `change-workflow.sh` "will complete properly."
- **Motivation item D**: close the originating GitHub issue when
  `change-workflow.sh` completes.
- **Motivation item E**: remove `.workflow/lock/lock` when
  `change-workflow.sh` completes.

Change Type is unchecked and Observed/Desired Behavior, Reproduction,
Constraints, Known Relevant Files, Out of Scope, and Success Criteria are all
unfilled template boilerplate (`from-issue.sh` only substitutes Summary and
Motivation from the issue; see §6). None of that narrows scope.

## 2. Repository architecture

Stagegate is a set of bash drivers, no compiled artifact. Two resumable
state-machine drivers share one lock/approval/logging convention:

- `scripts/stagegate.sh` — new-application pipeline, driven by
  `REQUIREMENTS.md`. No origin binding, no lock, no issue-close.
- `scripts/change-workflow.sh` — change-request pipeline, driven by
  `CHANGE_REQUEST.md`. Has origin binding, a single-writer lock, and a cost
  ledger.
- `scripts/from-issue.sh` — seeds either driver from a GitHub issue; for
  `--change` it also confirms with the human, invokes `change-workflow.sh`,
  and conditionally closes the issue afterward.
- `scripts/lib/audit-verdict.sh` — pure verdict classifier shared by the
  driver and `from-issue.sh`.
- `scripts/workflow.sh` — manual per-gate helper, predates the unified
  drivers, reads/writes the same `.workflow/` files by hand.
- `scripts/tests/close-flow-test.sh`, `scripts/tests/audit-verdict-test.sh` —
  hermetic bash test suites (no real `claude`/`codex`/`gh` calls; reviewer and
  agent CLIs are stubbed).

## 3. Relevant code paths

| Area | File:lines |
|---|---|
| Model/effort/CLI defaults (change-workflow) | `scripts/change-workflow.sh:57-63,103-104` |
| Model/effort/CLI defaults (stagegate) | `scripts/stagegate.sh:45-52,56-95` |
| State read/write (change-workflow) | `scripts/change-workflow.sh:33,130-140,801-804` |
| State read/write (stagegate) | `scripts/stagegate.sh:33,128-133` |
| State read (from-issue) | `scripts/from-issue.sh:17,22-26,39-73` |
| Origin binding | `scripts/change-workflow.sh:37,185-224`; `scripts/from-issue.sh:18,28-73,112` |
| Lock acquire/release | `scripts/change-workflow.sh:36,142-183,598` |
| Audit verdict record | `scripts/change-workflow.sh:38,760-778`; `scripts/lib/audit-verdict.sh` |
| Issue-close chain | `scripts/from-issue.sh:75-127,129-211` |
| Test fixtures asserting state/origin format | `scripts/tests/close-flow-test.sh:327-462` |
| Documented contract | `README.md:114-157,233-283`; `scripts/README.md:106` |

## 4. Current observable behavior

| ID | Trigger | Current result | Evidence | Must preserve? |
|---|---|---|---|---|
| B-1 | `change-workflow.sh` run with no `WORKFLOW_MODEL_*` overrides | BASELINE/CHANGE_SPEC/UPDATED_PLAN/EXECUTE stages use `sonnet`; CHANGE_PLAN/IMPLEMENT/SMALL use `opus` | `scripts/change-workflow.sh:57-63` | Only if CHANGE_SPEC keeps per-stage tiering; contradicts CR Summary ("everything opus") and CR Motivation-A ("everything kimi") |
| B-2 | `stagegate.sh` run with no overrides | All stages default `opus` except `requirements`/`execute-checklist` (`sonnet`) | `scripts/stagegate.sh:56,82-86` | Same tension as B-1 |
| B-3 | Either driver run with no `WORKFLOW_AGENT_CMD`/`WORKFLOW_REVIEWER_CMD` | Agent CLI is `claude`, reviewer CLI is `codex` | `scripts/change-workflow.sh:103-104`; `scripts/stagegate.sh:51-52` | Swapping is already a supported extension point — README's own example sets `WORKFLOW_AGENT_CMD=kimi` (`README.md:254`) — provided the substitute CLI accepts the same flags (`README.md:258-260`) |
| B-4 | Any stage transition | `.workflow/state` is overwritten with one bare token, e.g. `ANALYZE`, `IMPLEMENT`, `COMPLETE` — no issue number, no delimiter | `scripts/change-workflow.sh:130-132`; `scripts/stagegate.sh:128-131` | Format is read verbatim by `from-issue.sh:23-24`, `scripts/workflow.sh`, and asserted verbatim by `scripts/tests/close-flow-test.sh:399,444` and `QUICK_START.md:92` |
| B-5 | `from-issue.sh --change` invoked while `.workflow/state` is non-empty/non-`COMPLETE` and `.workflow/origin` names a **different** (repo, issue) | Refuses to seed, exits 1, prints the conflicting owner; `CHANGE_REQUEST.md` and `.workflow/state` are left untouched | `scripts/from-issue.sh:47-67`; verified live in `VERIFICATION_REPORT.md:29` (MC-010) | This already satisfies the safety goal behind CR Motivation-C, by refusing rather than by zeroing state — see §15 |
| B-6 | `change-workflow.sh` invoked directly (not via `from-issue.sh`) with `STAGEGATE_ORIGIN_REPO`/`ISSUE` set, state non-empty/non-`COMPLETE`, and `.workflow/origin` missing or naming a different issue | Refuses to proceed, no state mutation, no stage runs | `scripts/change-workflow.sh:191-218` | Mirror-image guard to B-5, driver side |
| B-7 | `change-workflow.sh` reaches `FINAL_AUDIT` and the reviewer produces a verdict | `.workflow/audit-verdict` gets `run_id\tVERDICT\tsha256(FINAL_AUDIT.md)`; state advances to `COMPLETE` | `scripts/change-workflow.sh:770-778` | change-workflow.sh itself never calls `gh` — closing is entirely `from-issue.sh`'s job (B-9) |
| B-8 | `change-workflow.sh` process exits, any path (success, error, or a signal `trap` catches) | `.workflow/lock/` (the whole directory, including `pid`) is removed by `release_lock` via the `EXIT` trap registered at first successful `mkdir` | `scripts/change-workflow.sh:149-154,162` | This already satisfies CR Motivation-E for every exit path the driver controls (not e.g. `kill -9`) |
| B-9 | `from-issue.sh --change` runs `change-workflow.sh` to exit 0, then checks `.workflow/audit-verdict` against `run_id`, `.workflow/origin` against the current issue, and a fresh hash of `FINAL_AUDIT.md` | Closes the GitHub issue via `gh issue close --comment ...` only if every check agrees and the verdict is `READY`/`READY_WITH_NON_BLOCKING_ISSUES`; otherwise leaves it open with a printed reason | `scripts/from-issue.sh:126,132-211` | This already satisfies CR Motivation-D, but **only for runs launched by `from-issue.sh`** — a `change-workflow.sh` run started by a human directly, or resumed in a later shell without going back through `from-issue.sh`, never reaches this code and never closes anything even on a READY audit |

## 5. Existing invariants

| ID | Invariant | Current enforcement | Existing test | Confidence |
|---|---|---|---|---|
| I-1 | A resumed run may not act on `.workflow/state` unless `.workflow/origin` proves it belongs to the current (repo, issue) | `scripts/change-workflow.sh:191-218` (driver) + `scripts/from-issue.sh:47-67` (seed gate) | `close-flow-test.sh` cases `preflight-origin-mismatch`, `preflight-origin-absent`, MC-010 in `VERIFICATION_REPORT.md:29` | High |
| I-2 | Only one `change-workflow.sh` may hold a given checkout at a time | `mkdir`-based lock, `scripts/change-workflow.sh:147-183` | `close-flow-test.sh` cases `lock-held-by-live-pid`, `lock-stale-pid-cleared` | High |
| I-3 | The GitHub issue is closed only when the verdict record's run id, origin binding, and `FINAL_AUDIT.md` hash all match the current run | `scripts/from-issue.sh:132-211` | Multiple `close-flow-test.sh` cases incl. `verdict-record-written` | High |
| I-4 | An approved artifact whose bytes change is re-hashed and rejected (gate must be re-approved) | `scripts/change-workflow.sh` `verify_approval` (~line 246+) | Not exercised by the two automated suites read in this pass | Medium (asserted by design, not observed running here) |
| I-5 | `.workflow/state` is never auto-deleted to resolve a foreign-owner conflict; the design explicitly rejected that as unsafe | `UPDATED_CHANGE_PLAN.md:53` ("this is not core-rule-13 state deletion... belt-and-suspenders, not a substitute for the lock") | N/A (design record, not code) | High — directly contradicts CR Motivation-C, see §15 |

## 6. Current API, schema, and interface contracts

- `.workflow/state`: single line, one bare token from `{ANALYZE, PLAN,
  UPDATED_PLAN, IMPLEMENT, CHECKLIST, EXECUTE_CHECKLIST, FINAL_AUDIT,
  COMPLETE}` (change-workflow) or the stagegate equivalent set. No delimiter,
  no issue number. Consumers: `scripts/change-workflow.sh`,
  `scripts/stagegate.sh`, `scripts/from-issue.sh`, `scripts/workflow.sh`,
  `README.md:157,273,282`, `QUICK_START.md:92`, and literal-value assertions
  in `scripts/tests/close-flow-test.sh:399,444`.
- `.workflow/origin`: single line, `OWNER/REPO\tISSUE_NUM`. Written by
  `from-issue.sh:112` and read by both drivers' preflight and
  `close_issue_if_ready`.
- `.workflow/audit-verdict`: single line,
  `run_id\tVERDICT_CLASS\tsha256(FINAL_AUDIT.md)`. Written
  `scripts/change-workflow.sh:770-775`, read `scripts/from-issue.sh:142-145`.
- `.workflow/lock/`: directory; `mkdir` is the mutex; contains `pid` only.
  Presence of the directory is the lock, not any specific file inside it.
- Env var contract (both drivers): `WORKFLOW_AGENT_CMD`, `WORKFLOW_REVIEWER_CMD`,
  `WORKFLOW_MODEL_<STAGE>`, `WORKFLOW_EFFORT_<STAGE>`, `WORKFLOW_TURNS_<STAGE>`,
  `WORKFLOW_TOOLS_<STAGE>`, `CODEX_MODEL`; change-workflow.sh adds
  `WORKFLOW_TRACK`, `WORKFLOW_BUDGET_<STAGE>`, `WORKFLOW_SESSION_REUSE`,
  `WORKFLOW_PARALLEL_CHECKLIST`; from-issue.sh chaining adds
  `STAGEGATE_RUN_ID`, `STAGEGATE_ORIGIN_REPO`, `STAGEGATE_ORIGIN_ISSUE`
  (documented `README.md:233-264`).
- `CHANGE_REQUEST.md` template: fixed section headings written by
  `from-issue.sh`'s `write_change_request` (heredoc around line 380+); only
  Summary and Motivation are populated from the issue, everything else stays
  boilerplate.

## 7. Existing automated-test coverage

| Suite | Scope | Checks |
|---|---|---|
| `scripts/tests/close-flow-test.sh` | Lock, origin binding, seed gate, verdict recording, issue-close decision matrix, end-to-end hermetic driver runs with stubbed `claude`/`codex`/`gh` | 99 |
| `scripts/tests/audit-verdict-test.sh` | `scripts/lib/audit-verdict.sh` verdict classification | 26 |

No test covers model/effort defaults, `WORKFLOW_AGENT_CMD` swapping, or any
issue-number-in-state format — all four are new surface for this change.

## 8. Exact build and test commands executed

```
bash scripts/tests/audit-verdict-test.sh
bash scripts/tests/close-flow-test.sh
```
No build step exists (bash scripts, no compilation).

## 9. Baseline test results

First run, in this session's ambient shell:

```
audit-verdict-test.sh: 26 checks passed
close-flow-test.sh: 4 of 99 checks failed
  FAIL [stale-audit-rejected] expected output to contain: Required file missing or empty: FINAL_AUDIT.md
  FAIL [verdict-record-written] expected exit 0, got 1
  FAIL [verdict-record-written] expected output to contain: Audit verdict: READY
  FAIL [verdict-record-written] verdict record mismatch: (empty)
```

Re-run after `unset STAGEGATE_ORIGIN_REPO STAGEGATE_ORIGIN_ISSUE
STAGEGATE_RUN_ID`:

```
close-flow-test.sh: 99 checks passed
audit-verdict-test.sh: 26 checks passed
```

True baseline (clean environment) is **125/125 passing**. See §10 for why the
first run failed.

## 10. Existing failures, warnings, and flaky behavior

The 4 failures above are an environment artifact, not a code defect: this
session's shell is itself a subprocess of a live `change-workflow.sh` ANALYZE
stage (launched by `from-issue.sh` for `unclehq/stagegate#3`), so
`STAGEGATE_ORIGIN_REPO=unclehq/stagegate`, `STAGEGATE_ORIGIN_ISSUE=3`, and
`STAGEGATE_RUN_ID` are exported ambient env vars. The two failing test cases
(`stale-audit-rejected`, `verdict-record-written`, `close-flow-test.sh:435,462`)
pre-set `.workflow/state=FINAL_AUDIT` without an `.workflow/origin`, expecting
no origin check to fire — but `run_driver` (`close-flow-test.sh:174`) does not
sanitize `STAGEGATE_ORIGIN_*`/`STAGEGATE_RUN_ID` out of the ambient
environment, so the inherited vars trigger the real origin-mismatch refusal
(I-1) instead. **Anyone running this test suite from inside an active
stagegate session, or any CI job that leaks these three var names, will see
the same spurious failures.** This is a latent test-isolation gap worth
flagging to the reviewer, independent of the requested change.

## 11. Reproduction result for the reported bug

Not applicable in the bug-repro sense — this is a bundle of feature/config
asks, not a single reported defect. Per-item status, established by reading
code plus the passing `close-flow-test.sh` suite (no bug reproduced live
against a real GitHub issue, to avoid side effects on `unclehq/stagegate#3`):

- Kimi/opus model change: not implemented (B-1, B-2).
- Issue number in `.workflow/state`: not implemented (B-4).
- Zero state on issue mismatch: not implemented; a different mechanism
  (refuse, not zero) already exists and covers the underlying safety concern
  (B-5, B-6, I-1, I-5).
- Close issue on completion: implemented, but only on the `from-issue.sh`
  chained path (B-9).
- Remove lock dir on completion: implemented for every exit path the driver
  controls (B-8).

## 12. Likely change surface

`scripts/change-workflow.sh`, `scripts/stagegate.sh` (model/CLI defaults,
state format), `scripts/from-issue.sh` (state-mismatch handling, issue-number
parsing), `scripts/workflow.sh` (reads state manually), `README.md` +
`scripts/README.md` + `QUICK_START.md` (documented format/defaults),
`scripts/tests/close-flow-test.sh` (state-format literals at
`327-462`), possibly `scripts/lib/`.

## 13. Regression-sensitive components

- Origin/lock/state machine (I-1, I-2, I-5) — the exact mechanism the prior
  change cycle (issue #2, see `UPDATED_CHANGE_PLAN.md`) built to close AR-001
  ("stale state closes wrong issue"). Any change to `.workflow/state`'s format
  or to the zero-on-mismatch semantics interacts directly with this and must
  not reopen AR-001.
- `close-flow-test.sh`'s 99 literal-state assertions — a state-format change
  breaks every `printf 'IMPLEMENT\n' > .../state` fixture unless updated in
  lockstep.
- Cost ledger (`scripts/change-workflow.sh:226-232`) — assumes stage names
  and per-stage model are independent columns; not schema-coupled to model
  values, low risk.
- `README.md`'s documented defaults table (`README.md:233-264`) and
  `scripts/README.md` — both will drift if model/env-var defaults change
  without a doc update.

## 14. Areas explicitly outside the change

`stagegate.sh`'s new-application pipeline behavior beyond shared model/CLI
defaults, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `GOOD_FIRST_ISSUES.md`,
`STRATEGY.md`, `AGENTIC.md`, the `prompts/` stage prompt bodies (no requested
change touches prompt content).

## 15. Unknowns and assumptions

- **Summary vs. Motivation contradict each other** ("everything opus" vs.
  "everything kimi"). CHANGE_SPEC must resolve this with the human before any
  model-default edit; assuming one over the other is a guess.
- **"Kimi" is not a drop-in value.** The CLI swap point already exists
  (`WORKFLOW_AGENT_CMD`/`WORKFLOW_REVIEWER_CMD`), but README documents it
  works only if "the swapped CLI must accept the same flags the driver
  passes... [otherwise] provide a wrapper script" (`README.md:258-260`). Test
  passage for it hasn't been checked and no `kimi` binary is available here.
  Whether "change all scripts to use kimi" means (a) changing the default env
  var value, (b) writing a flag-translating wrapper, or (c) something else is
  unresolved.
- **Motivation-C directly conflicts with an existing, deliberate design
  decision (I-5).** The prior change cycle explicitly chose "refuse" over
  "auto-reset" for foreign/stale state, reasoning that silent state deletion
  could discard another in-flight run's progress (`UPDATED_CHANGE_PLAN.md:53`,
  core rule 13: "do not overwrite unrelated uncommitted work"). Implementing
  Motivation-C literally (zero `.workflow/state` on mismatch) would reintroduce
  the class of bug AR-001 was written to close, unless scoped very carefully
  (e.g., only zero when no lock is held and no unresolved approvals exist).
  This needs explicit human sign-off before CHANGE_SPEC commits to it.
- **Whether "prepend issue number to state" changes the file format for all
  consumers, or adds a parallel/derived value.** A literal prepend (e.g.
  `3:ANALYZE`) breaks every exact-match consumer in §6/§13 unless they are all
  updated together; an additive approach (e.g. keep `.workflow/origin` as the
  source of truth, only cosmetically show the issue number) would be lower
  risk but may not satisfy the literal request.
- Whether "remove `.workflow/lock/lock`" refers to the existing `.workflow/lock/`
  directory (already removed on every driver-controlled exit, B-8) or names
  some other path not currently present in the repo — no file literally named
  `lock` inside `.workflow/lock/` exists today (only `pid`).
- No stated acceptance criteria, constraints, or out-of-scope list in
  `CHANGE_REQUEST.md` itself (§1) — all follow-on stages are working from the
  Motivation prose alone.

## 16. Initial risk assessment

Medium-high. The request bundles five materially independent changes, two of
which already appear implemented (issue-close for one entry point, lock
cleanup) and one of which (auto-zero state on mismatch) conflicts with a
just-completed, explicitly-reasoned safety mechanism (I-1/I-5) from the prior
change cycle. The model-default ask is internally contradictory. Proceeding
without resolving the opus/kimi contradiction and the zero-vs-refuse conflict
risks either reintroducing AR-001 or shipping a change the human didn't
actually ask for. Recommend splitting into separately-approved sub-changes in
CHANGE_SPEC.md rather than one combined spec.
