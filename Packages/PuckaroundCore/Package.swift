// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PuckaroundCore",
    defaultLocalization: "en",
    // iOS 16 is the app's floor (an iPhone 8 still plays). macOS is listed only so
    // `swift test` runs headless on the Mac — there is no Mac app, and never will be.
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        // Pure simulation — deterministic, no UI dependencies. Headlessly testable.
        .library(name: "PuckaroundCore", targets: ["PuckaroundCore"]),
        // SwiftUI rendering + touch capture. Depends on PuckaroundCore.
        .library(name: "PuckaroundKit", targets: ["PuckaroundKit"]),
        // Dev tool: renders the app icon from the game's own drawing code.
        .executable(name: "puckaround-icon", targets: ["PuckaroundIcon"]),
    ],
    targets: [
        .target(name: "PuckaroundCore"),
        .target(
            name: "PuckaroundKit",
            dependencies: ["PuckaroundCore"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .executableTarget(
            name: "PuckaroundIcon",
            dependencies: ["PuckaroundKit"]
        ),
        .testTarget(
            name: "PuckaroundCoreTests",
            dependencies: ["PuckaroundCore", "PuckaroundKit"]
        ),
    ]
)
