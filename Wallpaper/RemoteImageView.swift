import SwiftUI
import AppKit

struct RemoteImageView: View {
    private let url: URL?
    private let placeholderSystemName: String
    private let contentMode: ContentMode
    private let shouldCache: Bool

    @State private var image: Image?
    @State private var isLoading = false

    init(url: URL?, 
         placeholderSystemName: String = "photo", 
         contentMode: ContentMode = .fill,
         shouldCache: Bool = true) {
        self.url = url
        self.placeholderSystemName = placeholderSystemName
        self.contentMode = contentMode
        self.shouldCache = shouldCache
    }

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: placeholderSystemName)
                    .foregroundStyle(.secondary)
            }
            
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .task(id: url?.absoluteString) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            image = nil
            return
        }

        // 检查缓存（如果可用）
        if shouldCache, let cachedImage = await getCachedImage(for: url) {
            image = Image(nsImage: cachedImage)
            return
        }

        isLoading = true
        
        do {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            configuration.requestCachePolicy = .returnCacheDataElseLoad
            
            let session = URLSession(configuration: configuration)
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let nsImage = NSImage(data: data) else {
                image = nil
                isLoading = false
                return
            }
            
            // 缓存图片（如果启用了缓存）
            if shouldCache {
                await cacheImage(nsImage, for: url)
            }
            
            image = Image(nsImage: nsImage)
        } catch {
            image = nil
            print("Failed to load image: \(error)")
        }
        
        isLoading = false
    }
    
    // 简化的缓存实现（避免依赖外部 ImageCache 类）
    private func getCachedImage(for url: URL) async -> NSImage? {
        // 这里可以添加更复杂的缓存逻辑
        // 暂时返回 nil，确保编译通过
        return nil
    }
    
    private func cacheImage(_ image: NSImage, for url: URL) async {
        // 这里可以添加缓存逻辑
        // 暂时不做任何操作，确保编译通过
    }
}
