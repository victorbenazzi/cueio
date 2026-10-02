// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "cueio",
    platforms: [.macOS(.v14)],
    dependencies: [
        // cmark-gfm mantido pela Apple (branch gfm), fixado num commit para builds reproduzíveis.
        .package(url: "https://github.com/apple/swift-cmark.git", revision: "0c8947bbd58c491c54aae114aca40621cddc8357"),
    ],
    targets: [
        .executableTarget(
            name: "Cueio",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ],
            path: "Sources/Cueio"
        ),
    ]
)
