// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WinOnMac",
    products: [
        .library(name: "WinOnMacCore", targets: ["WinOnMacCore"]),
    ],
    targets: [
        .target(
            name: "WinOnMacCore",
            path: "Sources/WinOnMacCore"
        ),
        .testTarget(
            name: "WinOnMacCoreTests",
            dependencies: ["WinOnMacCore"],
            path: "Tests/WinOnMacCoreTests"
        ),
    ]
)
