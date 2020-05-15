// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BBCode",
    products: [
        .library(name: "BBCode", targets: ["BBCode"])
    ],
    dependencies: [],
    targets: [
        .target(name: "BBCode"),
        .testTarget(name: "BBCodeTests", dependencies: ["BBCode"])
    ]
)

