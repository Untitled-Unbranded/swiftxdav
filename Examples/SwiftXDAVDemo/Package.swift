// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftXDAVDemo",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "SwiftXDAVDemo", targets: ["SwiftXDAVDemo"])
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "SwiftXDAVDemo",
            dependencies: [
                .product(name: "SwiftXDAV", package: "swiftxdav")
            ],
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
