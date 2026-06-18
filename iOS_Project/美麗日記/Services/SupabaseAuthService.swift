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

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Supabase auth is not configured."
        case .invalidCredentials:
            return "The email or password is incorrect."
        case .invalidResponse:
            return "Supabase returned an invalid auth response."
        case .missingSession:
            return "No active session is available."
        case .serverMessage(let message):
            return message
        }
    }
}

protocol SupabaseAuthServiceProtocol {
    func restoreSession() async -> SupabaseAuthSession?
    func currentSession() -> SupabaseAuthSession?
    func signIn(email: String, password: String) async throws -> SupabaseAuthSession
    func requestMagicLink(email: String) async throws
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
    func signIn(email: String, password: String) async throws -> SupabaseAuthSession { throw SupabaseAuthError.unavailable }
    func requestMagicLink(email: String) async throws { throw SupabaseAuthError.unavailable }
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
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                if let authError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data),
                   !authError.message.isEmpty {
                    throw SupabaseAuthError.serverMessage(authError.message)
                }
                throw SupabaseAuthError.invalidCredentials
            }

            if let authError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data),
               !authError.message.isEmpty {
                throw SupabaseAuthError.serverMessage(authError.message)
            }

            throw URLError(.badServerResponse)
        }

        if Response.self == EmptySupabaseResponse.self, data.isEmpty {
            return EmptySupabaseResponse() as! Response
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(responseType, from: data.isEmpty ? Data("{}".utf8) : data)
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
    let message: String
}

private struct EmptySupabaseResponse: Decodable {}
