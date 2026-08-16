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
    @Published var state: BeautyDiaryState
    @Published var authStatus: SupabaseAuthStatus
    @Published var authSession: SupabaseAuthSession?
    @Published var authMessage: String?
    @Published var aiAdviceSuggestions: [AIAdviceTopic: [String]] = [:]
    @Published var aiAdviceRoutineSteps: [AIAdviceTopic: [String]] = [:]
    @Published var aiAdviceProducts: [AIAdviceTopic: [String]] = [:]
    @Published var aiAdviceRelatedResources: [AIAdviceTopic: [AIAdviceRelatedResource]] = [:]
    @Published var aiAdviceErrorMessage: [AIAdviceTopic: String] = [:]
    @Published var loadingAIAdviceTopics: Set<AIAdviceTopic> = []
    @Published var productLookupError: String?
    @Published var isLookingUpProduct = false
    @Published var foodAnalysisError: String?
    @Published var isAnalyzingFood = false
    @Published var notionQAMessages: [NotionQAChatMessage] = []
    @Published var isLoadingNotionQA = false
    @Published var notionQAError: String?
    @Published var notionQASessionID = KeychainStore.notionQASessionID()

    let repository: BeautyDiaryRepository
    let recommendationService = MockRecommendationService()
    let importService: ResourceImportService
    let analysisService: ResourceAnalysisService
    let cloudSyncService: any CloudResourceSyncService
    let officialImportService: any OfficialMetadataImportService
    let authService: any SupabaseAuthServiceProtocol
    let notificationScheduler: any NotificationScheduling

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
            await rescheduleHabitReminders(requestPermission: false)
        }
    }

    static let preview = BeautyDiaryStore(repository: PreviewRepository())

    nonisolated static func makeCloudSyncService() -> any CloudResourceSyncService {
        SupabaseCloudResourceSyncService() ?? NoopCloudResourceSyncService()
    }

    nonisolated static func makeAuthService() -> any SupabaseAuthServiceProtocol {
        SupabaseEmailAuthService() ?? NoopSupabaseAuthService()
    }

    var progressText: String {
        "\(completedChecklistCountToday)/\(state.checklistItems.count)"
    }

    var progressValue: Double {
        guard !state.checklistItems.isEmpty else { return 0 }
        return Double(completedChecklistCountToday) / Double(state.checklistItems.count)
    }

    var completedChecklistCountToday: Int {
        state.checklistItems.filter { isChecklistItemCompletedToday($0) }.count
    }

    func isChecklistItemCompletedToday(_ item: ChecklistItem) -> Bool {
        state.checklistCompletions.contains { $0.itemID == item.id && Calendar.current.isDateInToday($0.date) }
    }

    /// "本週完成率": of the items that have ever been checked off this week
    /// at least once, relative to the full checklist - matches the
    /// reference design's "本週已打卡 X/Y 項" framing (distinct from
    /// today's daily completion ratio above).
    var weeklyCompletionRate: (completed: Int, total: Int) {
        let calendar = Calendar.current
        let now = Date()
        let completedItemIDs = Set(
            state.checklistCompletions
                .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
                .map(\.itemID)
        )
        return (completedItemIDs.count, state.checklistItems.count)
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

    func replaceRecord<T: Identifiable>(_ item: T, in keyPath: WritableKeyPath<BeautyDiaryState, [T]>) {
        guard let index = state[keyPath: keyPath].firstIndex(where: { $0.id == item.id }) else { return }
        state[keyPath: keyPath][index] = item
        save()
    }

    /// 通用記錄刪除
    func removeRecord<T: Identifiable>(_ item: T, from keyPath: WritableKeyPath<BeautyDiaryState, [T]>) {
        state[keyPath: keyPath].removeAll { $0.id == item.id }
        save()
    }

    func save() {
        repository.save(state)
    }
}

private struct PreviewRepository: BeautyDiaryRepository {
    func load() -> BeautyDiaryState? { .seed }
    func save(_ state: BeautyDiaryState) {}
}
