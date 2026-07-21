import Foundation

/// Supabase `face_exercise_library` 公開唯讀表的一筆面部動作
/// (面部瑜珈 / 面部按摩 / 面部訓練)。
/// 欄位以 snake_case 儲存,由 SupabaseRESTClient 的 convertFromSnakeCase 解碼。
struct FaceExerciseItem: Identifiable, Decodable, Hashable {
    let id: String
    let itemType: String
    let nameEn: String
    let nameZh: String?
    let categoryZh: String?
    let targetAreaZh: [String]?
    let difficulty: String?
    let benefitsZh: String?
    let stepsZh: [String]?
    let repsZh: String?
    let cautionZh: String?
    let gifUrl: String?
    let tags: [String]?
    let sourceUrl: String?

    var displayName: String {
        if let nameZh, !nameZh.isEmpty { return nameZh }
        return nameEn
    }

    var secondaryName: String? {
        nameEn == displayName ? nil : nameEn
    }

    var itemTypeLabel: String {
        switch itemType {
        case "face_yoga": return "面部瑜珈"
        case "face_massage": return "面部按摩"
        case "face_training": return "面部訓練"
        default: return itemType
        }
    }

    var difficultyLabel: String? {
        switch difficulty {
        case "beginner": return "初級"
        case "intermediate": return "中級"
        case "expert": return "高級"
        default: return difficulty
        }
    }

    /// 卡片與詳情頁的標籤(類型/分類/部位/難度),過濾空值。
    var badgeTexts: [String] {
        var badges = [itemTypeLabel, categoryZh, difficultyLabel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        if let areas = targetAreaZh, !areas.isEmpty {
            badges.append(areas.prefix(2).joined(separator: "·"))
        }
        return badges
    }
}

enum FaceExerciseTypeFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case yoga = "面部瑜珈"
    case massage = "面部按摩"
    case training = "面部訓練"

    var id: String { rawValue }

    var itemTypeValue: String? {
        switch self {
        case .all: return nil
        case .yoga: return "face_yoga"
        case .massage: return "face_massage"
        case .training: return "face_training"
        }
    }
}

/// exercise-match Edge Function(library=face)的回傳:動作 + 一句推薦理由。
struct FaceExerciseMatchResult: Decodable, Identifiable, Hashable {
    let item: FaceExerciseItem
    let reason: String

    var id: String { item.id }
}

struct FaceExerciseMatchResponse: Decodable {
    let matches: [FaceExerciseMatchResult]
}
