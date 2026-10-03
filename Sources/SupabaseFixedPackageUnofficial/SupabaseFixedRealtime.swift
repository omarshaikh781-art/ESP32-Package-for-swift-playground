import Foundation

/// A lightweight Supabase Realtime client using Apple's URLSessionWebSocketTask.
///
/// This implementation supports Postgres Changes subscriptions for INSERT,
/// UPDATE, and DELETE events without adding external Swift dependencies.
public final class SupabaseFixedRealtime: @unchecked Sendable {
    public let projectURL: URL
    public let apiKey: String

    private let session: URLSession
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var callback: (@Sendable (SupabaseRealtimeEvent) -> Void)?
    private var channelTopic: String?
    private var joinRef: String?

    public init(
        projectURL: URL,
        apiKey: String,
        session: URLSession = .shared
    ) {
        self.projectURL = projectURL
        self.apiKey = apiKey
        self.session = session
    }

    /// Connects to Supabase Realtime and subscribes to Postgres changes.
    ///
    /// - Parameters:
    ///   - schema: Usually "public".
    ///   - table: The table to watch.
    ///   - events: Events to receive. Use ["*"] for INSERT, UPDATE and DELETE.
    ///   - onEvent: Called whenever a matching database change arrives.
    public func subscribe(
        schema: String = "public",
        table: String,
        events: [String] = ["*"],
        onEvent: @escaping @Sendable (SupabaseRealtimeEvent) -> Void
    ) async throws {
        disconnect()

        guard let socketURL = makeSocketURL() else {
            throw SupabaseRealtimeError.invalidURL
        }

        callback = onEvent
        channelTopic = "realtime:\(schema):\(table)"
        joinRef = UUID().uuidString

        let task = session.webSocketTask(with: socketURL)
        socket = task
        task.resume()

        let ref = joinRef ?? UUID().uuidString
        let joinPayload: [String: Any] = [
            "config": [
                "broadcast": ["self": false],
                "presence": ["key": ""],
                "postgres_changes": events.map { event in
                    [
                        "event": event,
                        "schema": schema,
                        "table": table
                    ]
                }
            ],
            "access_token": apiKey
        ]

        try await send(
            topic: channelTopic ?? "realtime:\(schema):\(table)",
            event: "phx_join",
            payload: joinPayload,
            ref: ref
        )

        startReceiveLoop()
        startHeartbeat()
    }

    /// Stops the active Realtime subscription.
    public func disconnect() {
        receiveTask?.cancel()
        heartbeatTask?.cancel()
        receiveTask = nil
        heartbeatTask = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        callback = nil
        channelTopic = nil
        joinRef = nil
    }

    deinit {
        disconnect()
    }

    private func makeSocketURL() -> URL? {
        var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false)

        guard var scheme = components?.scheme else {
            return nil
        }

        scheme = scheme == "https" ? "wss" : (scheme == "http" ? "ws" : scheme)
        components?.scheme = scheme
        components?.path = "/realtime/v1/websocket"

        components?.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "vsn", value: "1.0.0")
        ]

        return components?.url
    }

    private func send(
        topic: String,
        event: String,
        payload: [String: Any],
        ref: String
    ) async throws {
        guard let socket else {
            throw SupabaseRealtimeError.notConnected
        }

        let message: [String: Any] = [
            "topic": topic,
            "event": event,
            "payload": payload,
            "ref": ref
        ]

        let data = try JSONSerialization.data(withJSONObject: message)
        try await socket.send(.data(data))
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()

        receiveTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    guard let socket = self.socket else { return }

                    let message = try await socket.receive()

                    switch message {
                    case .data(let data):
                        self.handle(data: data)
                    case .string(let string):
                        guard let data = string.data(using: .utf8) else { continue }
                        self.handle(data: data)
                    @unknown default:
                        break
                    }
                } catch {
                    return
                }
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()

        heartbeatTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                if Task.isCancelled { return }

                do {
                    try await self.send(
                        topic: "phoenix",
                        event: "heartbeat",
                        payload: [:],
                        ref: UUID().uuidString
                    )
                } catch {
                    return
                }
            }
        }
    }

    private func handle(data: Data) {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let event = root["event"] as? String
        else {
            return
        }

        if event == "postgres_changes" {
            let payload = root["payload"] as? [String: Any] ?? [:]
            let dataPayload = payload["data"] as? [String: Any] ?? [:]

            let changeEvent =
                (dataPayload["type"] as? String)
                ?? (dataPayload["event"] as? String)
                ?? "UNKNOWN"

            let record = dataPayload["record"] as? [String: Any] ?? [:]
            let oldRecord = dataPayload["old_record"] as? [String: Any] ?? [:]

            let realtimeEvent = SupabaseRealtimeEvent(
                event: changeEvent,
                record: record,
                oldRecord: oldRecord,
                rawPayload: payload
            )

            callback?(realtimeEvent)
        }
    }
}

/// A database change received from Supabase Realtime.
public struct SupabaseRealtimeEvent: Sendable {
    public let event: String
    public let record: [String: Any]
    public let oldRecord: [String: Any]
    public let rawPayload: [String: Any]

    public init(
        event: String,
        record: [String: Any],
        oldRecord: [String: Any],
        rawPayload: [String: Any]
    ) {
        self.event = event
        self.record = record
        self.oldRecord = oldRecord
        self.rawPayload = rawPayload
    }
}

public enum SupabaseRealtimeError: Error, LocalizedError, Sendable {
    case invalidURL
    case notConnected

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The Supabase Realtime URL is invalid."
        case .notConnected:
            return "The Supabase Realtime socket is not connected."
        }
    }
}
