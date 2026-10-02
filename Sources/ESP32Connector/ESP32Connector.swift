import Foundation

public enum ESP32ConnectorError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The ESP32 URL is invalid."
        case .invalidResponse:
            return "The ESP32 returned an invalid response."
        case .httpError(let code):
            return "ESP32 returned HTTP status code \(code)."
        }
    }
}

public final class ESP32Connector {
    public let host: String

    public init(host: String) {
        self.host = host
    }

    public func get(_ path: String) async throws -> String {
        let cleanHost = host.hasSuffix("/") ? String(host.dropLast()) : host
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"

        guard let url = URL(string: "\(cleanHost)\(cleanPath)") else {
            throw ESP32ConnectorError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ESP32ConnectorError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ESP32ConnectorError.httpError(http.statusCode)
        }

        return String(decoding: data, as: UTF8.self)
    }

    public func status() async throws -> String {
        try await get("/status")
    }

    public func turnOn() async throws -> String {
        try await get("/on")
    }

    public func turnOff() async throws -> String {
        try await get("/off")
    }
}
