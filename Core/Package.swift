// swift-tools-version:5.9
// Платформенно-независимое ядро «Рациона»: расчёт целей, каталог продуктов, шаблоны блюд,
// подбор рациона и разбор этикеток. Собирается и тестируется на Linux (GitHub Actions),
// а в приложение для iPhone те же исходники входят напрямую (см. project.yml).
import PackageDescription

let package = Package(
    name: "RationCore",
    products: [.library(name: "RationCore", targets: ["RationCore"])],
    targets: [
        .target(name: "RationCore", path: "Sources/RationCore"),
        .testTarget(name: "RationCoreTests", dependencies: ["RationCore"], path: "Tests/RationCoreTests")
    ]
)
