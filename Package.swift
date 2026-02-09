// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TutorialKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "TutorialKit", targets: ["TutorialKit"]),
    ],
    targets: [
        .target(name: "TutorialKit"),
    ]
)
