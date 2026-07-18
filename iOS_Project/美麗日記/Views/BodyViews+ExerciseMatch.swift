import SwiftUI

/// AI 動作匹配:輸入需求 → exercise-match Edge Function → 動作 + 推薦理由。
struct ExerciseMatchView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var needText = ""
    @State private var results: [ExerciseMatchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var addedItemIDs: Set<String> = []

    private let service = ExerciseLibraryService.makeDefault()
    private let commonNeeds = ["瘦大腿", "翹臀", "練核心", "改善駝背", "開肩放鬆", "居家徒手燃脂", "睡前拉伸", "瘦手臂"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                titleRow(title: "AI 動作匹配") {}

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("想改善哪裡?")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("描述部位或目標,AI 會從 1,300+ 個動作中挑出最適合的組合")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)

                        ThemedTextField(title: "例如:瘦大腿、改善駝背、睡前放鬆", text: $needText)

                        FlowChips(options: commonNeeds, onTap: { needText = $0 })

                        Button {
                            Task { await runMatch() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                }
                                Text(isLoading ? "AI 匹配中…" : "開始匹配")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.primary)
                            .clipShape(Capsule())
                        }
                        .disabled(isLoading || needText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if let errorMessage {
                    CardView {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !results.isEmpty {
                    Text("為你挑選的動作")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    LazyVStack(spacing: 12) {
                        ForEach(results) { result in
                            matchCard(result)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private func matchCard(_ result: ExerciseMatchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                ExerciseLibraryDetailView(item: result.item)
            } label: {
                ExerciseLibraryItemCard(item: result.item)
            }
            .buttonStyle(.plain)

            if !result.reason.isEmpty {
                Label(result.reason, systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(AppTheme.primary)
            }

            Button {
                store.addCustomExercise(name: result.item.displayName)
                addedItemIDs.insert(result.item.id)
            } label: {
                Label(
                    addedItemIDs.contains(result.item.id) ? "已加入自訂運動" : "加入自訂運動",
                    systemImage: addedItemIDs.contains(result.item.id) ? "checkmark.circle.fill" : "plus.circle"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(addedItemIDs.contains(result.item.id) ? AppTheme.subtext : AppTheme.primary)
            }
            .disabled(addedItemIDs.contains(result.item.id))
        }
        .padding(12)
        .background(AppTheme.primarySoft.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func runMatch() async {
        let need = needText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !need.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let matches = try await service.matchExercises(need: need)
            results = matches
            addedItemIDs = []
            if matches.isEmpty {
                errorMessage = "AI 沒有找到合適的動作,換個描述試試。"
            }
        } catch {
            results = []
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("bearer") ||
                message.localizedCaseInsensitiveContains("authenticated") {
                errorMessage = "請先到「我的 → 個人設定」登入帳號,才能使用 AI 匹配。"
            } else {
                errorMessage = message
            }
        }
        isLoading = false
    }
}

/// 常用需求快速選字(自動換行排列)。
struct FlowChips: View {
    let options: [String]
    let onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    onTap(option)
                } label: {
                    Text(option)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.primarySoft)
                        .foregroundStyle(AppTheme.text)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
