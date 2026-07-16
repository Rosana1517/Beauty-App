import Foundation

extension ImportSourceType {
    var apiValue: String {
        switch self {
        case .xiaohongshu: return "xiaohongshu"
        case .youtube: return "youtube"
        case .instagram: return "instagram"
        case .web: return "web"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "xiaohongshu": self = .xiaohongshu
        case "youtube": self = .youtube
        case "instagram": self = .instagram
        case "web": self = .web
        default: return nil
        }
    }
}

extension ImportedContentType {
    var apiValue: String {
        switch self {
        case .video: return "video"
        case .imagePost: return "imagePost"
        case .carousel: return "carousel"
        case .article: return "article"
        case .unknown: return "unknown"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "video": self = .video
        case "imagePost": self = .imagePost
        case "carousel": self = .carousel
        case "article": self = .article
        case "unknown": self = .unknown
        default: return nil
        }
    }
}

extension ResourceCategory {
    var apiValue: String {
        switch self {
        case .all: return "other"
        case .skincare: return "skincare"
        case .fitness: return "fitness"
        case .food: return "food"
        case .outfit: return "outfit"
        case .learning: return "learning"
        case .other: return "other"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "skincare": self = .skincare
        case "fitness": self = .fitness
        case "food": self = .food
        case "outfit": self = .outfit
        case "learning": self = .learning
        case "other": self = .other
        default: return nil
        }
    }
}

extension ResourceImportStatus {
    var apiValue: String {
        switch self {
        case .parsed: return "parsed"
        case .partial: return "partial"
        case .manualCompleted: return "manualCompleted"
        case .failedFallbackSaved: return "failedFallbackSaved"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "parsed": self = .parsed
        case "partial": self = .partial
        case "manualCompleted": self = .manualCompleted
        case "failedFallbackSaved": self = .failedFallbackSaved
        default: return nil
        }
    }
}

extension ResourceAnalysisStatus {
    var apiValue: String {
        switch self {
        case .pending: return "pending"
        case .analyzing: return "analyzing"
        case .analyzed: return "analyzed"
        case .fallback: return "fallback"
        }
    }
}

extension ResourceSyncStatus {
    var apiValue: String {
        switch self {
        case .pending: return "pending"
        case .syncing: return "syncing"
        case .succeeded: return "succeeded"
        case .failed: return "failed"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "pending": self = .pending
        case "syncing": self = .syncing
        case "succeeded": self = .succeeded
        case "failed": self = .failed
        default: return nil
        }
    }
}

extension MediaRetentionPolicy {
    var apiValue: String {
        switch self {
        case .metadataOnly: return "metadataOnly"
        case .temporaryCache: return "temporaryCache"
        case .explicitKeep: return "explicitKeep"
        }
    }

    init?(apiValue: String?) {
        switch apiValue {
        case "metadataOnly":
            self = .metadataOnly
        case "temporaryCache":
            self = .temporaryCache
        case "explicitKeep":
            self = .explicitKeep
        default:
            return nil
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
