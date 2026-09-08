//
//  HTMLRichTextView.swift
//  SwiftUIHTMLLocalComponent
//
//  UIViewRepresentable 封装:承载 WKWebView,注入 JS 桥,同步配置,
//  并把内部高度 / 点击事件通过闭包透传给 SwiftUI 层。
//

import SwiftUI
import WebKit

/// 包装 WKWebView 的桥接视图(组件内部使用,无需外部关心)。
struct HTMLRichTextView: UIViewRepresentable {

    let html: String
    let config: HTMLRichTextConfig
    let colorScheme: ColorScheme
    let onHeightChange: (CGFloat) -> Void
    let onTap: (HTMLTapContext) -> Void
    let onLongPress: ((HTMLTapContext) -> Void)?
    let onStateChange: (HTMLRichTextWebState) -> Void

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(
            frame: .zero,
            configuration: makeConfiguration(context: context)
        )
        webView.navigationDelegate = context.coordinator
        // 内部滚动完全由 config.isScrollEnabled 决定(默认关闭,内容交给外层滚动)。
        // 不再做「内容高度超出容器就自动开滚动」的接管:该行为带来过多高度反馈
        // 与测量问题,已移除;固定高度容器装不下时内容直接裁切。
        configureAppearance(webView, scrollEnabled: config.isScrollEnabled)
        // 首次加载放到 updateUIView:此时 WebView 才能拿到真实容器宽度,
        // 用固定宽度排版,避免 `width=device-width` 在窄容器里引发高度膨胀。
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 外观类原生属性(背景色 / 滚动开关等)即时同步,无需重载页面。
        // 滚动只跟 config.isScrollEnabled 走(默认关闭,内容由外层滚动)。
        configureAppearance(webView, scrollEnabled: config.isScrollEnabled)
        webView.allowsLinkPreview = config.isLinkPreviewEnabled

        // 布局宽度变化时才同步给 JS 并按该宽度重测高度(避免高度反馈循环里反复注入)。
        pushContainerWidth(webView, context: context)

        // 渲染相关的配置变更才需要重新加载;首次 updateUIView 也是在这里完成加载(此时宽度已知)。
        guard webView.bounds.width > 0 else {
            // 极端情况:首个 updateUIView 还没拿到宽度,延后补偿一次。
            deferOnceLoaded(webView, context: context)
            return
        }
        guard renderKey != context.coordinator.renderedKey else { return }
        context.coordinator.renderedKey = renderKey
        load(webView, context: context)
    }

    /// 兜底:首个 updateUIView 若尚未拿到宽度,延迟补偿加载。
    private func deferOnceLoaded(_ webView: WKWebView, context: Context) {
        DispatchQueue.main.async {
            if context.coordinator.renderedKey == nil, webView.bounds.width > 0 {
                context.coordinator.renderedKey = self.renderKey
                self.load(webView, context: context)
            }
        }
    }

    /// 把容器宽度写入 `window.__htmlRichTextWidth` 并触发一次重新测量。
    /// 宽度未变化时跳过,避免在高度自适应过程中反复 evaluateJavaScript。
    private func pushContainerWidth(_ webView: WKWebView, context: Context) {
        let width = Int(webView.bounds.width)
        guard width > 0, width != context.coordinator.lastPushedWidth else { return }
        context.coordinator.lastPushedWidth = width
        webView.evaluateJavaScript(
            "window.__htmlRichTextWidth = \(width); window.__htmlRichTextReportSize && window.__htmlRichTextReportSize();"
        ) { _, _ in }
    }

    // MARK: - 配置

    private func makeConfiguration(context: Context) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        // 注入 JS 桥(在文档解析前注入,保证事件监听早于内容)
        var scriptSource = HTMLRichTextTemplate.javaScript
        #if DEBUG
        // 图片加载兜底调试:**DEBUG 下默认开启**(不依赖环境变量)。
        // 之前按 HRT_IMG_DBG 环境变量门控,直接点图标运行 / 真机调试时环境变量
        // 传不进来,stats / retry 一行都不打,「加载失败」与「加载成功」日志看起来
        // 毫无区别,无法区分漏绘与解码失败。现在默认开;设 HRT_IMG_DBG=0 可关闭。
        if ProcessInfo.processInfo.environment["HRT_IMG_DBG"] != "0" {
            scriptSource = scriptSource.replacingOccurrences(
                of: "window.__htmlRichTextImgDebug = false;",
                with: "window.__htmlRichTextImgDebug = true;"
            )
        }
        #endif
        let script = WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(script)
        configuration.userContentController.add(context.coordinator, name: HTMLRichTextTemplate.bridgeName)
        // 本地资源(HTML 文档 + 相对路径图片等)统一走 hrtlocal:// scheme,
        // 由 scheme handler 在 baseURL 沙箱内读取,不依赖临时文件或读文件权限。
        configuration.setURLSchemeHandler(context.coordinator.schemeHandler,
                                          forURLScheme: HTMLRichTextSchemeHandler.schemeName)
        return configuration
    }

    private func configureAppearance(_ webView: WKWebView, scrollEnabled: Bool) {
        webView.isOpaque = false
        // 背景:透明模式用宿主背景无缝融合;非透明模式在加载阶段直接铺上配置的背景色,
        // 避免「先白底/先透明、CSS 生效后才变色」的加载闪烁。
        if config.isTransparent {
            webView.backgroundColor = .clear
            if #available(iOS 15.0, *) {
                webView.underPageBackgroundColor = .clear
            }
        } else {
            let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
            let background = UIColor(config.backgroundColor).resolvedColor(with: traits)
            webView.backgroundColor = background
            if #available(iOS 15.0, *) {
                webView.underPageBackgroundColor = background
            }
        }
        webView.scrollView.backgroundColor = webView.backgroundColor ?? .clear
        webView.scrollView.isScrollEnabled = scrollEnabled
        webView.scrollView.bounces = scrollEnabled
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = config.isLinkPreviewEnabled
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
    }

    private func load(_ webView: WKWebView, context: Context) {
        let defaultBase = Bundle.main.bundleURL
        let baseURL = config.baseURL ?? defaultBase
        let document = HTMLRichTextTemplate.document(
            content: html,
            config: config,
            isDark: colorScheme == .dark,
            containerWidth: Int(webView.bounds.width)
        )

        // 更新 scheme handler 的服务内容与资源根目录,再加载主文档。
        context.coordinator.schemeHandler.currentDocument = document
        context.coordinator.schemeHandler.baseURL = baseURL
        context.coordinator.schemeHandler.inlineImagesEnabled = config.inlineLocalImages
        let url = URL(string: "\(HTMLRichTextSchemeHandler.schemeName)://local\(HTMLRichTextSchemeHandler.indexPath)")!
        webView.load(URLRequest(url: url))
    }

    // MARK: - 渲染指纹

    /// 只有影响页面渲染结果的参数参与比较;纯粹的交互开关单独同步。
    private var renderKey: String {
        Self.renderFingerprint(html: html, config: config, colorScheme: colorScheme)
    }

    /// 内容指纹(也供 `HTMLRichTextHeightCache` 用作缓存 key):
    /// 文案 + 样式参数 + 深浅色任何一个影响渲染的变化都会改变指纹。
    static func renderFingerprint(html: String, config: HTMLRichTextConfig, colorScheme: ColorScheme) -> String {
        let isDark = colorScheme == .dark
        return [
            html,
            "font:\(config.fontSize)-\(config.lineHeight)-\(config.letterSpacing.map(String.init(describing:)) ?? "nil")",
            "color:\(HTMLRichTextTemplate.hexString(config.textColor, isDark: isDark))-\(HTMLRichTextTemplate.hexString(config.linkColor, isDark: isDark))-\(HTMLRichTextTemplate.hexString(config.backgroundColor, isDark: isDark))",
            "bg:\(config.isTransparent)",
            "family:\(config.fontFamily ?? "")",
            "align:\(config.textAlignment)",
            "css:\(config.customCSS ?? "")",
            "img:\(imageStyleKey(config.imageStyle, isDark: isDark))",
            "zoom:\(config.isZoomEnabled)-select:\(config.isTextSelectionEnabled)-callout:\(config.isTouchCalloutEnabled)",
            "base:\(config.baseURL?.absoluteString ?? "")",
            "inlineImg:\(config.inlineLocalImages)",
            "scheme:\(isDark ? "dark" : "light")"
        ].joined(separator: "|")
    }

    /// imageStyle 的字符串指纹(任意字段变化都触发重载,含交互开关 / 排布 / 装饰)。
    private static func imageStyleKey(_ style: HTMLRichTextImageStyle, isDark: Bool) -> String {
        let mode = style.contentMode.map { $0 == .fit ? "fit" : "fill" } ?? "nil"
        let align = style.alignment.map { "\($0)" } ?? "nil"
        let layout = style.layout.map { "\($0)" } ?? "nil"
        let vAlign = style.verticalAlignment.map { "\($0)" } ?? "nil"
        let margin = style.margin.map { m in
            [m.top, m.left, m.right, m.bottom].map { $0.map(String.init(describing:)) ?? "nil" }.joined(separator: ",")
        } ?? "nil"
        let background = style.backgroundColor.map { HTMLRichTextTemplate.hexString($0, isDark: isDark) } ?? "nil"
        let border = "\(style.borderWidth.map(String.init(describing:)) ?? "nil")-\(style.borderColor.map { HTMLRichTextTemplate.hexString($0, isDark: isDark) } ?? "nil")"
        let interaction = "\(style.isTapEnabled.map { $0 ? "tap" : "noTap" } ?? "nil")-\(style.isLongPressEnabled.map { $0 ? "lp" : "noLp" } ?? "nil")"
        return "\(style.maxWidth.map(String.init(describing:)) ?? "nil")-\(style.height.map(String.init(describing:)) ?? "nil")-\(style.cornerRadius.map(String.init(describing:)) ?? "nil")-\(mode)-\(align)-\(layout)-\(vAlign)-\(margin)-\(background)-\(border)-\(interaction)"
    }
}