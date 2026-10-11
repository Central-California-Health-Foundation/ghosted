#!/usr/bin/env bash
# ghosted channel: hand the alert to another agent. Config: AGENT_CMD — any
# shell command that reads a witness prompt from stdin. Examples:
#   AGENT_CMD="claude -p"                           # a local agent CLI
#   AGENT_CMD="ssh witness@otherbox agent --stdin"  # an agent on another box
#   AGENT_CMD="cat >> ~/ghosted-witness.log"        # test it
# The receiving agent is a WITNESS: it composes the contact message and never
# sends or resets anything (see docs/agent-witness.md).
set -euo pipefail
stage="$1" age="$2" last="$3" alert="$4"
: "${AGENT_CMD:?AGENT_CMD not set — run: ghosted setup}"
draft="${GHOSTED_DIR:-$HOME/.ghosted}/CONTACT-DRAFT.md"
{
  cat <<EOF
You are the designated witness for someone's dead man's switch ('ghosted').
It fired: stage $stage, ${age} days of silence, last activity $last.

Your job — compose only, never act:
- Draft (or finalize, using the emergency note below) the message their
  emergency contact should receive.
- Do NOT send anything anywhere. Do NOT touch or reset any switch state.
- Present the draft for human review.

Alert:
EOF
  cat "$alert"
  if [ -f "$draft" ]; then
    printf '\nEmergency note draft:\n'
    cat "$draft"
  fi
} | bash -c "$AGENT_CMD"
