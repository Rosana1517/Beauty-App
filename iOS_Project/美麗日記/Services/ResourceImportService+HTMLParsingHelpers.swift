import Foundation

extension SharedHTMLParser {
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

}
