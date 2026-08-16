import Foundation

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

    func requestFoodAnalysis(text: String?, imageData: Data?) async throws -> FoodAnalysisResult? {
        nil
    }

    func requestProductLookup(name: String?, imageData: Data?) async throws -> ProductLookupResult? {
        nil
    }

    func requestNotionQA(message: String, sessionId: String) async throws -> NotionQAResult {
        NotionQAResult(text: "", images: [], sourceUrl: "", sessionId: sessionId)
    }

    func upsertAIProviderSettings(session: SupabaseAuthSession, settings: AIProviderSettings) async throws {}
    func fetchAIProviderSettings(session: SupabaseAuthSession) async throws -> AIProviderSettings? { nil }
    func deleteAIProviderSettings(session: SupabaseAuthSession) async throws {}
}
