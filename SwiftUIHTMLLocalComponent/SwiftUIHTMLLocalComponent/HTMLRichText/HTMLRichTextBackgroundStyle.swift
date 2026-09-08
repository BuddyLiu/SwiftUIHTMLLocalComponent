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

    /// 常用预设。对应 H5 常见毛玻璃做法,按「模糊档位 + 基调色」分成:
    ///
    /// | 预设 | 风格 | 特点 |
    /// |---|---|---|
    /// | `.light()` | 浅色毛玻璃 | `blur(20px) saturate(180%)` + 半透明白基 + 发丝描边,无高光,最朴素常见 |
    /// | `.dark()` | 深色毛玻璃 | 近黑基,适合深色宿主 / 夜间模式 |
    /// | `.gradient()` | 渐变高级毛玻璃 | 基色之上再叠 135° 对角高光 + 内高光,「晶莹剔透」的高配版 |
    /// | `.fallback()` | 轻量毛玻璃 | `blur(5px) saturate(180%)` + 基色 0.2:档位最低、性能开销小,内容保留更多细节 |
    ///
    /// 旧预设 `.card()` = `.gradient()`、`.darkCard()` = `.dark()`(兼容别名)。
    ///
    /// 浅色毛玻璃(`glass-card` 风格):纯模糊 + 白基 + 描边,无高光渐变。
    public static func light() -> HTMLRichTextFrostedStyle {
        HTMLRichTextFrostedStyle(
            blurRadius: 20,
            tintColor: .white,
            tintOpacity: 0.15,
            saturationAmount: 1.8,
            shineOpacity: 0,
            rimOpacity: 0.3
        )
    }

    /// 深色毛玻璃(`glass-card` 深色版):近黑基调,适合深色宿主 / 夜间模式。
    public static func dark() -> HTMLRichTextFrostedStyle {
        HTMLRichTextFrostedStyle(
            blurRadius: 20,
            tintColor: Color(red: 0.07, green: 0.07, blue: 0.09),
            tintOpacity: 0.25,
            saturationAmount: 1.2,
            shineOpacity: 0,
            rimOpacity: 0.25
        )
    }

    /// 渐变高级毛玻璃(`glass-premium` 风格):通透白基 + 135° 对角高光 +
    /// saturate(180%) + 内高光,「晶莹剔透」的高配版。
    public static func gradient() -> HTMLRichTextFrostedStyle {
        HTMLRichTextFrostedStyle(
            blurRadius: 20,
            tintColor: .white,
            tintOpacity: 0.1,
            saturationAmount: 1.8,
            shineOpacity: 0.4,
            rimOpacity: 0.6
        )
    }

    /// 轻量毛玻璃(`glass-fallback` 风格):`blur(5px) saturate(180%)` +
    /// 基色 `rgba(,0.2)`。模糊档位最低、近乎轻量方案:性能开销小、对背后
    /// 内容保留更多可读细节,常用于内容较密的界面或作为高模糊的降级档。
    public static func fallback() -> HTMLRichTextFrostedStyle {
        HTMLRichTextFrostedStyle(
            blurRadius: 5,
            tintColor: .white,
            tintOpacity: 0.2,
            saturationAmount: 1.8,
            shineOpacity: 0,
            rimOpacity: 0.3
        )
    }

    /// 兼容别名:同 `.gradient()`。
    public static func card() -> HTMLRichTextFrostedStyle {
        gradient()
    }

    /// 兼容别名:同 `.dark()`。
    public static func darkCard() -> HTMLRichTextFrostedStyle {
        dark()
    }
}