# Implementation Notes

Approved scope: UPDATED_CHANGE_PLAN.md (sha256
`57f8d5a28311610671666c02b926ad9a378efc85655ede8f116baa41cfcbb953`, matches
`.workflow/approvals/UPDATED_CHANGE_PLAN.sha256`). CHANGE_SPEC.md and
BASELINE_REPORT.md also verified against their approval hashes before editing.

## Pre-implementation state

`git status --porcelain` before any edit showed only untracked workflow
artifacts (`ADVERSARIAL_REVIEW.md`, `BASELINE_REPORT.md`, `CHANGE_PLAN.md`,
`CHANGE_SPEC.md`, `UPDATED_CHANGE_PLAN.md`). No tracked file was modified and
no unrelated uncommitted work existed. Nothing was overwritten.

## Files changed

| File | Purpose of change | Plan step | Behavior / invariant affected |
|---|---|---|---|
| `scripts/codex-review-plan.sh` | Add `usage()` + `case "$#:${1:-}"` guard between `cd "$ROOT"` and the `test -s REQUIREMENTS.md` precondition block. `-h`/`--help` → usage on stdout, exit 0; any other argument → usage on stderr, exit 1; zero args fall through untouched. | §16.1 | BH-09 (ADD), BH-10 (PRESERVE), IV-08 (NEW), AC-05 |
| `scripts/codex-create-checklist.sh` | Same guard, with its own basename-correct usage text naming `UPDATED_PROJECT_PLAN.md` / `AUTOMATED_TEST_REPORT.md` / `MANUAL_CHECKLIST.md` (AR-008 — not copy-pasted). | §16.2 | BH-11 (ADD), BH-12 (PRESERVE), IV-08 (NEW), AC-05 |
| `scripts/workflow.sh` | Extract the existing `*)` heredoc into `usage()` (byte-identical text). Insert an early-exit `case "$#:${1:-}" in 1:-h\|1:--help)` **before** `mkdir -p .workflow/approvals` (AR-001). Re-key the main dispatch `case` from `"${1:-}"` to `"$#:${1:-}"` (AR-005); the four subcommand arms become `1:approve-plan`, `1:approve-review`, `1:approve-updated-plan`, `1:status`. `*)` arm now calls `usage` and keeps `exit 1`. | §16.3 | BH-13 (MODIFY, **narrowed** — see D-1), BH-14/BH-15 (PRESERVE), IV-03 (RELAXED, partial), IV-07, AC-06 |
| `scripts/stagegate.sh` | Add `STAGEGATE_VERSION="0.1.0"`, `usage()`, and the `$#:$1` guard with a `--version` arm, between `cd "$ROOT"` and `STATE_DIR=`. | §16.5 | BH-01/02/03 (ADD), BH-04 (PRESERVE), IV-07 (NEW), AC-01/02/04 |
| `scripts/change-workflow.sh` | Same, with `change-workflow.sh`-specific usage text. | §16.6 | BH-05/06/07 (ADD), BH-08 (PRESERVE), IV-07 (NEW), AC-03/04 |
| `scripts/README.md` | New file. Per-script purpose and exact invocation syntax for all six scripts, written from the finished `usage()` texts; argument-handling summary table; documents the `workflow.sh`/`from-issue.sh` stdout exception (MC-08) and the trailing-argument rejection rule. | §16.8 | BH-17 (ADD), AC-08 |
| `README.md` | OPT-01: two-line pointer to `scripts/README.md` in the "Manual helpers" section. | §16.10 | AC-08 support; no behavior |

`scripts/from-issue.sh` — unmodified, as required by BH-16 / §4.

Change surface: `109 insertions(+), 13 deletions(-)` across 6 tracked files,
plus one new file. No formatting or refactoring outside the inserted guards.

## Deviations from the approved plan

**D-1 (material) — `workflow.sh` zero-argument case left at exit 1
(IV-03 relaxation only partially implemented).**

UPDATED_CHANGE_PLAN §7.1 requires that implementation of the IV-03 relaxation
begin only if the human approval of that document *explicitly reaffirms* it,
and directs the narrower implementation otherwise. The approval record
`.workflow/approvals/UPDATED_CHANGE_PLAN.sha256` is a bare SHA-256 hash with
no prose field, and a case-insensitive search for `IV-03` / `relax` across
`.workflow/` returned no matches. The approval therefore does not address the
relaxation specifically.

Per §7.1 and the first §10 stopping condition, I implemented the narrow
branch:

- `workflow.sh -h` and `workflow.sh --help` → usage on stdout, **exit 0** (the
  fixed part of BH-13), and no `.workflow/approvals` created.
- `workflow.sh` with **no arguments** → usage on stdout, **exit 1**,
  byte-identical to the pre-change baseline (verified by `cmp` against the §7
  golden fixture, including exit status).

Consequence: AC-06 and BH-13 are satisfied for `-h`/`--help` but **not** for
the no-argument case, which still exits 1. IV-03 is relaxed only for the two
explicit help flags. Completing BH-13 requires one further change — adding
`0:` to the early-exit `case` at `scripts/workflow.sh:18` — and an explicit
human approval of the IV-03 relaxation. Nothing else depends on it.

**D-2 (minor) — `scripts/README.md` points to the top-level `README.md` for
the `WORKFLOW_*` table rather than reproducing it.**

The plan (§4) specifies `scripts/README.md` as an "invocation reference." A
draft included a two-row `WORKFLOW_*` table; a grep found 30+ `WORKFLOW_*`
variables in the scripts, so a two-row table would have been inaccurate and a
complete one is outside the frozen scope (CHANGE_SPEC §12 non-goals). The
section now names only `WORKFLOW_AGENT_CMD` / `WORKFLOW_REVIEWER_CMD` — the
two that decide which external CLI is spawned, relevant to the §11 containment
technique — and refers to the top-level `README.md` "Configuration" section
(verified to exist at `README.md:204`) for the full list.

## Observations, not deviations

- **Trailing arguments to `workflow.sh` subcommands now exit 1.** Re-keying
  the main `case` on `"$#:${1:-}"` is required by AR-005/§1, and it means
  `./scripts/workflow.sh status extra` now prints usage and exits 1 where it
  previously ran `status`. §1 of the approved plan states this explicitly
  ("a recognized subcommand plus trailing args → usage, exit 1"). The
  documented single-argument forms (BH-14) are byte-identical. Flagging it
  because §1 also describes the `*)` path as matching "current behavior
  exactly", which is true for unknown subcommands but not for this form.
- **`workflow.sh --version` exits 1** (usage on stdout, via `*)`). Correct:
  CHANGE_SPEC §13 scopes `--version` to the two drivers only.
- **`mkdir -p` still runs on `workflow.sh`'s unknown-input path**, as it does
  today; only the help path was moved ahead of it, per §1.
- BASELINE_REPORT §13's claim that `run_codex` invokes the `codex-*.sh`
  scripts was re-checked and remains incorrect (R-5): `run_codex` is an
  internal function in `change-workflow.sh:370`. Re-grep of `scripts/`
  confirmed no in-repo caller passes arguments to any of the six scripts
  (§7.4) — the only matches are documentation strings.

## Unresolved concerns

- **D-1 blocks full AC-06 / BH-13 satisfaction.** Needs a human decision on
  the IV-03 relaxation. This is the one acceptance criterion not fully met.
- **R-2 stands:** `0.1.0` is duplicated as a literal in both drivers and can
  drift. Accepted by the plan (Q-2 deferred).
- **R-3 stands:** `scripts/README.md` and the `usage()` texts can drift.
  T-12 gives partial automated coverage (basename, per-flag existence, and
  every `*.md` / `--flag` token in each `usage()` asserted present in the
  README), but nothing enforces it in CI — the repo has no CI.
- The two drivers were exercised only on their argument-handling paths, under
  the §11 worktree containment with `WORKFLOW_*_CMD=false`. Their state
  machines were never executed with a real agent, before or after the change
  (consistent with BASELINE_REPORT §11).
