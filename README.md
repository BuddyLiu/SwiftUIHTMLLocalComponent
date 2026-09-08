# HTMLRichText — SwiftUI 本地富文本组件

一个基于 `WKWebView` 的本地方案 SwiftUI 富文本组件。SwiftUI 原生 `Text` / `AttributedString` 的样式表达能力有限,这里用本地 WebView 承载 HTML 渲染富文本,把**颜色、字号、行高、图文混排、列表引用**等能力带回来,同时保持组件化、高度自适应、交互全部回调给上层。

## 特性

- **独立组件**:`HTMLRichText` 直接嵌入 SwiftUI 视图,参数全配置;
- **声明式链式入口**:不写 HTML,传**普通文本**,用 `.baseStyle / .linkItem / .imageItem` 声明式标记基础样式与可点击/插图片段,组件内部编译成 HTML;
- **高度自适应**:内容多高,组件多高,流畅嵌入外层 `ScrollView`(默认关闭 WebView 内部滚动,内容与预估高度不符时按实际高度收身;放入**固定高度**容器装不下时内容直接裁切,需要内部滑动时显式开 `isScrollEnabled = true`);
- **样式丰富**:自定义字号、行高、字距、文本颜色、链接颜色、对齐、字体族、自定义 CSS;
- **交互全部回调**:`<a href>` 链接与带 `data-tap` 的任意元素点击后回调给 SwiftUI,`<a>` 原生跳转被拦截,绝不离开当前页面;
- **图片交互可配**:每张图片可独立配置**点击开关**(`isTapEnabled`)、**长按开关 + 独立长按回调**(`isLongPressEnabled` + `onLongPress`),以及**排布方式**(内联 / 块级 / 左·右浮动图文混排)、**大小 / 外边距 / 背景色 / 边框粗细与颜色**,预设快捷(.card / .bordered / .floatLeft…)给出一组合理默认值;
- **生命周期回调**:`onStateChange` 一个回调收敛 `loading / rendered / ready(高度) / failed(描述)` 四种状态,便于加载占位、内容就绪判定与失败兜底;
- **默认不可长按 / 滑动 / 缩放**:WebView 的光标、文本选中、长按菜单、长按预览、双指缩放默认全部关闭,按需通过配置开启;
- **本地优先**:HTML 片段、本地 `.html` 文件、相对路径图片资源全部本地加载,无需网络;
- **性能友好**:渲染参数用指纹比对,未变化不重载;容器宽度未变化不重复注入 JS;高度随内容变化增量上报,变化消息去重合并;
- **加载即最终样式**:首帧用「预估高度 / 历史缓存高度」撑起布局,内容一渲染出来就是最终高度,没有先塌成 0 再跳变的闪烁;
- **加载渐显 + 可选占位**:就绪(首个有效高度)前不显示内容,就绪后内容淡入,消除加载过程的"突然出现";加载期间可显示系统默认菊花(`.loadingSpinner()`)或完全自定义的占位视图(`.loadingPlaceholder { … }`)。

## 目录结构

```
SwiftUIHTMLLocalComponent/
├── Package.swift                              # SPM 库定义(可选接入方式)
├── README.md
└── SwiftUIHTMLLocalComponent/                 # Xcode 工程
    ├── SwiftUIHTMLLocalComponent.xcodeproj
    └── SwiftUIHTMLLocalComponent/
        ├── HTMLRichText/                      # ← 组件源码,拷贝这一整个文件夹即可接入
        │   ├── HTMLRichText.swift             # SwiftUI 视图入口(三套入口 + 链式修饰)
        │   ├── HTMLRichTextConfig.swift       # 可配置参数模型
        │   ├── HTMLRichTextItem.swift         # 链式标记模型 + 图片/链接单段样式
        │   ├── HTMLRichTextContentComposer.swift # 纯文本 + 标记 → HTML 编译
        │   ├── HTMLRichTextView.swift         # UIViewRepresentable 封装 WKWebView
        │   ├── HTMLRichTextCoordinator.swift  # 导航/消息桥接
        │   ├── HTMLRichTextTemplate.swift     # 完整 HTML 文档生成(CSS + JS 桥)
        │   ├── HTMLRichTextWebState.swift     # 生命周期状态枚举(loading / rendered / ready / failed)
        │   ├── HTMLRichTextSchemeHandler.swift# hrtlocal:// 本地资源加载器
        │   ├── HTMLRichTextTools.swift        # 配套公共工具类(预估高度、颜色/转义、行内 CSS 等)
        │   ├── HTMLRichTextHeightCache.swift  # 进程内高度缓存(内容指纹 + 容器宽度)
        │   └── HTMLTapContext.swift           # 点击回调数据模型
        ├── ContentView.swift                  # 演示页:10 个场景
        ├── Resources/                         # 演示资源(demo-banner.png / sample-article.html)
        └── SwiftUIHTMLLocalComponentApp.swift
```

## 快速开始

### 基础用法

```swift
import SwiftUI
import HTMLRichText   // SPM 接入时;拷贝源码则无需(源码提供方)

struct ContentView: View {
    var body: some View {
        ScrollView {
            HTMLRichText(
                html: "<h3>标题</h3><p>一段 <b>加粗</b> 与 <span style='color:#E53935'>红字</span>。</p>",
                config: .init(fontSize: 16, lineHeight: 1.7, linkColor: .orange)
            ) { tap in
                print(tap.url ?? tap.dataAttributes)   // 点击回调
            }
        }
    }
}
```

### 加载本地 HTML 文件

```swift
// 文件放 bundle 根目录或 Resources/ 子目录均可,内部宽容查找
HTMLRichText(localHTMLNamed: "article") { tap in
    // ...
}
```

### 相对路径本地图片

图片与文档相对路径自动从 `baseURL` 目录解析,全程本地沙箱,无需网络:

```swift
HTMLRichText(
    html: "<img src='img/banner.png'>",
    config: .init(baseURL: Bundle.main.bundleURL)
)
```

### 声明式链式入口(纯文本 + `.baseStyle / .linkItem / .imageItem`)

**不写 HTML,也不做转义**:只传一段**普通文本**,样式与交互全部用链式修饰器声明,组件内部把它编译成 HTML 再走渲染/桥接链路。普通文本自动转义,文案里的 `<`、`&` 等字符逐字显示:

```swift
HTMLRichText(content: "这是一段富文本，支持点击，能插入图片。")
    .baseStyle(.init(fontSize: 16,
                     lineHeight: 1.7,
                     linkColor: .orange,
                     imageStyle: .init(maxWidth: 240, cornerRadius: 10)))
    .linkItem("支持点击", link: "https://example.com/detail") { match in
        print(match)   // 点击「支持点击」时触发
    }
    .linkItem("富文本", link: "https://example.com/rich",
              style: .underlined) { match in
        print(match)
    }
    .imageItem("能插入图片", localSource: "demo-banner.png",
               style: .rounded(24)) { match in
        print(match)   // 点击图片时触发
    }
```

#### 语义规则

- **`.linkItem`**:匹配文本渲染为链接(`<a href>`,原生跳转由 JS 拦截,只回调),点击触发该段 `action`(参数为匹配文本);
- **`.imageItem`**:匹配文本替换为本地图片(`localSource` 相对 `config.baseURL` 解析),点击图片触发该段 `action`;图片的**点击 / 长按开关、排布方式、外边距、背景色、边框**等全部可经 `style` 配置;
- **`.baseStyle`**:整份覆盖基础 `HTMLRichTextConfig`(字号/行高/颜色/自定义 CSS/`imageStyle` 等),作用于全部内容;单段样式再覆盖个别字段;
- **替换所有出现**:每个链式标记的匹配文本出现几处替换几处;后到的标记自动跳过已被前面标记占用的区域;
- **匹配方式**:普通子串匹配(非正则),大小写敏感;
- **点击回调并存**:命中标记元素时,**该段的 `action` 与通用 `onTap` 都会触发**(`action` 先、`onTap` 后);未被标记的元素点击只走 `onTap`;
- **图片点击开关**:`isTapEnabled` 默认开启,点击同时触发该段 action 与通用 `onTap`;设 `false` 后图片成为纯展示(e.g. 装饰图 / 协议图),点击不产生任何回调;
- **图片长按**:`isLongPressEnabled` 默认关闭;开启后在 `.imageItem(..., onLongPress:)` 传回调,长按约 0.45s 触发,长按与点按回调**相互独立**(长按不会顺带触发 action / onTap);
- **排布方式**:`layout` 缺省为内联;`.block` 独占一行按 `alignment` 对齐,`.leftFloat / .rightFloat` 让文字环绕,实现图文混排;
- **图片样式合并**:全局 `config.imageStyle` 定默认值,`.imageItem(style:)` 字段级覆盖个别项;链接样式 `.linkItem(style:)` 覆盖全局 `linkColor`。

#### 链式修饰器列表

| 修饰器 | 参数 | 说明 |
|---|---|---|
| `.baseStyle` | `HTMLRichTextConfig` | 设置基础样式与配置(整份替换) |
| `.estimatedHeight` | `CGFloat?` | 首帧预估高度:加载完成前按该高度撑起布局,**收到真实测量后自动替换**,避免跳动 |
| `.loadingSpinner` | — | 加载期间显示**系统默认菊花**,内容就绪后菊花淡出、内容淡入(默认加载超过 1s 才显示) |
| `.loadingPlaceholder` | `@ViewBuilder () -> some View` | **完全自定义**的加载占位视图(文字/动画/进度条等),同样就绪后淡出 |
| `.loadingPlaceholderDelay` | `TimeInterval` | 占位**延迟显示时长**(秒,**默认 1.0**):加载很快时不闪占位,超过该时长仍未就绪才显示;0 = 立即 |
| `.linkItem` | `match, link, style?, action` | 匹配文本 → 可点击链接,`action(String)` |
| `.imageItem` | `match, localSource, style?, onLongPress?, action` | 匹配文本 → 本地图片;`action(String)` 点按,`onLongPress(String)` 长按(需在 style 里开 `isLongPressEnabled`) |
| `(入口)` | `content: String, estimatedHeight?, onTap:, onStateChange?` | 纯正文 + 可选首帧高度 + 通用点击回调 + 生命周期回调 |

#### `HTMLRichTextLinkStyle` 参数表(字段均可选,nil = 沿用全局)

| 参数 | 类型 | 说明 |
|---|---|---|
| `color` | `Color?` | 链接文字颜色,覆盖 `linkColor` |
| `isUnderlined` | `Bool?` | 是否加下划线,默认无 |
| `fontWeight` | `Font.Weight?` | 链接字重 |

**常见预设**(写 `.plain` / `.underlined` 等即可,不用每次 `.init(...)`):

| 预设 | 效果 |
|---|---|
| `.plain` | 常规链接(链接色、无下划线) |
| `.underlined` | 经典超链接(下划线) |
| `.bold` | 加粗链接 |
| `.boldUnderlined` | 加粗 + 下划线 |
| `.underlined(.red)` | 指定颜色的下划线链接 |
| `.bold(.orange)` | 指定颜色的加粗链接 |

#### `HTMLRichTextImageStyle` 参数表(字段均可选,nil = 默认/继承全局 `config.imageStyle`)

| 参数 | 类型 | 说明 |
|---|---|---|
| `maxWidth` | `CGFloat?` | 图片最大宽度(`pt`,默认 `100%`) |
| `height` | `CGFloat?` | 图片高度(`pt`,默认 `auto`) |
| `cornerRadius` | `CGFloat?` | 圆角 |
| `contentMode` | `ContentMode?` | `.fit` → `object-fit: contain`,`.fill` → `fill` |
| `alignment` | `HorizontalAlignment?` | 水平对齐(**块级排布**时生效:leading / center / trailing) |
| `verticalAlignment` | `HTMLRichTextImageVerticalAlignment?` | **内联排布**时与同行文字的垂直对齐:顶 / 中 / 底 |
| `layout` | `HTMLRichTextImageLayout?` | 排布方式:内联 / 块级 / 左浮动 / 右浮动(默认内联) |
| `margin` | `HTMLRichTextImageMargin?` | 外边距(top/left/right/bottom 任意组合,单位 `pt`;**内联时左右外边距即与相邻文字的间距**) |
| `backgroundColor` | `Color?` | 图片背景色(透过透明图片可见) |
| `borderWidth` | `CGFloat?` | 边框粗细(`pt`);与 `borderColor` 同时设置才显示 |
| `borderColor` | `Color?` | 边框颜色 |
| `isTapEnabled` | `Bool?` | 点击开关(默认开):false = 纯展示图,点击无回调 |
| `isLongPressEnabled` | `Bool?` | 长按开关(默认关):true = 长按触发 `.imageItem(onLongPress:)` |
| `default` | — | 全空默认值(所有字段跟随引擎默认) |

**排布方式**(`HTMLRichTextImageLayout`):

| 值 | 效果 |
|---|---|
| `.inline` | 内联:图片嵌在文字流中间,随文字流动(默认) |
| `.inline(vertical:.middle, marginLeft:4, marginRight:4)` | 内联 + 指定垂直对齐 + 图片左右与文字的间距 |
| `.block` | 块级:独占一行,按 `alignment` 对齐 |
| `.leftFloat` | 左浮动:图片靠左、右侧文字环绕 |
| `.rightFloat` | 右浮动:图片靠右、左侧文字环绕 |

**内联垂直对齐**(`HTMLRichTextImageVerticalAlignment`,仅 `.inline` 生效):

| 值 | 效果 |
|---|---|
| `.top` | 图片顶端与行内文字顶线对齐 |
| `.middle` | 图片垂直居中于行内容器 |
| `.bottom` | 图片底端与行内文字基线对齐(小图标贴文字的常见观感) |

**外边距**(`HTMLRichTextImageMargin`,四个方向均可选):直接 `init(top:left:right:bottom:)` 指定,或快捷构造 `.all(_:)`(四周)、`.horizontal(_:)`(左右)、`.vertical(_:)`(上下)、`.zero`。

**常见预设**(快捷构造,给出一组合理默认值):

| 预设 | 效果 |
|---|---|
| `.fullWidth` | 满宽自适应(引擎默认) |
| `.rounded(12)` | 圆角图,半径可传(默认 12) |
| `.square(120)` | 正方形缩略图(限宽 + 等高) |
| `.circle(100)` | 圆形头像(半径 = 边长一半) |
| `.thumbnail` | 小尺寸缩略图(100pt 限宽 + 圆角) |
| `.inline(vertical:.middle, marginLeft:4, marginRight:4)` / `.block(.center)` | 指定排布方式;内联可再带垂直对齐与左右文字间距 |
| `.floatLeft()` / `.floatRight()` | 浮动排布,默认给另一侧留 12pt 间距(传 `marginRight: 0` 去掉) |
| `.bordered(.gray, width: 1, cornerRadius: 8)` | 描边图(颜色 / 粗细 / 圆角) |
| `.card(alignment: .center)` | 卡片图:块级 + 白底 + 圆角 + 细边框 + 上下留白 |

**组合式便捷方法**:`.withBorder(width:color:)` / `.withMargin(_:)` 在现有样式上只改对应字段,便于叠加预设。

```swift
// 卡片图:块级居中,白底 + 圆角 + 边框,边上留 6pt
HTMLRichText(content: "卡片图 说明文字…", config: .init(baseURL: .main.bundleURL))
    .imageItem("卡片图", localSource: "photo.png",
               style: .card(alignment: .center, cornerRadius: 16)) { _ in }

// 图文混排:左浮动,文字自动环绕在图片右侧
.imageItem("主图", localSource: "photo.png", style: .floatLeft()) { _ in }

// 长按图:长按约 0.45s 触发 onLongPress;点按仍走 action
.imageItem("头像", localSource: "avatar.png",
           style: .init(maxWidth: 96, cornerRadius: 48, isLongPressEnabled: true),
           onLongPress: { match in print("长按了 \(match)") }) { _ in }

// 纯展示图:点击 / 长按都没有任何回调
.imageItem("分隔图", localSource: "divider.png",
           style: .init(maxWidth: 240, isTapEnabled: false)) { _ in }
```

> 兼容性:`html:` / `localHTMLNamed:` / 声明式入口三套 API 可混用。

## 接入方式(三选一)

1. **拷贝源码**:把 `HTMLRichText/` 文件夹拖进你的 Xcode 工程(iOS 15+,`import SwiftUI/WebKit` 即可,零依赖)。
2. **SPM**:把本仓库作为 Swift Package 依赖引入(见 `Package.swift`),`import HTMLRichText`。
3. **引入整个工程**:把 `SwiftUIHTMLLocalComponent.xcodeproj` 拖进你的 Workspace,关联 target 后使用。

支持最低 iOS 15(需要 `UIColor(Color)` 动态取色与 SwiftUI `ColorScheme`)。

## 参数表(`HTMLRichTextConfig`)

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `fontSize` | `CGFloat` | `17` | 正文字号(pt,CSS `font-size`) |
| `lineHeight` | `CGFloat` | `1.6` | 行高倍数(CSS `line-height`) |
| `letterSpacing` | `CGFloat?` | `nil` | 字距,不设置则跟随系统 |
| `textColor` | `Color` | `.label` | 文本色,随深浅色自动适配 |
| `linkColor` | `Color` | `.blue` | 链接颜色 |
| `backgroundColor` | `Color` | `.clear` | 页面背景色 |
| `fontFamily` | `String?` | `nil` | 字体族,如 `"PingFang SC, serif"` |
| `textAlignment` | `TextAlignment` | `.leading` | 对齐(映射 CSS `text-align`) |
| `customCSS` | `String?` | `nil` | 追加的自定义 CSS 规则 |
| `imageStyle` | `HTMLRichTextImageStyle` | `.default` | 文档内图片的全局默认样式(`.imageItem` 可单段覆盖) |
| `estimatedHeight` | `CGFloat?` | `nil` | 首帧预估高度:加载完成前先把布局撑起来,收到真实测量后自动替换 |
| `isTransparent` | `Bool` | `true` | 页面背景透明,无缝嵌入宿主背景 |
| `baseURL` | `URL?` | `Bundle.main.bundleURL` | 相对路径资源的解析根目录 |
| `inlineLocalImages` | `Bool` | `true` | 是否把文档内指向本地文件的 `<img>` 内联成 `data:` URI(图片随文档一起返回,不走子资源请求,可规避 WebKit 偶发丢图;HTML 字节数约 ×1.33。仅 `baseURL` 下真实存在的本地文件内联,网络 / data: / blob: 不受影响) |
| `preferredColorScheme` | `ColorScheme?` | `nil` | 强制浅/深色取色,默认跟随系统 |
| `isScrollEnabled` | `Bool` | `false` | 允许 WebView 内部滚动(**默认关**,内容由外层滚动)。不会**自动**开启:放进固定高度容器装不下时直接裁切,要在内部滑动需显式开启此开关 |
| `isZoomEnabled` | `Bool` | `false` | 允许双指缩放(**默认关**) |
| `isTextSelectionEnabled` | `Bool` | `false` | 允许文本选中(**默认关**) |
| `isLinkPreviewEnabled` | `Bool` | `false` | 允许长按链接预览(**默认关**) |
| `isTouchCalloutEnabled` | `Bool` | `false` | 允许长按弹出复制菜单(**默认关**) |

> 背景颜色由**外部**视图控制(`backgroundColor` 默认 `clear` + `isTransparent` 默认 `true`),HTML 内部不绘制背景,保证与宿主界面无缝融合。

## 高度与滚动(适配任意外层容器)

组件高度**始终等于内容的实际渲染高度**(把 `.frame(height:)` 交给外层),滚动策略再按外层容器决定:

- **默认(外层限高,内容放得下)**:组件高度 = 内容高度,内外都不滚动,内容完整展示。
- **外层固定高度放不下内容**:内容**直接裁切**。需要在这类固定高度里滑动查看时,给 `config.isScrollEnabled = true` 显式开启 WebView 内部滚动。
- **内容比预估高度小(`estimatedHeight` 偏大)**:就绪后按**实际内容高度**收身展示,不会黏在预估值上。JS 侧用 `body.scrollHeight / offsetHeight` 测高(不用 `documentElement.scrollHeight` —— html 是初始包含块,`scrollHeight` 至少等于视口高度,首帧 frame 比内容高时会误把视口高度报成内容高度,导致组件永远不按实际内容收身)。

## 加载体验优化

WebView 加载是异步的,组件做了以下几件事,尽量让**用户第一眼看到的就是加载完成的样式**,没有空白 / 塌缩 / 跳变:

1. **首帧不塌缩**:加载完成前先按「`estimatedHeight` 预估高度 / 历史缓存高度」撑起布局;收到 JS 真实测量后才精修。`estimatedHeight` 可经 `config`(html 入口)、`HTMLRichText(content:estimatedHeight:)`(入口参数)、或链式 `.estimatedHeight(180)`(声明式入口,需放在 `.baseStyle` 之后)传入。
2. **高度缓存**:按「内容指纹 + 容器宽度」缓存最近一次最终高度(`HTMLRichTextHeightCache`,进程内)。列表复用、页面来回切换时,同内容实例直接复用缓存高度,不再经历「0 → 真实高度」的跳变。
3. **渲染指纹去重**:只有影响渲染的参数变化才重载 WebView;容器宽度未变化不重复注入 JS。
4. **高度消息去重 / 防抖**:JS 侧尺寸未变化不重复 postMessage,MutationObserver 合并成 50ms 防抖;Swift 侧相同高度不重复驱动 SwiftUI 重绘。避免高度自适应过程中 JS ↔ Swift 两边互相风暴。
5. **非透明背景提前铺色**:`isTransparent = false` 时,加载阶段 WebView 就直接铺上配置背景色,避免「先透明/先白 → CSS 生效后才变色」的闪烁。
6. **加载渐显 + 可选占位**:就绪(收到首个有效高度)前内容保持隐藏,以 0.3s 淡入显示,不再"突然弹出";**渐显在文档内部完成**(CSS `body{opacity:0}` → JS 拿到首个有效尺寸后加 `.hrt-visible` 触发 0.3s 渐变),SwiftUI 侧只负责占位时序。加载期间可用 `.loadingSpinner()`(系统菊花)或 `.loadingPlaceholder { … }`(完全自定义)显示占位,就绪后占位淡出与内容淡入交错过渡。占位默认**延迟 1s** 才显示(`.loadingPlaceholderDelay(_:)` 可定制),本地加载通常几十毫秒就完成,不会闪一下菊花。重载(文字/样式/深浅色变化)会重新走一遍 loading → 新文档再次内部渐显。
7. **图片可靠显示**:本地图片默认内联成 `data:` URI,随文档一起返回、解码,不经过子资源请求链路;对内联解码失败的图,JS 侧自动「克隆替换节点」强制重解码;对普通 URL 图则重发带新查询参数的请求(上限 3 次 / 8s 恢复)。WebKit 合成器偶发漏绘时,Swift 侧用 `takeSnapshot(with:)` 强制整页重新光栅化,把图片补上。

> 首次真正打开一段新内容时,至少需要一次 WebView 渲染 + 一次高度回传(本地 scheme 通常几十毫秒级)。对此可用 `estimatedHeight` 消除占位塌缩,并配合上面的渐显/占位,让加载过程几乎无感。

## 配套工具类(`HTMLRichTextTools`)

`HTMLRichTextTools` 是组件自带的公共工具类(全部静态方法),提供预估高度、样式快捷构造、颜色/转义、行内 CSS、高度缓存等快捷方法,让接入方少写样板代码:

```swift
// 1. 首次打开新内容:按正文 + 配置实测一个预估高度,先撑住位置避免跳动
let estimate = HTMLRichTextTools.estimatedTextHeight(
    text: "这是一段富文本…", config: .init(fontSize: 16, lineHeight: 1.7), containerWidth: 342
)
HTMLRichText(content: "这是一段富文本…", estimatedHeight: estimate)

// 2. HEX 颜色字符串直接作配置色
let config = HTMLRichTextConfig(textColor: HTMLRichTextTools.color(hex: "#37474F"),
                                linkColor: HTMLRichTextTools.color(hex: "#1565C0"))

// 3. 固定尺寸图片样式 + 行内 CSS(编辑原始 HTML 时与组件同一套规则)
let style = HTMLRichTextTools.imageStyle(fixed: CGSize(width: 320, height: 200), cornerRadius: 12)
let css   = HTMLRichTextTools.inlineCSS(for: .rounded(24))

// 4. 查 / 清历史高度缓存
if let cached = HTMLRichTextTools.cachedHeight(forHTML: html, config: config,
                                               colorScheme: .light, containerWidth: 342) { … }
```

方法一览:

| 方法 | 说明 |
|---|---|
| `imageStyle(fixed:cornerRadius:contentMode:alignment:)` | 由固定尺寸快捷构造图片样式(限宽 + 等高) |
| `squareImageStyle(side:cornerRadius:)` | 由边长构造正方形图片样式(头像等) |
| `linkStyle(color:underlined:fontWeight:)` | 按需组合的链接样式(常见用预设 `.plain/.underlined/.bold`) |
| `estimatedTextHeight(text:config:containerWidth:)` | 按 config 排版实测**纯文本**高度(pt),做首帧预估 |
| `estimatedHeight(forHTML:config:containerWidth:)` | 粗略估算 **HTML** 高度(剥标签测文字 + 每张 `<img>` 加高度预算) |
| `cachedHeight(forHTML:config:colorScheme:containerWidth:)` | 读取高度缓存(同内容 + 同宽度的最近一次真实测量) |
| `clearHeightCache()` | 清空进程内高度缓存 |
| `htmlEscape(_:)` | 普通文本 HTML 实体转义(与组件内部同一套) |
| `hexString(from:isDark:)` | `Color` → HEX(按目标深浅色解析,供自定义 CSS 使用) |
| `color(hex:)` | `#RGB / #RRGGBB / #RRGGBBAA` → `Color` |
| `inlineCSS(for imageStyle:isDark:)` | 图片行内 CSS(与 `.imageItem(style:)` 同一套规则) |
| `inlineCSS(for linkStyle:isDark:)` | 链接行内 CSS(与 `.linkItem(style:)` 同一套规则) |

## 点击回调(`HTMLTapContext`)

`onTap` 回调在以下两种元素被点击时触发,`<a>` 链接的默认跳转会被拦截(纯展示组件不导航):

```swift
public struct HTMLTapContext {
    public let url: URL?                        // `<a href>` 时非空
    public let elementID: String?
    public let tagName: String?
    public let classes: [String]
    public let dataAttributes: [String: String] // 元素上所有 data-* 属性
    public let text: String?
}
```

带 `data-tap` 属性的任意元素会被当作可点击卡片:

```html
<div data-tap data-type="goods" data-id="10086">
  <b>示例商品</b>
</div>
```

```swift
HTMLRichText(html: originalHTML) { tap in
    guard tap.url == nil else { /* 这是普通链接 */ return }
    print(tap.dataAttributes)      // ["type": "goods", "id": "10086", ...]
}
```

## 生命周期回调(`onStateChange`)

`HTMLRichText` 把 WebView 的生命周期收敛成**一个回调 + 一个状态枚举**,用于展示加载占位、判定内容就绪、捕获失败:

```swift
HTMLRichText(
    html: "<p>Hello</p>",
    onStateChange: { state in
        switch state {
        case .loading:  showLoading()              // 开始加载(首次或参数变化重载)
        case .rendered: break                      // 文档渲染完成,高度可能尚未回传
        case .ready(let height): showContent(height) // 首个有效内容高度已回传,可安全展示
        case .failed(let message): showError(message) // 加载失败(errors.localizedDescription)
        }
    }
)
```

`HTMLRichTextWebState` 状态表:

| 状态 | 参数 | 说明 |
|---|---|---|
| `.loading` | — | 开始加载(首次加载,或渲染参数变化触发的重载都会重新走一遍) |
| `.rendered` | — | 文档渲染完成(`didFinish`),但内容高度可能还未回传 |
| `.ready(_ height: CGFloat)` | 内容高度(pt) | **首个有效高度**已回传,可以安全展示了;后续高度微调(图片加载、旋转)不会重复触发 |
| `.failed(_ message: String)` | 错误描述 | 加载失败(scheme 资源缺失等) |

> 一次加载最多各触发一次 `.loading` / `.rendered` / `.ready`;参数变化导致的任何一次重载都会重置并重新走一遍,方便上层移除旧的 loading 占位。
> `onStateChange` 与 `onTap`、高度回调各自独立;`.ready` 也在收到首个有效高度后触发,可作为「内容可以展示」的统一信号。

## 实现原理

1. **HTML 模板**:用户传入的 HTML 片段被包成完整文档(`<meta viewport>` + 由配置生成的 CSS + 注入的 JS 桥)。颜色值在 Swift 侧按目标深浅色解析成 HEX 写入 CSS,`isTransparent` 时页面背景透明,与 SwiftUI 背景无缝衔接。
2. **本地加载**:主文档与相对路径资源走自定义 `hrtlocal://` scheme(`WKURLSchemeHandler`)在 `baseURL` 沙箱内读取,不产生临时文件,也规避 `loadFileURL` 的读权限限制。主文档返回时,文档内指向本地文件的 `<img>` 默认先被内联成 `data:` URI(`inlineLocalImages`,可关闭),图片随文档一起解码,不经过子资源请求链路。主文档的 MIME 必须为 `text/html` 且字符集独立传 `textEncodingName`,不能拼进 MIME。
3. **高度自适应**:JS 桥(`htmlRichTextBridge`,文档解析前注入)在 `DOMContentLoaded`、`resize`、图片 `load`、`MutationObserver(body)` 触发时上报 `max(body.scrollHeight, body.offsetHeight)`,SwiftUI 侧据此设置组件高度。**排版按容器真实宽度**(Swift 把 `bounds.width` 写入 `window.__htmlRichTextWidth`,JS 同步 viewport 的 `width`),避免窄卡片内按全屏宽度排版导致的横向溢出与高度反馈放大。
4. **交互开关**:长按、缩放分别通过 CSS(`-webkit-user-select` / `-webkit-touch-callout`)、viewport meta(`user-scalable / maximum-scale`)与原生属性(`allowsLinkPreview` / `isScrollEnabled`)三层控制,全部默认关闭。注意 `-webkit-touch-callout` **不继承**、只对 `<a>` / `<img>` 元素本身生效,所以关闭系统长按菜单时按整份文档声明(而不是只写 body),图片长按不再弹「存储图像/拷贝」;图片另设 `-webkit-user-drag: none` 防拖拽。**图片长按回调**由 JS 以 touch 事件判定(touchstart 后 450ms 内未移动 / 松开),通过 `longPress` 消息独立桥接回 SwiftUI,并与随后的 click 去重,长按不误触点按回调。
5. **渲染指纹(RenderKey)**:只有影响页面渲染的参数(文案、样式、深浅色等)变化才重载 WebView;纯交互开关(`isScrollEnabled` 等)跳过重载即时同步。容器宽度未变化时不重复注入 JS,从源头减少 WebView 这个重量级视图的无效工作。

## 演示 App

`ContentView.swift` 内置多个场景:

1. 基础富文本(标题/加粗/斜体/下划线/列表/引用);
2. 图文混排(相对路径加载本地 `demo-banner.png`);
3. 点击交互(链接 + `data-tap` 卡片,顶部横幅实时展示回调);
4. 样式定制(字号/行高/颜色/对齐/字体族/自定义 CSS 对比);
5. WebView 开关(内部滚动/长按选择/双指缩放开关效果);
6. 本地 HTML 文件(`localHTMLNamed:` 加载 `sample-article.html`);
7. 纯文本 + 链式标记(`.baseStyle / .linkItem / .imageItem`,action + onTap 并存);
8. 配套工具类(`HTMLRichTextTools`:预估高度 / HEX 取色 / 行内 CSS);
9. 图片交互与样式细化(内联 / 块级卡片 / 左浮动图文混排、点击禁用、长按回调、边框 / 背景 / 外边距预设);
10. 固定高度容器(超出裁切)与预估高度收身。

构建:

```bash
open SwiftUIHTMLLocalComponent/SwiftUIHTMLLocalComponent.xcodeproj
# 选择 SwiftUIHTMLLocalComponent scheme,运行到 iOS 模拟器
```

## 许可

MIT