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

struct SupabaseEmailAuthService: SupabaseAuthServiceProtocol {
    private let baseURL: String
    private let anonKey: String
    private let redirectURL: String

    init?(
        baseURL: String = AppRuntimeConfiguration.supabaseURL,
        anonKey: String = AppRuntimeConfiguration.supabaseAnonKey,
        redirectURL: String = AppRuntimeConfiguration.supabaseAuthRedirectURL
    ) {
        guard !baseURL.isEmpty, !anonKey.isEmpty else {
            return nil
        }
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.redirectURL = redirectURL
    }

    func currentSession() -> SupabaseAuthSession? {
        SupabaseSessionStore.currentSession()
    }

    func restoreSession() async -> SupabaseAuthSession? {
        guard let session = SupabaseSessionStore.currentSession() else {
            return nil
        }

        if !session.isExpired {
            return session
        }

        do {
            let refreshed = try await refreshSession(refreshToken: session.refreshToken)
            SupabaseSessionStore.save(refreshed)
            return refreshed
        } catch {
            SupabaseSessionStore.clear()
            return nil
        }
    }

    /// Creates a brand-new Supabase Auth user. Returns the session directly
    /// when the project has "auto confirm" enabled; returns nil when email
    /// confirmation is required first (the account exists, but there's no
    /// session yet until the user clicks the confirmation link).
    func signUp(email: String, password: String) async throws -> SupabaseAuthSession? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            throw SupabaseAuthError.invalidCredentials
        }

        let signUpEncoder = JSONEncoder()
        signUpEncoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try signUpEncoder.encode(PasswordSignInRequest(email: trimmedEmail, password: trimmedPassword))

        let data = try await performRawRequest(
            path: "/auth/v1/signup",
            method: "POST",
            queryItems: [],
            bodyData: bodyData,
            authorized: false
        )

        guard let response = try? JSONDecoder.supabaseDecoder.decode(SupabaseTokenResponse.self, from: data) else {
            return nil
        }

        let session = response.session
        SupabaseSessionStore.save(session)
        return session
    }

    func signIn(email: String, password: String) async throws -> SupabaseAuthSession {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            throw SupabaseAuthError.invalidCredentials
        }

        let response: SupabaseTokenResponse = try await request(
            path: "/auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: PasswordSignInRequest(email: trimmedEmail, password: trimmedPassword),
            authorized: false,
            responseType: SupabaseTokenResponse.self
        )
        let session = response.session

        SupabaseSessionStore.save(session)
        return session
    }

    func requestMagicLink(email: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw SupabaseAuthError.invalidCredentials
        }

        let payload = MagicLinkRequest(
            email: trimmedEmail,
            createUser: true,
            emailRedirectTo: redirectURL.isEmpty ? nil : redirectURL
        )

        let _: EmptySupabaseResponse = try await request(
            path: "/auth/v1/otp",
            method: "POST",
            queryItems: [],
            body: payload,
            authorized: false,
            responseType: EmptySupabaseResponse.self
        )
    }

    func completeMagicLinkSignIn(from url: URL) async throws -> SupabaseAuthSession {
        let parameters = callbackParameters(from: url)

        if let errorDescription = parameters["error_description"], !errorDescription.isEmpty {
            throw SupabaseAuthError.serverMessage(errorDescription)
        }

        if let errorCode = parameters["error_code"], !errorCode.isEmpty {
            throw SupabaseAuthError.serverMessage(errorCode)
        }

        if let accessToken = parameters["access_token"],
           let refreshToken = parameters["refresh_token"] {
            let session = try await makeSessionFromCallback(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: parameters["token_type"] ?? "bearer",
                expiresAt: parameters["expires_at"],
                expiresIn: parameters["expires_in"]
            )
            SupabaseSessionStore.save(session)
            return session
        }

        if let tokenHash = parameters["token_hash"], !tokenHash.isEmpty {
            let type = parameters["type"] ?? "email"
            let response: SupabaseTokenResponse = try await request(
                path: "/auth/v1/verify",
                method: "POST",
                queryItems: [],
                body: VerifyTokenHashRequest(type: type, tokenHash: tokenHash),
                authorized: false,
                responseType: SupabaseTokenResponse.self
            )
            let session = response.session
            SupabaseSessionStore.save(session)
            return session
        }

        throw SupabaseAuthError.invalidResponse
    }

    func signOut() async throws {
        guard let session = SupabaseSessionStore.currentSession() else {
            SupabaseSessionStore.clear()
            return
        }

        do {
            let _: EmptySupabaseResponse = try await request(
                path: "/auth/v1/logout",
                method: "POST",
                queryItems: [],
                authorized: true,
                accessTokenOverride: session.accessToken,
                responseType: EmptySupabaseResponse.self
            )
        } catch {
            SupabaseSessionStore.clear()
            throw error
        }

        SupabaseSessionStore.clear()
    }

    private func refreshSession(refreshToken: String) async throws -> SupabaseAuthSession {
        let response: SupabaseTokenResponse = try await request(
            path: "/auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: RefreshTokenRequest(refreshToken: refreshToken),
            authorized: false,
            responseType: SupabaseTokenResponse.self
        )
        return response.session
    }

    private func makeSessionFromCallback(
        accessToken: String,
        refreshToken: String,
        tokenType: String,
        expiresAt: String?,
        expiresIn: String?
    ) async throws -> SupabaseAuthSession {
        let resolvedExpiry = resolveExpiry(expiresAt: expiresAt, expiresIn: expiresIn)
        let user = try await fetchCurrentUser(accessToken: accessToken)
        return SupabaseAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresAt: resolvedExpiry,
            userID: user.id,
            email: user.email ?? ""
        )
    }

    private func resolveExpiry(expiresAt: String?, expiresIn: String?) -> Date? {
        if let expiresAt,
           let timestamp = Double(expiresAt) {
            return Date(timeIntervalSince1970: timestamp)
        }

        if let expiresIn,
           let interval = Double(expiresIn) {
            return Date().addingTimeInterval(interval)
        }

        return nil
    }

    private func fetchCurrentUser(accessToken: String) async throws -> SupabaseAuthUser {
        try await request(
            path: "/auth/v1/user",
            method: "GET",
            queryItems: [],
            authorized: true,
            accessTokenOverride: accessToken,
            responseType: SupabaseAuthUser.self
        )
    }

    private func callbackParameters(from url: URL) -> [String: String] {
        var values: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems?.forEach { item in
                guard let value = item.value else { return }
                values[item.name] = value
            }

            if let fragment = components.fragment,
               let fragmentItems = URLComponents(string: "https://callback.local?\(fragment)")?.queryItems {
                fragmentItems.forEach { item in
                    guard let value = item.value else { return }
                    values[item.name] = value
                }
            }
        }

        return values
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        authorized: Bool,
        accessTokenOverride: String? = nil,
        responseType: Response.Type
    ) async throws -> Response {
        try await performRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            bodyData: nil,
            authorized: authorized,
            accessTokenOverride: accessTokenOverride,
            responseType: responseType
        )
    }

    private func request<Payload: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Payload,
        authorized: Bool,
        accessTokenOverride: String? = nil,
        responseType: Response.Type
    ) async throws -> Response {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(body)

        return try await performRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            bodyData: bodyData,
            authorized: authorized,
            accessTokenOverride: accessTokenOverride,
            responseType: responseType
        )
    }

    private func performRequest<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        bodyData: Data?,
        authorized: Bool,
        accessTokenOverride: String? = nil,
        responseType: Response.Type
    ) async throws -> Response {
        let data = try await performRawRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            bodyData: bodyData,
            authorized: authorized,
            accessTokenOverride: accessTokenOverride
        )

        if Response.self == EmptySupabaseResponse.self, data.isEmpty {
            return EmptySupabaseResponse() as! Response
        }

        return try JSONDecoder.supabaseDecoder.decode(responseType, from: data.isEmpty ? Data("{}".utf8) : data)
    }

    private func performRawRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        bodyData: Data?,
        authorized: Bool,
        accessTokenOverride: String? = nil
    ) async throws -> Data {
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authorized {
            let accessToken = accessTokenOverride ?? SupabaseSessionStore.currentSession()?.accessToken ?? ""
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        if let bodyData {
            request.httpBody = bodyData
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // GoTrue's error body shape varies by version/endpoint ("message",
            // "msg", or "error_description"/"error") - try all of them before
            // falling back to a generic message, so real causes (wrong
            // password, email provider disabled, signups disabled, etc.)
            // actually surface to the user instead of a bare NSURLError.
            if let resolvedMessage = decodeSupabaseErrorMessage(from: data) {
                throw SupabaseAuthError.serverMessage(resolvedMessage)
            }

            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                throw SupabaseAuthError.invalidCredentials
            }

            let rawBody = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseAuthError.unexpectedStatus(httpResponse.statusCode, rawBody)
        }

        return data
    }
}

private extension JSONDecoder {
    static var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct PasswordSignInRequest: Encodable {
    let email: String
    let password: String
}

private struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

private struct MagicLinkRequest: Encodable {
    let email: String
    let createUser: Bool
    let emailRedirectTo: String?
}

private struct VerifyTokenHashRequest: Encodable {
    let type: String
    let tokenHash: String
}

private struct SupabaseTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresAt: Date?
    let expiresIn: Double?
    let user: SupabaseAuthUser

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case tokenType
        case expiresAt
        case expiresIn
        case user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        expiresIn = try container.decodeIfPresent(Double.self, forKey: .expiresIn)
        user = try container.decode(SupabaseAuthUser.self, forKey: .user)

        if let timestamp = try container.decodeIfPresent(Double.self, forKey: .expiresAt) {
            expiresAt = Date(timeIntervalSince1970: timestamp)
        } else if let isoString = try container.decodeIfPresent(String.self, forKey: .expiresAt) {
            expiresAt = ISO8601DateFormatter().date(from: isoString)
        } else {
            expiresAt = nil
        }
    }

    var session: SupabaseAuthSession {
        let resolvedExpiry: Date?
        if let expiresAt {
            resolvedExpiry = expiresAt
        } else if let expiresIn {
            resolvedExpiry = Date().addingTimeInterval(expiresIn)
        } else {
            resolvedExpiry = nil
        }

        return SupabaseAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresAt: resolvedExpiry,
            userID: user.id,
            email: user.email ?? ""
        )
    }
}

private struct SupabaseAuthUser: Decodable {
    let id: String
    let email: String?
}

private struct SupabaseErrorResponse: Decodable {
    let message: String?
    let msg: String?
    let error: String?
    let errorDescription: String?

    private enum CodingKeys: String, CodingKey {
        case message
        case msg
        case error
        case errorDescription = "error_description"
    }
}

private func decodeSupabaseErrorMessage(from data: Data) -> String? {
    guard let parsed = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) else {
        return nil
    }

    let candidate = parsed.errorDescription ?? parsed.message ?? parsed.msg ?? parsed.error
    guard let candidate, !candidate.isEmpty else { return nil }
    return candidate
}

private struct EmptySupabaseResponse: Decodable {}
