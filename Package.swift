// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YourpaymentsSDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Yourpayments",
            targets: ["Yourpayments"]
        )
    ],
    targets: [
        .target(
            name: "Yourpayments",
            dependencies: [],
            path: "sdk",
            exclude: [
                "Tests",
                "README.md",
                "PrivacyInfo.xcprivacy",
                "Sources/Info.plist"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "YourpaymentsTests",
            dependencies: ["Yourpayments"],
            path: "sdk/Tests/sdkTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
