//
//  HTMLRichTextFrostedView.swift
//  SwiftUIHTMLLocalComponent
//
//  无文本的纯毛玻璃视图:复用 HTMLRichText 的 backdrop-filter 链路(可调模糊半径、
//  饱和度、色调渐变,而 SwiftUI 原生 .ultraThinMaterial 等只有固定档位)。
//

import SwiftUI

/// 无文本的**纯毛玻璃**视图。
///
/// 复用 `HTMLRichText` 的毛玻璃渲染链路(`backdrop-filter: blur(半径) saturate(倍数)`),
/// 但**不承载任何文本内容** —— 它只是一块可调的模糊玻璃,盖在背后的宿主内容上。
///
/// 与 SwiftUI 原生 `.ultraThinMaterial` 等固定档位不同,这里所有玻璃参数都可调:
/// 模糊半径(`blurRadius`)、饱和度(`saturationAmount`)、色调(`tintColor` / 多色
/// `tintColors` + 渐变方向 `tintDirection`)、色调透明度(`tintOpacity`)、对角高光
/// (`shineOpacity`)、顶部边缘光(`rimOpacity`),以及深浅色基调(`colorScheme`)。
///
/// 用法:
/// ```swift
/// ZStack {
///     colorfulBackground   // 宿主:毛玻璃模糊采样的就是它
///     HTMLRichTextFrostedView(style: .init(tintColors: [.blue, .purple], blurRadius: 30))
///         .clipShape(RoundedRectangle(cornerRadius: 16))   // 圆角由宿主负责
/// }
/// .frame(height: 200)
/// ```
///
/// - Note: **高度需要宿主给定**(`.frame(height:)` 或外部约束);本视图会强制铺满传入
///   的宽高,不走 `HTMLRichText` 的内容高度自适应(空内容测高恒 ≈1pt,内容自适应会把
///   WebView 塌成 1pt,故必须直接给足 frame)。
/// - Note: 圆角由宿主 `.clipShape(...)` 负责(毛玻璃块本身不做圆角)。
public struct HTMLRichTextFrostedView: View {

    /// 毛玻璃参数(全部可调,见 `HTMLRichTextFrostedStyle`)。
    let style: HTMLRichTextFrostedStyle

    /// 强制使用的深浅色基调;nil 跟随系统。
    let preferredColorScheme: ColorScheme?

    @Environment(\.colorScheme) private var systemScheme

    public init(
        style: HTMLRichTextFrostedStyle = .light(),
        colorScheme: ColorScheme? = nil
    ) {
        self.style = style
        self.preferredColorScheme = colorScheme
    }

    public var body: some View {
        GeometryReader { proxy in
            // 直接包 HTMLRichTextView(不走 HTMLRichText 的内容高度自适应):
            // 内容为空,渲染指纹由 html:"" + 毛玻璃样式决定,样式变化自动重载。
            // frame 强制铺满宿主给的宽高 —— html 盒恒等于视口,backdrop-filter
            // 恰好覆盖整块玻璃。
            HTMLRichTextView(
                html: "",
                config: HTMLRichTextConfig(backgroundStyle: .frosted(style)),
                colorScheme: preferredColorScheme ?? systemScheme,
                onHeightChange: { _ in },
                onTap: { _ in },
                onLongPress: nil,
                onStateChange: { _ in }
            )
            .frame(width: proxy.size.width, height: frostedHeight(proxy.size.height), alignment: .top)
        }
    }

    /// 高度兜底:GeometryReader 在无约束父级里可能给出 0 或无穷大,统一折算成合理值
    ///(正常用法宿主会给明确高度,这里只防止空/非法尺寸把 WebView 塌没)。
    private func frostedHeight(_ proposed: CGFloat) -> CGFloat {
        guard proposed.isFinite else { return 320 }
        return max(1, proposed)
    }
}
