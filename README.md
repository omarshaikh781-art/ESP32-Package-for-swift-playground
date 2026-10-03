# Supabase Fixed Package — Unofficial

A lightweight, unofficial Supabase-compatible Swift package designed for Swift Playgrounds and small SwiftUI apps.

## Why this exists

The official Supabase Swift package has a large dependency graph that can cause compatibility problems in some Swift Playgrounds projects.

This package uses Foundation and URLSession instead, keeping the dependency footprint small.

## Included

- PostgREST SELECT requests
- PostgREST INSERT requests
- Supabase Auth sign-in
- Supabase Auth sign-up
- Generic REST requests
- iOS 16+ and other modern Apple platforms

## Swift Playgrounds

Add this repository as a Swift package dependency:

```
https://github.com/omarshaikh781-art/ESP32-Package-for-swift-playground
```

Then import:

```swift
import SupabaseFixedPackageUnofficial
```

Example:

```swift
let supabase = SupabaseFixedClient(
    projectURL: URL(string: "https://YOUR_PROJECT.supabase.co")!,
    apiKey: "YOUR_ANON_KEY"
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

## Important

This is **unofficial** and is not the official Supabase Swift SDK. It intentionally provides a smaller REST/Auth layer rather than copying the official SDK.

Never put a Supabase service-role key in an app or repository. Use the publishable/anon key intended for client applications and configure Row Level Security correctly.

## Vortex-X

The package is intended to be usable as a lightweight backend layer for the Vortex-X Swift Playgrounds app without pulling in the full official Supabase dependency tree.
