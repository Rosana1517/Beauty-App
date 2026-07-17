import Foundation

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
