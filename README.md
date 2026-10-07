# Supabase Fixed Package — Unofficial

Version **1.1.3** — lightweight Supabase-compatible Swift package for Swift Playgrounds and SwiftUI apps.

## Package
- Swift tools: 5.9
- iOS: 16+
- No external Swift package dependencies
- Module: `SupabaseFixedPackageUnofficial`

## Add to Swift Playgrounds

Repository:

`https://github.com/omarshaikh781-art/ESP32-Package-for-swift-playground`

Use version **1.1.1**.

Then:

```swift
import SupabaseFixedPackageUnofficial
```

## Included

### Auth
- Email/password sign-up
- Email/password sign-in

### PostgREST
- Generic HTTP requests
- SELECT
- INSERT

### Realtime
- WebSocket connection to Supabase Realtime
- Postgres Changes
- INSERT, UPDATE, DELETE, or all events
- Heartbeats
- Clean disconnect / channel leave
- No external dependencies

Example:

```swift
let realtime = SupabaseFixedRealtime(
    projectURL: URL(string: "https://YOUR_PROJECT.supabase.co")!,
    apiKey: "YOUR_ANON_OR_PUBLISHABLE_KEY"
)

Task {
    do {
        try await realtime.subscribe(table: "sensor_readings") { event in
            print(event.event)
            print(event.record)
        }
    } catch {
        print(error.localizedDescription)
    }
}
```

Enable Realtime/Postgres Changes for the table in your Supabase project.

## Basic REST example

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
