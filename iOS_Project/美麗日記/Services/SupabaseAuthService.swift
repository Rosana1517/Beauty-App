import Foundation

enum SupabaseAuthStatus: String {
    case unavailable
    case signedOut
    case restoring
    case authenticating
    case authenticated
}

struct SupabaseAuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresAt: Date?
    let userID: String
    let email: String

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date().addingTimeInterval(30)
    }
}

enum SupabaseAuthError: LocalizedError {
    case unavailable
    case invalidCredentials
    case invalidResponse
    case missingSession
    case serverMessage(String)
    case unexpectedStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "尚未設定 Supabase，無法登入。"
        case .invalidCredentials:
            return "帳號或密碼不正確。"
        case .invalidResponse:
            return "Supabase 回傳了無法解析的回應。"
        case .missingSession:
            return "沒有可用的登入狀態。"
        case .serverMessage(let message):
            return message
        case .unexpectedStatus(let code, let body):
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedBody.isEmpty
                ? "Supabase 回應了非預期的狀態碼 \(code)。"
                : "Supabase 回應了非預期的狀態碼 \(code)：\(trimmedBody)"
        }
    }
}

protocol SupabaseAuthServiceProtocol {
    func restoreSession() async -> SupabaseAuthSession?
    func currentSession() -> SupabaseAuthSession?
    func signUp(email: String, password: String) async throws -> SupabaseAuthSession?
    func signIn(email: String, password: String) async throws -> SupabaseAuthSession
    func requestMagicLink(email: String) async throws
    func completeMagicLinkSignIn(from url: URL) async throws -> SupabaseAuthSession
    func signOut() async throws
}

enum SupabaseSessionStore {
    private static let defaultsKey = "beautiful-diary.supabase-session"

    static func currentSession() -> SupabaseAuthSession? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SupabaseAuthSession.self, from: data)
    }

    static func save(_ session: SupabaseAuthSession) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(session) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

struct NoopSupabaseAuthService: SupabaseAuthServiceProtocol {
    func restoreSession() async -> SupabaseAuthSession? { nil }
    func currentSession() -> SupabaseAuthSession? { nil }
    func signUp(email: String, password: String) async throws -> SupabaseAuthSession? { throw SupabaseAuthError.unavailable }
    func signIn(email: String, password: String) async throws -> SupabaseAuthSession { throw SupabaseAuthError.unavailable }
    func requestMagicLink(email: String) async throws { throw SupabaseAuthError.unavailable }
    func completeMagicLinkSignIn(from url: URL) async throws -> SupabaseAuthSession { throw SupabaseAuthError.unavailable }
    func signOut() async throws {}
}

