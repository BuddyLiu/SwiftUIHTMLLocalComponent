//
//  HTMLRichTextHeightCache.swift
//  SwiftUIHTMLLocalComponent
//
//  按「内容指纹 + 容器宽度」缓存最近一次测量的内容高度。
//  全新挂载的同内容实例(列表复用、页面来回切换)直接复用缓存的最终高度,
//  避免「先塌缩成 0 → 再跳变到真实高度」的加载闪烁——用户第一眼看到的就是最终样式。
//

import Foundation

/// 启动前的高度缓存(组件内部使用,所有方法仅限主线程调用)。
enum HTMLRichTextHeightCache {

    /// 内容指纹 -> (容器宽度 pt -> 内容高度)。
    private static var store: [String: [Int: CGFloat]] = [:]

    /// 缓存规模上限:指纹数量与每个指纹的宽度分桶数,防止无界增长。
    private static let maxKeys = 64
    private static let maxWidthsPerKey = 4

    /// 读取缓存高度;未命中返回 nil。
    static func height(for key: String, width: Int) -> CGFloat? {
        store[key]?[width]
    }

    /// 写入缓存高度(高度回调本身就在主线程)。
    static func set(_ height: CGFloat, key: String, width: Int) {
        guard height > 0 else { return }
        // 指纹濒临上限时,淘汰最早写入的 key,保持缓存有界。
        if store[key] == nil, store.count >= maxKeys, let oldest = store.keys.first {
            store.removeValue(forKey: oldest)
        }
        var widths = store[key] ?? [:]
        widths[width] = height
        while widths.count > maxWidthsPerKey, let spilled = widths.keys.first {
            widths.removeValue(forKey: spilled)
        }
        store[key] = widths
    }

    /// 仅在演示 / 测试时使用:清空缓存。
    static func reset() {
        store.removeAll()
    }
}