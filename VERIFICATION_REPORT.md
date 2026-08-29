# Verification Report

Method: two disposable `git worktree add --detach HEAD` checkouts (no
gitignored `.workflow/` carried over), the post-change tree populated by
copying the working tree's modified/new `scripts/*.sh`, `scripts/README.md`,
`README.md` over the clean checkout. `WORKFLOW_AGENT_CMD=false
WORKFLOW_REVIEWER_CMD=false` exported throughout. `.workflow` absence asserted
before/after every invocation. Both worktrees removed after use;
`git status --porcelain` on the main tree confirmed unchanged before and after.

| Check ID | Action performed | Expected result | Actual result | Evidence | Status | Defect ref |
|---|---|---|---|---|---|---|
| MC-001 | Ran `stagegate.sh`/`change-workflow.sh` with `-h` and `--help` | exit 0, usage on stdout, empty stderr, no `.workflow` | All 4 invocations: exit 0, stdout 364B/399B, stderr 0B, `.workflow` absent | command transcript | PASS | — |
| MC-002 | Ran `stagegate.sh --version`, `change-workflow.sh --version` | exit 0, stdout exactly `0.1.0`, empty stderr, no `.workflow` | Both: `out=0.1.0`, exit 0, stderr 0B, `.workflow` absent | transcript | PASS | — |
| MC-003 | Ran `--bogus`, `--help extra`, `--version extra` on both drivers | exit 1, stderr usage, empty stdout, no `.workflow` | All 4: exit 1, stdout 0B, stderr 389-427B, `.workflow` absent | transcript | PASS | — |
| MC-004 | Ran `-h`/`--help` on both `codex-*` scripts against a fixture with no precondition files | exit 0, usage on stdout, own basename present, other's absent, no precondition failure | All 4: exit 0, stdout non-empty and script-specific; `grep -c` cross-basename = 0 both directions | transcript | PASS | — |
| MC-005 | Ran `--bogus`, `--help extra` on both `codex-*` scripts | exit 1, stderr usage, empty stdout | All 4: exit 1, stdout 0B, stderr 427-512B | transcript | PASS | — |
| MC-007 | `workflow.sh status` and `workflow.sh bogus-subcommand` vs golden fixture from pre-change worktree, `cmp` on stdout/stderr/exit | byte-identical, `status` exit 0, `bogus` exit 1 | Both `cmp` clean, exit codes match | transcript | PASS | — |
| MC-008 | `approve-plan`/`approve-review`/`approve-updated-plan` under APPROVE (all three subcommands), missing-file, and REJECT scenarios, pre- vs post-change worktree, `cmp` on stdout/stderr/exit, hash comparison for APPROVE | byte-identical, matching SHA-256 on success | All scenarios `cmp`-clean; `hash_pre == hash_post` for approve-plan APPROVE | transcript | PASS | — |
| MC-009 | Zero-argument `stagegate.sh`/`change-workflow.sh` from a foreign cwd (`/tmp`), against `WORKFLOW_*_CMD=false` | dispatch reaches original first statement unchanged, no help path taken | exit 1, stdout 237B/177B, stderr 0B — matches CHANGE_TEST_REPORT.md's T-14 byte counts exactly | transcript (cross-checked against CHANGE_TEST_REPORT.md T-14, cited per output-economy rule rather than re-running that exact fixture) | PASS | — |
| MC-010 | `from-issue.sh`, `-h`, `--help`, no-args — cited from CHANGE_TEST_REPORT.md T-10 (golden-fixture `cmp`, already PASS) plus this pass's own MC-020 run of the identical file | unchanged, usage on stdout, exit 0 | T-10 PASS (cited); independently reconfirmed via MC-020's real-issue run showing pre/post identity | CHANGE_TEST_REPORT.md T-10; this report's MC-020 | PASS | — |
| MC-011 | Read `scripts/README.md`: six-script coverage, `--version` scoped to two drivers only, stdout-exception documentation, trailing-arg rule | matches actual observed behavior above | All six scripts documented; argument-handling table matches MC-001..MC-005 observations; stdout exception for `workflow.sh`/`from-issue.sh` explicitly called out; trailing-arg rule stated | file read | PASS | — |
| MC-012 | `for f in scripts/*.sh; do bash -n "$f"; done` in post-change worktree, bash 3.2.57 | all six parse individually | 6/6 exit 0 | transcript | PASS | — |
| MC-014 | Invoked each script's `--help` and both drivers' zero-arg form via absolute path from `/tmp` (foreign cwd) | help resolves ROOT and succeeds; zero-arg matches MC-009's controlled fixture | All 6 `--help` calls exit 0 from `/tmp`; zero-arg byte counts (237B/177B) identical to MC-009/T-14 | transcript | PASS | — |
| MC-015 | Checked for a change commit to revert | rollback = `git revert` per CHANGE_SPEC §11 | No commit exists yet (change is still uncommitted in the working tree) — nothing to revert | `git log`, `git status` | NOT RUN (environmental: no commit created; not executable until the change is committed) | — |
| MC-016 | `-h`/`--help` on `workflow.sh` (approvals-absence + usage), and no-args vs golden fixture | help exits 0 with no `.workflow/approvals`; no-args byte-identical to baseline per D-1 narrow branch | `-h`/`--help`: exit 0, stdout 159B, stderr 0B, approvals absent both times; no-args: `cmp`-clean vs golden (stdout/stderr/exit), exit 1 | transcript | PASS | — |
| MC-017 | `workflow.sh status extra`, `approve-plan extra`, `approve-review extra`, `approve-updated-plan extra` | exit 1, usage on stdout, empty stderr, no approval hash written, only pre-existing `mkdir -p` side effect | All 4: exit 1, stdout 159B, stderr 0B; `.workflow/approvals` created empty (mkdir -p only) with no `.sha256` file | transcript | PASS | — |
| MC-018 | State-machine resume across pre/post revisions with deterministic non-billable stubs recording argv | byte-identical stage-by-stage | Not executed — building a deterministic agent/reviewer stub harness that completes real workflow stages is out of proportion to this additive, argument-only change, and CHANGE_TEST_REPORT.md already lists the state machine beyond argument handling as untested for the same reason | CHANGE_TEST_REPORT.md "Untested areas" | NOT RUN (scope/cost: would require building a stub CLI harness not otherwise needed by this change) | — |
| MC-019 | `codex-review-plan.sh`/`codex-create-checklist.sh` with satisfied preconditions (approved PROJECT_PLAN.md/UPDATED_PROJECT_PLAN.md + reviewer stub) | byte-identical pre/post through to reviewer invocation | Not executed — requires a real or stubbed reviewer CLI and approved-hash fixtures beyond this pass's scope; guard placement above the precondition block already verified structurally (guard exits before `test -s` / `REVIEWER_CMD=` lines) | source read (guard precedes precondition/CMD lines in both files) | NOT RUN (scope: guard placement verified structurally; full satisfied-precondition run not performed) | — |
| MC-020 | `from-issue.sh 2 --new` (real open issue in `unclehq/stagegate`, read-only `gh issue view`, no GitHub write) pre- vs post-change worktree | byte-identical, unmodified file | Both: exit 0, stdout 96B, `REQUIREMENTS.md` md5 `057b4dc1e46dd83e390624adfc80a467` identical | transcript | PASS | — |
| MC-021 | Followed `scripts/README.md` link from `README.md:286`; checked "all six scripts" claim | link resolves, claim accurate, no double-count | Link text/target correct; `scripts/README.md` documents exactly 6 script sections | file read | PASS | — |
| MC-022 | Cross-checked source: in every guarded script, the `case` guard exits before any external-process-invoking statement (`AGENT_CMD=`/`REVIEWER_CMD=` reads at `stagegate.sh:51-52`, `codex-review-plan.sh:39`, all after the guard); combined with the `.workflow`-absence results from MC-001..MC-005 and MC-016 | no `claude`/`codex` process reachable on any help/version/unknown path | Guard lines precede all `_CMD=` reads in all 5 modified scripts; no `.workflow` mutation observed in any of the ~30 invocations run in this pass | source line numbers + aggregated MC-001..MC-005/MC-016 transcripts | PASS | — |

Removed checks (per MANUAL_CHECKLIST.md, not re-verified): MC-006, MC-013 —
reviewer marked these provably inapplicable/superseded (by MC-016 and MC-022
respectively) before this pass began.

## Acceptance criteria summary

| AC | Status | Basis |
|---|---|---|
| AC-01 | PASS | MC-001, MC-003, MC-022 |
| AC-02 | PASS | MC-002 |
| AC-03 | PASS | MC-001, MC-002, MC-003, MC-022 |
| AC-04 | PASS | MC-003, MC-022 |
| AC-05 | PASS | MC-004, MC-005 (MC-009/MC-019 zero-arg/satisfied-precondition portions: MC-009 PASS by citation, MC-019 NOT RUN) |
| AC-06 | **PARTIAL** | MC-007, MC-008, MC-016, MC-017 all PASS for the narrow D-1 scope (`-h`/`--help` exit 0, `status`/`approve-*` preserved); no-argument case intentionally still exits 1 per the recorded, plan-required deviation (IMPLEMENTATION_NOTES.md D-1) — not a defect |
| AC-07 | PASS | MC-010, MC-020 |
| AC-08 | PASS | MC-011, MC-021 |
| AC-09 | PASS | MC-009, MC-014; MC-018 (broader state-machine preservation) NOT RUN |

## Preserved behavior summary

`workflow.sh status`, all three `approve-*` subcommands (APPROVE/REJECT/missing-file
paths), `workflow.sh`'s unknown-subcommand and no-argument fall-through, and
`from-issue.sh` in full (including a real-issue argument) are confirmed
byte-identical to pre-change behavior. Both drivers' zero-argument entry path
is confirmed identical from both the repository root and a foreign cwd.

## Changed behavior summary

Five scripts gained `-h`/`--help` (all six, `from-issue.sh` already had it);
`stagegate.sh`/`change-workflow.sh` gained `--version`; unrecognized/trailing
arguments now reject with exit 1 (stderr for the four newly-guarded scripts,
stdout preserved for `workflow.sh`'s `*)` arm per BH-15). `workflow.sh -h`/`--help`
moved from exit 1 to exit 0 — the sole in-scope behavioral relaxation, deliberately
narrowed to exclude bare no-args (D-1). A new `scripts/README.md` was added and
`README.md` gained a pointer to it.

## Invariant summary

IV-01, IV-02, IV-04, IV-05, IV-06 confirmed intact (MC-002, MC-004, MC-009,
MC-012, MC-014, source read). IV-03 confirmed RELAXED only for the two explicit
help flags on `workflow.sh`, not for bare no-args (MC-016) — matches the
narrowed scope recorded in IMPLEMENTATION_NOTES.md D-1. IV-07/IV-08 (no side
effect before dispatch) confirmed for all five guarded scripts via `.workflow`
absence and source-line ordering (MC-001, MC-016, MC-022).

## Regression summary

No regression found. Every PRESERVE-classified behavior checked
(`status`, `approve-*`, unknown-subcommand, bare no-args on `workflow.sh`,
all of `from-issue.sh`, both drivers' zero-argument dispatch) is byte-identical
pre- and post-change.

## Unresolved defects

None found. AC-06 is PARTIAL by design (recorded, approved-scope deviation
D-1, not a defect) pending a future explicit approval of the full IV-03
relaxation.

## Not executed (scope/environmental, listed for follow-up)

- MC-015 (rollback) — no commit exists yet to revert; re-run once the change is committed.
- MC-018 (full state-machine resume under stubs) — would require building a
  dedicated deterministic agent/reviewer stub harness; out of proportion to an
  additive, argument-parsing-only change. Guard placement (the actual risk
  surface) is otherwise fully covered by MC-001, MC-016, MC-022.
- MC-019 (codex-* with satisfied preconditions) — same reasoning; guard
  placement relative to the precondition/CMD-read lines verified by source
  inspection instead.

## Recommendation

Approve as complete for the scope actually implemented (narrow D-1 branch).
Before closing AC-06 fully, obtain an explicit human decision on the IV-03
relaxation for `workflow.sh`'s bare no-argument case, per
IMPLEMENTATION_NOTES.md's "Unresolved concerns." No blocking defects.
