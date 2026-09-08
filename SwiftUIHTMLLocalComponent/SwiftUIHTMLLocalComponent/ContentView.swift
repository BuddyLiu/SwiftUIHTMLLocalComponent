//
//  ContentView.swift
//  SwiftUIHTMLLocalComponent
//
//  演示页:多场景展示 HTMLRichText 的能力,顶部实时显示最近一次点击回调。
//

import SwiftUI

struct ContentView: View {

    @State private var lastTap: String = "点击下方链接或 data-tap 卡片试试 👇"
    @State private var lastState: String = "生命周期:—"

    var body: some View {
        VStack {
            tapBanner.id(0)
                .padding(.horizontal, 16)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SectionCard("1️⃣ 基础富文本") {
                            HTMLRichText(html: Self.basicHTML)
                        }
                        .id(1)
                        
                        SectionCard("2️⃣ 图文混排(相对路径本地图片)") {
                            HTMLRichText(
                                html: Self.imageHTML,
                                config: .init(baseURL: Self.resourceBaseURL())
                            )
                        }
                        .id(2)
                        
                        SectionCard("3️⃣ 点击交互:链接 + data-tap 自定义元素") {
                            HTMLRichText(html: Self.interactiveHTML, onTap:  { tap in
                                lastTap = Self.describe(tap)
                                print("点击回调: \(Self.describe(tap))")   // 便于演示日志观察
                            })
                        }
                        .id(3)
                        
                        SectionCard("4️⃣ 样式定制:字号 / 行高 / 颜色 / 自定义CSS") {
                            HTMLRichText(html: Self.styleHTML,
                                         config: .init(fontSize: 15, lineHeight: 1.6, textColor: .orange))
                            HTMLRichText(html: Self.styleHTML,
                                         config: .init(fontSize: 18, lineHeight: 2.1, textColor: .indigo,
                                                       linkColor: .pink, customCSS: "p strong{color:#E53935}"))
                            HTMLRichText(html: Self.styleHTML,
                                         config: .init(fontSize: 16, lineHeight: 1.8, letterSpacing: 1,
                                                       fontFamily: "Georgia, serif", textAlignment: .center))
                        }
                        .id(4)
                        
                        SectionCard("5️⃣ WebView 开关:长按选择 / 双指缩放") {
                            Text("· 允许长按:可选中文本、弹出预览与复制菜单")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HTMLRichText(html: Self.selectableHTML,
                                         config: .init(isTextSelectionEnabled: true,
                                                       isLinkPreviewEnabled: true,
                                                       isTouchCalloutEnabled: true))

                            Text("· 允许双指缩放")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            HTMLRichText(html: Self.zoomableHTML,
                                         config: .init(isZoomEnabled: true))
                        }
                        .id(5)
                        
                        SectionCard("6️⃣ 加载本地 HTML 文件(localHTMLNamed:)") {
                            HTMLRichText(localHTMLNamed: "sample-article", onTap: { tap in
                                lastTap = Self.describe(tap)
                                print("点击回调: \(Self.describe(tap))")   // 便于演示日志观察
                            })
                        }
                        .id(6)
                        
                        SectionCard("7️⃣ 纯文本 + 链式标记(linkItem / imageItem)") {
                            let text = "这是一段富文本，支持点击，不支持缩放。再说一次：这是一段富文本。\n能插入图片，控制图片的样式——同一段配置会替换所有出现支持点击和富文本。"
                            HTMLRichText(
                                content: text,
                                onTap: { tap in
                                    lastTap = Self.describe(tap)
                                    print("点击回调: \(Self.describe(tap))")   // 通用 onTap 与命中 action 并存
                                },
                                onStateChange: { state in
                                    // WebView 生命周期:loading → rendered → ready(高度) / failed(描述)
                                    lastState = "生命周期: \(Self.describe(state))"
                                    print("状态回调: \(Self.describe(state))")
                                }
                            )
                            .baseStyle(.init(fontSize: 16, imageStyle: .init(maxWidth: 240, cornerRadius: 10), baseURL: Self.resourceBaseURL()))
                            // 预估高度:加载完成前先把布局撑到约 180pt,收到 JS 真实测量(~187pt)后精修,
                            // 页面元素不会因为 WebView 内容渲染出来而跳动(.baseStyle 之后调用,避免被整份替换覆盖)。
                            .estimatedHeight(180)
                            // 加载占位:默认超过 1s 未完成才显示系统菊花,内容就绪后菊花淡出、内容淡入
                            .loadingSpinner()
                            .loadingPlaceholderDelay(1.0)
                            .linkItem("支持点击", link: "https://example.com/detail") { match in
                                print("支持点击 -> \(match)")
                            }
                            .linkItem("富文本", link: "https://example.com/rich", style: .underlined) { match in
                                print("富文本 -> \(match)")
                            }
                            .imageItem("能插入图片", localSource: "demo-banner.png", style: .rounded(24), action: { match in
                                print("能插入图片 -> \(match)")
                            })
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white)

                            Text("加载完成前内容隐藏、就绪后淡入;`loadingSpinner()`+`loadingPlaceholderDelay(1.0)`:1s 内完成就不闪菊花,慢加载才显示(可定制时长/自定义视图)。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(lastState)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .id(7)

                        SectionCard("8️⃣ 配套工具类 HTMLRichTextTools") {
                            let text = "用公共工具类估一个首帧高度交给 estimatedHeight,内容首次打开也不跳动。"
                            let config = HTMLRichTextConfig(
                                fontSize: 16,
                                textColor: HTMLRichTextTools.color(hex: "#37474F"),
                                linkColor: HTMLRichTextTools.color(hex: "#1565C0")
                            )
                            let estimate = HTMLRichTextTools.estimatedTextHeight(
                                text: text, config: config, containerWidth: 340
                            )
                            let css = HTMLRichTextTools.inlineCSS(for: .rounded(16))

                            HTMLRichText(
                                content: text,
                                estimatedHeight: estimate,
                                onTap: { lastTap = Self.describe($0) },
                                onStateChange: { state in
                                    if case .ready(let h) = state {
                                        lastState = "实测 \(Int(h))pt(预估 \(Int(estimate))pt)→ 平滑替换"
                                    }
                                }
                            )
                            .baseStyle(config)

                            Text("HTMLRichTextTools: 预估高度 \(Int(estimate))pt · color(hex:) 取色 · inlineCSS 生成「\(css)」")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .id(8)
                        SectionCard("9️⃣ 图片交互与样式细化(layout / 边距 / 背景 / 边框 / 长按)") {
                            let base = Self.resourceBaseURL()

                            Text("· 内联:大小 + 左右间距 + 垂直对齐(`vertical:`)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // 内联可配:大小(maxWidth/height)、左右与文字间距(marginLeft/marginRight)、垂直对齐(top/middle/bottom)
                            HTMLRichText(
                                content: "正文文字中插入一张内联图片:能插入图片继续跟文字排在同一行里。",
                                onTap: { lastTap = Self.describe($0) }
                            )
                            .baseStyle(.init(fontSize: 15, imageStyle: .init(maxWidth: 110), baseURL: base))
                            .imageItem("能插入图片", localSource: "demo-banner.png",
                                       style: .inline(vertical: .middle, marginLeft: 4, marginRight: 6),
                                       action: { _ in })

                            Text("· 块级居中 + 白底 / 边框 / 圆角(`.card`)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HTMLRichText(
                                content: "卡片图\n这是这张图片的解释文字。",
                                onTap: { lastTap = Self.describe($0) }
                            )
                            .baseStyle(.init(fontSize: 15, imageStyle: .init(maxWidth: 300), baseURL: base))
                            .imageItem("卡片图", localSource: "demo-banner.png", style: .card(alignment: .center, cornerRadius: 16), action:  { _ in })

                            Text("· 左浮动(`.floatLeft()`):文字环绕在图片右侧")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HTMLRichText(
                                content: "左浮动图这是一段足够长的说明文字,让它能在图片右侧环绕几行,直观看到浮动排布的效果;当文字超过图片高度之后,应自然回到图片下方继续排列,形成图文混排。",
                                onTap: { lastTap = Self.describe($0) }
                            )
                            .baseStyle(.init(fontSize: 15, imageStyle: .init(maxWidth: 120), baseURL: base))
                            .imageItem("左浮动图", localSource: "demo-banner.png", style: .floatLeft(), action: { _ in })

                            Text("· 点击禁用(`isTapEnabled = false`):纯展示,点了没有回调")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HTMLRichText(
                                content: "纯展示图 这只是一张展示图,点击不会触发任何回调。",
                                onTap: { lastTap = Self.describe($0) }
                            )
                            .baseStyle(.init(fontSize: 15, imageStyle: .init(maxWidth: 160), baseURL: base))
                            .imageItem("纯展示图", localSource: "demo-banner.png",
                                       style: .init(maxWidth: 160, cornerRadius: 8, isTapEnabled: false), action:  { _ in
                                // 点击已禁用,这里不会输出
                                print("tap 已禁用,不应触发")
                            })

                            Text("· 长按(`isLongPressEnabled = true` + `onLongPress:`):触发独立长按回调")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HTMLRichText(
                                content: "长按图 按住这张图片约半秒触发长按回调(点按的 action 不受影响)。",
                                onTap: { lastTap = Self.describe($0) }
                            )
                            .baseStyle(.init(fontSize: 15, baseURL: base))
                            .imageItem("长按图", localSource: "demo-banner.png",
                                       style: .init(maxWidth: 200, cornerRadius: 10,
                                                    backgroundColor: .red.opacity(0.12),
                                                    borderWidth: 2, borderColor: .orange,
                                                    isLongPressEnabled: true),
                                       onLongPress: { match in
                                           lastTap = "长按图片↦ \(match)"
                                           print("长按图片 -> \(match)")
                                       },
                                       action: { match in
                                           lastTap = "点击图片↦ \(match)"
                                           print("点击图片 -> \(match)")
                                       })

                            Text("· 快捷预设组合:`.bordered(.purple, width: 3, cornerRadius: 6)`")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HTMLRichText(
                                content: "快捷图",
                                onTap: { lastTap = Self.describe($0) }
                            )
                            .baseStyle(.init(fontSize: 15, baseURL: base))
                            .imageItem("快捷图", localSource: "demo-banner.png",
                                       style: .bordered(.purple, width: 3, cornerRadius: 6), action:  { _ in })
                        }
                        .id(9)

                        SectionCard("🔟 预估高度收身 / 高度缓存") {
                            Text("内容 **比预估高度小** 时,就绪后按实际内容高度展示;同一内容再次出现会复用缓存高度,首帧不塌缩。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HTMLRichText(
                                content: "短的正文。",
                                estimatedHeight: 180,
                                onTap: { lastTap = Self.describe($0) },
                                onStateChange: { state in
                                    if case .ready(let h) = state {
                                        print("收身演示 ready(\(Int(h))pt)")
                                    }
                                }
                            )
                            .baseStyle(.init(fontSize: 15, baseURL: Self.resourceBaseURL()))
                        }
                        .id(10)

                        SectionCard("1️⃣1️⃣ 背景样式:毛玻璃 / 纯色") {
                            Text("· 毛玻璃(`backgroundStyle: .frosted`):WebView 保持透明,`backdrop-filter` 把背后的宿主内容模糊透出")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ZStack(alignment: .topLeading) {
                                // 彩色宿主:毛玻璃透过它演示模糊与色调(硬边色块让模糊一目了然)
                                LinearGradient(
                                    colors: [.orange, .pink, .purple, .indigo],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Circle().fill(.yellow).frame(width: 56, height: 56).offset(x: 232, y: 14)
                                Circle().fill(.blue).frame(width: 40, height: 40).offset(x: 34, y: 86)
                                Circle().fill(.green).frame(width: 64, height: 64).offset(x: 178, y: 92)
                                HTMLRichText(
                                    content: "毛玻璃段落:背景把渐变模糊透出来,文字保持清晰。可调 blurRadius / tintColor / tintOpacity / saturationAmount,也可用 .card() / .darkCard() 预设。"
                                )
                                // 背景样式走 .baseStyle(config) 注入(纯文本入口的 config 由链式样式整体替换)
                                .baseStyle(.init(backgroundStyle: .frosted(.init(blurRadius: 16, tintColor: .white, tintOpacity: 0.4, saturationAmount: 1.6))))
                                .padding(12)
                            }
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("· 纯色(`backgroundStyle: .solid`):铺一块颜色,透明度会写进 CSS")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            HTMLRichText(
                                content: "纯色背景段落:backgroundStyle = .solid(teal 25%),半透明也能生效。"
                            )
                            .baseStyle(.init(backgroundStyle: .solid(.teal.opacity(0.25))))
                            .padding(12)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .id(11)
                    }
                    .padding(16)
                }
                .task {
                    // 演示辅助:启动时可通过环境变量 HRT_SCROLL=4 快速定位到指定小节
                    if let raw = ProcessInfo.processInfo.environment["HRT_SCROLL"],
                       let index = Int(raw) {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(index, anchor: .top)
                        }
                    }
                }
            }   // end ScrollViewReader
        }
    }

    // MARK: - 顶部点击回调横幅

    private var tapBanner: some View {
        Text(lastTap)
            .font(.footnote.monospaced())
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.12))
            )
    }

    // MARK: - 场景文案

    private static let basicHTML = """
    <h3>用 WebView 承载富文本</h3>
    <p>\u{201C}SwiftUI 原生 <code>Text</code>\u{201D} 的富文本能力有限,这里用
    <b>WKWebView</b> 加载本地 HTML,把 <span style="color:#E53935">颜色</span>、
    <span style="font-size:22px">字号</span>、行高、图文混排的能力带回来。</p>
    <ul>
      <li>列表 <b>加粗</b></li>
      <li>列表 <i>斜体</i></li>
      <li>列表 <u>下划线</u></li>
    </ul>
    <blockquote>引用块:背景、边框、圆角都可以通过 customCSS 自定义。</blockquote>
    """

    private static let imageHTML = """
    <p>下面这张图是 bundle 内的 <code>demo-banner.png</code>,通过相对路径加载,无需网络:</p>
    <img src="demo-banner.png" alt="本地示例图">
    <p>图片默认 <code>max-width:100%; height:auto</code>,随容器宽度自适应。</p>
    """

    private static let interactiveHTML = """
    <p>1️⃣ 常规链接:<a href="https://example.com/doc/123">查看文档</a> ——
    点击不会跳转,只触发回调。</p>
    <div data-tap data-type="goods" data-id="10086" data-name="示例商品"
         style="background:#EEF2FF;border:1px solid #C7D2FE;border-radius:10px;padding:12px;margin:12px 0;">
      <b>🛍 可点击卡片</b>
      <div style="color:#6366F1;margin-top:4px">data-type=goods · data-id=10086 → 点击试试</div>
    </div>
    <p>点击上面的卡片,顶部回调横幅会展示它携带的 <code>data-*</code> 属性。</p>
    """

    private static let styleHTML = "<p><strong>加粗强调</strong> <b>加粗</b> <i>斜体</i>,<a href=\"https://example.com\">链接</a>,普通文本。</p>"

    private static let selectableHTML = """
    <p>这段开启了<b>长按能力</b>:可以<a href="https://example.com">长按链接预览</a>,
    长按文字选中复制。默认全部关闭。</p>
    """

    private static let zoomableHTML = """
    <p>这段开启了<b>双指缩放</b>:<code>isZoomEnabled = true</code>,默认关闭。</p>
    <p style="font-size:26px;color:#7C3AED">双指捏合或双击,把文字放大看看。🔍</p>
    """

    // MARK: - 工具

    /// 在 bundle 根目录或 Resources/ 子目录中宽容定位本地资源目录。
    private static func resourceBaseURL() -> URL? {
        let bundle = Bundle.main
        if bundle.url(forResource: "demo-banner", withExtension: "png") != nil {
            return bundle.bundleURL
        }
        if bundle.url(forResource: "demo-banner", withExtension: "png", subdirectory: "Resources") != nil {
            return bundle.bundleURL.appendingPathComponent("Resources")
        }
        return bundle.bundleURL
    }

    private static func describe(_ state: HTMLRichTextWebState) -> String {
        switch state {
        case .loading: return "loading(开始加载)"
        case .rendered: return "rendered(渲染完成)"
        case .ready(let h): return "ready(高度 \(Int(h))pt)"
        case .failed(let e): return "failed(\(e))"
        }
    }

    private static func describe(_ tap: HTMLTapContext) -> String {
        if let url = tap.url {
            return "链接 ↦ \(url.absoluteString)"
        }
        let id = tap.elementID.map { "#\($0)" } ?? ""
        let data = tap.dataAttributes
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: " ")
        let tag = tap.tagName ?? ""
        return "元素: <\(tag)\(id)>\(data.isEmpty ? "" : " · \(data)")"
    }
}

// MARK: - 分组卡片

private struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    ContentView()
}
