// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ESP32Connector",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ESP32Connector",
            targets: ["ESP32Connector"]
        )
    ],
    targets: [
        .target(
            name: "ESP32Connector"
        )
    ]
)
