import Foundation

extension BeautyDiaryStore {
    /// 送出問題給自架 n8n 的 Notion 知識庫問答 workflow，回覆可能包含文字與圖片。
    /// 對話會存進 state 跟著 save() 落地，與 Keychain 裡的 sessionID（n8n 端的對話記憶）
    /// 一起跨 App 重啟延續——兩層必須同時保留，否則畫面空白而 AI 仍在接續前文。
    func askNotionQA(_ message: String) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard authSession != nil else {
            notionQAError = "請先登入雲端同步帳號，才能使用知識庫問答功能。"
            return
        }

        state.notionQAMessages.append(NotionQAChatMessage(role: .user, text: trimmed))
        save()
        isLoadingNotionQA = true
        notionQAError = nil

        do {
            let result = try await cloudSyncService.requestNotionQA(message: trimmed, sessionId: notionQASessionID)
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
