# HTMLRichText — CocoaPods 接入定义(不影响 Xcode 工程与 SPM)。
# Git 方式接入(Podfile):
#   pod 'HTMLRichText', :git => 'https://github.com/BuddyLiu/SwiftUIHTMLLocalComponent.git', :tag => '0.3.0'
# 发布到 CDN 后可直接:
#   pod 'HTMLRichText'
Pod::Spec.new do |s|
  s.name             = 'HTMLRichText'
  s.version          = '0.3.0'
  s.summary          = 'SwiftUI 本地富文本组件:WKWebView 渲染 + 高度自适应 + 交互回调,支持可调毛玻璃背景。'
  s.description      = <<-DESC
  一个基于 WKWebView 的本地方案 SwiftUI 富文本组件。内容完全本地生成与加载(不依赖网络),自动测量
  内容高度并自适应;链接 / 图片点击与长按全部回调给 SwiftUI;本地图片自动内联;背景支持透明 / 纯色 /
  可调毛玻璃(模糊、饱和度、渐变色调 tintColors + 方向);无需联网即可渲染 HTML 与 Markdown。
  DESC
  s.homepage         = 'https://github.com/BuddyLiu/SwiftUIHTMLLocalComponent'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'BuddyLiu' => '13621905107@163.com' }
  s.source           = { :git => 'https://github.com/BuddyLiu/SwiftUIHTMLLocalComponent.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.swift_version    = '5.5'
  s.source_files     = 'SwiftUIHTMLLocalComponent/SwiftUIHTMLLocalComponent/HTMLRichText/**/*.swift'
end
