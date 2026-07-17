import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct DailyQuoteView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var quoteIndex = Int.random(in: 0..<DailyQuoteView.quotes.count)
    @State private var showAddAffirmation = false
    @State private var showAddVision = false
    @State private var showAddGratitude = false
    @State private var editingAffirmation: SelfAffirmation?
    @State private var editingVisionItem: VisionBoardItem?
    @State private var editingGratitude: GratitudeEntry?

    static let quotes = [
        "成為自己的太陽，無需借誰的光",
        "每一天都是新的開始",
        "你比自己想像的更堅強",
        "慢慢來，比較快",
        "先愛自己，再愛別人"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "每日金句") {}

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("「\(DailyQuoteView.quotes[quoteIndex])」")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(AppTheme.text)
                        Text("—— 今日金句")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                        Button("換一句") {
                            quoteIndex = Int.random(in: 0..<DailyQuoteView.quotes.count)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("自我肯定")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+添加") { showAddAffirmation = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.selfAffirmations.isEmpty {
                            EmptyStateView(title: "寫下你的肯定語", subtitle: "")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.state.selfAffirmations) { item in
                                    Text(item.text)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(AppTheme.primarySoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .recordActions(onEdit: { editingAffirmation = item }) {
                                            store.deleteSelfAffirmation(item)
                                        }
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("願景板")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+添加") { showAddVision = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.visionBoardItems.isEmpty {
                            EmptyStateView(title: "創建你的願景板", subtitle: "")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.state.visionBoardItems) { item in
                                    Text(item.text)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(AppTheme.primarySoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .recordActions(onEdit: { editingVisionItem = item }) {
                                            store.deleteVisionBoardItem(item)
                                        }
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("感恩日記")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+記錄") { showAddGratitude = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.gratitudeEntries.isEmpty {
                            EmptyStateView(title: "暫無記錄", subtitle: "")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.state.gratitudeEntries) { entry in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.text)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.text)
                                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingGratitude = entry }) {
                                        store.deleteGratitudeEntry(entry)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingAffirmation) { record in
            FieldsEditSheet(
                title: "編輯自我肯定",
                fieldLabels: ["內容"],
                values: [record.text],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = record
                updated.text = values[0]

                store.replaceRecord(updated, in: \.selfAffirmations)
            }
        }
        .sheet(item: $editingVisionItem) { record in
            FieldsEditSheet(
                title: "編輯願景板",
                fieldLabels: ["內容"],
                values: [record.text],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = record
                updated.text = values[0]

                store.replaceRecord(updated, in: \.visionBoardItems)
            }
        }
        .sheet(item: $editingGratitude) { record in
            FieldsEditSheet(
                title: "編輯感恩記錄",
                fieldLabels: ["內容"],
                values: [record.text],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.text = values[0]
                updated.date = newDate
                store.replaceRecord(updated, in: \.gratitudeEntries)
            }
        }
        .sheet(isPresented: $showAddAffirmation) {
            AddLinkSheet(sheetTitle: "添加自我肯定", titleFieldLabel: "我值得被愛…") { text, _ in
                store.addSelfAffirmation(text: text)
            }
        }
        .sheet(isPresented: $showAddVision) {
            AddLinkSheet(sheetTitle: "添加願景板項目", titleFieldLabel: "願景內容") { text, _ in
                store.addVisionBoardItem(text: text)
            }
        }
        .sheet(isPresented: $showAddGratitude) {
            AddLinkSheet(sheetTitle: "添加感恩日記", titleFieldLabel: "今天感謝的事") { text, _ in
                store.addGratitudeEntry(text: text)
            }
        }
    }
}
