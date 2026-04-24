#!/bin/bash
#SBATCH --job-name=memtest
#SBATCH --time=00:05:00
#SBATCH --mem=1G
#SBATCH --cpus-per-task=1
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null

set -euo pipefail

REPO_ROOT="${SLURM_SUBMIT_DIR:-$PWD}"
STRACE_BIN="${REPO_ROOT}/opt/strace-6.19/bin/strace"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUT_LOG="${REPO_ROOT}/logs/memory_testing-${SLURM_JOB_ID}-${TIMESTAMP}.out"
ERR_LOG="${REPO_ROOT}/logs/memory_testing-${SLURM_JOB_ID}-${TIMESTAMP}.err"
TRACE_LOG="${REPO_ROOT}/logs/memory_testing-${SLURM_JOB_ID}-${TIMESTAMP}.strace"

cd "${REPO_ROOT}"

exec >"${OUT_LOG}" 2>"${ERR_LOG}"

"${STRACE_BIN}" \
  -tt -T -yy -s 0 \
  -e trace=openat,read,lseek,close \
  -o "${TRACE_LOG}" \
  python3 scripts/memory_testing.py
