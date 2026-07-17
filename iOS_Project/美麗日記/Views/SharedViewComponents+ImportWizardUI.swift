import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct ImportWizardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var url = ""
    @State private var isLoading = false
    @State private var draft = ResourceImportDraft.empty(url: "")
    @State private var parseMessage = ""
    @State private var currentStep: ImportWizardStep = .input

    private enum ImportWizardStep {
        case input
        case preview
        case manual
    }

    var body: some View {
        FormSheet(title: "匯入精靈") {
            if currentStep == .input {
                VStack(alignment: .leading, spacing: 12) {
                    Text("貼上來源連結後，系統會先嘗試抓取標題、作者、縮圖、時間與內容型別。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtext)

                    ThemedTextField(title: "來源連結", text: $url)

                    if !parseMessage.isEmpty {
                        InfoCallout(title: "解析提醒", detail: parseMessage)
                    }

                    PrimaryButton(title: isLoading ? "解析中..." : "開始解析") {
                        guard !isLoading else { return }
                        Task {
                            await parseURL()
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("支援來源")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)

                            ForEach(ImportSourceType.allCases) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.systemImage)
                                        .foregroundStyle(AppTheme.primary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.rawValue)
                                            .foregroundStyle(AppTheme.text)
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            } else if currentStep == .preview {
                ImportPreviewView(draft: draft) {
                    store.saveImportedResource(draft)
                    dismiss()
                } manualAction: {
                    currentStep = .manual
                }
            } else {
                ManualCompleteView(draft: $draft) {
                    store.updateImportDraft(draft)
                    store.saveImportedResource(draft)
                    dismiss()
                }
            }
        }
        .onAppear {
            if let pending = store.state.pendingImportDraft {
                draft = pending
                url = pending.originalURL
                currentStep = pending.requiresManualCompletion ? .manual : .preview
            }
        }
    }

    private func parseURL() async {
        isLoading = true
        let parsed = await store.importResource(from: url)
        draft = parsed
        parseMessage = parsed.lastErrorMessage ?? ""
        currentStep = .preview
        isLoading = false
    }
}

struct ImportPreviewView: View {
    let draft: ResourceImportDraft
    let saveAction: () -> Void
    let manualAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("匯入預覽")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        StatusBadge(status: draft.importStatus)
                    }

                    MetadataHero(draft: draft)

                    if !draft.missingFields.isEmpty {
                        InfoCallout(title: "待補欄位", detail: draft.missingFields.joined(separator: "、"))
                    }

                    if let lastErrorMessage = draft.lastErrorMessage, !lastErrorMessage.isEmpty {
                        InfoCallout(title: "解析提醒", detail: lastErrorMessage)
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("來源資訊")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    MetadataRow(title: "平台", value: draft.source.rawValue)
                    MetadataRow(title: "內容型別", value: draft.platformContentType.rawValue)
                    MetadataRow(title: "分類建議", value: draft.category == .all ? "待確認" : draft.category.rawValue)
                    MetadataRow(title: "作者", value: draft.authorName.isEmpty ? "待補齊" : draft.authorName)
                    MetadataRow(title: "時間", value: draft.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "未解析")
                    MetadataRow(title: "信心分數", value: "\(Int(draft.metadataConfidence * 100))%")
                }
            }

            if !draft.mediaAssets.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("媒體資產")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            MediaRetentionBadge(policy: draft.mediaRetentionPolicy)
                        }
                        Text("已識別 \(draft.mediaAssets.count) 筆媒體，預設只保存 metadata。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                        MediaAssetListView(assets: draft.mediaAssets)
                    }
                }
            }

            if let payload = draft.sourcePayloadSummary, !payload.commentsPreview.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("評論預覽")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        ForEach(payload.commentsPreview, id: \.self) { comment in
                            Text(comment)
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }

            PrimaryButton(title: "保存到資源庫") {
                saveAction()
            }

            if draft.requiresManualCompletion {
                PrimaryButton(title: "手動補齊後再保存") {
                    manualAction()
                }
            }
        }
    }
}

struct ManualCompleteView: View {
    @Binding var draft: ResourceImportDraft
    let saveAction: () -> Void
    @State private var tagsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("手動補齊")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    Picker("來源平台", selection: $draft.source) {
                        ForEach(ImportSourceType.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    Picker("分類", selection: $draft.category) {
                        ForEach(ResourceCategory.allCases.filter { $0 != .all }) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    Picker("內容型別", selection: $draft.platformContentType) {
                        ForEach(ImportedContentType.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    Picker("媒體保存策略", selection: $draft.mediaRetentionPolicy) {
                        ForEach(MediaRetentionPolicy.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    ThemedTextField(title: "標題", text: $draft.title)
                    ThemedTextField(title: "作者", text: $draft.authorName)
                    ThemedTextField(title: "縮圖 URL", text: $draft.thumbnailURL)
                    ThemedTextField(title: "描述", text: $draft.descriptionText)
                    ThemedTextField(title: "標籤（以逗號分隔）", text: $tagsText)
                }
            }

            if !draft.mediaAssets.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("媒體選擇")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        MediaAssetSelectionList(assets: $draft.mediaAssets)
                    }
                }
            }

            if !draft.resolvedURL.isEmpty {
                CardView {
                    MetadataRow(title: "來源連結", value: draft.resolvedURL)
                }
            }

            PrimaryButton(title: "完成並保存") {
                draft.tags = tagsText
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                draft.importStatus = draft.metadataConfidence < 0.2 ? .failedFallbackSaved : .manualCompleted
                saveAction()
            }
        }
        .onAppear {
            tagsText = draft.tags.joined(separator: ", ")
        }
    }
}
