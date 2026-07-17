import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: AppTheme.shadow, radius: 16, y: 8)
    }
}

struct StatusBadge: View {
    let status: ResourceImportStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .parsed:
            return AppTheme.primary
        case .partial:
            return .orange
        case .manualCompleted:
            return .blue
        case .failedFallbackSaved:
            return .pink
        }
    }
}

struct RuntimeStatusChip: View {
    let title: String
    let active: Bool
    let activeDetail: String
    let inactiveDetail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(active ? AppTheme.success : AppTheme.subtext)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
            }

            Text(active ? activeDetail : inactiveDetail)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct MetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct InfoCallout: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(AppTheme.text)
                .accessibilityIdentifier("infoCallout.detail")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct MediaRetentionBadge: View {
    let policy: MediaRetentionPolicy

    var body: some View {
        Text(policy.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(policyColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(policyColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var policyColor: Color {
        switch policy {
        case .metadataOnly:
            return AppTheme.primary
        case .temporaryCache:
            return .orange
        case .explicitKeep:
            return .blue
        }
    }
}

struct MediaAssetListView: View {
    let assets: [XHSMediaAsset]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(assets) { asset in
                HStack(spacing: 12) {
                    ThumbnailPreview(thumbnailURL: asset.displayURL, size: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assetTypeLabel(asset.type))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text(asset.displayURL)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                            .lineLimit(1)
                        if let expiresAt = asset.expiresAt {
                            Text("到期：\(expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    MediaRetentionBadge(policy: asset.retentionPolicy)
                }
            }
        }
    }

    private func assetTypeLabel(_ type: XHSMediaAssetType) -> String {
        switch type {
        case .image:
            return "圖片"
        case .video:
            return "影片"
        case .cover:
            return "封面"
        case .livePhoto:
            return "LivePhoto"
        case .unknown:
            return "未知"
        }
    }
}

struct MediaAssetSelectionList: View {
    @Binding var assets: [XHSMediaAsset]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(assets.indices), id: \.self) { index in
                Button {
                    assets[index].isSelectedForImport.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: assets[index].isSelectedForImport ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(assets[index].isSelectedForImport ? AppTheme.primary : AppTheme.subtext)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(assets[index].type.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(assets[index].displayURL)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtext)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("#\(max(assets[index].index, 0) + 1)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    .padding(12)
                    .background(AppTheme.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct MetadataHero: View {
    let title: String
    let subtitle: String
    let sourceLabel: String
    let thumbnailURL: String
    let mediaAssets: [XHSMediaAsset]

    init(draft: ResourceImportDraft) {
        self.title = draft.title.isEmpty ? "尚未解析出標題" : draft.title
        self.subtitle = draft.descriptionText.isEmpty ? draft.resolvedURL : draft.descriptionText
        self.sourceLabel = "\(draft.source.rawValue) · \(draft.platformContentType.rawValue)"
        self.thumbnailURL = draft.thumbnailURL
        self.mediaAssets = draft.selectedMediaAssets.isEmpty ? draft.mediaAssets : draft.selectedMediaAssets
    }

    init(item: ResourceItem) {
        self.title = item.title
        self.subtitle = item.displaySummary
        self.sourceLabel = "\(item.source.rawValue) · \(item.platformContentType.rawValue)"
        self.thumbnailURL = item.thumbnailURL
        self.mediaAssets = item.selectedMediaAssets
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ThumbnailPreview(thumbnailURL: mediaAssets.first?.displayURL ?? thumbnailURL)

            VStack(alignment: .leading, spacing: 6) {
                Text(sourceLabel)
                    .font(.caption)
                    .foregroundStyle(AppTheme.primary)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                    .accessibilityIdentifier("metadataHero.title")
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                    .lineLimit(4)
            }
        }
    }
}

struct ThumbnailPreview: View {
    let thumbnailURL: String
    var size: CGFloat = 92

    var body: some View {
        Group {
            if let url = URL(string: thumbnailURL), !thumbnailURL.isEmpty {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.primarySoft)
                        .overlay(ProgressView().tint(AppTheme.primary))
                }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.primarySoft)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(AppTheme.primary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
