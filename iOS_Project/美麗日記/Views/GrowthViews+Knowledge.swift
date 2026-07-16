import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct KnowledgeNotesView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var editingNote: KnowledgeNote?
    @State private var tagFilter = "全部"

    private var allTags: [String] {
        let set = Set(store.state.knowledgeNotes.flatMap(\.tags)).filter { !$0.isEmpty }
        return ["全部"] + set.sorted()
    }

    private var filteredNotes: [KnowledgeNote] {
        guard tagFilter != "全部" else { return store.state.knowledgeNotes }
        return store.state.knowledgeNotes.filter { $0.tags.contains(tagFilter) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "知識筆記", action: "新建") {
                    showAdd = true
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(allTags, id: \.self) { tag in
                            Button {
                                tagFilter = tag
                            } label: {
                                Text(tag)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(tagFilter == tag ? AppTheme.primary : AppTheme.card)
                                    .foregroundStyle(tagFilter == tag ? Color.white : AppTheme.text)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                CardView {
                    if filteredNotes.isEmpty {
                        EmptyStateView(title: "暫無筆記", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredNotes) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(note.content)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    if !note.tags.isEmpty {
                                        Text(note.tags.joined(separator: "、"))
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingNote = note }) {
                                    store.deleteKnowledgeNote(note)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showAdd) { AddKnowledgeNoteSheet() }
        .sheet(item: $editingNote) { note in
            FieldsEditSheet(
                title: "編輯筆記",
                fieldLabels: ["標題", "重點摘錄", "標籤（逗號分隔）"],
                values: [note.title, note.content, note.tags.joined(separator: ",")],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = note
                updated.title = values[0]
                updated.content = values[1]
                updated.tags = values[2].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                store.replaceRecord(updated, in: \.knowledgeNotes)
            }
        }
    }
}

