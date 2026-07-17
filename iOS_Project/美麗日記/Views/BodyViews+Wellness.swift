import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct WellnessView: View {
    @EnvironmentObject var store: BeautyDiaryStore
    @State var section: WellnessSection = .status
    @State var showAddSymptom = false
    @State var improvementDirection = ""
    @State var showAddMenstrual = false
    @State var showAddNourishmentRecipe = false
    @State var selectedTeaCategory: String?
    @State var editingNourishmentRecipe: TutorialLink?
    @State var editingMenstrualRecord: MenstrualRecord?
    @State var editingSymptomRecord: SymptomRecord?

    let teaCategories = ["養身", "豐胸", "瘦身", "美白", "助眠"]
    let teaRecipeLibrary: [String: [String]] = [
        "養身": ["紅棗枸杞茶", "黃耆人蔘茶", "四物飲"],
        "豐胸": ["木瓜銀耳湯", "山藥豆漿"],
        "瘦身": ["荷葉決明子茶", "陳皮普洱茶"],
        "美白": ["玫瑰珍珠茶", "百合蓮子茶"],
        "助眠": ["甘麥大棗湯", "酸棗仁茶"]
    ]
    let constitutions = [("寒性", "手腳冰冷‧怕冷"), ("熱性", "易上火‧口渴"), ("虛性", "易疲倦‧氣短"), ("實性", "體力充沛‧易便秘")]

    /// 把使用者已記錄的症狀歷史整理成一段脈絡，靜默併入 AI 請求，
    /// 讓建議是依照實際紀錄而非僅憑當下輸入的單一問題。
    var symptomHistoryContext: [String] {
        guard !store.state.symptomRecords.isEmpty else { return [] }
        let recent = store.state.symptomRecords.prefix(8).map { record -> String in
            record.note.isEmpty ? record.symptom : "\(record.symptom)（\(record.note)）"
        }
        return ["我近期記錄的症狀：\(recent.joined(separator: "、"))"]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "養生健康") {}

                Picker("", selection: $section) {
                    ForEach(WellnessSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                switch section {
                case .status:
                    statusContent
                case .nourishment:
                    nourishmentContent
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingNourishmentRecipe) { record in
            FieldsEditSheet(
                title: "編輯食譜連結",
                fieldLabels: ["標題", "連結URL"],
                values: [record.title, record.url],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = record
                updated.title = values[0]
                updated.url = values[1]

                store.replaceRecord(updated, in: \.nourishmentRecipes)
            }
        }
        .sheet(item: $editingMenstrualRecord) { record in
            FieldsEditSheet(
                title: "編輯生理記錄",
                fieldLabels: ["備註"],
                values: [record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.note = values[0]
                updated.date = newDate
                store.replaceRecord(updated, in: \.menstrualRecords)
            }
        }
        .sheet(item: $editingSymptomRecord) { record in
            FieldsEditSheet(
                title: "編輯症狀記錄",
                fieldLabels: ["症狀", "備註"],
                values: [record.symptom, record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.symptom = values[0]
                updated.note = values[1]
                updated.date = newDate
                store.replaceRecord(updated, in: \.symptomRecords)
            }
        }
        .sheet(isPresented: $showAddSymptom) { AddSymptomSheet() }
        .sheet(isPresented: $showAddMenstrual) { AddMenstrualRecordSheet() }
        .sheet(isPresented: $showAddNourishmentRecipe) { AddNourishmentRecipeSheet() }
    }
}
