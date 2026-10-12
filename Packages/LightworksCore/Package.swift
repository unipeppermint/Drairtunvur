// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LightworksCore", platforms: [.macOS(.v13), .iOS(.v15)],
  products: [.library(name: "LightworksCore", targets: ["LightworksCore"])],
  targets: [
    .target(name: "LightworksCore"),
    .testTarget(name: "LightworksCoreTests", dependencies: ["LightworksCore"]),
  ], swiftLanguageModes: [.v5])
