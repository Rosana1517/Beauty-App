import Foundation

extension SupabaseEmailAuthService {
    func request<Response: Decodable>(
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

    func request<Payload: Encodable, Response: Decodable>(
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

    func performRequest<Response: Decodable>(
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

        if data.isEmpty, let empty = EmptySupabaseResponse() as? Response {
            return empty
        }

        return try JSONDecoder.supabaseDecoder.decode(responseType, from: data.isEmpty ? Data("{}".utf8) : data)
    }

    func performRawRequest(
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

extension JSONDecoder {
    static var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct PasswordSignInRequest: Encodable {
    let email: String
    let password: String
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

struct MagicLinkRequest: Encodable {
    let email: String
    let createUser: Bool
    let emailRedirectTo: String?
}

struct VerifyTokenHashRequest: Encodable {
    let type: String
    let tokenHash: String
}

struct SupabaseTokenResponse: Decodable {
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

struct SupabaseAuthUser: Decodable {
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

struct EmptySupabaseResponse: Decodable {}
