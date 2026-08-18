#!/usr/bin/env bash
set -euo pipefail

UPSTREAM="taufec/chatgpt-gitops"
BRIDGE_PORT="${BRIDGE_PORT:-22}"
BRIDGE_REPO="${BRIDGE_REPO:-chatgpt-machine-admin}"
BRIDGE_USER="${BRIDGE_USER:-$(id -un)}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 20
  }
}

for c in gh git ssh ssh-keygen curl awk base64; do need "$c"; done

gh auth status >/dev/null 2>&1 || {
  echo 'ERROR: GitHub CLI is not authenticated. Run: gh auth login' >&2
  exit 21
}

GH_OWNER="$(gh api user --jq .login)"
CONTROL_REPO="$GH_OWNER/$BRIDGE_REPO"

if [ -z "${BRIDGE_HOST:-}" ]; then
  BRIDGE_HOST="$(curl -4 -fsSL --max-time 8 https://api.ipify.org 2>/dev/null || true)"
fi

if [ -z "${BRIDGE_HOST:-}" ]; then
  echo 'ERROR: public host could not be detected.' >&2
  echo 'Re-run with BRIDGE_HOST=<public-ip-or-dns>.' >&2
  exit 22
fi

if [ "$BRIDGE_USER" != "$(id -un)" ]; then
  echo 'ERROR: MVP currently installs SSH authorization for the current OS user only.' >&2
  echo "Current user: $(id -un); requested BRIDGE_USER: $BRIDGE_USER" >&2
  exit 23
fi

SSH_DIR="$HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
KEY_DIR="$(mktemp -d)"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$KEY_DIR" "$WORK"; }
trap cleanup EXIT
KEY="$KEY_DIR/bridge_ed25519"

ssh-keygen -q -t ed25519 -N '' -C "chatgpt-gitops:$CONTROL_REPO" -f "$KEY"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
cat "$KEY.pub" >> "$AUTH_KEYS"

KNOWN_HOSTS=''
for pub in /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_rsa_key.pub; do
  if [ -r "$pub" ]; then
    read -r alg key _ < "$pub"
    if [ "$BRIDGE_PORT" = "22" ]; then
      KNOWN_HOSTS+="$BRIDGE_HOST $alg $key"$'\n'
    else
      KNOWN_HOSTS+="[$BRIDGE_HOST]:$BRIDGE_PORT $alg $key"$'\n'
    fi
  fi
done

if [ -z "$KNOWN_HOSTS" ]; then
  need ssh-keyscan
  KNOWN_HOSTS="$(ssh-keyscan -p "$BRIDGE_PORT" "$BRIDGE_HOST" 2>/dev/null)"
fi

if ! gh repo view "$CONTROL_REPO" >/dev/null 2>&1; then
  gh repo create "$CONTROL_REPO" \
    --private \
    --description 'Private ChatGPT GitOps machine control plane' >/dev/null
fi

mkdir -p "$WORK/repo/.github/workflows" "$WORK/repo/scripts" "$WORK/repo/requests"
for pair in \
  'template/.github/workflows/admin.yml:.github/workflows/admin.yml' \
  'template/scripts/run-admin.sh:scripts/run-admin.sh' \
  'template/requests/current.sh:requests/current.sh'; do
  src="${pair%%:*}"
  dest="${pair#*:}"
  gh api "repos/$UPSTREAM/contents/$src" --jq .content | tr -d '\n' | base64 -d > "$WORK/repo/$dest"
done

cat > "$WORK/repo/README.md" <<DOC
# $BRIDGE_REPO

Private machine control plane created by ChatGPT GitOps.

Target: \`$BRIDGE_USER@$BRIDGE_HOST:$BRIDGE_PORT\`

Flow: ChatGPT -> GitHub -> GitHub Actions -> SSH -> machine

Edit \`requests/current.sh\` to submit a remote task. Check the workflow artifact for stdout, stderr, exit code, and request SHA-256.
DOC

if [ ! -d "$WORK/repo/.git" ]; then
  git -C "$WORK/repo" init -q -b main
  git -C "$WORK/repo" remote add origin "https://github.com/$CONTROL_REPO.git"
fi

git -C "$WORK/repo" add .
GIT_AUTHOR_NAME='ChatGPT GitOps' \
GIT_AUTHOR_EMAIL='bridge@localhost' \
GIT_COMMITTER_NAME='ChatGPT GitOps' \
GIT_COMMITTER_EMAIL='bridge@localhost' \
  git -C "$WORK/repo" commit -m 'Initialize ChatGPT GitOps control plane' >/dev/null

gh auth setup-git >/dev/null 2>&1 || true
git -C "$WORK/repo" push -u origin main --force >/dev/null

gh secret set ADMIN_VPS_HOST --repo "$CONTROL_REPO" --body "$BRIDGE_HOST"
gh secret set ADMIN_VPS_PORT --repo "$CONTROL_REPO" --body "$BRIDGE_PORT"
gh secret set ADMIN_VPS_USER --repo "$CONTROL_REPO" --body "$BRIDGE_USER"
gh secret set ADMIN_VPS_SSH_KEY --repo "$CONTROL_REPO" < "$KEY"
printf '%s' "$KNOWN_HOSTS" | gh secret set ADMIN_VPS_KNOWN_HOSTS --repo "$CONTROL_REPO"

echo
echo 'ChatGPT GitOps installed.'
echo "Control repo: https://github.com/$CONTROL_REPO"
echo "Target: $BRIDGE_USER@$BRIDGE_HOST:$BRIDGE_PORT"
echo
echo 'Next:'
echo '1. Connect the private control repo to ChatGPT GitHub.'
echo '2. Trigger the Machine Admin workflow once.'
echo '3. Confirm the acceptance-test command exits 0.'
