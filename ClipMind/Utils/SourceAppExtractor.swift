import Foundation

/// 来源应用列表提取工具。
///
/// 从剪贴项列表中动态提取来源应用名称，去重并按名称排序。
enum SourceAppExtractor
{
    /// 从剪贴项列表中提取去重排序的来源应用名称列表。
    static func extract(from clips: [ClipItem]) -> [String]
    {
        let names = Set(clips.map(\.sourceAppName).filter { !$0.isEmpty })
        return names.sorted()
    }
}
