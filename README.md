# ESP32 Connector for Swift Playgrounds

A small Swift package for connecting a Swift/SwiftUI app or Swift Playground to an ESP32 over a local Wi-Fi network.

## What it does

- Connects to an ESP32 using its local IP address
- Sends HTTP GET requests to ESP32 endpoints
- Provides simple async Swift functions
- Designed for projects such as Vortex-X

## ESP32 setup

Your ESP32 should run a web server with endpoints such as:

- `/status`
- `/on`
- `/off`

Example:

```
http://192.168.1.50/status
http://192.168.1.50/on
http://192.168.1.50/off
```

Replace the IP address with the address shown by your ESP32.

## Swift example

```swift
import ESP32Connector

let esp32 = ESP32Connector(host: "192.168.1.50")

Task {
    do {
        let response = try await esp32.get("/status")
        print(response)
    } catch {
        print(error.localizedDescription)
    }
}
```

## Vortex-X

This package can be used as the communication layer between a Swift Playground/SwiftUI interface and the ESP32 controlling the Vortex-X hardware.

> Never put Wi-Fi passwords, API keys, or other private credentials in this repository.

## License

For personal/educational use.
