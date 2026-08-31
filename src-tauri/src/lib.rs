mod security;
mod tray;

#[cfg(target_os = "linux")]
mod platform_linux;

use tauri::{WebviewUrl, WebviewWindowBuilder, WindowEvent};

/// Uygulama icinde acilmasina izin verilen tek adres.
const START_URL: &str = "https://web.whatsapp.com/";

/// WhatsApp Web bilinmeyen tarayicilari reddeder, bu yuzden sabit bir Chrome
/// kimligi gonderiyoruz. WhatsApp "tarayiciniz desteklenmiyor" derse burayi
/// guncel bir Chrome surumuyle yenile.
const USER_AGENT: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 \
(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

pub fn run() {
    // Baska is parcaciklari dogmadan: oturum dosyalari 0600 olsun.
    #[cfg(target_os = "linux")]
    security::restrict_umask();

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            // Oturum verisi (IndexedDB/localStorage) = hesaba tam erisim.
            // Pencere olusmadan once dizini baskasina kapat.
            security::harden_data_dir(app.handle())?;

            let handle = app.handle().clone();
            let window = WebviewWindowBuilder::new(
                app,
                "main",
                WebviewUrl::External(START_URL.parse()?),
            )
            .title("WhatsApp")
            .inner_size(1100.0, 780.0)
            .min_inner_size(640.0, 520.0)
            .user_agent(USER_AGENT)
            .on_navigation(move |url| security::allow_navigation(&handle, url))
            .build()?;

            #[cfg(target_os = "linux")]
            platform_linux::harden_webview(&window);

            tray::build(app.handle())?;

            // Pencereyi kapatmak uygulamayi sonlandirmasin; tepsiye insin.
            let hidden = window.clone();
            window.on_window_event(move |event| {
                if let WindowEvent::CloseRequested { api, .. } = event {
                    api.prevent_close();
                    let _ = hidden.hide();
                }
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("uygulama baslatilamadi");
}
