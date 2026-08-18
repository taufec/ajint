#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f scripts/install-gh-standalone.py ] || fail 'standalone gh fallback missing'
python3 -m py_compile scripts/install-gh-standalone.py || fail 'standalone gh fallback syntax'
grep -Fq 'install_gh_standalone()' install.sh || fail 'install_gh_standalone function missing'
grep -Fq 'GH_STANDALONE_FALLBACK=1' install.sh || fail 'fallback evidence marker missing'
grep -Fq 'SSH_MODE_UNSUPPORTED' install.sh || fail 'unsupported SSH mode marker missing'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tree/gh_9.9.9_linux_amd64/bin" "$TMP/bin"
cat > "$TMP/tree/gh_9.9.9_linux_amd64/bin/gh" <<'GH'
#!/bin/sh
echo 'gh version 9.9.9 fake'
GH
chmod +x "$TMP/tree/gh_9.9.9_linux_amd64/bin/gh"
python3 - "$TMP" <<'PY'
import hashlib, json, pathlib, tarfile, sys
p = pathlib.Path(sys.argv[1])
archive = p / 'gh_9.9.9_linux_amd64.tar.gz'
with tarfile.open(archive, 'w:gz') as tf:
    tf.add(p / 'tree/gh_9.9.9_linux_amd64', arcname='gh_9.9.9_linux_amd64')
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
release = {
    'tag_name': 'v9.9.9',
    'assets': [{
        'name': archive.name,
        'browser_download_url': archive.as_uri(),
        'digest': 'sha256:' + digest,
    }],
}
(p / 'release.json').write_text(json.dumps(release))
PY
AJINT_GH_RELEASE_API="file://$TMP/release.json" AJINT_GH_INSTALL_DIR="$TMP/bin" python3 scripts/install-gh-standalone.py >/dev/null
[ -x "$TMP/bin/gh" ] || fail 'standalone gh binary not installed'
"$TMP/bin/gh" --version | grep -Fq '9.9.9 fake' || fail 'installed standalone gh does not execute'

echo 'PASS: Vellum compatibility contract'

# SSH support must be rejected before asking for GitHub authentication.
preflight_call="$(grep -n '^preflight_ssh_mode$' install.sh | head -n1 | cut -d: -f1)"
auth_check="$(grep -n '^if ! gh auth status' install.sh | head -n1 | cut -d: -f1)"
[ -n "$preflight_call" ] || fail 'SSH preflight call missing'
[ -n "$auth_check" ] || fail 'GitHub auth check missing'
[ "$preflight_call" -lt "$auth_check" ] || fail 'GitHub auth is checked before SSH-mode support'
