// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ViAnh",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ViAnh",
            targets: ["ViAnh"]
        )
    ],
    targets: [
        .target(
            name: "ViAnh",
            path: "ViAnh",
            exclude: ["ViAnhApp.swift"]
        ),
        .testTarget(
            name: "ViAnhTests",
            dependencies: ["ViAnh"],
            path: "ViAnhTests"
        )
    ]
)
