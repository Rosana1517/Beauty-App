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
    case hairCare = "頭髮保養"
    case whitening = "美白計畫"
    case faceLift = "面部拉提/瑜珈"
    case hairstyleMatch = "髮型臉型適配"
    case bodySkincare = "身體皮膚保養"
    case productLibrary = "產品管理庫"
    case appointments = "美容預約"
    case makeupInspiration = "妝容靈感"

    var id: String { rawValue }
}

enum SkincareSection: String, CaseIterable, Codable, Identifiable {
    case steps = "護膚步驟"
    case products = "保養品"
    case tracking = "膚質追蹤"
    case advice = "AI建議"
    case tutorials = "教程連結"
    case history = "打卡歷史"

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
    case courses = "課程學習"
    case notes = "知識筆記"
    case videos = "影音學習"
    case dailyQuote = "每日金句"
    case moodTracking = "情緒追蹤"
    case finance = "財務總覽"
    case goals = "目標管理"

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

enum AIAdviceTopic: String, Codable {
    case skincare
    case hair
    case facialLift
    case bodySkin
    case diet
    case makeup
    case exercise
    case wellness
    case finance
    case nourishment
}

enum FinanceRoute: String, Hashable, CaseIterable, Identifiable {
    case ledger = "快速記帳"
    case budget = "預算儀表板"
    case aiAdvice = "AI預算建議"
    case spendingAnalysis = "消費分析"
    case beautyFund = "變美基金"
    case shoppingList = "購物清單"
    case financialHealth = "財務健康評估"

    var id: String { rawValue }
}

enum WellnessSection: String, CaseIterable, Identifiable, Hashable {
    case status = "健康狀況"
    case nourishment = "養生內調"

    var id: String { rawValue }
}


