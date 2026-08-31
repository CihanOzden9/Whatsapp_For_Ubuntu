#!/usr/bin/env bash
# VS Code snap'inin terminale sizdirdigi ortam degiskenlerini temizleyip
# uygulamayi calistirir.
#
#   ./scripts/dev-clean.sh            -> native Wayland (temiz, onerilen)
#   ./scripts/dev-clean.sh x11        -> XWayland'a zorla
#   ./scripts/dev-clean.sh nodmabuf   -> native Wayland + DMABUF renderer kapali
#   ./scripts/dev-clean.sh build      -> release derlemesiyle calistir
#
# Herhangi bir modda sonuna ek komut verebilirsin, orn:
#   ./scripts/dev-clean.sh -- npm run build

set -euo pipefail

# 1) VS Code orijinal degerleri <VAR>_VSCODE_SNAP_ORIG icinde sakliyor: geri al.
while IFS= read -r orig; do
  var="${orig%_VSCODE_SNAP_ORIG}"
  if [[ -n "${!orig:-}" ]]; then export "$var=${!orig}"; else unset "$var" || true; fi
  unset "$orig" || true
done < <(compgen -v | grep '_VSCODE_SNAP_ORIG$' || true)

# 2) ORIG karsiligi olmayan, snap'ten sizan digerleri.
#    GTK_PATH + GIO_MODULE_DIR: core20 libpthread cakismasi (symbol lookup error)
#    GSETTINGS_SCHEMA_DIR + XDG_DATA_*: eski xsettings semasi -> Wayland'da cokme
unset GTK_PATH GIO_MODULE_DIR GTK_EXE_PREFIX GTK_IM_MODULE_FILE LOCPATH GSETTINGS_SCHEMA_DIR || true

cd "$(dirname "$0")/.."

mode="${1:-wayland}"
case "$mode" in
  wayland)  ;;
  x11)      export GDK_BACKEND=x11 ;;
  nodmabuf) export WEBKIT_DISABLE_DMABUF_RENDERER=1 ;;
  build)    exec npm run build ;;
  --)       shift; exec "$@" ;;
  *)        echo "bilinmeyen mod: $mode" >&2; exit 1 ;;
esac

exec npm run dev
