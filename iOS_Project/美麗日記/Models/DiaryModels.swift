import Foundation

enum TabRoute: String, CaseIterable, Codable, Identifiable {
    case home = "首頁"
    case beauty = "變美"
    case body = "體態"
    case growth = "成長"
    case profile = "我的"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .beauty:
            return "sparkles"
        case .body:
            return "figure.strengthtraining.traditional"
        case .growth:
            return "book.closed"
        case .profile:
            return "person"
        }
    }
}

enum AppRoute: Hashable, Codable {
    case home
    case beauty(BeautyRoute)
    case body(BodyRoute)
    case growth(GrowthRoute)
    case profile(ProfileRoute)
}

enum BeautyRoute: String, Hashable, Codable, CaseIterable, Identifiable {
    case skincare = "護膚管理"
    case hairCare = "頭髮保養"
    case whitening = "美白計畫"
    case faceLift = "面部拉提/瑜珈"
    case hairstyleMatch = "髮型臉型適配"
    case bodySkincare = "身體皮膚保養"
    case productLibrary = "產品管理庫"
    case appointments = "美容預約"
    case makeupInspiration = "妝容靈感"

    var id: String { rawValue }
}

enum SkincareSection: String, CaseIterable, Codable, Identifiable {
    case steps = "護膚步驟"
    case products = "保養品"
    case tracking = "膚質追蹤"
    case tutorials = "教程連結"
    case history = "打卡歷史"
    case advice = "AI建議"

    var id: String { rawValue }
}

enum BodyRoute: String, Hashable, Codable, CaseIterable, Identifiable {
    case exercise = "運動管理"
    case shaping = "塑型計畫"
    case metrics = "體重體脂"
    case meals = "飲食記錄"
    case wellness = "養生健康"
    case album = "體態相簿"

    var id: String { rawValue }
}

enum GrowthRoute: String, Hashable, Codable, CaseIterable, Identifiable {
    case reading = "閱讀追蹤"
    case notes = "成長筆記"
    case plan = "本週成長"

    var id: String { rawValue }
}

enum ProfileRoute: String, Hashable, Codable, CaseIterable, Identifiable {
    case settings = "個人設定"
    case customization = "客製化"
    case resources = "資源庫"
    case achievements = "成就徽章"
    case export = "數據匯出"

    var id: String { rawValue }
}

enum AIAdviceTopic: String, Codable {
    case skincare
    case hair
    case facialLift
    case bodySkin
    case diet
    case makeup
}

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

struct UserProfileRecord: Codable, Equatable {
    var nickname: String
    var streakDays: Int
    var signature: String
    var bodyFocus: String
    var skincareFocus: String
    var themeName: String
    var notificationTime: String
}

enum AIProviderKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case openai
    case anthropic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }
}

/// Each signed-in user can bring their own AI provider key instead of
/// relying on a single key shared across every installation. This is
/// synced to the user's own row in `user_ai_provider_settings` (RLS-scoped
/// to that user) so the key never needs to live in app code or a shared
/// backend secret.
struct AIProviderSettings: Codable, Equatable {
    var provider: AIProviderKind
    var apiKey: String
    var baseURL: String
    var model: String

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let empty = AIProviderSettings(provider: .openai, apiKey: "", baseURL: "", model: "")
}

struct ChecklistItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var category: String
    var isCompleted: Bool
}

struct RoutineStep: Identifiable, Codable {
    var id: UUID
    var period: RoutinePeriod
    var name: String
    var productName: String?
    var isChecked: Bool
}

struct SkincareRoutine: Codable {
    var steps: [RoutineStep]
}

struct Product: Identifiable, Codable {
    var id: UUID
    var name: String
    var brand: String
    var category: String
    var notes: String
}

struct SkinRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var skinType: String
    var concerns: [String]
    var note: String
}

struct HairCareRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var careType: String
    var note: String
}

struct BodySkinRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var area: String
    var concern: String
    var note: String
}

struct WhiteningProductUsage: Identifiable, Codable {
    var id: UUID
    var date: Date
    var productName: String
    var note: String
}

struct ShadeTrackingRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var shadeName: String
    var note: String
}

struct BeforeAfterPhotoPair: Identifiable, Codable {
    var id: UUID
    var date: Date
    var beforeImageData: Data?
    var afterImageData: Data?
    var note: String
}

struct FaceLiftAction: Identifiable, Codable {
    var id: UUID
    var name: String
}

struct FaceLiftPunchRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
}

struct FaceLiftRatingRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var score: Int
    var note: String
}

struct BodyMetricRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var weight: Double
    var bodyFat: Double
    var note: String
}

struct MealRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var mealType: String
    var summary: String
    var note: String
}

struct Appointment: Identifiable, Codable {
    var id: UUID
    var title: String
    var storeName: String
    var date: Date
    var note: String
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

struct BookRecord: Identifiable, Codable {
    var id: UUID
    var title: String
    var author: String
    var link: String
    var note: String
}

struct TutorialLink: Identifiable, Codable {
    var id: UUID
    var title: String
    var url: String
}

struct PunchRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var summary: String
}

struct AchievementBadge: Identifiable, Codable {
    var id: UUID
    var title: String
    var detail: String
    var unlocked: Bool
}

struct ExportRecord: Identifiable, Codable {
    var id: UUID
    var format: ExportFormat
    var createdAt: Date
    var summary: String
}

struct BeautyDiaryState: Codable {
    var profile: UserProfileRecord
    var checklistItems: [ChecklistItem]
    var routine: SkincareRoutine
    var products: [Product]
    var skinRecords: [SkinRecord]
    var bodyMetricRecords: [BodyMetricRecord]
    var mealRecords: [MealRecord]
    var appointments: [Appointment]
    var resourceItems: [ResourceItem]
    var bookRecords: [BookRecord]
    var tutorialLinks: [TutorialLink]
    var punchRecords: [PunchRecord]
    var achievements: [AchievementBadge]
    var exportHistory: [ExportRecord]
    var resourceFilter: ResourceCategory
    var resourceImportHistory: [ResourceImportHistoryEntry]
    var pendingImportDraft: ResourceImportDraft?
    var resourceSyncQueue: [ResourceSyncQueueItem]
    var aiProviderSettings: AIProviderSettings?
    var hairCareRecords: [HairCareRecord]
    var bodySkinRecords: [BodySkinRecord]
    var faceLiftActions: [FaceLiftAction]
    var faceLiftPunches: [FaceLiftPunchRecord]
    var faceLiftRatings: [FaceLiftRatingRecord]
    var bodyProducts: [Product]
    var hairProducts: [Product]
    var hairAppointments: [Appointment]
    var washFrequencyDays: Int
    var careFrequencyDays: Int
    var whiteningProductUsages: [WhiteningProductUsage]
    var shadeTrackingRecords: [ShadeTrackingRecord]
    var beforeAfterPhotos: [BeforeAfterPhotoPair]

    private enum CodingKeys: String, CodingKey {
        case profile
        case checklistItems
        case routine
        case products
        case skinRecords
        case bodyMetricRecords
        case mealRecords
        case appointments
        case resourceItems
        case bookRecords
        case tutorialLinks
        case punchRecords
        case achievements
        case exportHistory
        case resourceFilter
        case resourceImportHistory
        case pendingImportDraft
        case resourceSyncQueue
        case aiProviderSettings
        case hairCareRecords
        case bodySkinRecords
        case faceLiftActions
        case faceLiftPunches
        case faceLiftRatings
        case bodyProducts
        case hairProducts
        case hairAppointments
        case washFrequencyDays
        case careFrequencyDays
        case whiteningProductUsages
        case shadeTrackingRecords
        case beforeAfterPhotos
    }

    init(
        profile: UserProfileRecord,
        checklistItems: [ChecklistItem],
        routine: SkincareRoutine,
        products: [Product],
        skinRecords: [SkinRecord],
        bodyMetricRecords: [BodyMetricRecord],
        mealRecords: [MealRecord],
        appointments: [Appointment],
        resourceItems: [ResourceItem],
        bookRecords: [BookRecord],
        tutorialLinks: [TutorialLink],
        punchRecords: [PunchRecord],
        achievements: [AchievementBadge],
        exportHistory: [ExportRecord],
        resourceFilter: ResourceCategory,
        resourceImportHistory: [ResourceImportHistoryEntry],
        pendingImportDraft: ResourceImportDraft?,
        resourceSyncQueue: [ResourceSyncQueueItem],
        aiProviderSettings: AIProviderSettings? = nil,
        hairCareRecords: [HairCareRecord] = [],
        bodySkinRecords: [BodySkinRecord] = [],
        faceLiftActions: [FaceLiftAction] = [],
        faceLiftPunches: [FaceLiftPunchRecord] = [],
        faceLiftRatings: [FaceLiftRatingRecord] = [],
        bodyProducts: [Product] = [],
        hairProducts: [Product] = [],
        hairAppointments: [Appointment] = [],
        washFrequencyDays: Int = 2,
        careFrequencyDays: Int = 7,
        whiteningProductUsages: [WhiteningProductUsage] = [],
        shadeTrackingRecords: [ShadeTrackingRecord] = [],
        beforeAfterPhotos: [BeforeAfterPhotoPair] = []
    ) {
        self.profile = profile
        self.checklistItems = checklistItems
        self.routine = routine
        self.products = products
        self.skinRecords = skinRecords
        self.bodyMetricRecords = bodyMetricRecords
        self.mealRecords = mealRecords
        self.appointments = appointments
        self.resourceItems = resourceItems
        self.bookRecords = bookRecords
        self.tutorialLinks = tutorialLinks
        self.punchRecords = punchRecords
        self.achievements = achievements
        self.exportHistory = exportHistory
        self.resourceFilter = resourceFilter
        self.resourceImportHistory = resourceImportHistory
        self.pendingImportDraft = pendingImportDraft
        self.resourceSyncQueue = resourceSyncQueue
        self.aiProviderSettings = aiProviderSettings
        self.hairCareRecords = hairCareRecords
        self.bodySkinRecords = bodySkinRecords
        self.faceLiftActions = faceLiftActions
        self.faceLiftPunches = faceLiftPunches
        self.faceLiftRatings = faceLiftRatings
        self.bodyProducts = bodyProducts
        self.hairProducts = hairProducts
        self.hairAppointments = hairAppointments
        self.washFrequencyDays = washFrequencyDays
        self.careFrequencyDays = careFrequencyDays
        self.whiteningProductUsages = whiteningProductUsages
        self.shadeTrackingRecords = shadeTrackingRecords
        self.beforeAfterPhotos = beforeAfterPhotos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(UserProfileRecord.self, forKey: .profile)
        checklistItems = try container.decode([ChecklistItem].self, forKey: .checklistItems)
        routine = try container.decode(SkincareRoutine.self, forKey: .routine)
        products = try container.decodeIfPresent([Product].self, forKey: .products) ?? []
        skinRecords = try container.decodeIfPresent([SkinRecord].self, forKey: .skinRecords) ?? []
        bodyMetricRecords = try container.decodeIfPresent([BodyMetricRecord].self, forKey: .bodyMetricRecords) ?? []
        mealRecords = try container.decodeIfPresent([MealRecord].self, forKey: .mealRecords) ?? []
        appointments = try container.decodeIfPresent([Appointment].self, forKey: .appointments) ?? []
        resourceItems = try container.decodeIfPresent([ResourceItem].self, forKey: .resourceItems) ?? []
        bookRecords = try container.decodeIfPresent([BookRecord].self, forKey: .bookRecords) ?? []
        tutorialLinks = try container.decodeIfPresent([TutorialLink].self, forKey: .tutorialLinks) ?? []
        punchRecords = try container.decodeIfPresent([PunchRecord].self, forKey: .punchRecords) ?? []
        achievements = try container.decodeIfPresent([AchievementBadge].self, forKey: .achievements) ?? []
        exportHistory = try container.decodeIfPresent([ExportRecord].self, forKey: .exportHistory) ?? []
        resourceFilter = try container.decodeIfPresent(ResourceCategory.self, forKey: .resourceFilter) ?? .all
        resourceImportHistory = try container.decodeIfPresent([ResourceImportHistoryEntry].self, forKey: .resourceImportHistory) ?? []
        pendingImportDraft = try container.decodeIfPresent(ResourceImportDraft.self, forKey: .pendingImportDraft)
        resourceSyncQueue = try container.decodeIfPresent([ResourceSyncQueueItem].self, forKey: .resourceSyncQueue) ?? []
        aiProviderSettings = try container.decodeIfPresent(AIProviderSettings.self, forKey: .aiProviderSettings)
        hairCareRecords = try container.decodeIfPresent([HairCareRecord].self, forKey: .hairCareRecords) ?? []
        bodySkinRecords = try container.decodeIfPresent([BodySkinRecord].self, forKey: .bodySkinRecords) ?? []
        faceLiftActions = try container.decodeIfPresent([FaceLiftAction].self, forKey: .faceLiftActions) ?? []
        faceLiftPunches = try container.decodeIfPresent([FaceLiftPunchRecord].self, forKey: .faceLiftPunches) ?? []
        faceLiftRatings = try container.decodeIfPresent([FaceLiftRatingRecord].self, forKey: .faceLiftRatings) ?? []
        bodyProducts = try container.decodeIfPresent([Product].self, forKey: .bodyProducts) ?? []
        hairProducts = try container.decodeIfPresent([Product].self, forKey: .hairProducts) ?? []
        hairAppointments = try container.decodeIfPresent([Appointment].self, forKey: .hairAppointments) ?? []
        washFrequencyDays = try container.decodeIfPresent(Int.self, forKey: .washFrequencyDays) ?? 2
        careFrequencyDays = try container.decodeIfPresent(Int.self, forKey: .careFrequencyDays) ?? 7
        whiteningProductUsages = try container.decodeIfPresent([WhiteningProductUsage].self, forKey: .whiteningProductUsages) ?? []
        shadeTrackingRecords = try container.decodeIfPresent([ShadeTrackingRecord].self, forKey: .shadeTrackingRecords) ?? []
        beforeAfterPhotos = try container.decodeIfPresent([BeforeAfterPhotoPair].self, forKey: .beforeAfterPhotos) ?? []
    }
}

extension BeautyDiaryState {
    static let seed = BeautyDiaryState(
        profile: UserProfileRecord(
            nickname: "精緻女孩",
            streakDays: 1,
            signature: "設定、成就、資源、數據管理",
            bodyFocus: "全身 / 局部訓練追蹤",
            skincareFocus: "混合肌保養與膚況記錄",
            themeName: "暖米白",
            notificationTime: "21:00"
        ),
        checklistItems: [
            ChecklistItem(id: UUID(), title: "晨間護膚", category: "變美", isCompleted: false),
            ChecklistItem(id: UUID(), title: "體態紀錄", category: "體態", isCompleted: false),
            ChecklistItem(id: UUID(), title: "閱讀打卡", category: "成長", isCompleted: false),
            ChecklistItem(id: UUID(), title: "飲食回顧", category: "體態", isCompleted: false)
        ],
        routine: SkincareRoutine(
            steps: [
                RoutineStep(id: UUID(), period: .morning, name: "清潔", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .morning, name: "化妝水", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .morning, name: "精華液", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .morning, name: "眼霜", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .morning, name: "乳液/面霜", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .morning, name: "防曬", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "卸妝", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "清潔", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "化妝水", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "精華液", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "眼霜", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "乳液/面霜", productName: nil, isChecked: false)
            ]
        ),
        products: [],
        skinRecords: [],
        bodyMetricRecords: [],
        mealRecords: [],
        appointments: [],
        resourceItems: [],
        bookRecords: [],
        tutorialLinks: [
            TutorialLink(id: UUID(), title: "敏感肌晚間修護流程", url: "https://example.com/skincare-night"),
            TutorialLink(id: UUID(), title: "新手保養品疊擦順序", url: "https://example.com/product-order")
        ],
        punchRecords: [],
        achievements: [
            AchievementBadge(id: UUID(), title: "連續打卡王", detail: "連續打卡 7 天", unlocked: false),
            AchievementBadge(id: UUID(), title: "資源收藏家", detail: "新增 10 筆資源", unlocked: false),
            AchievementBadge(id: UUID(), title: "護膚紀錄員", detail: "完成 5 次膚況紀錄", unlocked: false)
        ],
        exportHistory: [],
        resourceFilter: .all,
        resourceImportHistory: [],
        pendingImportDraft: nil,
        resourceSyncQueue: [],
        hairCareRecords: [],
        bodySkinRecords: [],
        faceLiftActions: [],
        faceLiftPunches: [],
        faceLiftRatings: [],
        bodyProducts: [],
        hairProducts: [],
        hairAppointments: [],
        washFrequencyDays: 2,
        careFrequencyDays: 7,
        whiteningProductUsages: [],
        shadeTrackingRecords: [],
        beforeAfterPhotos: []
    )
}
