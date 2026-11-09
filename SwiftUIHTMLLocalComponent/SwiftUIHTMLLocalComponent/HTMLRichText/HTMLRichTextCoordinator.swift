//
//  HTMLRichTextCoordinator.swift
//  SwiftUIHTMLLocalComponent
//
//  桥接 WKWebView 导航回调与 JS 消息到 SwiftUI 回调。
//

import WebKit

extension HTMLRichTextView {

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

        /// 持有父视图值,以便把事件转发给用户的闭包回调。
        var parent: HTMLRichTextView

        /// 记录当前已渲染内容的内容指纹;只有指纹变化才重载。
        var renderedKey: String?

        /// 最近一次推送给 JS 的容器宽度,宽度未变化时不重复注入(性能优化)。
        var lastPushedWidth: Int = 0

        /// 最近一次上报给 SwiftUI 的内容高度,高度未变化时不重复回调,
        /// 避免高度自适应过程中每帧都触发一次 SwiftUI 重绘。
        var lastReportedHeight: CGFloat = 0

        /// 是否已上报过「高度就绪」;每次重新加载(start)时重置,保证重载后重新走一遍生命周期。
        var didReportReady = false

        /// 本地资源 scheme handler(加载主文档 + baseURL 下的相对路径资源)。
        let schemeHandler = HTMLRichTextSchemeHandler()

        init(_ parent: HTMLRichTextView) {
            self.parent = parent
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == HTMLRichTextTemplate.bridgeName,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            switch type {
            case "height":
                if let height = body["height"] as? NSNumber,
                   let value = CGFloat(exactly: height.doubleValue),
                   value > 0,
                   // 防御:异常暴涨的高度(正常内容不会超过 10 万像素)视为误测,忽略。
                   value < 100_000,
                   // 与上一次相同的高度不再回调,减少 SwiftUI 无谓重绘。
                   value != lastReportedHeight {
                    lastReportedHeight = value
                    parent.onHeightChange(value)
                    // 首个有效高度 → 「就绪」状态(内容可以展示了)
                    if !didReportReady {
                        didReportReady = true
                        parent.onStateChange(.ready(value))
                        // 就绪后再补几次重光栅化:覆盖「高度已就绪、但图片此时才解码完成」
                        // 的合成器漏绘场景(见 `nudgePaint`)。仅文档含 `<img>` 才需要
                        // (无文本毛玻璃 / 纯文本没有图片,跳过,省掉整页重栅格化)。
                        if parent.html.lowercased().contains("<img"), let webView = message.webView {
                            Self.nudgePaint(webView, at: 0.15)
                            Self.nudgePaint(webView, at: 0.5)
                            Self.nudgePaint(webView, at: 1.2)
                        }
                    }
                }
            case "tap":
                parent.onTap(makeContext(from: body))
            case "longPress":
                // 长按消息(带 data-long-press 的图片等元素)转发给上层的长按回调
                parent.onLongPress?(makeContext(from: body))
            case "imgpaint":
                // 图片解码完成后的轻量「重光栅化」请求:JS 在每张图 load /
                // 整页 load 后上报,修正合成器漏绘(见 `nudgePaint`)。
                // 无图文档 JS 侧不发该消息,这里再兜一层,防止任何残留消息触发重栅格化。
                guard parent.html.lowercased().contains("<img") else { break }
                if let webView = message.webView {
                    DispatchQueue.main.async {
                        Self.nudgePaint(webView)
                    }
                }
            default:
                break
            }
        }

        /// 把 JS 上报的 tap / longPress 消息体统一转成 `HTMLTapContext`。
        private func makeContext(from body: [String: Any]) -> HTMLTapContext {
            HTMLTapContext(
                url: (body["url"] as? String).flatMap(URL.init(string:)),
                elementID: body["id"] as? String,
                tagName: body["tag"] as? String,
                classes: (body["classes"] as? [String]) ?? [],
                dataAttributes: (body["data"] as? [String: String]) ?? [:],
                text: body["text"] as? String
            )
        }

        /// 强制 WebView 整页重新光栅化,修复合成器漏绘的图片。可选延时,
        /// 用于「就绪之后图片才解码完成」等场景的二次、三次兜底。
        ///
        /// WebKit 的渲染发生在独立的 WebContent 进程:`layer.setNeedsDisplay()` 与
        /// CSS transform 只影响 UI 进程一侧的 GPU 合成层,不会触发远程进程的 tile
        /// 重新光栅化。`takeSnapshot(with:)` 要求 WebKit 产出完整一帧渲染(强制所有
        /// tile 重栅格化),把结果丢弃即可 —— 无任何可见副作用,效果等同滚动一次。
        static func nudgePaint(_ webView: WKWebView, at delay: TimeInterval = 0) {
            let nudge = {
                webView.takeSnapshot(with: nil) { _, _ in }
                webView.layer.setNeedsDisplay()
                webView.scrollView.layer.setNeedsDisplay()
            }
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { nudge() }
            } else {
                DispatchQueue.main.async { nudge() }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // 每次开始加载(首次或渲染参数变化触发的重载)都重置「就绪」标记并上报 loading
            didReportReady = false
            parent.onStateChange(.loading)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 页面加载完,把 WebView 真实宽度同步给 JS 并按该宽度上报一次尺寸
            //(例如系统字体加载完成后高度可能变化)。无桥文档没有该 JS 全局,跳过。
            if parent.config.isBridgeNeeded {
                let width = Int(webView.bounds.width)
                if width > 0 {
                    webView.evaluateJavaScript(
                        "window.__htmlRichTextWidth = \(width); window.__htmlRichTextReportSize && window.__htmlRichTextReportSize()"
                    ) { _, _ in }
                }
            }
            parent.onStateChange(.rendered)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // 主文档加载失败(如 scheme 资源缺失)
            parent.onStateChange(.failed(error.localizedDescription))
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // 已加载到一半后失败
            parent.onStateChange(.failed(error.localizedDescription))
        }
    }
}