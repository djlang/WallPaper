import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
final class WallpaperService: ObservableObject {
    static let shared = WallpaperService()
    
    @Published var currentWallpaperURL: URL?
    @Published var isSettingWallpaper = false
    @Published var lastError: Error?
    
    private let fileManager = FileManager.default
    private let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("Wallpapers")
    
    private init() {
        // 创建临时目录
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // 清理旧的临时文件
        cleanupOldTempFiles()
    }
    
    func setWallpaper(from imageData: Data, for screen: NSScreen? = nil) async throws {
        isSettingWallpaper = true
        defer { isSettingWallpaper = false }
        
        let targetScreen = screen ?? NSScreen.main
        guard let targetScreen = targetScreen else {
            throw WallpaperError.noScreenAvailable
        }
        
        // 创建临时文件
        let tempFileName = "wallpaper_\(UUID().uuidString).jpg"
        let tempFileURL = tempDirectory.appendingPathComponent(tempFileName)
        
        do {
            try imageData.write(to: tempFileURL, options: .atomic)
            
            // 设置壁纸
            try NSWorkspace.shared.setDesktopImageURL(tempFileURL, for: targetScreen, options: [:])
            
            currentWallpaperURL = tempFileURL
            
            // 记录壁纸设置历史
            recordWallpaperHistory(url: tempFileURL, screenIdentifier: screenIdentifier(for: targetScreen))
            
        } catch {
            lastError = error
            throw error
        }
    }
    
    func setWallpaper(from url: URL, for screen: NSScreen? = nil) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        try await setWallpaper(from: data, for: screen)
    }
    
    func setWallpaperForAllScreens(from imageData: Data) async throws {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            throw WallpaperError.noScreenAvailable
        }
        
        // 为所有屏幕设置相同的壁纸
        for screen in screens {
            try await setWallpaper(from: imageData, for: screen)
        }
    }
    
    func restorePreviousWallpaper() async throws {
        guard let lastWallpaperURL = getLastWallpaperURL() else {
            throw WallpaperError.noPreviousWallpaper
        }
        
        try await setWallpaper(from: lastWallpaperURL)
    }
    
    // 获取屏幕标识符的辅助方法
    private func screenIdentifier(for screen: NSScreen) -> String {
        // NSScreen 在 macOS 中没有直接的标识符属性
        // 使用屏幕的 frame 和 deviceDescription 创建唯一标识符
        let frame = screen.frame
        let deviceDescription = screen.deviceDescription
        
        let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int ?? 0
        return "screen_\(screenNumber)_\(Int(frame.origin.x))_\(Int(frame.origin.y))_\(Int(frame.width))_\(Int(frame.height))"
    }
    
    private func recordWallpaperHistory(url: URL, screenIdentifier: String) {
        let historyEntry = WallpaperHistoryEntry(
            url: url,
            screenID: screenIdentifier,
            date: Date()
        )
        
        var history = UserDefaults.standard.wallpaperHistory ?? []
        history.append(historyEntry)
        
        // 只保留最近的 50 条记录
        if history.count > 50 {
            history.removeFirst(history.count - 50)
        }
        
        UserDefaults.standard.wallpaperHistory = history
    }
    
    private func getLastWallpaperURL() -> URL? {
        guard let history = UserDefaults.standard.wallpaperHistory,
              let lastEntry = history.last else {
            return nil
        }
        
        // 检查文件是否还存在
        guard fileManager.fileExists(atPath: lastEntry.url.path) else {
            return nil
        }
        
        return lastEntry.url
    }
    
    private func cleanupOldTempFiles() {
        guard let files = try? fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        
        for file in files {
            if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < oneWeekAgo {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    // 提供一个清理临时文件的公共方法
    func clearTempFiles() {
        do {
            let files = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        } catch {
            print("清理临时文件失败: \(error)")
        }
    }
}

enum WallpaperError: LocalizedError {
    case noScreenAvailable
    case noPreviousWallpaper
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .noScreenAvailable:
            return "未找到可用的屏幕"
        case .noPreviousWallpaper:
            return "没有可恢复的壁纸历史记录"
        case .invalidImageData:
            return "图片数据无效"
        }
    }
}

struct WallpaperHistoryEntry: Codable {
    let url: URL
    let screenID: String
    let date: Date
}

extension UserDefaults {
    private enum Keys {
        static let wallpaperHistory = "wallpaperHistory"
    }
    
    var wallpaperHistory: [WallpaperHistoryEntry]? {
        get {
            guard let data = data(forKey: Keys.wallpaperHistory) else { return nil }
            return try? JSONDecoder().decode([WallpaperHistoryEntry].self, from: data)
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            set(data, forKey: Keys.wallpaperHistory)
        }
    }
}
