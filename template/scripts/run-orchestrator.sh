#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
batch_dir="${1:-}"
result_dir="${2:-}"
[ -n "$batch_dir" ] || { echo 'missing batch directory' >&2; exit 64; }
[ -n "$result_dir" ] || { echo 'missing result directory' >&2; exit 64; }
[ -d "$batch_dir" ] || { echo "missing batch directory: $batch_dir" >&2; exit 64; }

mapfile -d '' waves < <(find "$batch_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
[ "${#waves[@]}" -gt 0 ] || { echo "batch has no wave directories: $batch_dir" >&2; exit 64; }

mkdir -p "$result_dir/waves"
: > "$result_dir/summary.tsv"
overall=0

for wave in "${waves[@]}"; do
  wave_name="$(basename "$wave")"
  wave_result="$result_dir/waves/$wave_name"

  if bash "$script_dir/run-wave.sh" "$wave" "$wave_result"; then
    wave_rc=0
  else
    wave_rc=$?
    overall=1
  fi

  if [ -f "$wave_result/summary.tsv" ]; then
    while IFS=$'\t' read -r worker worker_rc sha; do
      [ -n "${worker:-}" ] || continue
      printf '%s\t%s\t%s\t%s\n' "$wave_name" "$worker" "$worker_rc" "$sha" >> "$result_dir/summary.tsv"
    done < "$wave_result/summary.tsv"
  fi

  if [ "$wave_rc" -ne 0 ]; then
    break
  fi
done

printf '%s\n' "$overall" > "$result_dir/exit-code.txt"
exit "$overall"
