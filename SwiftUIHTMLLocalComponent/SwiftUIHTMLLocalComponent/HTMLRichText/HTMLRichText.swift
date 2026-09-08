//
//  HTMLRichText.swift
//  SwiftUIHTMLLocalComponent
//
//  对外 SwiftUI 组件。两套入口:
//  1. `html:` / `localHTMLNamed:` —— 直接传 HTML 源码或本地 HTML 文件;
//  2. 纯文本 + 链式修饰 —— 传普通文本,再用 `.baseStyle / .linkItem / .imageItem`
//     声明式地标记样式与可点击片段,组件内部编译成 HTML。
//

import SwiftUI

/// 用本地 `WKWebView` 承载 HTML 的富文本 SwiftUI 组件。
///
/// 特点:
/// - 样式多样性来自 CSS,弥补 SwiftUI 原生富文本的不足;
/// - 高度自适应:内容多高,组件就多高(默认关闭 WebView 内滚动,由外层滚动);
/// - 长按 / 滑动 / 双指缩放默认全部关闭,可通过配置开启;
/// - 支持点击回调:`<a href>` 与带 `data-tap` 的元素。
///
/// ## 纯文本 + 链式标记(推荐)
/// ```swift
/// HTMLRichText(content: "这是一段富文本，支持点击。")
///     .baseStyle(.init(fontSize: 16, lineHeight: 1.7, linkColor: .orange))
///     .linkItem("支持点击", link: "https://example.com") { match in
///         print(match)   // 点击「支持点击」时触发
///     }
///     .imageItem("插入图片", localSource: "demo.png",
///                style: .init(maxWidth: 240, cornerRadius: 8)) { match in
///         print(match)   // 点击图片时触发
///     }
/// ```
///
/// ## HTML 入口(底层)
/// ```swift
/// HTMLRichText(html: "<p>Hello <b>World</b></p>",
///              config: .init(fontSize: 16, linkColor: .orange)) { tap in
///     print(tap.url ?? tap.dataAttributes)
/// }
/// ```
public struct HTMLRichText: View {

    // MARK: - 存储状态

    /// 原始输入:完整 HTML(isRawHTML == true)或纯文本(声明式)。
    private let rawContent: String
    /// true 时 rawContent 原样作为文档内容;false 时按 items 编译成 HTML。
    private let isRawHTML: Bool
    /// 声明式标记(链式 `.linkItem` / `.imageItem` 逐个追加)。
    private var items: [HTMLRichTextItem]
    /// 全局配置(链式 `.baseStyle` 替换)。
    private var config: HTMLRichTextConfig
    /// 通用点击回调,与命中标记的 action 并存。
    private let userOnTap: (HTMLTapContext) -> Void
    /// WebView 生命周期回调(loading / rendered / ready(height) / failed)。
    private let onStateChange: (HTMLRichTextWebState) -> Void

    /// 当前内容高度:先用「预估高度/缓存高度」撑起首帧,收到 JS 真实测量后更新。
    @State private var contentHeight: CGFloat = 0
    /// 内容是否已就绪(收到首个有效高度):就绪前隐藏内容,就绪后淡入显示。
    @State private var isContentReady = false
    /// 是否处于加载中(loading → ready/failed 之间置真)。
    @State private var isLoading = false
    /// 加载占位是否已到点显示:延迟期内为 false,超过 delay 仍未完成才显示。
    @State private var isPlaceholderShown = false
    /// 可选的加载占位视图;nil = 不显示占位(默认)。
    private var loadingHint: (() -> AnyView)?
    /// 占位延迟时长(秒):加载很快时不闪占位,超过该时长仍未完成才显示。
    private var placeholderDelay: TimeInterval = 1.0
    @Environment(\.colorScheme) private var systemScheme

    // MARK: - 入口

    /// 直接传 HTML 源码(底层入口,样式完全由 HTML/CSS 决定)。
    ///
    /// - Parameter onStateChange: WebView 生命周期回调(可选):`.loading` 开始加载、
    ///   `.rendered` 文档渲染完成、`.ready(高度)` 首个有效高度回传、`.failed(描述)` 加载失败。
    public init(
        html: String,
        config: HTMLRichTextConfig = .init(),
        onTap: @escaping (HTMLTapContext) -> Void = { _ in },
        onStateChange: @escaping (HTMLRichTextWebState) -> Void = { _ in }
    ) {
        self.rawContent = html
        self.isRawHTML = true
        self.items = []
        self.config = config
        self.userOnTap = onTap
        self.onStateChange = onStateChange
        // 用预估高度作为首帧高度,WebView 加载完成前先把位置撑起来(避免塌缩闪烁)
        self._contentHeight = State(initialValue: config.estimatedHeight ?? 0)
    }

    /// 传一段**普通文本** + `config`(样式全部由 `.baseStyle` 链式配置)。
    /// 文本会自动做 HTML 转义,可点击 / 插图区域用链式 `.linkItem` / `.imageItem` 标记。
    ///
    /// - Parameter content: 正文纯文本(无需手写 `<a>` / `<img>` 等标签)。
    /// - Parameter estimatedHeight: 可选的首帧预估高度,加载完成前先把位置撑起来(默认 nil,命中历史缓存也会自动复用)。
    /// - Parameter onTap: 通用点击回调;被标记命中时与该段 action 一并触发。
    /// - Parameter onStateChange: WebView 生命周期回调(可选)。
    public init(
        content: String,
        estimatedHeight: CGFloat? = nil,
        onTap: @escaping (HTMLTapContext) -> Void = { _ in },
        onStateChange: @escaping (HTMLRichTextWebState) -> Void = { _ in }
    ) {
        self.rawContent = content
        self.isRawHTML = false
        self.items = []
        self.config = .init()
        self.userOnTap = onTap
        self.onStateChange = onStateChange
        self._contentHeight = State(initialValue: estimatedHeight ?? 0)
    }

    /// 直接加载 App 资源里的本地 `.html` 文件进行渲染。
    /// 文件可放在 bundle 根目录或 `Resources/` 子目录,内部会宽容查找。
    public init?(
        localHTMLNamed name: String,
        in bundle: Bundle = .main,
        config: HTMLRichTextConfig = .init(),
        onTap: @escaping (HTMLTapContext) -> Void = { _ in },
        onStateChange: @escaping (HTMLRichTextWebState) -> Void = { _ in }
    ) {
        guard let url = Self.locateLocalHTML(name, in: bundle),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        self.init(html: content, config: config, onTap: onTap, onStateChange: onStateChange)
    }

    // MARK: - 链式修饰

    /// 设置基础样式与配置(整份替换默认 `HTMLRichTextConfig`),作用于全部内容。
    /// 图片/链接等单段样式可以再用 `.imageItem(style:)` / `.linkItem(style:)` 覆盖。
    public func baseStyle(_ config: HTMLRichTextConfig) -> HTMLRichText {
        var copy = self
        copy.config = config
        return copy
    }

    /// 设置**首帧预估高度**:WebView 加载完成前先把布局撑到指定高度,
    /// 收到 JS 真实测量后自动替换,避免「先塌成 0、内容渲染出来后再跳到真实高度」的跳动。
    /// 配合高度缓存,首次打开 / 列表复用时界面元素不再因为 WebView 加载过程而移位。
    ///
    /// - Parameter height: 预估高度(pt);传 `nil` 表示不加预估(跟随历史缓存)。
    /// - Note: `.baseStyle` 会**整份替换** `HTMLRichTextConfig`(`estimatedHeight` 是其中一个字段),
    ///   若同时使用请把 `.estimatedHeight` 放在 `.baseStyle` **之后**,否则会被覆盖。
    public func estimatedHeight(_ height: CGFloat?) -> HTMLRichText {
        var copy = self
        copy.config.estimatedHeight = height
        // 内容尚未加载出真实高度时,直接把预估高度作为当前展示高度
        if copy.contentHeight == 0, let height = height {
            copy._contentHeight = State(initialValue: height)
        }
        return copy
    }

    /// 加载期间显示**系统默认菊花**(`ProgressView`)占位。
    /// 内容就绪(收到首个有效高度)后占位淡出、内容淡入,两者交错过渡;
    /// 需要完全自定义占位时改用 `.loadingPlaceholder`.
    public func loadingSpinner() -> HTMLRichText {
        var copy = self
        copy.loadingHint = { AnyView(ProgressView()) }
        return copy
    }

    /// **完全自定义**的加载占位视图:加载期间居中显示,内容就绪后淡出。
    /// 默认不显示任何占位;调用后在 `loading → ready` 期间把该视图叠加在内容位置上,
    /// 可自由组合文字 / 动画 / 进度条等任意 SwiftUI 视图。
    ///
    /// ```swift
    /// HTMLRichText(content: "……")
    ///     .loadingPlaceholder {
    ///         VStack(spacing: 8) {
    ///             ProgressView()
    ///             Text("加载中…").font(.caption).foregroundStyle(.secondary)
    ///         }
    ///     }
    /// ```
    public func loadingPlaceholder<Placeholder: View>(
        @ViewBuilder _ content: @escaping () -> Placeholder
    ) -> HTMLRichText {
        var copy = self
        copy.loadingHint = { AnyView(content()) }
        return copy
    }

    /// 设置加载占位的**延迟显示时长**(秒,默认 1.0):加载很快(例如本地 scheme 几十毫秒)
    /// 时不等它闪烁,超过该时长仍未就绪才显示占位。0 = 立即显示。
    ///
    /// 与 `.loadingSpinner()` / `.loadingPlaceholder {}` 配合使用:
    /// ```swift
    /// HTMLRichText(content: "……")
    ///     .loadingSpinner()
    ///     .loadingPlaceholderDelay(2.0)   // 超过 2s 未完成才显示菊花
    /// ```
    public func loadingPlaceholderDelay(_ seconds: TimeInterval) -> HTMLRichText {
        var copy = self
        copy.placeholderDelay = max(0, seconds)
        return copy
    }

    /// 把匹配文本标记为**可点击链接**:正文里每出现一次就替换成一条链接,
    /// 点击不跳转页面,触发该段 `action`(参数为匹配文本)。
    ///
    /// - Parameter match: 正文中要命中的文本(普通子串匹配,非正则)。
    /// - Parameter link: 点击回调携带的链接地址。
    /// - Parameter style: 单段链接样式(覆盖全局 `linkColor`),nil = 用全局。
    /// - Parameter action: 点击回调,接收匹配文本。
    public func linkItem(
        _ match: String,
        link: String,
        style: HTMLRichTextLinkStyle? = nil,
        action: @escaping (String) -> Void = { _ in }
    ) -> HTMLRichText {
        var copy = self
        copy.items.append(.click(match: match, link: link, style: style, action: action))
        return copy
    }

    /// 把匹配文本标记为**本地图片**:正文里每出现一次就替换成一张图片。
    /// 默认点击图片触发该段 `action`(参数为匹配文本);可通过 `style.isTapEnabled = false` 关闭点击,
    /// 或 `style.isLongPressEnabled = true` 开启长按(需同时传 `onLongPress`,长按与点按回调相互独立)。
    ///
    /// - Parameter match: 正文中要命中的文本。
    /// - Parameter localSource: 本地图片资源名(相对 `config.baseURL` 解析)。
    /// - Parameter style: 单段图片样式,未覆盖的字段沿用全局 `config.imageStyle`;
    ///   排布 / 外边距 / 背景 / 阴影 / 边框 / 点击长按开关都在这里配置。
    /// - Parameter onLongPress: 可选的长按回调;传了以后记得在 `style` 里开启 `isLongPressEnabled`。
    /// - Parameter action: 点击回调,接收匹配文本(放在最后便于直接尾随闭包)。
    public func imageItem(
        _ match: String,
        localSource: String,
        style: HTMLRichTextImageStyle? = nil,
        onLongPress: ((String) -> Void)? = nil,
        action: @escaping (String) -> Void = { _ in }
    ) -> HTMLRichText {
        var copy = self
        copy.items.append(.picture(match: match, localSource: localSource, style: style,
                                   action: action, onLongPress: onLongPress))
        return copy
    }

    // MARK: - Body

    public var body: some View {
        let scheme = config.preferredColorScheme ?? systemScheme
        let html = finalHTML(isDark: scheme == .dark)
        return GeometryReader { proxy in
            let widthPx = Int(proxy.size.width)
            // 内容指纹同时用作高度缓存 key:同内容 + 同宽度直接复用上次的最终高度
            let fingerprint = HTMLRichTextView.renderFingerprint(html: html, config: config, colorScheme: scheme)
            // 展示高度:
            // - 外层不限高(自由高度)→ proxy 给到的可用高度即内容高度,直接用内容高度;
            // - 外层给了更小高度(固定高度容器,如 .frame(height: 140))→ 按容器高度收进来,
            //   超出的部分直接裁切(内部滚动仅由 config.isScrollEnabled 控制,不再自动开启)。
            let availableHeight = proxy.size.height
            let displayHeight = max(0, availableHeight > 1 ? min(contentHeight, availableHeight) : contentHeight)
            HTMLRichTextView(
                html: html,
                config: config,
                colorScheme: scheme,
                onHeightChange: { height in
                    contentHeight = height
                    // 把最终高度写回缓存,列表复用 / 来回切换的同内容实例不再经历塌缩
                    HTMLRichTextHeightCache.set(height, key: fingerprint, width: widthPx)
                },
                onTap: forwardedTap,
                onLongPress: forwardedLongPress,
                onStateChange: { state in
                    // 就绪状态机:loading → rendered → ready / failed。
                    // 内容渐显由文档内部完成(见 Template:CSS body opacity + JS .hrt-visible),
                    // 这里只负责占位显示时机与把状态回调给上层。
                    switch state {
                    case .loading:
                        isLoading = true
                        isContentReady = false
                        isPlaceholderShown = false   // 重载时重新计延迟
                    case .rendered:
                        isContentReady = false        // 渲染完成但高度未回传,仍算加载中
                        isLoading = true
                    case .ready, .failed:
                        isLoading = false
                        isContentReady = true
                        isPlaceholderShown = false
                    }
                    onStateChange(state)
                }
            )
            // 宽度用"紧约束"(proxy 的实际宽度)而不是 maxWidth:.infinity:
            // WKWebView 会把滚动内容尺寸当作 intrinsicContentSize,一旦宽度可伸缩,
            // 会陷入"文档宽度→布局宽度"的反馈循环,导致高度暴涨(可达 33M px)。
            .frame(width: proxy.size.width, height: displayHeight, alignment: .top)
            // 注意:不要在 WebView 所在视图上做 SwiftUI 的 .opacity 动画 —— 那会扰动
            // WKWebView 远程合成层,表现为「图片已画出(takeSnapshot 生效),但淡入动画
            // 进行到一半又消失」。内容淡入已移到文档内部(CSS body.opacity:0 → JS 加
            // .hrt-visible 渐变 0.3s),WebView 视图本身保持 opacity:1,不做透明度动画。
            .overlay {
                // 可选加载占位:默认系统菊花(.loadingSpinner)或完全自定义(.loadingPlaceholder);
                // 只在「超过延迟时长仍未就绪」时显示,加载快(默认 <1s)则不闪占位。
                if isPlaceholderShown, !isContentReady, let hint = loadingHint {
                    hint()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: isPlaceholderShown)
            .task(id: isLoading) {
                // 占位延时上报视图:延迟结束后若仍在加载,才放行占位显示;
                // 中途就绪/失败/重载会导致 id 变化,任务被取消,天然不会闪花。
                guard isLoading, loadingHint != nil else { return }
                let nanoseconds = UInt64(max(0, placeholderDelay) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled, isLoading else { return }
                isPlaceholderShown = true
            }
            .onAppear {
                // 首次挂载且没有预估高度时,用历史缓存高度撑起首帧,避免「先塌成 0 再跳变」
                if contentHeight == 0,
                   let cached = HTMLRichTextHeightCache.height(for: fingerprint, width: widthPx) {
                    contentHeight = cached
                }
            }
        }
        // 高度只设「上限 + 理想」、不再写死,让外层容器的高度约束能流进来:
        // · 外层自由(ScrollView / VStack 不限高)→ 按 idealHeight = 内容高度报告,组件高度 = 内容高度;
        // · 外层给了更小高度(固定高度容器)→ 渲染成容器给的高度,内容多出的部分裁切掉
        //   (要内部滚动需显式 config.isScrollEnabled = true)。
        .frame(minHeight: 0, idealHeight: contentHeight, maxHeight: max(contentHeight, 0))
    }

    /// 最终交给 WebView 的 HTML:HTML 入口原样使用;声明式入口把纯文本 + items 编译。
    private func finalHTML(isDark: Bool) -> String {
        guard !isRawHTML else { return rawContent }
        return HTMLRichTextContentComposer.compose(text: rawContent, items: items, config: config, isDark: isDark)
    }

    /// 命中标记时先触发该段 `action`,再走通用 `onTap`(两者并存)。
    private var forwardedTap: (HTMLTapContext) -> Void {
        { tap in
            if let index = tap.dataAttributes["tap-index"].flatMap(Int.init),
               items.indices.contains(index) {
                let item = items[index]
                item.action(item.match)
            }
            userOnTap(tap)
        }
    }

    /// 长按转发:长按只触发命中图片段自己的 `onLongPress`(与点按的 action / onTap 相互独立);
    /// 没有任何图片段声明长按回调时返回 nil,JS 侧不再挂长按监听。
    private var forwardedLongPress: ((HTMLTapContext) -> Void)? {
        let hasSectionLongPress = items.contains { $0.onLongPress != nil }
        guard hasSectionLongPress else { return nil }
        return { tap in
            if let index = tap.dataAttributes["tap-index"].flatMap(Int.init),
               items.indices.contains(index) {
                items[index].onLongPress?(items[index].match)
            }
        }
    }

    // MARK: - 本地文件查找

    /// 宽容查找本地 html:bundle 根目录 → `Resources/` 子目录 → 显式 path 拼接。
    private static func locateLocalHTML(_ name: String, in bundle: Bundle) -> URL? {
        let withoutExt = (name as NSString).deletingPathExtension

        if let url = bundle.url(forResource: withoutExt, withExtension: "html") {
            return url
        }
        if let url = bundle.url(forResource: withoutExt, withExtension: "html", subdirectory: "Resources") {
            return url
        }

        let candidates = [
            bundle.bundleURL.appendingPathComponent("Resources").appendingPathComponent(withoutExt + ".html"),
            bundle.bundleURL.appendingPathComponent(withoutExt + ".html")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}