// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIFoodRecognition",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "FoodRecognitionCore", targets: ["FoodRecognitionCore"])],
    targets: [
        .target(name: "FoodRecognitionCore"),
        .testTarget(name: "FoodRecognitionCoreTests", dependencies: ["FoodRecognitionCore"])
    ]
)
