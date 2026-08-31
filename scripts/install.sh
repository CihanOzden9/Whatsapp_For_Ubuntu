#!/usr/bin/env bash
#
# WhatsApp for Linux - tek seferlik kurulum.
#
#   ./scripts/install.sh              kur
#   ./scripts/install.sh --autostart  kur + oturum acilisinda otomatik baslat
#
# Bittiginde terminale "whatsapp" yazmak uygulamayi acar.
# Kaldirmak icin: ./scripts/uninstall.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="whatsapp-for-linux"
CMD_NAME="whatsapp"

BIN_DIR="$HOME/.local/bin"
LIB_DIR="$HOME/.local/lib/$APP_ID"
ICON_DIR="$HOME/.local/share/icons/hicolor/128x128/apps"
DESKTOP_DIR="$HOME/.local/share/applications"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31mHATA:\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. Sistem bagimliliklari -------------------------------------------------

install_apt_deps() {
  local req="$REPO/packaging/apt-requirements.txt"
  [[ -f "$req" ]] || die "bulunamadi: $req"

  if ! command -v apt-get >/dev/null 2>&1; then
    warn "apt bulunamadi. Debian/Ubuntu disi bir dagitim kullaniyorsun."
    warn "Su paketlerin karsiliklarini elle kur:"
    grep -v '^#' "$req" | grep -v '^$' | sed 's/^/      /' >&2
    return 0
  fi

  mapfile -t pkgs < <(grep -v '^#' "$req" | grep -v '^$')

  local missing=()
  for p in "${pkgs[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    say "Sistem bagimliliklari zaten kurulu."
    return 0
  fi

  say "Eksik sistem paketleri kuruluyor (sudo parolasi istenecek): ${missing[*]}"
  sudo apt-get update
  sudo apt-get install -y "${missing[@]}"
}

# --- 2. Rust ------------------------------------------------------------------

install_rust() {
  # Kurulu ama PATH'te olmayabilir.
  [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

  if command -v cargo >/dev/null 2>&1; then
    say "Rust kurulu: $(cargo --version)"
  else
    say "Rust kuruluyor (rustup)..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    source "$HOME/.cargo/env"
  fi

  # rustup PATH satirini kalici hale getir (bir kez).
  local line='. "$HOME/.cargo/env"'
  if [[ -f "$HOME/.bashrc" ]] && ! grep -qF '.cargo/env' "$HOME/.bashrc"; then
    printf '\n%s\n' "$line" >> "$HOME/.bashrc"
    say "~/.bashrc'ye cargo PATH satiri eklendi."
  fi
}

# --- 3. Node bagimliliklari ve derleme ----------------------------------------

build_app() {
  command -v npm >/dev/null 2>&1 || die "npm bulunamadi. Node.js 18+ kur: https://nodejs.org"

  say "Node bagimliliklari kuruluyor..."
  cd "$REPO"
  if [[ -f package-lock.json ]]; then npm ci; else npm install; fi

  say "Release derlemesi yapiliyor (ilk seferde birkac dakika surebilir)..."
  npm run build
}

# --- 4. Kurulum ---------------------------------------------------------------

install_files() {
  local built="$REPO/src-tauri/target/release/$APP_ID"
  [[ -x "$built" ]] || die "derleme ciktisi bulunamadi: $built"

  mkdir -p "$BIN_DIR" "$LIB_DIR" "$ICON_DIR" "$DESKTOP_DIR"

  say "Binary kuruluyor -> $LIB_DIR/$APP_ID"
  install -m 755 "$built" "$LIB_DIR/$APP_ID"

  say "Ikon kuruluyor -> $ICON_DIR/$APP_ID.png"
  install -m 644 "$REPO/src-tauri/icons/128x128.png" "$ICON_DIR/$APP_ID.png"

  # "whatsapp" komutu: ortam temizligi yapip binary'yi calistiran ince bir kabuk.
  say "Komut kuruluyor -> $BIN_DIR/$CMD_NAME"
  cat > "$BIN_DIR/$CMD_NAME" <<WRAPPER
#!/usr/bin/env bash
# WhatsApp for Linux baslatici. scripts/install.sh tarafindan uretildi.
#
# Snap olarak kurulu VS Code / bazi snap uygulamalari entegre terminale kendi
# kutuphane yollarini sizdiriyor; bu ortamda WebKitGTK yanlis glibc'yi yukleyip
# cokuyor. Asagidaki temizlik o durumda da calismasini sagliyor.
while IFS= read -r orig; do
  var="\${orig%_VSCODE_SNAP_ORIG}"
  if [[ -n "\${!orig:-}" ]]; then export "\$var=\${!orig}"; else unset "\$var" || true; fi
done < <(compgen -v | grep '_VSCODE_SNAP_ORIG\$' || true)
unset GTK_PATH GIO_MODULE_DIR GTK_EXE_PREFIX GTK_IM_MODULE_FILE LOCPATH GSETTINGS_SCHEMA_DIR || true

exec "$LIB_DIR/$APP_ID" "\$@"
WRAPPER
  chmod 755 "$BIN_DIR/$CMD_NAME"

  say "Menu kaydi kuruluyor -> $DESKTOP_DIR/$APP_ID.desktop"
  cat > "$DESKTOP_DIR/$APP_ID.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=WhatsApp
Comment=WhatsApp Web masaustu kabugu
Exec=$BIN_DIR/$CMD_NAME
Icon=$APP_ID
Terminal=false
Categories=Network;InstantMessaging;
StartupWMClass=$APP_ID
DESKTOP

  command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
}

# --- 5. Otomatik baslatma (istege bagli, --autostart) -------------------------

install_autostart() {
  local dir="$HOME/.config/autostart"
  mkdir -p "$dir"
  # .desktop dosyalari ~ ya da %h desteklemez: mutlak yol yaziyoruz.
  sed "s|^Exec=YOL$|Exec=$BIN_DIR/$CMD_NAME|" \
      "$REPO/packaging/$APP_ID-autostart.desktop" \
      | grep -v '^#' > "$dir/$APP_ID.desktop"
  say "Oturum acilisinda otomatik baslatma kuruldu -> $dir/$APP_ID.desktop"
}

# --- 6. PATH kontrolu ---------------------------------------------------------

check_path() {
  case ":$PATH:" in
    *":$BIN_DIR:"*) return 0 ;;
  esac

  warn "$BIN_DIR PATH'inde degil."
  local line="export PATH=\"\$HOME/.local/bin:\$PATH\""
  if [[ -f "$HOME/.bashrc" ]] && ! grep -qF '.local/bin' "$HOME/.bashrc"; then
    printf '\n%s\n' "$line" >> "$HOME/.bashrc"
    say "~/.bashrc'ye PATH satiri eklendi."
  fi
  warn "Yeni bir terminal ac ya da: source ~/.bashrc"
}

# --- calistir -----------------------------------------------------------------

main() {
  local want_autostart=0
  for arg in "$@"; do
    case "$arg" in
      --autostart) want_autostart=1 ;;
      -h|--help)
        sed -n '3,9p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
        exit 0 ;;
      *) die "bilinmeyen secenek: $arg (--autostart, --help)" ;;
    esac
  done

  say "WhatsApp for Linux kurulumu basliyor."
  install_apt_deps
  install_rust
  build_app
  install_files
  if [[ $want_autostart -eq 1 ]]; then install_autostart; fi
  check_path
  echo
  say "Kurulum tamam. Terminale '$CMD_NAME' yaz ya da uygulama menusunden 'WhatsApp' ac."
}

main "$@"
