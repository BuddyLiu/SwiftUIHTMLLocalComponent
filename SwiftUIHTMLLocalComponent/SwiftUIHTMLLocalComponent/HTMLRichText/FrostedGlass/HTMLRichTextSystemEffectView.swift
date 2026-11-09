//
//  HTMLRichTextSystemEffectView.swift
//  SwiftUIHTMLLocalComponent
//
//  系统原生毛玻璃层:把 HTMLRichTextFrostedStyle.systemEffect
//  (UIKit UIBlurEffect / SwiftUI Material)渲染成真正的系统自带效果。
//

import SwiftUI
import UIKit

/// 渲染 `HTMLRichTextFrostedSystemEffect` 的**系统原生毛玻璃层**。
///
/// 两种效果分别走系统自带实现,不做任何 CSS 参数翻译:
/// - `.uiBlurEffect(style)` → `UIVisualEffectView` + `UIBlurEffect(style:)`;
/// - `.material(id:)` → SwiftUI `Material` 背景(`.background(material)`)。
///
/// 该视图**只负责玻璃本身,不承载任何文本**:
/// - 在 `HTMLRichTextFrostedView`(纯玻璃)里直接铺满整块 —— 相比原来的 WKWebView +
///   CSS backdrop-filter 链路更轻(纯玻璃不再需要 WebContent 进程);
/// - 在 `HTMLRichText`(带内容)里放在透明 WebView 背后,内容在上、玻璃在下,
///   由原生层模糊透出背后的宿主内容。
public struct HTMLRichTextSystemEffectView: View {

    /// 要渲染的系统原生效果。
    public let effect: HTMLRichTextFrostedSystemEffect

    public init(effect: HTMLRichTextFrostedSystemEffect) {
        self.effect = effect
    }

    public var body: some View {
        switch effect {
        case .uiBlurEffect(let style):
            UIKitBlurView(style: style)
        case .material(let id):
            Color.clear
                .background(material(id))
        }
    }

    /// 材质标识 → SwiftUI `Material`(与 `HTMLRichTextFrostedStyle.material(_:)`
    /// 运行时反射读到的 `id` 一一对应;识别失败回落系统默认档)。
    private func material(_ id: String) -> Material {
        switch id {
        case "ultraThin":   return .ultraThinMaterial
        case "thin":        return .thinMaterial
        case "regular":     return .regularMaterial
        case "thick":       return .thickMaterial
        case "ultraThick":  return .ultraThickMaterial
        case "systemBars":  return .bar
        default:            return .regularMaterial
        }
    }
}

/// `UIBlurEffect` → `UIVisualEffectView` 的 `UIViewRepresentable` 包装。
/// 视图尺寸由 SwiftUI 布局提案决定,自动铺满分配到的区域。
private struct UIKitBlurView: UIViewRepresentable {

    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
