//
//  HTMLRichTextTools.swift
//  SwiftUIHTMLLocalComponent
//
//  HTMLRichText 的配套公共工具类(全部为静态方法,无状态):
//  · 样式快捷构造(固定尺寸图片样式、链接样式等);
//  · 预估高度计算(纯文本 / HTML,用于 `estimatedHeight` 的首帧初值);
//  · 高度缓存读写(查历史测量 / 清空);
//  · 文本 / 颜色 / 行内 CSS 等常用快捷方法(与组件内部同一套规则)。
//

import Foundation
import SwiftUI
import UIKit

/// `HTMLRichText` 的配套公共工具。
///
/// 目的:让接入方**少写重复的样板代码**、并复用组件内部的同一套规则。
/// 典型用法:
/// ```swift
/// // 首次打开时按正文实测一个预估高度,先撑住位置、避免跳动
/// let estimate = HTMLRichTextTools.estimatedTextHeight(
///     text: "这是一段富文本…",
///     config: .init(fontSize: 16, lineHeight: 1.7),
///     containerWidth: 342
/// )
/// HTMLRichText(content: "这是一段富文本…", estimatedHeight: estimate)
/// ```
public enum HTMLRichTextTools {

    // MARK: - 样式快捷构造

    /// 由**固定尺寸**快捷构造图片样式:限宽 + 等高,可再叠加圆角 / 适配方式 / 对齐。
    /// 等价于 `HTMLRichTextImageStyle(maxWidth: size.width, height: size.height, ...)`。
    public static func imageStyle(
        fixed size: CGSize,
        cornerRadius: CGFloat? = nil,
        contentMode: ContentMode? = nil,
        alignment: HorizontalAlignment? = nil
    ) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(
            maxWidth: size.width,
            height: size.height,
            cornerRadius: cornerRadius,
            contentMode: contentMode,
            alignment: alignment
        )
    }

    /// 由**边长**快捷构造正方形图片样式(限宽 + 等高),可叠加圆角(如头像)。
    public static func squareImageStyle(side: CGFloat, cornerRadius: CGFloat? = nil) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(maxWidth: side, height: side, cornerRadius: cornerRadius)
    }

    /// 按需组合的链接样式(常见情况直接用预设 `.plain / .underlined / .bold` 即可)。
    public static func linkStyle(
        color: Color? = nil,
        underlined: Bool? = nil,
        fontWeight: Font.Weight? = nil
    ) -> HTMLRichTextLinkStyle {
        HTMLRichTextLinkStyle(color: color, isUnderlined: underlined, fontWeight: fontWeight)
    }

    // MARK: - 预估高度

    /// 估算一段**纯文本**在目标容器宽度下的高度(pt)。
    /// 按 `config` 的字号 / 行高 / 字距 / 对齐用系统文本布局实测,
    /// 适合作为 `config.estimatedHeight` 或 `.estimatedHeight(_:)` 的首帧初值——
    /// 「首次真正打开」新内容时也能先占住位置,收到 JS 真实测量后平滑替换。
    ///
    /// - Note: 只估算文字本身;正文里通过 `.imageItem` 插入的**图片**高度不包含在内,
    ///   图文混排场景建议用 `estimatedHeight(forHTML:config:containerWidth:)`(基于编译后的片段)。
    public static func estimatedTextHeight(
        text: String,
        config: HTMLRichTextConfig,
        containerWidth: CGFloat
    ) -> CGFloat {
        let font = resolvedFont(from: config.fontFamily, size: config.fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = max(0, config.fontSize * (config.lineHeight - 1))
        paragraph.alignment = nsTextAlignment(config.textAlignment)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
            .kern: config.letterSpacing ?? 0
        ]
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: max(1, containerWidth), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(bounds.height)
    }

    /// 估算一段 **HTML** 的粗略高度(pt):剥掉标签后按 `config` 排版测量文字,
    /// 再为每个 `<img>` 加上一张图的高度预算(优先 `imageStyle.height`,否则按 6:4 宽高比估算)。
    /// 适合做首帧预估;若此前渲染过同内容,优先用 `cachedHeight(...)` 拿到精确值。
    public static func estimatedHeight(
        forHTML html: String,
        config: HTMLRichTextConfig,
        containerWidth: CGFloat
    ) -> CGFloat {
        // 1. 去掉标签、还原常见实体后,按纯文本规则测量正文高度。
        let stripped = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        let height = estimatedTextHeight(text: stripped, config: config, containerWidth: containerWidth)

        // 2. 每张图加一个高度预算(图片高度未知,按合理比例粗估)。
        let imageCount = html.components(separatedBy: "<img").count - 1
        guard imageCount > 0 else { return height }
        let budget = config.imageStyle.height
            ?? min(config.imageStyle.maxWidth ?? containerWidth, containerWidth) * 0.6
        return height + CGFloat(imageCount) * budget
    }

    // MARK: - 高度缓存

    /// 读取历史缓存的高度:同内容(HTML/文本指纹相同)+ 同容器宽度下**最近一次的真实测量**。
    /// 命中说明此前渲染过一次,可直接作为首帧高度,避免「0 → 真实高度」跳变。
    public static func cachedHeight(
        forHTML html: String,
        config: HTMLRichTextConfig,
        colorScheme: ColorScheme,
        containerWidth: CGFloat
    ) -> CGFloat? {
        let key = HTMLRichTextView.renderFingerprint(html: html, config: config, colorScheme: colorScheme)
        return HTMLRichTextHeightCache.height(for: key, width: Int(containerWidth))
    }

    /// 清空进程内的高度缓存(正常使用无需调用;需要强制重新测量内容高度时可用)。
    public static func clearHeightCache() {
        HTMLRichTextHeightCache.reset()
    }

    // MARK: - 文本与颜色

    /// 对一段普通文本做 HTML 实体转义(与组件内部同一套,防止文案被当作标签注入)。
    public static func htmlEscape(_ text: String) -> String {
        var out = text
        let replacements = [
            ("&", "&amp;"),
            ("<", "&lt;"),
            (">", "&gt;"),
            ("\"", "&quot;"),
            ("'", "&#39;")
        ]
        for (key, value) in replacements {
            out = out.replacingOccurrences(of: key, with: value)
        }
        return out
    }

    /// SwiftUI `Color`(含动态系统色)按目标深浅色解析成 HEX 字符串,用于自定义 CSS / 行内样式。
    public static func hexString(from color: Color, isDark: Bool = false) -> String {
        let c = cssComponents(color, isDark: isDark)
        return String(format: "#%02X%02X%02X", Int(c.r * 255), Int(c.g * 255), Int(c.b * 255))
    }

    /// 把 Color 解析成可直接写进 CSS 的颜色值:`#RRGGBB`(不透明时)或 `rgba(r,g,b,a)`(带透明度时)。
    /// 适合用作边框 / 背景等需要透明度的行内样式。
    public static func cssColor(_ color: Color, isDark: Bool = false) -> String {
        let c = cssComponents(color, isDark: isDark)
        if c.a >= 0.999 {
            return String(format: "#%02X%02X%02X", Int(c.r * 255), Int(c.g * 255), Int(c.b * 255))
        }
        return String(format: "rgba(%d,%d,%d,%.2f)", Int(c.r * 255), Int(c.g * 255), Int(c.b * 255), min(1, c.a))
    }

    /// 解析 Color(含动态系统色)按目标深浅色得到 RGBA 分量(0...1)。
    private static func cssComponents(_ color: Color, isDark: Bool) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let traits = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
        let uiColor = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (r, g, b, a)
        }
        var w: CGFloat = 0, alpha: CGFloat = 0
        if uiColor.getWhite(&w, alpha: &alpha) {
            return (w, w, w, alpha)
        }
        return (0, 0, 0, 1)
    }

    /// 把 `#RGB` / `#RRGGBB` / `#RRGGBBAA` 形式的十六进制颜色字符串解析成 SwiftUI `Color`。
    /// 例如 `color(hex: "#E53935")` 可直接作为 `textColor / linkColor / backgroundColor`。
    public static func color(hex: String) -> Color {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var hexValue: UInt64 = 0
        guard Scanner(string: value).scanHexInt64(&hexValue) else { return .clear }
        let r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat
        switch value.count {
        case 3:
            r = CGFloat((hexValue >> 8) & 0xF) / 15
            g = CGFloat((hexValue >> 4) & 0xF) / 15
            b = CGFloat(hexValue & 0xF) / 15
            a = 1
        case 6:
            r = CGFloat((hexValue >> 16) & 0xFF) / 255
            g = CGFloat((hexValue >> 8) & 0xFF) / 255
            b = CGFloat(hexValue & 0xFF) / 255
            a = 1
        case 8:
            r = CGFloat((hexValue >> 24) & 0xFF) / 255
            g = CGFloat((hexValue >> 16) & 0xFF) / 255
            b = CGFloat((hexValue >> 8) & 0xFF) / 255
            a = CGFloat(hexValue & 0xFF) / 255
        default:
            return .clear
        }
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    // MARK: - 行内 CSS(编辑原始 HTML 时与组件同一套规则)

    /// 由图片样式生成行内 `style` 片段(与 `.imageItem` / 全局 `imageStyle` 同一套规则)。
    /// 覆盖尺寸 / 圆角 / 适配、内联垂直对齐、外边距(内联时即与相邻文字的间距)、
    /// 背景色、边框等图片样式字段。
    /// 编辑原始 HTML 时可直接拼进 `<img style="…">` 获得一致的呈现。
    public static func inlineCSS(for imageStyle: HTMLRichTextImageStyle, isDark: Bool = false) -> String {
        var mt: CGFloat = 0, mr: CGFloat = 0, mb: CGFloat = 0, ml: CGFloat = 0
        if let margin = imageStyle.margin {
            mt = margin.top ?? 0
            mr = margin.right ?? 0
            mb = margin.bottom ?? 0
            ml = margin.left ?? 0
        }

        var rules: [String] = []
        if let maxWidth = imageStyle.maxWidth {
            rules.append("max-width: \(Int(maxWidth))px")
        } else {
            rules.append("max-width: 100%")
        }
        rules.append("height: \(imageStyle.height.map { "\(Int($0))px" } ?? "auto")")
        if let radius = imageStyle.cornerRadius, radius > 0 {
            rules.append("border-radius: \(Int(radius))px")
        }
        if let mode = imageStyle.contentMode {
            rules.append("object-fit: \(mode == .fit ? "contain" : "fill")")
            rules.append("width: 100%")   // 让 fill/contain 有个确定的盒宽,配合 max-width 生效
        }
        // 内联排布时与同行文字的垂直对齐(顶 / 中 / 底);块级 / 浮动排布忽略。
        if let vertical = imageStyle.verticalAlignment {
            switch vertical {
            case .top:    rules.append("vertical-align: top")
            case .middle: rules.append("vertical-align: middle")
            case .bottom: rules.append("vertical-align: bottom")
            }
        }
        if let width = imageStyle.borderWidth, width > 0, let color = imageStyle.borderColor {
            rules.append("border: \(Int(width))px solid \(cssColor(color, isDark: isDark))")
        }
        if let background = imageStyle.backgroundColor {
            rules.append("background-color: \(cssColor(background, isDark: isDark))")
        }
        rules.append("margin: \(Int(mt))px \(Int(mr))px \(Int(mb))px \(Int(ml))px")
        if imageStyle.borderWidth != nil || imageStyle.backgroundColor != nil || imageStyle.height != nil {
            rules.append("box-sizing: border-box")
        }
        return rules.joined(separator: "; ")
    }

    /// 由链接样式生成行内 `style` 片段(与 `.linkItem(style:)` 同一套规则)。
    public static func inlineCSS(for linkStyle: HTMLRichTextLinkStyle, isDark: Bool = false) -> String {
        var rules: [String] = []
        if let color = linkStyle.color {
            rules.append("color: \(hexString(from: color, isDark: isDark))")
        }
        if let underlined = linkStyle.isUnderlined {
            rules.append("text-decoration: \(underlined ? "underline" : "none")")
        }
        if let weight = linkStyle.fontWeight {
            rules.append("font-weight: \(cssWeight(weight))")
        }
        return rules.joined(separator: "; ")
    }

    // MARK: - 内部小工具

    /// 解析字体族栈(如 "PingFang SC, sans-serif"),取第一个能解析为 UIFont 的名字。
    private static func resolvedFont(from family: String?, size: CGFloat) -> UIFont {
        if let stack = family {
            for rawName in stack.split(separator: ",") {
                let name = rawName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if !name.isEmpty, let font = UIFont(name: name, size: size) {
                    return font
                }
            }
        }
        return .systemFont(ofSize: size)
    }

    private static func nsTextAlignment(_ alignment: TextAlignment) -> NSTextAlignment {
        switch alignment {
        case .leading:  return .left
        case .center:   return .center
        case .trailing: return .right
        @unknown default: return .left
        }
    }

    private static func cssWeight(_ weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight: return "100"
        case .thin:       return "200"
        case .light:      return "300"
        case .regular:    return "400"
        case .medium:     return "500"
        case .semibold:   return "600"
        case .bold:       return "700"
        case .heavy:      return "800"
        case .black:      return "900"
        default:          return "400"
        }
    }
}
