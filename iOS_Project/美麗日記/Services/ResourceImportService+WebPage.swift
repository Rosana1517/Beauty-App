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

    static func encodePayload(_ payload: ParsedMetadataPayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(payload), let text = String(data: data, encoding: .utf8) else {
            return ""
        }

        return text
    }

    static func sanitizedText(_ value: String) -> String {
        sanitize(value.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " "))
    }

    static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\"", with: "'")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func confidenceScore(title: String, description: String, author: String, thumbnailURL: String) -> Double {
        var score = 0.0
        if !title.isEmpty { score += 0.45 }
        if !description.isEmpty { score += 0.2 }
        if !author.isEmpty { score += 0.15 }
        if !thumbnailURL.isEmpty { score += 0.15 }
        if !description.isEmpty && description != title { score += 0.05 }
        return min(score, 1)
    }

    static func fallbackContentType(for source: ImportSourceType, path: String) -> ImportedContentType {
        switch source {
        case .youtube:
            return .video
        case .instagram:
            return path.contains("/reel/") || path.contains("/reels/") ? .video : .imagePost
        case .xiaohongshu:
            return .imagePost
        case .web:
            return .article
        }
    }

    static func inferContentType(source: ImportSourceType, url: URL, html: String, jsonLDType: String?) -> ImportedContentType {
        let path = url.path.lowercased()
        if source == .youtube || path.contains("/reel/") || path.contains("/shorts/") {
            return .video
        }
        if let jsonLDType {
            let lowered = jsonLDType.lowercased()
            if lowered.contains("video") {
                return .video
            }
            if lowered.contains("article") || lowered.contains("newsarticle") || lowered.contains("blogposting") {
                return .article
            }
        }
        if html.lowercased().contains("carousel") || html.lowercased().contains("sidecar") {
            return .carousel
        }
        return source == .web ? .article : .imagePost
    }

    static func metaContent(in html: String, property: String) -> String {
        let patterns = [
            "<meta[^>]+property=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"'][^>]+content=[\"']([^\"']+)[\"'][^>]*>",
            "<meta[^>]+name=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"'][^>]+content=[\"']([^\"']+)[\"'][^>]*>",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"'][^>]*>",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+name=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"'][^>]*>"
        ]

        for pattern in patterns {
            let value = matchFirst(in: html, pattern: pattern)
            if !value.isEmpty {
                return decodeHTML(value)
            }
        }

        return ""
    }

    static func linkHref(in html: String, rel: String) -> String {
        let patterns = [
            "<link[^>]+rel=[\"']\(NSRegularExpression.escapedPattern(for: rel))[\"'][^>]+href=[\"']([^\"']+)[\"'][^>]*>",
            "<link[^>]+href=[\"']([^\"']+)[\"'][^>]+rel=[\"']\(NSRegularExpression.escapedPattern(for: rel))[\"'][^>]*>"
        ]

        for pattern in patterns {
            let value = matchFirst(in: html, pattern: pattern)
            if !value.isEmpty {
                return decodeHTML(value)
            }
        }

        return ""
    }

    static func extractTitle(in html: String) -> String {
        decodeHTML(matchFirst(in: html, pattern: "<title[^>]*>(.*?)</title>"))
    }

    static func extractTags(from html: String, jsonLDKeywords: String?) -> [String] {
        let keywordText = firstNonEmpty([
            jsonLDKeywords,
            metaContent(in: html, property: "keywords"),
            matchFirst(in: html, pattern: "\"keywords\"\\s*:\\s*\"([^\"]+)\"")
        ])

        let tags = keywordText
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "|" || $0 == "#" })
            .map { sanitize(String($0)) }
            .filter { !$0.isEmpty }

        return Array(NSOrderedSet(array: tags)) as? [String] ?? []
    }

    static func extractJSONLD(in html: String) -> [String: String] {
        let pattern = "<script[^>]+type=[\"']application/ld\\+json[\"'][^>]*>(.*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return [:]
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)
        let decoder = JSONDecoder()

        for match in matches {
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: html) else { continue }
            let rawJSON = html[range].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = rawJSON.data(using: .utf8) else { continue }

            if let object = try? decoder.decode(JSONLDNode.self, from: data) {
                return object.flattened()
            }

            if let array = try? decoder.decode([JSONLDNode].self, from: data), let first = array.first {
                return first.flattened()
            }
        }

        return [:]
    }

    static func matchFirst(in text: String, pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return ""
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange), match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return ""
        }

        return decodeHTML(String(text[range]))
    }

    static func matchAll(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return decodeHTML(String(text[range]))
        }
    }

    static func youtubeID(from url: URL) -> String? {
        if url.host?.contains("youtu.be") == true {
            return url.pathComponents.dropFirst().first
        }

        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let value = queryItems.first(where: { $0.name == "v" })?.value,
           !value.isEmpty {
            return value
        }

        return matchFirst(in: url.path, pattern: "/shorts/([^/]+)").nilIfEmpty
    }

    static func isoDate(from value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    static func firstNonEmpty(_ candidates: [String?]) -> String {
        for candidate in candidates {
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return decodeHTML(trimmed)
            }
        }
        return ""
    }

    static func decodeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}


struct JSONLDNode: Decodable {
    let type: String?
    let headline: String?
    let name: String?
    let description: String?
    let keywords: String?
    let datePublished: String?
    let uploadDate: String?
    let identifier: String?
    let creator: StringOrObject?
    let author: StringOrObject?
    let image: StringOrArrayOrObject?

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case headline
        case name
        case description
        case keywords
        case datePublished
        case uploadDate
        case identifier
        case creator
        case author
        case image
    }

    func flattened() -> [String: String] {
        [
            "@type": type ?? "",
            "headline": headline ?? "",
            "name": name ?? "",
            "description": description ?? "",
            "keywords": keywords ?? "",
            "datePublished": datePublished ?? "",
            "uploadDate": uploadDate ?? "",
            "identifier": identifier ?? "",
            "creator": creator?.stringValue ?? "",
            "authorName": author?.stringValue ?? "",
            "image": image?.stringValue ?? ""
        ]
    }
}

enum StringOrObject: Decodable {
    case string(String)
    case object(NameValue)
    case objects([NameValue])

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .object(let value):
            return value.name ?? value.value ?? ""
        case .objects(let values):
            return values.compactMap { $0.name ?? $0.value }.first ?? ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode(NameValue.self) {
            self = .object(value)
            return
        }
        self = .objects((try? container.decode([NameValue].self)) ?? [])
    }
}

enum StringOrArrayOrObject: Decodable {
    case string(String)
    case array([String])
    case object(NameValue)

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .array(let values):
            return values.first ?? ""
        case .object(let value):
            return value.url ?? value.name ?? value.value ?? ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let values = try? container.decode([String].self) {
            self = .array(values)
            return
        }
        self = .object((try? container.decode(NameValue.self)) ?? NameValue(name: nil, value: nil, url: nil, id: nil))
    }
}

struct NameValue: Decodable {
    let name: String?
    let value: String?
    let url: String?
    let id: String?

    enum CodingKeys: String, CodingKey {
        case name
        case value
        case url
        case id = "@id"
    }
}


