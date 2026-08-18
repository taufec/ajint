#!/usr/bin/env bash
set -euo pipefail

: "${ADMIN_VPS_HOST:?missing ADMIN_VPS_HOST}"
: "${ADMIN_VPS_PORT:?missing ADMIN_VPS_PORT}"
: "${ADMIN_VPS_USER:?missing ADMIN_VPS_USER}"
: "${ADMIN_VPS_SSH_KEY:?missing ADMIN_VPS_SSH_KEY}"
: "${ADMIN_VPS_KNOWN_HOSTS:?missing ADMIN_VPS_KNOWN_HOSTS}"

request="${1:-}"
result_dir="${2:-}"
[ -n "$request" ] || { echo 'missing request path' >&2; exit 64; }
[ -n "$result_dir" ] || { echo 'missing result directory' >&2; exit 64; }
[ -f "$request" ] || { echo "missing request file: $request" >&2; exit 64; }

mkdir -p "$result_dir"
ssh_tmp="$(mktemp -d)"
cleanup() { rm -rf "$ssh_tmp"; }
trap cleanup EXIT

known_hosts="$ssh_tmp/known_hosts"
key_file="$ssh_tmp/bridge_key"
printf '%s\n' "$ADMIN_VPS_KNOWN_HOSTS" > "$known_hosts"
printf '%s\n' "$ADMIN_VPS_SSH_KEY" > "$key_file"
chmod 600 "$known_hosts" "$key_file"

sha256sum "$request" | awk '{print $1}' > "$result_dir/request-sha256.txt"
basename "$request" > "$result_dir/request-name.txt"

set +e
ssh \
  -i "$key_file" \
  -p "$ADMIN_VPS_PORT" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$known_hosts" \
  -o ForwardAgent=no \
  -o RequestTTY=no \
  -o ClearAllForwardings=yes \
  "$ADMIN_VPS_USER@$ADMIN_VPS_HOST" \
  'bash -se' \
  < "$request" \
  > "$result_dir/stdout.txt" \
  2> "$result_dir/stderr.txt"
rc=$?
set -e

printf '%s\n' "$rc" > "$result_dir/exit-code.txt"
exit "$rc"
