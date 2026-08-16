import Foundation

/// 一則 Notion 知識庫問答的聊天訊息，包含 AI 回覆時可能附帶的圖片與參考來源。
struct NotionQAChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
    var images: [String] = []
    var sourceUrl: String = ""
}

extension BeautyDiaryStore {
    /// 送出問題給自架 n8n 的 Notion 知識庫問答 workflow，回覆可能包含文字與圖片。
    func askNotionQA(_ message: String) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard authSession != nil else {
            notionQAError = "請先登入雲端同步帳號，才能使用知識庫問答功能。"
            return
        }

        notionQAMessages.append(NotionQAChatMessage(role: .user, text: trimmed))
        isLoadingNotionQA = true
        notionQAError = nil

        do {
            let result = try await cloudSyncService.requestNotionQA(message: trimmed, sessionId: notionQASessionID)
            notionQAMessages.append(NotionQAChatMessage(
                role: .assistant,
                text: result.text,
                images: result.images,
                sourceUrl: result.sourceUrl
            ))
        } catch {
            notionQAError = error.localizedDescription
        }

        isLoadingNotionQA = false
    }

    func clearNotionQAConversation() {
        notionQAMessages.removeAll()
        notionQAError = nil
        notionQASessionID = KeychainStore.resetNotionQASessionID()
    }
}
