import Foundation

/// A lightweight, unofficial Supabase-compatible REST/Auth client.
///
/// This package intentionally avoids the large official Supabase dependency
/// graph so it can be used more easily in Swift Playgrounds.
public final class SupabaseFixedClient: @unchecked Sendable {
    public let projectURL: URL
    public let apiKey: String

    private let session: URLSession
    private var accessToken: String?

    public init(projectURL: URL, apiKey: String, session: URLSession = .shared) {
        self.projectURL = projectURL
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Session

    /// Stores the Supabase user's access token for authenticated requests.
    public func setAccessToken(_ token: String?) {
        accessToken = token
    }

    /// Clears the current user's access token.
    public func clearAccessToken() {
        accessToken = nil
    }

    /// True when this client has a Supabase access token.
    public var isAuthenticated: Bool {
        accessToken != nil
    }

    // MARK: - Request

    private func makeRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        extraHeaders: [String: String] = [:]
    ) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: projectURL)?.absoluteURL else {
            throw SupabaseFixedError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken {
            request.setValue(
                "Bearer \(accessToken)",
                forHTTPHeaderField: "Authorization"
            )
        }

        if body != nil {
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
        }

        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    /// Performs an authenticated or unauthenticated Supabase request.
    public func request(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> Data {
        let request = try makeRequest(
            path: path,
            method: method,
            body: body,
            extraHeaders: headers
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SupabaseFixedError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw SupabaseFixedError.httpError(
                statusCode: http.statusCode,
                message: String(
                    data: data,
                    encoding: .utf8
                ) ?? "Unknown server error"
            )
        }

        return data
    }

    // MARK: - Database

    /// Fetches rows from a PostgREST table.
    public func select(
        table: String,
        query: String = "*"
    ) async throws -> Data {
        let encodedTable =
            table.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) ?? table

        let encodedQuery =
            query.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) ?? query

        return try await request(
            path: "/rest/v1/\(encodedTable)?select=\(encodedQuery)"
        )
    }

    /// Inserts a JSON object into a PostgREST table.
    public func insert(
        table: String,
        jsonObject: [String: Any]
    ) async throws -> Data {
        let data = try JSONSerialization.data(
            withJSONObject: jsonObject
        )

        return try await request(
            path: "/rest/v1/\(table)",
            method: "POST",
            body: data,
            headers: [
                "Prefer": "return=representation"
            ]
        )
    }

    // MARK: - Auth

    /// Signs in with email and password.
    ///
    /// When Supabase returns an access_token, this client stores it
    /// automatically for later authenticated database requests.
    public func signIn(
        email: String,
        password: String
    ) async throws -> Data {
        let body = try JSONSerialization.data(
            withJSONObject: [
                "email": email,
                "password": password
            ]
        )

        let response = try await request(
            path: "/auth/v1/token?grant_type=password",
            method: "POST",
            body: body
        )

        storeAccessToken(from: response)

        return response
    }

    /// Creates a new Supabase Auth account.
    ///
    /// If the project immediately returns an access_token,
    /// this client stores it automatically.
    public func signUp(
        email: String,
        password: String
    ) async throws -> Data {
        let body = try JSONSerialization.data(
            withJSONObject: [
                "email": email,
                "password": password
            ]
        )

        let response = try await request(
            path: "/auth/v1/signup",
            method: "POST",
            body: body
        )

        storeAccessToken(from: response)

        return response
    }

    private func storeAccessToken(from data: Data) {
        guard
            let json = try? JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any],
            let token = json["access_token"] as? String,
            !token.isEmpty
        else {
            return
        }

        accessToken = token
    }
}

public enum SupabaseFixedError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The Supabase URL is invalid."

        case .invalidResponse:
            return "The server returned an invalid response."

        case let .httpError(statusCode, message):
            return "Supabase HTTP \(statusCode): \(message)"
        }
    }
}
