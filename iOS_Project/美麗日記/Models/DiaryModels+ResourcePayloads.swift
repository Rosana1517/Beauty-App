import Foundation

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

