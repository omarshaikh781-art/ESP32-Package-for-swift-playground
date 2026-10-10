// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "SupabaseFixedPackageUnofficial",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "SupabaseFixedPackageUnofficial",
            targets: ["SupabaseFixedPackageUnofficial"]
        )
    ],
    targets: [
        .target(
            name: "SupabaseFixedPackageUnofficial",
            path: "Sources/SupabaseFixedPackageUnofficial"
        )
    ]
)
