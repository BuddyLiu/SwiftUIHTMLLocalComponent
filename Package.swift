// swift-tools-version:5.10
// 为 HTMLRichText 组件提供 SPM 接入入口(不影响 Xcode 工程)。
import PackageDescription

let package = Package(
    name: "HTMLRichText",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "HTMLRichText", targets: ["HTMLRichText"])
    ],
    targets: [
        .target(
            name: "HTMLRichText",
            path: "SwiftUIHTMLLocalComponent/SwiftUIHTMLLocalComponent/HTMLRichText"
        )
    ]
)