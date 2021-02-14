// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "RxAutoBinding", targets: ["RxAutoBinding"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift", from: "6.0.0")
    ],
    targets: [
        .target(name: "RxAutoBinding", dependencies: ["RxSwift", "RxCocoa"], sources: "Sources")
    ]
)