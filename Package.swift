// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftXDAV",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SwiftXDAV", targets: ["SwiftXDAV"]),
        .library(name: "SwiftXDAVCore", targets: ["SwiftXDAVCore"]),
        .library(name: "SwiftXDAVNetwork", targets: ["SwiftXDAVNetwork"]),
        .library(name: "SwiftXDAVCalendar", targets: ["SwiftXDAVCalendar"]),
        .library(name: "SwiftXDAVContacts", targets: ["SwiftXDAVContacts"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
    ],
    targets: [
        // Core module
        .target(
            name: "SwiftXDAVCore",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Network module
        .target(
            name: "SwiftXDAVNetwork",
            dependencies: [
                "SwiftXDAVCore",
                "Alamofire"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Calendar module
        .target(
            name: "SwiftXDAVCalendar",
            dependencies: [
                "SwiftXDAVCore",
                "SwiftXDAVNetwork"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Contacts module
        .target(
            name: "SwiftXDAVContacts",
            dependencies: [
                "SwiftXDAVCore",
                "SwiftXDAVNetwork"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Umbrella module
        .target(
            name: "SwiftXDAV",
            dependencies: [
                "SwiftXDAVCore",
                "SwiftXDAVNetwork",
                "SwiftXDAVCalendar",
                "SwiftXDAVContacts"
            ]
        ),

        // Tests
        .testTarget(name: "SwiftXDAVCoreTests", dependencies: ["SwiftXDAVCore"]),
        .testTarget(name: "SwiftXDAVNetworkTests", dependencies: ["SwiftXDAVNetwork"]),
        .testTarget(name: "SwiftXDAVCalendarTests", dependencies: ["SwiftXDAVCalendar"]),
        .testTarget(name: "SwiftXDAVContactsTests", dependencies: ["SwiftXDAVContacts"]),
    ],
    swiftLanguageVersions: [.v6]
)
