import Foundation

struct UserProfileRecord: Codable, Equatable {
    var nickname: String
    var streakDays: Int
    var signature: String
    var bodyFocus: String
    var skincareFocus: String
    var themeName: String
    var notificationTime: String
    var morningReminderTime: String
    var enabledModules: Set<String>

    init(
        nickname: String,
        streakDays: Int,
        signature: String,
        bodyFocus: String,
        skincareFocus: String,
        themeName: String,
        notificationTime: String,
        morningReminderTime: String = "08:00",
        enabledModules: Set<String> = ["變美", "體態", "成長", "財務", "情緒"]
    ) {
        self.nickname = nickname
        self.streakDays = streakDays
        self.signature = signature
        self.bodyFocus = bodyFocus
        self.skincareFocus = skincareFocus
        self.themeName = themeName
        self.notificationTime = notificationTime
        self.morningReminderTime = morningReminderTime
        self.enabledModules = enabledModules
    }

    private enum CodingKeys: String, CodingKey {
        case nickname, streakDays, signature, bodyFocus, skincareFocus, themeName, notificationTime
        case morningReminderTime, enabledModules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try container.decode(String.self, forKey: .nickname)
        streakDays = try container.decode(Int.self, forKey: .streakDays)
        signature = try container.decode(String.self, forKey: .signature)
        bodyFocus = try container.decode(String.self, forKey: .bodyFocus)
        skincareFocus = try container.decode(String.self, forKey: .skincareFocus)
        themeName = try container.decode(String.self, forKey: .themeName)
        notificationTime = try container.decode(String.self, forKey: .notificationTime)
        morningReminderTime = try container.decodeIfPresent(String.self, forKey: .morningReminderTime) ?? "08:00"
        enabledModules = try container.decodeIfPresent(Set<String>.self, forKey: .enabledModules) ?? ["變美", "體態", "成長", "財務", "情緒"]
    }
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


