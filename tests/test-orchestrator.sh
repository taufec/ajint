#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ROOT/template/scripts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/fakebin" "$TMP/home" "$TMP/shared"
cat > "$TMP/fakebin/ssh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
bash -se
FAKE
chmod +x "$TMP/fakebin/ssh"
export PATH="$TMP/fakebin:$PATH"
export HOME="$TMP/home"
export AJINT_TEST_SHARED="$TMP/shared"
export ADMIN_VPS_HOST=fake-host
export ADMIN_VPS_PORT=22
export ADMIN_VPS_USER=fake-user
export ADMIN_VPS_SSH_KEY='fake-private-key'
export ADMIN_VPS_KNOWN_HOSTS='fake-host ssh-ed25519 AAAAFAKE'
export AJINT_MAX_PARALLEL=4

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { [ -f "$1" ] || fail "missing file $1"; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }

# Test 1: one request preserves evidence and remote exit code.
mkdir -p "$TMP/t1"
cat > "$TMP/t1/request.sh" <<'REQ'
printf 'hello\n'
printf 'oops\n' >&2
exit 7
REQ
set +e
bash "$SCRIPTS/run-request.sh" "$TMP/t1/request.sh" "$TMP/t1/result"
rc=$?
set -e
assert_eq "$rc" 7
assert_eq "$(cat "$TMP/t1/result/stdout.txt")" hello
assert_eq "$(cat "$TMP/t1/result/stderr.txt")" oops
assert_eq "$(cat "$TMP/t1/result/exit-code.txt")" 7
assert_eq "$(cat "$TMP/t1/result/request-name.txt")" request.sh
assert_file "$TMP/t1/result/request-sha256.txt"

# Test 2: requests in one wave really overlap. A would fail if B started only after A finished.
mkdir -p "$TMP/t2/wave" "$TMP/t2/result"
cat > "$TMP/t2/wave/a.sh" <<'REQ'
touch "$AJINT_TEST_SHARED/a-started"
for _ in $(seq 1 60); do
  [ -f "$AJINT_TEST_SHARED/b-started" ] && exit 0
  sleep 0.05
done
exit 19
REQ
cat > "$TMP/t2/wave/b.sh" <<'REQ'
touch "$AJINT_TEST_SHARED/b-started"
exit 0
REQ
bash "$SCRIPTS/run-wave.sh" "$TMP/t2/wave" "$TMP/t2/result"
grep -q $'^a\t0\t' "$TMP/t2/result/summary.tsv" || fail 'worker a not successful'
grep -q $'^b\t0\t' "$TMP/t2/result/summary.tsv" || fail 'worker b not successful'

# Test 3: wave waits for all workers, captures failures, then returns failure.
mkdir -p "$TMP/t3/wave" "$TMP/t3/result"
printf '%s\n' 'printf "ok\\n"' > "$TMP/t3/wave/ok.sh"
printf '%s\n' 'printf "bad\\n" >&2; exit 23' > "$TMP/t3/wave/bad.sh"
set +e
bash "$SCRIPTS/run-wave.sh" "$TMP/t3/wave" "$TMP/t3/result"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail 'failed wave returned success'
assert_eq "$(cat "$TMP/t3/result/bad/exit-code.txt")" 23
assert_eq "$(cat "$TMP/t3/result/ok/exit-code.txt")" 0

# Test 4: successful waves run in lexical order.
mkdir -p "$TMP/t4/batch/10-first" "$TMP/t4/batch/20-second" "$TMP/t4/result"
printf '%s\n' 'touch "$AJINT_TEST_SHARED/wave-one"' > "$TMP/t4/batch/10-first/a.sh"
printf '%s\n' 'test -f "$AJINT_TEST_SHARED/wave-one"' > "$TMP/t4/batch/20-second/b.sh"
bash "$SCRIPTS/run-orchestrator.sh" "$TMP/t4/batch" "$TMP/t4/result"
grep -q $'^10-first\ta\t0\t' "$TMP/t4/result/summary.tsv" || fail 'first wave missing from summary'
grep -q $'^20-second\tb\t0\t' "$TMP/t4/result/summary.tsv" || fail 'second wave missing from summary'

# Test 5: a failed wave blocks every later wave.
mkdir -p "$TMP/t5/batch/10-fail" "$TMP/t5/batch/20-must-not-run" "$TMP/t5/result"
printf '%s\n' 'exit 31' > "$TMP/t5/batch/10-fail/a.sh"
printf '%s\n' 'touch "$AJINT_TEST_SHARED/forbidden"' > "$TMP/t5/batch/20-must-not-run/b.sh"
set +e
bash "$SCRIPTS/run-orchestrator.sh" "$TMP/t5/batch" "$TMP/t5/result"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail 'orchestrator ignored failed wave'
[ ! -e "$AJINT_TEST_SHARED/forbidden" ] || fail 'later wave ran after failure'

# Test 6: dispatch validation rejects path traversal before execution.
mkdir -p "$TMP/t6"
printf '../escape\n' > "$TMP/t6/dispatch.txt"
set +e
(
  cd "$ROOT/template"
  bash scripts/run-dispatch.sh "$TMP/t6/dispatch.txt"
)
rc=$?
set -e
[ "$rc" -ne 0 ] || fail 'invalid dispatch id accepted'

printf 'PASS: orchestrator tests\n'
