import Foundation

struct XHSImportService: PlatformParser {
    let officialImportService: OfficialMetadataImportService

    func parse(url: URL, source: ImportSourceType) async -> ResourceImportDraft {
        let normalized = XHSURLNormalizer.normalize(urlString: url.absoluteString)

        if let authorized = await XHSOfficialImportGateway(officialImportService: officialImportService).parse(
            normalizedURL: normalized,
            needComments: false
        ) {
            return authorized.draft
        }

        return await XHSFallbackParser().parse(
            url: normalized.resolvedURL,
            source: source,
            normalized: normalized
        )
    }
}

struct XHSOfficialImportGateway {
    let officialImportService: OfficialMetadataImportService

    func parse(normalizedURL: XHSNormalizedURL, needComments: Bool) async -> PlatformImportResult? {
        await officialImportService.parseIfAvailable(
            url: normalizedURL.resolvedURL.absoluteString,
            source: .xiaohongshu,
            downloadPolicy: .metadataOnly,
            selectedIndexes: nil,
            needComments: needComments
        )
    }
}

struct XHSFallbackParser {
    func parse(url: URL, source: ImportSourceType, normalized: XHSNormalizedURL) async -> ResourceImportDraft {
        await SharedHTMLParser.parse(url: url, source: source) { metadata, html in
            let payload = XHSDraftMapper.makePayload(
                normalized: normalized,
                metadata: metadata,
                html: html,
                originalURL: url.absoluteString
            )
            return XHSDraftMapper.makeDraft(from: payload, originalURL: url.absoluteString)
        }
    }
}

struct XHSNormalizedURL {
    let resolvedURL: URL
    let identifier: XHSNoteIdentifier
}

enum XHSURLNormalizer {
    static func normalize(urlString: String) -> XHSNormalizedURL {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            return XHSNormalizedURL(
                resolvedURL: URL(string: "https://www.xiaohongshu.com")!,
                identifier: XHSNoteIdentifier(noteID: "", authorID: "", canonicalURL: "", shareURL: trimmed, xsecToken: "")
            )
        }

        let path = url.path
        let noteID = SharedHTMLParser.matchFirst(in: path, pattern: "/(?:explore|discovery/item|user/profile/[^/]+)/([A-Za-z0-9_-]+)")
        let authorID = SharedHTMLParser.matchFirst(in: path, pattern: "/user/profile/([^/]+)/")
        let xsecToken = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.lowercased() == "xsec_token" })?
            .value ?? ""

        return XHSNormalizedURL(
            resolvedURL: url,
            identifier: XHSNoteIdentifier(
                noteID: noteID,
                authorID: authorID,
                canonicalURL: url.absoluteString,
                shareURL: trimmed,
                xsecToken: xsecToken
            )
        )
    }
}

enum XHSMediaDeriver {
    static func derive(from html: String, metadata: ParsedMetadataPayload) -> (XHSNoteContentType, [XHSMediaAsset]) {
        let lowered = html.lowercased()
        let imageURLs = uniqueURLs(
            SharedHTMLParser.matchAll(in: html, pattern: #"(https?:\\?/\\?/[^"'\\\s>]+(?:jpg|jpeg|png|webp))"#)
                .map(unescapeURL)
        )
        let videoURLs = uniqueURLs(
            SharedHTMLParser.matchAll(in: html, pattern: #"(https?:\\?/\\?/[^"'\\\s>]+(?:mp4|m3u8))"#)
                .map(unescapeURL)
        )

        let contentType: XHSNoteContentType
        if lowered.contains("livephoto") || lowered.contains("live_photo") {
            contentType = .livePhoto
        } else if !videoURLs.isEmpty || metadata.platformContentType == .video {
            contentType = .video
        } else if imageURLs.count > 1 {
            contentType = .carousel
        } else if imageURLs.count == 1 {
            contentType = .imagePost
        } else {
            contentType = .unknown
        }

        var assets: [XHSMediaAsset] = []
        for (index, url) in imageURLs.enumerated() {
            assets.append(
                XHSMediaAsset(
                    id: UUID(),
                    assetID: "xhs-image-\(index)",
                    type: contentType == .livePhoto ? .livePhoto : .image,
                    remoteURL: url,
                    previewURL: url,
                    width: nil,
                    height: nil,
                    duration: nil,
                    index: index,
                    retentionPolicy: .metadataOnly,
                    localStoragePath: nil,
                    checksum: nil,
                    isSelectedForImport: true,
                    expiresAt: nil
                )
            )
        }

        if let videoURL = videoURLs.first {
            assets.insert(
                XHSMediaAsset(
                    id: UUID(),
                    assetID: "xhs-video-0",
                    type: .video,
                    remoteURL: videoURL,
                    previewURL: metadata.thumbnailURL,
                    width: nil,
                    height: nil,
                    duration: nil,
                    index: 0,
                    retentionPolicy: .metadataOnly,
                    localStoragePath: nil,
                    checksum: nil,
                    isSelectedForImport: true,
                    expiresAt: nil
                ),
                at: 0
            )
        }

        if !metadata.thumbnailURL.isEmpty, assets.allSatisfy({ $0.previewURL != metadata.thumbnailURL }) {
            assets.insert(
                XHSMediaAsset(
                    id: UUID(),
                    assetID: "xhs-cover",
                    type: .cover,
                    remoteURL: metadata.thumbnailURL,
                    previewURL: metadata.thumbnailURL,
                    width: nil,
                    height: nil,
                    duration: nil,
                    index: -1,
                    retentionPolicy: .metadataOnly,
                    localStoragePath: nil,
                    checksum: nil,
                    isSelectedForImport: true,
                    expiresAt: nil
                ),
                at: 0
            )
        }

        return (contentType, assets)
    }

    private static func uniqueURLs(_ urls: [String]) -> [String] {
        var seen = Set<String>()
        return urls.filter { url in
            guard !url.isEmpty, !seen.contains(url) else { return false }
            seen.insert(url)
            return true
        }
    }

    private static func unescapeURL(_ value: String) -> String {
        value.replacingOccurrences(of: "\\/", with: "/")
    }
}

enum XHSDraftMapper {
    static func makePayload(
        normalized: XHSNormalizedURL,
        metadata: ParsedMetadataPayload,
        html: String,
        originalURL: String
    ) -> XHSParsedPayload {
        let (contentType, assets) = XHSMediaDeriver.derive(from: html, metadata: metadata)
        let authorID = normalized.identifier.authorID.isEmpty
            ? SharedHTMLParser.matchFirst(in: html, pattern: "\"author_id\"\\s*:\\s*\"([^\"]+)\"")
            : normalized.identifier.authorID
        let likeCount = Int(SharedHTMLParser.matchFirst(in: html, pattern: "\"liked_count\"\\s*:\\s*\"?(\\d+)\"?"))
        let comments = SharedHTMLParser.matchAll(in: html, pattern: "\"content\"\\s*:\\s*\"([^\"]{4,120})\"")

        return XHSParsedPayload(
            identifier: XHSNoteIdentifier(
                noteID: normalized.identifier.noteID.isEmpty ? metadata.externalID : normalized.identifier.noteID,
                authorID: authorID,
                canonicalURL: metadata.canonicalURL.isEmpty ? normalized.identifier.canonicalURL : metadata.canonicalURL,
                shareURL: normalized.identifier.shareURL.isEmpty ? originalURL : normalized.identifier.shareURL,
                xsecToken: normalized.identifier.xsecToken
            ),
            title: metadata.title.isEmpty ? "小紅書收藏" : metadata.title,
            description: metadata.descriptionText,
            author: XHSAuthorProfile(
                authorID: authorID,
                name: metadata.authorName,
                avatarURL: "",
                noteCountSummary: likeCount.map { "點讚 \($0)" } ?? ""
            ),
            likeCount: likeCount,
            tags: metadata.tags,
            publishedAt: metadata.publishedAt,
            contentType: contentType,
            mediaAssets: assets,
            commentsPreview: Array(comments.prefix(3)),
            rawSnapshot: SharedHTMLParser.sanitize(html.prefix(6000).description)
        )
    }

    static func makeDraft(from payload: XHSParsedPayload, originalURL: String) -> ResourceImportDraft {
        var draft = SharedHTMLParser.makeDraft(
            source: .xiaohongshu,
            url: originalURL,
            title: payload.title,
            description: payload.description,
            author: payload.author.name,
            thumbnailURL: payload.mediaAssets.first?.displayURL ?? "",
            canonicalURL: payload.identifier.canonicalURL,
            externalID: payload.identifier.noteID,
            publishedAt: payload.publishedAt,
            contentType: payload.importedContentType,
            tags: payload.tags,
            rawPayload: ParsedMetadataPayload(
                title: payload.title,
                descriptionText: payload.description,
                authorName: payload.author.name,
                thumbnailURL: payload.mediaAssets.first?.displayURL ?? "",
                canonicalURL: payload.identifier.canonicalURL,
                externalID: payload.identifier.noteID,
                publishedAt: payload.publishedAt,
                platformContentType: payload.importedContentType,
                tags: payload.tags,
                htmlTitle: payload.title,
                pageHost: "xiaohongshu.com"
            )
        )
        draft.platformContentType = payload.importedContentType
        draft.mediaRetentionPolicy = .metadataOnly
        draft.mediaAssets = payload.mediaAssets
        draft.sourcePayloadSummary = payload
        draft.thumbnailURL = payload.mediaAssets.first?.displayURL ?? draft.thumbnailURL
        draft.lastErrorMessage = draft.importStatus == .partial ? "部分欄位仍需手動確認。" : nil
        return draft
    }
}


extension XHSParsedPayload {
    var importedContentType: ImportedContentType {
        switch contentType {
        case .video:
            return .video
        case .imagePost:
            return .imagePost
        case .carousel, .livePhoto:
            return .carousel
        case .unknown:
            return .unknown
        }
    }
}

