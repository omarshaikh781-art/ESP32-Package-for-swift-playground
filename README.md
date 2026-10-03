# Supabase Fixed Package — Unofficial

Version **1.0.0** — lightweight Supabase-compatible Swift package for Swift Playgrounds and SwiftUI apps.

## Package
- Swift tools: 5.9
- iOS: 16+
- No external Swift package dependencies
- Module: `SupabaseFixedPackageUnofficial`

## Add to Swift Playgrounds

Repository:

`https://github.com/omarshaikh781-art/ESP32-Package-for-swift-playground`

Use version **1.0.0**.

Then:

```swift
import SupabaseFixedPackageUnofficial
```

## Included in 1.0.0

### Realtime

Version 1.1.0 adds a lightweight WebSocket-based Supabase Realtime client for Postgres Changes. It supports INSERT, UPDATE, and DELETE subscriptions without external Swift dependencies.

Example:

```swift
let realtime = SupabaseFixedRealtime(
    projectURL: URL(string: "https://YOUR_PROJECT.supabase.co")!,
    apiKey: "YOUR_ANON_OR_PUBLISHABLE_KEY"
)

Task {
    do {
        try await realtime.subscribe(table: "your_table") { event in
            print(event.event)
            print(event.record)
        }
    } catch {
        print(error.localizedDescription)
    }
}
```

Enable Realtime for the table in your Supabase project and configure its Postgres replication/publication settings as required by Supabase.


- Generic HTTP requests
- PostgREST SELECT
- PostgREST INSERT
- Supabase Auth sign-in
- Supabase Auth sign-up

## Example

```swift
let supabase = SupabaseFixedClient(
    projectURL: URL(string: "https://YOUR_PROJECT.supabase.co")!,
    apiKey: "YOUR_ANON_OR_PUBLISHABLE_KEY"
)

Task {
    do {
        let data = try await supabase.select(table: "your_table")
        print(String(data: data, encoding: .utf8) ?? "")
    } catch {
        print(error.localizedDescription)
    }
}
```

This is an **unofficial** lightweight client and is not the official Supabase Swift SDK.

Never put a Supabase service-role key in an app or repository.
