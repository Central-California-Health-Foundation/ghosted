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
