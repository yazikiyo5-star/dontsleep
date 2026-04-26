// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DontSleep",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DontSleep", targets: ["DontSleep"])
    ],
    targets: [
        .executableTarget(
            name: "DontSleep",
            path: "Sources/DontSleep"
        )
    ]
)
