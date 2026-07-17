import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct HomeView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showCustomize = false
    @State private var editingChecklistItem: ChecklistItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("我的美麗日記")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    Text(Date.now.formatted(date: .complete, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtext)
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("本週完成率")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Text("\(weeklyPercent)%")
                                .font(.headline)
                                .foregroundStyle(AppTheme.primary)
                        }

                        ProgressView(value: Double(store.weeklyCompletionRate.completed), total: Double(max(1, store.weeklyCompletionRate.total)))
                            .tint(AppTheme.primary)

                        Text("本週已打卡 \(store.weeklyCompletionRate.completed)/\(store.weeklyCompletionRate.total) 項")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("每週回顧")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        let review = store.weeklyReview()
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            reviewTile(value: "\(review.punchCount)", label: "本週打卡次數")
                            reviewTile(value: "\(review.exerciseMinutes)", label: "運動分鐘")
                            reviewTile(
                                value: review.averageDailyCalories.map { "\($0)" } ?? "—",
                                label: "日均攝取大卡"
                            )
                            reviewTile(
                                value: review.weightDelta.map { String(format: "%+.1f", $0) } ?? "—",
                                label: "本週體重變化 kg"
                            )
                        }

                        if let mood = review.moodSummary {
                            Text("本週最常見心情：\(mood)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                }

                HStack {
                    sectionTitle("今日待辦打卡")
                    Spacer()
                    Button("自定義") { showCustomize = true }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }

                VStack(spacing: 12) {
                    ForEach(store.state.checklistItems) { item in
                        let completedToday = store.isChecklistItemCompletedToday(item)
                        Button {
                            store.toggleChecklist(item)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: completedToday ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(completedToday ? AppTheme.primary : AppTheme.subtext)

                                Text(item.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppTheme.text)

                                Spacer()

                                Text(item.category)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            .padding(16)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                        .shadow(color: AppTheme.shadow, radius: 10, y: 5)
                        .recordActions(onEdit: { editingChecklistItem = item }) {
                            store.deleteChecklistItem(item)
                        }
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showCustomize) { CustomizeChecklistSheet() }
        .sheet(item: $editingChecklistItem) { item in
            FieldsEditSheet(
                title: "編輯打卡項目",
                fieldLabels: ["名稱", "分類"],
                values: [item.title, item.category],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = item
                updated.title = values[0]
                updated.category = values[1]
                store.replaceRecord(updated, in: \.checklistItems)
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppTheme.text)
    }

    private var weeklyPercent: Int {
        let rate = store.weeklyCompletionRate
        guard rate.total > 0 else { return 0 }
        return Int(Double(rate.completed) / Double(rate.total) * 100)
    }

    private func reviewTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
