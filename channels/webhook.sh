#!/usr/bin/env bash
# ghosted channel: generic JSON webhook (Slack/Discord-friendly: the payload
# carries both `text` and `content` keys). Config: WEBHOOK_URL.
set -euo pipefail
stage="$1" age="$2" last="$3" alert="$4"
: "${WEBHOOK_URL:?WEBHOOK_URL not set — run: ghosted setup}"
text=$(sed 's/\\/\\\\/g; s/"/\\"/g' "$alert" | awk '{printf "%s\\n", $0}')
curl -fsS --max-time 15 -o /dev/null \
  -H 'Content-Type: application/json' \
  -d "{\"source\":\"ghosted\",\"stage\":\"$stage\",\"silent_days\":$age,\"last_activity\":\"$last\",\"text\":\"$text\",\"content\":\"$text\"}" \
  "$WEBHOOK_URL"
