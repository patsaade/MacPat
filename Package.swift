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
        .library(name: "PersistenceKit", targets: ["PersistenceKit"]),
        .library(name: "UninstallKit", targets: ["UninstallKit"]),
        .library(name: "AnalyzeKit", targets: ["AnalyzeKit"]),
        .library(name: "StatusKit", targets: ["StatusKit"]),
        .library(name: "OptimizeKit", targets: ["OptimizeKit"]),
    ],
    targets: [
        .target(name: "MacPatCore"),
        .target(name: "DesignSystem", dependencies: ["MacPatCore"]),
        .target(
            name: "CleanKit",
            dependencies: ["MacPatCore", "DesignSystem"],
            resources: [.copy("Rules")]
        ),
        .target(name: "PersistenceKit", dependencies: ["MacPatCore", "DesignSystem"]),
        .target(name: "UninstallKit", dependencies: ["MacPatCore", "DesignSystem", "PersistenceKit"]),
        .target(name: "AnalyzeKit", dependencies: ["MacPatCore", "DesignSystem"]),
        .target(name: "StatusKit", dependencies: ["DesignSystem"]),
        .target(name: "OptimizeKit", dependencies: ["MacPatCore", "DesignSystem", "AnalyzeKit"]),
        .testTarget(name: "StatusKitTests", dependencies: ["StatusKit"]),
        .testTarget(name: "OptimizeKitTests", dependencies: ["OptimizeKit", "MacPatCore"]),
        .testTarget(name: "UninstallKitTests", dependencies: ["UninstallKit", "MacPatCore", "PersistenceKit"]),
        .testTarget(name: "AnalyzeKitTests", dependencies: ["AnalyzeKit", "MacPatCore"]),
        .testTarget(name: "PersistenceKitTests", dependencies: ["PersistenceKit", "MacPatCore"]),
        .testTarget(name: "MacPatCoreTests", dependencies: ["MacPatCore"]),
        .testTarget(name: "CleanKitTests", dependencies: ["CleanKit", "MacPatCore"]),
    ],
    swiftLanguageModes: [.v6]
)
