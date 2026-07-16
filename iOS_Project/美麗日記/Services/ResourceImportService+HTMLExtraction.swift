import Foundation

extension SharedHTMLParser {
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

}
