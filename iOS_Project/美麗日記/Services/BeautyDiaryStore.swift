import Combine
import Foundation

protocol BeautyDiaryRepository {
    func load() -> BeautyDiaryState?
    func save(_ state: BeautyDiaryState)
}

final class JSONBeautyDiaryRepository: BeautyDiaryRepository {
    private let url: URL

    init(filename: String = "beauty-diary-state.json") {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.url = base.appendingPathComponent(filename)
    }

    func load() -> BeautyDiaryState? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard
            let data = try? Data(contentsOf: url),
            let state = try? decoder.decode(BeautyDiaryState.self, from: data)
        else {
            return nil
        }

        return state
    }

    func save(_ state: BeautyDiaryState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

struct MockRecommendationService {
    func skincareAdvice(state: BeautyDiaryState) -> [String] {
        var suggestions: [String] = []

        if state.skinRecords.isEmpty {
            suggestions.append("先建立第一筆膚況紀錄，AI 建議會更貼近目前肌膚狀態。")
        }

        if state.products.isEmpty {
            suggestions.append("補齊保養品清單後，可以依步驟直接綁定產品。")
        }

        if state.routine.steps.filter(\.isChecked).isEmpty {
            suggestions.append("今天還沒有護膚打卡，建議先完成晨間或晚間流程。")
        }

        if suggestions.isEmpty {
            suggestions.append("本週狀態穩定，建議持續保濕並維持固定防曬節奏。")
        }

        return suggestions
    }

    func resourceRecommendations(state: BeautyDiaryState) -> [String] {
        if state.resourceItems.isEmpty {
            return ["先導入小紅書、YouTube、Instagram 或網頁內容，系統會依分類幫你整理推薦。"]
        }

        let categories = Set(state.resourceItems.map(\.category))
        if categories.count < 2 {
            return ["目前收藏集中在單一主題，建議補充飲食或健身內容，讓推薦更平衡。"]
        }

        return ["你的資源分布已經很完整，建議先從最近新增的內容開始整理成行動清單。"]
    }
}

@MainActor
final class BeautyDiaryStore: ObservableObject {
    @Published private(set) var state: BeautyDiaryState
    @Published private(set) var authStatus: SupabaseAuthStatus
    @Published private(set) var authSession: SupabaseAuthSession?
    @Published private(set) var authMessage: String?

    private let repository: BeautyDiaryRepository
    private let recommendationService = MockRecommendationService()
    private let importService: ResourceImportService
    private let analysisService: ResourceAnalysisService
    private let cloudSyncService: any CloudResourceSyncService
    private let officialImportService: any OfficialMetadataImportService
    private let authService: any SupabaseAuthServiceProtocol
    private let notificationScheduler: any NotificationScheduling

    init(
        repository: BeautyDiaryRepository = JSONBeautyDiaryRepository(),
        importService: ResourceImportService = CompositeResourceImportService(),
        analysisService: ResourceAnalysisService = LocalRuleBasedResourceAnalysisService(),
        cloudSyncService: any CloudResourceSyncService = BeautyDiaryStore.makeCloudSyncService(),
        officialImportService: any OfficialMetadataImportService = OfficialMetadataImportGateway(),
        authService: any SupabaseAuthServiceProtocol = BeautyDiaryStore.makeAuthService(),
        notificationScheduler: any NotificationScheduling = UserNotificationScheduler()
    ) {
        self.repository = repository
        self.importService = importService
        self.analysisService = analysisService
        self.cloudSyncService = cloudSyncService
        self.officialImportService = officialImportService
        self.authService = authService
        self.notificationScheduler = notificationScheduler
        self.state = repository.load() ?? .seed
        let restoredSession = authService.currentSession()
        let restoredStatus: SupabaseAuthStatus
        if AppRuntimeConfiguration.hasSupabaseConfig {
            restoredStatus = restoredSession == nil ? .signedOut : .authenticated
        } else {
            restoredStatus = .unavailable
        }
        self.authSession = restoredSession
        self.authStatus = restoredStatus
        self.authMessage = nil
        cleanupExpiredTemporaryMedia()
        self.repository.save(self.state)
        if AppRuntimeConfiguration.hasSupabaseConfig {
            Task {
                await restoreAuthSession()
            }
        }
        Task {
            await scheduleDailyReminderIfPossible(requestPermission: false)
        }
    }

    static let preview = BeautyDiaryStore(repository: PreviewRepository())

    nonisolated private static func makeCloudSyncService() -> any CloudResourceSyncService {
        SupabaseCloudResourceSyncService() ?? NoopCloudResourceSyncService()
    }

    nonisolated private static func makeAuthService() -> any SupabaseAuthServiceProtocol {
        SupabaseEmailAuthService() ?? NoopSupabaseAuthService()
    }

    var progressText: String {
        "\(completedChecklistCount)/\(state.checklistItems.count)"
    }

    var progressValue: Double {
        guard !state.checklistItems.isEmpty else { return 0 }
        return Double(completedChecklistCount) / Double(state.checklistItems.count)
    }

    var completedChecklistCount: Int {
        state.checklistItems.filter(\.isCompleted).count
    }

    var skincareAdvice: [String] {
        recommendationService.skincareAdvice(state: state)
    }

    var resourceRecommendations: [String] {
        recommendationService.resourceRecommendations(state: state)
    }

    var filteredResources: [ResourceItem] {
        if state.resourceFilter == .all {
            return state.resourceItems
        }
        return state.resourceItems.filter { $0.category == state.resourceFilter }
    }

    var platformCapabilities: [SourcePlatformCapability] {
        ImportSourceType.allCases.map { officialImportService.capability(for: $0) }
    }

    var isCloudSyncReady: Bool {
        AppRuntimeConfiguration.hasSupabaseConfig && authSession != nil
    }

    func toggleChecklist(_ item: ChecklistItem) {
        guard let index = state.checklistItems.firstIndex(where: { $0.id == item.id }) else { return }
        state.checklistItems[index].isCompleted.toggle()
        save()
    }

    func toggleRoutineStep(_ step: RoutineStep) {
        guard let index = state.routine.steps.firstIndex(where: { $0.id == step.id }) else { return }
        state.routine.steps[index].isChecked.toggle()
        save()
    }

    func assignProduct(_ productName: String, to step: RoutineStep) {
        guard let index = state.routine.steps.firstIndex(where: { $0.id == step.id }) else { return }
        state.routine.steps[index].productName = productName.isEmpty ? nil : productName
        save()
    }

    func addRoutineStep(period: RoutinePeriod, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.routine.steps.append(
            RoutineStep(
                id: UUID(),
                period: period,
                name: trimmed,
                productName: nil,
                isChecked: false
            )
        )
        save()
    }

    func addProduct(name: String, brand: String, category: String, notes: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.products.append(
            Product(
                id: UUID(),
                name: trimmed,
                brand: brand,
                category: category,
                notes: notes
            )
        )
        save()
    }

    func deleteProduct(_ product: Product) {
        state.products.removeAll { $0.id == product.id }
        state.routine.steps = state.routine.steps.map { step in
            var updated = step
            if updated.productName == product.name {
                updated.productName = nil
            }
            return updated
        }
        save()
    }

    func addSkinRecord(type: String, concerns: [String], note: String) {
        guard !type.isEmpty else { return }

        state.skinRecords.insert(
            SkinRecord(
                id: UUID(),
                date: Date(),
                skinType: type,
                concerns: concerns,
                note: note
            ),
            at: 0
        )
        save()
    }

    func deleteSkinRecord(_ record: SkinRecord) {
        state.skinRecords.removeAll { $0.id == record.id }
        save()
    }

    func addHairCareRecord(careType: String, note: String) {
        let trimmed = careType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.hairCareRecords.insert(
            HairCareRecord(id: UUID(), date: Date(), careType: trimmed, note: note),
            at: 0
        )
        save()
    }

    func deleteHairCareRecord(_ record: HairCareRecord) {
        state.hairCareRecords.removeAll { $0.id == record.id }
        save()
    }

    func addBodySkinRecord(area: String, concern: String, note: String) {
        let trimmedArea = area.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedArea.isEmpty else { return }

        state.bodySkinRecords.insert(
            BodySkinRecord(id: UUID(), date: Date(), area: trimmedArea, concern: concern, note: note),
            at: 0
        )
        save()
    }

    func deleteBodySkinRecord(_ record: BodySkinRecord) {
        state.bodySkinRecords.removeAll { $0.id == record.id }
        save()
    }

    func addBodyProduct(name: String, brand: String, category: String, notes: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.bodyProducts.append(Product(id: UUID(), name: trimmed, brand: brand, category: category, notes: notes))
        save()
    }

    func deleteBodyProduct(_ product: Product) {
        state.bodyProducts.removeAll { $0.id == product.id }
        save()
    }

    func addHairProduct(name: String, brand: String, category: String, notes: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.hairProducts.append(Product(id: UUID(), name: trimmed, brand: brand, category: category, notes: notes))
        save()
    }

    func deleteHairProduct(_ product: Product) {
        state.hairProducts.removeAll { $0.id == product.id }
        save()
    }

    func addHairAppointment(title: String, storeName: String, date: Date, note: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.hairAppointments.insert(
            Appointment(id: UUID(), title: trimmed, storeName: storeName, date: date, note: note),
            at: 0
        )
        save()
    }

    func deleteHairAppointment(_ appointment: Appointment) {
        state.hairAppointments.removeAll { $0.id == appointment.id }
        save()
    }

    func adjustWashFrequency(by delta: Int) {
        state.washFrequencyDays = max(1, state.washFrequencyDays + delta)
        save()
    }

    func adjustCareFrequency(by delta: Int) {
        state.careFrequencyDays = max(1, state.careFrequencyDays + delta)
        save()
    }

    func addFaceLiftAction(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.faceLiftActions.append(FaceLiftAction(id: UUID(), name: trimmed))
        save()
    }

    func deleteFaceLiftAction(_ action: FaceLiftAction) {
        state.faceLiftActions.removeAll { $0.id == action.id }
        save()
    }

    func addFaceLiftPunch() {
        let calendar = Calendar.current
        let alreadyPunchedToday = state.faceLiftPunches.contains { calendar.isDateInToday($0.date) }
        guard !alreadyPunchedToday else { return }

        state.faceLiftPunches.insert(FaceLiftPunchRecord(id: UUID(), date: Date()), at: 0)
        save()
    }

    var faceLiftPunchDaysThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        let punchedDays = state.faceLiftPunches
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .compactMap { calendar.dateComponents([.day], from: $0.date).day }
        return Set(punchedDays).count
    }

    func addFaceLiftRating(score: Int, note: String) {
        state.faceLiftRatings.insert(
            FaceLiftRatingRecord(id: UUID(), date: Date(), score: score, note: note),
            at: 0
        )
        save()
    }

    func deleteFaceLiftRating(_ record: FaceLiftRatingRecord) {
        state.faceLiftRatings.removeAll { $0.id == record.id }
        save()
    }

    /// Keyed by topic so independent "type your concern -> AI suggestions"
    /// screens (skincare/hair/face-lift/body-skin/diet/makeup) don't clobber
    /// each other's results when the user switches between them.
    @Published private(set) var aiAdviceSuggestions: [AIAdviceTopic: [String]] = [:]
    @Published private(set) var aiAdviceErrorMessage: [AIAdviceTopic: String] = [:]
    @Published private(set) var loadingAIAdviceTopics: Set<AIAdviceTopic> = []

    func suggestions(for topic: AIAdviceTopic) -> [String] {
        aiAdviceSuggestions[topic] ?? []
    }

    func errorMessage(for topic: AIAdviceTopic) -> String? {
        aiAdviceErrorMessage[topic]
    }

    func isLoadingAdvice(for topic: AIAdviceTopic) -> Bool {
        loadingAIAdviceTopics.contains(topic)
    }

    func requestAIAdvice(topic: AIAdviceTopic, concerns: [String]) async {
        guard authSession != nil else {
            aiAdviceErrorMessage[topic] = "請先登入雲端同步帳號，才能使用 AI 推薦功能。"
            return
        }

        loadingAIAdviceTopics.insert(topic)
        aiAdviceErrorMessage[topic] = nil

        do {
            let suggestions = try await cloudSyncService.requestAIAdvice(topic: topic, concerns: concerns)
            aiAdviceSuggestions[topic] = suggestions
        } catch {
            aiAdviceErrorMessage[topic] = error.localizedDescription
        }

        loadingAIAdviceTopics.remove(topic)
    }

    func addPunchRecord(summary: String) {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.punchRecords.insert(
            PunchRecord(id: UUID(), date: Date(), summary: trimmed),
            at: 0
        )
        state.profile.streakDays += 1
        save()
    }

    func addAppointment(title: String, storeName: String, date: Date, note: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.appointments.insert(
            Appointment(
                id: UUID(),
                title: trimmed,
                storeName: storeName,
                date: date,
                note: note
            ),
            at: 0
        )
        save()
    }

    func deleteAppointment(_ appointment: Appointment) {
        state.appointments.removeAll { $0.id == appointment.id }
        save()
    }

    func addBodyMetric(weight: Double, bodyFat: Double, note: String) {
        state.bodyMetricRecords.insert(
            BodyMetricRecord(
                id: UUID(),
                date: Date(),
                weight: weight,
                bodyFat: bodyFat,
                note: note
            ),
            at: 0
        )
        save()
    }

    func deleteBodyMetric(_ record: BodyMetricRecord) {
        state.bodyMetricRecords.removeAll { $0.id == record.id }
        save()
    }

    func addMealRecord(type: String, summary: String, note: String) {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.mealRecords.insert(
            MealRecord(
                id: UUID(),
                date: Date(),
                mealType: type,
                summary: trimmed,
                note: note
            ),
            at: 0
        )
        save()
    }

    func deleteMealRecord(_ record: MealRecord) {
        state.mealRecords.removeAll { $0.id == record.id }
        save()
    }

    func addResource(title: String, source: ImportSourceType, category: ResourceCategory, url: String, summary: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalizedCategory = category == .all ? .other : category
        state.resourceItems.insert(
            ResourceItem(
                title: trimmed,
                source: source,
                category: normalizedCategory,
                platformContentType: source == .youtube ? .video : (source == .web ? .article : .imagePost),
                canonicalURL: url,
                originalURL: url,
                externalID: "",
                authorName: "",
                thumbnailURL: "",
                publishedAt: nil,
                descriptionText: summary,
                tags: [],
                importStatus: .manualCompleted,
                metadataConfidence: 0.2,
                rawMetadataSnapshot: ""
            ),
            at: 0
        )
        unlockBadgeIfNeeded(title: "資源收藏家", when: state.resourceItems.count >= 10)
        save()
    }

    func setResourceFilter(_ category: ResourceCategory) {
        state.resourceFilter = category
        save()
    }

    func deleteResource(_ item: ResourceItem) {
        state.resourceItems.removeAll { $0.id == item.id }
        state.resourceImportHistory.removeAll { $0.originalURL == item.originalURL || $0.title == item.title }
        state.resourceSyncQueue.removeAll { $0.resourceID == item.id }
        save()
    }

    func addBook(title: String, author: String, link: String, note: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.bookRecords.insert(
            BookRecord(
                id: UUID(),
                title: trimmed,
                author: author,
                link: link,
                note: note
            ),
            at: 0
        )
        save()
    }

    func deleteBook(_ book: BookRecord) {
        state.bookRecords.removeAll { $0.id == book.id }
        save()
    }

    func updateProfile(nickname: String, signature: String, bodyFocus: String, skincareFocus: String, notificationTime: String) {
        state.profile.nickname = nickname
        state.profile.signature = signature
        state.profile.bodyFocus = bodyFocus
        state.profile.skincareFocus = skincareFocus
        state.profile.notificationTime = notificationTime
        save()

        Task {
            await scheduleDailyReminderIfPossible(requestPermission: false)
        }

        guard authSession != nil else { return }
        Task {
            await syncCurrentUserProfileIfNeeded()
        }
    }

    func enableDailyReminder() async {
        await scheduleDailyReminderIfPossible(requestPermission: true)
    }

    func createExport(format: ExportFormat) -> String {
        let summary = format == .json
            ? "本地 JSON 匯出預覽：包含護膚、體態、成長與資源摘要。"
            : "PDF 報告預覽：護膚步驟、體態趨勢、閱讀進度與資源整理。"

        state.exportHistory.insert(
            ExportRecord(
                id: UUID(),
                format: format,
                createdAt: Date(),
                summary: summary
            ),
            at: 0
        )
        save()
        return summary
    }

    func importResource(from url: String) async -> ResourceImportDraft {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return markImportFailure(url: url, message: "請先貼上要匯入的內容連結。")
        }

        let parsed = await importService.parse(url: trimmed)
        let analyzed = await analysisService.analyze(draft: parsed)
        var draft = parsed
        draft = analyzed
        if draft.category == .all {
            draft.category = ResourceCategory.suggestedCategory(
                title: draft.title,
                description: draft.descriptionText,
                source: draft.source
            )
        }
        state.pendingImportDraft = draft
        save()
        return draft
    }

    func updateImportDraft(_ draft: ResourceImportDraft) {
        state.pendingImportDraft = draft
        save()
    }

    @discardableResult
    func markImportFailure(url: String, message: String) -> ResourceImportDraft {
        var draft = ResourceImportDraft.empty(url: url)
        draft.lastErrorMessage = message
        draft.importStatus = .partial
        draft.platformContentType = draft.source == .web ? .article : .unknown
        draft.analysisStatus = .fallback
        state.pendingImportDraft = draft
        save()
        return draft
    }

    func saveImportedResource(_ draft: ResourceImportDraft) {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        // A completely failed fetch (e.g. unreachable host) leaves the
        // title empty - falling back to the URL instead of silently
        // dropping the save, since the "保存到資源庫" button is always
        // shown regardless of parse outcome and gives no feedback when it
        // no-ops.
        let resolvedTitle = trimmedTitle.isEmpty
            ? draft.originalURL.trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmedTitle
        guard !resolvedTitle.isEmpty else { return }

        var normalizedDraft = draft
        normalizedDraft.title = resolvedTitle
        normalizedDraft.category = draft.category == .all ? .other : draft.category
        normalizedDraft.importedAt = Date()
        normalizedDraft.temporaryMediaLeases = normalizedDraft.temporaryMediaLeases.filter { $0.cleanedAt == nil }

        if normalizedDraft.mediaRetentionPolicy == .metadataOnly {
            normalizedDraft.temporaryMediaLeases = []
            normalizedDraft.mediaAssets = normalizedDraft.selectedMediaAssets.map {
                var asset = $0
                asset.localStoragePath = nil
                asset.expiresAt = nil
                asset.retentionPolicy = .metadataOnly
                return asset
            }
        } else if normalizedDraft.mediaRetentionPolicy == .temporaryCache {
            let expiry = Date().addingTimeInterval(60 * 60)
            normalizedDraft.mediaAssets = normalizedDraft.selectedMediaAssets.map {
                var asset = $0
                asset.retentionPolicy = .temporaryCache
                asset.expiresAt = expiry
                return asset
            }
        } else {
            normalizedDraft.mediaAssets = normalizedDraft.selectedMediaAssets
        }

        if var payload = normalizedDraft.sourcePayloadSummary {
            payload.mediaAssets = normalizedDraft.mediaAssets
            normalizedDraft.sourcePayloadSummary = payload
        }

        if draft.importStatus == .partial {
            normalizedDraft.importStatus = draft.metadataConfidence < 0.2 ? .failedFallbackSaved : .manualCompleted
        } else if draft.requiresManualCompletion {
            normalizedDraft.importStatus = .manualCompleted
        } else {
            normalizedDraft.importStatus = .parsed
        }

        let resourceItem = ResourceItem(from: normalizedDraft)
        state.resourceItems.insert(resourceItem, at: 0)
        state.resourceImportHistory.insert(
            ResourceImportHistoryEntry(
                id: UUID(),
                source: normalizedDraft.source,
                title: normalizedDraft.title,
                originalURL: normalizedDraft.originalURL,
                status: normalizedDraft.importStatus,
                importedAt: normalizedDraft.importedAt ?? Date(),
                note: normalizedDraft.lastErrorMessage ?? ""
            ),
            at: 0
        )
        state.resourceSyncQueue.insert(
            ResourceSyncQueueItem(
                id: UUID(),
                resourceID: resourceItem.id,
                jobType: .importJob,
                syncTarget: "supabase",
                syncStatus: .pending,
                retryCount: 0,
                requestPayload: resourceItem.originalURL,
                lastErrorMessage: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            at: 0
        )
        state.pendingImportDraft = nil
        unlockBadgeIfNeeded(title: "資源收藏家", when: state.resourceItems.count >= 10)
        save()

        Task {
            await syncResource(resourceItem.id)
            await scheduleMediaCleanupIfNeeded(for: resourceItem.id)
        }
    }

    func clearPendingImportDraft() {
        state.pendingImportDraft = nil
        save()
    }

    func syncPendingResources() async {
        await syncPendingResources(respectBackoff: true)
    }

    /// `respectBackoff: false` is used for explicit user-triggered syncs
    /// (e.g. `syncCloudNow()`) so a manual retry isn't silently skipped just
    /// because the automatic backoff window hasn't elapsed yet. The max
    /// retry cap still applies either way, since repeated failures usually
    /// mean a real error, not a transient one.
    private func syncPendingResources(respectBackoff: Bool) async {
        let dueResourceIDs = state.resourceSyncQueue
            .filter { item in
                guard item.jobType == .importJob else { return false }
                guard item.syncStatus == .pending || item.syncStatus == .failed else { return false }
                guard item.retryCount < Self.maxResourceSyncRetryCount else { return false }
                return !respectBackoff || isDueForRetry(item)
            }
            .map(\.resourceID)

        for resourceID in Set(dueResourceIDs) {
            await syncResource(resourceID)
        }
    }

    private static let maxResourceSyncRetryCount = 5

    private func backoffInterval(forRetryCount retryCount: Int) -> TimeInterval {
        min(pow(2.0, Double(retryCount)) * 5, 300)
    }

    private func isDueForRetry(_ item: ResourceSyncQueueItem) -> Bool {
        guard item.syncStatus == .failed else { return true }
        return Date().timeIntervalSince(item.updatedAt) >= backoffInterval(forRetryCount: item.retryCount)
    }

    private func isTransientNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    func requestBackendReparse(for item: ResourceItem, reason: String) async {
        do {
            let queueItem = try await cloudSyncService.enqueueReparse(for: item, reason: reason)
            state.resourceSyncQueue.insert(queueItem, at: 0)
            save()
        } catch {
            appendSyncFailure(resourceID: item.id, message: "建立重解析佇列失敗：\(error.localizedDescription)")
        }
    }

    func refreshCloudResources() async {
        await refreshCloudResources(allowRetry: true)
    }

    private func refreshCloudResources(allowRetry: Bool) async {
        do {
            let remoteItems = try await cloudSyncService.fetchResources()
            guard !remoteItems.isEmpty else { return }
            state.resourceItems = merge(local: state.resourceItems, remote: remoteItems)
            save()
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await refreshCloudResources(allowRetry: false)
            }
            return
        }
    }

    func restoreAuthSession() async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else {
            authStatus = .unavailable
            authSession = nil
            authMessage = "Supabase is not configured."
            return
        }

        authStatus = .restoring
        authMessage = nil
        authSession = await authService.restoreSession()

        if authSession == nil {
            authStatus = .signedOut
            return
        }

        authStatus = .authenticated
        await reconcileCurrentUserProfileWithCloud()
        await fetchAIProviderSettingsFromCloud()
        await refreshCloudResources()
        await syncPendingResources()
    }

    func signInToSupabase(email: String, password: String) async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else {
            authStatus = .unavailable
            authMessage = "Supabase is not configured."
            return
        }

        authStatus = .authenticating
        authMessage = nil

        do {
            let session = try await authService.signIn(email: email, password: password)
            authSession = session
            authStatus = .authenticated
            authMessage = "Signed in. Cloud sync is ready."
            await reconcileCurrentUserProfileWithCloud()
            await fetchAIProviderSettingsFromCloud()
            await refreshCloudResources()
            await syncPendingResources()
        } catch {
            authSession = nil
            authStatus = .signedOut
            authMessage = error.localizedDescription
        }
    }

    func handleSupabaseAuthCallback(_ url: URL) async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else { return }
        guard isSupabaseCallbackURL(url) else { return }

        authStatus = .authenticating
        authMessage = nil

        do {
            let session = try await authService.completeMagicLinkSignIn(from: url)
            authSession = session
            authStatus = .authenticated
            authMessage = "Magic link sign-in completed."
            await reconcileCurrentUserProfileWithCloud()
            await fetchAIProviderSettingsFromCloud()
            await refreshCloudResources()
            await syncPendingResources()
        } catch {
            authSession = nil
            authStatus = .signedOut
            authMessage = error.localizedDescription
        }
    }

    func requestSupabaseMagicLink(email: String) async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else {
            authStatus = .unavailable
            authMessage = "Supabase is not configured."
            return
        }

        authStatus = .authenticating
        authMessage = nil

        do {
            try await authService.requestMagicLink(email: email)
            authStatus = authSession == nil ? .signedOut : .authenticated
            authMessage = "Magic link sent. Check your email to finish sign-in."
        } catch {
            authStatus = authSession == nil ? .signedOut : .authenticated
            authMessage = error.localizedDescription
        }
    }

    func signOutFromSupabase() async {
        do {
            try await authService.signOut()
        } catch {
            authMessage = error.localizedDescription
        }

        authSession = nil
        authStatus = AppRuntimeConfiguration.hasSupabaseConfig ? .signedOut : .unavailable
    }

    func syncCloudNow() async {
        guard authSession != nil else {
            authMessage = "Sign in to Supabase before syncing."
            return
        }

        authMessage = nil
        await reconcileCurrentUserProfileWithCloud()
        await syncPendingResources(respectBackoff: false)
        await refreshCloudResources()
        authMessage = "Cloud sync finished."
    }

    func applyBackendRecommendationsIfNeeded(for item: ResourceItem) async {
        do {
            let cards = try await cloudSyncService.requestRecommendations(for: item)
            guard let index = state.resourceItems.firstIndex(where: { $0.id == item.id }), !cards.isEmpty else { return }
            state.resourceItems[index].recommendationCards = cards
            state.resourceItems[index].analysisStatus = .analyzed
            save()
        } catch {
            return
        }
    }

    private func unlockBadgeIfNeeded(title: String, when condition: Bool) {
        guard condition, let index = state.achievements.firstIndex(where: { $0.title == title }) else { return }
        state.achievements[index].unlocked = true
    }

    private func cleanupExpiredTemporaryMedia(now: Date = Date()) {
        state.resourceItems = state.resourceItems.map { item in
            var updated = item
            let activeLeases = item.temporaryMediaLeases.filter { lease in
                lease.cleanedAt == nil && lease.expiresAt > now
            }
            updated.temporaryMediaLeases = activeLeases
            if item.mediaRetentionPolicy == .temporaryCache {
                updated.mediaAssets = item.mediaAssets.map { asset in
                    var mutable = asset
                    if let expiresAt = asset.expiresAt, expiresAt <= now {
                        mutable.localStoragePath = nil
                        mutable.retentionPolicy = .metadataOnly
                    }
                    return mutable
                }
            }
            return updated
        }
    }

    private func scheduleDailyReminderIfPossible(requestPermission: Bool) async {
        let reminderTime = state.profile.notificationTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reminderTime.isEmpty else { return }

        do {
            let isAuthorized = requestPermission
                ? try await notificationScheduler.requestAuthorizationIfNeeded()
                : true
            guard isAuthorized else {
                authMessage = "Notifications are disabled. Enable them in Settings to receive reminders."
                return
            }
            try await notificationScheduler.scheduleDailyReminder(
                timeString: reminderTime,
                nickname: state.profile.nickname
            )
        } catch {
            authMessage = error.localizedDescription
        }
    }

    private func syncCurrentUserProfileIfNeeded() async {
        await syncCurrentUserProfileIfNeeded(allowRetry: true)
    }

    private func syncCurrentUserProfileIfNeeded(allowRetry: Bool) async {
        guard let session = authSession else { return }

        do {
            try await cloudSyncService.upsertCurrentUserProfile(session: session, profile: state.profile)
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await syncCurrentUserProfileIfNeeded(allowRetry: false)
                return
            }
            authMessage = error.localizedDescription
        }
    }

    private func reconcileCurrentUserProfileWithCloud() async {
        await reconcileCurrentUserProfileWithCloud(allowRetry: true)
    }

    private func reconcileCurrentUserProfileWithCloud(allowRetry: Bool) async {
        guard let session = authSession else { return }

        do {
            if let remoteProfile = try await cloudSyncService.fetchCurrentUserProfile(session: session),
               shouldAdoptRemoteProfile(remoteProfile) {
                state.profile = remoteProfile
                save()
            }

            try await cloudSyncService.upsertCurrentUserProfile(session: session, profile: state.profile)
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await reconcileCurrentUserProfileWithCloud(allowRetry: false)
                return
            }
            authMessage = error.localizedDescription
        }
    }

    /// Saves the signed-in user's own AI provider config (URL/key/model) to
    /// their RLS-scoped row in `user_ai_provider_settings`. Each user brings
    /// their own key instead of sharing one baked into backend env vars.
    func saveAIProviderSettings(_ settings: AIProviderSettings) async {
        await saveAIProviderSettings(settings, allowRetry: true)
    }

    private func saveAIProviderSettings(_ settings: AIProviderSettings, allowRetry: Bool) async {
        state.aiProviderSettings = settings
        save()

        guard let session = authSession else {
            authMessage = "Sign in to Supabase to sync your AI provider key across devices."
            return
        }

        do {
            try await cloudSyncService.upsertAIProviderSettings(session: session, settings: settings)
            authMessage = "AI provider settings saved."
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await saveAIProviderSettings(settings, allowRetry: false)
                return
            }
            authMessage = "Saved locally, but cloud sync failed: \(error.localizedDescription)"
        }
    }

    func clearAIProviderSettings() async {
        await clearAIProviderSettings(allowRetry: true)
    }

    private func clearAIProviderSettings(allowRetry: Bool) async {
        state.aiProviderSettings = nil
        save()

        guard let session = authSession else { return }

        do {
            try await cloudSyncService.deleteAIProviderSettings(session: session)
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await clearAIProviderSettings(allowRetry: false)
                return
            }
            authMessage = "Removed locally, but cloud delete failed: \(error.localizedDescription)"
        }
    }

    private func fetchAIProviderSettingsFromCloud() async {
        await fetchAIProviderSettingsFromCloud(allowRetry: true)
    }

    private func fetchAIProviderSettingsFromCloud(allowRetry: Bool) async {
        guard let session = authSession else { return }

        do {
            if let remoteSettings = try await cloudSyncService.fetchAIProviderSettings(session: session) {
                state.aiProviderSettings = remoteSettings
                save()
            }
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await fetchAIProviderSettingsFromCloud(allowRetry: false)
                return
            }
            // Non-fatal: keep whatever AI provider settings are already
            // cached locally rather than surfacing this as a user-facing error.
        }
    }

    private func recoverSessionIfNeeded(after error: Error) async -> Bool {
        guard case SupabaseRESTError.unauthorized = error else { return false }
        let restoredSession = await authService.restoreSession()
        guard let restoredSession else {
            authSession = nil
            authStatus = .signedOut
            authMessage = "Supabase session expired. Please sign in again."
            return false
        }

        authSession = restoredSession
        authStatus = .authenticated
        authMessage = "Supabase session refreshed. Retrying sync."
        return true
    }

    private func shouldAdoptRemoteProfile(_ remoteProfile: UserProfileRecord) -> Bool {
        guard remoteProfile != state.profile else { return false }
        return state.profile == BeautyDiaryState.seed.profile
    }

    private func isSupabaseCallbackURL(_ url: URL) -> Bool {
        guard let redirectURL = URL(string: AppRuntimeConfiguration.supabaseAuthRedirectURL),
              let callbackComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let expectedComponents = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false) else {
            return false
        }

        let sameScheme = callbackComponents.scheme?.caseInsensitiveCompare(expectedComponents.scheme ?? "") == .orderedSame
        let sameHost = (callbackComponents.host ?? "").caseInsensitiveCompare(expectedComponents.host ?? "") == .orderedSame
        let samePath = callbackComponents.path == expectedComponents.path
        return sameScheme && sameHost && samePath
    }

    private func syncResource(_ resourceID: UUID) async {
        await syncResource(resourceID, allowSessionRetry: true, allowTransientRetry: true)
    }

    private func syncResource(_ resourceID: UUID, allowSessionRetry: Bool, allowTransientRetry: Bool) async {
        guard let resourceIndex = state.resourceItems.firstIndex(where: { $0.id == resourceID }) else { return }

        updateSyncState(for: resourceID, jobType: .importJob, status: .syncing, errorMessage: nil)
        do {
            let result = try await cloudSyncService.pushResource(state.resourceItems[resourceIndex])
            state.resourceItems[resourceIndex].syncStatus = .succeeded
            state.resourceItems[resourceIndex].remoteRecordID = result.remoteRecordID
            state.resourceItems[resourceIndex].lastSyncedAt = result.syncedAt
            updateSyncState(for: resourceID, jobType: .importJob, status: .succeeded, errorMessage: nil)
            save()
            await applyBackendRecommendationsIfNeeded(for: state.resourceItems[resourceIndex])
        } catch {
            if allowSessionRetry, await recoverSessionIfNeeded(after: error) {
                await syncResource(resourceID, allowSessionRetry: false, allowTransientRetry: allowTransientRetry)
                return
            }
            // A single short-delay retry for transient network blips (timeout,
            // dropped connection) so a flaky network during bulk import
            // doesn't immediately burn through the queue's retry budget.
            if allowTransientRetry, isTransientNetworkError(error) {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await syncResource(resourceID, allowSessionRetry: false, allowTransientRetry: false)
                return
            }
            state.resourceItems[resourceIndex].syncStatus = .failed
            updateSyncState(for: resourceID, jobType: .importJob, status: .failed, errorMessage: error.localizedDescription)
            save()
        }
    }

    private func scheduleMediaCleanupIfNeeded(for resourceID: UUID) async {
        guard let resource = state.resourceItems.first(where: { $0.id == resourceID }) else { return }
        guard resource.mediaRetentionPolicy != .explicitKeep else { return }
        guard !resource.mediaAssets.isEmpty || !resource.temporaryMediaLeases.isEmpty else { return }

        do {
            let queueItem = try await cloudSyncService.enqueueMediaCleanup(for: resource)
            state.resourceSyncQueue.insert(queueItem, at: 0)
            save()
        } catch {
            appendSyncFailure(resourceID: resourceID, message: "建立媒體清理佇列失敗：\(error.localizedDescription)")
        }
    }

    private func updateSyncState(for resourceID: UUID, jobType: ResourceSyncJobType, status: ResourceSyncStatus, errorMessage: String?) {
        if let queueIndex = state.resourceSyncQueue.firstIndex(where: { $0.resourceID == resourceID && $0.jobType == jobType }) {
            state.resourceSyncQueue[queueIndex].syncStatus = status
            state.resourceSyncQueue[queueIndex].updatedAt = Date()
            state.resourceSyncQueue[queueIndex].lastErrorMessage = errorMessage
            if status == .failed {
                state.resourceSyncQueue[queueIndex].retryCount += 1
            }
        } else {
            state.resourceSyncQueue.insert(
                ResourceSyncQueueItem(
                    id: UUID(),
                    resourceID: resourceID,
                    jobType: jobType,
                    syncTarget: "supabase",
                    syncStatus: status,
                    retryCount: status == .failed ? 1 : 0,
                    requestPayload: "",
                    lastErrorMessage: errorMessage,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                at: 0
            )
        }
    }

    private func appendSyncFailure(resourceID: UUID, message: String) {
        updateSyncState(for: resourceID, jobType: .importJob, status: .failed, errorMessage: message)
        save()
    }

    private func merge(local: [ResourceItem], remote: [ResourceItem]) -> [ResourceItem] {
        var merged = local
        for remoteItem in remote {
            if let index = merged.firstIndex(where: { $0.remoteRecordID == remoteItem.remoteRecordID && !$0.remoteRecordID.isEmpty }) {
                guard canOverwriteWithRemote(merged[index]) else { continue }
                merged[index] = remoteItem
            } else if let index = merged.firstIndex(where: { $0.originalURL == remoteItem.originalURL && $0.source == remoteItem.source }) {
                guard canOverwriteWithRemote(merged[index]) else { continue }
                merged[index] = remoteItem
            } else {
                merged.append(remoteItem)
            }
        }
        return merged.sorted { $0.importedAt > $1.importedAt }
    }

    /// Local edits made while a push is pending/in-flight/failed haven't been
    /// confirmed by the server yet. If a cloud refresh overwrote them with
    /// (possibly stale) remote data, the unsynced local change would be lost
    /// silently. Only items the server has already acknowledged
    /// (`.succeeded`) are safe to replace wholesale here; pending ones will
    /// reconcile themselves once `syncPendingResources()` pushes them up.
    private func canOverwriteWithRemote(_ localItem: ResourceItem) -> Bool {
        localItem.syncStatus == .succeeded
    }

    private func save() {
        repository.save(state)
    }
}

private struct PreviewRepository: BeautyDiaryRepository {
    func load() -> BeautyDiaryState? { .seed }
    func save(_ state: BeautyDiaryState) {}
}
