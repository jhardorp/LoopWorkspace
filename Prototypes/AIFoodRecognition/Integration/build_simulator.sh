#!/bin/bash
# Keep the full build log and expose progress without flooding the Actions log.
set -uo pipefail

if [[ "$OSTYPE" != darwin* || "${CI:-}" != true || "${GITHUB_REF:-}" != refs/heads/migration/loop4-ai-photo ]]; then
  echo "Simulator build wrapper requires macOS migration CI." >&2
  exit 1
fi
if (( $# < 2 )); then
  echo "Usage: build_simulator.sh LOG XCODEBUILD_ARGUMENTS..." >&2
  exit 1
fi
build_log_path="$1"
shift

(
  while sleep 45; do
    tail -n 2 "$build_log_path" 2>/dev/null || true
  done
) &
build_progress_pid=$!
trap 'kill "$build_progress_pid" 2>/dev/null || true' EXIT

build_exit_status=0
xcodebuild "$@" > "$build_log_path" 2>&1 || build_exit_status=$?
if (( build_exit_status != 0 )); then
  tail -n 180 "$build_log_path"
else
  tail -n 12 "$build_log_path"
fi
exit "$build_exit_status"
