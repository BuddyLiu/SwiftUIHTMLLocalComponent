//
//  HTMLTapContext.swift
//  SwiftUIHTMLLocalComponent
//
//  点击回调携带的信息模型。
//

import Foundation

/// 点击回调数据:命中 `<a>` 时 `url` 非空;命中带 `data-tap` 属性自定义元素时,
/// `url` 为 nil,可读取 `dataAttributes` / `elementID` 等做业务区分。
public struct HTMLTapContext {
    /// 链接地址(命中 `<a href>`),否则为 nil。
    public let url: URL?
    /// 元素 `id` 属性。
    public let elementID: String?
    /// 命中元素标签名(小写)。
    public let tagName: String?
    /// 元素 class 列表。
    public let classes: [String]
    /// 元素上所有 `data-*` 属性(去掉 `data-` 前缀)。
    public let dataAttributes: [String: String]
    /// 元素文本内容。
    public let text: String?

    public init(
        url: URL?,
        elementID: String?,
        tagName: String?,
        classes: [String],
        dataAttributes: [String: String],
        text: String?
    ) {
        self.url = url
        self.elementID = elementID
        self.tagName = tagName
        self.classes = classes
        self.dataAttributes = dataAttributes
        self.text = text
    }
}