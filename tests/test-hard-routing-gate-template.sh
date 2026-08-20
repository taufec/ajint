#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $*" >&2; exit 1; }

required=(
  template/scripts/policy_gate.py
  template/scripts/evidence_validator.py
  template/policy/routes.json
  template/policy/known-good.json
  template/requests/task.json
)
for f in "${required[@]}"; do
  [ -f "$f" ] || fail "missing $f"
done

grep -Fq "python3 scripts/policy_gate.py" template/.github/workflows/admin.yml || fail "admin workflow missing policy gate"
grep -Fq "python3 scripts/evidence_validator.py" template/.github/workflows/admin.yml || fail "admin workflow missing evidence validator"
grep -Fq "python3 scripts/policy_gate.py" template/.github/workflows/parallel.yml || fail "parallel workflow missing policy gate"
grep -Fq "python3 scripts/evidence_validator.py" template/.github/workflows/parallel.yml || fail "parallel workflow missing evidence validator"

grep -Fq "template/scripts/policy_gate.py:scripts/policy_gate.py" install.sh || fail "installer missing policy gate copy"
grep -Fq "template/scripts/evidence_validator.py:scripts/evidence_validator.py" install.sh || fail "installer missing evidence validator copy"
grep -Fq "template/requests/task.json:requests/task.json" install.sh || fail "installer missing task manifest copy"
grep -Fq "template/policy/routes.json:policy/routes.json" install.sh || fail "installer missing routes seed"
grep -Fq "template/policy/known-good.json:policy/known-good.json" install.sh || fail "installer missing known-good seed"
grep -Fq '[ ! -f "$WORK/repo/$dest" ]' install.sh || fail "installer must preserve existing machine policy"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf '#!/usr/bin/env bash\necho ok\n' > "$tmp/request.sh"
hash="$(sha256sum "$tmp/request.sh" | awk '{print $1}')"

cat > "$tmp/manifest.json" <<EOF
{"capability":"linux.generic","mode":"execute","intent":"test","request_sha256":"$hash"}
EOF
python3 template/scripts/policy_gate.py \
  --manifest "$tmp/manifest.json" \
  --lane admin \
  --request "$tmp/request.sh" \
  --routes template/policy/routes.json \
  --known-good template/policy/known-good.json \
  | grep -Fq 'POLICY_GATE=PASS' || fail "valid generic route did not pass"

set +e
route_out="$(python3 template/scripts/policy_gate.py \
  --manifest "$tmp/manifest.json" \
  --lane parallel \
  --request "$tmp/request.sh" \
  --routes template/policy/routes.json \
  --known-good template/policy/known-good.json 2>&1)"
route_rc=$?
set -e
[ "$route_rc" -ne 0 ] || fail "route mismatch unexpectedly passed"
grep -Fq 'ROUTE_MISMATCH' <<<"$route_out" || fail "route mismatch reason missing"

printf 'SPECIAL_ONLY\n' > "$tmp/request.sh"
hash="$(sha256sum "$tmp/request.sh" | awk '{print $1}')"
cat > "$tmp/manifest.json" <<EOF
{"capability":"linux.generic","mode":"execute","intent":"test","request_sha256":"$hash"}
EOF
cat > "$tmp/routes.json" <<'EOF'
{
  "routes": {
    "linux.generic": {"lane":"admin","workflow":"admin.yml","request":"requests/current.sh","priority":10,"specific_markers":[]},
    "app.special": {"lane":"special","workflow":"special.yml","request":"requests/special.sh","priority":100,"specific_markers":["SPECIAL_ONLY"]}
  },
  "protected_during_diagnosis":[".github/workflows/","scripts/policy_gate.py","scripts/evidence_validator.py","policy/"]
}
EOF
set +e
specific_out="$(python3 template/scripts/policy_gate.py \
  --manifest "$tmp/manifest.json" \
  --lane admin \
  --request "$tmp/request.sh" \
  --routes "$tmp/routes.json" \
  --known-good template/policy/known-good.json 2>&1)"
specific_rc=$?
set -e
[ "$specific_rc" -ne 0 ] || fail "specific-route marker unexpectedly passed generic route"
grep -Fq 'SPECIFIC_ROUTE_MARKER' <<<"$specific_out" || fail "specific route reason missing"

printf '#!/usr/bin/env bash\necho ok\n' > "$tmp/request.sh"
hash="$(sha256sum "$tmp/request.sh" | awk '{print $1}')"
cat > "$tmp/manifest.json" <<EOF
{"capability":"linux.generic","mode":"diagnose","intent":"test","request_sha256":"$hash"}
EOF
printf '.github/workflows/admin.yml\n' > "$tmp/changed.txt"
set +e
diag_out="$(python3 template/scripts/policy_gate.py \
  --manifest "$tmp/manifest.json" \
  --lane admin \
  --request "$tmp/request.sh" \
  --routes template/policy/routes.json \
  --known-good template/policy/known-good.json \
  --changed-files "$tmp/changed.txt" 2>&1)"
diag_rc=$?
set -e
[ "$diag_rc" -ne 0 ] || fail "diagnosis architecture mutation unexpectedly passed"
grep -Fq 'ARCHITECTURE_MUTATION_DURING_DIAGNOSIS' <<<"$diag_out" || fail "diagnosis deny reason missing"

cat > "$tmp/evidence.json" <<'EOF'
{"request_commit":"abc","route":"admin","workflow":"admin.yml","exit_code":"0","result_present":true}
EOF
python3 template/scripts/evidence_validator.py "$tmp/evidence.json" | grep -Fq 'VERDICT=UNCONFIRMED' || fail "incomplete evidence should be unconfirmed"

cat > "$tmp/evidence.json" <<'EOF'
{"request_commit":"abc","route":"admin","workflow":"admin.yml","run_id":"123","exit_code":"0","result_present":true}
EOF
python3 template/scripts/evidence_validator.py "$tmp/evidence.json" | grep -Fxq 'VERDICT=PASS' || fail "complete successful evidence should pass"

cat > "$tmp/evidence.json" <<'EOF'
{"request_commit":"abc","route":"admin","workflow":"admin.yml","run_id":"123","exit_code":"7","result_present":true}
EOF
python3 template/scripts/evidence_validator.py "$tmp/evidence.json" | grep -Fxq 'VERDICT=FAIL' || fail "complete failed evidence should fail"

echo "HARD_ROUTING_GATE_TEMPLATE_TEST=PASS"
