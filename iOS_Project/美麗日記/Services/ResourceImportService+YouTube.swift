import Foundation

struct YouTubeParser: PlatformParser {
    let apiKey: String

    func parse(url: URL, source: ImportSourceType) async -> ResourceImportDraft {
        if let videoID = SharedHTMLParser.youtubeID(from: url),
           !apiKey.isEmpty,
           let apiDraft = await YouTubeDataAPIParser(apiKey: apiKey).parse(videoID: videoID, originalURL: url.absoluteString) {
            return apiDraft
        }

        return await SharedHTMLParser.parse(url: url, source: source) { metadata, _ in
            let externalID = SharedHTMLParser.youtubeID(from: url) ?? metadata.externalID
            return SharedHTMLParser.makeDraft(
                source: source,
                url: url.absoluteString,
                title: metadata.title.isEmpty ? "YouTube 收藏" : metadata.title,
                description: metadata.descriptionText,
                author: metadata.authorName,
                thumbnailURL: metadata.thumbnailURL,
                canonicalURL: metadata.canonicalURL,
                externalID: externalID,
                publishedAt: metadata.publishedAt,
                contentType: .video,
                tags: metadata.tags,
                rawPayload: metadata
            )
        }
    }
}

struct YouTubeDataAPIParser {
    let apiKey: String

    func parse(videoID: String, originalURL: String) async -> ResourceImportDraft? {
        guard !apiKey.isEmpty else { return nil }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
            URLQueryItem(name: "id", value: videoID),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components?.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }

            let decoded = try JSONDecoder.youtube.decode(YouTubeVideosResponse.self, from: data)
            guard let item = decoded.items.first else { return nil }

            let payload = ParsedMetadataPayload(
                title: item.snippet.title,
                descriptionText: item.snippet.description,
                authorName: item.snippet.channelTitle,
                thumbnailURL: item.snippet.bestThumbnailURL,
                canonicalURL: "https://www.youtube.com/watch?v=\(item.id)",
                externalID: item.id,
                publishedAt: item.snippet.publishedAt,
                platformContentType: .video,
                tags: item.snippet.tags ?? [],
                htmlTitle: item.snippet.title,
                pageHost: "youtube.com"
            )

            var draft = SharedHTMLParser.makeDraft(
                source: .youtube,
                url: originalURL,
                title: item.snippet.title,
                description: item.snippet.description,
                author: item.snippet.channelTitle,
                thumbnailURL: item.snippet.bestThumbnailURL,
                canonicalURL: "https://www.youtube.com/watch?v=\(item.id)",
                externalID: item.id,
                publishedAt: item.snippet.publishedAt,
                contentType: .video,
                tags: item.snippet.tags ?? [],
                rawPayload: payload
            )
            draft.importStatus = .parsed
            draft.metadataConfidence = max(draft.metadataConfidence, 0.95)
            draft.lastErrorMessage = "已使用 YouTube Data API 取得正式 metadata。"
            return draft
        } catch {
            return nil
        }
    }
}


struct YouTubeVideosResponse: Decodable {
    let items: [YouTubeVideoItem]
}

struct YouTubeVideoItem: Decodable {
    let id: String
    let snippet: YouTubeVideoSnippet
}

struct YouTubeVideoSnippet: Decodable {
    let publishedAt: Date?
    let channelTitle: String
    let title: String
    let description: String
    let tags: [String]?
    let thumbnails: YouTubeThumbnailMap

    var bestThumbnailURL: String {
        thumbnails.maxres?.url
            ?? thumbnails.standard?.url
            ?? thumbnails.high?.url
            ?? thumbnails.medium?.url
            ?? thumbnails.defaultValue?.url
            ?? ""
    }
}

struct YouTubeThumbnailMap: Decodable {
    let defaultValue: YouTubeThumbnail?
    let medium: YouTubeThumbnail?
    let high: YouTubeThumbnail?
    let standard: YouTubeThumbnail?
    let maxres: YouTubeThumbnail?

    enum CodingKeys: String, CodingKey {
        case defaultValue = "default"
        case medium
        case high
        case standard
        case maxres
    }
}

struct YouTubeThumbnail: Decodable {
    let url: String
}


extension JSONDecoder {
    static var youtube: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}


