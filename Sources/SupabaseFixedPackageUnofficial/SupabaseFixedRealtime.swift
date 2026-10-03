import Foundation

/// Lightweight Supabase Realtime client for Postgres Changes.
///
/// Uses Supabase Realtime protocol 1.0.0 and Apple's URLSessionWebSocketTask.
/// No external Swift package dependencies are required.
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

    /// Subscribes to INSERT, UPDATE, DELETE, or all Postgres changes.
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

        let topic = "realtime:(table)"
        let ref = UUID().uuidString

        callback = onEvent
        channelTopic = topic
        joinRef = ref

        let task = session.webSocketTask(with: socketURL)
        socket = task
        task.resume()

        // Start receiving BEFORE phx_join so the join reply cannot be missed.
        startReceiveLoop()
        startHeartbeat()

        let postgresChanges: [[String: Any]] = events.map {
            [
                "event": $0,
                "schema": schema,
                "table": table
            ]
        }

        let joinPayload: [String: Any] = [
            "config": [
                "broadcast": [
                    "ack": false,
                    "self": false
                ],
                "presence": [
                    "enabled": false,
                    "key": ""
                ],
                "postgres_changes": postgresChanges,
                "private": false
            ],
            "access_token": apiKey
        ]

        try await send(
            topic: topic,
            event: "phx_join",
            payload: joinPayload,
            ref: ref,
            joinRef: ref
        )
    }

    /// Stops the active subscription and closes the socket.
    public func disconnect() {
        receiveTask?.cancel()
        heartbeatTask?.cancel()
        receiveTask = nil
        heartbeatTask = nil

        if let socket, let topic = channelTopic, let ref = joinRef {
            let leave: [String: Any] = [
                "topic": topic,
                "event": "phx_leave",
                "payload": [:],
                "ref": UUID().uuidString,
                "join_ref": ref
            ]

            if let data = try? JSONSerialization.data(withJSONObject: leave),
               let text = String(data: data, encoding: .utf8) {
                socket.send(.string(text)) { _ in }
            }
        }

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

        guard let scheme = components?.scheme else {
            return nil
        }

        components?.scheme =
            scheme == "https" ? "wss" :
            scheme == "http" ? "ws" : scheme

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
        ref: String,
        joinRef: String?
    ) async throws {
        guard let socket else {
            throw SupabaseRealtimeError.notConnected
        }

        var message: [String: Any] = [
            "topic": topic,
            "event": event,
            "payload": payload,
            "ref": ref
        ]

        if let joinRef {
            message["join_ref"] = joinRef
        }

        let data = try JSONSerialization.data(withJSONObject: message)

        guard let text = String(data: data, encoding: .utf8) else {
            throw SupabaseRealtimeError.invalidMessage
        }

        try await socket.send(.string(text))
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()

        receiveTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    guard let socket = self.socket else { return }

                    switch try await socket.receive() {
                    case .data(let data):
                        handle(data: data)

                    case .string(let string):
                        guard let data = string.data(using: .utf8) else {
                            continue
                        }
                        handle(data: data)

                    @unknown default:
                        continue
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
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                if Task.isCancelled { return }

                do {
                    try await send(
                        topic: "phoenix",
                        event: "heartbeat",
                        payload: [:],
                        ref: UUID().uuidString,
                        joinRef: nil
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

        switch event {
        case "postgres_changes":
            let payload = root["payload"] as? [String: Any] ?? [:]
            let dataPayload = payload["data"] as? [String: Any] ?? [:]

            let changeEvent =
                (dataPayload["type"] as? String)
                ?? (dataPayload["event"] as? String)
                ?? "UNKNOWN"

            let record = dataPayload["record"] as? [String: Any] ?? [:]
            let oldRecord = dataPayload["old_record"] as? [String: Any] ?? [:]

            callback?(
                SupabaseRealtimeEvent(
                    event: changeEvent,
                    record: record,
                    oldRecord: oldRecord,
                    rawPayload: payload
                )
            )

        default:
            break
        }
    }
}

/// A database change received from Supabase Realtime.
public struct SupabaseRealtimeEvent: @unchecked Sendable {
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
    case invalidMessage
    case notConnected

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The Supabase Realtime URL is invalid."
        case .invalidMessage:
            return "The Realtime message could not be encoded."
        case .notConnected:
            return "The Supabase Realtime socket is not connected."
        }
    }
}
