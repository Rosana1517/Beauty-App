import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct AIAdviceSection: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    let topic: AIAdviceTopic
    let title: String
    let subtitle: String
    let commonConcerns: [String]
    let buttonTitle: String
    /// 靜默併入 AI 請求的背景資訊（例如症狀歷史、目標），不會顯示成使用者的問題 chip
    var additionalContext: [String] = []
    var onAddRoutineStep: ((String) -> Void)?
    var onAddProduct: ((String) -> Void)?
    var onAddExercise: ((AIAdviceRelatedResource) -> Void)?
    var onAddRecipe: ((String) -> Void)?

    @State private var selectedConcerns: Set<String> = []
    @State private var customConcern = ""
    @State private var selectedCustomConcerns: Set<String> = []
    @State private var addedRoutineSteps: Set<String> = []
    @State private var addedProducts: Set<String> = []
    @State private var addedRecipeSuggestions: Set<String> = []
    @State private var addedExerciseResourceIDs: Set<String> = []
    @State private var viewingTutorial: ResourceItem?
    @State private var tutorialMissingMessage: String?

    private var allConcerns: [String] {
        Array(selectedConcerns) + Array(selectedCustomConcerns) + additionalContext
    }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)

                if !commonConcerns.isEmpty {
                    WrapToggleChips(items: commonConcerns, selection: $selectedConcerns)
                }

                HStack(spacing: 10) {
                    ThemedTextField(title: "自訂問題…", text: $customConcern)
                    Button("加入") {
                        let trimmed = customConcern.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        store.addCustomConcern(trimmed, for: topic)
                        selectedCustomConcerns.insert(trimmed)
                        customConcern = ""
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                }

                let savedCustomConcerns = store.customConcerns(for: topic)
                if !savedCustomConcerns.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("我的常用問題（點選使用，長按刪除）")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                        WrapToggleChips(items: savedCustomConcerns, selection: $selectedCustomConcerns)
                            .contextMenu {
                                ForEach(savedCustomConcerns, id: \.self) { concern in
                                    Button(role: .destructive) {
                                        store.removeCustomConcern(concern, for: topic)
                                        selectedCustomConcerns.remove(concern)
                                    } label: {
                                        Label("刪除「\(concern)」", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }

                PrimaryButton(title: store.isLoadingAdvice(for: topic) ? "正在取得建議…" : buttonTitle) {
                    Task { await store.requestAIAdvice(topic: topic, concerns: allConcerns) }
                }
                .disabled(store.isLoadingAdvice(for: topic))

                if let errorMessage = store.errorMessage(for: topic) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !store.suggestions(for: topic).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.suggestions(for: topic), id: \.self) { suggestion in
                            if let onAddRecipe {
                                recommendationRow(
                                    text: suggestion,
                                    added: addedRecipeSuggestions.contains(suggestion),
                                    actionTitle: "加入收藏食譜"
                                ) {
                                    onAddRecipe(suggestion)
                                    addedRecipeSuggestions.insert(suggestion)
                                }
                            } else {
                                Text("• \(suggestion)")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }

                if let onAddRoutineStep, !store.recommendedRoutineSteps(for: topic).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("建議加入護膚流程")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)

                        ForEach(store.recommendedRoutineSteps(for: topic), id: \.self) { step in
                            recommendationRow(
                                text: step,
                                added: addedRoutineSteps.contains(step),
                                actionTitle: "加入護膚流程"
                            ) {
                                onAddRoutineStep(step)
                                addedRoutineSteps.insert(step)
                            }
                        }
                    }
                }

                if let onAddProduct, !store.recommendedProducts(for: topic).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("建議加入保養品清單")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)

                        ForEach(store.recommendedProducts(for: topic), id: \.self) { product in
                            recommendationRow(
                                text: product,
                                added: addedProducts.contains(product),
                                actionTitle: "加入保養品"
                            ) {
                                onAddProduct(product)
                                addedProducts.insert(product)
                            }
                        }
                    }
                }

                let related = store.relatedResources(for: topic)
                if !related.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("資料庫相關教學")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)

                        ForEach(related) { resource in
                            HStack(spacing: 10) {
                                AsyncImage(url: URL(string: resource.thumbnailURL)) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFill()
                                    } else {
                                        AppTheme.primarySoft
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(resource.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                        .lineLimit(2)
                                    if !resource.author.isEmpty {
                                        Text(resource.author)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    HStack(spacing: 12) {
                                        Button("查看教學") {
                                            if let item = store.resourceItem(remoteID: resource.id) {
                                                viewingTutorial = item
                                            } else {
                                                tutorialMissingMessage = "教學內容還沒同步到本機，請先登入並到「資源庫」下拉更新後再試。"
                                            }
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)

                                        if let onAddExercise {
                                            Button(addedExerciseResourceIDs.contains(resource.id) ? "已加入" : "加入運動管理") {
                                                onAddExercise(resource)
                                                addedExerciseResourceIDs.insert(resource.id)
                                            }
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(addedExerciseResourceIDs.contains(resource.id) ? AppTheme.subtext : AppTheme.primary)
                                            .disabled(addedExerciseResourceIDs.contains(resource.id))
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if let tutorialMissingMessage {
                            Text(tutorialMissingMessage)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .sheet(item: $viewingTutorial) { item in
            NavigationStack {
                ResourceDetailView(item: item)
                    .background(AppTheme.background)
            }
        }
    }

    private func recommendationRow(text: String, added: Bool, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("• \(text)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(added ? "已加入" : actionTitle, action: action)
                .font(.caption.weight(.semibold))
                .foregroundStyle(added ? AppTheme.subtext : AppTheme.primary)
                .disabled(added)
        }
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
