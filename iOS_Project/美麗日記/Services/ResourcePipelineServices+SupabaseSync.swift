import Foundation

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

    func requestFoodAnalysis(text: String?, imageData: Data?) async throws -> FoodAnalysisResult? {
        let response: DietAnalyzeFunctionResponse = try await client.invokeFunction(
            named: configuration.dietAnalyzeFunction,
            payload: DietAnalyzeFunctionRequest(text: text, imageBase64: imageData?.base64EncodedString()),
            responseType: DietAnalyzeFunctionResponse.self
        )
        guard !response.foodName.isEmpty else { return nil }
        return FoodAnalysisResult(
            foodName: response.foodName,
            estimatedCalories: response.estimatedCalories,
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

enum SupabaseCloudSyncError: LocalizedError {
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

