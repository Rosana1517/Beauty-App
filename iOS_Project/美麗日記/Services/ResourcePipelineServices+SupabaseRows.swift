import Foundation

struct SupabaseResourcePayload: Encodable {
    let id: String?
    let userID: String?
    let sourceType: String
    let contentType: String
    let category: String
    let title: String
    let descriptionText: String
    let authorName: String
    let originalURL: String
    let canonicalURL: String
    let externalID: String
    let thumbnailURL: String
    let publishedAt: Date?
    let tags: [String]
    let importStatus: String
    let metadataConfidence: Double
    let mediaRetentionPolicy: String
    let rawMetadataSnapshot: JSONValue
    let sourcePayload: JSONValue

    init(item: ResourceItem, userID: String) {
        id = item.remoteRecordID.nilIfEmpty
        self.userID = userID.nilIfEmpty
        sourceType = item.source.apiValue
        contentType = item.platformContentType.apiValue
        category = item.category.apiValue
        title = item.title
        descriptionText = item.descriptionText
        authorName = item.authorName
        originalURL = item.originalURL
        canonicalURL = item.canonicalURL
        externalID = item.externalID
        thumbnailURL = item.thumbnailURL
        publishedAt = item.publishedAt
        tags = item.tags
        importStatus = item.importStatus.apiValue
        metadataConfidence = item.metadataConfidence
        mediaRetentionPolicy = item.mediaRetentionPolicy.apiValue
        rawMetadataSnapshot = JSONValue.jsonString(item.rawMetadataSnapshot)
        sourcePayload = JSONValue.dictionary([
            "analysisStatus": .string(item.analysisStatus.apiValue),
            "mediaAssets": .array(item.selectedMediaAssets.map { asset in
                .dictionary([
                    "assetID": .string(asset.assetID),
                    "type": .string(asset.type.rawValue),
                    "remoteURL": .string(asset.remoteURL),
                    "previewURL": .string(asset.previewURL),
                    "retentionPolicy": .string(asset.retentionPolicy.apiValue)
                ])
            }),
            "recommendationCount": .number(Double(item.recommendationCards.count)),
            "syncStatus": .string(item.syncStatus.apiValue)
        ])
    }
}

struct SupabaseAppUserPayload: Encodable {
    let id: String
    let email: String?
    let nickname: String?
    let streakDays: Int
    let signature: String?
    let bodyFocus: String?
    let skincareFocus: String?
    let themeName: String?
    let notificationTime: String?

    init(session: SupabaseAuthSession, profile: UserProfileRecord) {
        id = session.userID
        email = session.email.nilIfEmpty
        nickname = profile.nickname.nilIfEmpty
        streakDays = profile.streakDays
        signature = profile.signature.nilIfEmpty
        bodyFocus = profile.bodyFocus.nilIfEmpty
        skincareFocus = profile.skincareFocus.nilIfEmpty
        themeName = profile.themeName.nilIfEmpty
        notificationTime = profile.notificationTime.nilIfEmpty
    }
}

struct SupabaseImportEventPayload: Encodable {
    let resourceID: String?
    let userID: String?
    let sourceType: String
    let requestURL: String
    let resolvedURL: String
    let importerVersion: String
    let status: String
    let errorMessage: String?
    let parserMode: String
    let responseSnapshot: JSONValue

    init(item: ResourceItem, remoteRecordID: String?, userID: String) {
        resourceID = (remoteRecordID ?? item.remoteRecordID).nilIfEmpty
        self.userID = userID.nilIfEmpty
        sourceType = item.source.apiValue
        requestURL = item.originalURL
        resolvedURL = item.resolvedURL
        importerVersion = "v2"
        status = item.importStatus.apiValue
        errorMessage = item.aiAnalysis?.summary
        parserMode = item.source == .youtube ? "youtubeDataAPI" : "manualFallback"
        responseSnapshot = JSONValue.jsonString(item.rawMetadataSnapshot)
    }
}

struct SupabaseResourceRow: Decodable {
    let id: String
    let userID: String?
    let sourceType: String
    let contentType: String
    let category: String
    let title: String
    let descriptionText: String?
    let authorName: String?
    let originalURL: String
    let canonicalURL: String?
    let externalID: String?
    let thumbnailURL: String?
    let publishedAt: Date?
    let tags: [String]?
    let importStatus: String
    let metadataConfidence: Double?
    let mediaRetentionPolicy: String?
    let rawMetadataSnapshot: JSONValue?
    let createdAt: Date?
    let updatedAt: Date?

    // decoder 的 convertFromSnakeCase 會把 original_url 轉成 originalUrl（小寫 l），
    // 與本結構的 URL/ID 大寫命名不符，必須用 CodingKeys 對回轉換後的鍵名，
    // 否則非 optional 的 originalURL 會讓整批資源解碼失敗。
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case sourceType
        case contentType
        case category
        case title
        case descriptionText
        case authorName
        case originalURL = "originalUrl"
        case canonicalURL = "canonicalUrl"
        case externalID = "externalId"
        case thumbnailURL = "thumbnailUrl"
        case publishedAt
        case tags
        case importStatus
        case metadataConfidence
        case mediaRetentionPolicy
        case rawMetadataSnapshot
        case createdAt
        case updatedAt
    }

    var resourceItem: ResourceItem {
        ResourceItem(
            id: UUID(),
            title: title,
            source: ImportSourceType(apiValue: sourceType) ?? .web,
            category: ResourceCategory(apiValue: category) ?? .other,
            platformContentType: ImportedContentType(apiValue: contentType) ?? .unknown,
            canonicalURL: canonicalURL ?? "",
            originalURL: originalURL,
            externalID: externalID ?? "",
            authorName: authorName ?? "",
            thumbnailURL: thumbnailURL ?? "",
            publishedAt: publishedAt,
            descriptionText: descriptionText ?? "",
            tags: tags ?? [],
            importStatus: ResourceImportStatus(apiValue: importStatus) ?? .partial,
            metadataConfidence: metadataConfidence ?? 0,
            importedAt: createdAt ?? Date(),
            rawMetadataSnapshot: rawMetadataSnapshot?.stringValue ?? "",
            mediaRetentionPolicy: MediaRetentionPolicy(apiValue: mediaRetentionPolicy) ?? .metadataOnly,
            analysisStatus: .pending,
            aiAnalysis: nil,
            recommendationCards: [],
            syncStatus: .succeeded,
            remoteRecordID: id,
            lastSyncedAt: updatedAt
        )
    }
}

struct SupabaseImportEventRow: Decodable {
    let id: String
}

struct SupabaseMediaAssetRow: Decodable {
    let id: String
    let resourceID: String
    let assetID: String?
    let assetType: String
    let remoteURL: String
    let previewURL: String?
    let displayIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case resourceID = "resourceId"
        case assetID = "assetId"
        case assetType
        case remoteURL = "remoteUrl"
        case previewURL = "previewUrl"
        case displayIndex
    }

    var mediaAsset: XHSMediaAsset {
        XHSMediaAsset(
            id: UUID(uuidString: id) ?? UUID(),
            assetID: assetID ?? "",
            type: XHSMediaAssetType(rawValue: assetType) ?? .image,
            remoteURL: remoteURL,
            previewURL: previewURL ?? remoteURL,
            width: nil,
            height: nil,
            duration: nil,
            index: displayIndex ?? 0,
            retentionPolicy: .explicitKeep,
            localStoragePath: nil,
            checksum: nil,
            isSelectedForImport: true,
            expiresAt: nil
        )
    }
}
