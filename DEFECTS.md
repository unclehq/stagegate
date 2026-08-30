# Defects

Found during independent manual verification (VERIFICATION_REPORT.md). Each
defect below was reproduced live against the actual committed
`scripts/change-workflow.sh` / `scripts/lib/issue-close.sh` in a scratch
checkout, with a stubbed `gh`. Not fixed here per the completion rule
("do not silently fix failures during checklist execution").

## D-1 (P0, security, INV-1/INV-3): a `COMPLETE`-state run with explicit
`STAGEGATE_ORIGIN_*` can close whatever issue `.workflow/origin` names on
disk, even when that disagrees with the explicit binding

**Where:** `scripts/change-workflow.sh:207-240` (`origin_preflight`),
`scripts/change-workflow.sh:272-302` (`close_origin_issue_if_ready`),
`scripts/lib/issue-close.sh:130-135` (the "origin binding no longer names
$repo#$issue" check).

**Root cause:** `origin_preflight` only compares `.workflow/origin` against
`STAGEGATE_ORIGIN_REPO`/`ISSUE` when the state is non-empty and not
`COMPLETE` (`change-workflow.sh:222-224` returns early otherwise). Separately,
`ORIGIN_BOUND` is set to `1` whenever `STAGEGATE_ORIGIN_REPO`/`ISSUE` are
explicitly set for this invocation (`change-workflow.sh:687-689`), regardless
of what `.workflow/origin` actually contains. `close_origin_issue_if_ready`
then reads the repo/issue to close **from the origin file itself**
(`origin_field "$ORIGIN_FILE" 1/2`, `change-workflow.sh:297-298`), not from
`STAGEGATE_ORIGIN_REPO`/`ISSUE`. `issue_close_if_ready`'s own "origin binding
no longer names $repo#$issue" guard (`issue-close.sh:130-135`) compares the
origin file's fields against `$repo`/`$issue` — which were derived from that
same file — so the comparison is tautological and can never fail. Nothing in
the gate ever cross-checks the origin file against the operator's actual
`STAGEGATE_ORIGIN_REPO`/`ISSUE` for this invocation.

**Reproduction (evidence in VERIFICATION_REPORT.md, scenario
`mc009-originmismatch3`):**

```
state:  COMPLETE                      (bare, no issue prefix)
origin: other/repo<TAB>99<TAB>gh      (leftover from an unrelated run)
audit-verdict: run-1  READY  <hash of FINAL_AUDIT.md>
invocation: STAGEGATE_RUN_ID=run-1 STAGEGATE_ORIGIN_REPO=owner/repo \
            STAGEGATE_ORIGIN_ISSUE=42 change-workflow.sh
```

Expected (per CHANGE_SPEC BEH-D / AR-001's stated intent): either the run
refuses to close anything (origin cannot be proven to belong to owner/repo#42
for this invocation), or it closes owner/repo#42 (the operator's stated
target). Actual: it closes **other/repo#99** — an issue the operator never
named — and writes a marker recording that close as legitimate
(`run-1<TAB>other/repo<TAB>99`), exit 0, no warning of any kind.

**Why this is reachable, not just theoretical:** this exact state shape
(bare/prefixed `COMPLETE`, no fresh `ANALYZE` pass to self-heal the origin
file via `write_origin`) is precisely the state the AR-002 retry-on-rerun
feature (this same delivery) is designed to act on — a rerun landing on
`COMPLETE` with the marker absent. If `.workflow/origin` is stale or has been
superseded (e.g. this checkout was later reseeded for a different issue, or
hand-edited) between the original run and the retry, the retry silently
targets the wrong issue instead of refusing.

**Why the automated suite and MC-011 as literally worded miss it:** the
committed case `direct-run-explicit-origin-env-closes`
(`close-flow-test.sh:722-730`) and `MANUAL_CHECKLIST.md`'s MC-011 both set
`.workflow/origin` to the *same* repo/issue as the explicit
`STAGEGATE_ORIGIN_*` env — the divergent case (explicit env names one issue,
on-disk origin names another, state itself carries no prefix to trip AR-004)
is untested by both the automated suite and the checklist as written.

**Suggested direction (not applied):** `close_origin_issue_if_ready` should
pass `STAGEGATE_ORIGIN_REPO`/`STAGEGATE_ORIGIN_ISSUE` (when set) as the
`repo`/`issue` to close, and `issue_close_if_ready`'s existing "origin binding
no longer names $repo#$issue" check would then do real work instead of being
tautological. Alternatively, `origin_preflight` could refuse (not silently
pass) whenever explicit `STAGEGATE_ORIGIN_*` disagrees with an existing
`.workflow/origin`, regardless of `state`.

## D-2 (P1, documentation): `STAGEGATE_CLOSE_TIMEOUT` and the AR-004
corruption-refusal / manual-clear guidance text are not documented

**Where:** `README.md`, `scripts/README.md`.

`STAGEGATE_CLOSE_TIMEOUT` (`scripts/lib/issue-close.sh:23`) controls the
`gh issue close` deadline (MC-033) but appears nowhere in either README.
Likewise the state/origin corruption refusal message and its `rm -f
.workflow/state .workflow/origin` guidance (`scripts/lib/issue-close.sh:74-78`,
exercised by MC-004/MC-005) are not documented. `UPDATED_CHANGE_PLAN.md`'s
compatibility requirements (§8) call for README updates alongside BEH-B/BEH-D;
this is a gap against that requirement, not a functional defect. MC-026's
"kill switch, retry, skip guards" content is otherwise present and accurate.

## Gate-prompt verification (2026-08-29)

Independent manual verification of the `APPROVE`/`ACKNOWLEDGE` → bold `Y/N`
gate-prompt change (`CHANGE_SPEC.md`, `MANUAL_CHECKLIST.md` MC-001 through
MC-018) found no new defects. All P0/P1 checks passed; automated regression
suites remained green; the implementation was confined to the six authorized
paths in `UPDATED_CHANGE_PLAN.md` §23. The existing D-1/D-2 entries above
concern origin-binding behavior and are outside the scope of this gate-prompt
verification.
