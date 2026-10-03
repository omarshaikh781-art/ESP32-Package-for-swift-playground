// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SupabaseFixedPackageUnofficial",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
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
