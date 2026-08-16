import Foundation
import Security

/// 輕量 Keychain 存取，只處理字串值。比 UserDefaults 更適合放「不該被一般備份/還原
/// 隨意帶走、但也稱不上機密」的裝置專屬識別碼，例如聊天 sessionID。
enum KeychainStore {
    private static let service = "com.beautydiary.app"

    static func string(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    static func remove(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static let notionQASessionIDKey = "notion-qa-session-id"

    /// 讀取已存在的 Notion 問答 sessionID；沒有就產生一組新的並存回 Keychain，
    /// 讓對話上下文(n8n 的 Window Buffer Memory 依 sessionID 記憶)能跨 App 重啟延續。
    static func notionQASessionID() -> String {
        if let existing = string(forKey: notionQASessionIDKey) {
            return existing
        }
        let newID = UUID().uuidString
        set(newID, forKey: notionQASessionIDKey)
        return newID
    }

    /// 產生並儲存一組新的 sessionID，取代舊的。用於使用者主動「清空對話」時，
    /// 讓 n8n 那端的 Window Buffer Memory 也跟著開新的上下文，不會延續被清掉的舊對話。
    static func resetNotionQASessionID() -> String {
        let newID = UUID().uuidString
        set(newID, forKey: notionQASessionIDKey)
        return newID
    }
}
