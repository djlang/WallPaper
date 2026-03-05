//
//  ImageItem.swift
//  Wallpaper
//
//  Created by dj on 2026/3/4.
//

import Foundation

struct ImageItem: Codable, Identifiable, Hashable {
    let id: String
    let author: String
    let width: Int
    let height: Int
    let url: String
    let download_url: String
    
    // 用于 SwiftUI ForEach 的 Identifiable 要求
    var idString: String { id }
}

extension ImageItem {
    init(from dto: WallpaperImageDTO) {
        let cleanedUtag = Self.cleanedValue(dto.utag)
        let cleanedTag = Self.cleanedValue(dto.tag)
        let cleanedResolution = Self.cleanedValue(dto.resolution)
        let resolvedAuthor = cleanedUtag ?? cleanedTag ?? cleanedResolution ?? "Unknown"

        let (w, h) = Self.parseResolution(dto.resolution)

        let fullURL = Self.firstNonEmptyURL([
            dto.url,
            dto.url_mid,
            dto.img_1600_900,
            dto.img_1440_900,
            dto.img_1366_768,
            dto.img_1280_1024,
            dto.img_1024_768,
            dto.url_thumb
        ])

        let thumbURL = Self.firstNonEmptyURL([
            dto.url_thumb,
            dto.url_mid,
            dto.img_1366_768,
            dto.img_1280_1024,
            dto.img_1024_768,
            dto.url
        ])

        id = dto.id
        author = resolvedAuthor
        width = w
        height = h
        url = fullURL ?? ""
        download_url = thumbURL ?? fullURL ?? ""
    }

    private static func firstNonEmptyURL(_ candidates: [String?]) -> String? {
        for value in candidates {
            if let cleaned = cleanedValue(value) {
                return cleaned
            }
        }
        return nil
    }

    private static func parseResolution(_ resolution: String?) -> (Int, Int) {
        guard let cleaned = cleanedValue(resolution) else { return (0, 0) }
        let parts = cleaned.split(separator: "x")
        guard parts.count == 2,
              let w = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let h = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return (0, 0)
        }
        return (w, h)
    }

    private static func cleanedValue(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sanitizeURLString(_ value: String) -> String {
        value
    }
}
