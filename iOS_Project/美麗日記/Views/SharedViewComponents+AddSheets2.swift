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

struct AddMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var type = "早餐"
    @State private var summary = ""
    @State private var note = ""
    @State private var caloriesText = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var validationMessage: String?

    private let mealTypes = ["早餐", "午餐", "晚餐", "點心", "飲料"]

    var body: some View {
        FormSheet(title: "飲食記錄") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(mealTypes, id: \.self) { meal in
                        chip(meal, selected: meal == type) { type = meal }
                    }
                }
            }

            ThemedTextField(title: "餐點內容（例：雞腿便當+無糖豆漿）", text: $summary)
            ThemedTextField(title: "備註", text: $note)

            HStack(spacing: 10) {
                ThemedTextField(title: "熱量（大卡，可留空自動估算）", text: $caloriesText)
                Button("估算") {
                    Task { await runAIAnalysis() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .disabled(store.isAnalyzingFood)
            }

            HStack(spacing: 10) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍食物照", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.primarySoft)
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("相簿選照", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.primarySoft)
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if store.isAnalyzingFood {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("AI 正在辨識餐點與估算熱量…")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }
            } else if let error = store.foodAnalysisError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            PrimaryButton(title: "保存") {
                let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    validationMessage = "請輸入餐點內容，或先用拍照/選照讓 AI 辨識。"
                    return
                }
                store.addMealRecord(
                    type: type,
                    summary: summary,
                    note: note,
                    calories: Int(caloriesText),
                    photoData: photoData
                )
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image?.jpegData(compressionQuality: 0.6) {
                    photoData = data
                    Task { await runAIAnalysis() }
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    photoData = image.jpegData(compressionQuality: 0.6)
                    await runAIAnalysis()
                }
                photoItem = nil
            }
        }
    }

    private func runAIAnalysis() async {
        validationMessage = nil
        let textHint = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard photoData != nil || !textHint.isEmpty else {
            validationMessage = "請先輸入餐點內容或提供照片，AI 才能估算。"
            return
        }
        guard let result = await store.analyzeFood(text: textHint.isEmpty ? nil : textHint, imageData: photoData) else {
            // AI 失敗時退回本地關鍵字估算，至少熱量欄不會空著
            if let estimated = CalorieEstimator.estimate(from: summary) {
                caloriesText = String(estimated)
            }
            return
        }
        if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            summary = result.foodName
        }
        caloriesText = String(result.estimatedCalories)
        if !result.notes.isEmpty, note.isEmpty {
            note = result.notes
        }
    }
}

struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var author = ""
    @State private var link = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "添加書籍") {
            ThemedTextField(title: "書名", text: $title)
            ThemedTextField(title: "作者", text: $author)
            ThemedTextField(title: "外部連結", text: $link)
            ThemedTextField(title: "筆記", text: $note)

            PrimaryButton(title: "保存") {
                store.addBook(title: title, author: author, link: link, note: note)
                dismiss()
            }
        }
    }
}

