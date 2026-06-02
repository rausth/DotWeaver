// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DotWeaver",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "DotWeaverApp", targets: ["DotWeaver"]),
        .executable(name: "dw", targets: ["DotWeaverCLI"])
    ],
    targets: [
        .target(
            name: "DotWeaverKit",
            dependencies: [],
            linkerSettings: [.linkedFramework("LocalAuthentication")]
        ),
        .executableTarget(
            name: "DotWeaver",
            dependencies: ["DotWeaverKit"],
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
