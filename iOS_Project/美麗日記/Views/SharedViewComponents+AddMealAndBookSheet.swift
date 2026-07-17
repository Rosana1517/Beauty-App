import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

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
