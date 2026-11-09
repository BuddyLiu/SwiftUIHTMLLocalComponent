//
//  HTMLRichTextGlassView.swift
//  SwiftUIHTMLLocalComponent
//
//  玻璃包装层:在 HTMLRichTextFrostedView 之上再封一层,让「玻璃效果」可选。
//  默认仍是毛玻璃(backdrop-filter);需要时可以切到系统原生玻璃效果
//  (SwiftUI `.glassEffect`,iOS 26+ / macOS 26+),低版本自动退回毛玻璃。
//

import SwiftUI

/// 玻璃视图包装层。
///
/// 在 `HTMLRichTextFrostedView` 之上再封一层,提供**可选的玻璃效果**:
/// - 默认 `.frosted(.light())`,行为与直接用 `HTMLRichTextFrostedView(style: .light())`
///   完全一致(恒定 backdrop-filter 毛玻璃,所有系统版本可用);
/// - 传入 `.glass(...)`,在支持 `glassEffect` 的系统版本上切换为 SwiftUI 原生玻璃,
///   旧版本自动退回 `HTMLRichTextGlassEffect.fallbackFrostedStyle` 的毛玻璃 ——
///   即「想在高版本用玻璃效果、低版本用毛玻璃效果」。
///
/// 用法:
/// ```swift
/// // 默认:恒定毛玻璃(等价旧视图)
/// HTMLRichTextGlassView()
///
/// // 高版本原生玻璃,低版本自动退回毛玻璃(默认档 + 圆角玻璃面)
/// HTMLRichTextGlassView(style: .glass(.regular), cornerRadius: 12)
///
/// // 染色玻璃:给玻璃叠一层青色
/// HTMLRichTextGlassView(style: .glass(.tinted(.cyan)), cornerRadius: 16)
///
/// // 恒定毛玻璃(显式指定档位)
/// HTMLRichTextGlassView(style: .frosted(.thinMaterial()))
/// ```
///
/// - Note: 与 `HTMLRichTextFrostedView` 相同,**高度需要宿主给定**(`.frame(height:)`
///   或外部约束),视图会强制铺满传入的宽高。
/// - Note: `cornerRadius` 只作用于系统玻璃路径(`glassEffect` 的 `in:` 形状),让玻璃
///   边缘自带圆角;`.frosted(...)` 路径的圆角仍由宿主 `.clipShape(...)` 负责。
public struct HTMLRichTextGlassView: View {

    /// 玻璃样式:`.frosted`(恒定毛玻璃,默认)/ `.glass`(高版本原生玻璃 + 低版本兜底)。
    let style: HTMLRichTextGlassStyle

    /// 强制使用的深浅色基调;nil 跟随系统。只影响毛玻璃路径(原生玻璃自适应)。
    let preferredColorScheme: ColorScheme?

    /// 系统玻璃路径的圆角(默认 0 = 直角矩形);毛玻璃路径忽略(由宿主 clipShape)。
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var systemScheme

    public init(
        style: HTMLRichTextGlassStyle = .frosted(.light()),
        colorScheme: ColorScheme? = nil,
        cornerRadius: CGFloat = 0
    ) {
        self.style = style
        self.preferredColorScheme = colorScheme
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        GeometryReader { proxy in
            Group {
                switch style {
                case .frosted(let frostedStyle):
                    // 恒定毛玻璃:原样复用 HTMLRichTextFrostedView(无桥极简文档链路)
                    HTMLRichTextFrostedView(
                        style: frostedStyle,
                        colorScheme: preferredColorScheme ?? systemScheme
                    )

                case .glass(let glassEffect):
                    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
                        // 高版本:系统原生玻璃(glassEffect)
                        SystemGlassLayer(
                            glass: glassEffect.glass,
                            cornerRadius: cornerRadius
                        )
                    } else {
                        // 低版本:退回对应档位的毛玻璃
                        HTMLRichTextFrostedView(
                            style: glassEffect.fallbackFrostedStyle,
                            colorScheme: preferredColorScheme ?? systemScheme
                        )
                    }
                }
            }
            .frame(width: proxy.size.width, height: glassHeight(proxy.size.height), alignment: .top)
        }
    }

    /// 高度兜底:GeometryReader 在无约束父级里可能给出 0 或无穷大,统一折算成合理值
    ///(正常用法宿主会给明确高度,这里只防止空/非法尺寸把玻璃层塌没)。
    private func glassHeight(_ proposed: CGFloat) -> CGFloat {
        guard proposed.isFinite else { return 320 }
        return max(1, proposed)
    }
}

/// 玻璃视图的可选样式。
///
/// 两种:
/// - `.frosted(_:)`:恒定的毛玻璃(backdrop-filter),所有系统版本可用 —— **默认**;
/// - `.glass(_:)`:系统原生玻璃(SwiftUI `glassEffect`),高版本用原生玻璃,
///   低版本自动退回对应的毛玻璃档位。
public enum HTMLRichTextGlassStyle {
    
    /// 恒定毛玻璃:复用 `HTMLRichTextFrostedView` 的 backdrop-filter 链路,
    /// 所有系统版本可用,参数见 `HTMLRichTextFrostedStyle`。当样式携带
    /// `systemEffect`(经 `HTMLRichTextFrostedStyle.uiBlurEffect(_:)` / `.material(_:)`
    /// 构造)时,内部改为渲染系统原生毛玻璃(`UIVisualEffectView` / SwiftUI `Material`)。
    case frosted(HTMLRichTextFrostedStyle)
    
    /// 系统原生玻璃:在支持 `glassEffect` 的系统版本(iOS 26+ / macOS 26+ 等)
    /// 用 SwiftUI 原生玻璃效果,不支持的旧版本自动退回
    /// `HTMLRichTextGlassEffect` 各自对应的毛玻璃档位(见
    /// `HTMLRichTextGlassEffect.fallbackFrostedStyle`)。
    case glass(HTMLRichTextGlassEffect)
}

/// 系统原生玻璃(SwiftUI `Glass`)的档位。
///
/// 一一对应 SwiftUI `glassEffect(_:in:)` 里的 `Glass`:
/// - `.regular`:默认玻璃;
/// - `.clear`:不叠色调的玻璃,最通透;
/// - `.tinted(color)`:`Glass.regular.tint(color)`,给玻璃染色;
/// - `.interactive`:`Glass.regular.interactive()`,随触摸产生动态弹性反馈;
/// - `.tintedInteractive(color)`:染色 + 交互式。
///
/// 每种档位都有一个低版本兜底(`.fallbackFrostedStyle`),实现「高版本玻璃、
/// 低版本毛玻璃」。
public enum HTMLRichTextGlassEffect {
    
    /// 系统默认玻璃(`Glass.regular`)。
    case regular
    
    /// 无色调玻璃(`Glass.clear`):只保留玻璃质感、不叠色。
    case clear
    
    /// 染色玻璃(`Glass.tinted(color)`):给玻璃表面叠一层色调。
    case tinted(Color)
    
    /// 交互式玻璃(`Glass.interactive()`):随触摸产生弹性反馈。
    case interactive
    
    /// 染色 + 交互式玻璃(`Glass.tinted(color).interactive()`)。
    case tintedInteractive(Color)
    
    /// 映射到 SwiftUI `Glass`。仅在高版本(`glassEffect` 可用时)调用。
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
    var glass: Glass {
        switch self {
            case .regular:
                return .regular
            case .clear:
                return .clear
            case .tinted(let color):
                return .regular.tint(color)
            case .interactive:
                return .regular.interactive()
            case .tintedInteractive(let color):
                return .regular.tint(color).interactive()
        }
    }
    
    /// 低版本兜底:无 `glassEffect` 时退回的毛玻璃档位,让玻璃感在旧系统
    /// 上仍有一个最接近的近似。
    public var fallbackFrostedStyle: HTMLRichTextFrostedStyle {
        switch self {
            case .regular:
                // 系统默认玻璃 ≈ 系统默认材质档
                return .regularMaterial()
            case .clear:
                // 无色调玻璃 ≈ 最透材质档(纯模糊不叠色)
                return .ultraThinMaterial()
            case .tinted(let color), .tintedInteractive(let color):
                // 染色玻璃 ≈ 同色调的毛玻璃
                return HTMLRichTextFrostedStyle(
                    blurRadius: 4,
                    tintColor: color,
                    tintOpacity: 0.05,
                    saturationAmount: 1.8,
                    shineOpacity: 0,
                    rimOpacity: 0
                )
            case .interactive:
                // 交互弹性反馈没有静态等价物,退回系统默认材质档
                return .regularMaterial()
        }
    }
}

/// 系统原生玻璃层:iOS 26+ / macOS 26+ 专用,在给定形状内渲染 `glassEffect`。
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct SystemGlassLayer: View {

    let glass: Glass
    let cornerRadius: CGFloat

    var body: some View {
        Color.clear
            .glassEffect(glass, in: shape)
    }

    /// glassEffect 的 `in:` 形状:带圆角时给玻璃面自身圆角(比宿主 clipShape
    /// 裁出来的硬边更自然);0 时铺满矩形。
    private var shape: AnyShape {
        if cornerRadius > 0 {
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        return AnyShape(Rectangle())
    }
}
