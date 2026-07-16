import Foundation

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


