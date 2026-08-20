#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f VERSION ] || fail 'VERSION missing'
version="$(tr -d '\r\n' < VERSION)"
[ "$version" = '0.1.0-alpha.1' ] || fail "unexpected VERSION: $version"

grep -Fq 'Developer Preview' README.md || fail 'README maturity label missing'
grep -Fq 'docs/CHATGPT-QUICKSTART.md' README.md || fail 'README ChatGPT quick-start link missing'
grep -Fq 'DISCLAIMER.md' README.md || fail 'README disclaimer link missing'
grep -Fq 'SECURITY.md' README.md || fail 'README security link missing'

for f in \
  CHANGELOG.md \
  DISCLAIMER.md \
  SECURITY.md \
  CONTRIBUTING.md \
  docs/CHATGPT-QUICKSTART.md \
  docs/SECURITY-MODEL.md \
  docs/TROUBLESHOOTING.md \
  docs/UPGRADE.md \
  docs/UNINSTALL.md \
  docs/RELEASES.md \
  docs/COMPATIBILITY.md \
  docs/NETWORK-AND-PRIVACY.md \
  docs/MAINTAINER-SETUP.md; do
  [ -s "$f" ] || fail "required public-alpha file missing/empty: $f"
done

grep -Fq 'not a shell sandbox' docs/SECURITY-MODEL.md || fail 'security-model sandbox boundary missing'
grep -Fq 'write to the private Ajint control repository' docs/CHATGPT-QUICKSTART.md || fail 'ChatGPT write-capability preflight missing'
grep -Fq 'AJINT_ACCEPTANCE=PASS' docs/CHATGPT-QUICKSTART.md || fail 'acceptance verification missing'
grep -Fq 'AJINT_REF=v0.1.0-alpha.1' README.md || fail 'README immutable release ref missing'
grep -Fq 'AJINT_REF=v0.1.0-alpha.1' docs/CHATGPT-QUICKSTART.md || fail 'quick-start immutable release ref missing'

echo 'PASS: public alpha contract'
