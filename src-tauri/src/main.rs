// Release derlemesinde Windows'ta konsol penceresi acilmasin diye.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    app_lib::run();
}
