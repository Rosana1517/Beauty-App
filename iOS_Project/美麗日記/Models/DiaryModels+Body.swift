import Foundation

struct ExercisePunchRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var category: String
    var durationMinutes: Int
}

struct CustomExercise: Identifiable, Codable {
    var id: UUID
    var name: String
    /// 來自 AI 推薦時，關聯的資料庫筆記遠端 ID（可跳轉教學內容）
    var linkedResourceRemoteID: String?
}

struct TrainingScheduleItem: Identifiable, Codable {
    var id: UUID
    var name: String
}

struct SymptomRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var symptom: String
    var note: String
}

struct MenstrualRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var note: String
}

struct BodyAlbumPhoto: Identifiable, Codable {
    var id: UUID
    var date: Date
    var imageData: Data?
    var note: String
}

struct FaceLiftAction: Identifiable, Codable {
    var id: UUID
    var name: String
}

struct FaceLiftPunchRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
}

struct FaceLiftRatingRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var score: Int
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
    /// 估算或手動輸入的熱量（大卡）；舊資料缺此欄位時解碼為 nil
    var calories: Int?
    /// 食物照（僅存本機）
    var photoData: Data?
}

/// 常見食物關鍵字熱量估算表（大卡），供未輸入熱量時粗估
enum CalorieEstimator {
    private static let table: [(keywords: [String], calories: Int)] = [
        (["便當", "排骨飯", "雞腿飯"], 750),
        (["滷肉飯", "咖哩飯", "燴飯", "丼飯"], 650),
        (["炒麵", "炒飯", "義大利麵", "拉麵"], 600),
        (["火鍋", "麻辣燙"], 700),
        (["漢堡", "薯條", "炸雞", "披薩", "鹽酥雞"], 800),
        (["牛肉麵", "湯麵", "米粉", "冬粉"], 500),
        (["水餃", "鍋貼", "小籠包"], 450),
        (["壽司", "生魚片", "飯糰"], 400),
        (["三明治", "吐司", "貝果", "蛋餅"], 350),
        (["沙拉", "燙青菜", "溫沙拉"], 200),
        (["雞胸", "水煮蛋", "豆腐", "無糖豆漿"], 180),
        (["麵包", "蛋糕", "甜點", "餅乾", "冰淇淋"], 380),
        (["手搖", "奶茶", "拿鐵", "果汁", "可樂"], 250),
        (["燕麥", "優格", "地瓜", "香蕉"], 220),
        (["粥", "稀飯"], 300),
    ]

    static func estimate(from text: String) -> Int? {
        var total = 0
        for entry in table where entry.keywords.contains(where: { text.contains($0) }) {
            total += entry.calories
        }
        return total > 0 ? total : nil
    }
}


struct PunchRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var summary: String
}

/// 每日熱量目標（TDEE）計算參數。以 Mifflin-St Jeor（女性）估基礎代謝，
/// 乘活動係數後依目標微調；本 app 目標族群為女性故不設性別欄位。
struct TDEEProfile: Codable, Equatable {
    var heightCM: Double = 0
    var age: Int = 0
    var activityLevel: String = "輕度活動"
    var goal: String = "維持體重"

    static let activityLevels: [(name: String, factor: Double)] = [
        ("久坐少動", 1.2),
        ("輕度活動", 1.375),
        ("中度活動", 1.55),
        ("高度活動", 1.725),
    ]

    static let goals: [(name: String, adjustment: Int)] = [
        ("減脂", -400),
        ("維持體重", 0),
        ("增肌", 300),
    ]

    var isConfigured: Bool {
        heightCM > 0 && age > 0
    }

    /// 以最近一筆體重紀錄計算每日建議攝取熱量（大卡）
    func dailyCalorieTarget(weightKG: Double) -> Int? {
        guard isConfigured, weightKG > 0 else { return nil }
        let bmr = 10 * weightKG + 6.25 * heightCM - 5 * Double(age) - 161
        let factor = Self.activityLevels.first(where: { $0.name == activityLevel })?.factor ?? 1.375
        let adjustment = Self.goals.first(where: { $0.name == goal })?.adjustment ?? 0
        let target = Int(bmr * factor) + adjustment
        return max(1000, target)
    }
}

/// 可設定獨立提醒的習慣清單（key 存進 habitReminderTimes）
enum HabitReminderKind: String, CaseIterable, Identifiable {
    case skincare = "護膚打卡"
    case exercise = "運動"
    case diet = "飲食記錄"
    case weighIn = "量體重"

    var id: String { rawValue }

    var notificationBody: String {
        switch self {
        case .skincare: return "今天的護膚流程完成了嗎？打開 app 打卡吧。"
        case .exercise: return "動一動的時間到了，完成今天的運動打卡。"
        case .diet: return "記得記錄今天吃了什麼，熱量統計才準確。"
        case .weighIn: return "站上體重計，記錄今天的變化。"
        }
    }
}


