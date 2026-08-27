#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STATE_DIR=".workflow"
APPROVAL_DIR="$STATE_DIR/approvals"
LOG_DIR="$STATE_DIR/logs"
STATE_FILE="$STATE_DIR/state"
SESSION_FILE="$STATE_DIR/session-head"
LEDGER_FILE="$STATE_DIR/cost.tsv"

mkdir -p "$APPROVAL_DIR" "$LOG_DIR"

# ---------------------------------------------------------------------------
# Tunables
# ---------------------------------------------------------------------------

# Track. `full` runs baseline, spec, and plan as three separate stages.
# `small` produces all three artifacts in one call, sized to a change whose
# analysis does not justify three cold starts. Every review gate, the
# adversarial review, the checklist, and the final audit run on both tracks.
TRACK="${WORKFLOW_TRACK:-full}"

# Stage models. Opus is roughly 5x Sonnet, so it is reserved for the two
# stages where a wrong answer is expensive to undo: the plan everything else
# hangs off, and the implementation itself. BASELINE and EXECUTE_CHECKLIST
# carry the largest contexts in the pipeline (whole-repo reads, full test
# output) and are mostly read-and-record work, so they pay Sonnet rates.
MODEL_BASELINE="${WORKFLOW_MODEL_BASELINE:-sonnet}"
MODEL_CHANGE_SPEC="${WORKFLOW_MODEL_CHANGE_SPEC:-sonnet}"
MODEL_CHANGE_PLAN="${WORKFLOW_MODEL_CHANGE_PLAN:-opus}"
MODEL_UPDATED_PLAN="${WORKFLOW_MODEL_UPDATED_PLAN:-sonnet}"
MODEL_IMPLEMENT="${WORKFLOW_MODEL_IMPLEMENT:-opus}"
MODEL_EXECUTE="${WORKFLOW_MODEL_EXECUTE:-sonnet}"
MODEL_SMALL="${WORKFLOW_MODEL_SMALL:-opus}"

EFFORT_CHANGE_SPEC="${WORKFLOW_EFFORT_CHANGE_SPEC:-medium}"
EFFORT_UPDATED_PLAN="${WORKFLOW_EFFORT_UPDATED_PLAN:-medium}"
EFFORT_EXECUTE="${WORKFLOW_EFFORT_EXECUTE:-medium}"

# Per-stage stop-loss, in dollars. This is a runaway guard, not a target: the
# cap is checked between turns, so a stage stops shortly after crossing it
# rather than being preempted mid-turn. Raise a cap rather than lowering the
# work if a legitimate stage trips it.
BUDGET_BASELINE="${WORKFLOW_BUDGET_BASELINE:-10}"
BUDGET_CHANGE_SPEC="${WORKFLOW_BUDGET_CHANGE_SPEC:-5}"
BUDGET_CHANGE_PLAN="${WORKFLOW_BUDGET_CHANGE_PLAN:-12}"
BUDGET_UPDATED_PLAN="${WORKFLOW_BUDGET_UPDATED_PLAN:-5}"
BUDGET_IMPLEMENT="${WORKFLOW_BUDGET_IMPLEMENT:-40}"
BUDGET_EXECUTE="${WORKFLOW_BUDGET_EXECUTE:-20}"
BUDGET_SMALL="${WORKFLOW_BUDGET_SMALL:-12}"

# Codex reasoning effort. The two judgement stages think; the two checklist
# stages transcribe an approved specification into checks.
CODEX_EFFORT_REVIEW="${WORKFLOW_CODEX_EFFORT_REVIEW:-high}"
CODEX_EFFORT_CHECKLIST="${WORKFLOW_CODEX_EFFORT_CHECKLIST:-low}"
CODEX_EFFORT_AUDIT="${WORKFLOW_CODEX_EFFORT_AUDIT:-high}"

# Carry one forked conversation across the Claude stages. Off by default:
# a forked stage inherits the entire transcript that produced the upstream
# artifacts and re-sends it on every turn, so cost grows with the pipeline.
# The artifacts on disk are a compressed form of that same context. Set to 1
# to trade the money back for latency.
SESSION_REUSE="${WORKFLOW_SESSION_REUSE:-0}"

# Write the Codex verification checklist concurrently with implementation.
# Set to 0 to fall back to the serial single-shot checklist stage.
PARALLEL_CHECKLIST="${WORKFLOW_PARALLEL_CHECKLIST:-1}"

# Agent/reviewer CLI commands. Defaults are `claude` and `codex`. Swap either
# for a compatible CLI or a wrapper script. The agent CLI must accept the same
# flags as `claude -p` (model, effort, max-turns, output-format stream-json,
# allowedTools, stdin prompt). The reviewer CLI must accept the same flags as
# `codex exec` (ephemeral, sandbox read-only, model, output-last-message).
AGENT_CMD="${WORKFLOW_AGENT_CMD:-claude}"
REVIEWER_CMD="${WORKFLOW_REVIEWER_CMD:-codex}"

# `$AGENT_CMD -p` is non-interactive, so a normal permission prompt can never be
# answered. Explicitly grant the tools needed by the analysis, writing, build,
# and verification stages. This is an allowlist, not a permission bypass.
CLAUDE_TOOLS="Read,Glob,Grep,Write,Edit,TodoWrite,Bash"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

hash_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

require_file() {
    if [[ ! -s "$1" ]]; then
        echo "Required file missing or empty: $1"
        exit 1
    fi
}

set_state() {
    printf '%s\n' "$1" > "$STATE_FILE"
}

get_state() {
    if [[ -s "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo ANALYZE
    fi
}

# stage, seconds, usd, input, output, cache_read, cache_write
record_cost() {
    if [[ ! -s "$LEDGER_FILE" ]]; then
        printf 'stage\tsecs\tusd\tin\tout\tcache_r\tcache_w\n' > "$LEDGER_FILE"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >> "$LEDGER_FILE"
}

ledger_total() {
    if [[ -s "$LEDGER_FILE" ]]; then
        awk -F'\t' 'NR>1 && $3 != "-" {t += $3} END {printf "%.2f", t}' "$LEDGER_FILE"
    else
        printf '0.00'
    fi
}

show_spend() {
    echo "  Stage cost so far: \$$(ledger_total)"
}

verify_approval() {
    local file="$1"
    local approval_name="$2"
    local approval="$APPROVAL_DIR/${approval_name}.sha256"

    require_file "$file"
    require_file "$approval"

    local expected
    local actual

    expected="$(cat "$approval")"
    actual="$(hash_file "$file")"

    if [[ "$expected" != "$actual" ]]; then
        echo "$file changed after approval."
        echo "Review and approve the new contents."
        exit 1
    fi
}

# One gate can cover several documents. Each document is still hashed and
# approved individually; batching only removes the round-trip of stopping the
# pipeline twice for two documents that are read together anyway.
#
# Usage: human_gate ACTION file1 approval_name1 [file2 approval_name2 ...]
human_gate() {
    local action="$1"
    shift

    local -a files=()
    local -a names=()

    while [[ "$#" -gt 0 ]]; do
        require_file "$1"
        files+=("$1")
        names+=("$2")
        shift 2
    done

    echo
    echo "=================================================="
    echo "HUMAN REVIEW REQUIRED"
    local f
    for f in "${files[@]}"; do
        echo "  $f"
    done
    echo "=================================================="
    echo
    echo "Review with:"
    echo "  less ${files[*]}"
    echo
    echo "Edit with:"
    echo "  code ${files[*]}"
    echo
    echo "Edits you make now are picked up by the next stage."
    show_spend
    echo

    if [[ "${#files[@]}" -gt 1 ]]; then
        read -r -p "Press ENTER after reviewing all documents above..."
    else
        read -r -p "Press ENTER after reviewing..."
    fi

    echo
    read -r -p "Type $action exactly to continue: " response

    if [[ "$response" != "$action" ]]; then
        echo "Gate not accepted. Workflow remains paused."
        exit 0
    fi

    local i
    for i in "${!files[@]}"; do
        hash_file "${files[$i]}" > "$APPROVAL_DIR/${names[$i]}.sha256"
        echo "Recorded approval for ${files[$i]}"
    done
}

# Render Claude's streaming JSON event feed as readable progress. Startup
# warnings and other non-JSON lines are ignored rather than making jq fail.
format_claude_stream() {
    jq -R -r --unbuffered '
        (fromjson? // empty) as $e
        | if $e.type == "assistant" then
              ($e.message.content[]?
               | if .type == "text" then .text
                 elif .type == "tool_use" then "  [tool] \(.name)"
                 else empty end)
          elif $e.type == "user" then
              ($e.message.content[]?
               | select(.type == "tool_result" and .is_error == true)
               | .content
               | (if type == "array" then map(.text? // "") | join(" ")
                  else tostring end)
               | "  [tool ERROR] \(.[0:200])")
          elif $e.type == "result" then
              "\n[done] \($e.subtype) — \($e.num_turns) turns, \($e.duration_ms / 1000 | floor)s, $\($e.total_cost_usd // 0 | .*100 | round / 100)"
          else empty end
    '
}

run_claude() {
    local prompt_file="$1"
    local log_name="$2"
    local model="$3"
    local effort="${4:-}"
    local max_turns="${5:-80}"
    local budget="${6:-}"

    require_file "$prompt_file"

    local -a flags=(
        -p
        --model "$model"
        --max-turns "$max_turns"
        --output-format stream-json
        --verbose
        --strict-mcp-config
        --exclude-dynamic-system-prompt-sections
        --allowedTools "$CLAUDE_TOOLS"
    )

    if [[ -n "$effort" ]]; then
        flags+=(--effort "$effort")
    fi

    if [[ -n "$budget" ]]; then
        flags+=(--max-budget-usd "$budget")
    fi

    # Forking inherits the previous stage's whole transcript. That is faster
    # but costs more every turn, so it is off unless asked for. Forking leaves
    # the parent session untouched, so a failed stage retries from the same
    # point.
    local head=""
    if [[ "$SESSION_REUSE" == "1" && -s "$SESSION_FILE" ]]; then
        head="$(cat "$SESSION_FILE")"
        flags+=(--resume "$head" --fork-session)
    fi

    echo
    echo "Launching agent ($AGENT_CMD): $log_name"
    echo "Model: $model${effort:+  Effort: $effort}${budget:+  Cap: \$$budget}"
    if [[ -n "$head" ]]; then
        echo "Forking session: $head"
    fi
    echo

    # Use stdin for the prompt because --allowedTools is variadic and can
    # otherwise consume a trailing positional prompt. Streaming also makes a
    # long-running stage visibly active instead of buffering until completion.
    local start="$SECONDS"
    local status=0
    "$AGENT_CMD" "${flags[@]}" \
        < "$prompt_file" \
        2>&1 \
        | tee "$LOG_DIR/${log_name}.jsonl" \
        | format_claude_stream || status=$?

    local elapsed="$((SECONDS - start))"
    local log="$LOG_DIR/${log_name}.jsonl"

    # The final result event, if the run produced one.
    local result
    result="$(jq -R -c 'fromjson? | select(.type == "result")' < "$log" | tail -n 1)"

    if [[ -n "$result" ]]; then
        record_cost "agent:$log_name" "$elapsed" \
            "$(printf '%s' "$result" | jq -r '.total_cost_usd // 0')" \
            "$(printf '%s' "$result" | jq -r '.usage.input_tokens // 0')" \
            "$(printf '%s' "$result" | jq -r '.usage.output_tokens // 0')" \
            "$(printf '%s' "$result" | jq -r '.usage.cache_read_input_tokens // 0')" \
            "$(printf '%s' "$result" | jq -r '.usage.cache_creation_input_tokens // 0')"
    else
        record_cost "agent:$log_name" "$elapsed" - - - - -
    fi

    if [[ "$status" -ne 0 ]]; then
        echo "Agent ($AGENT_CMD) exited with status $status."
        echo "Raw event log: $log"
        exit "$status"
    fi

    # A budget breach, a turn-limit stop, and an API failure all exit 0 and
    # report themselves only inside the result event. Without this check the
    # stage would look like a success and the pipeline would advance on a
    # partial artifact.
    if [[ -z "$result" ]]; then
        echo "No result event in $log; treating $log_name as failed."
        exit 1
    fi

    local is_error subtype
    is_error="$(printf '%s' "$result" | jq -r '.is_error // false')"
    subtype="$(printf '%s' "$result" | jq -r '.subtype // "unknown"')"

    if [[ "$is_error" == "true" ]]; then
        echo
        echo "Stage $log_name reported failure: $subtype"
        if [[ "$subtype" == *budget* ]]; then
            echo "The \$$budget cap for this stage was reached."
            echo "Raise it with the matching WORKFLOW_BUDGET_* variable and re-run."
        fi
        echo "Raw event log: $log"
        show_spend
        exit 1
    fi

    show_spend

    if [[ "$SESSION_REUSE" == "1" ]]; then
        local next
        next="$(printf '%s' "$result" | jq -r '.session_id // empty')"
        if [[ -n "$next" ]]; then
            printf '%s\n' "$next" > "$SESSION_FILE"
        else
            echo "Warning: no session id in $log_name; next stage cold-starts."
        fi
    fi
}

# Codex reports token usage on its last line but never a dollar figure, so the
# ledger records tokens for Codex stages and a dash for cost.
record_codex_cost() {
    local log_name="$1"
    local elapsed="$2"
    local log="$LOG_DIR/${log_name}.log"
    local tokens="-"

    if [[ -s "$log" ]]; then
        tokens="$(awk '/tokens used/ {getline; gsub(/[^0-9]/, "", $0); if ($0 != "") t = $0} END {print (t == "" ? "-" : t)}' "$log")"
    fi

    record_cost "reviewer:$log_name" "$elapsed" - - - - "$tokens"
}

run_codex() {
    local prompt_file="$1"
    local output_file="$2"
    local log_name="$3"
    local effort="${4:-}"

    require_file "$prompt_file"

    local -a flags=(
        exec
        --ephemeral
        --sandbox read-only
        --output-last-message "$output_file"
    )

    if [[ -n "$effort" ]]; then
        flags+=(-c "model_reasoning_effort=$effort")
    fi

    echo
    echo "Launching reviewer ($REVIEWER_CMD): $log_name${effort:+  Effort: $effort}"

    local start="$SECONDS"
    "$REVIEWER_CMD" "${flags[@]}" "$(cat "$prompt_file")" \
        2>&1 | tee "$LOG_DIR/${log_name}.log"

    record_codex_cost "$log_name" "$((SECONDS - start))"
    require_file "$output_file"
}

BG_PID=""
BG_LABEL=""
BG_START=0

cleanup_bg() {
    if [[ -n "$BG_PID" ]] && kill -0 "$BG_PID" 2>/dev/null; then
        echo "Stopping background stage: $BG_LABEL"
        kill "$BG_PID" 2>/dev/null || true
        wait "$BG_PID" 2>/dev/null || true
    fi
}
trap cleanup_bg EXIT

start_codex_bg() {
    local prompt_file="$1"
    local output_file="$2"
    local log_name="$3"
    local effort="${4:-}"

    require_file "$prompt_file"
    rm -f "$output_file"

    local -a flags=(
        exec
        --ephemeral
        --sandbox read-only
        --output-last-message "$output_file"
    )

    if [[ -n "$effort" ]]; then
        flags+=(-c "model_reasoning_effort=$effort")
    fi

    echo
    echo "Starting background reviewer ($REVIEWER_CMD) stage: $log_name${effort:+  Effort: $effort}"
    echo "Log: $LOG_DIR/${log_name}.log"

    "$REVIEWER_CMD" "${flags[@]}" "$(cat "$prompt_file")" \
        > "$LOG_DIR/${log_name}.log" 2>&1 &

    BG_PID=$!
    BG_LABEL="$log_name"
    BG_START="$SECONDS"
}

wait_codex_bg() {
    local output_file="$1"

    if [[ -z "$BG_PID" ]]; then
        return 0
    fi

    echo
    echo "Waiting for background Codex stage: $BG_LABEL"

    local pid="$BG_PID"
    local label="$BG_LABEL"
    local status=0
    wait "$pid" || status=$?
    BG_PID=""

    record_codex_cost "$label" "$((SECONDS - BG_START))"

    if [[ "$status" -ne 0 ]]; then
        echo "Background Codex stage $label failed with status $status."
        echo "Log: $LOG_DIR/${label}.log"
        exit "$status"
    fi

    require_file "$output_file"
    echo "Background Codex stage complete: $label"
}

# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

case "$TRACK" in
    full|small) ;;
    *) echo "Unknown WORKFLOW_TRACK: $TRACK (expected 'full' or 'small')"; exit 1 ;;
esac

echo "Track: $TRACK"

while true; do
    state="$(get_state)"

    echo
    echo "Current state: $state"

    case "$state" in
        ANALYZE)
            require_file CHANGE_REQUEST.md

            if [[ "$TRACK" == "small" ]]; then
                # One call writes all three analysis artifacts, so downstream
                # prompts, approval hashes, and Codex stages are unchanged.
                run_claude prompts/change/small-analysis.md small-analysis \
                    "$MODEL_SMALL" "" 100 "$BUDGET_SMALL"
                require_file BASELINE_REPORT.md
                require_file CHANGE_SPEC.md
                require_file CHANGE_PLAN.md

                run_codex \
                    prompts/change/adversarial-review.md \
                    ADVERSARIAL_REVIEW.md \
                    adversarial-review \
                    "$CODEX_EFFORT_REVIEW"
            else
                run_claude prompts/change/baseline.md baseline \
                    "$MODEL_BASELINE" "" 120 "$BUDGET_BASELINE"
                require_file BASELINE_REPORT.md

                run_claude prompts/change/change-spec.md change-spec \
                    "$MODEL_CHANGE_SPEC" "$EFFORT_CHANGE_SPEC" 60 \
                    "$BUDGET_CHANGE_SPEC"
                require_file CHANGE_SPEC.md
            fi

            set_state WAIT_ANALYSIS_APPROVAL
            ;;

        WAIT_ANALYSIS_APPROVAL)
            if [[ "$TRACK" == "small" ]]; then
                human_gate ACKNOWLEDGE \
                    BASELINE_REPORT.md BASELINE_REPORT \
                    CHANGE_SPEC.md CHANGE_SPEC \
                    CHANGE_PLAN.md CHANGE_PLAN \
                    ADVERSARIAL_REVIEW.md ADVERSARIAL_REVIEW
                set_state UPDATED_PLAN
            else
                human_gate APPROVE \
                    BASELINE_REPORT.md BASELINE_REPORT \
                    CHANGE_SPEC.md CHANGE_SPEC
                set_state PLAN
            fi
            ;;

        PLAN)
            verify_approval BASELINE_REPORT.md BASELINE_REPORT
            verify_approval CHANGE_SPEC.md CHANGE_SPEC

            run_claude prompts/change/change-plan.md change-plan \
                "$MODEL_CHANGE_PLAN" "" 120 "$BUDGET_CHANGE_PLAN"
            require_file CHANGE_PLAN.md

            run_codex \
                prompts/change/adversarial-review.md \
                ADVERSARIAL_REVIEW.md \
                adversarial-review \
                "$CODEX_EFFORT_REVIEW"

            set_state WAIT_PLAN_APPROVAL
            ;;

        WAIT_PLAN_APPROVAL)
            human_gate ACKNOWLEDGE \
                CHANGE_PLAN.md CHANGE_PLAN \
                ADVERSARIAL_REVIEW.md ADVERSARIAL_REVIEW
            set_state UPDATED_PLAN
            ;;

        UPDATED_PLAN)
            verify_approval BASELINE_REPORT.md BASELINE_REPORT
            verify_approval CHANGE_SPEC.md CHANGE_SPEC
            verify_approval CHANGE_PLAN.md CHANGE_PLAN
            verify_approval ADVERSARIAL_REVIEW.md ADVERSARIAL_REVIEW

            run_claude prompts/change/updated-change-plan.md updated-change-plan \
                "$MODEL_UPDATED_PLAN" "$EFFORT_UPDATED_PLAN" 60 \
                "$BUDGET_UPDATED_PLAN"
            require_file UPDATED_CHANGE_PLAN.md

            set_state WAIT_UPDATED_PLAN_APPROVAL
            ;;

        WAIT_UPDATED_PLAN_APPROVAL)
            human_gate APPROVE \
                UPDATED_CHANGE_PLAN.md UPDATED_CHANGE_PLAN
            set_state IMPLEMENT
            ;;

        IMPLEMENT)
            verify_approval UPDATED_CHANGE_PLAN.md UPDATED_CHANGE_PLAN

            # The verification checklist is derived from the frozen, approved
            # artifacts, so it can be written while the implementation runs
            # instead of after it. Its prompt forbids reading source, which
            # would otherwise race Claude's in-flight edits; anything that
            # genuinely depends on the implementation is added by the delta
            # pass in the CHECKLIST state.
            if [[ "$PARALLEL_CHECKLIST" == "1" ]]; then
                start_codex_bg \
                    prompts/change/manual-checklist-base.md \
                    "$STATE_DIR/MANUAL_CHECKLIST.base.md" \
                    manual-checklist-base \
                    "$CODEX_EFFORT_CHECKLIST"
            fi

            run_claude prompts/change/implement-change.md implementation \
                "$MODEL_IMPLEMENT" "" 200 "$BUDGET_IMPLEMENT"
            require_file IMPLEMENTATION_NOTES.md
            require_file CHANGE_TEST_REPORT.md

            git diff --check
            git diff --stat > "$STATE_DIR/change-stat.txt"
            git diff > "$STATE_DIR/change.diff"

            if [[ "$PARALLEL_CHECKLIST" == "1" ]]; then
                wait_codex_bg "$STATE_DIR/MANUAL_CHECKLIST.base.md"
            fi

            set_state CHECKLIST
            ;;

        CHECKLIST)
            if [[ "$PARALLEL_CHECKLIST" == "1" ]]; then
                require_file "$STATE_DIR/MANUAL_CHECKLIST.base.md"
                run_codex \
                    prompts/change/manual-checklist-delta.md \
                    MANUAL_CHECKLIST.md \
                    manual-checklist-delta \
                    "$CODEX_EFFORT_CHECKLIST"
            else
                run_codex \
                    prompts/change/manual-checklist.md \
                    MANUAL_CHECKLIST.md \
                    manual-checklist \
                    "$CODEX_EFFORT_CHECKLIST"
            fi
            set_state EXECUTE_CHECKLIST
            ;;

        EXECUTE_CHECKLIST)
            run_claude prompts/change/execute-change-checklist.md execute-checklist \
                "$MODEL_EXECUTE" "$EFFORT_EXECUTE" 200 "$BUDGET_EXECUTE"
            require_file VERIFICATION_REPORT.md
            set_state FINAL_AUDIT
            ;;

        FINAL_AUDIT)
            run_codex \
                prompts/change/final-audit.md \
                FINAL_AUDIT.md \
                final-audit \
                "$CODEX_EFFORT_AUDIT"
            set_state COMPLETE
            ;;

        COMPLETE)
            echo
            echo "Change workflow complete."
            echo
            echo "Review:"
            echo "  CHANGE_TEST_REPORT.md"
            echo "  VERIFICATION_REPORT.md"
            echo "  FINAL_AUDIT.md"
            echo "  .workflow/change.diff"
            if [[ -s "$LEDGER_FILE" ]]; then
                echo
                echo "Cost ledger ($LEDGER_FILE):"
                column -t -s "$(printf '\t')" < "$LEDGER_FILE" | sed 's/^/  /'
                echo
                echo "  Total Claude spend: \$$(ledger_total)"
                echo "  (Codex stages report tokens only; see the cache_w column.)"
            fi
            exit 0
            ;;

        *)
            echo "Unknown workflow state: $state"
            echo "Delete $STATE_FILE to restart from the beginning."
            exit 1
            ;;
    esac
done
