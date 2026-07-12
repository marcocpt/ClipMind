@testable import ClipMind
import Foundation

/// URLProtocol 子类，用于测试时拦截所有网络请求（AC-19 数据不出本机）。
///
/// 作用：
/// 1. 拦截 URLSession 的所有出网请求，记录 URL、HTTP 方法、请求体
/// 2. 返回可配置的 mock 响应（避免真实网络调用）
/// 3. 验证 LLM 服务只向预期的 API endpoint 发请求
/// 4. 验证非 LLM 功能（分类、搜索）不发出网络请求
///
/// 用法：
/// ```swift
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [InterceptingURLProtocol.self]
/// let session = URLSession(configuration: config)
/// InterceptingURLProtocol.capturedRequests.removeAll()
/// InterceptingURLProtocol.mockResponseData = data
/// InterceptingURLProtocol.mockStatusCode = 200
/// ```
final class InterceptingURLProtocol: URLProtocol {
    /// 捕获的请求列表（每次测试前应清空）
    static var capturedRequests: [URLRequest] = []
    /// 捕获的请求体列表（与 capturedRequests 一一对应，处理 httpBodyStream 场景）
    static var capturedRequestBodies: [Data] = []
    /// mock 响应体（nil 时返回空 Data）
    static var mockResponseData: Data?
    /// mock HTTP 状态码（nil 时返回 200）
    static var mockStatusCode: Int?
    /// mock 响应头
    static var mockHeaders: [String: String]?
    /// mock 错误（非 nil 时优先于 mockResponseData/mockStatusCode，
    /// 用于模拟 URLError.timedOut 等网络错误场景）
    static var mockError: Error?

    // URLProtocol 要求 class func（非 static func），无法修改
    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedRequests.append(request)
        Self.capturedRequestBodies.append(readRequestBody(request))
        LogCategory.llm.debug("[TEST] 拦截请求: \(request.url?.absoluteString ?? "nil")")

        // 优先处理 mockError：模拟网络层错误（如 URLError.timedOut）
        if let error = Self.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let statusCode = Self.mockStatusCode ?? 200
        let headers = Self.mockHeaders ?? [:]
        let data = Self.mockResponseData ?? Data()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // no-op
    }

    /// 读取请求体（URLSession 可能将 httpBody 转为 httpBodyStream）
    private func readRequestBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        return readFromStream(stream)
    }

    /// 从 InputStream 读取所有数据
    private func readFromStream(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var data = Data()
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        return data
    }
}
