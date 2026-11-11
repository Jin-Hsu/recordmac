// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QingLu",
    platforms: [.macOS("15.0")],
    products: [.executable(name: "QingLu", targets: ["QingLu"])],
    targets: [.executableTarget(name: "QingLu", swiftSettings: [.unsafeFlags(["-swift-version", "5"])])]
)
