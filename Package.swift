// swift-tools-version: 5.11
import PackageDescription

let package = Package(
    name: "strings-catalog-plugin",
    platforms: [
        .iOS(.v13),
        .macOS(.v13)
    ],
    products: [
        .plugin(
            name: "StringsCatalogPlugin",
            targets: ["StringsCatalogPlugin"]
        )
    ],
    targets: [
        .plugin(
            name: "StringsCatalogPlugin",
            capability: .buildTool(),
            path: "Plugins"
        )
    ]
)
