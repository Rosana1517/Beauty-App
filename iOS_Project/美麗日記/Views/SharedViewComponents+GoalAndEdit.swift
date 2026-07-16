import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct GoalAdviceCard: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    let area: String
    let topic: AIAdviceTopic
    @State private var goalText = ""
    @State private var goalSaved = false

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(area)目標與建議")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                HStack(spacing: 10) {
                    ThemedTextField(title: "輸入預期目標（例：三個月瘦 3kg）", text: $goalText)
                    Button(goalSaved ? "已保存" : "保存") {
                        store.setAreaGoal(area, goal: goalText)
                        goalSaved = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("記錄彙整")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.subtext)
                    ForEach(store.areaRecordsDigest(area), id: \.self) { line in
                        Text("・\(line)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.text)
                    }
                }

                Button {
                    let goal = store.areaGoal(area)
                    let concerns = (goal.isEmpty ? [] : ["我的目標：\(goal)"]) + store.areaRecordsDigest(area)
                    Task {
                        await store.requestAIAdvice(topic: topic, concerns: concerns)
                    }
                } label: {
                    HStack {
                        if store.isLoadingAdvice(for: topic) {
                            ProgressView().tint(.white)
                        }
                        Text("依記錄生成後續建議")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(store.isLoadingAdvice(for: topic))

                if let error = store.errorMessage(for: topic) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                let suggestions = store.suggestions(for: topic)
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("後續建議")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.subtext)
                        ForEach(suggestions, id: \.self) { suggestion in
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .onAppear {
            if goalText.isEmpty {
                goalText = store.areaGoal(area)
            }
        }
        .onChange(of: goalText) { _ in
            goalSaved = false
        }
    }
}

/// 通用編輯 sheet：單行文字 + 日期（心得、備註類記錄）
struct TextDateEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let fieldLabel: String
    @State var text: String
    @State var date: Date
    let onSave: (String, Date) -> Void

    var body: some View {
        FormSheet(title: title) {
            ThemedTextField(title: fieldLabel, text: $text)
            DatePicker("日期", selection: $date, displayedComponents: .date)
                .font(.subheadline)

            PrimaryButton(title: "保存修改") {
                onSave(text.trimmingCharacters(in: .whitespacesAndNewlines), date)
                dismiss()
            }
        }
    }
}

/// 通用編輯 sheet：標題 + 連結（教學連結、食譜、髮型靈感等）
struct TitleURLEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State var itemTitle: String
    @State var url: String
    let onSave: (String, String) -> Void

    var body: some View {
        FormSheet(title: title) {
            ThemedTextField(title: "標題", text: $itemTitle)
            ThemedTextField(title: "連結URL", text: $url)

            PrimaryButton(title: "保存修改") {
                onSave(
                    itemTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    url.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                dismiss()
            }
        }
    }
}

/// 通用編輯 sheet：類型（可選項）+ 備註（膚況、症狀、心情等記錄）
struct TypeNoteEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let typeLabel: String
    let typeOptions: [String]
    @State var typeValue: String
    @State var note: String
    let onSave: (String, String) -> Void

    var body: some View {
        FormSheet(title: title) {
            if typeOptions.isEmpty {
                ThemedTextField(title: typeLabel, text: $typeValue)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(typeLabel)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(typeOptions, id: \.self) { option in
                                chip(option, selected: option == typeValue) {
                                    typeValue = option
                                }
                            }
                        }
                    }
                }
            }
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存修改") {
                onSave(typeValue, note.trimmingCharacters(in: .whitespacesAndNewlines))
                dismiss()
            }
        }
    }
}

/// 萬用多欄位編輯 sheet：以文字欄位陣列驅動，可選日期欄
struct FieldsEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let fieldLabels: [String]
    @State var values: [String]
    var showsDate: Bool = false
    @State var date: Date = .now
    let onSave: ([String], Date) -> Void

    var body: some View {
        FormSheet(title: title) {
            ForEach(Array(fieldLabels.enumerated()), id: \.offset) { index, label in
                ThemedTextField(title: label, text: Binding(
                    get: { index < values.count ? values[index] : "" },
                    set: { newValue in
                        if index < values.count { values[index] = newValue }
                    }
                ))
            }
            if showsDate {
                DatePicker("日期", selection: $date, displayedComponents: .date)
                    .font(.subheadline)
            }

            PrimaryButton(title: "保存修改") {
                onSave(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }, date)
                dismiss()
            }
        }
    }
}

/// 通用列操作選單：附加「編輯 / 刪除」到記錄列（長按顯示）
struct RecordRowActions: ViewModifier {
    let onEdit: (() -> Void)?
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("編輯", systemImage: "pencil")
                }
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }
}

extension View {
    func recordActions(onEdit: (() -> Void)? = nil, onDelete: @escaping () -> Void) -> some View {
        modifier(RecordRowActions(onEdit: onEdit, onDelete: onDelete))
    }
}

