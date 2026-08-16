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

struct NotionQAFunctionRequest: Encodable {
    let message: String
    let sessionId: String
}

struct NotionQAFunctionResponse: Decodable {
    let text: String
    let images: [String]
    let sourceUrl: String
    let sessionId: String
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
