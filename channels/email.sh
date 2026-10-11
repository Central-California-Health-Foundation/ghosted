#!/usr/bin/env bash
# ghosted channel: email via msmtp. Config: EMAIL_TO (comma-separated ok),
# MSMTP_ACCOUNT (default: "default"). Needs msmtp configured in ~/.msmtprc.
set -euo pipefail
# shellcheck disable=SC2034  # uniform channel arg contract; `last` unused here
stage="$1" age="$2" last="$3" alert="$4"
: "${EMAIL_TO:?EMAIL_TO not set — run: ghosted setup}"
command -v msmtp >/dev/null 2>&1 || {
  echo "email channel: msmtp not installed (apt install msmtp)" >&2
  exit 1
}
draft="${GHOSTED_DIR:-$HOME/.ghosted}/CONTACT-DRAFT.md"
# shellcheck disable=SC2086  # split comma-separated recipients on purpose
{
  printf 'To: %s\n' "$EMAIL_TO"
  printf 'Subject: [ghosted] dead man switch — stage %s, %s days silent\n' "$stage" "$age"
  printf 'Content-Type: text/plain; charset=utf-8\n\n'
  cat "$alert"
  if [ -f "$draft" ]; then
    printf '\n--- emergency note draft (finalize with a human before acting) ---\n'
    cat "$draft"
  fi
} | msmtp -a "${MSMTP_ACCOUNT:-default}" -- ${EMAIL_TO//,/ }
