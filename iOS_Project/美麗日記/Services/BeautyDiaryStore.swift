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

final class BeautyDiaryStore: ObservableObject {
    @Published private(set) var state: BeautyDiaryState

    private let repository: BeautyDiaryRepository
    private let recommendationService = MockRecommendationService()

    init(repository: BeautyDiaryRepository = JSONBeautyDiaryRepository()) {
        self.repository = repository
        self.state = repository.load() ?? .seed
        self.repository.save(self.state)
    }

    static let preview = BeautyDiaryStore(repository: PreviewRepository())

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

        state.resourceItems.insert(
            ResourceItem(
                id: UUID(),
                title: trimmed,
                source: source,
                category: category,
                url: url,
                summary: summary
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

    private func unlockBadgeIfNeeded(title: String, when condition: Bool) {
        guard condition, let index = state.achievements.firstIndex(where: { $0.title == title }) else { return }
        state.achievements[index].unlocked = true
    }

    private func save() {
        repository.save(state)
    }
}

private struct PreviewRepository: BeautyDiaryRepository {
    func load() -> BeautyDiaryState? { .seed }
    func save(_ state: BeautyDiaryState) {}
}
