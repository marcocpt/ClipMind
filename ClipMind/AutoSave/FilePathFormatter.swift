import Foundation

/// 路径格式化器（D16 URI 标准编码）。
public struct FilePathFormatter
{
    public init() {}

    public func format(url: URL, format: PathFormat) -> String
    {
        switch format
        {
        case .plainPath:
            return url.path
        case .fileURI:
            return url.absoluteString
        case .markdownLink:
            let displayName = url.lastPathComponent
            let uri = url.absoluteString
            return "[\(displayName)](\(uri))"
        }
    }
}
