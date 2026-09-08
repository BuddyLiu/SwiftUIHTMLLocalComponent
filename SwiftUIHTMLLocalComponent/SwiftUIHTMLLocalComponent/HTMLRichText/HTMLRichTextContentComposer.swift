//
//  HTMLRichTextContentComposer.swift
//  SwiftUIHTMLLocalComponent
//
//  把「纯文本 + 链式标记(items)」编译成组件内部使用的 HTML 片段:
//  · 普通文本做 HTML 转义,防止用户文案被当作标签注入;
//  · `.click` 标记 → `<a href data-tap-index>`(既有 JS 桥上报 url,tap-index 供 Swift 反查 item);
//  · `.picture` 标记 → `<div data-tap data-tap-index><img src style>`(点按图片触发 action);
//  · 每个标记「替换所有出现」;后到的标记跳过已被前面标记占用的区域。
//

import Foundation
import SwiftUI

enum HTMLRichTextContentComposer {

    /// 编译整段文本为 HTML 片段(可空 items,也可多处命中)。
    static func compose(text: String, items: [HTMLRichTextItem], config: HTMLRichTextConfig, isDark: Bool) -> String {
        guard !items.isEmpty else { return HTMLRichTextTools.htmlEscape(text) }

        // 1. 按 items 顺序扫描,记录命中区间(已占用的区域后续跳过)。
        var reserved: [Range<String.Index>] = []
        var parts: [(span: Range<String.Index>, html: String)] = []

        for (index, item) in items.enumerated() {
            let match = item.match
            guard !match.isEmpty else { continue }
            var cursor = text.startIndex
            while cursor < text.endIndex,
                  let range = text.range(of: match, range: cursor..<text.endIndex) {
                if !reserved.contains(where: { $0.overlaps(range) }) {
                    reserved.append(range)
                    parts.append((range, html(for: item, index: index, config: config, isDark: isDark,
                                              escapedMatch: HTMLRichTextTools.htmlEscape(String(text[range])))))
                }
                cursor = range.upperBound
            }
        }

        // 2. 按位置升序拼装:普通区间转义输出,命中区间输出替换 HTML。
        var out = ""
        var cursor = text.startIndex
        for part in parts.sorted(by: { $0.span.lowerBound < $1.span.lowerBound }) {
            if part.span.lowerBound > cursor {
                out += HTMLRichTextTools.htmlEscape(String(text[cursor..<part.span.lowerBound]))
            }
            out += part.html
            cursor = part.span.upperBound
        }
        if cursor < text.endIndex {
            out += HTMLRichTextTools.htmlEscape(String(text[cursor..<text.endIndex]))
        }
        return out
    }

    // MARK: - 片段生成

    private static func html(for item: HTMLRichTextItem, index: Int, config: HTMLRichTextConfig,
                             isDark: Bool, escapedMatch: String) -> String {
        switch item {
        case .click(_, let link, let style, _):
            let href = attrs(link)
            return "<a href=\"\(href)\" data-tap-index=\"\(index)\"\(cssAttribute(HTMLRichTextTools.inlineCSS(for: style ?? .plain, isDark: isDark)))>\(escapedMatch)</a>"

        case .picture(_, let source, let style, _, _):
            let src = attrs(source)
            let merged = config.imageStyle.merged(with: style)

            // 交互属性:点击默认开启(data-tap),长按默认关闭(data-long-press);
            // 后到的标记仍带 data-tap-index 供 Swift 反查 section(点按 / 长按共用)。
            var interaction = " data-tap-index=\"\(index)\""
            if merged.isTapEnabled ?? true { interaction += " data-tap" }
            if merged.isLongPressEnabled ?? false { interaction += " data-long-press" }

            // 图片行内样式(公共 CSS:尺寸/圆角/适配/边框/背景/外边距)+ 排布用的 display
            let baseCSS = HTMLRichTextTools.inlineCSS(for: merged, isDark: isDark)
            let imgCSS = cssAttribute(baseCSS.isEmpty ? "display: inline-block" : baseCSS + "; display: inline-block")

            // 排布方式(默认内联):内联嵌文字流;块级独占一行按对齐摆放;浮动让文字环绕
            switch merged.layout ?? .inline {
            case .inline:
                return "<span\(interaction)>" + "<img src=\"\(src)\"\(imgCSS)></span>"
            case .block:
                return "<div\(interaction)\(alignmentCSS(merged.alignment))>" + "<img src=\"\(src)\"\(imgCSS)></div>"
            case .leftFloat:
                return "<div\(interaction) style=\"float: left\">" + "<img src=\"\(src)\"\(imgCSS)></div>"
            case .rightFloat:
                return "<div\(interaction) style=\"float: right\">" + "<img src=\"\(src)\"\(imgCSS)></div>"
            }
        }
    }

    private static func cssAttribute(_ css: String) -> String {
        css.isEmpty ? "" : " style=\"\(css)\""
    }

    private static func alignmentCSS(_ alignment: HorizontalAlignment?) -> String {
        guard let alignment else { return "" }
        switch alignment {
        case .leading:  return " style=\"text-align: left\""
        case .center:   return " style=\"text-align: center\""
        case .trailing: return " style=\"text-align: right\""
        default:        return ""
        }
    }

    // MARK: - 转义

    /// 属性值转义(与正文转义同一套,再配合双引号转义防止属性逃逸)。
    private static func attrs(_ s: String) -> String {
        HTMLRichTextTools.htmlEscape(s)
    }
}