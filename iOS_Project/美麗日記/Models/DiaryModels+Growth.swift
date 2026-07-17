import Foundation

struct Course: Identifiable, Codable {
    var id: UUID
    var title: String
    var platform: String
    var url: String
    var progressPercent: Int
}

struct KnowledgeNote: Identifiable, Codable {
    var id: UUID
    var date: Date
    var title: String
    var content: String
    var tags: [String]
}

struct VideoLearningRecord: Identifiable, Codable {
    var id: UUID
    var title: String
    var contentType: String
    var platform: String
    var url: String
    var watched: Bool
}

struct SelfAffirmation: Identifiable, Codable {
    var id: UUID
    var text: String
}

struct VisionBoardItem: Identifiable, Codable {
    var id: UUID
    var text: String
}

struct GratitudeEntry: Identifiable, Codable {
    var id: UUID
    var date: Date
    var text: String
}

struct MoodEntry: Identifiable, Codable {
    var id: UUID
    var date: Date
    var mood: String
    var note: String
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
