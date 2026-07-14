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
            await rescheduleHabitReminders(requestPermission: false)
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

    func toggleChecklist(_ item: ChecklistItem) {
        if isChecklistItemCompletedToday(item) {
            state.checklistCompletions.removeAll { $0.itemID == item.id && Calendar.current.isDateInToday($0.date) }
        } else {
            state.checklistCompletions.append(ChecklistCompletionEntry(id: UUID(), itemID: item.id, date: Date()))
        }
        save()
    }

    func addCustomChecklistItem(title: String, category: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.checklistItems.append(ChecklistItem(id: UUID(), title: trimmed, category: category))
        save()
    }

    func deleteChecklistItem(_ item: ChecklistItem) {
        state.checklistItems.removeAll { $0.id == item.id }
        state.checklistCompletions.removeAll { $0.itemID == item.id }
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

    func addWhiteningProductUsage(productName: String, note: String) {
        let trimmed = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.whiteningProductUsages.insert(
            WhiteningProductUsage(id: UUID(), date: Date(), productName: trimmed, note: note),
            at: 0
        )
        save()
    }

    func deleteWhiteningProductUsage(_ record: WhiteningProductUsage) {
        state.whiteningProductUsages.removeAll { $0.id == record.id }
        save()
    }

    func addShadeTrackingRecord(shadeName: String, note: String) {
        let trimmed = shadeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.shadeTrackingRecords.insert(
            ShadeTrackingRecord(id: UUID(), date: Date(), shadeName: trimmed, note: note),
            at: 0
        )
        save()
    }

    func deleteShadeTrackingRecord(_ record: ShadeTrackingRecord) {
        state.shadeTrackingRecords.removeAll { $0.id == record.id }
        save()
    }

    func addBeforeAfterPhoto(beforeImageData: Data?, afterImageData: Data?, note: String) {
        guard beforeImageData != nil || afterImageData != nil else { return }

        state.beforeAfterPhotos.insert(
            BeforeAfterPhotoPair(id: UUID(), date: Date(), beforeImageData: beforeImageData, afterImageData: afterImageData, note: note),
            at: 0
        )
        save()
    }

    func deleteBeforeAfterPhoto(_ pair: BeforeAfterPhotoPair) {
        state.beforeAfterPhotos.removeAll { $0.id == pair.id }
        save()
    }

    func addFavoriteRecipe(title: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.favoriteRecipes.append(TutorialLink(id: UUID(), title: trimmed, url: url))
        save()
    }

    func deleteFavoriteRecipe(_ recipe: TutorialLink) {
        state.favoriteRecipes.removeAll { $0.id == recipe.id }
        save()
    }

    func setFaceShape(_ shape: String) {
        state.faceShape = shape
        save()
    }

    func addSavedHairstyle(title: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.savedHairstyles.append(TutorialLink(id: UUID(), title: trimmed, url: url))
        save()
    }

    func deleteSavedHairstyle(_ hairstyle: TutorialLink) {
        state.savedHairstyles.removeAll { $0.id == hairstyle.id }
        save()
    }

    func addMakeupInspiration(title: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.makeupInspirations.append(TutorialLink(id: UUID(), title: trimmed, url: url))
        save()
    }

    func deleteMakeupInspiration(_ inspiration: TutorialLink) {
        state.makeupInspirations.removeAll { $0.id == inspiration.id }
        save()
    }

    func addExercisePunch(category: String, durationMinutes: Int) {
        state.exercisePunches.insert(
            ExercisePunchRecord(id: UUID(), date: Date(), category: category, durationMinutes: durationMinutes),
            at: 0
        )
        save()
    }

    func deleteExercisePunch(_ record: ExercisePunchRecord) {
        state.exercisePunches.removeAll { $0.id == record.id }
        save()
    }

    func addCustomExercise(name: String, linkedResourceRemoteID: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 同一篇教學筆記不重複加入
        if let linkedResourceRemoteID,
           state.customExercises.contains(where: { $0.linkedResourceRemoteID == linkedResourceRemoteID }) {
            return
        }

        state.customExercises.append(
            CustomExercise(id: UUID(), name: trimmed, linkedResourceRemoteID: linkedResourceRemoteID)
        )
        save()
    }

    func deleteCustomExercise(_ exercise: CustomExercise) {
        state.customExercises.removeAll { $0.id == exercise.id }
        save()
    }

    func setShapingGoal(targetWeight: Double?, targetBodyFat: Double?) {
        state.targetWeight = targetWeight
        state.targetBodyFat = targetBodyFat
        save()
    }

    func addTrainingScheduleItem(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.trainingSchedule.append(TrainingScheduleItem(id: UUID(), name: trimmed))
        save()
    }

    func deleteTrainingScheduleItem(_ item: TrainingScheduleItem) {
        state.trainingSchedule.removeAll { $0.id == item.id }
        save()
    }

    var exerciseCompletionRates: (week: Int, month: Int, total: Int) {
        let calendar = Calendar.current
        let now = Date()
        let weekCount = state.exercisePunches.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }.count
        let monthCount = state.exercisePunches.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }.count
        let weeklyGoal = 7
        let monthlyGoal = 30
        let weekPercent = min(100, Int(Double(weekCount) / Double(weeklyGoal) * 100))
        let monthPercent = min(100, Int(Double(monthCount) / Double(monthlyGoal) * 100))
        return (weekPercent, monthPercent, state.exercisePunches.count)
    }

    func addSymptomRecord(symptom: String, note: String) {
        let trimmed = symptom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.symptomRecords.insert(
            SymptomRecord(id: UUID(), date: Date(), symptom: trimmed, note: note),
            at: 0
        )
        save()
    }

    func deleteSymptomRecord(_ record: SymptomRecord) {
        state.symptomRecords.removeAll { $0.id == record.id }
        save()
    }

    var symptomFrequency: [(symptom: String, count: Int)] {
        let grouped = Dictionary(grouping: state.symptomRecords, by: \.symptom)
        return grouped.map { (symptom: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }
    }

    func addMenstrualRecord(note: String) {
        state.menstrualRecords.insert(MenstrualRecord(id: UUID(), date: Date(), note: note), at: 0)
        save()
    }

    func deleteMenstrualRecord(_ record: MenstrualRecord) {
        state.menstrualRecords.removeAll { $0.id == record.id }
        save()
    }

    func addNourishmentRecipe(title: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.nourishmentRecipes.append(TutorialLink(id: UUID(), title: trimmed, url: url))
        save()
    }

    func deleteNourishmentRecipe(_ link: TutorialLink) {
        state.nourishmentRecipes.removeAll { $0.id == link.id }
        save()
    }

    func setBodyConstitution(_ constitution: String) {
        state.bodyConstitution = constitution
        save()
    }

    func addBodyAlbumPhoto(imageData: Data?, note: String) {
        guard let imageData else { return }

        state.bodyAlbumPhotos.insert(
            BodyAlbumPhoto(id: UUID(), date: Date(), imageData: imageData, note: note),
            at: 0
        )
        save()
    }

    func deleteBodyAlbumPhoto(_ photo: BodyAlbumPhoto) {
        state.bodyAlbumPhotos.removeAll { $0.id == photo.id }
        save()
    }

    func addCourse(title: String, platform: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.courses.append(Course(id: UUID(), title: trimmed, platform: platform, url: url, progressPercent: 0))
        save()
    }

    func deleteCourse(_ course: Course) {
        state.courses.removeAll { $0.id == course.id }
        save()
    }

    func updateCourseProgress(_ course: Course, progressPercent: Int) {
        guard let index = state.courses.firstIndex(where: { $0.id == course.id }) else { return }
        state.courses[index].progressPercent = min(100, max(0, progressPercent))
        save()
    }

    func addKnowledgeNote(title: String, content: String, tags: [String]) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.knowledgeNotes.insert(
            KnowledgeNote(id: UUID(), date: Date(), title: trimmed, content: content, tags: tags),
            at: 0
        )
        save()
    }

    func deleteKnowledgeNote(_ note: KnowledgeNote) {
        state.knowledgeNotes.removeAll { $0.id == note.id }
        save()
    }

    func addVideoLearningRecord(title: String, contentType: String, platform: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.videoLearningRecords.append(
            VideoLearningRecord(id: UUID(), title: trimmed, contentType: contentType, platform: platform, url: url, watched: false)
        )
        save()
    }

    func toggleVideoLearningWatched(_ record: VideoLearningRecord) {
        guard let index = state.videoLearningRecords.firstIndex(where: { $0.id == record.id }) else { return }
        state.videoLearningRecords[index].watched.toggle()
        save()
    }

    func deleteVideoLearningRecord(_ record: VideoLearningRecord) {
        state.videoLearningRecords.removeAll { $0.id == record.id }
        save()
    }

    func addSelfAffirmation(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.selfAffirmations.append(SelfAffirmation(id: UUID(), text: trimmed))
        save()
    }

    func deleteSelfAffirmation(_ item: SelfAffirmation) {
        state.selfAffirmations.removeAll { $0.id == item.id }
        save()
    }

    func addVisionBoardItem(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.visionBoardItems.append(VisionBoardItem(id: UUID(), text: trimmed))
        save()
    }

    func deleteVisionBoardItem(_ item: VisionBoardItem) {
        state.visionBoardItems.removeAll { $0.id == item.id }
        save()
    }

    func addGratitudeEntry(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.gratitudeEntries.insert(GratitudeEntry(id: UUID(), date: Date(), text: trimmed), at: 0)
        save()
    }

    func deleteGratitudeEntry(_ entry: GratitudeEntry) {
        state.gratitudeEntries.removeAll { $0.id == entry.id }
        save()
    }

    func addMoodEntry(mood: String, note: String) {
        state.moodEntries.insert(MoodEntry(id: UUID(), date: Date(), mood: mood, note: note), at: 0)
        save()
    }

    func deleteMoodEntry(_ entry: MoodEntry) {
        state.moodEntries.removeAll { $0.id == entry.id }
        save()
    }

    func addTransaction(type: TransactionType, amount: Double, category: String, account: String, note: String) {
        guard amount > 0 else { return }

        state.transactions.insert(
            Transaction(id: UUID(), date: Date(), type: type, amount: amount, category: category, account: account, note: note),
            at: 0
        )
        save()
    }

    func deleteTransaction(_ transaction: Transaction) {
        state.transactions.removeAll { $0.id == transaction.id }
        save()
    }

    private var currentMonthTransactions: [Transaction] {
        state.transactions.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    var monthlyIncome: Double {
        currentMonthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var monthlyExpense: Double {
        currentMonthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    func accountBalance(_ account: String) -> Double {
        state.transactions.filter { $0.account == account }.reduce(0) { total, transaction in
            total + (transaction.type == .income ? transaction.amount : -transaction.amount)
        }
    }

    var expenseByCategory: [(category: String, total: Double)] {
        let expenses = currentMonthTransactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped.map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    func setBudget(category: String, amount: Double) {
        if let index = state.budgetCategories.firstIndex(where: { $0.category == category }) {
            state.budgetCategories[index].amount = amount
        } else {
            state.budgetCategories.append(BudgetCategory(id: UUID(), category: category, amount: amount))
        }
        save()
    }

    var totalBudget: Double {
        state.budgetCategories.reduce(0) { $0 + $1.amount }
    }

    var savingsRate: Double {
        guard monthlyIncome > 0 else { return 0 }
        return (monthlyIncome - monthlyExpense) / monthlyIncome
    }

    var beautyFundBalance: Double {
        state.beautyFundTransactions.reduce(0) { total, transaction in
            total + (transaction.type == .deposit ? transaction.amount : -transaction.amount)
        }
    }

    func addBeautyFundTransaction(type: BeautyFundTransactionType, amount: Double) {
        guard amount > 0 else { return }

        state.beautyFundTransactions.append(BeautyFundTransaction(id: UUID(), date: Date(), type: type, amount: amount))
        save()
    }

    func addWish(name: String, targetAmount: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.wishes.append(Wish(id: UUID(), name: trimmed, targetAmount: targetAmount))
        save()
    }

    func deleteWish(_ wish: Wish) {
        state.wishes.removeAll { $0.id == wish.id }
        save()
    }

    func addShoppingItem(name: String, estimatedPrice: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.shoppingItems.append(ShoppingItem(id: UUID(), name: trimmed, estimatedPrice: estimatedPrice, isPurchased: false))
        save()
    }

    func toggleShoppingItem(_ item: ShoppingItem) {
        guard let index = state.shoppingItems.firstIndex(where: { $0.id == item.id }) else { return }
        state.shoppingItems[index].isPurchased.toggle()
        save()
    }

    func deleteShoppingItem(_ item: ShoppingItem) {
        state.shoppingItems.removeAll { $0.id == item.id }
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
    @Published private(set) var aiAdviceRoutineSteps: [AIAdviceTopic: [String]] = [:]
    @Published private(set) var aiAdviceProducts: [AIAdviceTopic: [String]] = [:]
    @Published private(set) var aiAdviceRelatedResources: [AIAdviceTopic: [AIAdviceRelatedResource]] = [:]
    @Published private(set) var aiAdviceErrorMessage: [AIAdviceTopic: String] = [:]
    @Published private(set) var loadingAIAdviceTopics: Set<AIAdviceTopic> = []
    @Published var productLookupError: String?
    @Published private(set) var isLookingUpProduct = false
    @Published var foodAnalysisError: String?
    @Published private(set) var isAnalyzingFood = false

    func suggestions(for topic: AIAdviceTopic) -> [String] {
        aiAdviceSuggestions[topic] ?? []
    }

    func recommendedRoutineSteps(for topic: AIAdviceTopic) -> [String] {
        aiAdviceRoutineSteps[topic] ?? []
    }

    func recommendedProducts(for topic: AIAdviceTopic) -> [String] {
        aiAdviceProducts[topic] ?? []
    }

    func relatedResources(for topic: AIAdviceTopic) -> [AIAdviceRelatedResource] {
        aiAdviceRelatedResources[topic] ?? []
    }

    /// 以遠端記錄 ID 找回本地資源（AI 推薦跳轉教學用）
    func resourceItem(remoteID: String) -> ResourceItem? {
        state.resourceItems.first { $0.remoteRecordID == remoteID }
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
            let result = try await cloudSyncService.requestAIAdvice(topic: topic, concerns: concerns)
            aiAdviceSuggestions[topic] = result.suggestions
            aiAdviceRoutineSteps[topic] = result.routineSteps
            aiAdviceProducts[topic] = result.products
            aiAdviceRelatedResources[topic] = result.relatedResources
        } catch {
            aiAdviceErrorMessage[topic] = error.localizedDescription
        }

        loadingAIAdviceTopics.remove(topic)
    }

    /// Looks up product info from a name and/or a photo via AI, so 新增保養品
    /// doesn't require the user to type in brand/category/notes by hand.
    func requestProductLookup(name: String?, imageData: Data?) async -> ProductLookupResult? {
        guard authSession != nil else {
            productLookupError = "請先登入雲端同步帳號，才能使用 AI 產品辨識功能。"
            return nil
        }

        isLookingUpProduct = true
        productLookupError = nil

        defer { isLookingUpProduct = false }

        do {
            guard let result = try await cloudSyncService.requestProductLookup(name: name, imageData: imageData) else {
                productLookupError = "AI 無法辨識這個產品，請手動輸入。"
                return nil
            }
            return result
        } catch {
            productLookupError = error.localizedDescription
            return nil
        }
    }

    func analyzeFood(text: String?, imageData: Data?) async -> FoodAnalysisResult? {
        guard authSession != nil else {
            foodAnalysisError = "請先登入雲端同步帳號，才能使用 AI 熱量估算功能。"
            return nil
        }

        isAnalyzingFood = true
        foodAnalysisError = nil
        defer { isAnalyzingFood = false }

        do {
            guard let result = try await cloudSyncService.requestFoodAnalysis(text: text, imageData: imageData) else {
                foodAnalysisError = "AI 無法辨識這份餐點，請手動輸入餐點內容與熱量。"
                return nil
            }
            return result
        } catch {
            foodAnalysisError = error.localizedDescription
            return nil
        }
    }

    // MARK: - TDEE 每日熱量目標

    func updateTDEEProfile(_ profile: TDEEProfile) {
        state.tdeeProfile = profile
        save()
    }

    /// 以最近體重紀錄（無則不計）計算每日建議攝取熱量
    func dailyCalorieTarget() -> Int? {
        guard let latestWeight = state.bodyMetricRecords.first?.weight else { return nil }
        return state.tdeeProfile.dailyCalorieTarget(weightKG: latestWeight)
    }

    // MARK: - 習慣提醒

    func setHabitReminder(_ kind: HabitReminderKind, timeString: String?) {
        if let timeString, !timeString.isEmpty {
            state.habitReminderTimes[kind.rawValue] = timeString
        } else {
            state.habitReminderTimes.removeValue(forKey: kind.rawValue)
        }
        save()
        Task { await rescheduleHabitReminders(requestPermission: true) }
    }

    func habitReminderTime(_ kind: HabitReminderKind) -> String? {
        state.habitReminderTimes[kind.rawValue]
    }

    func rescheduleHabitReminders(requestPermission: Bool) async {
        guard !state.habitReminderTimes.isEmpty else { return }
        do {
            let isAuthorized = requestPermission
                ? try await notificationScheduler.requestAuthorizationIfNeeded()
                : true
            guard isAuthorized else {
                authMessage = "通知權限已關閉，請至「設定」開啟才能收到提醒。"
                return
            }
            try await notificationScheduler.scheduleHabitReminders(
                state.habitReminderTimes,
                nickname: state.profile.nickname
            )
        } catch {
            authMessage = error.localizedDescription
        }
    }

    // MARK: - 每週回顧

    struct WeeklyReview {
        let punchCount: Int
        let exerciseMinutes: Int
        let mealCount: Int
        let averageDailyCalories: Int?
        let weightDelta: Double?
        let moodSummary: String?
    }

    /// 最近 7 天的活動摘要，供首頁「每週回顧」卡
    func weeklyReview(now: Date = Date()) -> WeeklyReview {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return WeeklyReview(punchCount: 0, exerciseMinutes: 0, mealCount: 0, averageDailyCalories: nil, weightDelta: nil, moodSummary: nil)
        }

        let punches = state.punchRecords.filter { $0.date >= weekAgo }.count
            + state.exercisePunches.filter { $0.date >= weekAgo }.count
        let exerciseMinutes = state.exercisePunches
            .filter { $0.date >= weekAgo }
            .reduce(0) { $0 + $1.durationMinutes }

        let weekMeals = state.mealRecords.filter { $0.date >= weekAgo }
        let calorieDays = Dictionary(grouping: weekMeals.filter { $0.calories != nil }) {
            calendar.startOfDay(for: $0.date)
        }
        let averageCalories: Int? = calorieDays.isEmpty ? nil : calorieDays.values
            .map { $0.compactMap(\.calories).reduce(0, +) }
            .reduce(0, +) / calorieDays.count

        var weightDelta: Double?
        let weekMetrics = state.bodyMetricRecords.filter { $0.date >= weekAgo }.sorted { $0.date < $1.date }
        if let first = weekMetrics.first, let last = weekMetrics.last, weekMetrics.count >= 2 {
            weightDelta = last.weight - first.weight
        }

        let weekMoods = state.moodEntries.filter { $0.date >= weekAgo }
        let moodSummary = weekMoods.isEmpty ? nil : Dictionary(grouping: weekMoods, by: \.mood)
            .max { $0.value.count < $1.value.count }?.key

        return WeeklyReview(
            punchCount: punches,
            exerciseMinutes: exerciseMinutes,
            mealCount: weekMeals.count,
            averageDailyCalories: averageCalories,
            weightDelta: weightDelta,
            moodSummary: moodSummary
        )
    }

    /// 近 7 天每日熱量合計（含無記錄日=0），供飲食頁長條圖
    func dailyCalorieTotals(days: Int = 7, now: Date = Date()) -> [(date: Date, calories: Int)] {
        let calendar = Calendar.current
        let mealsByDay = Dictionary(grouping: state.mealRecords) { calendar.startOfDay(for: $0.date) }
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) else { return nil }
            let total = (mealsByDay[day] ?? []).compactMap(\.calories).reduce(0, +)
            return (day, total)
        }
    }

    // MARK: - AI 建議自訂常用問題

    func customConcerns(for topic: AIAdviceTopic) -> [String] {
        state.customAdviceConcerns[topic.rawValue] ?? []
    }

    func addCustomConcern(_ concern: String, for topic: AIAdviceTopic) {
        let trimmed = concern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = state.customAdviceConcerns[topic.rawValue] ?? []
        guard !list.contains(trimmed) else { return }
        list.append(trimmed)
        state.customAdviceConcerns[topic.rawValue] = list
        save()
    }

    func removeCustomConcern(_ concern: String, for topic: AIAdviceTopic) {
        var list = state.customAdviceConcerns[topic.rawValue] ?? []
        list.removeAll { $0 == concern }
        state.customAdviceConcerns[topic.rawValue] = list
        save()
    }

    // MARK: - 區域目標與彙整建議

    func setAreaGoal(_ area: String, goal: String) {
        state.areaGoals[area] = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func areaGoal(_ area: String) -> String {
        state.areaGoals[area] ?? ""
    }

    /// 依區域彙整近期記錄成摘要句，供本地顯示與 AI 建議的輸入
    func areaRecordsDigest(_ area: String) -> [String] {
        var digest: [String] = []
        switch area {
        case "變美":
            if let latest = state.skinRecords.first {
                digest.append("最近膚況：\(latest.skinType)，困擾 \(latest.concerns.joined(separator: "、"))")
            }
            digest.append("護膚打卡 \(state.punchRecords.count) 次、膚況紀錄 \(state.skinRecords.count) 筆")
            if !state.whiteningProductUsages.isEmpty {
                digest.append("美白產品使用 \(state.whiteningProductUsages.count) 次")
            }
            if let shape = state.faceShape, !shape.isEmpty {
                digest.append("臉型：\(shape)")
            }
        case "體態":
            let metrics = state.bodyMetricRecords
            if let latest = metrics.first {
                digest.append("目前體重 \(latest.weight)kg、體脂 \(latest.bodyFat)%")
            }
            if metrics.count >= 2, let latest = metrics.first, let oldest = metrics.last {
                let delta = latest.weight - oldest.weight
                digest.append(String(format: "累計體重變化 %+.1fkg（共 %d 筆記錄）", delta, metrics.count))
            }
            let totalMinutes = state.exercisePunches.reduce(0) { $0 + $1.durationMinutes }
            if !state.exercisePunches.isEmpty {
                digest.append("運動打卡 \(state.exercisePunches.count) 次，共 \(totalMinutes) 分鐘")
            }
            if !state.mealRecords.isEmpty {
                digest.append("飲食記錄 \(state.mealRecords.count) 筆")
            }
        case "成長":
            if !state.courses.isEmpty {
                let avg = state.courses.reduce(0) { $0 + $1.progressPercent } / max(state.courses.count, 1)
                digest.append("課程 \(state.courses.count) 門，平均進度 \(avg)%")
            }
            if !state.bookRecords.isEmpty {
                digest.append("閱讀書目 \(state.bookRecords.count) 本")
            }
            if !state.knowledgeNotes.isEmpty {
                digest.append("知識筆記 \(state.knowledgeNotes.count) 篇")
            }
            if let mood = state.moodEntries.first {
                digest.append("最近心情：\(mood.mood)")
            }
        case "財務":
            let expenses = state.transactions.filter { $0.type == .expense }
            let income = state.transactions.filter { $0.type == .income }
            let totalExpense = expenses.reduce(0.0) { $0 + $1.amount }
            let totalIncome = income.reduce(0.0) { $0 + $1.amount }
            digest.append(String(format: "累計支出 %.0f、收入 %.0f（%d 筆交易）", totalExpense, totalIncome, state.transactions.count))
            if !state.budgetCategories.isEmpty {
                let totalBudget = state.budgetCategories.reduce(0.0) { $0 + $1.amount }
                digest.append(String(format: "預算共 %.0f，分 %d 類", totalBudget, state.budgetCategories.count))
            }
            if !state.wishes.isEmpty {
                digest.append("儲蓄願望 \(state.wishes.count) 項")
            }
        default:
            break
        }
        if digest.isEmpty {
            digest.append("此區域還沒有任何記錄，先從新增第一筆開始。")
        }
        return digest
    }

    /// 通用記錄編輯：以 id 比對後整筆替換，適用於所有 state 內的記錄陣列
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

    func addMealRecord(type: String, summary: String, note: String, calories: Int? = nil, photoData: Data? = nil) {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.mealRecords.insert(
            MealRecord(
                id: UUID(),
                date: Date(),
                mealType: type,
                summary: trimmed,
                note: note,
                calories: calories ?? CalorieEstimator.estimate(from: trimmed),
                photoData: photoData
            ),
            at: 0
        )
        save()
    }

    /// 今日各餐與總熱量
    func todayCalorieSummary() -> (meals: [MealRecord], total: Int) {
        let todays = state.mealRecords.filter { Calendar.current.isDateInToday($0.date) }
        let total = todays.compactMap(\.calories).reduce(0, +)
        return (todays, total)
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

    func setThemeName(_ name: String) {
        state.profile.themeName = name
        save()
    }

    func setMorningReminderTime(_ time: String) {
        state.profile.morningReminderTime = time
        save()
    }

    func setEveningReminderTime(_ time: String) {
        state.profile.notificationTime = time
        save()
    }

    func toggleModule(_ module: String) {
        if state.profile.enabledModules.contains(module) {
            state.profile.enabledModules.remove(module)
        } else {
            state.profile.enabledModules.insert(module)
        }
        save()
    }

    func clearAllLocalData() {
        state = .seed
        save()
    }

    var hasPerfectChecklistDay: Bool {
        guard !state.checklistItems.isEmpty else { return false }
        let grouped = Dictionary(grouping: state.checklistCompletions) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.values.contains { dayEntries in
            Set(dayEntries.map(\.itemID)).count >= state.checklistItems.count
        }
    }

    var hasUsedBeautyModule: Bool {
        !state.skinRecords.isEmpty || !state.hairCareRecords.isEmpty || !state.faceLiftActions.isEmpty || !state.bodySkinRecords.isEmpty
    }

    var hasUsedBodyModule: Bool {
        !state.bodyMetricRecords.isEmpty || !state.exercisePunches.isEmpty || !state.mealRecords.isEmpty
    }

    var hasUsedGrowthModule: Bool {
        !state.bookRecords.isEmpty || !state.courses.isEmpty || !state.knowledgeNotes.isEmpty
    }

    var knowledgeRecordCount: Int {
        state.knowledgeNotes.count + state.courses.count + state.bookRecords.count + state.videoLearningRecords.count
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
            authMessage = "Supabase 尚未設定。"
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

    func signUpToSupabase(email: String, password: String) async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else {
            authStatus = .unavailable
            authMessage = "Supabase 尚未設定。"
            return
        }

        authStatus = .authenticating
        authMessage = nil

        do {
            let session = try await authService.signUp(email: email, password: password)
            if let session {
                authSession = session
                authStatus = .authenticated
                authMessage = "註冊成功，已自動登入。"
                await reconcileCurrentUserProfileWithCloud()
                await fetchAIProviderSettingsFromCloud()
                await refreshCloudResources()
                await syncPendingResources()
            } else {
                authStatus = .signedOut
                authMessage = "帳號已建立，請至信箱完成驗證後再登入。"
            }
        } catch {
            authStatus = .signedOut
            authMessage = error.localizedDescription
        }
    }

    func signInToSupabase(email: String, password: String) async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else {
            authStatus = .unavailable
            authMessage = "Supabase 尚未設定。"
            return
        }

        authStatus = .authenticating
        authMessage = nil

        do {
            let session = try await authService.signIn(email: email, password: password)
            authSession = session
            authStatus = .authenticated
            authMessage = "登入成功，雲端同步已就緒。"
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
            authMessage = "已透過 Email 連結完成登入。"
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
            authMessage = "Supabase 尚未設定。"
            return
        }

        authStatus = .authenticating
        authMessage = nil

        do {
            try await authService.requestMagicLink(email: email)
            authStatus = authSession == nil ? .signedOut : .authenticated
            authMessage = "登入連結已寄出，請至信箱完成登入。"
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
            authMessage = "請先登入 Supabase 才能同步。"
            return
        }

        authMessage = nil
        await reconcileCurrentUserProfileWithCloud()
        await syncPendingResources(respectBackoff: false)
        await refreshCloudResources()
        authMessage = "雲端同步完成。"
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

    /// 小紅書影片筆記同步成功後，背景觸發雲端語音轉錄整理教學步驟。
    /// 非同步、不等待完成也不擋 UI；結果之後靠 refreshCloudResources 帶回。
    private func requestVideoTranscriptionIfNeeded(for item: ResourceItem) async {
        guard item.source == .xiaohongshu,
              item.platformContentType == .video,
              !item.remoteRecordID.isEmpty,
              !item.descriptionText.contains("📋 教學步驟") else { return }
        guard let videoURL = item.mediaAssets.first(where: { $0.type == .video })?.remoteURL,
              !videoURL.isEmpty else { return }

        await cloudSyncService.requestVideoTranscription(resourceRemoteID: item.remoteRecordID, videoURL: videoURL)
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
                authMessage = "通知權限已關閉，請至「設定」開啟才能收到提醒。"
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
            authMessage = "登入 Supabase 後，AI 設定才能同步到其他裝置。"
            return
        }

        do {
            try await cloudSyncService.upsertAIProviderSettings(session: session, settings: settings)
            authMessage = "AI 提供者設定已儲存。"
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await saveAIProviderSettings(settings, allowRetry: false)
                return
            }
            authMessage = "已儲存在本機，但雲端同步失敗：\(error.localizedDescription)"
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
            authMessage = "已從本機移除，但雲端刪除失敗：\(error.localizedDescription)"
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
            authMessage = "登入已過期，請重新登入。"
            return false
        }

        authSession = restoredSession
        authStatus = .authenticated
        authMessage = "登入狀態已更新，正在重新同步。"
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
            await requestVideoTranscriptionIfNeeded(for: state.resourceItems[resourceIndex])
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
