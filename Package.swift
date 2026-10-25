// swift-tools-version: 6.2
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade
import PackageDescription

let package = Package(
    name: "MacPat",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "MacPatCore", targets: ["MacPatCore"]),
        .library(name: "CleanKit", targets: ["CleanKit"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    targets: [
        .target(name: "MacPatCore"),
        .target(name: "DesignSystem"),
        .target(
            name: "CleanKit",
            dependencies: ["MacPatCore", "DesignSystem"],
            resources: [.copy("Rules")]
        ),
        .testTarget(name: "MacPatCoreTests", dependencies: ["MacPatCore"]),
        .testTarget(name: "CleanKitTests", dependencies: ["CleanKit", "MacPatCore"]),
    ],
    swiftLanguageModes: [.v6]
)
