import Foundation

enum ImportSourceType: String, CaseIterable, Codable, Identifiable {
    case xiaohongshu = "小紅書"
    case youtube = "YouTube"
    case instagram = "Instagram"
    case web = "網頁"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .xiaohongshu:
            return "筆記導入"
        case .youtube:
            return "影片收藏"
        case .instagram:
            return "圖文導入"
        case .web:
            return "文章收藏"
        }
    }

    var systemImage: String {
        switch self {
        case .xiaohongshu:
            return "book.closed.fill"
        case .youtube:
            return "tv.fill"
        case .instagram:
            return "camera.fill"
        case .web:
            return "globe"
        }
    }

    static func detectedSource(from urlString: String) -> ImportSourceType {
        guard let host = URLComponents(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines))?.host?.lowercased() else {
            return .web
        }

        if host.contains("xiaohongshu") || host.contains("xhslink") || host.contains("rednote") {
            return .xiaohongshu
        }

        if host.contains("instagram") || host.contains("instagr.am") {
            return .instagram
        }

        if host.contains("youtube") || host.contains("youtu.be") {
            return .youtube
        }

        return .web
    }
}

enum ExportFormat: String, CaseIterable, Codable, Identifiable {
    case json = "JSON"
    case pdf = "PDF"

    var id: String { rawValue }
}

enum RoutinePeriod: String, CaseIterable, Codable, Identifiable {
    case morning = "早間"
    case evening = "晚間"

    var id: String { rawValue }
}

enum ResourceCategory: String, CaseIterable, Codable, Identifiable {
    case all = "全部"
    case skincare = "護膚"
    case fitness = "健身"
    case food = "飲食"
    case outfit = "穿搭"
    case learning = "學習"
    case other = "其他"

    var id: String { rawValue }

    static func suggestedCategory(title: String, description: String, source: ImportSourceType) -> ResourceCategory {
        let combined = "\(title) \(description)".lowercased()

        let skincareKeywords = ["保養", "護膚", "面膜", "精華", "乳液", "防曬", "skin", "serum", "moisturizer"]
        if skincareKeywords.contains(where: combined.contains) {
            return .skincare
        }

        let fitnessKeywords = ["運動", "健身", "體脂", "重量", "瑜伽", "pilates", "workout", "fitness", "gym"]
        if fitnessKeywords.contains(where: combined.contains) {
            return .fitness
        }

        let foodKeywords = ["飲食", "食譜", "熱量", "蛋白質", "早餐", "晚餐", "meal", "recipe", "food"]
        if foodKeywords.contains(where: combined.contains) {
            return .food
        }

        let outfitKeywords = ["穿搭", "服裝", "妝容", "髮型", "outfit", "style", "lookbook"]
        if outfitKeywords.contains(where: combined.contains) {
            return .outfit
        }

        if source == .youtube || source == .web {
            return .learning
        }

        return .other
    }
}

enum ImportedContentType: String, CaseIterable, Codable, Identifiable {
    case video = "影片"
    case imagePost = "圖文"
    case carousel = "多圖"
    case article = "文章"
    case unknown = "未知"

    var id: String { rawValue }
}

enum ResourceImportStatus: String, CaseIterable, Codable, Identifiable {
    case parsed = "已解析"
    case partial = "部分解析"
    case manualCompleted = "手動補齊"
    case failedFallbackSaved = "失敗補存"

    var id: String { rawValue }
}

enum ResourceAnalysisStatus: String, CaseIterable, Codable, Identifiable {
    case pending = "待分析"
    case analyzing = "分析中"
    case analyzed = "已分析"
    case fallback = "規則回退"

    var id: String { rawValue }
}

enum ResourceSyncStatus: String, CaseIterable, Codable, Identifiable {
    case pending = "待同步"
    case syncing = "同步中"
    case succeeded = "同步成功"
    case failed = "同步失敗"

    var id: String { rawValue }
}

enum PlatformAuthorizationState: String, CaseIterable, Codable, Identifiable {
    case notConfigured = "未配置"
    case oauthReady = "可進入授權"
    case backendRequired = "需後端代理"
    case unavailable = "暫不可用"

    var id: String { rawValue }
}

enum MediaRetentionPolicy: String, CaseIterable, Codable, Identifiable {
    case metadataOnly = "只存 Metadata"
    case temporaryCache = "暫存媒體"
    case explicitKeep = "明確保留"

    var id: String { rawValue }
}

enum XHSNoteContentType: String, CaseIterable, Codable, Identifiable {
    case video = "video"
    case imagePost = "imagePost"
    case carousel = "carousel"
    case livePhoto = "livePhoto"
    case unknown = "unknown"

    var id: String { rawValue }
}

enum XHSMediaAssetType: String, CaseIterable, Codable, Identifiable {
    case image = "image"
    case video = "video"
    case cover = "cover"
    case livePhoto = "livePhoto"
    case unknown = "unknown"

    var id: String { rawValue }
}

enum ResourceSyncJobType: String, CaseIterable, Codable, Identifiable {
    case importJob = "import"
    case reparse = "reparse"
    case recommendation = "recommendation"
    case mediaCleanup = "media_cleanup"

    var id: String { rawValue }
}


