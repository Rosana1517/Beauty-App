import Combine
import Foundation

extension BeautyDiaryStore {
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
}
