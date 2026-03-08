// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "evnia",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Evnia",
            targets: ["Evnia"]
        ),
        .executable(
            name: "EvniaRainbowDemo",
            targets: ["EvniaRainbowDemo"]
        ),
    ],
    targets: [
        .target(
            name: "Evnia",
            linkerSettings: [
                .linkedFramework("CoreFoundation"),
                .linkedFramework("IOKit"),
            ]
        ),
        .executableTarget(
            name: "EvniaRainbowDemo",
            dependencies: ["Evnia"]
        ),
    ]
)
