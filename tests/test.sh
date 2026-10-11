#!/usr/bin/env bash
# Integration tests for ghosted. No systemd required: drives the full ladder
# with fake mtimes and env-var config. Exits non-zero on any failure.
set -euo pipefail
cd "$(dirname "$0")/.."

export GHOSTED_CONFIG=/dev/null
export GHOSTED_DIR="$PWD/.test/state" HEARTBEAT_PATHS="$PWD/.test/hb"
export GRACE_AFTER=30 CONTACT_AFTER=37
rm -rf .test && mkdir -p "$GHOSTED_DIR" "$HEARTBEAT_PATHS/ws/session-abc"

pass=0 fail=0
assert() { # $1 got  $2 want  $3 label
  if [ "$1" = "$2" ]; then
    echo "ok   $3"; pass=$((pass + 1))
  else
    echo "FAIL $3 (got '$1', want '$2')"; fail=$((fail + 1))
  fi
}
stage() { cat "$GHOSTED_DIR/stage" 2>/dev/null || echo 0; }
age_hb() { touch -d "$1" "$HEARTBEAT_PATHS" "$HEARTBEAT_PATHS/ws" "$HEARTBEAT_PATHS/ws/session-abc"; }
G() { ./bin/ghosted "$@"; }

echo "== fresh install, activity now"
G check
assert "$(stage)" 0 "fresh install stays at stage 0"
assert "$([ -f "$GHOSTED_DIR/ALERT" ] && echo y || echo n)" n "no ALERT when healthy"

echo "== 10 days silent"
age_hb "10 days ago"
G check
assert "$(stage)" 0 "10d silent stays at stage 0"

echo "== 31 days silent -> stage 1"
age_hb "31 days ago"
G check
assert "$(stage)" 1 "31d silent trips stage 1"
assert "$([ -f "$GHOSTED_DIR/ALERT" ] && echo y || echo n)" y "stage 1 writes ALERT"

echo "== idempotent re-run"
G check
assert "$(grep -c STAGE1 "$GHOSTED_DIR/alert.log")" 1 "stage 1 fires exactly once"

echo "== 38 days silent -> stage 2 + contact draft"
cp config/note.md "$GHOSTED_DIR/note.md"
age_hb "38 days ago"
G check
assert "$(stage)" 2 "38d silent trips stage 2"
assert "$([ -f "$GHOSTED_DIR/CONTACT-DRAFT.md" ] && echo y || echo n)" y "stage 2 copies note to CONTACT-DRAFT.md"

echo "== recovery: user comes back"
age_hb now
G check
assert "$(stage)" 0 "activity resumes -> auto-recover to stage 0"
assert "$([ -f "$GHOSTED_DIR/ALERT" ] && echo y || echo n)" n "ALERT cleared on recovery"

echo "== ack wins over stale heartbeats (pre-vacation)"
G ack
age_hb "45 days ago"
G check
assert "$(stage)" 0 "explicit ack outranks stale heartbeat dirs"

echo "== delivery channels fire on stage transitions"
mkdir -p "$GHOSTED_DIR/channels"
cat >"$GHOSTED_DIR/channels/recorder.sh" <<'CH'
#!/usr/bin/env bash
echo "stage=$1 age=$2" >>"$TEST_LOG"
CH
chmod +x "$GHOSTED_DIR/channels/recorder.sh"
export CHANNELS=recorder TEST_LOG="$PWD/.test/chan.log"
rm -f "$GHOSTED_DIR/heartbeat" # the ack above left a fresh heartbeat; drop it
age_hb "31 days ago"
G check
assert "$(head -n1 "$TEST_LOG")" "stage=1 age=31" "channel fires at stage 1 with stage+age"
age_hb now
G check
age_hb "38 days ago"
G check
assert "$(tail -n1 "$TEST_LOG")" "stage=2 age=38" "channel fires at stage 2"
assert "$(grep -c 'NOTIFY channel=recorder ok' "$GHOSTED_DIR/alert.log")" 2 "both deliveries logged"

echo "== missing channel script warns but check succeeds"
export CHANNELS=ghostchannel
echo 0 >"$GHOSTED_DIR/stage" # reset stage without touching heartbeat
age_hb "31 days ago"
G check
assert "$(stage)" 1 "check still advances stage with broken channel config"
assert "$(grep -c 'WARN channel=ghostchannel' "$GHOSTED_DIR/alert.log")" 1 "missing channel script logged as WARN"

echo "== agent channel hands witness prompt to AGENT_CMD"
export CHANNELS=agent AGENT_CMD="cat > $PWD/.test/agent_in.txt"
age_hb now
G check
age_hb "38 days ago"
G check
assert "$(grep -c 'compose only' "$PWD/.test/agent_in.txt")" 1 "agent channel sends witness instructions"
assert "$(grep -c 'CONTACT STAGE' "$PWD/.test/agent_in.txt")" 1 "agent channel includes the alert"
unset CHANNELS AGENT_CMD TEST_LOG

echo "== legacy notify.sh hook still runs"
rm -rf "$GHOSTED_DIR"
mkdir -p "$GHOSTED_DIR"
cat >"$GHOSTED_DIR/notify.sh" <<'HK'
#!/usr/bin/env bash
echo "legacy stage=$1" >>"$TEST_LOG2"
HK
chmod +x "$GHOSTED_DIR/notify.sh"
export TEST_LOG2="$PWD/.test/legacy.log"
age_hb "31 days ago"
G check
assert "$(cat "$TEST_LOG2")" "legacy stage=1" "v0.1 notify.sh hook still fires"
unset TEST_LOG2

echo "== empty heartbeat sources -> INIT"
rm -rf "$GHOSTED_DIR" "$HEARTBEAT_PATHS"
mkdir -p "$HEARTBEAT_PATHS"
G check
assert "$([ -f "$GHOSTED_DIR/heartbeat" ] && echo y || echo n)" y "INIT creates baseline heartbeat"

echo "== status runs clean"
G status >/dev/null
assert 0 0 "status exits 0"

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
