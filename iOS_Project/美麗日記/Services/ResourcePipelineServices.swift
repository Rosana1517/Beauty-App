import Foundation

struct PipelineRuntimeConfiguration {
    let supabaseURL: String
    let supabaseAnonKey: String
    let supabaseAuthRedirectURL: String
    let syncUserID: String
    let resourceImportFunction: String
    let resourceReparseFunction: String
    let resourceRecommendationFunction: String
    let resourceMediaCleanupFunction: String
    let aiAdviceFunction: String
    let videoTranscribeFunction: String
    let productLookupFunction: String
    let instagramAppID: String
    let instagramRedirectURI: String
    let xiaohongshuClientID: String
    let xiaohongshuRedirectURI: String

    static func fromRuntime() -> PipelineRuntimeConfiguration {
        PipelineRuntimeConfiguration(
            supabaseURL: AppRuntimeConfiguration.supabaseURL,
            supabaseAnonKey: AppRuntimeConfiguration.supabaseAnonKey,
            supabaseAuthRedirectURL: AppRuntimeConfiguration.supabaseAuthRedirectURL,
            syncUserID: AppRuntimeConfiguration.resourceSyncUserID,
            resourceImportFunction: AppRuntimeConfiguration.resourceImportFunction,
            resourceReparseFunction: AppRuntimeConfiguration.resourceReparseFunction,
            resourceRecommendationFunction: AppRuntimeConfiguration.resourceRecommendationFunction,
            resourceMediaCleanupFunction: AppRuntimeConfiguration.resourceMediaCleanupFunction,
            aiAdviceFunction: AppRuntimeConfiguration.aiAdviceFunction,
            videoTranscribeFunction: AppRuntimeConfiguration.videoTranscribeFunction,
            productLookupFunction: AppRuntimeConfiguration.productLookupFunction,
            instagramAppID: AppRuntimeConfiguration.instagramAppID,
            instagramRedirectURI: AppRuntimeConfiguration.instagramRedirectURI,
            xiaohongshuClientID: AppRuntimeConfiguration.xiaohongshuClientID,
            xiaohongshuRedirectURI: AppRuntimeConfiguration.xiaohongshuRedirectURI
        )
    }
}

protocol OfficialMetadataImportService {
    func parseIfAvailable(
        url: String,
        source: ImportSourceType,
        downloadPolicy: MediaRetentionPolicy,
        selectedIndexes: [Int]?,
        needComments: Bool
    ) async -> PlatformImportResult?
    func capability(for source: ImportSourceType) -> SourcePlatformCapability
    func authorizationURL(for source: ImportSourceType, state: String) -> URL?
}

protocol ResourceAnalysisService {
    func analyze(draft: ResourceImportDraft) async -> ResourceImportDraft
}

protocol CloudResourceSyncService {
    func upsertCurrentUserProfile(session: SupabaseAuthSession, profile: UserProfileRecord) async throws
    func fetchCurrentUserProfile(session: SupabaseAuthSession) async throws -> UserProfileRecord?
    func pushResource(_ item: ResourceItem) async throws -> CloudSyncResult
    func fetchResources() async throws -> [ResourceItem]
    func enqueueReparse(for item: ResourceItem, reason: String) async throws -> ResourceSyncQueueItem
    func enqueueMediaCleanup(for item: ResourceItem) async throws -> ResourceSyncQueueItem
    func requestRecommendations(for item: ResourceItem) async throws -> [ResourceRecommendationCard]
    func requestAIAdvice(topic: AIAdviceTopic, concerns: [String]) async throws -> AIAdviceResult
    func requestVideoTranscription(resourceRemoteID: String, videoURL: String) async
    func requestProductLookup(name: String?, imageData: Data?) async throws -> ProductLookupResult?
    func upsertAIProviderSettings(session: SupabaseAuthSession, settings: AIProviderSettings) async throws
    func fetchAIProviderSettings(session: SupabaseAuthSession) async throws -> AIProviderSettings?
    func deleteAIProviderSettings(session: SupabaseAuthSession) async throws
}

struct CloudSyncResult {
    let remoteRecordID: String
    let syncedAt: Date
}

struct AIAdviceResult {
    let suggestions: [String]
    let routineSteps: [String]
    let products: [String]
    var relatedResources: [AIAdviceRelatedResource] = []
}

struct ProductLookupResult {
    let name: String
    let brand: String
    let category: String
    let notes: String
}

struct PlatformImportResult {
    let draft: ResourceImportDraft
    let xhsPayload: XHSParsedPayload?
}

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

struct LocalRuleBasedResourceAnalysisService: ResourceAnalysisService {
    func analyze(draft: ResourceImportDraft) async -> ResourceImportDraft {
        var analyzed = draft
        analyzed.analysisStatus = .analyzed

        let category = draft.category == .all
            ? ResourceCategory.suggestedCategory(title: draft.title, description: draft.descriptionText, source: draft.source)
            : draft.category
        analyzed.category = category

        let summary = makeSummary(draft: analyzed)
        let insights = makeInsights(draft: analyzed, category: category)
        let actions = makeActions(draft: analyzed, category: category)

        analyzed.aiAnalysis = AIAnalysisResult(
            summary: summary,
            insights: insights,
            recommendedActions: actions,
            confidence: max(0.35, min(0.92, analyzed.metadataConfidence)),
            provider: "local-rule-engine",
            generatedAt: Date()
        )
        analyzed.recommendationCards = makeRecommendations(draft: analyzed, category: category, actions: actions)
        return analyzed
    }

    private func makeSummary(draft: ResourceImportDraft) -> String {
        let title = draft.title.isEmpty ? "未命名內容" : draft.title
        switch draft.source {
        case .xiaohongshu:
            return "已整理小紅書內容「\(title)」，適合進一步轉成可執行的日常養成或保養清單。"
        case .instagram:
            return "已整理 Instagram 內容「\(title)」，可延伸為圖文靈感與行動建議。"
        case .youtube:
            return "已整理 YouTube 影片「\(title)」，可提煉重點步驟與後續追蹤項目。"
        case .web:
            return "已整理網頁文章「\(title)」，可轉成知識卡與待執行任務。"
        }
    }

    private func makeInsights(draft: ResourceImportDraft, category: ResourceCategory) -> [String] {
        var insights: [String] = []
        if !draft.authorName.isEmpty {
            insights.append("來源作者：\(draft.authorName)")
        }
        insights.append("系統判定主分類為「\(category.rawValue)」。")
        if draft.platformContentType != .unknown {
            insights.append("內容型別為「\(draft.platformContentType.rawValue)」，適合進行結構化整理。")
        }
        if draft.metadataConfidence < 0.66 {
            insights.append("目前 metadata 完整度偏低，建議補齊標題、作者或描述。")
        }
        return insights
    }

    private func makeActions(draft: ResourceImportDraft, category: ResourceCategory) -> [String] {
        switch category {
        case .skincare:
            return ["加入保養步驟清單", "補一筆膚況紀錄", "建立 7 天追蹤提醒"]
        case .fitness:
            return ["加入運動計畫", "補體重體脂紀錄", "建立每週執行次數"]
        case .food:
            return ["加入飲食記錄模板", "標記高蛋白或低糖重點", "建立採買清單"]
        case .outfit:
            return ["加入靈感收藏", "標記場合與季節", "建立搭配清單"]
        case .learning:
            return ["加入閱讀/觀看清單", "萃取 3 個知識重點", "建立一週複習提醒"]
        case .other, .all:
            return ["補齊分類與標籤", "整理成可執行筆記", "加入稍後回顧清單"]
        }
    }

    private func makeRecommendations(
        draft: ResourceImportDraft,
        category: ResourceCategory,
        actions: [String]
    ) -> [ResourceRecommendationCard] {
        actions.prefix(3).map { action in
            ResourceRecommendationCard(
                id: UUID(),
                title: action,
                detail: draft.title.isEmpty ? "依匯入內容建立後續任務。" : "根據「\(draft.title)」建立可執行建議。",
                category: category == .all ? .other : category,
                reason: draft.source.rawValue
            )
        }
    }
}

struct NoopCloudResourceSyncService: CloudResourceSyncService {
    func upsertCurrentUserProfile(session: SupabaseAuthSession, profile: UserProfileRecord) async throws {}
    func fetchCurrentUserProfile(session: SupabaseAuthSession) async throws -> UserProfileRecord? { nil }

    func pushResource(_ item: ResourceItem) async throws -> CloudSyncResult {
        CloudSyncResult(remoteRecordID: item.remoteRecordID, syncedAt: Date())
    }

    func fetchResources() async throws -> [ResourceItem] {
        []
    }

    func enqueueReparse(for item: ResourceItem, reason: String) async throws -> ResourceSyncQueueItem {
        ResourceSyncQueueItem(
            id: UUID(),
            resourceID: item.id,
            jobType: .reparse,
            syncTarget: "supabase",
            syncStatus: .pending,
            retryCount: 0,
            requestPayload: reason,
            lastErrorMessage: reason,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func enqueueMediaCleanup(for item: ResourceItem) async throws -> ResourceSyncQueueItem {
        ResourceSyncQueueItem(
            id: UUID(),
            resourceID: item.id,
            jobType: .mediaCleanup,
            syncTarget: "supabase",
            syncStatus: .pending,
            retryCount: 0,
            requestPayload: item.mediaRetentionPolicy.rawValue,
            lastErrorMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func requestRecommendations(for item: ResourceItem) async throws -> [ResourceRecommendationCard] {
        []
    }

    func requestAIAdvice(topic: AIAdviceTopic, concerns: [String]) async throws -> AIAdviceResult {
        AIAdviceResult(suggestions: [], routineSteps: [], products: [])
    }

    func requestVideoTranscription(resourceRemoteID: String, videoURL: String) async {}

    func requestProductLookup(name: String?, imageData: Data?) async throws -> ProductLookupResult? {
        nil
    }

    func upsertAIProviderSettings(session: SupabaseAuthSession, settings: AIProviderSettings) async throws {}
    func fetchAIProviderSettings(session: SupabaseAuthSession) async throws -> AIProviderSettings? { nil }
    func deleteAIProviderSettings(session: SupabaseAuthSession) async throws {}
}

struct SupabaseCloudResourceSyncService: CloudResourceSyncService {
    private let configuration: PipelineRuntimeConfiguration
    private let client: SupabaseRESTClient

    init?(configuration: PipelineRuntimeConfiguration = .fromRuntime()) {
        guard !configuration.supabaseURL.isEmpty, !configuration.supabaseAnonKey.isEmpty else {
            return nil
        }
        self.configuration = configuration
        self.client = SupabaseRESTClient(baseURL: configuration.supabaseURL, anonKey: configuration.supabaseAnonKey)
    }

    func upsertCurrentUserProfile(session: SupabaseAuthSession, profile: UserProfileRecord) async throws {
        let payload = SupabaseAppUserPayload(session: session, profile: profile)
        _ = try await client.upsert(
            table: "app_users",
            payload: [payload],
            responseType: [SupabaseAppUserRow].self
        )
    }

    func fetchCurrentUserProfile(session: SupabaseAuthSession) async throws -> UserProfileRecord? {
        let rows: [SupabaseAppUserRow] = try await client.select(
            table: "app_users",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(session.userID)")],
            responseType: [SupabaseAppUserRow].self
        )
        return rows.first?.profile
    }

    func pushResource(_ item: ResourceItem) async throws -> CloudSyncResult {
        let payload = SupabaseResourcePayload(item: item, userID: try resolvedUserID())
        let response: [SupabaseResourceRow] = try await client.upsert(
            table: "resource_items",
            payload: [payload],
            responseType: [SupabaseResourceRow].self
        )

        let remote = response.first
        try await createImportEvent(for: item, remoteRecordID: remote?.id)
        return CloudSyncResult(
            remoteRecordID: remote?.id ?? item.remoteRecordID,
            syncedAt: remote?.updatedAt ?? Date()
        )
    }

    func fetchResources() async throws -> [ResourceItem] {
        let userID = try resolvedUserID()
        let rows: [SupabaseResourceRow] = try await client.select(
            table: "resource_items",
            queryItems: [URLQueryItem(name: "user_id", value: "eq.\(userID)")],
            responseType: [SupabaseResourceRow].self
        )

        // 一次抓回使用者名下所有媒體資產（RLS 已限定 owner），依 resource_id 掛回各筆資源
        var assetsByResource: [String: [SupabaseMediaAssetRow]] = [:]
        if !rows.isEmpty {
            let assetRows: [SupabaseMediaAssetRow] = (try? await client.select(
                table: "resource_media_assets",
                queryItems: [URLQueryItem(name: "order", value: "display_index.asc")],
                responseType: [SupabaseMediaAssetRow].self
            )) ?? []
            assetsByResource = Dictionary(grouping: assetRows, by: \.resourceID)
        }

        return rows.map { row in
            var item = row.resourceItem
            if let assetRows = assetsByResource[row.id], !assetRows.isEmpty {
                item.mediaAssets = assetRows.map(\.mediaAsset)
            }
            return item
        }
    }

    func enqueueReparse(for item: ResourceItem, reason: String) async throws -> ResourceSyncQueueItem {
        let response: SupabaseQueueJobResponse = try await client.invokeFunction(
            named: configuration.resourceReparseFunction,
            payload: ReparseJobRequest(resourceID: item.remoteRecordID.nilIfEmpty ?? item.id.uuidString, reason: reason),
            responseType: SupabaseQueueJobResponse.self
        )

        return ResourceSyncQueueItem(
            id: UUID(uuidString: response.id) ?? UUID(),
            resourceID: item.id,
            jobType: .reparse,
            syncTarget: "supabase",
            syncStatus: ResourceSyncStatus(apiValue: response.syncStatus) ?? .pending,
            retryCount: response.retryCount,
            requestPayload: reason,
            lastErrorMessage: response.lastError,
            createdAt: response.createdAt ?? Date(),
            updatedAt: response.updatedAt ?? Date()
        )
    }

    func enqueueMediaCleanup(for item: ResourceItem) async throws -> ResourceSyncQueueItem {
        let response: SupabaseQueueJobResponse = try await client.invokeFunction(
            named: configuration.resourceMediaCleanupFunction,
            payload: MediaCleanupJobRequest(
                resourceID: item.remoteRecordID.nilIfEmpty ?? item.id.uuidString,
                retentionPolicy: item.mediaRetentionPolicy.apiValue
            ),
            responseType: SupabaseQueueJobResponse.self
        )

        return ResourceSyncQueueItem(
            id: UUID(uuidString: response.id) ?? UUID(),
            resourceID: item.id,
            jobType: .mediaCleanup,
            syncTarget: "supabase",
            syncStatus: ResourceSyncStatus(apiValue: response.syncStatus) ?? .pending,
            retryCount: response.retryCount,
            requestPayload: item.mediaRetentionPolicy.apiValue,
            lastErrorMessage: response.lastError,
            createdAt: response.createdAt ?? Date(),
            updatedAt: response.updatedAt ?? Date()
        )
    }

    func requestRecommendations(for item: ResourceItem) async throws -> [ResourceRecommendationCard] {
        let response: RecommendationFunctionResponse = try await client.invokeFunction(
            named: configuration.resourceRecommendationFunction,
            payload: RecommendationFunctionRequest(resourceID: item.remoteRecordID.nilIfEmpty ?? item.id.uuidString),
            responseType: RecommendationFunctionResponse.self
        )
        return response.cards
    }

    func requestAIAdvice(topic: AIAdviceTopic, concerns: [String]) async throws -> AIAdviceResult {
        let response: AIAdviceFunctionResponse = try await client.invokeFunction(
            named: configuration.aiAdviceFunction,
            payload: AIAdviceFunctionRequest(topic: topic.rawValue, concerns: concerns),
            responseType: AIAdviceFunctionResponse.self
        )
        return AIAdviceResult(
            suggestions: response.suggestions,
            routineSteps: response.routineSteps ?? [],
            products: response.products ?? [],
            relatedResources: response.relatedResources ?? []
        )
    }

    /// 影片筆記同步成功後即時觸發，背景整理教學步驟並回寫描述欄位；
    /// 失敗（例如影片過大、逾時）不影響匯入本身，靜默記錄即可。
    func requestVideoTranscription(resourceRemoteID: String, videoURL: String) async {
        struct EmptyResponse: Decodable {}
        _ = try? await client.invokeFunction(
            named: configuration.videoTranscribeFunction,
            payload: VideoTranscribeFunctionRequest(resourceID: resourceRemoteID, videoURL: videoURL),
            responseType: EmptyResponse.self
        )
    }

    func requestProductLookup(name: String?, imageData: Data?) async throws -> ProductLookupResult? {
        let response: ProductLookupFunctionResponse = try await client.invokeFunction(
            named: configuration.productLookupFunction,
            payload: ProductLookupFunctionRequest(name: name, imageBase64: imageData?.base64EncodedString()),
            responseType: ProductLookupFunctionResponse.self
        )
        guard !response.name.isEmpty else { return nil }
        return ProductLookupResult(
            name: response.name,
            brand: response.brand ?? "",
            category: response.category ?? "",
            notes: response.notes ?? ""
        )
    }

    /// Stored per-user (RLS-scoped to `session.userID`) so each signed-in
    /// person can bring their own AI provider key instead of sharing a
    /// single key baked into the backend's environment variables.
    func upsertAIProviderSettings(session: SupabaseAuthSession, settings: AIProviderSettings) async throws {
        let payload = SupabaseAIProviderSettingsPayload(userID: session.userID, settings: settings)
        _ = try await client.upsert(
            table: "user_ai_provider_settings",
            payload: [payload],
            responseType: [SupabaseAIProviderSettingsRow].self
        )
    }

    func fetchAIProviderSettings(session: SupabaseAuthSession) async throws -> AIProviderSettings? {
        let rows: [SupabaseAIProviderSettingsRow] = try await client.select(
            table: "user_ai_provider_settings",
            queryItems: [URLQueryItem(name: "user_id", value: "eq.\(session.userID)")],
            responseType: [SupabaseAIProviderSettingsRow].self
        )
        return rows.first?.settings
    }

    func deleteAIProviderSettings(session: SupabaseAuthSession) async throws {
        try await client.delete(
            table: "user_ai_provider_settings",
            queryItems: [URLQueryItem(name: "user_id", value: "eq.\(session.userID)")]
        )
    }

    private func createImportEvent(for item: ResourceItem, remoteRecordID: String?) async throws {
        let payload = SupabaseImportEventPayload(item: item, remoteRecordID: remoteRecordID, userID: try resolvedUserID())
        _ = try await client.insert(
            table: "resource_import_events",
            payload: [payload],
            responseType: [SupabaseImportEventRow].self
        )
    }

    private func resolvedUserID() throws -> String {
        let userID = AppRuntimeConfiguration.resourceSyncUserID
        if !userID.isEmpty {
            return userID
        }
        throw SupabaseCloudSyncError.missingUserID
    }
}

private enum SupabaseCloudSyncError: LocalizedError {
    case missingUserID

    var errorDescription: String? {
        switch self {
        case .missingUserID:
            return "No Supabase user session is available for sync."
        }
    }
}

enum SupabaseRESTError: LocalizedError {
    case unauthorized
    case serverMessage(String)
    case invalidResponse
    case unexpectedStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Supabase 登入已過期，請重新登入後再試一次。"
        case .serverMessage(let message):
            return message
        case .invalidResponse:
            return "Supabase 回傳了無法解析的回應。"
        case .unexpectedStatus(let code, let body):
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedBody.isEmpty
                ? "Supabase 回應了非預期的狀態碼 \(code)。"
                : "Supabase 回應了非預期的狀態碼 \(code)：\(trimmedBody)"
        }
    }
}

private struct SupabaseRESTClient {
    let baseURL: String
    let anonKey: String

    func select<Response: Decodable>(
        table: String,
        queryItems: [URLQueryItem],
        responseType: Response.Type
    ) async throws -> Response {
        try await requestWithoutBody(
            path: "/rest/v1/\(table)",
            method: "GET",
            queryItems: queryItems + [URLQueryItem(name: "select", value: "*")],
            responseType: responseType
        )
    }

    func insert<Payload: Encodable, Response: Decodable>(
        table: String,
        payload: Payload,
        responseType: Response.Type
    ) async throws -> Response {
        try await request(
            path: "/rest/v1/\(table)",
            method: "POST",
            queryItems: [],
            body: payload,
            responseType: responseType,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func upsert<Payload: Encodable, Response: Decodable>(
        table: String,
        payload: Payload,
        responseType: Response.Type
    ) async throws -> Response {
        try await request(
            path: "/rest/v1/\(table)",
            method: "POST",
            queryItems: [],
            body: payload,
            responseType: responseType,
            extraHeaders: [
                "Prefer": "resolution=merge-duplicates,return=representation",
                "Content-Type": "application/json"
            ]
        )
    }

    func invokeFunction<Payload: Encodable, Response: Decodable>(
        named functionName: String,
        payload: Payload,
        responseType: Response.Type
    ) async throws -> Response {
        try await request(
            path: "/functions/v1/\(functionName)",
            method: "POST",
            queryItems: [],
            body: payload,
            responseType: responseType,
            // AI 建議等 LLM function 常需 15~30 秒以上，沿用預設 20 秒會頻繁逾時
            timeout: 90
        )
    }

    func delete(table: String, queryItems: [URLQueryItem]) async throws {
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        components.path = "/rest/v1/\(table)"
        components.queryItems = queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 20
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseRESTError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw mappedError(from: data, statusCode: httpResponse.statusCode)
        }
    }

    private func requestWithoutBody<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        responseType: Response.Type,
        extraHeaders: [String: String] = [:]
    ) async throws -> Response {
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        extraHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseRESTError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw mappedError(from: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(responseType, from: data)
    }

    private func request<Payload: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Payload?,
        responseType: Response.Type,
        extraHeaders: [String: String] = [:],
        timeout: TimeInterval = 20
    ) async throws -> Response {
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        extraHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseRESTError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw mappedError(from: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(responseType, from: data)
    }

    private var authorizationToken: String {
        SupabaseSessionStore.currentSession()?.accessToken ?? anonKey
    }

    private func mappedError(from data: Data, statusCode: Int) -> Error {
        if statusCode == 401 {
            return SupabaseRESTError.unauthorized
        }

        // Edge Functions (e.g. ai-advice) return {"error": "..."}, while
        // PostgREST table errors return {"message": "...", "hint": "..."} -
        // check all of them before falling back to a generic status code, so
        // e.g. "No AI provider configured" actually reaches the user instead
        // of a bare NSURLError.
        if let error = try? JSONDecoder().decode(SupabaseRESTErrorResponse.self, from: data) {
            let resolved = error.message ?? error.error ?? error.hint
            if let resolved, !resolved.isEmpty {
                return SupabaseRESTError.serverMessage(resolved)
            }
        }

        let rawBody = String(data: data, encoding: .utf8) ?? ""
        return SupabaseRESTError.unexpectedStatus(statusCode, rawBody)
    }
}

private struct SupabaseRESTErrorResponse: Decodable {
    let message: String?
    let hint: String?
    let error: String?
}

private struct AuthorizedImportRequest: Encodable {
    let source: String
    let url: String
    let downloadPolicy: String
    let selectedIndexes: [Int]?
    let needComments: Bool
}

private struct AuthorizedImportResponse: Decodable {
    let draft: ResourceImportDraft
    let xhsPayload: XHSParsedPayload?
}

private struct ReparseJobRequest: Encodable {
    let resourceID: String
    let reason: String
}

private struct MediaCleanupJobRequest: Encodable {
    let resourceID: String
    let retentionPolicy: String
}

private struct RecommendationFunctionRequest: Encodable {
    let resourceID: String
}

private struct RecommendationFunctionResponse: Decodable {
    let cards: [ResourceRecommendationCard]
}

private struct AIAdviceFunctionRequest: Encodable {
    let topic: String
    let concerns: [String]
}

private struct VideoTranscribeFunctionRequest: Encodable {
    let resourceID: String
    let videoURL: String

    // 明確指定 CodingKeys，不依賴 JSONEncoder.convertToSnakeCase 對
    // "resourceID"/"videoURL" 這類尾端縮寫大寫字母的轉換結果。
    enum CodingKeys: String, CodingKey {
        case resourceID = "resource_id"
        case videoURL = "video_url"
    }
}

private struct AIAdviceFunctionResponse: Decodable {
    let suggestions: [String]
    let routineSteps: [String]?
    let products: [String]?
    let relatedResources: [AIAdviceRelatedResource]?
}

/// AI 建議附帶的資料庫筆記推薦（可加入運動管理、跳轉教學內容）
struct AIAdviceRelatedResource: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let category: String
    let author: String
    let thumbnailURL: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case author
        // convertFromSnakeCase 會把 thumbnail_url 轉成 thumbnailUrl
        case thumbnailURL = "thumbnailUrl"
    }
}

private struct ProductLookupFunctionRequest: Encodable {
    let name: String?
    let imageBase64: String?
}

private struct ProductLookupFunctionResponse: Decodable {
    let name: String
    let brand: String?
    let category: String?
    let notes: String?
}

private struct SupabaseQueueJobResponse: Decodable {
    let id: String
    let syncStatus: String
    let retryCount: Int
    let lastError: String?
    let createdAt: Date?
    let updatedAt: Date?
}

private struct SupabaseResourcePayload: Encodable {
    let id: String?
    let userID: String?
    let sourceType: String
    let contentType: String
    let category: String
    let title: String
    let descriptionText: String
    let authorName: String
    let originalURL: String
    let canonicalURL: String
    let externalID: String
    let thumbnailURL: String
    let publishedAt: Date?
    let tags: [String]
    let importStatus: String
    let metadataConfidence: Double
    let mediaRetentionPolicy: String
    let rawMetadataSnapshot: JSONValue
    let sourcePayload: JSONValue

    init(item: ResourceItem, userID: String) {
        id = item.remoteRecordID.nilIfEmpty
        self.userID = userID.nilIfEmpty
        sourceType = item.source.apiValue
        contentType = item.platformContentType.apiValue
        category = item.category.apiValue
        title = item.title
        descriptionText = item.descriptionText
        authorName = item.authorName
        originalURL = item.originalURL
        canonicalURL = item.canonicalURL
        externalID = item.externalID
        thumbnailURL = item.thumbnailURL
        publishedAt = item.publishedAt
        tags = item.tags
        importStatus = item.importStatus.apiValue
        metadataConfidence = item.metadataConfidence
        mediaRetentionPolicy = item.mediaRetentionPolicy.apiValue
        rawMetadataSnapshot = JSONValue.jsonString(item.rawMetadataSnapshot)
        sourcePayload = JSONValue.dictionary([
            "analysisStatus": .string(item.analysisStatus.apiValue),
            "mediaAssets": .array(item.selectedMediaAssets.map { asset in
                .dictionary([
                    "assetID": .string(asset.assetID),
                    "type": .string(asset.type.rawValue),
                    "remoteURL": .string(asset.remoteURL),
                    "previewURL": .string(asset.previewURL),
                    "retentionPolicy": .string(asset.retentionPolicy.apiValue)
                ])
            }),
            "recommendationCount": .number(Double(item.recommendationCards.count)),
            "syncStatus": .string(item.syncStatus.apiValue)
        ])
    }
}

private struct SupabaseAppUserPayload: Encodable {
    let id: String
    let email: String?
    let nickname: String?
    let streakDays: Int
    let signature: String?
    let bodyFocus: String?
    let skincareFocus: String?
    let themeName: String?
    let notificationTime: String?

    init(session: SupabaseAuthSession, profile: UserProfileRecord) {
        id = session.userID
        email = session.email.nilIfEmpty
        nickname = profile.nickname.nilIfEmpty
        streakDays = profile.streakDays
        signature = profile.signature.nilIfEmpty
        bodyFocus = profile.bodyFocus.nilIfEmpty
        skincareFocus = profile.skincareFocus.nilIfEmpty
        themeName = profile.themeName.nilIfEmpty
        notificationTime = profile.notificationTime.nilIfEmpty
    }
}

private struct SupabaseImportEventPayload: Encodable {
    let resourceID: String?
    let userID: String?
    let sourceType: String
    let requestURL: String
    let resolvedURL: String
    let importerVersion: String
    let status: String
    let errorMessage: String?
    let parserMode: String
    let responseSnapshot: JSONValue

    init(item: ResourceItem, remoteRecordID: String?, userID: String) {
        resourceID = (remoteRecordID ?? item.remoteRecordID).nilIfEmpty
        self.userID = userID.nilIfEmpty
        sourceType = item.source.apiValue
        requestURL = item.originalURL
        resolvedURL = item.resolvedURL
        importerVersion = "v2"
        status = item.importStatus.apiValue
        errorMessage = item.aiAnalysis?.summary
        parserMode = item.source == .youtube ? "youtubeDataAPI" : "manualFallback"
        responseSnapshot = JSONValue.jsonString(item.rawMetadataSnapshot)
    }
}

private struct SupabaseResourceRow: Decodable {
    let id: String
    let userID: String?
    let sourceType: String
    let contentType: String
    let category: String
    let title: String
    let descriptionText: String?
    let authorName: String?
    let originalURL: String
    let canonicalURL: String?
    let externalID: String?
    let thumbnailURL: String?
    let publishedAt: Date?
    let tags: [String]?
    let importStatus: String
    let metadataConfidence: Double?
    let mediaRetentionPolicy: String?
    let rawMetadataSnapshot: JSONValue?
    let createdAt: Date?
    let updatedAt: Date?

    // decoder 的 convertFromSnakeCase 會把 original_url 轉成 originalUrl（小寫 l），
    // 與本結構的 URL/ID 大寫命名不符，必須用 CodingKeys 對回轉換後的鍵名，
    // 否則非 optional 的 originalURL 會讓整批資源解碼失敗。
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case sourceType
        case contentType
        case category
        case title
        case descriptionText
        case authorName
        case originalURL = "originalUrl"
        case canonicalURL = "canonicalUrl"
        case externalID = "externalId"
        case thumbnailURL = "thumbnailUrl"
        case publishedAt
        case tags
        case importStatus
        case metadataConfidence
        case mediaRetentionPolicy
        case rawMetadataSnapshot
        case createdAt
        case updatedAt
    }

    var resourceItem: ResourceItem {
        ResourceItem(
            id: UUID(),
            title: title,
            source: ImportSourceType(apiValue: sourceType) ?? .web,
            category: ResourceCategory(apiValue: category) ?? .other,
            platformContentType: ImportedContentType(apiValue: contentType) ?? .unknown,
            canonicalURL: canonicalURL ?? "",
            originalURL: originalURL,
            externalID: externalID ?? "",
            authorName: authorName ?? "",
            thumbnailURL: thumbnailURL ?? "",
            publishedAt: publishedAt,
            descriptionText: descriptionText ?? "",
            tags: tags ?? [],
            importStatus: ResourceImportStatus(apiValue: importStatus) ?? .partial,
            metadataConfidence: metadataConfidence ?? 0,
            importedAt: createdAt ?? Date(),
            rawMetadataSnapshot: rawMetadataSnapshot?.stringValue ?? "",
            mediaRetentionPolicy: MediaRetentionPolicy(apiValue: mediaRetentionPolicy) ?? .metadataOnly,
            analysisStatus: .pending,
            aiAnalysis: nil,
            recommendationCards: [],
            syncStatus: .succeeded,
            remoteRecordID: id,
            lastSyncedAt: updatedAt
        )
    }
}

private struct SupabaseImportEventRow: Decodable {
    let id: String
}

private struct SupabaseMediaAssetRow: Decodable {
    let id: String
    let resourceID: String
    let assetID: String?
    let assetType: String
    let remoteURL: String
    let previewURL: String?
    let displayIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case resourceID = "resourceId"
        case assetID = "assetId"
        case assetType
        case remoteURL = "remoteUrl"
        case previewURL = "previewUrl"
        case displayIndex
    }

    var mediaAsset: XHSMediaAsset {
        XHSMediaAsset(
            id: UUID(uuidString: id) ?? UUID(),
            assetID: assetID ?? "",
            type: XHSMediaAssetType(rawValue: assetType) ?? .image,
            remoteURL: remoteURL,
            previewURL: previewURL ?? remoteURL,
            width: nil,
            height: nil,
            duration: nil,
            index: displayIndex ?? 0,
            retentionPolicy: .explicitKeep,
            localStoragePath: nil,
            checksum: nil,
            isSelectedForImport: true,
            expiresAt: nil
        )
    }
}

private struct SupabaseAppUserRow: Decodable {
    let id: String
    let email: String?
    let nickname: String?
    let streakDays: Int?
    let signature: String?
    let bodyFocus: String?
    let skincareFocus: String?
    let themeName: String?
    let notificationTime: String?

    var profile: UserProfileRecord {
        UserProfileRecord(
            nickname: nickname ?? "",
            streakDays: streakDays ?? 0,
            signature: signature ?? "",
            bodyFocus: bodyFocus ?? "",
            skincareFocus: skincareFocus ?? "",
            themeName: themeName ?? "",
            notificationTime: notificationTime ?? ""
        )
    }
}

private struct SupabaseAIProviderSettingsPayload: Encodable {
    let userID: String
    let provider: String
    let apiKey: String
    let baseURL: String?
    let model: String?

    init(userID: String, settings: AIProviderSettings) {
        self.userID = userID
        provider = settings.provider.rawValue
        apiKey = settings.apiKey
        baseURL = settings.baseURL.nilIfEmpty
        model = settings.model.nilIfEmpty
    }
}

private struct SupabaseAIProviderSettingsRow: Decodable {
    // `user_id` is intentionally omitted: JSONDecoder's `.convertFromSnakeCase`
    // can't reconstruct the "ID" acronym (it produces "userId", not "userID"),
    // and the field isn't needed here since the query already filters by
    // user_id.
    let provider: String
    let apiKey: String
    let baseURL: String?
    let model: String?

    var settings: AIProviderSettings {
        AIProviderSettings(
            provider: AIProviderKind(rawValue: provider) ?? .openai,
            apiKey: apiKey,
            baseURL: baseURL ?? "",
            model: model ?? ""
        )
    }
}

private enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case dictionary([String: JSONValue])
    case array([JSONValue])
    case null

    static func jsonString(_ value: String) -> JSONValue {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return .string(value)
        }
        return JSONValue.from(any: object)
    }

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .dictionary(let value):
            let object = value.mapValues(\.foundationObject)
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
                  let string = String(data: data, encoding: .utf8) else {
                return ""
            }
            return string
        case .array(let value):
            let object = value.map(\.foundationObject)
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
                  let string = String(data: data, encoding: .utf8) else {
                return ""
            }
            return string
        case .null:
            return ""
        }
    }

    private var foundationObject: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .dictionary(let value):
            return value.mapValues(\.foundationObject)
        case .array(let value):
            return value.map(\.foundationObject)
        case .null:
            return NSNull()
        }
    }

    private static func from(any value: Any) -> JSONValue {
        switch value {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            let objCType = String(cString: number.objCType)
            return objCType == "c" ? .bool(number.boolValue) : .number(number.doubleValue)
        case let array as [Any]:
            return .array(array.map(from(any:)))
        case let dictionary as [String: Any]:
            return .dictionary(dictionary.mapValues { JSONValue.from(any: $0) })
        default:
            return .null
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .dictionary(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

private extension ImportSourceType {
    var apiValue: String {
        switch self {
        case .xiaohongshu: return "xiaohongshu"
        case .youtube: return "youtube"
        case .instagram: return "instagram"
        case .web: return "web"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "xiaohongshu": self = .xiaohongshu
        case "youtube": self = .youtube
        case "instagram": self = .instagram
        case "web": self = .web
        default: return nil
        }
    }
}

private extension ImportedContentType {
    var apiValue: String {
        switch self {
        case .video: return "video"
        case .imagePost: return "imagePost"
        case .carousel: return "carousel"
        case .article: return "article"
        case .unknown: return "unknown"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "video": self = .video
        case "imagePost": self = .imagePost
        case "carousel": self = .carousel
        case "article": self = .article
        case "unknown": self = .unknown
        default: return nil
        }
    }
}

private extension ResourceCategory {
    var apiValue: String {
        switch self {
        case .all: return "other"
        case .skincare: return "skincare"
        case .fitness: return "fitness"
        case .food: return "food"
        case .outfit: return "outfit"
        case .learning: return "learning"
        case .other: return "other"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "skincare": self = .skincare
        case "fitness": self = .fitness
        case "food": self = .food
        case "outfit": self = .outfit
        case "learning": self = .learning
        case "other": self = .other
        default: return nil
        }
    }
}

private extension ResourceImportStatus {
    var apiValue: String {
        switch self {
        case .parsed: return "parsed"
        case .partial: return "partial"
        case .manualCompleted: return "manualCompleted"
        case .failedFallbackSaved: return "failedFallbackSaved"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "parsed": self = .parsed
        case "partial": self = .partial
        case "manualCompleted": self = .manualCompleted
        case "failedFallbackSaved": self = .failedFallbackSaved
        default: return nil
        }
    }
}

private extension ResourceAnalysisStatus {
    var apiValue: String {
        switch self {
        case .pending: return "pending"
        case .analyzing: return "analyzing"
        case .analyzed: return "analyzed"
        case .fallback: return "fallback"
        }
    }
}

private extension ResourceSyncStatus {
    var apiValue: String {
        switch self {
        case .pending: return "pending"
        case .syncing: return "syncing"
        case .succeeded: return "succeeded"
        case .failed: return "failed"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "pending": self = .pending
        case "syncing": self = .syncing
        case "succeeded": self = .succeeded
        case "failed": self = .failed
        default: return nil
        }
    }
}

private extension MediaRetentionPolicy {
    var apiValue: String {
        switch self {
        case .metadataOnly: return "metadataOnly"
        case .temporaryCache: return "temporaryCache"
        case .explicitKeep: return "explicitKeep"
        }
    }

    init?(apiValue: String?) {
        switch apiValue {
        case "metadataOnly":
            self = .metadataOnly
        case "temporaryCache":
            self = .temporaryCache
        case "explicitKeep":
            self = .explicitKeep
        default:
            return nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
