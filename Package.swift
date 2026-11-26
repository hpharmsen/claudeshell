// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Maestro",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", exact: "1.99.3"),
    ],
    targets: [
        .target(name: "MaestroCore"),
        .executableTarget(
            name: "Maestro",
            dependencies: ["MaestroCore", .product(name: "SwiftTerm", package: "SwiftTerm")]
        ),
        .testTarget(name: "MaestroCoreTests", dependencies: ["MaestroCore"]),
    ]
)
