import Foundation

enum AppError: LocalizedError, Identifiable {
    case networkError(Error)
    case imageLoadingFailed
    case wallpaperSettingFailed(Error)
    case diskSpaceInsufficient
    case invalidURL
    
    var id: String { localizedDescription }
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .imageLoadingFailed:
            return "图片加载失败"
        case .wallpaperSettingFailed(let error):
            return "壁纸设置失败: \(error.localizedDescription)"
        case .diskSpaceInsufficient:
            return "磁盘空间不足"
        case .invalidURL:
            return "URL 无效"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "请检查网络连接后重试"
        case .imageLoadingFailed:
            return "请尝试刷新或选择其他图片"
        case .wallpaperSettingFailed:
            return "请检查系统权限或尝试重启应用"
        case .diskSpaceInsufficient:
            return "请清理磁盘空间后重试"
        case .invalidURL:
            return "请检查图片链接是否有效"
        }
    }
}
