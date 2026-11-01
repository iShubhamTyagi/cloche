// swift-tools-version: 6.2
import PackageDescription

let settings: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "ClocheKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(
            name: "ClocheKit",
            targets: ["Domain", "DoorSensing", "Persistence", "Services", "DesignSystem", "Features", "BakeActivity"]
        ),
        // The widget extension: draws the bake's Live Activity (lock screen, Dynamic Island, Watch).
        .library(name: "BakeActivityUI", targets: ["BakeActivityUI", "BakeActivity", "DesignSystem"]),
    ],
    targets: [
        // Pure Swift: models, session engine, grading. Depends on nothing.
        .target(name: "Domain", swiftSettings: settings),
        .target(name: "DoorSensing", dependencies: ["Domain"], swiftSettings: settings),
        .target(name: "Persistence", dependencies: ["Domain"], swiftSettings: settings),
        // The Live Activity's shared model: the app starts it, the widget extension draws it.
        .target(name: "BakeActivity", swiftSettings: settings),
        .target(name: "BakeActivityUI", dependencies: ["BakeActivity", "DesignSystem"], resources: [.process("Resources")], swiftSettings: settings),
        .target(name: "Services", dependencies: ["Domain", "BakeActivity"], resources: [.process("Resources")], swiftSettings: settings),
        // SwiftUI only; no domain knowledge.
        .target(name: "DesignSystem", resources: [.process("Resources")], swiftSettings: settings),
        .target(
            name: "Features",
            dependencies: ["Domain", "DoorSensing", "Persistence", "Services", "DesignSystem"],
            resources: [.process("Resources")],
            swiftSettings: settings
        ),
        .testTarget(name: "DomainTests", dependencies: ["Domain"], swiftSettings: settings),
        .testTarget(name: "DoorSensingTests", dependencies: ["DoorSensing", "Domain"], swiftSettings: settings),
        .testTarget(name: "ServicesTests", dependencies: ["Services", "Domain"], swiftSettings: settings),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "Domain"], swiftSettings: settings),
        .testTarget(name: "FeaturesTests", dependencies: ["Features", "Domain", "DoorSensing", "Persistence"], swiftSettings: settings),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"], swiftSettings: settings),
    ]
)
