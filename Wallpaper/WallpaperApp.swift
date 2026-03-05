//
//  WallpaperApp.swift
//  Wallpaper
//
//  Created by dj on 2026/3/4.
//

import SwiftUI

@main
struct WallpaperApp: App {
    @StateObject private var viewModel = ImageViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }

        MenuBarExtra("Wallpaper", systemImage: "photo.on.rectangle.angled") {
            MenuBarImageListView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
