# WhatsApp for Linux

`web.whatsapp.com`'u kendi penceresinde çalıştıran, sistem tepsisinde arka
planda duran Tauri v2 kabuğu. Sistem WebKitGTK'sını kullanır — güvenlik
yamaları dağıtım güncellemeleriyle gelir, uygulamayla birlikte paketlenmez.

![platform](https://img.shields.io/badge/platform-Linux-blue)
![tauri](https://img.shields.io/badge/Tauri-v2-24C8DB)
![license](https://img.shields.io/badge/license-MIT-green)

Depo: [github.com/CihanOzden9/Whatsapp_For_Ubuntu](https://github.com/CihanOzden9/Whatsapp_For_Ubuntu)

Ubuntu üzerinde geliştirildi ve test edildi; WebKitGTK 4.1 bulunan her
Linux dağıtımında çalışır.

---

## Kurulum

Tek seferlik:

```bash
git clone https://github.com/CihanOzden9/Whatsapp_For_Ubuntu.git
cd Whatsapp_For_Ubuntu
./scripts/install.sh
```

Script şunları sırayla yapar; her adım zaten tamamsa atlar:

1. Sistem paketlerini kurar (`packaging/apt-requirements.txt`, `sudo` ister)
2. Rust yoksa `rustup` ile kurar ve `~/.bashrc`'ye PATH satırını ekler
3. `npm ci` ile Node bağımlılıklarını kurar
4. Release derlemesi yapar
5. Binary'yi, `whatsapp` komutunu, ikonu ve menü kaydını `~/.local` altına kurar

Bittiğinde:

```bash
whatsapp
```

Uygulama menüsünde de **WhatsApp** olarak görünür.

> `whatsapp: command not found` alırsan `~/.local/bin` henüz PATH'ine
> girmemiştir. Yeni bir terminal aç ya da `source ~/.bashrc` çalıştır.

### Oturum açılışında otomatik başlat

```bash
./scripts/install.sh --autostart
```

systemd tercih edersen `packaging/whatsapp-for-linux.service` dosyasına bak —
sertleştirilmiş bir user unit'i (`ProtectHome=read-only`, yalnızca kendi veri
dizinine yazma izni).

### Kaldırma

```bash
./scripts/uninstall.sh           # uygulamayı kaldırır, oturumu korur
./scripts/uninstall.sh --purge   # oturum verisini de siler (tekrar QR okutursun)
```

---

## Gereksinimler

| Bileşen | Sürüm | Not |
|---|---|---|
| Linux | — | Debian/Ubuntu ailesi test edildi |
| Node.js | 18+ | `npm` ile birlikte |
| Rust | 1.77+ | `install.sh` yoksa kurar |
| WebKitGTK | 4.1 | `libwebkit2gtk-4.1-dev` |

Sistem paketlerinin tam listesi `packaging/apt-requirements.txt` içinde.
Debian/Ubuntu dışı bir dağıtımdaysan karşılıklarını elle kur; `install.sh`
apt bulamazsa listeyi ekrana basıp devam eder.

---

## Geliştirme

```bash
npm install
npm run dev      # hot-reload ile geliştirme derlemesi
npm run build    # src-tauri/target/release/bundle/ altında .deb ve AppImage
```

### VS Code snap'i kullanıyorsan

Snap olarak kurulu VS Code, entegre terminale kendi kütüphane yollarını
sızdırır (`GTK_PATH`, `GIO_MODULE_DIR`, `XDG_DATA_DIRS`, `GDK_BACKEND`…).
Bu ortamda `npm run dev` iki şekilde patlar:

```
symbol lookup error: /snap/core20/.../libpthread.so.0: undefined symbol: __libc_pthread_init
GLib-GIO-ERROR: Settings schema 'org.gnome.settings-daemon.plugins.xsettings' does not contain a key named 'antialiasing'
```

İkisi de projeyle ilgili değil, ortam kirliliği. Çözüm — normal bir terminal
kullan, ya da:

```bash
./scripts/dev-clean.sh            # ortamı temizleyip native Wayland'da çalıştırır
./scripts/dev-clean.sh x11        # XWayland'a zorla
./scripts/dev-clean.sh nodmabuf   # DMABUF renderer kapalı
```

Kurulmuş `whatsapp` komutu bu temizliği kendi içinde yaptığı için her
terminalde sorunsuz çalışır.

### Performans notu

Ağır iş WebKitGTK'nın render sürecinde: boş QR sayfasında `WebKitWebProcess`
tek çekirdeğin ~%46'sını kullanır, Rust tarafı ~%4'te kalır. GPU hızlandırma
açıktır (`/dev/dri/renderD128` webview süreçlerinde açık). WhatsApp Web ağır
bir React uygulaması ve Blink için optimize edilmiş; WebKitGTK'da daha yavaş
olması bu yaklaşımın yapısal sonucu.

`WEBKIT_DISABLE_COMPOSITING_MODE=1` **kullanma** — ölçümde durumu belirgin
şekilde kötüleştiriyor.

---

## Güvenlik kararları

| Karar | Nerede | Neden |
|---|---|---|
| Sadece `web.whatsapp.com` uygulama içinde açılır | `src-tauri/src/security.rs` | Sohbetten gelen kimlik avı bağlantısı asla oturum context'inde açılmaz; geri kalan her adres varsayılan tarayıcıya gider |
| `https` dışındaki şemalar engelli | `src-tauri/src/security.rs` | `file:`, `javascript:`, özel şema saldırılarını keser |
| Oturum dizini `0700` | `src-tauri/src/security.rs` | WhatsApp Web oturumu = hesaba tam erişim; diğer kullanıcılar okuyamasın |
| `umask(0077)` en başta | `src-tauri/src/security.rs` | WebKitGTK oturum dosyalarını kendi yaratıyor ve varsayılan umask'ta 0644 bırakıyor |
| Remote origin'e sıfır Tauri komutu | `src-tauri/capabilities/default.json` | `remote` alanı bilerek boş: WhatsApp'ın JS'i IPC'ye ulaşamaz |
| İzin filtresi: sadece bildirim | `src-tauri/src/platform_linux.rs` | Konum, MIDI, cihaz erişimi reddedilir; kamera/mikrofon varsayılan kapalı |
| Sayfa kendi penceresini açamaz | `src-tauri/src/platform_linux.rs` | `javascript_can_open_windows_automatically = false` |
| DevTools sadece debug derlemesinde | `src-tauri/src/platform_linux.rs` | Release'de uzaktan gelen JS için hata ayıklama yüzeyi yok |
| systemd sertleştirmesi | `packaging/*.service` | `ProtectHome=read-only` + sadece kendi veri dizinine yazma |

### Bilerek yapılmayanlar

- **Script enjeksiyonu yok.** Tema/eklenti amacıyla sayfaya JS enjekte eden her
  şey oturum anahtarlarını okuyabilir.
- **Şifreleme uygulamada yok.** Oturum verisi WebKitGTK'nın kendi deposunda düz
  durur; gerçek koruma disk şifrelemesi (LUKS).
- **Protokol kütüphanesi (Baileys/whatsapp-web.js) yok.** ToS ihlali ve ban
  riski; oturum anahtarlarını kendi kodundan geçirmek gereksiz saldırı yüzeyi.

---

## Bakım

- **`USER_AGENT`** (`src-tauri/src/lib.rs`): WhatsApp "tarayıcınız
  desteklenmiyor" derse güncel bir Chrome sürümüyle yenile.
- **Kamera/mikrofon**: `ALLOW_CAMERA_AND_MIC` (`src-tauri/src/platform_linux.rs`)
  — sesli ve görüntülü arama için `true` yap, sonra yeniden kur.

## Proje yapısı

```
src/index.html                     açılış ekranı (webview WhatsApp'a yönlenene kadar)
src-tauri/src/lib.rs               pencere kurulumu, tepsi, kapatma davranışı
src-tauri/src/security.rs          gezinme filtresi, dosya izinleri
src-tauri/src/platform_linux.rs    WebKitGTK ayarları ve izin filtresi
src-tauri/src/tray.rs              sistem tepsisi menüsü
packaging/                         systemd unit, autostart, apt bağımlılıkları
scripts/install.sh                 tek seferlik kurulum
scripts/uninstall.sh               kaldırma
scripts/dev-clean.sh               snap ortam kirliliğine karşı geliştirme başlatıcısı
```

## Lisans

[MIT](LICENSE) — Copyright (c) 2026 Cihan
