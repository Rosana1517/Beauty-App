import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct ReadingTrackerView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var editingBookRecord: BookRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "閱讀追蹤", action: "添加") {
                    showAdd = true
                }

                CardView {
                    if store.state.bookRecords.isEmpty {
                        EmptyStateView(title: "暫無書籍，開始添加吧", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.bookRecords) { book in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(book.author.isEmpty ? "未填寫作者" : book.author)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    if !book.link.isEmpty {
                                        Text(book.link)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingBookRecord = book }, onDelete: {
                                    store.deleteBook(book)
                                })
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingBookRecord) { record in
            FieldsEditSheet(
                title: "編輯書籍",
                fieldLabels: ["書名", "作者", "連結", "筆記"],
                values: [record.title, record.author, record.link, record.note],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = record
                updated.title = values[0]
                updated.author = values[1]
                updated.link = values[2]
                updated.note = values[3]

                store.replaceRecord(updated, in: \.bookRecords)
            }
        }
        .sheet(isPresented: $showAdd) { AddBookSheet() }
    }
}
