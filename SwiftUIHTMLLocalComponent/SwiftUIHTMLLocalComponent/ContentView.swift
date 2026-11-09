//
//  ContentView.swift
//  SwiftUIHTMLLocalComponent
//
//  演示页:多场景展示 HTMLRichText 的能力,顶部实时显示最近一次点击回调。
//

import SwiftUI
import Combine

struct ContentView: View {

    @State private var lastTap: String = "点击下方链接或 data-tap 卡片试试 👇"
    @State private var lastState: String = "生命周期:—"
    @State private var autoDetailIndex: Int?

    var body: some View {
        NavigationView { demoContent }
            .overlay { FrostedGlassHost() }
    }

    /// 演示主体:滚动展示各小节;毛玻璃样式库(第 15 小节)点行跳转子页,
    /// 玻璃由 body 里的全局宿主统一渲染(同一时刻最多一块)。
    private var demoContent: some View {
        VStack {
//            tapBanner.id(0)
//                .padding(.horizontal, 16)
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
                            Text("· 毛玻璃(`backgroundStyle: .frosted`):WebView 保持透明,`backdrop-filter` 把背后的宿主内容模糊透出;预设 `.light()` / `.dark()` / `.gradient()` / `.fallback()` 覆盖浅色 / 深色 / 渐变 / 轻量四档,另有系统材质档 `.regularMaterial()` 等(对应 `Material` / `UIBlurEffect`)")
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
                                    content: "渐变毛玻璃(.gradient()):对角高光 + 高饱和,彩色宿主上最「透亮」。文字边缘用 contentPadding: 12 内缩。"
                                )
                                // 背景样式走 .baseStyle(config) 注入(纯文本入口的 config 由链式样式整体替换)。
                                // 玻璃铺满整卡,文字与玻璃边缘之间的内边距由 contentPadding 配置(默认 0)。
                                // 上边缘光挂在 html 上,恒对齐组件顶部;圆角由宿主 .clipShape 负责(毛玻璃块本身不做圆角)。
                                .baseStyle(.init(contentPadding: 12, backgroundStyle: .frosted(.gradient())))
                            }
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("· 渐变色调(`tintColors` + `tintDirection`):多色底色按方向生成渐变,默认单色路径输出不变")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            ZStack(alignment: .topLeading) {
                                LinearGradient(
                                    colors: [.indigo, .blue, .cyan],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Circle().fill(.orange).frame(width: 60, height: 60).offset(x: 24, y: 16)
                                Circle().fill(.pink).frame(width: 44, height: 44).offset(x: 210, y: 80)
                                Circle().fill(.yellow).frame(width: 52, height: 52).offset(x: 120, y: 30)
                                HTMLRichText(
                                    content: "渐变色调(radial):tintColors = [青, 紫, 橙] 中心放射,彩色宿主上底色自带过渡。"
                                )
                                .baseStyle(.init(
                                    contentPadding: 12,
                                    backgroundStyle: .frosted(.init(
                                        tintColors: [.cyan, .purple, .orange],
                                        tintDirection: .radial,
                                        tintOpacity: 0.16
                                    ))
                                ))
                            }
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 8)

                            ZStack(alignment: .topLeading) {
                                // 深色宿主:暗黑界面上的毛玻璃
                                LinearGradient(
                                    colors: [.black, .gray.opacity(0.6), .purple.opacity(0.8)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Circle().fill(.indigo).frame(width: 70, height: 70).offset(x: 210, y: 12)
                                Circle().fill(.pink).frame(width: 46, height: 46).offset(x: 40, y: 96)
                                HTMLRichText(
                                    content: "深色毛玻璃(.dark()):近黑基调,夜间模式 / 深色界面的常配。"
                                )
                                .baseStyle(.init(backgroundStyle: .frosted(.dark())))
                                .padding(12)
                            }
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 8)

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

                        SectionCard("1️⃣2️⃣ 无文本毛玻璃视图(HTMLRichTextFrostedView)") {
                            Text("SwiftUI 原生 `.ultraThinMaterial` 等模糊不可调;`HTMLRichTextFrostedView` 复用 backdrop-filter 链路,模糊半径 / 饱和度 / 色调渐变 / 高光全可调。预设也有系统材质档(`.thinMaterial()` / `.regularMaterial()` 等,对应 `Material` / `UIBlurEffect`)。玻璃铺满宿主给的 frame,圆角由宿主 .clipShape 负责。")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ZStack(alignment: .topLeading) {
                                LinearGradient(
                                    colors: [.pink, .orange, .yellow, .green],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Circle().fill(.purple).frame(width: 70, height: 70).offset(x: 210, y: 8)
                                Circle().fill(.blue).frame(width: 46, height: 46).offset(x: 30, y: 84)
                                HTMLRichTextFrostedView(style: .light())
                                    .overlay(alignment: .center) {
                                        Text(".light():blur(20) saturate(1.8),白基盖在浅色宿主上")
                                            .font(.caption2)
                                            .foregroundStyle(.black.opacity(0.6))
                                            .padding(10)
                                    }
                            }
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            ZStack(alignment: .topLeading) {
                                LinearGradient(
                                    colors: [.black, .gray.opacity(0.7), .purple.opacity(0.9)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Circle().fill(.pink).frame(width: 60, height: 60).offset(x: 210, y: 10)
                                Circle().fill(.cyan).frame(width: 44, height: 44).offset(x: 40, y: 90)
                                HTMLRichTextFrostedView(
                                    style: .init(
                                        tintColors: [.blue, .purple],
                                        tintDirection: .topTrailingToBottomLeading,
                                        tintOpacity: 0.18
                                    )
                                )
                                .overlay(alignment: .center) {
                                    Text("渐变色调 .topTrailingToBottomLeading(右上→左下) · 深色宿主")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.85))
                                        .padding(10)
                                }
                            }
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.top, 8)

                            Text("· 大半径模糊:blur(45) 让背后细节几乎糊平,方向 / 饱和度可继续调")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            ZStack(alignment: .topLeading) {
                                LinearGradient(
                                    colors: [.teal, .indigo, .pink],
                                    startPoint: .top, endPoint: .bottom
                                )
                                Circle().fill(.yellow).frame(width: 64, height: 64).offset(x: 190, y: 16)
                                Circle().fill(.white).frame(width: 36, height: 36).offset(x: 60, y: 76)
                                HTMLRichTextFrostedView(
                                    style: .init(
                                        blurRadius: 45,
                                        tintColors: [.cyan, .blue, .purple],
                                        tintDirection: .topToBottom,
                                        tintOpacity: 0.22,
                                        saturationAmount: 1.4
                                    )
                                )
                                .overlay(alignment: .center) {
                                    Text("blur(45) + 上→下渐变,饱和 1.4")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.85))
                                        .padding(10)
                                }
                            }
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.top, 8)

                            Text("· 系统材质预设:`.thinMaterial()` 浅色宿主(自适应白基)/ `.ultraThickMaterial()` 深色宿主(自适应近黑基)—— 扁平无高光无边缘光,档位对应 SwiftUI `Material` 与 UIKit `system*Material`")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .id("frosted-material")
                            ZStack(alignment: .topLeading) {
                                LinearGradient(
                                    colors: [.mint, .cyan, .blue, .indigo],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Circle().fill(.yellow).frame(width: 60, height: 60).offset(x: 196, y: 12)
                                Circle().fill(.orange).frame(width: 40, height: 40).offset(x: 48, y: 88)
                                HTMLRichTextFrostedView(style: .thinMaterial())
                                    .overlay(alignment: .center) {
                                        Text(".thinMaterial():blur(12) saturate(1.8),自适应白基(浅色宿主)")
                                            .font(.caption2)
                                            .foregroundStyle(.black.opacity(0.6))
                                            .padding(10)
                                    }
                            }
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 8)

                            ZStack(alignment: .topLeading) {
                                LinearGradient(
                                    colors: [.black, .gray.opacity(0.6), .indigo.opacity(0.9)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Circle().fill(.pink).frame(width: 56, height: 56).offset(x: 200, y: 12)
                                Circle().fill(.cyan).frame(width: 40, height: 40).offset(x: 44, y: 88)
                                HTMLRichTextFrostedView(style: .ultraThickMaterial())
                                    .overlay(alignment: .center) {
                                        Text(".ultraThickMaterial():blur(30),自适应近黑基(深色宿主)")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.85))
                                            .padding(10)
                                    }
                            }
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.top, 8)
                        }
                        .id(12)

                        SectionCard("1️⃣3️⃣ 玻璃包装层(HTMLRichTextGlassView):原生玻璃可选 / 自动退回毛玻璃") {
                            Text("在 `HTMLRichTextFrostedView` 上再封一层:默认仍是毛玻璃(`.frosted`,所有版本可用);传入 `.glass(.regular)` 等即可在高版本(iOS 26+)用 SwiftUI 原生 `glassEffect`,低版本自动退回 `HTMLRichTextGlassEffect.fallbackFrostedStyle` 的毛玻璃档位。玻璃效果支持多种枚举配置:`.regular` / `.clear` / `.tinted(color)` / `.interactive` / `.tintedInteractive(color)`。`cornerRadius` 只作用于原生玻璃路径(玻璃面自带圆角),毛玻璃路径圆角仍由宿主 clipShape。")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("· `.glass(.XXXX)`:高版本原生玻璃(浅色宿主),低版本自动退回毛玻璃(.regularMaterial 档)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            ZStack(alignment: .topLeading) {
                                LinearGradient(
                                    colors: [.pink, .orange, .yellow, .green],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Circle().fill(.purple).frame(width: 70, height: 70).offset(x: 210, y: 8)
                                Circle().fill(.blue).frame(width: 46, height: 46).offset(x: 30, y: 84)
                                VStack(spacing: 0) {
                                    HTMLRichTextGlassView(style: .glass(.regular), cornerRadius: 0)
                                        .overlay(alignment: .center) {
                                            Text(".glass(.regular):iOS26+ 原生普通玻璃,低版本退回毛玻璃")
                                                .font(.caption2)
                                                .foregroundStyle(.black.opacity(0.6))
                                                .padding(10)
                                        }
                                    HTMLRichTextGlassView(style: .glass(.clear), cornerRadius: 0)
                                        .overlay(alignment: .center) {
                                            Text(".glass(.clear):iOS26+ 原生透明玻璃,低版本退回毛玻璃")
                                                .font(.caption2)
                                                .foregroundStyle(.black.opacity(0.6))
                                                .padding(10)
                                        }
                                    HTMLRichTextGlassView(style: .glass(.interactive), cornerRadius: 0)
                                        .overlay(alignment: .center) {
                                            Text(".glass(.interactive):iOS26+ 原生交互玻璃,低版本退回毛玻璃")
                                                .font(.caption2)
                                                .foregroundStyle(.black.opacity(0.6))
                                                .padding(10)
                                        }
                                }
                            }
                            .frame(height: 130)
                            .background(.ultraThinMaterial)
                            
                            Text("· `.glass(.tinted(.cyan))`:染色玻璃(深色宿主),玻璃面叠一层青色")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            ZStack(alignment: .topLeading) {
                                LinearGradient(
                                    colors: [.black, .gray.opacity(0.7), .purple.opacity(0.9)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Circle().fill(.pink).frame(width: 60, height: 60).offset(x: 210, y: 10)
                                Circle().fill(.cyan).frame(width: 44, height: 44).offset(x: 40, y: 90)
                                HTMLRichTextGlassView(style: .glass(.tinted(.cyan)), cornerRadius: 16)
                                    .overlay(alignment: .center) {
                                        Text(".glass(.tinted(.cyan)):染色玻璃 · 深色宿主")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.85))
                                            .padding(10)
                                    }
                            }
                            .frame(height: 130)
                            .padding(.top, 8)

                            Text("· 默认仍是毛玻璃:`HTMLRichTextGlassView()` = `.frosted(.light())`,行为与旧视图完全一致")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            ZStack(alignment: .topLeading) {
                                LinearGradient(
                                    colors: [.mint, .cyan, .blue, .indigo],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Circle().fill(.yellow).frame(width: 60, height: 60).offset(x: 196, y: 12)
                                Circle().fill(.orange).frame(width: 40, height: 40).offset(x: 48, y: 88)
                                HTMLRichTextGlassView()
                                    .overlay(alignment: .center) {
                                        Text("默认 `HTMLRichTextGlassView()` = `.frosted(.light())` 毛玻璃")
                                            .font(.caption2)
                                            .foregroundStyle(.black.opacity(0.6))
                                            .padding(10)
                                    }
                            }
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 8)
                        }
                        .id(13)

                        if Self.perfSectionEnabled {
                            SectionCard("1️⃣4️⃣ 性能测量:毛玻璃 vs 透明(仅 WebView 方案)") {
                                Text("同一批 8 张 `HTMLRichText` 卡片(每张独立 WKWebView):`HRT_PERF=1` 显示本节、`HRT_FROSTED=1` 走 `.frosted(.regularMaterial())` 毛玻璃、否则透明背景;`HRT_AUTOSCROLL=1` 在 perf-top ↔ perf-bottom 间循环滚动,便于宿主取样滚动时的重合成 CPU。其余环境变量、卡片内容、宽度完全一致。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .id("perf-top")

                                ForEach(0..<8, id: \.self) { index in
                                    HTMLRichText(content: Self.perfText(index: index))
                                        .baseStyle(.init(
                                            contentPadding: 12,
                                            backgroundStyle: Self.isFrosted ? .frosted(.regularMaterial()) : .transparent
                                        ))
                                        .frame(maxWidth: .infinity)
                                }
                                .id("perf-bottom")
                            }
                            .id(14)
                        }
                        
                        let blurCases: [(style: HTMLRichTextGlassStyle, label: String)] = [
                            (.frosted(.uiBlurEffect(.systemUltraThinMaterial)),      ".systemUltraThinMaterial"),
                            (.frosted(.uiBlurEffect(.systemThinMaterial)),          ".systemThinMaterial"),
                            (.frosted(.uiBlurEffect(.systemMaterial)),              ".systemMaterial"),
                            (.frosted(.uiBlurEffect(.systemThickMaterial)),         ".systemThickMaterial"),
                            (.frosted(.uiBlurEffect(.systemChromeMaterial)),        ".systemChromeMaterial"),
                            (.frosted(.uiBlurEffect(.systemUltraThinMaterialLight)), ".systemUltraThinMaterialLight(恒定浅色)"),
                            (.frosted(.uiBlurEffect(.systemThinMaterialLight)),     ".systemThinMaterialLight(恒定浅色)"),
                            (.frosted(.uiBlurEffect(.systemMaterialLight)),         ".systemMaterialLight(恒定浅色)"),
                            (.frosted(.uiBlurEffect(.systemThickMaterialLight)),    ".systemThickMaterialLight(恒定浅色)"),
                            (.frosted(.uiBlurEffect(.systemChromeMaterialLight)),   ".systemChromeMaterialLight(恒定浅色)"),
                            (.frosted(.uiBlurEffect(.systemUltraThinMaterialDark)), ".systemUltraThinMaterialDark(恒定深色)"),
                            (.frosted(.uiBlurEffect(.systemThinMaterialDark)),      ".systemThinMaterialDark(恒定深色)"),
                            (.frosted(.uiBlurEffect(.systemMaterialDark)),          ".systemMaterialDark(恒定深色)"),
                            (.frosted(.uiBlurEffect(.systemThickMaterialDark)),     ".systemThickMaterialDark(恒定深色)"),
                            (.frosted(.uiBlurEffect(.systemChromeMaterialDark)),    ".systemChromeMaterialDark(恒定深色)"),
                            (.frosted(.uiBlurEffect(.extraLight)),                  ".extraLight(白0.3)"),
                            (.frosted(.uiBlurEffect(.light)),                       ".light"),
                            (.frosted(.uiBlurEffect(.dark)),                        ".dark"),
                            (.frosted(.uiBlurEffect(.regular)),                     ".regular"),
                            (.frosted(.uiBlurEffect(.prominent)),                   ".prominent"),
                            (.frosted(.material(.ultraThinMaterial)),               "M .ultraThinMaterial"),
                            (.frosted(.material(.thinMaterial)),                    "M .thinMaterial"),
                            (.frosted(.material(.regularMaterial)),                 "M .regularMaterial"),
                            (.frosted(.material(.thickMaterial)),                   "M .thickMaterial"),
                            (.frosted(.material(.ultraThickMaterial)),              "M .ultraThickMaterial"),
                            (.frosted(.material(.bar)),                             "M .bar"),
                            // HTMLRichTextFrostedStyle 直接预设(工厂方法,全部 14 个)
                            (.frosted(.light()),                                    "Style .light()(H5 浅色)"),
                            (.frosted(.dark()),                                     "Style .dark()(H5 深色)"),
                            (.frosted(.gradient()),                                 "Style .gradient()(H5 premium)"),
                            (.frosted(.fallback(16)),                                 "Style .fallback()(blur2 轻量16)"),
                            (.frosted(.fallback(8)),                                  "Style .fallback()(blur2 轻量8)"),
                            (.frosted(.fallback(4)),                                  "Style .fallback()(blur2 轻量4)"),
                            (.frosted(.fallback(2)),                                  "Style .fallback()(blur2 轻量2)"),
                            (.frosted(.fallback(1)),                                  "Style .fallback()(blur2 轻量1)"),
                            (.frosted(.fallback(0.5)),                                "Style .fallback()(blur2 轻量0.5)"),
                            (.frosted(
                                HTMLRichTextFrostedStyle(
                                    blurRadius: 4,
                                    tintColor: .white,
                                    tintOpacity: 0.1,
                                    saturationAmount: 1.8,
                                    shineOpacity: 0,
                                    rimOpacity: 0)),                                  "Style .custom() blurRadius: 2, tintColor: .white, tintOpacity: 0.1, saturationAmount: 1.8, shineOpacity: 0, rimOpacity: 0"),
                            (.frosted(.extraLight()),                               "Style .extraLight()(恒定浅色)"),
                            (.frosted(.extraDark()),                                "Style .extraDark()(恒定深色)"),
                            (.frosted(.ultraThinMaterial()),                        "Style .ultraThinMaterial()"),
                            (.frosted(.thinMaterial()),                             "Style .thinMaterial()"),
                            (.frosted(.regularMaterial()),                          "Style .regularMaterial()"),
                            (.frosted(.bar()),                                      "Style .bar()"),
                            (.frosted(.thickMaterial()),                            "Style .thickMaterial()"),
                            (.frosted(.ultraThickMaterial()),                       "Style .ultraThickMaterial()"),
                            (.frosted(.card()),                                     "Style .card()(= .gradient() 别名)"),
                            (.frosted(.darkCard()),                                 "Style .darkCard()(= .dark() 别名)"),
                        ]
                        
                        SectionCard("1️⃣5️⃣ 毛玻璃样式库:全局共用一块玻璃 · 点行跳转子页逐档查看") {
                            Text("从这里开始不再是「每格一块玻璃」:全部样式由**全局唯一**的玻璃宿主渲染 —— 同一时刻最多创建一块毛玻璃(一个 WKWebView),换页面 / 换样式时复用并刷新。点击下面的行进入子页,单独查看「背景文字」透过该档玻璃的实际样子;`HRT_FROST_DETAIL=N` 可启动后自动跳到第 N 行,`HRT_FROST_CYCLE=1` 时子页每 2.5s 自动轮换下一档,验证「创建一次、换样式刷新」。")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(Array(blurCases.enumerated()), id: \.offset) { index, item in
                                NavigationLink(destination: FrostedStyleDetailPage(
                                    style: item.style,
                                    label: item.label,
                                    index: index,
                                    cases: blurCases
                                )) {
                                    FrostedStyleRow(label: item.label)
                                }
                            }
                        }
                        .id(15)
                        .background {
                            // 模拟器无法脚本化点击:HRT_FROST_DETAIL=N 启动后自动跳到第 N 行子页。
                            // 放卡片 background:blurCases 在该作用域可见(VStack 级 background
                            // 在内容闭包之外,访问不到这个局部数组)。
                            if let target = Self.autoPushIndex, blurCases.indices.contains(target) {
                                NavigationLink(
                                    destination: FrostedStyleDetailPage(
                                        style: blurCases[target].style,
                                        label: blurCases[target].label,
                                        index: target,
                                        cases: blurCases
                                    ),
                                    tag: target,
                                    selection: $autoDetailIndex
                                ) { EmptyView() }
                            }
                        }
                    }
                    .padding(16)
                    .task(id: Self.autoscrollEnabled ? 1 : 0) {
                        guard Self.perfSectionEnabled, Self.autoscrollEnabled else { return }
                        while !Task.isCancelled {
                            withAnimation(.linear(duration: 0.45)) { proxy.scrollTo("perf-top", anchor: .top) }
                            try? await Task.sleep(nanoseconds: 750_000_000)
                            withAnimation(.linear(duration: 0.45)) { proxy.scrollTo("perf-bottom", anchor: .bottom) }
                            try? await Task.sleep(nanoseconds: 750_000_000)
                        }
                    }
                    .task {
                        if let target = Self.autoPushIndex { autoDetailIndex = target }
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

    // MARK: - 性能测量辅助(第 14 小节,全部按环境变量开关,默认不渲染)

    /// `HRT_PERF=1` 时显示第 14 小节(8 张性能测量卡片)。默认关闭,保证演示
    /// 页面零额外 WebView 开销;需要复测时启动加 `SIMCTL_CHILD_HRT_PERF=1`。
    private static var perfSectionEnabled: Bool {
        ProcessInfo.processInfo.environment["HRT_PERF"] == "1"
    }

    /// `HRT_FROSTED=1` 时第 14 小节全部卡片走毛玻璃(`.frosted(.regularMaterial())`),
    /// 否则用默认透明背景 —— 两张配置除了这一点以外完全相同。
    private static var isFrosted: Bool {
        ProcessInfo.processInfo.environment["HRT_FROSTED"] == "1"
    }

    /// `HRT_AUTOSCROLL=1` 时在 perf-top ↔ perf-bottom 间循环滚动,供宿主取样
    /// 滚动时的瞬时 CPU(毛玻璃 blur 需要每帧重合成,透明背景则几乎无开销)。
    private static var autoscrollEnabled: Bool {
        ProcessInfo.processInfo.environment["HRT_AUTOSCROLL"] == "1"
    }

    /// `HRT_FROST_DETAIL=N`:启动后自动跳转到第 N 个毛玻璃子页(模拟器无法
    /// 脚本化点击,用环境变量代替)。
    private static var autoPushIndex: Int? {
        guard let raw = ProcessInfo.processInfo.environment["HRT_FROST_DETAIL"],
              let index = Int(raw) else { return nil }
        return index
    }

    /// `HRT_FROST_CYCLE=1`:毛玻璃子页每 2.5s 轮换下一档样式,验证
    /// 「同一块玻璃、换样式刷新」(创建一次)。子页类型需要读取,故为 fileprivate。
    fileprivate static var cycleEnabled: Bool {
        ProcessInfo.processInfo.environment["HRT_FROST_CYCLE"] == "1"
    }

    private static func perfText(index: Int) -> String {
        "性能测量卡片 \(index + 1):这段文字用于制造足够的排版负载,让毛玻璃(backdrop-filter: blur(16px) saturate(1.8))与透明背景在滚动时的重合成开销差异可测。包含普通文本、加粗、链接、行内代码与颜色,撑满卡片宽度。"
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

// MARK: - 全局共用毛玻璃(页面跳转子页分别查看)

/// 全局共用玻璃宿主的状态:同一时刻最多一块毛玻璃。
/// 子页出现时 `show` 报告样式 + 卡片全局 frame + 圆角,宿主据此精确摆位;
/// 离开时 `hide`,玻璃销毁(不占 WebContent 进程)。
private final class FrostedGlassModel: ObservableObject {
    static let shared = FrostedGlassModel()
    @Published var config: (style: HTMLRichTextGlassStyle, frame: CGRect, cornerRadius: CGFloat)?
    func show(style: HTMLRichTextGlassStyle, frame: CGRect, cornerRadius: CGFloat) {
        config = (style, frame, cornerRadius)
    }
    func hide() { config = nil }
}

/// 挂在 NavigationView 上的玻璃宿主:按模型给定的全局 frame 摆位。
/// `config == nil` 时渲染透明占位(不创建 WebView)。
private struct FrostedGlassHost: View {
    @ObservedObject var model = FrostedGlassModel.shared

    var body: some View {
        GeometryReader { hostProxy in
            let host = hostProxy.frame(in: .global)
            if let config = model.config {
                // 圆角统一走宿主:毛玻璃路径由 clipShape 裁圆角;
                // 原生玻璃路径同半径的玻璃面 + 再裁一层,视觉一致。
                HTMLRichTextGlassView(style: config.style, cornerRadius: config.cornerRadius)
                    .frame(
                        width: max(1, config.frame.width),
                        height: max(1, config.frame.height),
                        alignment: .top
                    )
                    .position(
                        x: config.frame.midX - host.minX,
                        y: config.frame.midY - host.minY
                    )
                    .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
    }
}

/// 报告宿主视图在全局坐标里的 frame;推入动画 / 布局变化会持续重报。
private struct FrameReporter: View {
    let onFrame: (CGRect) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { onFrame(proxy.frame(in: .global)) }
                .onChange(of: proxy.frame(in: .global)) { f in onFrame(f) }
        }
    }
}

/// 子页:单独查看某一档毛玻璃 / 玻璃效果。整卡玻璃由全局宿主渲染,
/// 本页只负责报告卡片位置 + 提供玻璃下方的「背景文字」供模糊采样。
private struct FrostedStyleDetailPage: View {
    let label: String
    let index: Int
    let cases: [(style: HTMLRichTextGlassStyle, label: String)]

    @State private var shownStyle: HTMLRichTextGlassStyle
    @State private var currentLabel: String
    @State private var cardFrame: CGRect = .zero

    init(
        style: HTMLRichTextGlassStyle,
        label: String,
        index: Int,
        cases: [(style: HTMLRichTextGlassStyle, label: String)]
    ) {
        self.label = label
        self.index = index
        self.cases = cases
        _shownStyle = State(initialValue: style)
        _currentLabel = State(initialValue: label)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("当前样式:\(currentLabel)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                ZStack {
                    LinearGradient(
                        colors: [.purple.opacity(0.8), .pink.opacity(0.55), .teal.opacity(0.6), .orange.opacity(0.45)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    VStack(spacing: 10) {
                        Text("背景文字")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black.opacity(0.75))
                        Text("第二行细节文字 0123456789 ABCDEFG")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.55))
                        Text("第三行:更小更细的内容,检验不同档位的模糊与透出。")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.black.opacity(0.45))
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .background(
                    FrameReporter { frame in
                        cardFrame = frame
                        FrostedGlassModel.shared.show(style: shownStyle, frame: frame, cornerRadius: 18)
                    }
                )

                Text("玻璃 = 全局宿主的同一块(每次进页创建一次,换样式 / 换页面复用刷新)。圆角统一由宿主负责(跟随卡片 18pt),`.glass(...)` 档另有同半径玻璃面。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("样式 #\(index + 1)/\(cases.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { FrostedGlassModel.shared.hide() }
        .task {
            guard ContentView.cycleEnabled else { return }
            var i = index
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                i = (i + 1) % cases.count
                currentLabel = cases[i].label
                shownStyle = cases[i].style
                if cardFrame != .zero {
                    FrostedGlassModel.shared.show(style: shownStyle, frame: cardFrame, cornerRadius: 18)
                }
            }
        }
    }
}

/// 样式库列表行:静态渐变色块 + 样式名 + 箭头(不放真实玻璃,避免每行再起 WebView)。
private struct FrostedStyleRow: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(
                    colors: [.purple, .pink, .teal, .orange],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 14, height: 14)
            Text(label)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}
