// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DotWeaver",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "DotWeaverApp", targets: ["DotWeaver"]),
        .executable(name: "dw", targets: ["DotWeaverCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
    ],
    targets: [
        .target(
            name: "DotWeaverKit",
            dependencies: [],
            linkerSettings: [.linkedFramework("LocalAuthentication")]
        ),
        .executableTarget(
            name: "DotWeaver",
            dependencies: [
                "DotWeaverKit",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [
                .copy("LICENSE")
            ]
        ),
        .executableTarget(
            name: "DotWeaverCLI",
            dependencies: ["DotWeaverKit"]
        ),
        .testTarget(
            name: "DotWeaverKitTests",
            dependencies: ["DotWeaverKit"]
        )
    ]
)
