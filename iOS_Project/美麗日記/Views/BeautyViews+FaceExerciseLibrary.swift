import SwiftUI

/// 面部動作庫:Supabase `face_exercise_library`
/// (面部瑜珈 / 面部按摩 / 面部訓練,每個動作附線稿示範 GIF 與分步教學)。
struct FaceExerciseLibraryView: View {
    @State private var items: [FaceExerciseItem] = []
    @State private var typeFilter: FaceExerciseTypeFilter = .all
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = FaceExerciseLibraryService.makeDefault()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                titleRow(title: "面部動作庫") {}

                Picker("類型", selection: $typeFilter) {
                    ForEach(FaceExerciseTypeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                ThemedTextField(title: "搜尋動作名稱", text: $searchText)
                    .onSubmit { Task { await reload() } }

                if isLoading && items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let errorMessage {
                    CardView {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if filteredItems.isEmpty {
                    EmptyStateView(title: "沒有符合的動作", subtitle: "換個類型或關鍵字試試")
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                FaceExerciseDetailView(item: item)
                            } label: {
                                FaceExerciseItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .task { await reload() }
        .onChange(of: typeFilter) { _ in Task { await reload() } }
    }

    private var filteredItems: [FaceExerciseItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return items }
        return items.filter {
            $0.displayName.localizedCaseInsensitiveContains(keyword)
                || $0.nameEn.localizedCaseInsensitiveContains(keyword)
                || ($0.tags ?? []).contains { $0.localizedCaseInsensitiveContains(keyword) }
        }
    }

    @MainActor
    private func reload() async {
        guard service.isConfigured else {
            errorMessage = "尚未設定 Supabase 連線。"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            items = try await service.fetchItems(typeFilter: typeFilter, search: "")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct FaceExerciseItemCard: View {
    let item: FaceExerciseItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.gifUrl ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "face.smiling")
                        .foregroundStyle(AppTheme.subtext)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                if let benefits = item.benefitsZh, !benefits.isEmpty {
                    Text(benefits)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    ForEach(item.badgeTexts.prefix(3), id: \.self) { badge in
                        Text(badge)
                            .font(.caption2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppTheme.primarySoft)
                            .foregroundStyle(AppTheme.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
        }
        .padding(12)
        .background(AppTheme.primarySoft.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// 面部動作詳情:線稿 GIF 示範 + 分步教學 + 次數與注意事項。
struct FaceExerciseDetailView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    let item: FaceExerciseItem
    @State private var addedToActions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let gifUrl = item.gifUrl, let url = URL(string: gifUrl) {
                    AnimatedGIFView(url: url)
                        .aspectRatio(1088.0 / 832.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                    if let secondary = item.secondaryName {
                        Text(secondary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    HStack(spacing: 6) {
                        ForEach(item.badgeTexts, id: \.self) { badge in
                            Text(badge)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.primarySoft)
                                .foregroundStyle(AppTheme.primary)
                                .clipShape(Capsule())
                        }
                    }
                }

                if let benefits = item.benefitsZh, !benefits.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("功效")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Text(benefits)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtext)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let steps = item.stepsZh, !steps.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("動作步驟")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 20, height: 20)
                                        .background(AppTheme.primary)
                                        .clipShape(Circle())
                                    Text(step)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                }
                            }
                            if let reps = item.repsZh, !reps.isEmpty {
                                Label(reps, systemImage: "repeat")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.primary)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let caution = item.cautionZh, !caution.isEmpty {
                    CardView {
                        Label(caution, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    store.addFaceLiftAction(name: item.displayName)
                    addedToActions = true
                } label: {
                    Label(
                        addedToActions ? "已加入我的動作庫" : "加入我的動作庫",
                        systemImage: addedToActions ? "checkmark.circle.fill" : "plus.circle"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(addedToActions ? AppTheme.subtext : Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(addedToActions ? AppTheme.primarySoft : AppTheme.primary)
                    .clipShape(Capsule())
                }
                .disabled(addedToActions)
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}

/// AI 面部動作匹配:臉部困擾 → exercise-match(library=face)→ 動作 + 理由。
struct FaceExerciseMatchSection: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var needText = ""
    @State private var results: [FaceExerciseMatchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var addedItemIDs: Set<String> = []

    private let service = FaceExerciseLibraryService.makeDefault()
    private let commonConcerns = ["法令紋", "雙下巴", "臉頰鬆弛", "抬頭紋", "魚尾紋", "嘴角下垂", "臉部水腫", "太陽穴凹陷", "下顎線模糊", "牙套臉"]

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("AI 動作匹配")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text("描述臉部困擾,AI 會從面部動作庫挑出最適合的動作組合")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)

                ThemedTextField(title: "例如:法令紋、雙下巴、臉頰鬆弛", text: $needText)

                FlowChips(options: commonConcerns, onTap: { needText = $0 })

                Button {
                    Task { await runMatch() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        }
                        Text(isLoading ? "AI 匹配中…" : "從動作庫匹配")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .clipShape(Capsule())
                }
                .disabled(isLoading || needText.trimmingCharacters(in: .whitespaces).isEmpty)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }

                if !results.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(results) { result in
                            matchCard(result)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func matchCard(_ result: FaceExerciseMatchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                FaceExerciseDetailView(item: result.item)
            } label: {
                FaceExerciseItemCard(item: result.item)
            }
            .buttonStyle(.plain)

            if !result.reason.isEmpty {
                Label(result.reason, systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(AppTheme.primary)
            }

            Button {
                store.addFaceLiftAction(name: result.item.displayName)
                addedItemIDs.insert(result.item.id)
            } label: {
                Label(
                    addedItemIDs.contains(result.item.id) ? "已加入動作庫" : "加入動作庫",
                    systemImage: addedItemIDs.contains(result.item.id) ? "checkmark.circle.fill" : "plus.circle"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(addedItemIDs.contains(result.item.id) ? AppTheme.subtext : AppTheme.primary)
            }
            .disabled(addedItemIDs.contains(result.item.id))
        }
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
