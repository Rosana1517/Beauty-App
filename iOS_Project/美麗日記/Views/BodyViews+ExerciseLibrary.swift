import SwiftUI

/// 運動資料庫清單:1,324 個健身動作 + 48 個瑜伽體式(Supabase exercise_library)。
struct ExerciseLibraryView: View {
    @State private var items: [ExerciseLibraryItem] = []
    @State private var page = 0
    @State private var canLoadMore = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var typeFilter: ExerciseLibraryTypeFilter = .all
    @State private var selectedBodyPart: String?
    @State private var selectedDifficulty: String?
    @State private var searchText = ""

    private let service = ExerciseLibraryService.makeDefault()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                titleRow(title: "運動資料庫") {}

                searchField
                typeChips
                if typeFilter != .yoga {
                    bodyPartChips
                }
                if typeFilter == .yoga {
                    difficultyChips
                }

                if let errorMessage {
                    errorCard(errorMessage)
                } else if items.isEmpty && !isLoading {
                    EmptyStateView(title: "找不到符合的動作", subtitle: "換個篩選條件或關鍵字試試")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            NavigationLink {
                                ExerciseLibraryDetailView(item: item)
                            } label: {
                                ExerciseLibraryItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("exerciseLibrary.itemCard")
                        }
                    }

                    if canLoadMore {
                        Button(isLoading ? "載入中…" : "載入更多") {
                            Task { await loadPage(reset: false) }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .disabled(isLoading)
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .task { await loadPage(reset: true) }
        .onChange(of: typeFilter) { _ in resetAndReload() }
        .onChange(of: selectedBodyPart) { _ in resetAndReload() }
        .onChange(of: selectedDifficulty) { _ in resetAndReload() }
        .onSubmit(of: .text) { resetAndReload() }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.subtext)
            TextField("搜尋動作名稱(中/英文)", text: $searchText)
                .submitLabel(.search)
                .accessibilityIdentifier("exerciseLibrary.searchField")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    resetAndReload()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.subtext)
                }
            }
        }
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var typeChips: some View {
        HStack(spacing: 8) {
            ForEach(ExerciseLibraryTypeFilter.allCases) { filter in
                chip(title: filter.rawValue, isSelected: typeFilter == filter) {
                    typeFilter = filter
                    selectedBodyPart = nil
                    selectedDifficulty = nil
                }
            }
            Spacer()
        }
    }

    private var bodyPartChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "全部部位", isSelected: selectedBodyPart == nil) {
                    selectedBodyPart = nil
                }
                ForEach(ExerciseLibraryConstants.bodyParts, id: \.self) { part in
                    chip(title: part, isSelected: selectedBodyPart == part) {
                        selectedBodyPart = part
                    }
                }
            }
        }
    }

    private var difficultyChips: some View {
        HStack(spacing: 8) {
            chip(title: "全部難度", isSelected: selectedDifficulty == nil) {
                selectedDifficulty = nil
            }
            ForEach(ExerciseLibraryConstants.difficulties, id: \.self) { level in
                chip(title: level, isSelected: selectedDifficulty == level) {
                    selectedDifficulty = level
                }
            }
            Spacer()
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? AppTheme.primary : AppTheme.primarySoft)
                .foregroundStyle(isSelected ? Color.white : AppTheme.text)
                .clipShape(Capsule())
        }
        .accessibilityIdentifier("exerciseLibrary.chip_\(title)")
    }

    private func errorCard(_ message: String) -> some View {
        CardView {
            VStack(spacing: 10) {
                Text("載入失敗")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                    .multilineTextAlignment(.center)
                Button("重試") { resetAndReload() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func resetAndReload() {
        Task { await loadPage(reset: true) }
    }

    @MainActor
    private func loadPage(reset: Bool) async {
        if isLoading { return }
        guard service.isConfigured else {
            errorMessage = "尚未設定 Supabase 連線(SUPABASE_URL / SUPABASE_ANON_KEY)"
            return
        }
        isLoading = true
        errorMessage = nil
        let targetPage = reset ? 0 : page + 1
        do {
            let fetched = try await service.fetchItems(
                typeFilter: typeFilter,
                bodyPartZh: typeFilter == .yoga ? nil : selectedBodyPart,
                difficultyZh: typeFilter == .yoga ? selectedDifficulty : nil,
                search: searchText,
                page: targetPage
            )
            if reset {
                items = fetched
            } else {
                items += fetched
            }
            page = targetPage
            canLoadMore = fetched.count == ExerciseLibraryConstants.pageSize
        } catch {
            if reset { items = [] }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ExerciseLibraryItemCard: View {
    let item: ExerciseLibraryItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.imageUrl ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: item.isYoga ? "figure.yoga" : "dumbbell")
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
                if let secondary = item.secondaryName {
                    Text(secondary)
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
