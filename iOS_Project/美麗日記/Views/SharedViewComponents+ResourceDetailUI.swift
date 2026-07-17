import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct ResourceListCard: View {
    let item: ResourceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                    Text("\(item.source.rawValue) · \(item.platformContentType.rawValue) · \(item.category.rawValue)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }
                Spacer()
                StatusBadge(status: item.importStatus)
            }

            Text(item.displaySummary)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
                .lineLimit(2)

            HStack {
                MediaRetentionBadge(policy: item.mediaRetentionPolicy)
                if !item.selectedMediaAssets.isEmpty {
                    Text("媒體 \(item.selectedMediaAssets.count) 筆")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.subtext)
                }
                Spacer()
                if !item.temporaryMediaLeases.isEmpty {
                    Text("暫存 \(item.temporaryMediaLeases.count)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            if !item.authorName.isEmpty || !item.tags.isEmpty {
                HStack {
                    if !item.authorName.isEmpty {
                        Text("作者：\(item.authorName)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    Spacer()
                    if !item.tags.isEmpty {
                        Text(item.tags.prefix(2).joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// 解析描述欄位裡「📋 教學步驟：\n1. xxx\n2. xxx」這段條列文字，
/// 讓詳情頁能把每一步跟對應的畫面截圖（若有）配對顯示。
enum TeachingStepParser {
    static let marker = "📋 教學步驟"

    static func parse(_ description: String) -> [(index: Int, text: String)] {
        guard let range = description.range(of: marker) else { return [] }
        let after = description[range.upperBound...]
        var results: [(Int, String)] = []
        for line in after.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let dotIndex = trimmed.firstIndex(where: { $0 == "." || $0 == "、" }) else { continue }
            let numberPart = trimmed[trimmed.startIndex..<dotIndex]
            guard let number = Int(numberPart) else { continue }
            let text = trimmed[trimmed.index(after: dotIndex)...].trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            results.append((number, text))
        }
        return results
    }

    static func stripSteps(from description: String) -> String {
        guard let range = description.range(of: marker) else { return description }
        return String(description[description.startIndex..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ResourceDetailView: View {
    let item: ResourceItem

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "資源詳情") {}

                let stepShots = Dictionary(uniqueKeysWithValues: item.mediaAssets
                    .filter { $0.assetID.hasPrefix("step-") && !$0.displayURL.isEmpty }
                    .map { ($0.index, $0.displayURL) })
                let parsedSteps = TeachingStepParser.parse(item.descriptionText)

                let carouselAssets = item.mediaAssets
                    .filter { ($0.type == .image || $0.type == .cover) && !$0.assetID.hasPrefix("step-") && !$0.displayURL.isEmpty }
                    .sorted { $0.index < $1.index }
                if !carouselAssets.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("圖片（\(carouselAssets.count) 張，左右滑動）")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            TabView {
                                ForEach(carouselAssets) { asset in
                                    AsyncImage(url: URL(string: asset.displayURL)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                        case .failure:
                                            VStack(spacing: 6) {
                                                Image(systemName: "photo")
                                                    .font(.title)
                                                Text("圖片載入失敗")
                                                    .font(.caption)
                                            }
                                            .foregroundStyle(AppTheme.subtext)
                                        default:
                                            ProgressView()
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .always))
                            .indexViewStyle(.page(backgroundDisplayMode: .always))
                            .frame(height: 360)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }

                if !parsedSteps.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("📋 教學步驟")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)

                            ForEach(parsedSteps, id: \.index) { step in
                                HStack(alignment: .top, spacing: 12) {
                                    if let shotURL = stepShots[step.index] {
                                        AsyncImage(url: URL(string: shotURL)) { phase in
                                            if case .success(let image) = phase {
                                                image.resizable().scaledToFill()
                                            } else {
                                                AppTheme.primarySoft
                                            }
                                        }
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    Text("\(step.index). \(step.text)")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(10)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        MetadataHero(item: item)
                        let descriptionWithoutSteps = TeachingStepParser.stripSteps(from: item.descriptionText)
                        if !descriptionWithoutSteps.isEmpty {
                            Text(descriptionWithoutSteps)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 小紅書在台灣被網路封鎖，開原文只會看到錯誤頁，故不提供按鈕
                        if item.source != .xiaohongshu,
                           let originalLink = URL(string: item.originalURL.isEmpty ? item.canonicalURL : item.originalURL) {
                            Link(destination: originalLink) {
                                HStack(spacing: 6) {
                                    Image(systemName: "safari")
                                    Text("查看原文")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("詳細欄位")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        MetadataRow(title: "平台", value: item.source.rawValue)
                        MetadataRow(title: "內容型別", value: item.platformContentType.rawValue)
                        MetadataRow(title: "解析狀態", value: item.importStatus.rawValue)
                        MetadataRow(title: "分類", value: item.category.rawValue)
                        MetadataRow(title: "作者", value: item.authorName.isEmpty ? "未提供" : item.authorName)
                        MetadataRow(title: "發佈時間", value: item.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "未解析")
                        MetadataRow(title: "原始連結", value: item.originalURL)
                        MetadataRow(title: "標準連結", value: item.canonicalURL.isEmpty ? "未提供" : item.canonicalURL)
                        MetadataRow(title: "外部 ID", value: item.externalID.isEmpty ? "未提供" : item.externalID)
                        MetadataRow(title: "媒體策略", value: item.mediaRetentionPolicy.rawValue)
                        MetadataRow(title: "媒體數量", value: "\(item.selectedMediaAssets.count)")
                        MetadataRow(title: "匯入時間", value: item.importedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                if !item.selectedMediaAssets.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("媒體清單")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            MediaAssetListView(assets: item.selectedMediaAssets)
                        }
                    }
                }

                if !item.temporaryMediaLeases.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("暫存清理狀態")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            ForEach(item.temporaryMediaLeases) { lease in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lease.storagePath)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.text)
                                            .lineLimit(1)
                                        Text("到期：\(lease.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    Spacer()
                                    Text(lease.cleanupStatus.rawValue)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                                .padding(10)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}
