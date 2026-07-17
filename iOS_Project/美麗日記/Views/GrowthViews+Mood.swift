import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct MoodTrackingView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var selectedMood: String?
    @State private var note = ""
    @State private var editingMoodEntry: MoodEntry?

    private let moods = [("😊", "開心"), ("😌", "平靜"), ("😔", "低落"), ("😫", "煩躁"), ("🥺", "疲憊")]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "每日金句·情緒追蹤") {}

                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("「\(DailyQuoteView.quotes.first ?? "")」")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.text)
                        Text("—— 今日金句")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }

                if let firstAffirmation = store.state.selfAffirmations.first {
                    CardView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(firstAffirmation.text)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.text)
                            Text("—— 今日自我肯定")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("今日情緒")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 14) {
                            ForEach(moods, id: \.1) { mood in
                                Button {
                                    selectedMood = mood.1
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(mood.0)
                                            .font(.title2)
                                        Text(mood.1)
                                            .font(.caption2)
                                            .foregroundStyle(selectedMood == mood.1 ? AppTheme.primary : AppTheme.subtext)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedMood == mood.1 ? AppTheme.primarySoft : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        ThemedTextField(title: "記錄此刻的感受…", text: $note)

                        PrimaryButton(title: "保存") {
                            guard let selectedMood else { return }
                            store.addMoodEntry(mood: selectedMood, note: note)
                            note = ""
                        }
                    }
                }

                if !store.state.moodEntries.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("情緒紀錄")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            VStack(spacing: 8) {
                                ForEach(store.state.moodEntries) { entry in
                                    HStack {
                                        Text(entry.mood)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.note.isEmpty ? entry.date.formatted(date: .abbreviated, time: .omitted) : entry.note)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.text)
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .recordActions(onEdit: { editingMoodEntry = entry }) {
                                        store.deleteMoodEntry(entry)
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
        .sheet(item: $editingMoodEntry) { record in
            FieldsEditSheet(
                title: "編輯心情記錄",
                fieldLabels: ["心情", "備註"],
                values: [record.mood, record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.mood = values[0]
                updated.note = values[1]
                updated.date = newDate
                store.replaceRecord(updated, in: \.moodEntries)
            }
        }
    }
}
