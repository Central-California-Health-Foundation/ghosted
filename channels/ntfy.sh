#!/usr/bin/env bash
# ghosted channel: ntfy push. Config: NTFY_TOPIC (topic name or full URL).
# The topic name is the secret — pick long unguessable words.
set -euo pipefail
# shellcheck disable=SC2034  # uniform channel arg contract; `last` unused here
stage="$1" age="$2" last="$3" alert="$4"
: "${NTFY_TOPIC:?NTFY_TOPIC not set — run: ghosted setup}"
url="$NTFY_TOPIC"
case "$url" in https?*) ;; *) url="https://ntfy.sh/$NTFY_TOPIC" ;; esac
prio=default
case "$stage" in 2 | 3) prio=high ;; esac
msg=$(head -n 4 "$alert" | tr '\n' ' ')
curl -fsS --max-time 15 -o /dev/null \
  -H "Title: ghosted — stage $stage, ${age}d silent" \
  -H "Priority: $prio" \
  -d "$msg" "$url"
