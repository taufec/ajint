#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wave_dir="${1:-}"
result_dir="${2:-}"
[ -n "$wave_dir" ] || { echo 'missing wave directory' >&2; exit 64; }
[ -n "$result_dir" ] || { echo 'missing result directory' >&2; exit 64; }
[ -d "$wave_dir" ] || { echo "missing wave directory: $wave_dir" >&2; exit 64; }

max_parallel="${AJINT_MAX_PARALLEL:-4}"
[[ "$max_parallel" =~ ^[1-9][0-9]*$ ]] || { echo 'AJINT_MAX_PARALLEL must be a positive integer' >&2; exit 65; }

mapfile -d '' requests < <(find "$wave_dir" -mindepth 1 -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
count="${#requests[@]}"
[ "$count" -gt 0 ] || { echo "wave has no .sh requests: $wave_dir" >&2; exit 64; }
[ "$count" -le "$max_parallel" ] || {
  echo "wave has $count requests; AJINT_MAX_PARALLEL=$max_parallel" >&2
  exit 65
}

mkdir -p "$result_dir"
: > "$result_dir/summary.tsv"

declare -a pids=()
declare -a names=()

for request in "${requests[@]}"; do
  name="$(basename "$request" .sh)"
  names+=("$name")
  bash "$script_dir/run-request.sh" "$request" "$result_dir/$name" &
  pids+=("$!")
done

overall=0
for i in "${!pids[@]}"; do
  if wait "${pids[$i]}"; then
    rc=0
  else
    rc=$?
    overall=1
  fi
  sha="$(cat "$result_dir/${names[$i]}/request-sha256.txt" 2>/dev/null || printf '-')"
  printf '%s\t%s\t%s\n' "${names[$i]}" "$rc" "$sha" >> "$result_dir/summary.tsv"
done

exit "$overall"
