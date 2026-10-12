// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIFoodRecognition",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "FoodRecognitionCore", targets: ["FoodRecognitionCore"]),
        .library(name: "FoodRecognitionUI", targets: ["FoodRecognitionUI"])
    ],
    targets: [
        .target(name: "FoodRecognitionCore"),
        .target(name: "FoodRecognitionUI", dependencies: ["FoodRecognitionCore"],
                path: "PrototypeApp",
                exclude: ["Assets.xcassets", "FoodRecognitionPrototype.xcodeproj",
                          "FoodRecognitionPrototypeApp.swift", "Info.plist"]),
        .testTarget(name: "FoodRecognitionCoreTests", dependencies: ["FoodRecognitionCore"])
    ]
)
