//
//  ImageViewModel.swift
//  Wallpaper
//
//  Created by dj on 2026/3/4.
//
import SwiftUI
import Combine

@MainActor
final class ImageViewModel: ObservableObject {
    
    @Published var images: [ImageItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    @Published var currentRandomImageURL: URL?     // 用于显示预览
    @Published var isSettingWallpaper: Bool = false
    @Published private(set) var favoriteImages: [ImageItem] = []
    @Published private(set) var categories: [WallpaperCategory] = []
    
    @AppStorage("wallpaperInterval") private var savedInterval: String = WallpaperInterval.off.rawValue
    @AppStorage("favoriteImageItemsData") private var favoriteImageItemsData: Data = Data()
    @AppStorage("wallpaperCategoryId") private var savedCategoryId: String = "29"
    
    @Published var selectedInterval: WallpaperInterval {
        didSet {
            savedInterval = selectedInterval.rawValue
            updateTimer()
        }
    }

    @Published var selectedCategoryId: String {
        didSet {
            savedCategoryId = selectedCategoryId
            Task { await refresh() }
        }
    }
    
    
    private let service: PicsumService
    private var currentPage = 1
    private(set) var canLoadMore = true
    private var loadToken = UUID()
    
    private var timer: Timer?
    
    init(service: PicsumService? = nil) {
        self.service = service ?? PicsumService()
        
        // 从 UserDefaults 恢复上次选择
        let persistedValue = UserDefaults.standard.string(forKey: "wallpaperInterval")
            ?? WallpaperInterval.off.rawValue
        let initialInterval = WallpaperInterval(rawValue: persistedValue) ?? .off
        _selectedInterval = .init(initialValue: initialInterval)

        let persistedFavorites = UserDefaults.standard.data(forKey: "favoriteImageItemsData") ?? Data()
        favoriteImages = Self.decodeFavorites(from: persistedFavorites)

        let persistedCategoryId = UserDefaults.standard.string(forKey: "wallpaperCategoryId") ?? "29"
        _selectedCategoryId = .init(initialValue: persistedCategoryId)
        
        // App 启动时如果之前开了定时，就继续
        updateTimer()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func updateTimer() {
        timer?.invalidate()
        timer = nil
        
        guard let intervalSeconds = selectedInterval.seconds else {
            return  // 关闭状态
        }
        
        // 立即执行一次（可选：用户可能希望“开启后马上换一次”）
        // Task { await fetchAndSetRandomWallpaper() }
        
        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchAndSetRandomWallpaper()
            }
        }
        
        // 让 timer 立即开始计时（默认第一次触发是在 interval 后）
        // 如果希望立即触发，可以在上面加一次手动调用
    }
    
    func loadMoreImages(force: Bool = false) async {
        guard (!isLoading || force), canLoadMore else { return }
        
        isLoading = true
        errorMessage = nil
        let requestCategoryId = selectedCategoryId
        let requestToken = loadToken
        
        do {
            let newImages = try await service.fetchImages(
                categoryId: requestCategoryId,
                page: currentPage,
                limit: 60
            )
            guard requestToken == loadToken, requestCategoryId == selectedCategoryId else {
                isLoading = false
                return
            }
            images.append(contentsOf: newImages)
            
            if newImages.count < 60 {
                canLoadMore = false
            } else {
                currentPage += 1
            }
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refresh() async {
        loadToken = UUID()
        images.removeAll()
        currentPage = 1
        canLoadMore = true
        await loadMoreImages(force: true)
    }
    
    func fetchAndSetRandomWallpaper() async {
        isSettingWallpaper = true
        
        defer { isSettingWallpaper = false }
        
        do {
            let imageURL = try await service.fetchRandomImageURL(categoryId: selectedCategoryId)
            currentRandomImageURL = imageURL
            
            let data = try await service.fetchImageData(from: imageURL)
            
            try await setWallpaper(data: data)
        } catch {
            errorMessage = "随机壁纸设置失败：\(error.localizedDescription)"
        }
    }

    func setWallpaper(for item: ImageItem) async {
        isSettingWallpaper = true
        defer { isSettingWallpaper = false }

        do {
            guard let imageURL = URL(string: item.download_url) else {
                errorMessage = "图片地址无效"
                return
            }
            currentRandomImageURL = imageURL
            let data = try await service.fetchImageData(from: imageURL)
            try await setWallpaper(data: data)
        } catch {
            errorMessage = "设置壁纸失败：\(error.localizedDescription)"
        }
    }

    func loadCategories() async {
        do {
            categories = try await service.fetchCategories()
            if categories.contains(where: { $0.id == selectedCategoryId }) == false,
               let first = categories.first {
                selectedCategoryId = first.id
            }
        } catch {
            errorMessage = "分类加载失败：\(error.localizedDescription)"
        }
    }

    func isFavorite(_ item: ImageItem) -> Bool {
        favoriteImages.contains(where: { $0.id == item.id })
    }

    func toggleFavorite(_ item: ImageItem) {
        if let index = favoriteImages.firstIndex(where: { $0.id == item.id }) {
            favoriteImages.remove(at: index)
        } else {
            favoriteImages.insert(item, at: 0)
        }
        persistFavorites()
    }

    func copyImageLink(for item: ImageItem) {
        let link = resolvedImageLink(for: item)
        guard link.isEmpty == false else {
            errorMessage = "复制失败：图片链接无效"
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
    }

    func downloadImage(for item: ImageItem) async {
        let links = resolvedImageLinks(for: item)
        guard links.isEmpty == false else {
            errorMessage = "下载失败：图片链接无效"
            return
        }

        var lastError: Error?
        for link in links {
            guard let url = URL(string: link) else { continue }
            do {
                let data = try await service.fetchImageData(from: url)
                let savedURL = try saveImageData(data, itemId: item.id)
                errorMessage = "已下载到：\(savedURL.lastPathComponent)"
                return
            } catch {
                lastError = error
            }
        }

        if let lastError {
            errorMessage = "下载失败：\(lastError.localizedDescription)"
        } else {
            errorMessage = "下载失败：图片链接无效"
        }
    }
    
    // 设置壁纸（放在 ViewModel 里也可以，视需求抽到单独 WallpaperService）
    private func setWallpaper(data: Data) async throws {
        guard let screen = NSScreen.main else { return }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("random_wallpaper_\(UUID().uuidString).jpg")
        
        try data.write(to: tempURL, options: .atomic)
        try NSWorkspace.shared.setDesktopImageURL(tempURL, for: screen, options: [:])
        
        // 可选：清理旧临时文件（这里简单起见不做）
    }

    private func persistFavorites() {
        favoriteImageItemsData = (try? JSONEncoder().encode(favoriteImages)) ?? Data()
    }

    private static func decodeFavorites(from data: Data) -> [ImageItem] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([ImageItem].self, from: data)) ?? []
    }

    private func resolvedImageLink(for item: ImageItem) -> String {
        item.url.isEmpty ? item.download_url : item.url
    }

    private func resolvedImageLinks(for item: ImageItem) -> [String] {
        var links: [String] = []
        let primary = item.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondary = item.download_url.trimmingCharacters(in: .whitespacesAndNewlines)
        if primary.isEmpty == false { links.append(primary) }
        if secondary.isEmpty == false, secondary != primary { links.append(secondary) }
        return links
    }

    private func saveImageData(_ data: Data, itemId: String) throws -> URL {
        let fileName = "wallpaper_\(itemId).jpg"
        let fileManager = FileManager.default

        if let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            let downloadFileURL = downloadsURL.appendingPathComponent(fileName)
            do {
                try data.write(to: downloadFileURL, options: .atomic)
                return downloadFileURL
            } catch {
                // Continue to temporary directory fallback.
            }
        }

        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }
}


enum WallpaperInterval: String, CaseIterable, Identifiable {
    case off       = "关闭"
    case min15     = "15分钟"
    case min30     = "30分钟"
    case hour1     = "1小时"
    case hour12    = "12小时"
    case hour24    = "24小时"
    case week1     = "1周"
    
    var id: String { rawValue }
    
    var seconds: TimeInterval? {
        switch self {
        case .off:     return nil
        case .min15:   return 15 * 60
        case .min30:   return 30 * 60
        case .hour1:   return 3600
        case .hour12:  return 12 * 3600
        case .hour24:  return 24 * 3600
        case .week1:   return 7 * 24 * 3600
        }
    }
    
    var displayName: String { rawValue }
}
