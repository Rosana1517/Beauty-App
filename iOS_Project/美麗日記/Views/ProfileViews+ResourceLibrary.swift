import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct ResourceLibraryView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showImport = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "資源庫", action: "匯入精靈") {
                    showImport = true
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("匯入管線")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        Text("貼上來源連結後，自動判斷平台、抓取 metadata、進入預覽，必要時再手動補齊。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(ImportSourceType.allCases) { source in
                                Button {
                                    showImport = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Image(systemName: source.systemImage)
                                            .font(.title2)
                                            .foregroundStyle(AppTheme.primary)
                                        Text(source.rawValue)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.text)
                                        Text(source.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                                    .padding(14)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("真實資料狀態")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 10) {
                            RuntimeStatusChip(
                                title: "YouTube API",
                                active: AppRuntimeConfiguration.hasYouTubeAPI,
                                activeDetail: "正式 metadata",
                                inactiveDetail: "HTML fallback"
                            )
                            RuntimeStatusChip(
                                title: "Supabase",
                                active: AppRuntimeConfiguration.hasSupabaseConfig,
                                activeDetail: "已配置",
                                inactiveDetail: "僅本地 JSON"
                            )
                        }

                        Text("目前小紅書仍以公開頁面解析為主，YouTube 在有 `YOUTUBE_API_KEY` 時會優先走官方 Data API。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("AI 智能分析")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        if store.state.resourceItems.isEmpty {
                            EmptyStateView(title: "先導入資源再進行分析", subtitle: "")
                        } else {
                            ForEach(store.resourceRecommendations, id: \.self) { suggestion in
                                Text(suggestion)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("智能分類")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        WrapSelectableChips(items: ResourceCategory.allCases, selected: store.state.resourceFilter) { category in
                            store.setResourceFilter(category)
                        }

                        if store.filteredResources.isEmpty {
                            EmptyStateView(title: "暫無資源", subtitle: "")
                        } else {
                            ForEach(store.filteredResources) { item in
                                NavigationLink {
                                    ResourceDetailView(item: item)
                                } label: {
                                    ResourceListCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteResource(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                if !store.state.resourceImportHistory.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("最近匯入")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)

                            ForEach(store.state.resourceImportHistory.prefix(3)) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(entry.title.isEmpty ? entry.originalURL : entry.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.text)
                                            .lineLimit(1)
                                        Spacer()
                                        StatusBadge(status: entry.status)
                                    }

                                    Text("\(entry.source.rawValue) · \(entry.importedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("智能推薦")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        ForEach(store.resourceRecommendations, id: \.self) { suggestion in
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showImport, onDismiss: {
            store.clearPendingImportDraft()
        }) {
            ImportWizardSheet()
        }
    }
}


