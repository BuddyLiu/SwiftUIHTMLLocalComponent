//
//  HTMLRichTextConfig.swift
//  SwiftUIHTMLLocalComponent
//
//  组件全部可配置参数。所有字段均有默认值,通常只需设置关心的少数几个。
//

import SwiftUI

/// `HTMLRichText` 的可配置参数模型。
///
/// 用法:
/// ```
/// var config = HTMLRichTextConfig()
/// config.fontSize = 16
/// config.lineHeight = 1.8
/// config.linkColor = .orange
/// ```
public struct HTMLRichTextConfig {

    // MARK: - 内容样式

    /// 基础字号(CSS px),默认 17。
    public var fontSize: CGFloat = 17

    /// 行高(单位倍数,对应 CSS `line-height`),默认 1.6。
    public var lineHeight: CGFloat = 1.6

    /// 字间距(CSS px),nil 表示不额外设置。
    public var letterSpacing: CGFloat? = nil

    /// 基础文字颜色,默认 label(自动适配深色模式)。
    public var textColor: Color = Color(uiColor: .label)

    /// 链接颜色,默认 `.blue`。
    public var linkColor: Color = .blue

    /// 背景颜色,仅当 `isTransparent == false` 时生效。
    public var backgroundColor: Color = .clear

    /// 字体族,如 `"PingFang SC, sans-serif"`;nil 使用系统默认字体栈。
    public var fontFamily: String? = nil

    /// 基础文本对齐方式,默认左对齐。
    public var textAlignment: TextAlignment = .leading

    /// 追加注入的自定义 CSS 规则(可写任意 CSS,如 `.box { ... }`)。
    public var customCSS: String? = nil

    /// 文档内图片的全局默认样式(链式入口 `.imageItem(style:)` 可单段覆盖个别字段)。
    public var imageStyle: HTMLRichTextImageStyle = .default

    /// 是否透明背景无缝隙嵌入 SwiftUI,默认 true。
    public var isTransparent: Bool = true

    // MARK: - 加载体验

    /// 首帧预估高度(pt):WebView 加载完成前先用它撑起布局,避免「先塌缩成 0 →
    /// 再跳变到真实高度」的闪烁风险。收到 JS 真实测量后会自动替换为精确高度;
    /// 若未设置但历史缓存命中(同内容 + 同容器宽度),同样会直接复用缓存高度。
    public var estimatedHeight: CGFloat? = nil

    // MARK: - WebView 交互开关(默认全部关闭:不可长按 / 缩放)

    /// 是否允许双指缩放。默认 false(通过 viewport meta 禁用)。
    public var isZoomEnabled: Bool = false

    /// 是否允许选中文本(长按出现光标 / 选择菜单)。默认 false。
    public var isTextSelectionEnabled: Bool = false

    /// 是否允许长按链接弹出预览(Peek & Pop)。默认 false。
    public var isLinkPreviewEnabled: Bool = false

    /// 是否允许长按弹出系统菜单(复制 / 共享按钮,即 `-webkit-touch-callout`)。默认 false。
    public var isTouchCalloutEnabled: Bool = false

    // MARK: - 其它

    /// 用于解析相对路径本地资源(如图片)的 base URL,默认 `Bundle.main.bundleURL`。
    public var baseURL: URL? = nil

    /// 是否把文档内指向本地文件的 `<img src>` 内联成 `data:` URI(默认 true)。
    /// 内联后图片不经过 webview 的子资源请求链路,可彻底规避 WebKit 偶发丢
    /// 子资源请求导致的图片加载不出现象;代价是 HTML 字节数约放大 1.33 倍。
    /// 仅指向 baseURL 下真实存在的本地文件才内联,网络地址 / data: / blob: 不受影响。
    public var inlineLocalImages: Bool = true

    /// 强制按指定深浅色取色;nil 跟随系统。
    public var preferredColorScheme: ColorScheme? = nil

    public init() {}

    /// 全参数构造函数,可只传关心的字段。
    public init(
        fontSize: CGFloat = 17,
        lineHeight: CGFloat = 1.6,
        letterSpacing: CGFloat? = nil,
        textColor: Color = Color(uiColor: .label),
        linkColor: Color = .blue,
        backgroundColor: Color = .clear,
        fontFamily: String? = nil,
        textAlignment: TextAlignment = .leading,
        customCSS: String? = nil,
        imageStyle: HTMLRichTextImageStyle = .default,
        isTransparent: Bool = true,
        isZoomEnabled: Bool = false,
        isTextSelectionEnabled: Bool = false,
        isLinkPreviewEnabled: Bool = false,
        isTouchCalloutEnabled: Bool = false,
        baseURL: URL? = nil,
        inlineLocalImages: Bool = true,
        preferredColorScheme: ColorScheme? = nil,
        estimatedHeight: CGFloat? = nil
    ) {
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
        self.textColor = textColor
        self.linkColor = linkColor
        self.backgroundColor = backgroundColor
        self.fontFamily = fontFamily
        self.textAlignment = textAlignment
        self.customCSS = customCSS
        self.imageStyle = imageStyle
        self.isTransparent = isTransparent
        self.isZoomEnabled = isZoomEnabled
        self.isTextSelectionEnabled = isTextSelectionEnabled
        self.isLinkPreviewEnabled = isLinkPreviewEnabled
        self.isTouchCalloutEnabled = isTouchCalloutEnabled
        self.baseURL = baseURL
        self.inlineLocalImages = inlineLocalImages
        self.preferredColorScheme = preferredColorScheme
        self.estimatedHeight = estimatedHeight
    }
}