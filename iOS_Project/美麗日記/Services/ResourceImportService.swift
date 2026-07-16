import Foundation

import Foundation

protocol ResourceImportService {
    func parse(url: String) async -> ResourceImportDraft
}

struct CompositeResourceImportService: ResourceImportService {
    private let configuration: ImportServiceConfiguration
    private let officialImportService: OfficialMetadataImportService

    init(
        configuration: ImportServiceConfiguration = .fromRuntime(),
        officialImportService: OfficialMetadataImportService = OfficialMetadataImportGateway()
    ) {
        self.configuration = configuration
        self.officialImportService = officialImportService
    }

    func parse(url: String) async -> ResourceImportDraft {
        let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let requestURL = URL(string: normalizedURL), !normalizedURL.isEmpty else {
            var draft = ResourceImportDraft.empty(url: url)
            draft.lastErrorMessage = "請先輸入有效的連結。"
            return draft
        }

        let source = ImportSourceType.detectedSource(from: normalizedURL)
        if let authorizedDraft = await officialImportService.parseIfAvailable(
            url: normalizedURL,
            source: source,
            downloadPolicy: .metadataOnly,
            selectedIndexes: nil,
            needComments: false
        ) {
            return authorizedDraft.draft
        }
        let parser: any PlatformParser

        switch source {
        case .xiaohongshu:
            parser = XHSImportService(officialImportService: officialImportService)
        case .instagram:
            parser = InstagramParser()
        case .youtube:
            parser = YouTubeParser(apiKey: configuration.youtubeAPIKey)
        case .web:
            parser = WebPageParser()
        }

        return await parser.parse(url: requestURL, source: source)
    }
}

struct ImportServiceConfiguration {
    let youtubeAPIKey: String
    let supabaseURL: String
    let supabaseAnonKey: String

    static func fromRuntime() -> ImportServiceConfiguration {
        ImportServiceConfiguration(
            youtubeAPIKey: AppRuntimeConfiguration.youtubeAPIKey,
            supabaseURL: AppRuntimeConfiguration.supabaseURL,
            supabaseAnonKey: AppRuntimeConfiguration.supabaseAnonKey
        )
    }
}

protocol PlatformParser {
    func parse(url: URL, source: ImportSourceType) async -> ResourceImportDraft
}


