//
//  HTMLRichTextBackgroundStyle.swift
//  SwiftUIHTMLLocalComponent
//
//  背景样式枚举:透明(默认)/ 纯色 / 毛玻璃(backdrop-filter 模糊)。
//  毛玻璃的参数(模糊半径 / 色调 / 饱和度 / 高光 / 边缘光)全部暴露给调用方,
//  默认值对齐 H5 常见「高级毛玻璃」做法。
//

import SwiftUI

/// HTMLRichText 的背景样式。
///
/// 三个互斥的选项:
/// - `.transparent`:透明,内容直接叠加在宿主(SwiftUI)背景上 —— 组件默认;
/// - `.solid(_:)`:整块纯色(可带透明度,`Color.opacity` 会写进 CSS);
/// - `.frosted(_:)`:毛玻璃 —— WebView 保持透明,文档内用
///   `backdrop-filter: blur(...) saturate(...)` 把背后的宿主内容模糊透出,
///   可调模糊半径、叠加色调(颜色 + 不透明度)、饱和度增强、对角高光与边缘光,
///   参数见 `HTMLRichTextFrostedStyle`。
///
/// 与旧字段的关系:设置后**优先于** `config.isTransparent` / `config.backgroundColor`(那对
/// 字段保留用于兼容,未设置 `backgroundStyle` 时的行为不变)。
///
/// 用法:
/// ```swift
/// // 毛玻璃:叠在彩色宿主视图上,背后内容被模糊透出(H5 高级毛玻璃预设)
/// HTMLRichText(content: "……", config: .init(backgroundStyle: .frosted(.card())))
///
/// // 纯色(不透明 / 半透明均可)
/// HTMLRichText(content: "……", config: .init(backgroundStyle: .solid(.teal.opacity(0.25))))
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
/// html, body {
///   background:
///     linear-gradient(135deg, rgba(255,255,255,0.35) 0%, rgba(255,255,255,0.04) 50%, rgba(0,0,0,0.04) 100%),  /* 对角高光 */
///     rgba(255,255,255,0.15);                       /* 半透明基色(必须半透明,blur 才透得出背后) */
///   -webkit-backdrop-filter: blur(20px) saturate(1.8);   /* -webkit- 前缀必须写,否则 iOS 不生效 */
///   backdrop-filter: blur(20px) saturate(1.8);
/// }
/// html {
///   box-shadow: inset 0 1px 0 rgba(255,255,255,0.35),  /* 顶部内高光 */
///               inset 0 -1px 0 rgba(255,255,255,0.14), /* 底部内微光 */
///               0 0 0 1px rgba(255,255,255,0.35);      /* 发丝描边(边框位) */
/// }
/// ```
/// 说明:
/// - `blurRadius` 直接以 CSS px(= SwiftUI pt,因排版宽度按容器 pt 注入)书写;
/// - 色调不透明度按 `tintOpacity` 与色调自身 alpha 相乘后统一写进 `rgba()`;基色
///   **必须半透明**,完全不透的纯色会盖住背后内容、毛玻璃无从谈起;
/// - 高光 / 边缘光是「高级毛玻璃」的加分项(透亮感 + 边界明确),不想要时置 0。
public struct HTMLRichTextFrostedStyle {

    /// 背景模糊半径(CSS px),默认 20。越大背后内容越糊;0 等于只叠加色调、不模糊。
    public var blurRadius: CGFloat

    /// 叠加在模糊背景上的色调;nil = 按深浅色自动取白 / 近黑。
    /// 传 `.clear` 表示不要色调,只做纯模糊。
    public var tintColor: Color?

    /// 色调不透明度(0...1),默认 0.15 —— 对齐 H5 常见 `rgba(255,255,255,0.1~0.15)`:
    /// 基色越透,背后内容的模糊感越明显;写大了会「盖住」、失去通透感。
    public var tintOpacity: CGFloat

    /// 饱和度增强倍数,默认 1.8(即 H5 惯用的 `saturate(180%)`,更「鲜」);
    /// 传 nil 表示不写 `saturate()`。
    public var saturationAmount: CGFloat?

    /// 对角高光强度(0 = 关闭,1 = 最强)。按 H5 高级毛玻璃把一段
    /// `linear-gradient(135deg, 白 → 接近透明 → 极淡黑)` 叠在基色之上,
    /// 制造「晶莹剔透」的上光感;默认 0.35。
    public var shineOpacity: CGFloat

    /// 边缘光强度(0 = 关闭,1 = 最强)。在块边缘画「顶部内高光 + 底部内微光 +
    /// 1px 发丝描边」,让毛玻璃块的边界清晰可辨(纯模糊没有边界,视觉上容易
    /// 和宿主糊成一片);默认 0.35。
    public var rimOpacity: CGFloat

    /// 全参构造(都有默认值)。
    public init(
        blurRadius: CGFloat = 20,
        tintColor: Color? = nil,
        tintOpacity: CGFloat = 0.15,
        saturationAmount: CGFloat? = 1.8,
        shineOpacity: CGFloat = 0.35,
        rimOpacity: CGFloat = 0.35
    ) {
        self.blurRadius = blurRadius
        self.tintColor = tintColor
        self.tintOpacity = tintOpacity
        self.saturationAmount = saturationAmount
        self.shineOpacity = shineOpacity
        self.rimOpacity = rimOpacity
    }

    /// 常用预设:高级毛玻璃卡(通透白基 + 对角高光 + 边缘光,适合浅色宿主)。
    /// `blur 20 + saturate(180%) + 1px 描边` 即 H5 最常用的组合。
    public static func card() -> HTMLRichTextFrostedStyle {
        HTMLRichTextFrostedStyle(
            blurRadius: 20,
            tintColor: .white,
            tintOpacity: 0.15,
            saturationAmount: 1.8,
            shineOpacity: 0.35,
            rimOpacity: 0.35
        )
    }

    /// 常用预设:深色毛玻璃卡(近黑基调、压低高光,适合深色宿主 / 夜间模式)。
    public static func darkCard() -> HTMLRichTextFrostedStyle {
        HTMLRichTextFrostedStyle(
            blurRadius: 20,
            tintColor: Color(red: 0.07, green: 0.07, blue: 0.09),
            tintOpacity: 0.25,
            saturationAmount: 1.2,
            shineOpacity: 0.15,
            rimOpacity: 0.2
        )
    }
}