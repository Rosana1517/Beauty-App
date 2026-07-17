import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct AddSymptomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var symptom = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增症狀記錄") {
            ThemedTextField(title: "症狀", text: $symptom)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addSymptomRecord(symptom: symptom, note: note)
                dismiss()
            }
        }
    }
}

struct AddMenstrualRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增經期記錄") {
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addMenstrualRecord(note: note)
                dismiss()
            }
        }
    }
}

struct AddNourishmentRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var url = ""

    var body: some View {
        FormSheet(title: "添加滋補食譜") {
            ThemedTextField(title: "食譜名稱", text: $title)
            ThemedTextField(title: "連結（選填）", text: $url)

            PrimaryButton(title: "保存") {
                store.addNourishmentRecipe(title: title, url: url)
                dismiss()
            }
        }
    }
}

struct AddFaceLiftActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var name = ""

    var body: some View {
        FormSheet(title: "新增動作") {
            ThemedTextField(title: "動作名稱", text: $name)

            PrimaryButton(title: "保存") {
                store.addFaceLiftAction(name: name)
                dismiss()
            }
        }
    }
}

struct AddFaceLiftRatingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var score: Double = 7
    @State private var note = ""

    var body: some View {
        FormSheet(title: "緊緻度評分") {
            VStack(alignment: .leading, spacing: 8) {
                Text("評分：\(Int(score)) 分")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text)
                Slider(value: $score, in: 1...10, step: 1)
                    .tint(AppTheme.primary)
            }

            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addFaceLiftRating(score: Int(score), note: note)
                dismiss()
            }
        }
    }
}

struct AddHairCareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var careType = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增護髮紀錄") {
            ThemedTextField(title: "保養類型（洗髮、護髮療程…）", text: $careType)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addHairCareRecord(careType: careType, note: note)
                dismiss()
            }
        }
    }
}

struct AddBodySkinRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var area = ""
    @State private var concern = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增身體保養紀錄") {
            ThemedTextField(title: "部位", text: $area)
            ThemedTextField(title: "膚況問題", text: $concern)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addBodySkinRecord(area: area, concern: concern, note: note)
                dismiss()
            }
        }
    }
}

struct AddPunchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var summary = ""

    var body: some View {
        FormSheet(title: "新增打卡") {
            ThemedTextField(title: "今日心得", text: $summary)

            PrimaryButton(title: "保存") {
                store.addPunchRecord(summary: summary)
                dismiss()
            }
        }
    }
}

/// 區域目標 + 記錄彙整建議卡：輸入預期目標，依累積記錄生成後續建議
