// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MguiExRuntime",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/Flight-School/MessagePack.git", from: "1.2.4")
    ],
    targets: [
        .executableTarget(
            name: "MguiExRuntime",
            dependencies: ["MessagePack"],
            path: "Sources/MguiExRuntime"
        )
    ]
)