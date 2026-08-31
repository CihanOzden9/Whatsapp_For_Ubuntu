#!/usr/bin/env bash
#
# WhatsApp for Linux - kurulumu geri al.
#
#   ./scripts/uninstall.sh            binary, komut, ikon ve menu kaydini siler
#   ./scripts/uninstall.sh --purge    oturum verisini de siler (tekrar QR okutursun)

set -euo pipefail

APP_ID="whatsapp-for-linux"
CMD_NAME="whatsapp"
IDENTIFIER="dev.cedric.whatsapp-for-linux"

BIN="$HOME/.local/bin/$CMD_NAME"
LIB_DIR="$HOME/.local/lib/$APP_ID"
ICON="$HOME/.local/share/icons/hicolor/128x128/apps/$APP_ID.png"
DESKTOP="$HOME/.local/share/applications/$APP_ID.desktop"
AUTOSTART="$HOME/.config/autostart/$APP_ID-autostart.desktop"
SERVICE="$HOME/.config/systemd/user/$APP_ID.service"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

if systemctl --user is-enabled "$APP_ID.service" >/dev/null 2>&1; then
  say "systemd servisi durduruluyor..."
  systemctl --user disable --now "$APP_ID.service" || true
fi

for f in "$BIN" "$ICON" "$DESKTOP" "$AUTOSTART" "$SERVICE"; do
  [[ -e "$f" ]] && { say "siliniyor: $f"; rm -f "$f"; }
done
[[ -d "$LIB_DIR" ]] && { say "siliniyor: $LIB_DIR"; rm -rf "$LIB_DIR"; }

systemctl --user daemon-reload 2>/dev/null || true
command -v update-desktop-database >/dev/null 2>&1 \
  && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

if [[ "${1:-}" == "--purge" ]]; then
  for d in "$HOME/.local/share/$IDENTIFIER" "$HOME/.cache/$IDENTIFIER"; do
    [[ -d "$d" ]] && { say "oturum verisi siliniyor: $d"; rm -rf "$d"; }
  done
fi

say "Kaldirma tamam."
