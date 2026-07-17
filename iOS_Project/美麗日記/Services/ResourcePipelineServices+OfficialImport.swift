import Foundation

struct OfficialMetadataImportGateway: OfficialMetadataImportService {
    private let configuration: PipelineRuntimeConfiguration
    private let client: SupabaseRESTClient?

    init(configuration: PipelineRuntimeConfiguration = .fromRuntime()) {
        self.configuration = configuration
        if configuration.supabaseURL.isEmpty || configuration.supabaseAnonKey.isEmpty {
            self.client = nil
        } else {
            self.client = SupabaseRESTClient(
                baseURL: configuration.supabaseURL,
                anonKey: configuration.supabaseAnonKey
            )
        }
    }

    func parseIfAvailable(
        url: String,
        source: ImportSourceType,
        downloadPolicy: MediaRetentionPolicy = .metadataOnly,
        selectedIndexes: [Int]? = nil,
        needComments: Bool = false
    ) async -> PlatformImportResult? {
        guard let client else { return nil }
        let capability = capability(for: source)
        guard capability.supportsBackendReparse || capability.supportsOfficialOAuth else {
            return nil
        }

        let payload = AuthorizedImportRequest(
            source: source.apiValue,
            url: url,
            downloadPolicy: downloadPolicy.apiValue,
            selectedIndexes: selectedIndexes,
            needComments: needComments
        )

        do {
            let response: AuthorizedImportResponse = try await client.invokeFunction(
                named: configuration.resourceImportFunction,
                payload: payload,
                responseType: AuthorizedImportResponse.self
            )
            return PlatformImportResult(draft: response.draft, xhsPayload: response.xhsPayload)
        } catch {
            return nil
        }
    }

    func capability(for source: ImportSourceType) -> SourcePlatformCapability {
        switch source {
        case .instagram:
            return SourcePlatformCapability(
                source: source,
                supportsOfficialOAuth: !configuration.instagramAppID.isEmpty && !configuration.instagramRedirectURI.isEmpty,
                supportsBackendReparse: client != nil,
                authorizationState: !configuration.instagramAppID.isEmpty && !configuration.instagramRedirectURI.isEmpty ? .oauthReady : .notConfigured,
                note: "Instagram 正式資料建議走 Meta Graph API OAuth + 後端 token 交換，iOS client 只保留授權入口與同步觸發。"
            )
        case .xiaohongshu:
            return SourcePlatformCapability(
                source: source,
                supportsOfficialOAuth: !configuration.xiaohongshuClientID.isEmpty && !configuration.xiaohongshuRedirectURI.isEmpty,
                supportsBackendReparse: client != nil,
                authorizationState: !configuration.xiaohongshuClientID.isEmpty && !configuration.xiaohongshuRedirectURI.isEmpty ? .backendRequired : .notConfigured,
                note: "小紅書正式內容抓取需由後端代理授權與解析；client 只負責送出匯入請求與顯示結果。"
            )
        case .youtube:
            return SourcePlatformCapability(
                source: source,
                supportsOfficialOAuth: false,
                supportsBackendReparse: client != nil,
                authorizationState: .backendRequired,
                note: "YouTube 已可用 Data API 直接抓 metadata；若要做重解析或推薦回寫，建議仍走後端。"
            )
        case .web:
            return SourcePlatformCapability(
                source: source,
                supportsOfficialOAuth: false,
                supportsBackendReparse: client != nil,
                authorizationState: .unavailable,
                note: "一般網頁不需要官方 OAuth，保留公開 metadata 解析與後端重解析。"
            )
        }
    }

    func authorizationURL(for source: ImportSourceType, state: String) -> URL? {
        switch source {
        case .instagram:
            guard !configuration.instagramAppID.isEmpty,
                  !configuration.instagramRedirectURI.isEmpty else { return nil }
            var components = URLComponents(string: "https://api.instagram.com/oauth/authorize")
            components?.queryItems = [
                URLQueryItem(name: "client_id", value: configuration.instagramAppID),
                URLQueryItem(name: "redirect_uri", value: configuration.instagramRedirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: "user_profile,user_media"),
                URLQueryItem(name: "state", value: state)
            ]
            return components?.url
        case .xiaohongshu:
            guard !configuration.xiaohongshuClientID.isEmpty,
                  !configuration.xiaohongshuRedirectURI.isEmpty else { return nil }
            var components = URLComponents(string: "https://open.xiaohongshu.com/oauth2/authorize")
            components?.queryItems = [
                URLQueryItem(name: "client_id", value: configuration.xiaohongshuClientID),
                URLQueryItem(name: "redirect_uri", value: configuration.xiaohongshuRedirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "state", value: state)
            ]
            return components?.url
        case .youtube, .web:
            return nil
        }
    }
}
