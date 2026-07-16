import Foundation

struct SupabaseEmailAuthService: SupabaseAuthServiceProtocol {
    let baseURL: String
    let anonKey: String
    let redirectURL: String

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

    func refreshSession(refreshToken: String) async throws -> SupabaseAuthSession {
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

    func makeSessionFromCallback(
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

    func resolveExpiry(expiresAt: String?, expiresIn: String?) -> Date? {
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

    func fetchCurrentUser(accessToken: String) async throws -> SupabaseAuthUser {
        try await request(
            path: "/auth/v1/user",
            method: "GET",
            queryItems: [],
            authorized: true,
            accessTokenOverride: accessToken,
            responseType: SupabaseAuthUser.self
        )
    }

    func callbackParameters(from url: URL) -> [String: String] {
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

}
