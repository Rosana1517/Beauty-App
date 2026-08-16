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
    let dietAnalyzeFunction: String
    let productLookupFunction: String
    let notionQAFunction: String
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
            dietAnalyzeFunction: AppRuntimeConfiguration.dietAnalyzeFunction,
            productLookupFunction: AppRuntimeConfiguration.productLookupFunction,
            notionQAFunction: AppRuntimeConfiguration.notionQAFunction,
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
    func requestFoodAnalysis(text: String?, imageData: Data?) async throws -> FoodAnalysisResult?
    func requestProductLookup(name: String?, imageData: Data?) async throws -> ProductLookupResult?
    func requestNotionQA(message: String, sessionId: String) async throws -> NotionQAResult
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

struct FoodAnalysisResult {
    let foodName: String
    let estimatedCalories: Int
    let notes: String
}

struct NotionQAResult {
    let text: String
    let images: [String]
    let sourceUrl: String
    let sessionId: String
}

struct PlatformImportResult {
    let draft: ResourceImportDraft
    let xhsPayload: XHSParsedPayload?
}
