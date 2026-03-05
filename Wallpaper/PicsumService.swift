//
//  PicsumService.swift
//  Wallpaper
//
//  Created by dj on 2026/3/4.
//

import Foundation

final class PicsumService {
    
    private let session: URLSession
    private let categoriesURL = "http://cdn.apc.360.cn/index.php"
    private let listURL = "http://wallpaper.apc.360.cn/index.php"
    
    init(session: URLSession = TrustedURLSession.shared) {
        self.session = session
    }
    
    /// 获取图片分类
    func fetchCategories() async throws -> [WallpaperCategory] {
        let url = try makeURL(
            base: categoriesURL,
            queryItems: [
                URLQueryItem(name: "c", value: "WallPaper"),
                URLQueryItem(name: "a", value: "getAllCategoriesV2"),
                URLQueryItem(name: "from", value: "360chrome")
            ]
        )

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decodeArray(from: data)
    }

    /// 获取图片列表（支持分页）
    /// - Parameters:
    ///   - categoryId: 分类 ID
    ///   - page: 页码，从 1 开始
    ///   - limit: 每页数量
    func fetchImages(categoryId: String, page: Int = 1, limit: Int = 10) async throws -> [ImageItem] {
        let start = max(1, (page - 1) * limit + 1)
        let url = try makeURL(
            base: listURL,
            queryItems: [
                URLQueryItem(name: "c", value: "WallPaper"),
                URLQueryItem(name: "a", value: "getAppsByCategory"),
                URLQueryItem(name: "cid", value: categoryId),
                URLQueryItem(name: "start", value: String(start)),
                URLQueryItem(name: "count", value: String(limit)),
                URLQueryItem(name: "from", value: "360chrome")
            ]
        )

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        let items: [WallpaperImageDTO] = try decodeArray(from: data)
        return items.map { ImageItem(from: $0) }
    }
    
    /// 获取一张随机图片（1920×1080）
    func fetchRandomImageURL(categoryId: String) async throws -> URL {
        let randomStart = Int.random(in: 1...2000)
        let url = try makeURL(
            base: listURL,
            queryItems: [
                URLQueryItem(name: "c", value: "WallPaper"),
                URLQueryItem(name: "a", value: "getAppsByCategory"),
                URLQueryItem(name: "cid", value: categoryId),
                URLQueryItem(name: "start", value: String(randomStart)),
                URLQueryItem(name: "count", value: "1"),
                URLQueryItem(name: "from", value: "360chrome")
            ]
        )

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        let items: [WallpaperImageDTO] = try decodeArray(from: data)
        if let first = items.first {
            let image = ImageItem(from: first)
            if let resolvedURL = URL(string: image.url.isEmpty ? image.download_url : image.url) {
                return resolvedURL
            }
        }
        throw URLError(.badServerResponse)
    }
    
    /// 直接获取图片 Data（用于设置壁纸）
    func fetchImageData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return data
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func makeURL(base: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: base) else {
            throw URLError(.badURL)
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private func decodeArray<T: Codable>(from data: Data) throws -> [T] {
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([T].self, from: data) {
            return direct
        }
        let wrapper = try decoder.decode(WallpaperAPIListWrapper<T>.self, from: data)
        return wrapper.data ?? wrapper.list ?? wrapper.result ?? []
    }
}
