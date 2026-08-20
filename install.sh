#!/usr/bin/env bash
set -euo pipefail

UPSTREAM="taufec/ajint"
AJINT_REF="${AJINT_REF:-main}"
BRIDGE_PORT="${BRIDGE_PORT:-22}"
BRIDGE_REPO="${BRIDGE_REPO:-ajint-machine-admin}"
BRIDGE_USER="${BRIDGE_USER:-$(id -un)}"

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit "${2:-20}"; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die 'missing dependencies require root or sudo' 20
  fi
}

install_missing_dependencies() {
  local missing=0 c
  for c in gh git ssh ssh-keygen curl awk base64; do
    command -v "$c" >/dev/null 2>&1 || missing=1
  done
  [ "$missing" -eq 1 ] || return 0

  log 'Ajint: installing missing runtime dependencies...'
  if command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update -qq
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      ca-certificates curl git gh openssh-client coreutils gawk >/dev/null
  elif command -v apk >/dev/null 2>&1; then
    as_root apk add --no-cache ca-certificates curl git github-cli openssh-client coreutils gawk >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    as_root dnf install -y ca-certificates curl git gh openssh-clients coreutils gawk >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    as_root yum install -y ca-certificates curl git gh openssh-clients coreutils gawk >/dev/null
  else
    die 'cannot auto-install dependencies: supported package manager not found (apt-get/apk/dnf/yum)' 20
  fi
}

install_gh_standalone() {
  command -v gh >/dev/null 2>&1 && return 0
  command -v python3 >/dev/null 2>&1 || return 1

  local gh_dir helper
  if [ "$(id -u)" -eq 0 ] || [ -w /usr/local/bin ]; then
    gh_dir='/usr/local/bin'
  else
    gh_dir="$HOME/.local/bin"
    mkdir -p "$gh_dir"
  fi

  helper="$(mktemp)"
  if ! python3 - "$helper" "$UPSTREAM" "$AJINT_REF" <<'PYHELPER'
import pathlib, sys, urllib.request
path = pathlib.Path(sys.argv[1])
url = f"https://raw.githubusercontent.com/{sys.argv[2]}/{sys.argv[3]}/scripts/install-gh-standalone.py"
req = urllib.request.Request(url, headers={"User-Agent": "Ajint/gh-bootstrap"})
with urllib.request.urlopen(req, timeout=30) as r:
    path.write_bytes(r.read())
PYHELPER
  then
    rm -f "$helper"
    return 1
  fi

  if ! AJINT_GH_INSTALL_DIR="$gh_dir" python3 "$helper"; then
    rm -f "$helper"
    return 1
  fi
  rm -f "$helper"
  export PATH="$gh_dir:$PATH"
  command -v gh >/dev/null 2>&1 || return 1
  log 'GH_STANDALONE_FALLBACK=1'
}

preflight_ssh_mode() {
  local pub
  for pub in /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_rsa_key.pub; do
    [ -r "$pub" ] && return 0
  done
  ssh-keyscan -T 8 -p "$BRIDGE_PORT" "$BRIDGE_HOST" >/dev/null 2>&1 && return 0
  die 'SSH_MODE_UNSUPPORTED: no readable SSH host key and target host/port did not answer ssh-keyscan' 24
}

install_missing_dependencies
if ! command -v gh >/dev/null 2>&1; then
  log 'Ajint: package manager did not provide gh; trying official standalone GitHub CLI...'
  install_gh_standalone || true
fi
for c in gh git ssh ssh-keygen curl awk base64 mktemp; do
  command -v "$c" >/dev/null 2>&1 || die "required command still missing after bootstrap: $c" 20
done

if [ -z "${BRIDGE_HOST:-}" ]; then
  BRIDGE_HOST="$(curl -4 -fsSL --max-time 8 https://api.ipify.org 2>/dev/null || true)"
fi
[ -n "${BRIDGE_HOST:-}" ] || die 'public host could not be detected; re-run with BRIDGE_HOST=<public-ip-or-dns>' 22
preflight_ssh_mode

if [ -n "${AJINT_GITHUB_TOKEN:-}" ] && [ -z "${GH_TOKEN:-}" ]; then
  export GH_TOKEN="$AJINT_GITHUB_TOKEN"
fi

if ! gh auth status >/dev/null 2>&1; then
  cat >&2 <<'MSG'
ERROR: GitHub authentication is required.
Authenticate once with:
  gh auth login
Or provide GH_TOKEN/AJINT_GITHUB_TOKEN through a secure environment variable.
Then run Ajint again.
MSG
  exit 21
fi

GH_OWNER="$(gh api user --jq .login)"
CONTROL_REPO="$GH_OWNER/$BRIDGE_REPO"

if [ "$BRIDGE_USER" != "$(id -un)" ]; then
  die "MVP installs SSH authorization for the current OS user only (current=$(id -un), requested=$BRIDGE_USER)" 23
fi

SSH_DIR="$HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
KEY_DIR="$(mktemp -d)"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$KEY_DIR" "$WORK"; }
trap cleanup EXIT
KEY="$KEY_DIR/ajint_ed25519"
KEY_MARKER="ajint:$CONTROL_REPO"

ssh-keygen -q -t ed25519 -N '' -C "$KEY_MARKER" -f "$KEY"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
AUTH_TMP="$(mktemp)"
awk -v marker="$KEY_MARKER" 'NF == 0 || $NF != marker' "$AUTH_KEYS" > "$AUTH_TMP"
cat "$KEY.pub" >> "$AUTH_TMP"
cat "$AUTH_TMP" > "$AUTH_KEYS"
rm -f "$AUTH_TMP"

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
  KNOWN_HOSTS="$(ssh-keyscan -T 8 -p "$BRIDGE_PORT" "$BRIDGE_HOST" 2>/dev/null || true)"
fi
[ -n "$KNOWN_HOSTS" ] || die 'SSH_MODE_UNSUPPORTED: no readable SSH host key and target host/port did not answer ssh-keyscan' 24

REPO_EXISTS=0
if gh repo view "$CONTROL_REPO" >/dev/null 2>&1; then
  REPO_EXISTS=1
else
  gh repo create "$CONTROL_REPO" --private --description 'Private Ajint machine control plane' >/dev/null
fi

# Configure credentials before any push can trigger remote execution.
gh secret set ADMIN_VPS_HOST --repo "$CONTROL_REPO" --body "$BRIDGE_HOST"
gh secret set ADMIN_VPS_PORT --repo "$CONTROL_REPO" --body "$BRIDGE_PORT"
gh secret set ADMIN_VPS_USER --repo "$CONTROL_REPO" --body "$BRIDGE_USER"
gh secret set ADMIN_VPS_SSH_KEY --repo "$CONTROL_REPO" < "$KEY"
gh secret set ADMIN_VPS_KNOWN_HOSTS --repo "$CONTROL_REPO" --body "$KNOWN_HOSTS"

if [ "$REPO_EXISTS" -eq 1 ]; then
  gh repo clone "$CONTROL_REPO" "$WORK/repo" -- --quiet
  git -C "$WORK/repo" checkout main >/dev/null 2>&1 || git -C "$WORK/repo" checkout -b main
else
  mkdir -p "$WORK/repo"
  git -C "$WORK/repo" init -q -b main
  git -C "$WORK/repo" remote add origin "https://github.com/$CONTROL_REPO.git"
fi

mkdir -p "$WORK/repo/.github/workflows" "$WORK/repo/scripts" "$WORK/repo/policy" "$WORK/repo/requests" "$WORK/repo/requests/batches"
for pair in \
  'template/.github/workflows/admin.yml:.github/workflows/admin.yml' \
  'template/.github/workflows/parallel.yml:.github/workflows/parallel.yml' \
  'template/scripts/run-admin.sh:scripts/run-admin.sh' \
  'template/scripts/run-request.sh:scripts/run-request.sh' \
  'template/scripts/run-wave.sh:scripts/run-wave.sh' \
  'template/scripts/run-orchestrator.sh:scripts/run-orchestrator.sh' \
  'template/scripts/run-dispatch.sh:scripts/run-dispatch.sh' \
  'template/scripts/policy_gate.py:scripts/policy_gate.py' \
  'template/scripts/evidence_validator.py:scripts/evidence_validator.py' \
  'template/requests/current.sh:requests/current.sh' \
  'template/requests/task.json:requests/task.json'; do
  src="${pair%%:*}"
  dest="${pair#*:}"
  gh api "repos/$UPSTREAM/contents/$src?ref=$AJINT_REF" --jq .content | tr -d '\n' | base64 -d > "$WORK/repo/$dest"
done

# Seed machine-specific policy only when absent; never clobber custom routes or known-good history.
for pair in \
  'template/policy/routes.json:policy/routes.json' \
  'template/policy/known-good.json:policy/known-good.json'; do
  src="${pair%%:*}"
  dest="${pair#*:}"
  if [ ! -f "$WORK/repo/$dest" ]; then
    gh api "repos/$UPSTREAM/contents/$src?ref=$AJINT_REF" --jq .content | tr -d '\n' | base64 -d > "$WORK/repo/$dest"
  fi
done

# The installer acceptance workflow must carry a manifest whose hash matches current.sh.
CURRENT_REQUEST_SHA="$(sha256sum "$WORK/repo/requests/current.sh" | awk '{print $1}')"
cat > "$WORK/repo/requests/task.json" <<EOF
{
  "capability": "linux.generic",
  "mode": "execute",
  "intent": "Ajint installer acceptance test",
  "request_sha256": "$CURRENT_REQUEST_SHA"
}
EOF

chmod +x "$WORK/repo/scripts/run-admin.sh" "$WORK/repo/scripts/run-request.sh" "$WORK/repo/scripts/run-wave.sh" "$WORK/repo/scripts/run-orchestrator.sh" "$WORK/repo/scripts/run-dispatch.sh" "$WORK/repo/scripts/policy_gate.py" "$WORK/repo/scripts/evidence_validator.py" "$WORK/repo/requests/current.sh"

cat > "$WORK/repo/README.md" <<DOC
# $BRIDGE_REPO

Private machine control plane managed by Ajint.

Target: \`$BRIDGE_USER@$BRIDGE_HOST:$BRIDGE_PORT\`

Flow: AI/Agent -> GitHub -> GitHub Actions -> Ajint -> machine

Ajint-managed files:
- \`.github/workflows/admin.yml\`
- \`.github/workflows/parallel.yml\`
- \`scripts/run-admin.sh\`
- \`scripts/run-request.sh\`
- \`scripts/run-wave.sh\`
- \`scripts/run-orchestrator.sh\`
- \`scripts/run-dispatch.sh\`
- \`scripts/policy_gate.py\`
- \`scripts/evidence_validator.py\`
- \`requests/current.sh\`
- \`requests/task.json\`
- \`policy/routes.json\` (seeded only if absent)
- \`policy/known-good.json\` (seeded only if absent)

Single request: update \`requests/task.json\` with the intended capability/mode and the SHA-256 of the request, then edit the matching request lane. The policy gate rejects route or hash mismatches before SSH execution.

Parallel batch: create \`requests/batches/<batch-id>/<wave>/*.sh\`, then create or change \`requests/dispatch.txt\` to that batch id as the final trigger. Requests inside one wave run concurrently; waves run in lexical order and stop on failure.

Check workflow artifacts for stdout, stderr, exit codes, request hashes, and the aggregated summary.
DOC

# Preserve existing repo/history; only commit managed-file changes.
git -C "$WORK/repo" add .github/workflows/admin.yml .github/workflows/parallel.yml scripts/run-admin.sh scripts/run-request.sh scripts/run-wave.sh scripts/run-orchestrator.sh scripts/run-dispatch.sh scripts/policy_gate.py scripts/evidence_validator.py policy/routes.json policy/known-good.json requests/current.sh requests/task.json README.md
if ! git -C "$WORK/repo" diff --cached --quiet; then
  GIT_AUTHOR_NAME='Ajint' \
  GIT_AUTHOR_EMAIL='ajint@localhost' \
  GIT_COMMITTER_NAME='Ajint' \
  GIT_COMMITTER_EMAIL='ajint@localhost' \
    git -C "$WORK/repo" commit -m 'Update Ajint control plane' >/dev/null
  gh auth setup-git >/dev/null 2>&1 || true
  git -C "$WORK/repo" push -u origin main >/dev/null
fi

# Always run a fresh acceptance test, including on reinstall.
BEFORE_RUN="$(gh run list -R "$CONTROL_REPO" --limit 20 --json databaseId,event --jq '[.[] | select(.event=="workflow_dispatch")][0].databaseId // empty' 2>/dev/null || true)"
DISPATCHED=0
for _ in $(seq 1 20); do
  if gh workflow run 'Machine Admin' -R "$CONTROL_REPO" >/dev/null 2>&1; then
    DISPATCHED=1
    break
  fi
  sleep 2
done
[ "$DISPATCHED" -eq 1 ] || die 'could not dispatch Machine Admin acceptance workflow' 25

RUN_ID=''
for _ in $(seq 1 40); do
  CANDIDATE="$(gh run list -R "$CONTROL_REPO" --limit 20 --json databaseId,event --jq '[.[] | select(.event=="workflow_dispatch")][0].databaseId // empty' 2>/dev/null || true)"
  if [ -n "$CANDIDATE" ] && [ "$CANDIDATE" != "$BEFORE_RUN" ]; then
    RUN_ID="$CANDIDATE"
    break
  fi
  sleep 2
done
[ -n "$RUN_ID" ] || die 'acceptance workflow run did not appear' 26

for _ in $(seq 1 120); do
  STATUS="$(gh run view "$RUN_ID" -R "$CONTROL_REPO" --json status --jq .status 2>/dev/null || true)"
  [ "$STATUS" = 'completed' ] && break
  sleep 2
done

CONCLUSION="$(gh run view "$RUN_ID" -R "$CONTROL_REPO" --json conclusion --jq .conclusion 2>/dev/null || true)"
RUN_URL="$(gh run view "$RUN_ID" -R "$CONTROL_REPO" --json url --jq .url 2>/dev/null || true)"
if [ "$CONCLUSION" != 'success' ]; then
  printf 'ERROR: acceptance workflow failed: %s\n' "$RUN_URL" >&2
  gh run view "$RUN_ID" -R "$CONTROL_REPO" --log-failed 2>&1 | tail -n 80 >&2 || true
  exit 27
fi

ACCEPT_DIR="$WORK/acceptance"
mkdir -p "$ACCEPT_DIR"
gh run download "$RUN_ID" -R "$CONTROL_REPO" -D "$ACCEPT_DIR" >/dev/null 2>&1 || die 'acceptance artifact could not be downloaded' 28
EXIT_FILE="$(find "$ACCEPT_DIR" -name exit-code.txt -type f | head -n1 || true)"
STDOUT_FILE="$(find "$ACCEPT_DIR" -name stdout.txt -type f | head -n1 || true)"
[ -n "$EXIT_FILE" ] && [ -n "$STDOUT_FILE" ] || die 'acceptance artifact is incomplete' 29
REMOTE_RC="$(tr -d '\r\n ' < "$EXIT_FILE")"
[ "$REMOTE_RC" = '0' ] || die "remote acceptance command exited $REMOTE_RC" 30
grep -Fq 'ajint acceptance test' "$STDOUT_FILE" || die 'acceptance output marker missing' 31

log
log 'Ajint connected and verified.'
log "Control repo: https://github.com/$CONTROL_REPO"
log "Target: $BRIDGE_USER@$BRIDGE_HOST:$BRIDGE_PORT"
log "Acceptance: $RUN_URL"
log 'AJINT_ACCEPTANCE=PASS'
