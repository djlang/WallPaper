//
//  WallpaperApp.swift
//  Wallpaper
//
//  Created by dj on 2026/3/4.
//

import SwiftUI

@main
struct WallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
