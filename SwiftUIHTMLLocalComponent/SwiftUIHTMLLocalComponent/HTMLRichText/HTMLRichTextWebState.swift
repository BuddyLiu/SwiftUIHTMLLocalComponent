//
//  HTMLRichTextWebState.swift
//  SwiftUIHTMLLocalComponent
//
//  WebView 生命周期状态枚举:通过 `HTMLRichText` 的 `onStateChange` 唯一回调,
//  把「开始加载 → 渲染完成 → 高度就绪 / 异常」等不同状态分发给上层。
//

import Foundation

/// WebView 的生命周期状态(一次加载一条带状态的回调,与 onTap 各自独立)。
///
/// 典型顺序:`.loading` → `.rendered` → `.ready(height)`;
/// 渲染参数变化触发的重载会再次走一遍;中间任意一步失败则到 `.failed`。
public enum HTMLRichTextWebState: Equatable {

    /// 开始加载:首次加载,或参数变化(文字 / 样式 / 深浅色)触发的重载。
    /// 可在此显示 loading 占位。
    case loading

    /// 文档渲染完成(WKWebView `didFinish`),但内容高度可能还未回传。
    case rendered

    /// 首个有效内容高度已回传,可以安全展示了;参数为内容高度(pt)。
    /// 内容就绪后的后续高度微调(图片加载、旋转)不会重复触发本状态。
    case ready(CGFloat)

    /// 加载失败,附带错误描述。
    case failed(String)
}