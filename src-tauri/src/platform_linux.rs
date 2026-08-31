//! WebKitGTK'ya dogrudan dokunan sertlestirmeler. Tauri bu ayarlari kendi
//! API'sinden acmadigi icin platform webview'ini asagi seviyeden aliyoruz.

use gtk::glib::object::Cast;
use tauri::WebviewWindow;
use webkit2gtk::{
    NotificationPermissionRequest, PermissionRequestExt, SettingsExt, UserMediaPermissionRequest,
    WebViewExt,
};

/// Sesli/goruntulu arama icin kamera ve mikrofon erisimi. Varsayilan kapali:
/// ihtiyacin olunca `true` yap. Kapaliyken WhatsApp arama baslatamaz.
const ALLOW_CAMERA_AND_MIC: bool = false;

pub fn harden_webview(window: &WebviewWindow) {
    let result = window.with_webview(|platform| {
        let webview = platform.inner();

        if let Some(settings) = WebViewExt::settings(&webview) {
            // Uzaktan gelen JS calistiriyoruz; DevTools'u sadece debug'da ac.
            settings.set_enable_developer_extras(cfg!(debug_assertions));
            // Sayfa kendi basina yeni pencere acamasin.
            settings.set_javascript_can_open_windows_automatically(false);
        }

        // Izin istekleri: bildirim disinda her sey reddedilir.
        webview.connect_permission_request(|_webview, request| {
            if request
                .downcast_ref::<NotificationPermissionRequest>()
                .is_some()
            {
                request.allow();
            } else if request
                .downcast_ref::<UserMediaPermissionRequest>()
                .is_some()
            {
                if ALLOW_CAMERA_AND_MIC {
                    request.allow();
                } else {
                    request.deny();
                }
            } else {
                // Konum, MIDI, cihaz erisimi, pointer lock vb.
                request.deny();
            }
            true
        });
    });

    if let Err(e) = result {
        eprintln!("webview sertlestirilemedi: {e}");
    }
}
