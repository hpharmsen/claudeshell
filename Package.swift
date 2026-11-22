// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Claudeshell",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", exact: "1.99.3"),
    ],
    targets: [
        .target(name: "ClaudeshellCore"),
        .executableTarget(
            name: "Claudeshell",
            dependencies: ["ClaudeshellCore", .product(name: "SwiftTerm", package: "SwiftTerm")]
        ),
        .testTarget(name: "ClaudeshellCoreTests", dependencies: ["ClaudeshellCore"]),
    ]
)
