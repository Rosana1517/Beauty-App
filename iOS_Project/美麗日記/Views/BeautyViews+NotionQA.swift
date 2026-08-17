import SwiftUI

struct NotionQAView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            titleRow(title: "美妝知識問答", action: store.state.notionQAMessages.isEmpty ? nil : "清空") {
                store.clearNotionQAConversation()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if store.state.notionQAMessages.isEmpty {
                            EmptyStateView(
                                title: "問我小紅書變美筆記知識庫",
                                subtitle: "例如:「法令紋怎麼改善」「有推薦的緊緻按摩手法嗎」"
                            )
                            .padding(.top, 40)
                        }

                        ForEach(store.state.notionQAMessages) { message in
                            NotionQAMessageBubble(message: message)
                                .id(message.id)
                        }

                        if store.isLoadingNotionQA {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("正在查詢知識庫…")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            .padding(12)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if let notionQAError = store.notionQAError {
                            Text(notionQAError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: store.state.notionQAMessages) { messages in
                    guard let lastID = messages.last?.id else { return }
                    withAnimation {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }

            inputBar
        }
        .background(AppTheme.background)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            ThemedTextField(title: "輸入你的美妝問題…", text: $draft)
                .focused($inputFocused)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(canSend ? AppTheme.primary : AppTheme.subtext)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.card)
        .shadow(color: AppTheme.shadow, radius: 12, y: -4)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isLoadingNotionQA
    }

    private func send() {
        guard canSend else { return }
        let message = draft
        draft = ""
        Task { await store.askNotionQA(message) }
    }
}

private struct NotionQAMessageBubble: View {
    let message: NotionQAChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 10) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? .white : AppTheme.text)

                if !message.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(message.images, id: \.self) { imageURL in
                                AsyncImage(url: URL(string: imageURL)) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFill()
                                    } else {
                                        AppTheme.primarySoft
                                    }
                                }
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }

                if !message.sourceUrl.isEmpty, let url = URL(string: message.sourceUrl) {
                    Link("查看原始筆記", destination: url)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(message.role == .user ? .white.opacity(0.85) : AppTheme.primary)
                }
            }
            .padding(12)
            .background(message.role == .user ? AppTheme.primary : AppTheme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}
