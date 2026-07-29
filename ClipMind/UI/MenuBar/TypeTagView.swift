import SwiftUI

/// 类型标签视图（兼容包装）。
///
/// 根据 `ContentType` 显示对应的系统标签 pill，用于 popover 和主窗口中剪贴条目的
/// 类型可视化。内部复用 `TagPillView` 与 `SystemTagCatalog`，避免维护两套系统标签
/// 颜色与名称映射。
///
/// 兼容包装继续暴露既有 `typeTag_<contentType>` identifier，保证旧系统标签 XCUITest
/// 不因内部复用而失效。
struct TypeTagView: View
{
    let contentType: ContentType

    var body: some View
    {
        TagPillView(tag: SystemTagCatalog.tag(for: contentType), isInteractive: false)
            .accessibilityIdentifier("typeTag_\(contentType.rawValue)")
    }
}
