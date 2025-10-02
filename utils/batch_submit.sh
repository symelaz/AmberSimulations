#!/bin/bash
#
# Usage:
#   ./submit_jobs.sh <file> <count> [continue_from_jobid]
#
# Arguments:
#   $1 → File to submit (sbatch script)
#   $2 → Number of times to submit
#   $3 → (Optional) Continue from this job ID
#

# Function: submit
# Submits a job using sbatch and extracts the Job ID
submit() {
    local sbr
    sbr="$(/usr/bin/sbatch "$@")"
    wait

    if [[ "$sbr" =~ Submitted\ batch\ job\ ([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "Error: sbatch submission failed." >&2
        exit 1
    fi
}

# Validate arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <file> <count> [continue_from_jobid]" >&2
    exit 1
fi

# Handle dependency if a job ID is provided
if [[ $# -eq 3 ]]; then
    jid="$3"
    echo "Continuing from Job ID: $jid"
    jid="$(submit --dependency=afterany:$jid "$1")"
else
    echo "No dependency specified."
    jid="$(submit "$1")"
fi

wait
echo "SUBMITTED JOBID: $jid"

# Submit dependent jobs sequentially
for ((i = 1; i <= $2; i++)); do
    jid="$(submit --dependency=afterany:$jid "$1")"
    wait
    echo "SUBMITTED JOBID: $jid"
done
