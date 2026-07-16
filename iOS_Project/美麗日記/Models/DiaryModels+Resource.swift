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


struct ParsedMetadataPayload: Codable {
    var title: String
    var descriptionText: String
    var authorName: String
    var thumbnailURL: String
    var canonicalURL: String
    var externalID: String
    var publishedAt: Date?
    var platformContentType: ImportedContentType
    var tags: [String]
    var htmlTitle: String
    var pageHost: String
}

struct AIAnalysisResult: Codable {
    var summary: String
    var insights: [String]
    var recommendedActions: [String]
    var confidence: Double
    var provider: String
    var generatedAt: Date
}

struct ResourceRecommendationCard: Identifiable, Codable {
    var id: UUID
    var title: String
    var detail: String
    var category: ResourceCategory
    var reason: String
}

struct SourcePlatformCapability: Identifiable, Codable {
    var id: ImportSourceType { source }
    var source: ImportSourceType
    var supportsOfficialOAuth: Bool
    var supportsBackendReparse: Bool
    var authorizationState: PlatformAuthorizationState
    var note: String
}

struct XHSNoteIdentifier: Codable {
    var noteID: String
    var authorID: String
    var canonicalURL: String
    var shareURL: String
    var xsecToken: String
}

struct XHSAuthorProfile: Codable {
    var authorID: String
    var name: String
    var avatarURL: String
    var noteCountSummary: String
}

struct XHSMediaAsset: Identifiable, Codable {
    var id: UUID
    var assetID: String
    var type: XHSMediaAssetType
    var remoteURL: String
    var previewURL: String
    var width: Int?
    var height: Int?
    var duration: Double?
    var index: Int
    var retentionPolicy: MediaRetentionPolicy
    var localStoragePath: String?
    var checksum: String?
    var isSelectedForImport: Bool
    var expiresAt: Date?

    var displayURL: String {
        previewURL.isEmpty ? remoteURL : previewURL
    }
}

struct XHSParsedPayload: Codable {
    var identifier: XHSNoteIdentifier
    var title: String
    var description: String
    var author: XHSAuthorProfile
    var likeCount: Int?
    var tags: [String]
    var publishedAt: Date?
    var contentType: XHSNoteContentType
    var mediaAssets: [XHSMediaAsset]
    var commentsPreview: [String]
    var rawSnapshot: String
}

struct TemporaryMediaLease: Identifiable, Codable {
    var id: UUID
    var assetID: String
    var resourceID: UUID?
    var storagePath: String
    var retentionPolicy: MediaRetentionPolicy
    var expiresAt: Date
    var cleanedAt: Date?
    var cleanupStatus: ResourceSyncStatus
}

struct ResourceImportDraft: Identifiable, Codable {
    var id: UUID
    var source: ImportSourceType
    var category: ResourceCategory
    var platformContentType: ImportedContentType
    var title: String
    var canonicalURL: String
    var originalURL: String
    var externalID: String
    var authorName: String
    var thumbnailURL: String
    var publishedAt: Date?
    var descriptionText: String
    var tags: [String]
    var importStatus: ResourceImportStatus
    var metadataConfidence: Double
    var importedAt: Date?
    var rawMetadataSnapshot: String
    var mediaRetentionPolicy: MediaRetentionPolicy
    var mediaAssets: [XHSMediaAsset]
    var temporaryMediaLeases: [TemporaryMediaLease]
    var sourcePayloadSummary: XHSParsedPayload?
    var analysisStatus: ResourceAnalysisStatus
    var aiAnalysis: AIAnalysisResult?
    var recommendationCards: [ResourceRecommendationCard]
    var syncStatus: ResourceSyncStatus
    var remoteRecordID: String
    var lastSyncedAt: Date?
    var lastErrorMessage: String?

    var resolvedURL: String {
        canonicalURL.isEmpty ? originalURL : canonicalURL
    }

    var selectedMediaAssets: [XHSMediaAsset] {
        mediaAssets.filter(\.isSelectedForImport)
    }

    var missingFields: [String] {
        var fields: [String] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.append("標題")
        }
        if category == .all {
            fields.append("分類")
        }
        if source == .web && originalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.append("來源連結")
        }
        if !mediaAssets.isEmpty && selectedMediaAssets.isEmpty {
            fields.append("至少選擇一筆媒體")
        }
        return fields
    }

    var requiresManualCompletion: Bool {
        importStatus == .partial || !missingFields.isEmpty || metadataConfidence < 0.66
    }

    static func empty(url: String) -> ResourceImportDraft {
        let source = ImportSourceType.detectedSource(from: url)
        return ResourceImportDraft(
            id: UUID(),
            source: source,
            category: .all,
            platformContentType: .unknown,
            title: "",
            canonicalURL: "",
            originalURL: url,
            externalID: "",
            authorName: "",
            thumbnailURL: "",
            publishedAt: nil,
            descriptionText: "",
            tags: [],
            importStatus: .partial,
            metadataConfidence: 0,
            importedAt: nil,
            rawMetadataSnapshot: "",
            mediaRetentionPolicy: .metadataOnly,
            mediaAssets: [],
            temporaryMediaLeases: [],
            sourcePayloadSummary: nil,
            analysisStatus: .pending,
            aiAnalysis: nil,
            recommendationCards: [],
            syncStatus: .pending,
            remoteRecordID: "",
            lastSyncedAt: nil,
            lastErrorMessage: nil
        )
    }
}

struct ResourceImportHistoryEntry: Identifiable, Codable {
    var id: UUID
    var source: ImportSourceType
    var title: String
    var originalURL: String
    var status: ResourceImportStatus
    var importedAt: Date
    var note: String
}

struct ResourceItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var source: ImportSourceType
    var category: ResourceCategory
    var platformContentType: ImportedContentType
    var canonicalURL: String
    var originalURL: String
    var externalID: String
    var authorName: String
    var thumbnailURL: String
    var publishedAt: Date?
    var descriptionText: String
    var tags: [String]
    var importStatus: ResourceImportStatus
    var metadataConfidence: Double
    var importedAt: Date
    var rawMetadataSnapshot: String
    var mediaRetentionPolicy: MediaRetentionPolicy
    var mediaAssets: [XHSMediaAsset]
    var temporaryMediaLeases: [TemporaryMediaLease]
    var sourcePayloadSummary: XHSParsedPayload?
    var analysisStatus: ResourceAnalysisStatus
    var aiAnalysis: AIAnalysisResult?
    var recommendationCards: [ResourceRecommendationCard]
    var syncStatus: ResourceSyncStatus
    var remoteRecordID: String
    var lastSyncedAt: Date?

    var displaySummary: String {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? resolvedURL : descriptionText
    }

    var resolvedURL: String {
        canonicalURL.isEmpty ? originalURL : canonicalURL
    }

    var selectedMediaAssets: [XHSMediaAsset] {
        mediaAssets.filter(\.isSelectedForImport)
    }

    init(
        id: UUID = UUID(),
        title: String,
        source: ImportSourceType,
        category: ResourceCategory,
        platformContentType: ImportedContentType,
        canonicalURL: String,
        originalURL: String,
        externalID: String,
        authorName: String,
        thumbnailURL: String,
        publishedAt: Date?,
        descriptionText: String,
        tags: [String],
        importStatus: ResourceImportStatus,
        metadataConfidence: Double,
        importedAt: Date = Date(),
        rawMetadataSnapshot: String,
        mediaRetentionPolicy: MediaRetentionPolicy = .metadataOnly,
        mediaAssets: [XHSMediaAsset] = [],
        temporaryMediaLeases: [TemporaryMediaLease] = [],
        sourcePayloadSummary: XHSParsedPayload? = nil,
        analysisStatus: ResourceAnalysisStatus = .pending,
        aiAnalysis: AIAnalysisResult? = nil,
        recommendationCards: [ResourceRecommendationCard] = [],
        syncStatus: ResourceSyncStatus = .pending,
        remoteRecordID: String = "",
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.category = category
        self.platformContentType = platformContentType
        self.canonicalURL = canonicalURL
        self.originalURL = originalURL
        self.externalID = externalID
        self.authorName = authorName
        self.thumbnailURL = thumbnailURL
        self.publishedAt = publishedAt
        self.descriptionText = descriptionText
        self.tags = tags
        self.importStatus = importStatus
        self.metadataConfidence = metadataConfidence
        self.importedAt = importedAt
        self.rawMetadataSnapshot = rawMetadataSnapshot
        self.mediaRetentionPolicy = mediaRetentionPolicy
        self.mediaAssets = mediaAssets
        self.temporaryMediaLeases = temporaryMediaLeases
        self.sourcePayloadSummary = sourcePayloadSummary
        self.analysisStatus = analysisStatus
        self.aiAnalysis = aiAnalysis
        self.recommendationCards = recommendationCards
        self.syncStatus = syncStatus
        self.remoteRecordID = remoteRecordID
        self.lastSyncedAt = lastSyncedAt
    }

    init(from draft: ResourceImportDraft) {
        self.init(
            title: draft.title,
            source: draft.source,
            category: draft.category == .all ? .other : draft.category,
            platformContentType: draft.platformContentType,
            canonicalURL: draft.canonicalURL,
            originalURL: draft.originalURL,
            externalID: draft.externalID,
            authorName: draft.authorName,
            thumbnailURL: draft.thumbnailURL,
            publishedAt: draft.publishedAt,
            descriptionText: draft.descriptionText,
            tags: draft.tags,
            importStatus: draft.importStatus,
            metadataConfidence: draft.metadataConfidence,
            importedAt: draft.importedAt ?? Date(),
            rawMetadataSnapshot: draft.rawMetadataSnapshot,
            mediaRetentionPolicy: draft.mediaRetentionPolicy,
            mediaAssets: draft.selectedMediaAssets,
            temporaryMediaLeases: draft.temporaryMediaLeases,
            sourcePayloadSummary: draft.sourcePayloadSummary,
            analysisStatus: draft.analysisStatus,
            aiAnalysis: draft.aiAnalysis,
            recommendationCards: draft.recommendationCards,
            syncStatus: draft.syncStatus,
            remoteRecordID: draft.remoteRecordID,
            lastSyncedAt: draft.lastSyncedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case source
        case category
        case platformContentType
        case canonicalURL
        case originalURL
        case externalID
        case authorName
        case thumbnailURL
        case publishedAt
        case descriptionText
        case tags
        case importStatus
        case metadataConfidence
        case importedAt
        case rawMetadataSnapshot
        case mediaRetentionPolicy
        case mediaAssets
        case temporaryMediaLeases
        case sourcePayloadSummary
        case analysisStatus
        case aiAnalysis
        case recommendationCards
        case syncStatus
        case remoteRecordID
        case lastSyncedAt
        case url
        case summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        source = try container.decodeIfPresent(ImportSourceType.self, forKey: .source) ?? .web
        category = try container.decodeIfPresent(ResourceCategory.self, forKey: .category) ?? .other
        platformContentType = try container.decodeIfPresent(ImportedContentType.self, forKey: .platformContentType) ?? .unknown

        let legacyURL = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        canonicalURL = try container.decodeIfPresent(String.self, forKey: .canonicalURL) ?? legacyURL
        originalURL = try container.decodeIfPresent(String.self, forKey: .originalURL) ?? legacyURL
        externalID = try container.decodeIfPresent(String.self, forKey: .externalID) ?? ""
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName) ?? ""
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL) ?? ""
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)

        let legacySummary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        descriptionText = try container.decodeIfPresent(String.self, forKey: .descriptionText) ?? legacySummary
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        importStatus = try container.decodeIfPresent(ResourceImportStatus.self, forKey: .importStatus) ?? .manualCompleted
        metadataConfidence = try container.decodeIfPresent(Double.self, forKey: .metadataConfidence) ?? 0.4
        importedAt = try container.decodeIfPresent(Date.self, forKey: .importedAt) ?? Date()
        rawMetadataSnapshot = try container.decodeIfPresent(String.self, forKey: .rawMetadataSnapshot) ?? ""
        mediaRetentionPolicy = try container.decodeIfPresent(MediaRetentionPolicy.self, forKey: .mediaRetentionPolicy) ?? .metadataOnly
        mediaAssets = try container.decodeIfPresent([XHSMediaAsset].self, forKey: .mediaAssets) ?? []
        temporaryMediaLeases = try container.decodeIfPresent([TemporaryMediaLease].self, forKey: .temporaryMediaLeases) ?? []
        sourcePayloadSummary = try container.decodeIfPresent(XHSParsedPayload.self, forKey: .sourcePayloadSummary)
        analysisStatus = try container.decodeIfPresent(ResourceAnalysisStatus.self, forKey: .analysisStatus) ?? .pending
        aiAnalysis = try container.decodeIfPresent(AIAnalysisResult.self, forKey: .aiAnalysis)
        recommendationCards = try container.decodeIfPresent([ResourceRecommendationCard].self, forKey: .recommendationCards) ?? []
        syncStatus = try container.decodeIfPresent(ResourceSyncStatus.self, forKey: .syncStatus) ?? .pending
        remoteRecordID = try container.decodeIfPresent(String.self, forKey: .remoteRecordID) ?? ""
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(source, forKey: .source)
        try container.encode(category, forKey: .category)
        try container.encode(platformContentType, forKey: .platformContentType)
        try container.encode(canonicalURL, forKey: .canonicalURL)
        try container.encode(originalURL, forKey: .originalURL)
        try container.encode(externalID, forKey: .externalID)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(thumbnailURL, forKey: .thumbnailURL)
        try container.encodeIfPresent(publishedAt, forKey: .publishedAt)
        try container.encode(descriptionText, forKey: .descriptionText)
        try container.encode(tags, forKey: .tags)
        try container.encode(importStatus, forKey: .importStatus)
        try container.encode(metadataConfidence, forKey: .metadataConfidence)
        try container.encode(importedAt, forKey: .importedAt)
        try container.encode(rawMetadataSnapshot, forKey: .rawMetadataSnapshot)
        try container.encode(mediaRetentionPolicy, forKey: .mediaRetentionPolicy)
        try container.encode(mediaAssets, forKey: .mediaAssets)
        try container.encode(temporaryMediaLeases, forKey: .temporaryMediaLeases)
        try container.encodeIfPresent(sourcePayloadSummary, forKey: .sourcePayloadSummary)
        try container.encode(analysisStatus, forKey: .analysisStatus)
        try container.encodeIfPresent(aiAnalysis, forKey: .aiAnalysis)
        try container.encode(recommendationCards, forKey: .recommendationCards)
        try container.encode(syncStatus, forKey: .syncStatus)
        try container.encode(remoteRecordID, forKey: .remoteRecordID)
        try container.encodeIfPresent(lastSyncedAt, forKey: .lastSyncedAt)
    }
}

struct ResourceSyncQueueItem: Identifiable, Codable {
    var id: UUID
    var resourceID: UUID
    var jobType: ResourceSyncJobType
    var syncTarget: String
    var syncStatus: ResourceSyncStatus
    var retryCount: Int
    var requestPayload: String
    var lastErrorMessage: String?
    var createdAt: Date
    var updatedAt: Date
}


