import Foundation

struct SupabaseRESTClient {
    let baseURL: String
    let anonKey: String

    func select<Response: Decodable>(
        table: String,
        queryItems: [URLQueryItem],
        responseType: Response.Type
    ) async throws -> Response {
        try await requestWithoutBody(
            path: "/rest/v1/\(table)",
            method: "GET",
            queryItems: queryItems + [URLQueryItem(name: "select", value: "*")],
            responseType: responseType
        )
    }

    func insert<Payload: Encodable, Response: Decodable>(
        table: String,
        payload: Payload,
        responseType: Response.Type
    ) async throws -> Response {
        try await request(
            path: "/rest/v1/\(table)",
            method: "POST",
            queryItems: [],
            body: payload,
            responseType: responseType,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func upsert<Payload: Encodable, Response: Decodable>(
        table: String,
        payload: Payload,
        responseType: Response.Type
    ) async throws -> Response {
        try await request(
            path: "/rest/v1/\(table)",
            method: "POST",
            queryItems: [],
            body: payload,
            responseType: responseType,
            extraHeaders: [
                "Prefer": "resolution=merge-duplicates,return=representation",
                "Content-Type": "application/json"
            ]
        )
    }

    func invokeFunction<Payload: Encodable, Response: Decodable>(
        named functionName: String,
        payload: Payload,
        responseType: Response.Type
    ) async throws -> Response {
        try await request(
            path: "/functions/v1/\(functionName)",
            method: "POST",
            queryItems: [],
            body: payload,
            responseType: responseType,
            // AI 建議等 LLM function 常需 15~30 秒以上，沿用預設 20 秒會頻繁逾時
            timeout: 90
        )
    }

    func delete(table: String, queryItems: [URLQueryItem]) async throws {
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        components.path = "/rest/v1/\(table)"
        components.queryItems = queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 20
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseRESTError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw mappedError(from: data, statusCode: httpResponse.statusCode)
        }
    }

    private func requestWithoutBody<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        responseType: Response.Type,
        extraHeaders: [String: String] = [:]
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
        request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        extraHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseRESTError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw mappedError(from: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(responseType, from: data)
    }

    private func request<Payload: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Payload?,
        responseType: Response.Type,
        extraHeaders: [String: String] = [:],
        timeout: TimeInterval = 20
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
        request.timeoutInterval = timeout
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        extraHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseRESTError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw mappedError(from: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(responseType, from: data)
    }

    private var authorizationToken: String {
        SupabaseSessionStore.currentSession()?.accessToken ?? anonKey
    }

    private func mappedError(from data: Data, statusCode: Int) -> Error {
        if statusCode == 401 {
            return SupabaseRESTError.unauthorized
        }

        // Edge Functions (e.g. ai-advice) return {"error": "..."}, while
        // PostgREST table errors return {"message": "...", "hint": "..."} -
        // check all of them before falling back to a generic status code, so
        // e.g. "No AI provider configured" actually reaches the user instead
        // of a bare NSURLError.
        if let error = try? JSONDecoder().decode(SupabaseRESTErrorResponse.self, from: data) {
            let resolved = error.message ?? error.error ?? error.hint
            if let resolved, !resolved.isEmpty {
                return SupabaseRESTError.serverMessage(resolved)
            }
        }

        let rawBody = String(data: data, encoding: .utf8) ?? ""
        return SupabaseRESTError.unexpectedStatus(statusCode, rawBody)
    }
}
