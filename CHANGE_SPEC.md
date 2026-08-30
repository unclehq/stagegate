# Change Spec

Omitted sections: Performance requirements (no performance-sensitive behavior); Prototype-isolation requirements (not a prototype).

## 1. Change type

Feature — interactive UX improvement.

## 2. Problem statement

The human gates in `change-workflow.sh`, `stagegate.sh`, and `scripts/workflow.sh` force the operator to type the full uppercase words `APPROVE` or `ACKNOWLEDGE` (BASELINE B-1, B-2, B-3, B-7). This is slow, error-prone, and inconsistent with a simple yes/no decision.

## 3. Current behavior

- `change-workflow.sh` `human_gate` asks for `APPROVE`/`ACKNOWLEDGE` verbatim (BASELINE B-1, B-7).
- `stagegate.sh` `review_and_approve` asks for its configured wording verbatim (BASELINE B-2, B-7).
- `scripts/workflow.sh` `approve_*` asks for `APPROVE` verbatim and exits 1 on mismatch (BASELINE B-3, B-7, I-4).
- Accepted gates still record a SHA-256 approval hash (BASELINE B-5, I-2).
- `stagegate.sh` rechecks the file hash after input and reopens the gate if the file changed (BASELINE B-6, I-3).
- `from-issue.sh` uses a separate `RUN` confirmation and is not covered by this request (BASELINE B-4).

## 4. Desired behavior

Replace the prompt and acceptance logic in the three affected gate functions with a single bold Y/N question. `y` or `Y` accepts and proceeds; any other input (including `n`, `N`, empty input, or EOF) declines and preserves the existing exit-code contract. Hash recording, edit detection, and all other gate semantics remain unchanged.

## 5. Acceptance criteria

1. Affected gates print one prompt line that is bold, names the action/file being approved, and ends with `[Y/N]`.
2. Input `y` or `Y` advances the gate and records the approval hash as before.
3. Input `n`, `N`, any other text, empty input, or EOF declines and preserves the existing exit code (`0` for `change-workflow.sh`/`stagegate.sh`, `1` for `scripts/workflow.sh`).
4. `stagegate.sh` still detects a file modified during review and reopens the gate instead of recording approval.
5. `from-issue.sh` `RUN` gate continues to require exact `RUN` and passes `close-flow-test.sh` unchanged.
6. `README.md`, `QUICK_START.md`, and `scripts/README.md` no longer tell the user to type `APPROVE`/`ACKNOWLEDGE`.

## 6. Observable behavior table

| ID | Class | Trigger | Current behavior | Expected behavior | Verification |
|---|---|---|---|---|---|
| B-1 | MODIFY | `change-workflow.sh` reaches `human_gate APPROVE`/`ACKNOWLEDGE` | Exact-word prompt; only the matching word accepted (BASELINE B-1, B-7) | Bold Y/N prompt; `y`/`Y` accepts, else declines | Manual/piped gate test; output inspected for bold ANSI and `[Y/N]` |
| B-2 | MODIFY | `stagegate.sh` reaches `review_and_approve` | Exact-word prompt; only the matching word accepted (BASELINE B-2, B-7) | Bold Y/N prompt; `y`/`Y` accepts, else declines | Manual/piped gate test; output inspected |
| B-3 | MODIFY | `scripts/workflow.sh approve-plan/review/updated-plan` invoked | Exact-word `APPROVE` prompt; mismatch exits 1 (BASELINE B-3, B-7) | Bold Y/N prompt; `y`/`Y` accepts, else exits 1 | Manual gate test |
| B-4 | PRESERVE | `from-issue.sh --change` confirms launch | Exact-word `RUN` prompt; mismatch declines (BASELINE B-4) | Exact-word `RUN` prompt; mismatch declines | `close-flow-test.sh` passes unchanged |
| B-5 | PRESERVE | Any accepted gate | SHA-256 hash written to `.workflow/approvals/<name>.sha256` (BASELINE B-5) | Same hash file written only after `y`/`Y` | Existing suites + manual gate |
| B-6 | PRESERVE | `stagegate.sh` review with file changed during review | Re-opens gate / cancels speculation (BASELINE B-6) | Same edit detection and reopen behavior | Existing suites + manual test |
| B-7 | REMOVE | Affected gate prompts | Plain-text exact-word prompt (BASELINE B-7) | Exact-word prompt no longer used | Output inspection |
| B-8 | PRESERVE | Gate declined in drivers / helper | `change-workflow.sh`/`stagegate.sh` exit 0; `workflow.sh` exits 1 (BASELINE I-4, I-5) | Same exit codes on Y/N decline | Manual test with `n`, `foo`, empty, EOF |
| B-9 | MODIFY | Gate documentation in `README.md`, `QUICK_START.md`, `scripts/README.md` | Instructs typing `APPROVE`/`ACKNOWLEDGE` | Describes Y/N response | Read docs |

## 7. Invariant table

| ID | Status | Invariant | Scope | Enforcement point | Verification |
|---|---|---|---|---|---|
| I-1 | **REMOVED** (affected gates only) | Gate accepts only the exact configured confirmation word. | `change-workflow.sh` `human_gate`, `stagegate.sh` `review_and_approve`, `workflow.sh` `approve_file` | Replaced by Y/N check | Manual test that `APPROVE`/`ACKNOWLEDGE` no longer advances |
| I-1a | EXISTING | Gate accepts only the exact configured confirmation word. | `from-issue.sh` `confirm_and_run_workflow` | String equality check (BASELINE I-1) | `close-flow-test.sh` |
| I-2 | EXISTING | Approval records the hash of the file bytes present at acceptance. | All gates that record approvals | `hash_file` after accepted response (BASELINE I-2) | Existing suites + manual gate |
| I-3 | EXISTING | `stagegate.sh` refuses to approve a file that changed during review. | `stagegate.sh` `review_and_approve` | Before/after hash compare (BASELINE I-3) | Existing suites + manual test |
| I-4 | EXISTING | `workflow.sh` declines with exit 1 when approval is not given. | `workflow.sh approve_*` | `exit 1` on mismatch (BASELINE I-4) | Manual gate test |
| I-5 | EXISTING | `change-workflow.sh`/`stagegate.sh` decline with exit 0 when gate not accepted. | Those drivers | `exit 0` on mismatch (BASELINE I-5) | Manual gate test |
| I-6 | NEW | Affected gates accept only `y`/`Y` as yes; any other input declines. | Affected gates | Y/N acceptance check | Feed `y`, `Y`, `n`, `N`, `foo`, empty, EOF |
| I-7 | NEW | Prompt line is rendered in bold. | Affected gate prompts | Terminal ANSI formatting | Output contains bold ANSI codes |
| I-8 | NEW | Prompt states the action/file being approved and offers `[Y/N]`. | Affected gate prompts | Prompt string construction | Output inspection |

## 8. Compatibility requirements

- Exit codes on decline are preserved (I-4, I-5).
- Approval hash file format and path (`.workflow/approvals/<name>.sha256`) are unchanged (I-2).
- `.workflow/state`, `.workflow/origin`, `.workflow/audit-verdict`, and `.workflow/lock` contracts are untouched (BASELINE §6).
- `from-issue.sh` `RUN` gate remains exact-word (B-4).
- Scripts that previously piped `APPROVE`/`ACKNOWLEDGE` to the affected gates must be updated to pipe `y`/`Y`; this is an intentional UX break.
- Bold formatting must not corrupt piped/non-TTY input used by tests (BASELINE §13).

## 9. Error and failure behavior

- Empty input or EOF at an affected gate is treated as decline, with the preserved exit code.
- Any text other than `y`/`Y` is treated as decline.
- If the terminal does not support bold, the prompt must remain readable; no fatal error may be emitted solely because of styling.
- `stagegate.sh` file-modified-during-review still reopens the gate (B-6).

## 10. Security requirements

- The gate remains a strict human barrier: only `y`/`Y` advances; no hidden or whitespace-trimmed characters may be accepted as yes.
- Bold ANSI escape sequences must not be written into approval hash files, state files, or logs.
- No new credentials or secrets are introduced.

## 11. Migration requirements

- Update `README.md`, `QUICK_START.md`, and `scripts/README.md` to describe the new Y/N gate response.
- No data or state migration is required.

## 12. Rollback expectations

- Revert the source changes to restore exact-word `APPROVE`/`ACKNOWLEDGE` prompts and acceptance.
- Existing approval hashes remain valid; no state rollback is needed.

## 13. Explicit non-goals

- Converting `from-issue.sh` `RUN` confirmation to Y/N.
- Changing the approval hash algorithm or storage path.
- Changing `.workflow` state/lock/verdict contracts.
- Modifying `scripts/agent-kimi.sh` or its untracked test file.
- Adding configuration knobs for prompt wording, case sensitivity, or styling.
- Supporting languages other than English.

## 14. Assumptions and unresolved questions

Assumptions:

- "Bold" means ANSI terminal bold escape codes on the prompt line.
- Y/N is case-insensitive for yes (`y`/`Y`), and any other response declines.
- Empty input or EOF is treated as decline.
- The prompt retains the action/file name for context (e.g., "Approve `<file>`? [Y/N]").

Unresolved questions: none.
