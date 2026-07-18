import Foundation

/// Supabase `exercise_library` 公開唯讀表的一筆運動/瑜伽資料。
/// 欄位以 snake_case 儲存,由 SupabaseRESTClient 的 convertFromSnakeCase 解碼。
struct ExerciseLibraryItem: Identifiable, Decodable, Hashable {
    let id: String
    let itemType: String
    let nameEn: String
    let nameZh: String?
    let sanskritName: String?
    let categoryZh: String?
    let bodyPartZh: String?
    let equipmentZh: String?
    let targetMuscle: String?
    let difficultyZh: String?
    let descriptionZh: String?
    let descriptionEn: String?
    let benefitsZh: String?
    let stepsZh: [String]?
    let imageUrl: String?
    let gifUrl: String?
    let svgUrl: String?
    let attribution: String?

    var isYoga: Bool { itemType == "yoga" }

    var displayName: String {
        if let nameZh, !nameZh.isEmpty { return nameZh }
        return nameEn
    }

    /// 詳情頁副標:健身顯示英文原名,瑜伽顯示梵文名。
    var secondaryName: String? {
        if isYoga {
            return sanskritName
        }
        return nameEn == displayName ? nil : nameEn
    }

    /// 卡片與詳情頁的標籤(分類/器材/難度),過濾空值。
    var badgeTexts: [String] {
        [categoryZh, equipmentZh, difficultyZh, targetMuscle]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
    }

    var resolvedDescription: String? {
        if let descriptionZh, !descriptionZh.isEmpty { return descriptionZh }
        return descriptionEn
    }
}

enum ExerciseLibraryTypeFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case strength = "健身"
    case yoga = "瑜伽"

    var id: String { rawValue }

    var itemTypeValue: String? {
        switch self {
        case .all:
            return nil
        case .strength:
            return "strength"
        case .yoga:
            return "yoga"
        }
    }
}

/// exercise-match Edge Function 的回傳:動作 + 一句推薦理由。
struct ExerciseMatchResult: Decodable, Identifiable, Hashable {
    let item: ExerciseLibraryItem
    let reason: String

    var id: String { item.id }
}

struct ExerciseMatchResponse: Decodable {
    let matches: [ExerciseMatchResult]
}

enum ExerciseLibraryConstants {
    /// exercise_library 的 body_part_zh 全部取值(依資料量排序)
    static let bodyParts = ["上臂", "大腿", "背部", "腰腹", "胸部", "肩部", "小腿", "前臂", "心肺", "頸部"]
    static let difficulties = ["初級", "中級", "高級"]
    static let pageSize = 30
}
