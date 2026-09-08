//
//  HTMLRichTextSchemeHandler.swift
//  SwiftUIHTMLLocalComponent
//
//  自定义 URL scheme:`hrtlocal://`。
//  · 主文档路径 `/__index.html` → 返回当前生成的 HTML 文档;
//  · 其它路径 → 从配置的 baseURL 目录读取本地资源(如图片),全程 file 沙箱内,
//    不需要 loadFileURL 的读权限,也不需要临时文件。
//

import Foundation
import WebKit

/// 服务 `hrtlocal://` scheme 的本地资源加载器。
final class HTMLRichTextSchemeHandler: NSObject, WKURLSchemeHandler {

    static let schemeName = "hrtlocal"
    /// 主文档虚拟路径(内部使用)。
    static let indexPath = "/__index.html"

    /// 当前要渲染的完整 HTML 文档(由 HTMLRichTextView.load 更新)。
    var currentDocument: String = ""
    /// 本地资源根目录(由 HTMLRichTextView.load 更新)。
    var baseURL: URL = Bundle.main.bundleURL
    /// 是否把文档内指向本地文件的 `<img src>` 内联成 data: URI(默认开)。
    /// 内联后图片不经过 WKURLSchemeHandler 子资源请求链路——WebKit 偶发取消 /
    /// 漏响应子资源请求会丢图,内联直接绕开这条链路,图片必然出现在文档字节里。
    var inlineImagesEnabled: Bool = true

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            fail(urlSchemeTask, code: NSURLErrorBadURL)
            return
        }

        #if DEBUG
        // 图片内联验证 & 子资源请求追踪:DEBUG 下默认打印(设 HRT_IMG_DBG=0 可关闭)。
        // 内联主防线生效时,非主文档的子资源请求应为 0 条 —— 若打印出图片路径即内联没命中。
        if url.path != Self.indexPath, ProcessInfo.processInfo.environment["HRT_IMG_DBG"] != "0" {
            print("HRT_SUB \(url.path)")
        }
        #endif

        if url.path == Self.indexPath {
            let document = inlineImagesEnabled ? inlineLocalImages(in: currentDocument, baseURL: baseURL) : currentDocument
            #if DEBUG
            if ProcessInfo.processInfo.environment["HRT_IMG_DBG"] != "0" {
                let imgCount = document.components(separatedBy: "<img").count - 1
                let dataCount = document.components(separatedBy: "data:image").count - 1
                print("HRT_DOC inline=\(inlineImagesEnabled) imgs=\(imgCount) dataURI=\(dataCount) rawSrc=\(imgCount - dataCount)")
            }
            #endif
            respond(urlSchemeTask, url: url,
                    data: Data(document.utf8),
                    mimeType: "text/html",
                    encoding: "utf-8")
            return
        }

        // 本地子资源:相对路径解析到 baseURL 目录
        let relativePath = String(url.path.dropFirst())
        let candidate = baseURL.appendingPathComponent(relativePath).standardizedFileURL
        guard candidate.path.hasPrefix(baseURL.standardizedFileURL.path) else {
            fail(urlSchemeTask, code: NSURLErrorFileDoesNotExist)
            return
        }
        guard let data = try? Data(contentsOf: candidate) else {
            fail(urlSchemeTask, code: NSURLErrorFileDoesNotExist)
            return
        }
        respond(urlSchemeTask, url: url, data: data, mimeType: Self.mimeType(for: url))
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // 任务被取消时无需额外处理:只要确保每条任务只响应一次。
    }

    // MARK: - 工具

    /// 把文档里 `<img src>` 指向**本地文件**的引用内联成 `data:` URI。
    ///
    /// 只处理「无 scheme、相对 baseURL 解析到存在的文件」的 src;`data:` / `blob:` /
    /// `http(s):` 等带 scheme 的值、CSS `url()`、其它标签一律不动。内联后图片随文档
    /// 一起返回,WebKit 在解析阶段直接解码,不再发子资源请求。
    private func inlineLocalImages(in html: String, baseURL: URL) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"(<img\b[^>]*?src\s*=\s*)("([^"]*)"|'([^']*)'|([^\s>]+))"#,
            options: [.caseInsensitive]
        ) else { return html }

        let ns = html as NSString
        var out = ""
        var cursor = 0
        for match in regex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            // 捕获组:1 前缀,2/4 带引号的完整值,3/5 引号内值,6 无引号值 —— 取纯值组
            let valueRange: NSRange
            if match.range(at: 3).location != NSNotFound { valueRange = match.range(at: 3) }
            else if match.range(at: 5).location != NSNotFound { valueRange = match.range(at: 5) }
            else { valueRange = match.range(at: 6) }
            let value = ns.substring(with: valueRange)
            if let uri = dataURI(for: value, baseURL: baseURL) {
                out += ns.substring(with: match.range(at: 1))
                out += "\"\(uri)\""
            } else {
                out += ns.substring(with: match.range)
            }
            cursor = match.range.location + match.range.length
        }
        out += ns.substring(from: cursor)
        return out
    }

    /// 解析一个 img src 为 data: URI;无法本地解析返回 nil。
    private func dataURI(for src: String, baseURL: URL) -> String? {
        guard !src.isEmpty else { return nil }
        let lower = src.lowercased()
        if lower.hasPrefix("data:") || lower.hasPrefix("blob:") { return nil }
        if lower.contains("://") { return nil }   // 带 scheme 的网络/自定义 URL 不动
        // 剥掉 query / fragment(与子资源按 path 取文件的语义一致)
        let pathOnly = (src as NSString).components(separatedBy: "?").first ?? src
        let pathPart = (pathOnly as NSString).components(separatedBy: "#").first ?? pathOnly
        let normalized = URL(string: pathPart)?.path ?? pathPart
        guard !normalized.isEmpty else { return nil }
        let base = baseURL.standardizedFileURL.path
        let candidate = baseURL.appendingPathComponent(normalized).standardizedFileURL
        guard candidate.path.hasPrefix(base), !candidate.hasDirectoryPath else { return nil }
        guard FileManager.default.fileExists(atPath: candidate.path),
              let data = try? Data(contentsOf: candidate) else { return nil }
        return "data:\(Self.mimeType(for: candidate));base64," + data.base64EncodedString()
    }

    private func respond(_ task: WKURLSchemeTask, url: URL, data: Data, mimeType: String, encoding: String? = nil) {
        let response = URLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: data.count,
            textEncodingName: encoding
        )
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    private func fail(_ task: WKURLSchemeTask, code: Int) {
        task.didFailWithError(NSError(domain: NSURLErrorDomain, code: code, userInfo: nil))
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "css":         return "text/css"
        case "js":          return "application/javascript"
        case "png":         return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif":         return "image/gif"
        case "webp":        return "image/webp"
        case "svg":         return "image/svg+xml"
        case "woff":        return "font/woff"
        case "woff2":       return "font/woff2"
        case "ttf":         return "font/ttf"
        default:            return "application/octet-stream"
        }
    }
}