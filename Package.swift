// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lex",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "LexCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "Lex", dependencies: ["LexCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "lex-eval", dependencies: ["LexCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "LexCoreTests", dependencies: ["LexCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
