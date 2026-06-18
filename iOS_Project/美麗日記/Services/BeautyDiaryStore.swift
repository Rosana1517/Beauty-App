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

    init(
        repository: BeautyDiaryRepository = JSONBeautyDiaryRepository(),
        importService: ResourceImportService = CompositeResourceImportService(),
        analysisService: ResourceAnalysisService = LocalRuleBasedResourceAnalysisService(),
        cloudSyncService: any CloudResourceSyncService = BeautyDiaryStore.makeCloudSyncService(),
        officialImportService: any OfficialMetadataImportService = OfficialMetadataImportGateway(),
        authService: any SupabaseAuthServiceProtocol = BeautyDiaryStore.makeAuthService()
    ) {
        self.repository = repository
        self.importService = importService
        self.analysisService = analysisService
        self.cloudSyncService = cloudSyncService
        self.officialImportService = officialImportService
        self.authService = authService
        self.state = repository.load() ?? .seed
        self.authSession = authService.currentSession()
        self.authStatus = AppRuntimeConfiguration.hasSupabaseConfig ? (self.authSession == nil ? .signedOut : .authenticated) : .unavailable
        self.authMessage = nil
        cleanupExpiredTemporaryMedia()
        self.repository.save(self.state)
        if AppRuntimeConfiguration.hasSupabaseConfig {
            Task {
                await restoreAuthSession()
            }
        }
    }

    static let preview = BeautyDiaryStore(repository: PreviewRepository())

    private static func makeCloudSyncService() -> any CloudResourceSyncService {
        SupabaseCloudResourceSyncService() ?? NoopCloudResourceSyncService()
    }

    private static func makeAuthService() -> any SupabaseAuthServiceProtocol {
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

    func updateProfile(nickname: String, signature: String, bodyFocus: String, skincareFocus: String, notificationTime: String) {
        state.profile.nickname = nickname
        state.profile.signature = signature
        state.profile.bodyFocus = bodyFocus
        state.profile.skincareFocus = skincareFocus
        state.profile.notificationTime = notificationTime
        save()
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
        guard !trimmedTitle.isEmpty else { return }

        var normalizedDraft = draft
        normalizedDraft.title = trimmedTitle
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
        let pendingIDs = state.resourceSyncQueue
            .filter { $0.syncStatus == .pending || $0.syncStatus == .failed }
            .map(\.resourceID)

        for resourceID in pendingIDs {
            await syncResource(resourceID)
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
        do {
            let remoteItems = try await cloudSyncService.fetchResources()
            guard !remoteItems.isEmpty else { return }
            state.resourceItems = merge(local: state.resourceItems, remote: remoteItems)
            save()
        } catch {
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
        await syncPendingResources()
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

    private func syncResource(_ resourceID: UUID) async {
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
                merged[index] = remoteItem
            } else if let index = merged.firstIndex(where: { $0.originalURL == remoteItem.originalURL && $0.source == remoteItem.source }) {
                merged[index] = remoteItem
            } else {
                merged.append(remoteItem)
            }
        }
        return merged.sorted { $0.importedAt > $1.importedAt }
    }

    private func save() {
        repository.save(state)
    }
}

private struct PreviewRepository: BeautyDiaryRepository {
    func load() -> BeautyDiaryState? { .seed }
    func save(_ state: BeautyDiaryState) {}
}
