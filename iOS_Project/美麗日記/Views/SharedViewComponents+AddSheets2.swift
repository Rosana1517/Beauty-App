import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct EditPunchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var summary: String
    @State private var date: Date
    private let record: PunchRecord

    init(record: PunchRecord) {
        self.record = record
        _summary = State(initialValue: record.summary)
        _date = State(initialValue: record.date)
    }

    var body: some View {
        FormSheet(title: "編輯打卡") {
            ThemedTextField(title: "心得", text: $summary)
            DatePicker("日期", selection: $date, displayedComponents: .date)
                .font(.subheadline)

            PrimaryButton(title: "保存修改") {
                var updated = record
                updated.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.date = date
                store.replaceRecord(updated, in: \.punchRecords)
                dismiss()
            }
        }
    }
}

struct AddAppointmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var storeName = ""
    @State private var date = Date()
    @State private var note = ""

    /// nil defaults to 美容預約's own list; 護髮療程預約 passes its own
    /// store method so the same form can target a different list.
    var onSave: ((String, String, Date, String) -> Void)?
    var sheetTitle: String = "新增預約"

    var body: some View {
        FormSheet(title: sheetTitle) {
            ThemedTextField(title: "服務名稱", text: $title)
            ThemedTextField(title: "店家名稱", text: $storeName)
            DatePicker("預約時間", selection: $date)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                if let onSave {
                    onSave(title, storeName, date, note)
                } else {
                    store.addAppointment(title: title, storeName: storeName, date: date, note: note)
                }
                dismiss()
            }
        }
    }
}

struct AddBodyMetricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "體重體脂記錄") {
            ThemedTextField(title: "體重 (kg)", text: $weight)
            ThemedTextField(title: "體脂 (%)", text: $bodyFat)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addBodyMetric(weight: Double(weight) ?? 0, bodyFat: Double(bodyFat) ?? 0, note: note)
                dismiss()
            }
        }
    }
}

struct TDEESetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var heightText = ""
    @State private var ageText = ""
    @State private var activityLevel = "輕度活動"
    @State private var goal = "維持體重"

    var body: some View {
        FormSheet(title: "每日熱量目標") {
            Text("依身高、年齡、活動量與目標，用最近一筆體重紀錄自動計算每日建議攝取熱量。")
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)

            ThemedTextField(title: "身高（公分）", text: $heightText)
            ThemedTextField(title: "年齡", text: $ageText)

            VStack(alignment: .leading, spacing: 6) {
                Text("活動量")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TDEEProfile.activityLevels, id: \.name) { level in
                            chip(level.name, selected: level.name == activityLevel) {
                                activityLevel = level.name
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("目標")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                HStack(spacing: 8) {
                    ForEach(TDEEProfile.goals, id: \.name) { item in
                        chip(item.name, selected: item.name == goal) {
                            goal = item.name
                        }
                    }
                }
            }

            if store.state.bodyMetricRecords.isEmpty {
                Text("尚無體重紀錄——請先到「體重體脂」新增一筆，目標才能計算。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            PrimaryButton(title: "保存目標") {
                var profile = store.state.tdeeProfile
                profile.heightCM = Double(heightText) ?? profile.heightCM
                profile.age = Int(ageText) ?? profile.age
                profile.activityLevel = activityLevel
                profile.goal = goal
                store.updateTDEEProfile(profile)
                dismiss()
            }
        }
        .onAppear {
            let profile = store.state.tdeeProfile
            if profile.heightCM > 0 { heightText = String(Int(profile.heightCM)) }
            if profile.age > 0 { ageText = String(profile.age) }
            activityLevel = profile.activityLevel
            goal = profile.goal
        }
    }
}
