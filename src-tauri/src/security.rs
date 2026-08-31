use std::fs;

use tauri::{AppHandle, Manager, Url};
use tauri_plugin_opener::OpenerExt;

/// Sadece bu ana bilgisayar uygulamanin icinde acilir. Digerlerinin tamami
/// (whatsapp.com/faq dahil) varsayilan tarayiciya gider: boylece sohbetten
/// gelen bir kimlik avi baglantisi asla oturumun context'inde acilmaz.
const IN_APP_HOSTS: &[&str] = &["web.whatsapp.com"];

/// `true` -> gezinmeye izin ver, `false` -> engelle.
pub fn allow_navigation(app: &AppHandle, url: &Url) -> bool {
    match url.scheme() {
        // Webview'in kendi ic semalari; medya onizleme ve about:blank icin gerekli.
        "about" | "blob" | "data" => return true,
        "https" => {}
        // http, file, javascript, ozel semalar: hicbiri.
        _ => return false,
    }

    if IN_APP_HOSTS.contains(&url.host_str().unwrap_or_default()) {
        return true;
    }

    open_externally(app, url);
    false
}

/// Baglantiyi varsayilan tarayiciya devret.
pub fn open_externally(app: &AppHandle, url: &Url) {
    if let Err(e) = app.opener().open_url(url.as_str(), None::<&str>) {
        eprintln!("baglanti disarida acilamadi: {e}");
    }
}

/// Bundan sonra olusturulacak her dosya sadece bu kullaniciya acik olsun.
/// WebKitGTK oturum dosyalarini kendi yaratiyor ve varsayilan umask ile
/// 0644 biraki(yor); ust dizin 0700 olsa da savunmayi derinlestiriyoruz.
/// Baska is parcaciklari dogmadan, main'in en basinda cagrilmali.
#[cfg(target_os = "linux")]
pub fn restrict_umask() {
    // SAFETY: tek is parcacikli baslangicta cagriliyor.
    unsafe { libc::umask(0o077) };
}

/// Oturum dizinini olustur ve 0700 yap (baska kullanicilar okuyamasin).
pub fn harden_data_dir(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    let dir = app.path().app_local_data_dir()?;
    fs::create_dir_all(&dir)?;

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&dir, fs::Permissions::from_mode(0o700))?;
    }

    Ok(())
}
