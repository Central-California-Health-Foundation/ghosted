#!/usr/bin/env bash
# install.sh — install ghosted for the current user (no sudo needed).
#   PREFIX=/usr/local sudo -E ./install.sh   # system-wide instead
#   ./install.sh --uninstall
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
SRC="$(cd "$(dirname "$0")" && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"

if [ "${1:-}" = "--uninstall" ]; then
  systemctl --user disable --now ghosted-check.timer 2>/dev/null || true
  rm -f "$PREFIX/bin/ghosted" "$PREFIX/bin/alive" \
    "$UNIT_DIR/ghosted-check.service" "$UNIT_DIR/ghosted-check.timer"
  systemctl --user daemon-reload 2>/dev/null || true
  echo "ghosted: uninstalled. State left in ~/.ghosted — rm -rf it if you're sure."
  exit 0
fi

install -Dm755 "$SRC/bin/ghosted" "$PREFIX/bin/ghosted"
ln -sf ghosted "$PREFIX/bin/alive"

[ -f "$HOME/.config/ghosted/config" ] ||
  install -Dm644 "$SRC/config/config.example" "$HOME/.config/ghosted/config"
mkdir -p "$HOME/.ghosted"
[ -f "$HOME/.ghosted/note.md" ] ||
  install -m644 "$SRC/config/note.md" "$HOME/.ghosted/note.md"
[ -f "$HOME/.ghosted/contact.txt" ] ||
  echo 'REPLACE-WITH-emergency-contact@example.com' >"$HOME/.ghosted/contact.txt"
[ -f "$HOME/.ghosted/notify.sh.example" ] ||
  install -m644 "$SRC/examples/notify.sh.example" "$HOME/.ghosted/notify.sh.example"

if command -v systemctl >/dev/null 2>&1 &&
  systemctl --user show -p State >/dev/null 2>&1; then
  mkdir -p "$UNIT_DIR"
  for u in service timer; do
    sed "s|@PREFIX@|$PREFIX/bin|g" "$SRC/systemd/ghosted-check.$u" >"$UNIT_DIR/ghosted-check.$u"
  done
  systemctl --user daemon-reload
  systemctl --user enable --now ghosted-check.timer
  systemctl --user list-timers ghosted-check.timer || true
else
  echo "ghosted: no systemd user session detected — add this cron line instead:"
  echo "  30 9 * * * $PREFIX/bin/ghosted check"
fi

echo ""
echo "ghosted installed. Next steps:"
echo "  1. edit ~/.config/ghosted/config   (point HEARTBEAT_PATHS at your agent's dirs)"
echo "  2. edit ~/.ghosted/note.md         (what your contact should know/do)"
echo "  3. ghosted status                  (see the current state)"
command -v alive >/dev/null 2>&1 || echo "  (put $PREFIX/bin on PATH for the 'alive' shortcut)"
