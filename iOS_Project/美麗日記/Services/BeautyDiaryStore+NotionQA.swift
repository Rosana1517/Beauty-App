import Foundation

extension BeautyDiaryStore {
    /// 帶給後端的對話輪數上限。伺服器端無狀態，記憶完全由這裡供給。
    static let notionQAHistoryTurnLimit = 6

    /// 送出問題給 notion-qa Edge Function（內部會查 Notion 知識庫再請 LLM 作答），
    /// 回覆可能包含文字與圖片。對話存進 state 跟著 save() 落地，跨 App 重啟延續。
    func askNotionQA(_ message: String) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard authSession != nil else {
            notionQAError = "請先登入雲端同步帳號，才能使用知識庫問答功能。"
            return
        }

        // 伺服器端不存對話記憶，改由這裡帶上最近幾輪（要在把本次提問 append 進去之前取，
        // 否則會把當前問題重複送一次）。
        let history = state.notionQAMessages.suffix(Self.notionQAHistoryTurnLimit).map {
            NotionQAHistoryTurn(role: $0.role == .user ? "user" : "assistant", text: $0.text)
        }

        state.notionQAMessages.append(NotionQAChatMessage(role: .user, text: trimmed))
        save()
        isLoadingNotionQA = true
        notionQAError = nil

        do {
            let result = try await cloudSyncService.requestNotionQA(
                message: trimmed,
                sessionId: notionQASessionID,
                history: history
            )
            state.notionQAMessages.append(NotionQAChatMessage(
                role: .assistant,
                text: result.text,
                images: result.images,
                sourceUrl: result.sourceUrl
            ))
            save()
        } catch {
            notionQAError = error.localizedDescription
        }

        isLoadingNotionQA = false
    }

    func clearNotionQAConversation() {
        state.notionQAMessages.removeAll()
        save()
        notionQAError = nil
        notionQASessionID = KeychainStore.resetNotionQASessionID()
    }
}
