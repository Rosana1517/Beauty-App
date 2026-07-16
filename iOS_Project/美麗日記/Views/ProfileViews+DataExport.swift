import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct DataExportView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var exportPreview = ""
    @State private var showClearConfirm = false

    private var storageRows: [(label: String, count: Int)] {
        [
            ("打卡記錄", store.state.punchRecords.count),
            ("體態數據", store.state.bodyMetricRecords.count),
            ("飲食記錄", store.state.mealRecords.count),
            ("茶飲記錄", 0),
            ("食譜", store.state.favoriteRecipes.count),
            ("食材", 0),
            ("書籍", store.state.bookRecords.count),
            ("課程", store.state.courses.count),
            ("筆記", store.state.knowledgeNotes.count),
            ("影音", store.state.videoLearningRecords.count),
            ("財務記錄", store.state.transactions.count),
            ("目標", store.state.wishes.count)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "資源庫與數據匯出") {}

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("數據匯出")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("將所有本地數據匯出為JSON文件備份")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)

                        PrimaryButton(title: "匯出數據") {
                            exportPreview = store.createExport(format: .json)
                        }

                        if !exportPreview.isEmpty {
                            Text(exportPreview)
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("清除數據")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("清除所有本地存儲的數據，此操作不可恢復")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)

                        Button("清除所有數據") {
                            showClearConfirm = true
                        }
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("存儲空間")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        ForEach(storageRows, id: \.label) { row in
                            HStack {
                                Text(row.label)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Text("\(row.count) 條記錄")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .alert("確定要清除所有數據嗎？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                store.clearAllLocalData()
            }
        } message: {
            Text("此操作不可恢復。")
        }
    }
}


