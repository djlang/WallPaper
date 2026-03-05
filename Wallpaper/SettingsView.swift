//
//  SettingsView.swift
//  Wallpaper
//
//  Created by dj on 2026/3/4.
//

import SwiftUI
import Combine

struct SettingsView: View {
    @AppStorage("wallpaperInterval") private var savedInterval: String = WallpaperInterval.off.rawValue
    
    var selectedInterval: Binding<WallpaperInterval> {
        Binding(
            get: { WallpaperInterval(rawValue: savedInterval) ?? .off },
            set: { savedInterval = $0.rawValue }
        )
    }
    
    var body: some View {
        Form {
            Section("自动更换壁纸") {
                Picker("间隔", selection: selectedInterval) {
                    ForEach(WallpaperInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.radioGroup)   // 或 .menu
                
                Text("当前设置：\(selectedInterval.wrappedValue.displayName)")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 320, minHeight: 180)
        .padding()
    }
}
