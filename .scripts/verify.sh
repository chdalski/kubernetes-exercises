#!/bin/bash

RESET_COLOR='\033[0m'
SOLVED_COLOR='\033[0;32m'
FAILED_COLOR='\033[0;31m'

solved() {
  printf "Task %2s: ${SOLVED_COLOR}solved!${RESET_COLOR} 🎉\n" "$TASK_NUMBER"
}

failed() {
  printf "Task %2s: ${FAILED_COLOR}failed!${RESET_COLOR} 🙈\n" "$TASK_NUMBER"
}

# Helper for debug messages
debug() {
  [ "${CKAD_EXAM_DEBUG}" = "true" ] && echo "[DEBUG][Task ${TASK_NUMBER}] $1"
}

# Runner for the verification tasks
run_verification() {
    local array_name="$1"
    shift

    # Get the array length
    local array_length
    eval "array_length=\${#${array_name}[@]}"

    if [[ $# -eq 0 ]]; then
        # No arguments: verify all tasks
        local idx
        for ((idx=0; idx<array_length; idx++)); do
            eval "FUNC=\${${array_name}[$idx]}"
            if declare -f "$FUNC" > /dev/null; then
                $FUNC
            else
                echo "Warning: $FUNC not defined."
            fi
        done
    elif [[ $# -eq 1 ]]; then
        # One argument: verify only the specified task (by index, 1-based)
        IDX=$(( $1 - 1 ))
        if [[ $IDX -ge 0 && $IDX -lt $array_length ]]; then
            eval "FUNC=\${${array_name}[$IDX]}"
            if declare -f "$FUNC" > /dev/null; then
                $FUNC
            else
                echo "Error: $FUNC not defined."
                exit 1
            fi
        else
            echo "Error: Task $1 does not exist."
            exit 1
        fi
    else
        echo "Usage: $0 [TASKNUMBER]"
        exit 1
    fi
}
