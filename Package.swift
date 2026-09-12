// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Duck",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6"),
    ],
    targets: [
        // Settings, shortcut, login item. Never touches the screen.
        .target(
            name: "DuckCore",
            path: "src/data",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The app itself: menu bar items and the preferences window.
        .executableTarget(
            name: "Duck",
            dependencies: [
                "DuckCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "src",
            exclude: ["data"],
            sources: ["app", "ui"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Plain checks run with `swift run DuckChecks`. The command line tools ship
        // Swift Testing without its library paths wired up, so a test target cannot load here.
        .executableTarget(
            name: "DuckChecks",
            dependencies: ["DuckCore"],
            path: "tests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
