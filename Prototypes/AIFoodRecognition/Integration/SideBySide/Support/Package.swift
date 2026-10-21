// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MealPhotoSandboxSupport",
    platforms: [.iOS(.v17), .macOS(.v12)],
    products: [.library(name: "MealPhotoSandboxSupport", targets: ["MealPhotoSandboxSupport"])],
    targets: [
        .target(name: "MealPhotoSandboxSupport"),
        .testTarget(name: "MealPhotoSandboxSupportTests", dependencies: ["MealPhotoSandboxSupport"])
    ]
)
