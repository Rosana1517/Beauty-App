import Foundation

struct ChecklistItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var category: String
}

struct ChecklistCompletionEntry: Identifiable, Codable {
    var id: UUID
    var itemID: UUID
    var date: Date
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

struct Appointment: Identifiable, Codable {
    var id: UUID
    var title: String
    var storeName: String
    var date: Date
    var note: String
}

/// 一則「美妝知識問答」的聊天訊息，含 AI 回覆時附帶的圖片與參考來源。
/// Role 用 String raw value，避免日後改動 case 順序讓已存的紀錄解不開。
struct NotionQAChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id = UUID()
    var role: Role
    var text: String
    var images: [String] = []
    var sourceUrl: String = ""
}
