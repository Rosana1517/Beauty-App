import Foundation

extension SharedHTMLParser {
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
