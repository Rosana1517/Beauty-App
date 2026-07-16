import Foundation

struct WebPageParser: PlatformParser {
    func parse(url: URL, source: ImportSourceType) async -> ResourceImportDraft {
        await SharedHTMLParser.parse(url: url, source: source) { metadata, _ in
            SharedHTMLParser.makeDraft(
                source: source,
                url: url.absoluteString,
                title: metadata.title,
                description: metadata.descriptionText,
                author: metadata.authorName,
                thumbnailURL: metadata.thumbnailURL,
                canonicalURL: metadata.canonicalURL,
                externalID: metadata.externalID,
                publishedAt: metadata.publishedAt,
                contentType: metadata.platformContentType == .unknown ? .article : metadata.platformContentType,
                tags: metadata.tags,
                rawPayload: metadata
            )
        }
    }
}

enum SharedHTMLParser {
    static func parse(
        url: URL,
        source: ImportSourceType,
        transform: (ParsedMetadataPayload, String) -> ResourceImportDraft
    ) async -> ResourceImportDraft {
        do {
            let html = try await fetchHTML(from: url)
            let payload = extractPayload(from: html, url: url, source: source)
            return transform(payload, html)
        } catch {
            var draft = ResourceImportDraft.empty(url: url.absoluteString)
            draft.source = source
            draft.category = .other
            draft.platformContentType = fallbackContentType(for: source, path: url.path.lowercased())
            draft.lastErrorMessage = "無法完整抓取 metadata，請手動補齊後保存。"
            draft.metadataConfidence = 0.05
            draft.rawMetadataSnapshot = "{\"fetchError\":\"\(sanitize(error.localizedDescription))\"}"
            return draft
        }
    }

    static func makeDraft(
        source: ImportSourceType,
        url: String,
        title: String,
        description: String,
        author: String,
        thumbnailURL: String,
        canonicalURL: String,
        externalID: String,
        publishedAt: Date?,
        contentType: ImportedContentType,
        tags: [String],
        rawPayload: ParsedMetadataPayload
    ) -> ResourceImportDraft {
        let normalizedTitle = sanitizedText(title)
        let normalizedDescription = sanitizedText(description)
        let confidence = confidenceScore(title: normalizedTitle, description: normalizedDescription, author: author, thumbnailURL: thumbnailURL)
        let status: ResourceImportStatus = normalizedTitle.isEmpty ? .partial : (confidence >= 0.75 ? .parsed : .partial)

        return ResourceImportDraft(
            id: UUID(),
            source: source,
            category: ResourceCategory.suggestedCategory(title: normalizedTitle, description: normalizedDescription, source: source),
            platformContentType: contentType,
            title: normalizedTitle,
            canonicalURL: canonicalURL,
            originalURL: url,
            externalID: externalID,
            authorName: sanitizedText(author),
            thumbnailURL: thumbnailURL,
            publishedAt: publishedAt,
            descriptionText: normalizedDescription,
            tags: tags,
            importStatus: status,
            metadataConfidence: confidence,
            importedAt: nil,
            rawMetadataSnapshot: encodePayload(rawPayload),
            mediaRetentionPolicy: .metadataOnly,
            mediaAssets: [],
            temporaryMediaLeases: [],
            sourcePayloadSummary: nil,
            analysisStatus: .pending,
            aiAnalysis: nil,
            recommendationCards: [],
            syncStatus: .pending,
            remoteRecordID: "",
            lastSyncedAt: nil,
            lastErrorMessage: status == .partial ? "部分欄位仍需手動確認。" : nil
        )
    }

    static func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return String(decoding: data, as: UTF8.self)
    }

    static func extractPayload(from html: String, url: URL, source: ImportSourceType) -> ParsedMetadataPayload {
        let ogTitle = metaContent(in: html, property: "og:title")
        let ogDescription = metaContent(in: html, property: "og:description")
        let ogImage = metaContent(in: html, property: "og:image")
        let ogURL = metaContent(in: html, property: "og:url")
        let twitterTitle = metaContent(in: html, property: "twitter:title")
        let twitterDescription = metaContent(in: html, property: "twitter:description")
        let authorMeta = metaContent(in: html, property: "author")
        let pageTitle = extractTitle(in: html)
        let jsonLD = extractJSONLD(in: html)

        let title = firstNonEmpty([
            jsonLD["headline"],
            jsonLD["name"],
            ogTitle,
            twitterTitle,
            pageTitle
        ])

        let description = firstNonEmpty([
            jsonLD["description"],
            ogDescription,
            twitterDescription
        ])

        let author = firstNonEmpty([
            jsonLD["authorName"],
            jsonLD["creator"],
            authorMeta,
            matchFirst(in: html, pattern: "\"owner_username\"\\s*:\\s*\"([^\"]+)\""),
            matchFirst(in: html, pattern: "\"nickname\"\\s*:\\s*\"([^\"]+)\""),
            matchFirst(in: html, pattern: "\"author\"\\s*:\\s*\\{[^\\}]*\"name\"\\s*:\\s*\"([^\"]+)\""),
            matchFirst(in: html, pattern: "\"user\"\\s*:\\s*\\{[^\\}]*\"nickname\"\\s*:\\s*\"([^\"]+)\"")
        ])

        let thumbnail = firstNonEmpty([
            jsonLD["image"],
            ogImage,
            metaContent(in: html, property: "twitter:image")
        ])

        let canonical = firstNonEmpty([
            ogURL,
            linkHref(in: html, rel: "canonical"),
            url.absoluteString
        ])

        let publishedAt = isoDate(from: firstNonEmpty([
            jsonLD["datePublished"],
            jsonLD["uploadDate"],
            metaContent(in: html, property: "article:published_time"),
            matchFirst(in: html, pattern: "\"time\"\\s*:\\s*\"([^\"]+)\"")
        ]))

        let tags = extractTags(from: html, jsonLDKeywords: jsonLD["keywords"])

        return ParsedMetadataPayload(
            title: title,
            descriptionText: description,
            authorName: author,
            thumbnailURL: thumbnail,
            canonicalURL: canonical,
            externalID: jsonLD["identifier"] ?? "",
            publishedAt: publishedAt,
            platformContentType: inferContentType(source: source, url: url, html: html, jsonLDType: jsonLD["@type"]),
            tags: tags,
            htmlTitle: pageTitle,
            pageHost: url.host ?? ""
        )
    }

}
