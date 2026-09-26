// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PliKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PliCore", targets: ["PliCore"]),
        .library(name: "PliRender", targets: ["PliRender"]),
        .library(name: "PliSystem", targets: ["PliSystem"]),
        .library(name: "PliUI", targets: ["PliUI"]),
        .library(name: "PliApp", targets: ["PliApp"]),
        .executable(name: "pli-render", targets: ["pli-render"]),
    ],
    targets: [
        .target(name: "PliCore"),
        .target(name: "PliRender", dependencies: ["PliCore"]),
        .target(name: "PliSystem", dependencies: ["PliCore"]),
        .target(name: "PliUI", dependencies: ["PliCore", "PliRender"], resources: [.process("Resources")]),
        .target(name: "PliApp", dependencies: ["PliCore", "PliRender", "PliSystem", "PliUI"]),
        .executableTarget(name: "pli-render", dependencies: ["PliCore", "PliRender"]),
        .testTarget(name: "PliCoreTests", dependencies: ["PliCore"]),
        .testTarget(name: "PliRenderTests", dependencies: ["PliRender", "PliCore"]),
        .testTarget(name: "PliRenderToolTests", dependencies: ["pli-render"]),
        .testTarget(name: "PliSystemTests", dependencies: ["PliSystem", "PliCore"]),
        .testTarget(name: "PliUITests", dependencies: ["PliUI", "PliRender", "PliCore"]),
        .testTarget(name: "PliAppTests", dependencies: ["PliApp", "PliUI", "PliSystem", "PliRender", "PliCore"]),
    ]
)
