// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorLiveReload",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapgoCapacitorLiveReload",
            targets: ["LiveReloadPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "LiveReloadPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/LiveReloadPlugin"),
        .testTarget(
            name: "LiveReloadPluginTests",
            dependencies: ["LiveReloadPlugin"],
            path: "ios/Tests/LiveReloadPluginTests")
    ]
)
