// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "flash-gui",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "flash-gui", targets: ["FlashGUI"]),
    ],
    targets: [
        .executableTarget(
            name: "FlashGUI",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
            ]
        )
    ]
)
