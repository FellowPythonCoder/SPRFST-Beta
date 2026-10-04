// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SPRFST",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SprfstCore", targets: ["SprfstCore"]),
        .executable(name: "sprfst", targets: ["sprfst"])
    ],
    targets: [
        .target(name: "SprfstCore"),
        .executableTarget(name: "sprfst", dependencies: ["SprfstCore"]),
        .testTarget(name: "SprfstCoreTests", dependencies: ["SprfstCore"])
    ]
)
