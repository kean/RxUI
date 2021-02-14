// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "RxUI",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(name: "RxUI", targets: ["RxUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "RxUI",
            dependencies: [
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxCocoa", package: "RxSwift")
            ],
            path: "Sources"
        )
    ]
)
