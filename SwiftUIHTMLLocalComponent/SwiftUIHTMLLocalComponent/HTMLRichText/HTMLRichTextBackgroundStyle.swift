//
//  HTMLRichTextBackgroundStyle.swift
//  SwiftUIHTMLLocalComponent
//
//  背景样式枚举:透明(默认)/ 纯色 / 毛玻璃(backdrop-filter 模糊)。
//  毛玻璃的参数(模糊半径 / 色调 / 饱和度增强)全部暴露给调用方。
//

import SwiftUI

/// HTMLRichText 的背景样式。
///
/// 三个互斥的选项:
/// - `.transparent`:透明,内容直接叠加在宿主(SwiftUI)背景上 —— 组件默认;
/// - `.solid(_:)`:整块纯色(可带透明度,`Color.opacity` 会写进 CSS);
/// - `.frosted(_:)`:毛玻璃 —— WebView 保持透明,文档内用
///   `backdrop-filter: blur(...) saturate(...)` 把背后的宿主内容模糊透出,
///   可调模糊半径、叠加色调(颜色 + 不透明度)、饱和度增强,参数见
///   `HTMLRichTextFrostedStyle`。
///
/// 与旧字段的关系:设置后**优先于** `config.isTransparent` / `config.backgroundColor`(那对
/// 字段保留用于兼容,未设置 `backgroundStyle` 时的行为不变)。
///
/// 用法:
/// ```swift
/// // 毛玻璃:叠在彩色宿主视图上,背后内容被模糊透出
/// HTMLRichText(content: "……", config: .init(
///     backgroundStyle: .frosted(.init(blurRadius: 16, tintColor: .white, tintOpacity: 0.4))
/// ))
///
/// // 纯色(不透明 / 半透明均可)
/// HTMLRichText(content: "……", config: .init(
///     backgroundStyle: .solid(.teal.opacity(0.25))
/// ))
/// ```
public enum HTMLRichTextBackgroundStyle {

    /// 透明背景(默认):内容无缝隙嵌入宿主,谁放背后就透出谁。
    case transparent

    /// 纯色背景(含透明度)。
    case solid(Color)

    /// 毛玻璃背景:`backdrop-filter` 模糊背后内容,参数见 `HTMLRichTextFrostedStyle`。
    case frosted(HTMLRichTextFrostedStyle)
}

/// 毛玻璃(`backdrop-filter`)背景的可调参数。
///
/// 全部字段都有默认值,通常只需调一两个。产生的 CSS 形如:
/// ```
/// background: rgba(色调, 色调不透明度);
/// -webkit-backdrop-filter: blur(半径) saturate(饱和度);
/// backdrop-filter: blur(半径) saturate(饱和度);
/// ```
/// 说明:`blurRadius` 直接以 CSS px(= SwiftUI pt,因排版宽度按容器 pt 注入)书写;
/// 透明度按 `tintOpacity` 与色调自身 alpha 相乘后统一写进 `rgba()`。
public struct HTMLRichTextFrostedStyle {

    /// 背景模糊半径(CSS px),默认 20。越大背后内容越糊;0 等于只叠加色调、不模糊。
    public var blurRadius: CGFloat

    /// 叠加在模糊背景上的色调;nil = 按深浅色自动取白 / 近黑。
    /// 传 `.clear` 表示不要色调,只做纯模糊。
    public var tintColor: Color?

    /// 色调不透明度(0...1),默认 0.4。
    public var tintOpacity: CGFloat

    /// 饱和度增强倍数,默认 1.8(更「鲜」);传 nil 表示不写 `saturate()`。
    public var saturationAmount: CGFloat?

    /// 全参构造(都有默认值)。
    public init(
        blurRadius: CGFloat = 20,
        tintColor: Color? = nil,
        tintOpacity: CGFloat = 0.4,
        saturationAmount: CGFloat? = 1.8
    ) {
        self.blurRadius = blurRadius
        self.tintColor = tintColor
        self.tintOpacity = tintOpacity
        self.saturationAmount = saturationAmount
    }

    /// 常用预设:浅色毛玻璃卡片(暖白基调 + 弱饱和,适合浅色宿主)。
    public static func card() -> HTMLRichTextFrostedStyle {
        HTMLRichTextFrostedStyle(
            blurRadius: 20,
            tintColor: .white,
            tintOpacity: 0.45,
            saturationAmount: 1.6
        )
    }

    /// 常用预设:深色毛玻璃卡片(近黑基调,适合深色宿主 / 夜间模式)。
    public static func darkCard() -> HTMLRichTextFrostedStyle {
        HTMLRichTextFrostedStyle(
            blurRadius: 20,
            tintColor: Color(red: 0.07, green: 0.07, blue: 0.09),
            tintOpacity: 0.55,
            saturationAmount: 1.0
        )
    }
}