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
    case whitening = "美白計畫"
    case appointments = "美容預約"

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
}

struct UserProfileRecord: Codable {
    var nickname: String
    var streakDays: Int
    var signature: String
    var bodyFocus: String
    var skincareFocus: String
    var themeName: String
    var notificationTime: String
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

struct ResourceItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var source: ImportSourceType
    var category: ResourceCategory
    var url: String
    var summary: String
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
        resourceFilter: .all
    )
}
