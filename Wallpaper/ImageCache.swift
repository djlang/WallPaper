import Foundation
import AppKit

actor ImageCache {
    static let shared = ImageCache()
    
    private let memoryCache = NSCache<NSURL, NSImage>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    
    private init() {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cachesDirectory.appendingPathComponent("ImageCache")
        
        // 创建缓存目录
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // 设置内存缓存限制
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func image(for url: URL) async -> NSImage? {
        // 1. 检查内存缓存
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        
        // 2. 检查磁盘缓存
        let fileName = await url.absoluteString.sha256 + ".jpg"
        let fileURL = diskCacheURL.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = NSImage(data: data) {
            // 存入内存缓存
            memoryCache.setObject(image, forKey: url as NSURL)
            return image
        }
        
        return nil
    }
    
    func store(_ image: NSImage, for url: URL) async {
        // 存入内存缓存
        memoryCache.setObject(image, forKey: url as NSURL)
        
        // 存入磁盘缓存
        Task.detached { [weak self] in
            guard let self = self,
                  let data = image.tiffRepresentation,
                  let jpegData = NSBitmapImageRep(data: data)?.representation(using: .jpeg, properties: [:]) else {
                return
            }
            
            let fileName = await url.absoluteString.sha256 + ".jpg"
            let fileURL = self.diskCacheURL.appendingPathComponent(fileName)
            
            try? jpegData.write(to: fileURL, options: .atomic)
        }
    }
    
    func clearCache() async {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}
// SHA256 扩展
extension String {
    var sha256: String {
        guard let data = self.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// 需要导入 CommonCrypto
import CommonCrypto

