import Foundation

struct SupabaseRESTErrorResponse: Decodable {
    let message: String?
    let hint: String?
    let error: String?
}

struct AuthorizedImportRequest: Encodable {
    let source: String
    let url: String
    let downloadPolicy: String
    let selectedIndexes: [Int]?
    let needComments: Bool
}

struct AuthorizedImportResponse: Decodable {
    let draft: ResourceImportDraft
    let xhsPayload: XHSParsedPayload?
}

struct ReparseJobRequest: Encodable {
    let resourceID: String
    let reason: String
}

struct MediaCleanupJobRequest: Encodable {
    let resourceID: String
    let retentionPolicy: String
}

struct RecommendationFunctionRequest: Encodable {
    let resourceID: String
}

struct RecommendationFunctionResponse: Decodable {
    let cards: [ResourceRecommendationCard]
}

struct AIAdviceFunctionRequest: Encodable {
    let topic: String
    let concerns: [String]
}

struct VideoTranscribeFunctionRequest: Encodable {
    let resourceID: String
    let videoURL: String

    // 明確指定 CodingKeys，不依賴 JSONEncoder.convertToSnakeCase 對
    // "resourceID"/"videoURL" 這類尾端縮寫大寫字母的轉換結果。
    enum CodingKeys: String, CodingKey {
        case resourceID = "resource_id"
        case videoURL = "video_url"
    }
}

struct AIAdviceFunctionResponse: Decodable {
    let suggestions: [String]
    let routineSteps: [String]?
    let products: [String]?
    let relatedResources: [AIAdviceRelatedResource]?
}

/// AI 建議附帶的資料庫筆記推薦（可加入運動管理、跳轉教學內容）
struct AIAdviceRelatedResource: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let category: String
    let author: String
    let thumbnailURL: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case author
        // convertFromSnakeCase 會把 thumbnail_url 轉成 thumbnailUrl
        case thumbnailURL = "thumbnailUrl"
    }
}

struct ProductLookupFunctionRequest: Encodable {
    let name: String?
    let imageBase64: String?

    // convertToSnakeCase 會把 "imageBase64" 轉成 "image_base64"，但 Edge Function
    // 讀的是駝峰 "imageBase64"；明確指定避免照片辨識路徑一直悄悄失敗。
    enum CodingKeys: String, CodingKey {
        case name
        case imageBase64
    }
}

struct ProductLookupFunctionResponse: Decodable {
    let name: String
    let brand: String?
    let category: String?
    let notes: String?
}

struct DietAnalyzeFunctionRequest: Encodable {
    let text: String?
    let imageBase64: String?

    // 同 ProductLookupFunctionRequest：避免 convertToSnakeCase 把 imageBase64
    // 轉成 image_base64 導致與 Edge Function 讀取的駝峰欄位對不上。
    enum CodingKeys: String, CodingKey {
        case text
        case imageBase64
    }
}

struct DietAnalyzeFunctionResponse: Decodable {
    let foodName: String
    let estimatedCalories: Int
    let notes: String?
}

struct SupabaseQueueJobResponse: Decodable {
    let id: String
    let syncStatus: String
    let retryCount: Int
    let lastError: String?
    let createdAt: Date?
    let updatedAt: Date?
}

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

struct SupabaseAppUserRow: Decodable {
    let id: String
    let email: String?
    let nickname: String?
    let streakDays: Int?
    let signature: String?
    let bodyFocus: String?
    let skincareFocus: String?
    let themeName: String?
    let notificationTime: String?

    var profile: UserProfileRecord {
        UserProfileRecord(
            nickname: nickname ?? "",
            streakDays: streakDays ?? 0,
            signature: signature ?? "",
            bodyFocus: bodyFocus ?? "",
            skincareFocus: skincareFocus ?? "",
            themeName: themeName ?? "",
            notificationTime: notificationTime ?? ""
        )
    }
}

struct SupabaseAIProviderSettingsPayload: Encodable {
    let userID: String
    let provider: String
    let apiKey: String
    let baseURL: String?
    let model: String?

    init(userID: String, settings: AIProviderSettings) {
        self.userID = userID
        provider = settings.provider.rawValue
        apiKey = settings.apiKey
        baseURL = settings.baseURL.nilIfEmpty
        model = settings.model.nilIfEmpty
    }
}

struct SupabaseAIProviderSettingsRow: Decodable {
    // `user_id` is intentionally omitted: JSONDecoder's `.convertFromSnakeCase`
    // can't reconstruct the "ID" acronym (it produces "userId", not "userID"),
    // and the field isn't needed here since the query already filters by
    // user_id.
    let provider: String
    let apiKey: String
    let baseURL: String?
    let model: String?

    var settings: AIProviderSettings {
        AIProviderSettings(
            provider: AIProviderKind(rawValue: provider) ?? .openai,
            apiKey: apiKey,
            baseURL: baseURL ?? "",
            model: model ?? ""
        )
    }
}

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case dictionary([String: JSONValue])
    case array([JSONValue])
    case null

    static func jsonString(_ value: String) -> JSONValue {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return .string(value)
        }
        return JSONValue.from(any: object)
    }

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .dictionary(let value):
            let object = value.mapValues(\.foundationObject)
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
                  let string = String(data: data, encoding: .utf8) else {
                return ""
            }
            return string
        case .array(let value):
            let object = value.map(\.foundationObject)
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
                  let string = String(data: data, encoding: .utf8) else {
                return ""
            }
            return string
        case .null:
            return ""
        }
    }

    private var foundationObject: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .dictionary(let value):
            return value.mapValues(\.foundationObject)
        case .array(let value):
            return value.map(\.foundationObject)
        case .null:
            return NSNull()
        }
    }

    private static func from(any value: Any) -> JSONValue {
        switch value {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            let objCType = String(cString: number.objCType)
            return objCType == "c" ? .bool(number.boolValue) : .number(number.doubleValue)
        case let array as [Any]:
            return .array(array.map(from(any:)))
        case let dictionary as [String: Any]:
            return .dictionary(dictionary.mapValues { JSONValue.from(any: $0) })
        default:
            return .null
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .dictionary(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

