// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OllamaGateway",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OllamaGateway",
            path: "Sources/OllamaGateway"
        )
    ]
)
