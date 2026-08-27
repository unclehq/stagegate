#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p .workflow/approvals

hash_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

approve_file() {
    local file="$1"
    local approval_name="$2"

    if [[ ! -s "$file" ]]; then
        echo "Cannot approve missing or empty file: $file"
        exit 1
    fi

    echo
    echo "You are approving: $file"
    echo "SHA-256: $(hash_file "$file")"
    echo
    read -r -p "Type APPROVE exactly to continue: " confirmation

    if [[ "$confirmation" != "APPROVE" ]]; then
        echo "Approval cancelled."
        exit 1
    fi

    hash_file "$file" > ".workflow/approvals/${approval_name}.sha256"
    echo "Approved $file"
}

case "${1:-}" in
    approve-plan)
        approve_file PROJECT_PLAN.md PROJECT_PLAN
        echo "Next: ask the agent to run Stage 2."
        ;;

    approve-review)
        approve_file ADVERSARIAL_REVIEW.md ADVERSARIAL_REVIEW
        echo "Next: ask the agent to create UPDATED_PROJECT_PLAN.md."
        ;;

    approve-updated-plan)
        approve_file UPDATED_PROJECT_PLAN.md UPDATED_PROJECT_PLAN
        echo "Updated plan approved."
        echo "The agent may now build and continue through verification."
        ;;

    status)
        echo "Approval status:"
        for item in PROJECT_PLAN ADVERSARIAL_REVIEW UPDATED_PROJECT_PLAN; do
            approval=".workflow/approvals/${item}.sha256"
            file="${item}.md"

            if [[ -s "$approval" && -s "$file" ]]; then
                expected="$(cat "$approval")"
                actual="$(hash_file "$file")"

                if [[ "$expected" == "$actual" ]]; then
                    echo "  $file: APPROVED"
                else
                    echo "  $file: CHANGED AFTER APPROVAL"
                fi
            else
                echo "  $file: NOT APPROVED"
            fi
        done
        ;;

    *)
        cat <<'USAGE'
Usage:

  ./scripts/workflow.sh approve-plan
  ./scripts/workflow.sh approve-review
  ./scripts/workflow.sh approve-updated-plan
  ./scripts/workflow.sh status
USAGE
        exit 1
        ;;
esac
