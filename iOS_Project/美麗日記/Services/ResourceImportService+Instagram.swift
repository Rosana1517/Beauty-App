import Foundation

struct InstagramParser: PlatformParser {
    func parse(url: URL, source: ImportSourceType) async -> ResourceImportDraft {
        await SharedHTMLParser.parse(url: url, source: source) { metadata, _ in
            let path = url.path.lowercased()
            let contentType: ImportedContentType
            if path.contains("/reel/") || path.contains("/reels/") {
                contentType = .video
            } else if path.contains("/p/") {
                contentType = metadata.platformContentType == .unknown ? .imagePost : metadata.platformContentType
            } else {
                contentType = metadata.platformContentType
            }

            let externalID = SharedHTMLParser.matchFirst(in: path, pattern: "/(?:p|reel|reels)/([^/]+)")

            return SharedHTMLParser.makeDraft(
                source: source,
                url: url.absoluteString,
                title: metadata.title.isEmpty ? "Instagram 收藏" : metadata.title,
                description: metadata.descriptionText,
                author: metadata.authorName,
                thumbnailURL: metadata.thumbnailURL,
                canonicalURL: metadata.canonicalURL,
                externalID: externalID.isEmpty ? metadata.externalID : externalID,
                publishedAt: metadata.publishedAt,
                contentType: contentType == .unknown ? .imagePost : contentType,
                tags: metadata.tags,
                rawPayload: metadata
            )
        }
    }
}
