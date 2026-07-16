import Combine
import Foundation

extension BeautyDiaryStore {
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
}

