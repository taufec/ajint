#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }

bash -n install.sh || fail 'install.sh syntax'
[ -f bootstrap.py ] || fail 'bootstrap.py missing'
python3 -m py_compile bootstrap.py || fail 'bootstrap.py syntax'

grep -Fq 'install_missing_dependencies()' install.sh || fail 'dependency bootstrap missing'
grep -Fq 'gh workflow run' install.sh || fail 'automatic acceptance dispatch missing'
grep -Fq 'AJINT_ACCEPTANCE=PASS' install.sh || fail 'acceptance PASS marker missing'
grep -Fq 'awk -v marker="$KEY_MARKER"' install.sh || fail 'SSH key idempotency missing'

if grep -Fq 'git -C "$WORK/repo" push -u origin main --force' install.sh; then
  fail 'force push remains'
fi

secret_line="$(grep -n 'gh secret set ADMIN_VPS_HOST' install.sh | head -n1 | cut -d: -f1)"
push_line="$(grep -n 'git -C "$WORK/repo" push' install.sh | head -n1 | cut -d: -f1)"
[ -n "$secret_line" ] && [ -n "$push_line" ] || fail 'secret/push markers missing'
[ "$secret_line" -lt "$push_line" ] || fail 'secrets must be configured before push can trigger workflow'

grep -Fq 'Minimal Linux (no curl required)' README.md || fail 'minimal Linux docs missing'
grep -Fq 'Debian 13' README.md || fail 'tested Debian docs missing'
grep -Fq 'Ubuntu 24.04' README.md || fail 'tested Ubuntu docs missing'

echo 'PASS: Linux bootstrap contract'
