//
//  HTMLRichTextItem.swift
//  SwiftUIHTMLLocalComponent
//
//  声明式内容入口的数据模型:链式标记(.linkItem / .imageItem)以及
//  图片 / 链接的单段样式。普通文本本身不需要任何模型,直接交给编译器。
//

import SwiftUI
import UIKit

/// 图片排布方式(决定图片在正文中的布局位置)。
public enum HTMLRichTextImageLayout {
    /// 内联:图片嵌在文字流中间,随文字流动(引擎默认)。
    case inline
    /// 块级:图片独占一行,按 `alignment`(默认继承正文)对齐。
    case block
    /// 左浮动:图片靠左,右侧文字环绕图文混排。
    case leftFloat
    /// 右浮动:图片靠右,左侧文字环绕图文混排。
    case rightFloat
}

/// **内联图片**与同一行文字的垂直对齐方式(CSS `vertical-align`)。
/// 仅 `layout == .inline`(图片嵌在文字流中)时生效;块级 / 浮动排布下无效。
public enum HTMLRichTextImageVerticalAlignment {
    /// 顶对齐:图片顶端与行内文字顶线对齐。
    case top
    /// 居中对齐:图片垂直中点与行内容器中线对齐。
    case middle
    /// 底对齐:图片底端与行内文字基线对齐(小图标贴文字的常见观感)。
    case bottom
}

/// 图片外边距(单位 pt / CSS px)。全部字段可选,nil = 该侧不设置外边距。
public struct HTMLRichTextImageMargin {

    public var top: CGFloat?
    public var left: CGFloat?
    public var right: CGFloat?
    public var bottom: CGFloat?

    public init(top: CGFloat? = nil, left: CGFloat? = nil, right: CGFloat? = nil, bottom: CGFloat? = nil) {
        self.top = top
        self.left = left
        self.right = right
        self.bottom = bottom
    }

    /// 四周相同外边距。
    public static func all(_ value: CGFloat) -> HTMLRichTextImageMargin {
        HTMLRichTextImageMargin(top: value, left: value, right: value, bottom: value)
    }

    /// 仅水平方向(left / right)。
    public static func horizontal(_ value: CGFloat) -> HTMLRichTextImageMargin {
        HTMLRichTextImageMargin(left: value, right: value)
    }

    /// 仅垂直方向(top / bottom)。
    public static func vertical(_ value: CGFloat) -> HTMLRichTextImageMargin {
        HTMLRichTextImageMargin(top: value, bottom: value)
    }

    /// 无外边距。
    public static let zero = HTMLRichTextImageMargin(top: 0, left: 0, right: 0, bottom: 0)

    /// 字段级合并:用 `override` 的非 nil 字段覆盖 `self`。
    func merged(with override: HTMLRichTextImageMargin?) -> HTMLRichTextImageMargin {
        guard let override else { return self }
        return HTMLRichTextImageMargin(
            top: override.top ?? top,
            left: override.left ?? left,
            right: override.right ?? right,
            bottom: override.bottom ?? bottom
        )
    }
}

/// 图片阴影模型(照片级 API,当前**不参与渲染**)。
/// 图片阴影功能已按需求暂时停用:首帧漏绘 / 视口裁切带来的问题较多,先不移除 API、
/// 待后续恢复。`color/opacity/radius/offsetX/offsetY` 字段仍可读写,但渲染层不会再输出
/// `filter: drop-shadow(...)`。
public struct HTMLRichTextImageShadow {

    /// 阴影颜色,默认黑色。
    public var color: Color = .black
    /// 阴影不透明度(0...1),默认 0.2。
    public var opacity: Double = 0.2
    /// 模糊半径(CSS px),默认 4。
    public var radius: CGFloat = 4
    /// 水平偏移(CSS px,右为正),默认 0。
    public var offsetX: CGFloat = 0
    /// 垂直偏移(CSS px,下为正),默认 2。
    public var offsetY: CGFloat = 2

    public init(
        color: Color = .black,
        opacity: Double = 0.2,
        radius: CGFloat = 4,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 2
    ) {
        self.color = color
        self.opacity = max(0, min(1, opacity))
        self.radius = radius
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

/// 图片样式(**全部字段可选**,nil = 用引擎默认或继承全局 `HTMLRichTextConfig.imageStyle`)。
/// 声明式入口可在 `.imageItem(style:)` 里覆盖个别字段,未覆盖的字段回落到全局配置。
public struct HTMLRichTextImageStyle {

    /// 图片最大宽度(CSS px);nil = 100%(随容器自适应)。
    public var maxWidth: CGFloat?
    /// 图片固定高度(CSS px);nil = 高度自适应。
    public var height: CGFloat?
    /// 圆角半径(CSS px);nil / 0 = 不圆角。
    public var cornerRadius: CGFloat?
    /// 内容适配:`.fit` → `object-fit: contain`,`.fill` → `object-fit: fill`;nil = 不设置。
    public var contentMode: ContentMode?
    /// 水平对齐(块级排布时生效):`.leading/.center/.trailing`;nil = 继承正文对齐。
    public var alignment: HorizontalAlignment?
    /// 排布方式(section-level override):内联 / 块级 / 左浮动 / 右浮动;nil = 引擎默认 `.inline`。
    public var layout: HTMLRichTextImageLayout?
    /// 内联图片与同行文字的**垂直对齐**(CSS `vertical-align`):顶 / 中 / 底;nil = 引擎默认。
    /// 仅 `layout == .inline` 时生效,块级 / 浮动排布忽略该项。
    public var verticalAlignment: HTMLRichTextImageVerticalAlignment?
    /// 外边距;nil = 不设置。内联时左右两边距控制图片与相邻文字的间距。
    public var margin: HTMLRichTextImageMargin?
    /// 背景颜色(透过透明图片可见);nil = 透明。
    public var backgroundColor: Color?
    /// 阴影;nil = 无阴影。⚠️ 当前不参与渲染(功能已临时停用,见 `HTMLRichTextImageShadow`)。
    public var shadow: HTMLRichTextImageShadow?
    /// 边框粗细(CSS px);nil / 0 = 无边框。
    public var borderWidth: CGFloat?
    /// 边框颜色;与 `borderWidth` 同时设置才显示边框。
    public var borderColor: Color?
    /// 是否支持点击(点按触发 action + 通用 `onTap`);nil = 引擎默认开启。
    public var isTapEnabled: Bool?
    /// 是否支持长按(长按触发该段 `onLongPress`);nil = 引擎默认关闭。
    public var isLongPressEnabled: Bool?

    public init(
        maxWidth: CGFloat? = nil,
        height: CGFloat? = nil,
        cornerRadius: CGFloat? = nil,
        contentMode: ContentMode? = nil,
        alignment: HorizontalAlignment? = nil,
        layout: HTMLRichTextImageLayout? = nil,
        verticalAlignment: HTMLRichTextImageVerticalAlignment? = nil,
        margin: HTMLRichTextImageMargin? = nil,
        backgroundColor: Color? = nil,
        shadow: HTMLRichTextImageShadow? = nil,
        borderWidth: CGFloat? = nil,
        borderColor: Color? = nil,
        isTapEnabled: Bool? = nil,
        isLongPressEnabled: Bool? = nil
    ) {
        self.maxWidth = maxWidth
        self.height = height
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
        self.alignment = alignment
        self.layout = layout
        self.verticalAlignment = verticalAlignment
        self.margin = margin
        self.backgroundColor = backgroundColor
        self.shadow = shadow
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.isTapEnabled = isTapEnabled
        self.isLongPressEnabled = isLongPressEnabled
    }

    /// 引擎默认样式(全部字段 nil,跟随引擎默认)。
    public static var `default`: HTMLRichTextImageStyle { HTMLRichTextImageStyle() }

    // MARK: - 常见样式预设

    /// 满宽大图:不限制宽度,随容器自适应(引擎默认)。
    public static let fullWidth = HTMLRichTextImageStyle()

    /// 圆角图(默认 12pt 圆角);可传半径,如 `.rounded(24)`。
    public static func rounded(_ radius: CGFloat = 12) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(cornerRadius: radius)
    }

    /// 正方形缩略图:限宽 + 等高。
    public static func square(_ side: CGFloat) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(maxWidth: side, height: side)
    }

    /// 圆形头像:正方形 + 半径 = 边长一半。
    public static func circle(_ diameter: CGFloat) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(maxWidth: diameter, height: diameter, cornerRadius: diameter / 2)
    }

    /// 小尺寸缩略图(100pt 限宽 + 圆角),适合商品列表图。
    public static var thumbnail: HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(maxWidth: 100, cornerRadius: 8)
    }

    // MARK: - 排布预设

    /// 内联排布:图片嵌在文字流中间(引擎默认,通常无需显式指定)。
    /// 可传垂直对齐方式,如 `.inline(vertical: .middle)` 让图片与同行文字垂直居中。
    public static func inline(
        vertical: HTMLRichTextImageVerticalAlignment? = nil,
        marginLeft: CGFloat? = nil,
        marginRight: CGFloat? = nil
    ) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(layout: .inline, verticalAlignment: vertical,
                               margin: HTMLRichTextImageMargin(left: marginLeft, right: marginRight))
    }

    /// 块级排布:图片独占一行;可传对齐方式(默认继承正文对齐),如 `.block(.center)`。
    public static func block(_ alignment: HorizontalAlignment? = nil) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(alignment: alignment, layout: .block)
    }

    /// 左浮动:图片靠左、右侧文字环绕;默认给右侧留 12pt 间距(`marginRight: 0` 可去掉)。
    public static func floatLeft(marginRight: CGFloat = 12) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(layout: .leftFloat, margin: HTMLRichTextImageMargin(right: marginRight))
    }

    /// 右浮动:图片靠右、左侧文字环绕;默认给左侧留 12pt 间距。
    public static func floatRight(marginLeft: CGFloat = 12) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(layout: .rightFloat, margin: HTMLRichTextImageMargin(left: marginLeft))
    }

    // MARK: - 边框 / 阴影预设

    /// 描边图:边框颜色 + 粗细,可叠加圆角。
    public static func bordered(
        _ color: Color = Color(uiColor: .separator),
        width: CGFloat = 1,
        cornerRadius: CGFloat = 0
    ) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(cornerRadius: cornerRadius, borderWidth: width, borderColor: color)
    }

    /// 阴影图(默认:黑色 0.2 / 半径 4 / 向下偏移 2)。⚠️ 阴影当前不参与渲染(功能临时停用)。
    public static func shadowed(_ shadow: HTMLRichTextImageShadow = HTMLRichTextImageShadow()) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(shadow: shadow)
    }

    /// 卡片图:块级 + 白底 + 圆角 + 细边框 + 上下留白,常见商品/内容卡。
    /// 注意:默认 shadow 字段当前不参与渲染(阴影功能临时停用)。
    public static func card(
        alignment: HorizontalAlignment? = nil,
        cornerRadius: CGFloat = 12,
        borderColor: Color = Color(uiColor: .separator),
        borderWidth: CGFloat = 1,
        backgroundColor: Color = .white,
        shadow: HTMLRichTextImageShadow = HTMLRichTextImageShadow(radius: 8, offsetY: 2)
    ) -> HTMLRichTextImageStyle {
        HTMLRichTextImageStyle(
            cornerRadius: cornerRadius,
            alignment: alignment,
            layout: .block,
            margin: HTMLRichTextImageMargin(top: 6, bottom: 6),
            backgroundColor: backgroundColor,
            shadow: shadow,
            borderWidth: borderWidth,
            borderColor: borderColor
        )
    }

    // MARK: - 组合式便捷方法

    /// 叠加阴影(在现有样式基础上只改阴影字段)。⚠️ 阴影当前不参与渲染(功能临时停用)。
    public func withShadow(_ shadow: HTMLRichTextImageShadow) -> HTMLRichTextImageStyle {
        var copy = self
        copy.shadow = shadow
        return copy
    }

    /// 叠加边框(只改边框字段)。
    public func withBorder(width: CGFloat, color: Color) -> HTMLRichTextImageStyle {
        var copy = self
        copy.borderWidth = width
        copy.borderColor = color
        return copy
    }

    /// 叠加外边距(只改外边距字段)。
    public func withMargin(_ margin: HTMLRichTextImageMargin) -> HTMLRichTextImageStyle {
        var copy = self
        copy.margin = margin
        return copy
    }

    /// 字段级合并:用 `override` 中的非 nil 字段覆盖 `self`,得到最终样式。
    func merged(with override: HTMLRichTextImageStyle?) -> HTMLRichTextImageStyle {
        guard let override else { return self }
        return HTMLRichTextImageStyle(
            maxWidth: override.maxWidth ?? maxWidth,
            height: override.height ?? height,
            cornerRadius: override.cornerRadius ?? cornerRadius,
            contentMode: override.contentMode ?? contentMode,
            alignment: override.alignment ?? alignment,
            layout: override.layout ?? layout,
            verticalAlignment: override.verticalAlignment ?? verticalAlignment,
            margin: override.margin.map { $0.merged(with: margin) } ?? margin,
            backgroundColor: override.backgroundColor ?? backgroundColor,
            shadow: override.shadow ?? shadow,
            borderWidth: override.borderWidth ?? borderWidth,
            borderColor: override.borderColor ?? borderColor,
            isTapEnabled: override.isTapEnabled ?? isTapEnabled,
            isLongPressEnabled: override.isLongPressEnabled ?? isLongPressEnabled
        )
    }
}

/// 链接单段样式(覆盖全局 `linkColor`)。全部字段可选,nil = 沿用全局样式。
public struct HTMLRichTextLinkStyle {

    /// 链接文字颜色;nil = 用全局 `config.linkColor`。
    public var color: Color?
    /// 是否加下划线;nil = 组件默认(无下划线)。
    public var isUnderlined: Bool?
    /// 字重;nil = 继承正文。
    public var fontWeight: Font.Weight?

    public init(
        color: Color? = nil,
        isUnderlined: Bool? = nil,
        fontWeight: Font.Weight? = nil
    ) {
        self.color = color
        self.isUnderlined = isUnderlined
        self.fontWeight = fontWeight
    }

    // MARK: - 常见样式预设

    /// 普通链接:链接色、无下划线、继承字重(引擎默认)。
    public static let plain = HTMLRichTextLinkStyle()

    /// 下划线链接(经典超链接样式)。
    public static let underlined = HTMLRichTextLinkStyle(isUnderlined: true)

    /// 加粗链接。
    public static let bold = HTMLRichTextLinkStyle(fontWeight: .bold)

    /// 加粗 + 下划线(文档 / 标题里的强调链接)。
    public static let boldUnderlined = HTMLRichTextLinkStyle(isUnderlined: true, fontWeight: .bold)

    /// 指定颜色的下划线链接,如 `.underlined(.red)`。
    public static func underlined(_ color: Color) -> HTMLRichTextLinkStyle {
        HTMLRichTextLinkStyle(color: color, isUnderlined: true)
    }

    /// 指定颜色的加粗链接,如 `.bold(.orange)`。
    public static func bold(_ color: Color) -> HTMLRichTextLinkStyle {
        HTMLRichTextLinkStyle(color: color, fontWeight: .bold)
    }
}

/// 声明式链式标记:纯文本里被 `.linkItem` / `.imageItem` 命中的一段 + 命中的回调。
/// 组件内部使用,由 `HTMLRichText` 的链式修饰器逐个追加。
enum HTMLRichTextItem {
    /// 匹配文本渲染为链接,点击触发 action。
    case click(match: String, link: String, style: HTMLRichTextLinkStyle?, action: (String) -> Void)
    /// 匹配文本替换为本地图片,点击触发 action;`onLongPress` 非空且样式开启长按时,长按触发它。
    case picture(match: String, localSource: String, style: HTMLRichTextImageStyle?,
                 action: (String) -> Void, onLongPress: ((String) -> Void)? = nil)

    /// 需要匹配的原文文本。
    var match: String {
        switch self {
        case .click(let match, _, _, _): return match
        case .picture(let match, _, _, _, _): return match
        }
    }

    /// 命中回调(参数:匹配文本)。
    var action: (String) -> Void {
        switch self {
        case .click(_, _, _, let action): return action
        case .picture(_, _, _, let action, _): return action
        }
    }

    /// 长按回调(仅图片段可能有);nil = 未开启长按。
    var onLongPress: ((String) -> Void)? {
        switch self {
        case .click: return nil
        case .picture(_, _, _, _, let onLongPress): return onLongPress
        }
    }
}