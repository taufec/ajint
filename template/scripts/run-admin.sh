#!/usr/bin/env bash
set -euo pipefail

: "${ADMIN_VPS_HOST:?missing ADMIN_VPS_HOST}"
: "${ADMIN_VPS_PORT:?missing ADMIN_VPS_PORT}"
: "${ADMIN_VPS_USER:?missing ADMIN_VPS_USER}"
: "${ADMIN_VPS_SSH_KEY:?missing ADMIN_VPS_SSH_KEY}"
: "${ADMIN_VPS_KNOWN_HOSTS:?missing ADMIN_VPS_KNOWN_HOSTS}"

request="${1:-requests/current.sh}"
[ -f "$request" ] || { echo 'missing request file' >&2; exit 64; }
mkdir -p result "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
printf '%s\n' "$ADMIN_VPS_KNOWN_HOSTS" > "$HOME/.ssh/known_hosts"
printf '%s\n' "$ADMIN_VPS_SSH_KEY" > "$HOME/.ssh/bridge_key"
chmod 600 "$HOME/.ssh/known_hosts" "$HOME/.ssh/bridge_key"
sha256sum "$request" | awk '{print $1}' > result/request-sha256.txt

set +e
ssh \
  -i "$HOME/.ssh/bridge_key" \
  -p "$ADMIN_VPS_PORT" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$HOME/.ssh/known_hosts" \
  -o ForwardAgent=no \
  -o RequestTTY=no \
  -o ClearAllForwardings=yes \
  "$ADMIN_VPS_USER@$ADMIN_VPS_HOST" \
  'bash -se' \
  < "$request" \
  > result/stdout.txt \
  2> result/stderr.txt
rc=$?
set -e

printf '%s\n' "$rc" > result/exit-code.txt
rm -f "$HOME/.ssh/bridge_key"
exit "$rc"
