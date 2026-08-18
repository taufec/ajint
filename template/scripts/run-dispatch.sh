#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
control_root="$(cd "$script_dir/.." && pwd)"
dispatch_file="${1:-$control_root/requests/dispatch.txt}"
[ -f "$dispatch_file" ] || { echo "missing dispatch file: $dispatch_file" >&2; exit 64; }

IFS= read -r batch < "$dispatch_file" || true
batch="${batch%$'\r'}"
[[ "$batch" =~ ^[A-Za-z0-9._-]+$ ]] || { echo 'invalid batch id' >&2; exit 64; }
[ "$batch" != '.' ] && [ "$batch" != '..' ] || { echo 'invalid batch id' >&2; exit 64; }

batch_dir="$control_root/requests/batches/$batch"
[ -d "$batch_dir" ] || { echo "batch not found: $batch" >&2; exit 64; }

result_dir="$control_root/result/parallel"
rm -rf "$result_dir"
mkdir -p "$result_dir"
printf '%s\n' "$batch" > "$result_dir/batch.txt"

set +e
bash "$script_dir/run-orchestrator.sh" "$batch_dir" "$result_dir"
rc=$?
set -e

# run-orchestrator writes the overall exit code; keep dispatch exit identical.
exit "$rc"
