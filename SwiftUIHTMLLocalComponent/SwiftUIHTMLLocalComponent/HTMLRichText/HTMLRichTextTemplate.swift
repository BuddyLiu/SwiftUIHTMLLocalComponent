//
//  HTMLRichTextTemplate.swift
//  SwiftUIHTMLLocalComponent
//
//  根据配置把用户传入的 HTML 片段包成完整文档(CSS + viewport + JS 桥),
//  并向上层暴露 JS 桥脚本与消息通道名。
//

import SwiftUI
import UIKit

enum HTMLRichTextTemplate {

    /// JS 桥消息通道名(与注入脚本保持一致)。
    static let bridgeName = "htmlRichTextBridge"

    // MARK: - 完整文档

    /// 把用户内容片段包成可交给 WKWebView 的完整 HTML 文档。
    /// 内容经 `hrtlocal://` scheme 加载,相对路径资源(如 `img/a.png`)会自动解析到
    /// 配置的 baseURL 目录。
    ///
    /// - Parameter containerWidth: 已知的容器宽度(pt)。传入后用固定宽度排版——
    ///   若用 `width=device-width`,在比屏幕窄的卡片/容器里会按全屏宽度排版并缩放,
    ///   造成高度反馈放大(高度随帧高线性膨胀),所以必须用真实容器宽度。
    static func document(content: String, config: HTMLRichTextConfig, isDark: Bool, containerWidth: Int = 0) -> String {
        let viewportWidth = containerWidth > 0 ? "width=\(containerWidth)" : "width=device-width"
        // 注意:不要给固定宽度追加 `initial-scale=1` —— 该组合会把排版宽度拉回设备宽度
        //(窄容器会横向溢出、高度反馈放大),请保持 only width。
        let viewport: String
        if containerWidth > 0 {
            viewport = config.isZoomEnabled
                ? viewportWidth
                : "\(viewportWidth), maximum-scale=1, user-scalable=no"
        } else if config.isZoomEnabled {
            viewport = "\(viewportWidth), initial-scale=1"
        } else {
            viewport = "\(viewportWidth), initial-scale=1, maximum-scale=1, user-scalable=no"
        }
        let extraCSS = config.customCSS.map { "<style>\($0)</style>" } ?? ""
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="\(viewport)">
        <style>\(makeCSS(config: config, isDark: isDark))</style>
        \(extraCSS)
        </head>
        <body>\(content)</body>
        </html>
        """
    }

    // MARK: - CSS

    private static func makeCSS(config: HTMLRichTextConfig, isDark: Bool) -> String {
        let textColor = hexString(config.textColor, isDark: isDark)
        let linkColor = hexString(config.linkColor, isDark: isDark)

        let fontFamily = config.fontFamily
            ?? "-apple-system, \"PingFang SC\", Roboto, \"Helvetica Neue\", Arial, sans-serif"

        let align: String
        switch config.textAlignment {
        case .leading:  align = "left"
        case .center:   align = "center"
        case .trailing: align = "right"
        @unknown default: align = "left"
        }

        // 背景:透明 / 纯色 / 毛玻璃(backdrop-filter 模糊背后透出的宿主内容)。
        // 毛玻璃的基色、对角高光叠成多层 background(高光在上层、色调兜底),
        // 边缘光(内阴影 + 描边)单独挂在 html 上 —— html 的盒恒等于视口,
        // 不受 WebKit 内容偏移影响,边缘光总能对齐组件边缘。
        let background: String
        var backdrop = ""
        var frostedRim = ""
        switch config.effectiveBackgroundStyle {
        case .transparent:
            background = "transparent"
        case .solid(let color):
            background = HTMLRichTextTools.cssColor(color, isDark: isDark)
        case .frosted(let style):
            background = frostedBackgroundCSS(style, isDark: isDark)
            let filter = backdropFilterCSS(style)
            backdrop = "\n            -webkit-backdrop-filter: \(filter);\n            backdrop-filter: \(filter);"
            frostedRim = frostedRimCSS(style)
        }

        let selection: String = config.isTextSelectionEnabled ? "text" : "none"
        let calloutRule = config.isTouchCalloutEnabled
            ? ""
            : "\n            -webkit-touch-callout: none;"

        var css = """
        html, body {
            margin: 0;
            padding: 0;
            background: \(background);\(backdrop)
            -webkit-text-size-adjust: 100%;
            text-size-adjust: 100%;
        }
        body {
            font-family: \(fontFamily);
            font-size: \(config.fontSize)px;
            line-height: \(config.lineHeight);
            color: \(textColor);
            text-align: \(align);
            word-break: break-word;
            overflow-wrap: anywhere;
            -webkit-user-select: \(selection);
            user-select: \(selection);\(calloutRule)
        """
        if let letterSpacing = config.letterSpacing {
            css += "\n            letter-spacing: \(letterSpacing)px;"
        }
        // 内容淡入在 WebView 内部完成(CSS + JS),SwiftUI 侧不对含 WKWebView 的视图做
        // 透明度动画:给 WKWebView 的 layer 加 .opacity 动画会扰动远程合成层,导致已经
        // 画出来的内容(经 takeSnapshot 修好的图片)在渐变途中丢失。
        // body 初始 opacity:0 → JS 加 .hrt-visible 后经 CSS 过渡淡入;opacity 不影响布局与测高。
        css += """
        opacity: 0;
            -webkit-transition: opacity 0.3s ease;
            transition: opacity 0.3s ease;
        }
        body.hrt-visible { opacity: 1; }
        h1, h2, h3, h4, h5, h6, p, li, dt, dd, blockquote {
            line-height: inherit;
        }
        \(imageCSSRules(config: config, isDark: isDark))
        a {
            color: \(linkColor);
            text-decoration: none;
        }
        """
        // 毛玻璃边缘光(内高光 + 描边)单独追加在 html 规则上(见 frostedRimCSS)
        css += frostedRim
        // `-webkit-touch-callout` **不继承**:只对 `<a>` / `<img>` 元素本身生效,
        // 写在 body 上挡不住图片 —— 长按图片仍会弹系统「存储图像/拷贝/共享」菜单。
        // 关闭系统长按菜单时必须用通配符整份覆盖,链接与文档内所有图片才真正不可长按。
        if !config.isTouchCalloutEnabled {
            css += "\n        * {\n            -webkit-touch-callout: none;\n        }"
        }
        // 图片拖拽(长按拽走 / iPadOS 拖到相册等)不属于组件的交互范畴,编辑入口统一禁用。
        css += "\n        img {\n            -webkit-user-drag: none;\n        }"
        return css
    }

    /// 毛玻璃基色:`rgba(色调, tintOpacity × 色调自身alpha)`。
    /// `tintColor` 为 nil 时按深浅色自动取白 / 近黑,nil 表示「跟随系统」。
    /// 半透明基色是毛玻璃的前提 —— 完全不透会盖死背后的宿主内容。
    private static func frostedTintCSS(_ style: HTMLRichTextFrostedStyle, isDark: Bool) -> String {
        let tint = style.tintColor ?? (isDark ? Color(red: 0.06, green: 0.06, blue: 0.08) : .white)
        return HTMLRichTextTools.cssColor(tint, opacity: style.tintOpacity, isDark: isDark)
    }

    /// 毛玻璃的多层 `background` 值:`[对角高光渐变] , 基色`。
    /// 高光渐变按 H5 高级毛玻璃的 135° 对角线从白渐隐到极淡黑,叠在基色之上,
    /// 给出「晶莹剔透」的上光感;`shineOpacity = 0` 时只保留基色。
    private static func frostedBackgroundCSS(_ style: HTMLRichTextFrostedStyle, isDark: Bool) -> String {
        let tint = frostedTintCSS(style, isDark: isDark)
        guard style.shineOpacity > 0 else { return tint }
        let hi = min(1, max(0, style.shineOpacity))
        let mid = hi * 0.12     // 中段近透明,渐变主过渡
        let dark = hi * 0.12    // 尾部极淡黑,增加玻璃厚度感
        let gradient = String(
            format: "linear-gradient(135deg, rgba(255,255,255,%.2f) 0%%, rgba(255,255,255,%.2f) 50%%, rgba(0,0,0,%.2f) 100%%)",
            hi, mid, dark
        )
        return "\(gradient), \(tint)"
    }

    /// 毛玻璃块的边缘光:顶部内高光 + 底部内微光 + 1px 发丝描边(用 `0 0 0 1px`
    /// 的 box-shadow 充当描边,不占布局、不挤压内容)。
    /// 挂在 `html` 上而非 `body`:html 的盒恒等于视口尺寸,WebKit 在布局往返中
    /// 给 body 累积的顶部偏移(≈20px)不会把边缘光带偏,边缘光总能贴住组件边缘。
    /// `rimOpacity = 0` 时返回空(不输出此规则)。
    private static func frostedRimCSS(_ style: HTMLRichTextFrostedStyle) -> String {
        let o = min(1, max(0, style.rimOpacity))
        guard o > 0 else { return "" }
        let edge = String(format: "%.2f", o)
        let bottom = String(format: "%.2f", o * 0.4)
        return "\n        html {\n            box-shadow: inset 0 1px 0 rgba(255,255,255,\(edge)),\n                        inset 0 -1px 0 rgba(255,255,255,\(bottom)),\n                        0 0 0 1px rgba(255,255,255,\(o));\n        }"
    }

    /// 毛玻璃滤镜片段:`blur(半径)[ saturate(倍数)]`。
    private static func backdropFilterCSS(_ style: HTMLRichTextFrostedStyle) -> String {
        var filter = "blur(\(cssNumber(style.blurRadius)))px"
        if let saturation = style.saturationAmount {
            filter += " saturate(\(cssNumber(saturation)))"
        }
        return filter
    }

    /// 把 CGFloat 转成不含多余小数位的 CSS 数值(20.0 → "20")。
    private static func cssNumber(_ value: CGFloat) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
    }

    /// 按全局 `imageStyle` 生成文档级 `img {}` 规则(单段 `.pic` 再用行内样式覆盖)。
    private static func imageCSSRules(config: HTMLRichTextConfig, isDark: Bool) -> String {
        let display = "display: inline-block"
        let css = HTMLRichTextTools.inlineCSS(for: config.imageStyle, isDark: isDark)
        let body = css.isEmpty ? display : "\(display); \(css)"
        // translateZ(0) 把每张图片提升为独立合成层:避免图片与正文共享同一 tile,
        // 从首帧就让它走「独立层合成」而非「tile 内联绘制」—— 后者正是 WebKit 首帧
        // 漏绘的高发路径(图片解码完成但 tile 已按「无图」提交,再滚动/重排才补上)。
        return "img {\n            \(body);\n            -webkit-transform: translateZ(0);\n            transform: translateZ(0);\n        }"
    }

    // MARK: - JS 桥

    /// 注入到页面里的 JS 桥:
    /// 1. 尺寸上报 —— 内容高度/宽度变化时回传,驱动 SwiftUI 侧自适应高度;
    /// 2. 点击拦截 —— 命中 `<a>` 或带 `data-tap` 的元素时回传,且阻止 `<a>` 自身跳转。
    ///
    /// viewport 同步说明:`width=device-width` 会按照**设备全屏宽度**排版,而组件的
    /// WebView 通常比屏幕窄(卡片内),两者不一致会导致横向溢出与高度反馈放大,
    /// 因此由 Swift 侧把 WebView 真实宽度写进 `window.__htmlRichTextWidth`,这里据此
    /// 把 viewport 宽度改为容器宽度,保证按真实宽度排版后再测高。
    static let javaScript: String = """
    (function () {
      var NS = "\(bridgeName)";
      function post(obj) {
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[NS]) {
            window.webkit.messageHandlers[NS].postMessage(obj);
          }
        } catch (e) {}
      }
      // 由 Swift 侧在 WebView 完成布局后写入容器宽度(单位 pt / CSS px)。
      window.__htmlRichTextWidth = 0;

      // 把 viewport 的宽度改成容器宽度,使排版宽度 = 真实显示宽度。
      // 只改动 width 一项,保留 maximum-scale / user-scalable 等既有配置。
      // 容器宽度变化时(如旋转),Swift 会重新推送并触发本方法更新。
      function syncViewport(width) {
        var m = document.querySelector("meta[name=viewport]");
        if (!m || !(width > 0)) return;
        var content = m.getAttribute("content") || "";
        var target = content.replace(/width=[^,]*/, "width=" + Math.floor(width));
        if (target !== content) m.setAttribute("content", target);
      }

      var lastH = -1, lastW = -1;
      function reportSize() {
        var d = document.documentElement, b = document.body;
        var w = window.__htmlRichTextWidth || 0;
        if (!(w > 0)) return;               // 还没拿到真实容器宽度,跳过
        syncViewport(w);                    // 保证按容器宽度排版
        // 高度只测内容本身,不能取 documentElement.scrollHeight —— html 是初始包含块,
        // 其 scrollHeight「至少等于视口高度」:当首帧 frame 比内容高(预估高度偏大 /
        // 固定容器设得太高)时会把视口高度误报到内容高度,导致「内容比预估矮」时组件
        // 永远不按实际内容收身(高度被黏在预估值上)。
        // body.getBoundingClientRect().bottom 是内容实际落到的视口坐标底部:当 WebKit
        // 因布局往返给页面累积了一小段顶部内边距/回弹时,它比 scrollHeight 更接近
        // 「把内容完整显示出来所需的高度」,取两者最大值避免最后一行被裁。
        var h = Math.max(b ? b.scrollHeight : 0, b ? b.offsetHeight : 0);
        var bodyBottom = (b && b.getBoundingClientRect) ? b.getBoundingClientRect().bottom : 0;
        if (bodyBottom > h) h = Math.ceil(bodyBottom);
        h += 1;   // 1px 兜底:避免内容底正好落在整数像素边界上被裁掉
        var ww = Math.max(d ? d.scrollWidth : 0, b ? b.scrollWidth : 0);
        // 与上次上报完全相同则跳过,避免高度自适应过程中反复 postMessage 驱动 SwiftUI 重绘
        if (h === lastH && ww === lastW) return;
        lastH = h; lastW = ww;
        // 拿到首个有效尺寸后才放行淡入(与 SwiftUI 的就绪时机对齐 —— 先测准高度
        // 再显示,避免内容已出现但容器高度还没跟上引起跳动);body 初始 opacity:0。
        if (!hrtShown && h > 0) showBody();
        post({type: "height", height: h});
        post({type: "width", width: ww});
      }
      window.__htmlRichTextReportSize = reportSize;

      // 内容淡入:body 初始 opacity:0,加 .hrt-visible 类触发 CSS 渐变(0.3s)。
      // 放在 WKWebView 内完成,而不是 SwiftUI 对 WebView 视图做 .opacity 动画 ——
      // SwiftUI 的透明度动画会扰动 WebKit 远程合成层,是「图片已画出但中途又消失」的根因。
      // WebKit 首帧漏绘类似的坑:在宿主视图层上动画透明度也会逼迫合成器重新提交 tile。
      var hrtShown = false;
      function showBody() {
        if (hrtShown || !document.body) return;
        hrtShown = true;
        document.body.classList.add("hrt-visible");
      }

      function describe(el) {
        var aa = el.attributes, data = {}, i, n;
        for (i = 0; i < aa.length; i++) {
          n = aa[i].name;
          if (n.indexOf("data-") === 0) data[n.substring(5)] = aa[i].value;
        }
        return {
          id: el.id || null,
          tag: (el.tagName || "").toLowerCase(),
          classes: (el.className && el.className.split) ? el.className.split(/\\s+/).filter(Boolean) : [],
          data: data,
          text: (el.innerText || "").trim() || null
        };
      }

      // 长按:命中带 `data-long-press` 的元素(如图片),按下 450ms 内未移动 / 松开即上报;
      // 上报后抑制随后同一次松手触发的 click,避免「长按」后再多报一次「点击」。
      var longPressTimer = null, longPressTarget = null, suppressClickUntil = 0;
      function clearLongPress() {
        if (longPressTimer) { clearTimeout(longPressTimer); longPressTimer = null; }
        longPressTarget = null;
      }
      document.addEventListener("touchstart", function (e) {
        if (e.touches.length !== 1) return;
        var t = e.target;
        var lp = t && t.closest ? t.closest("[data-long-press]") : null;
        if (!lp) return;
        longPressTarget = lp;
        longPressTimer = setTimeout(function () {
          longPressTimer = null;
          var info = describe(longPressTarget);
          info.type = "longPress";
          suppressClickUntil = Date.now() + 600;
          post(info);
        }, 450);
      }, true);
      document.addEventListener("touchmove", clearLongPress, true);
      document.addEventListener("touchend", clearLongPress, true);
      document.addEventListener("touchcancel", clearLongPress, true);

      document.addEventListener("click", function (e) {
        // 长按刚上报过:吞掉松手那一下产生的 click
        if (Date.now() < suppressClickUntil) { suppressClickUntil = 0; return; }
        var t = e.target;
        var a = t && t.closest ? t.closest("a") : null;
        if (a) {
          e.preventDefault();
          var ai = describe(a);
          ai.type = "tap";
          ai.url = a.href || null;
          post(ai);
          return;
        }
        var c = t && t.closest ? t.closest("[data-tap]") : null;
        if (c) {
          var ci = describe(c);
          ci.type = "tap";
          ci.url = null;
          post(ci);
        }
      });

      function whenReady(fn) {
        if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn, false);
        else fn();
      }

      whenReady(function () {
        reportSize();
        // DOMContentLoaded 时 WebView 可能还没被 SwiftUI 摆到最终宽度,
        // 一次性算出的高度会错(按默认视口宽度排版 → 高度虚高)。
        // 再排两轮:等布局稳定后按真实宽度重新测一次。
        setTimeout(reportSize, 100);
        setTimeout(reportSize, 300);
      });
      window.addEventListener("resize", reportSize, false);
      // 捕获阶段监听所有资源加载(如图片),确保懒加载/慢图加载后高度准确
      document.addEventListener("load", reportSize, true);

      // 兜底:万一桥接没跑起来(宽度没推下来,reportSize 一直拿不到有效 w),
      // 过 500ms 也算内容可见 —— 不能因为 JS 桥故障让整页一直透明。
      whenReady(function () {
        setTimeout(showBody, 500);
      });

      // WebKit 合成器偶发漏绘:图片已解码(naturalWidth>0)但所在 tile 按「无图」提交,
      // 滚动或请求一帧完整渲染才会触发 WebContent 进程重栅格化。setNeedsDisplay /
      // transform 只动 UI 进程的 GPU 合成层,够不到远程合成器,所以这里在每张图
      // load / 整页 load 后向 Swift 侧发一次轻量通知(imgpaint),由 Coordinator 调
      // takeSnapshot 强制整页重新光栅化。不发「重绘指令」以外的任何消息、不改变
      // DOM / 布局 / 样式,因此不会产生可见闪断或跳动。
      var lastNudge = 0;
      function nudgePaint() {
        var n = Date.now();
        if (n - lastNudge < 300) return;   // 多图并发只 nud 一次
        lastNudge = n;
        post({ type: "imgpaint" });
      }
      window.addEventListener("load", function () {
        nudgePaint();
        reportSize();
        // 整页资源完成后兜底再 nud 两轮(慢解码 / 后到达的 load)
        setTimeout(function () { nudgePaint(); }, 600);
        setTimeout(function () { nudgePaint(); reportSize(); }, 1500);
      });
      // 每张图片解码完成立即 nud,专门覆盖「正文文字里插一张图」的单图场景
      document.addEventListener("load", function (e) {
        var t = e.target;
        if (t && t.tagName === "IMG") { nudgePaint(); }
      }, true);

      if (window.MutationObserver) {
        // mutation 往往成串到来(布局/图片加载),防抖合并成一次测量,避免 JS ↔ Swift 风暴
        var obsTimer = null;
        function scheduleReport() {
          if (obsTimer) return;
          obsTimer = setTimeout(function () { obsTimer = null; reportSize(); }, 50);
        }
        var obs = new MutationObserver(function () { scheduleReport(); });
        whenReady(function () {
          if (document.body) {
            obs.observe(document.body, {
              childList: true, subtree: true, attributes: true, characterData: true
            });
          }
        });
      }

      // —— 图片加载失败兜底 ——
      // WebKit 偶发不把图片画上去,失败形态有两种,都要捞:
      //  a) complete 但 naturalWidth==0(加载"结束"但没解出宽度,可能没触发 error);
      //  b) 长时间停在 loading(请求被吞掉:不 complete 也不 error)。
      // 重试手段:普通 URL 用「src 追加新查询参数」强制 WebKit 重新发请求(path 不变,
      // scheme handler 按 path 取文件,仍命中同一张本地图);已内联的 data: URI 无请求
      // 可重发,用「克隆替换节点」强制重新解码。最多连续 3 次,超过 8s 重置计数。
      (function imgGuard() {
        var wm = typeof WeakMap !== "undefined" ? new WeakMap() : null;
        // 每张 img 的状态:{retries, lastTry, seenPending}
        function st(img) {
          if (!wm) return null;
          var s = wm.get(img);
          if (!s) { s = { retries: 0, lastTry: 0, seenPending: 0 }; wm.set(img, s); }
          return s;
        }
        function canRetry(s) {
          if (!s) return true;
          if (s.retries >= 3 && Date.now() - s.lastTry < 8000) return false;
          return true;
        }
        function retry(img, reason) {
          var s = st(img), now = Date.now();
          if (!canRetry(s)) return;
          var src = img.getAttribute("src") || "";
          if (!src) return;
          if (s) {
            if (now - s.lastTry > 8000) s.retries = 0;
            s.retries += 1; s.lastTry = now; s.seenPending = 0;
          }
          if (src.indexOf("data:") === 0) {
            // 内联 data: URI 没有请求可重发;解码失败时克隆替换节点强制重新解码
            //(新元素 → 新的 ImageLoader → 重新 decode)。父容器(data-tap 等)不受影响。
            var parent = img.parentNode;
            if (parent && parent.replaceChild) {
              parent.replaceChild(img.cloneNode(true), img);
            }
            return;
          }
          var sep = src.indexOf("?") >= 0 ? "&" : "?";
          img.src = src + sep + "imgRetry=" + now;   // 换新 URL 强制重发
        }
        // error 事件(didFail / 解码失败)立即重试
        document.addEventListener("error", function (e) {
          var t = e.target;
          if (t && t.tagName === "IMG") retry(t, "error");
        }, true);
        function isBad(img) {
          if (img.naturalWidth > 0) {
            var s0 = st(img);
            if (s0) s0.seenPending = 0;   // 已健康:复位观察期
            return false;
          }
          return true;
        }
        function nextAt(ms, cur) { return cur === null || ms < cur ? ms : cur; }
        // 连续监控:随时还有「待观察 / 待重试 / 到点再试」的图片就按下一截止时间自己重排,
        // 全部健康后自动停止(不空转)。覆盖形态 a(失败态)与 b(卡在 loading)。
        var timer = null;
        function scan() {
          var imgs = document.getElementsByTagName("img");
          var nextIn = null, now = Date.now();
          for (var i = 0; i < imgs.length; i++) {
            var img = imgs[i];
            if (!isBad(img)) continue;
            var s = st(img);
            if (img.complete) {                       // a.失败态(complete 但没宽度)
              if (canRetry(s)) { retry(img, "sweep"); nextIn = nextAt(800, nextIn); }
              else { nextIn = nextAt(Math.max(1, (s.lastTry || now) + 8000 - now), nextIn); }
              continue;
            }
            // b.卡在加载中:先观察 1.2s,仍不动再重试
            if (!s || s.seenPending === 0) { if (s) s.seenPending = now; nextIn = nextAt(1200, nextIn); continue; }
            if (now - s.seenPending >= 1200) {
              if (canRetry(s)) { retry(img, "stuck"); nextIn = nextAt(800, nextIn); }
              else { nextIn = nextAt(Math.max(1, (s.lastTry || now) + 8000 - now), nextIn); }
            } else {
              nextIn = nextAt(Math.max(1, s.seenPending + 1200 - now), nextIn);
            }
          }
          timer = nextIn === null ? null : setTimeout(scan, nextIn);
        }
        whenReady(function () { setTimeout(scan, 500); });
        window.addEventListener("load", function () { if (!timer) setTimeout(scan, 400); }, false);
      })();
    })();
    """

    // MARK: - 颜色 -> HEX

    /// 把 SwiftUI Color(含动态系统色)按目标深浅色解析成 HEX 字符串。
    /// 与公共工具 `HTMLRichTextTools.hexString(from:isDark:)` 共用同一套实现。
    static func hexString(_ color: Color, isDark: Bool) -> String {
        HTMLRichTextTools.hexString(from: color, isDark: isDark)
    }
}