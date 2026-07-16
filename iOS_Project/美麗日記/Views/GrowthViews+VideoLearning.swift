import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct VideoLearningView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var editingVideoRecord: VideoLearningRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "影音學習追蹤", action: "添加") {
                    showAdd = true
                }

                CardView {
                    if store.state.videoLearningRecords.isEmpty {
                        EmptyStateView(title: "暫無影音記錄", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.videoLearningRecords) { record in
                                Button {
                                    store.toggleVideoLearningWatched(record)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: record.watched ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(record.watched ? AppTheme.primary : AppTheme.subtext)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(record.title)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(AppTheme.text)
                                            Text("\(record.contentType) · \(record.platform.isEmpty ? "未填寫平台" : record.platform)")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.subtext)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingVideoRecord = record }) {
                                    store.deleteVideoLearningRecord(record)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingVideoRecord) { record in
            FieldsEditSheet(
                title: "編輯影片學習",
                fieldLabels: ["標題", "平台", "連結URL"],
                values: [record.title, record.platform, record.url],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.title = values[0]
                updated.platform = values[1]
                updated.url = values[2]

                store.replaceRecord(updated, in: \.videoLearningRecords)
            }
        }
        .sheet(isPresented: $showAdd) { AddVideoLearningSheet() }
    }
}

