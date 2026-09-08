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
                        // 兜底:WebKit 偶发的首帧漏绘(图片看不到)常因 UI 侧持有过期的
                        // 远程图层快照所致。就绪后隔几拍无害地重绘几次自己的图层,
                        // 让合成器拉取最新帧 —— 与 JS 侧的 reflow 扰动(两处保险)配合。
                        // 多次 nud 覆盖慢解码图片在就绪之后才完成解码的情况。
                        if let webView = message.webView {
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
                // 图片「解码完成但合成器没画上去」的漏绘自愈:JS 在每张图 load /
                // 整页 load 后请求对图层 nud 一次,拉取最新合成帧。
                if let webView = message.webView {
                    DispatchQueue.main.async {
                        Self.nudgePaint(webView)
                    }
                }
            case "img":
                // 图片兜底调试消息:DEBUG 下默认打印(与 JS 侧 `__htmlRichTextImgDebug`
                // 的默认开启保持一致,不依赖 HRT_IMG_DBG 环境变量 —— 直接点图标运行 /
                // 真机调试时环境变量传不进来,会导致该日志一行都看不到)。
                // 设 HRT_IMG_DBG=0 可关闭。
                #if DEBUG
                if ProcessInfo.processInfo.environment["HRT_IMG_DBG"] != "0" {
                    let src = body["src"] as? String ?? "?"
                    let attempt = body["attempt"] as? NSNumber ?? 0
                    // stats 消息没有 src,单独打一行:解码统计用于区分「解码失败」与「解码但漏绘」
                    if let status = body["status"] as? String, status == "stats" {
                        print("HRT_IMG stats decoded=\(body["decoded"] ?? "?")/total=\(body["total"] ?? "?") failed=\(body["failed"] ?? "?")")
                    } else {
                        print("HRT_IMG \(body["reason"] ?? "?")[\(attempt)] src=\(src)")
                    }
                }
                #endif
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

        /// 让 WebView 强制整页重新光栅化(漏绘自愈)。可选延时,
        /// 用于「就绪之后图片才解码完成」等场景的二次、三次兜底。
        ///
        /// 关键:对 WebKit 的独立 WebContent 渲染进程,**`layer.setNeedsDisplay()` /
        /// transform 都只动 UI 进程这一侧的 GPU 合成层,不会触发远程进程的 tile
        /// 重新光栅化** —— 这正是此前「setNeedsDisplay + JS transform」兜底对漏绘
        /// 收效甚微的原因。唯一可靠的是 `takeSnapshot(with:)`:它要求 WebKit 产出
        /// 完整一帧渲染(强制所有 tile 重栅格化),把结果丢弃即可 —— 无任何可见
        /// 副作用,效果等同「划出去再划回来」(滚动正是靠强制重栅格化修好漏绘)。
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
            //(例如系统字体加载完成后高度可能变化)。
            let width = Int(webView.bounds.width)
            if width > 0 {
                webView.evaluateJavaScript(
                    "window.__htmlRichTextWidth = \(width); window.__htmlRichTextReportSize && window.__htmlRichTextReportSize()"
                ) { _, _ in }
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