import SwiftUI

/// F2.1.1 Toast 视图模块（设计文档 §3.3）。
///
/// 呈现成功图标 + 实际保存的文件名，遵循视觉原型 v1.2 的视觉细节：
/// - 半透明深色背景 rgba(28, 28, 30, 0.92)
/// - 圆角 10px
/// - 图标 20px（绿色 #34c759 圆形 + 白色对勾）
/// - 文字 14px 白色
/// - 内边距 16px / 10px（水平 / 垂直）
/// - 最大宽度 360px（文件名过长省略号）
public struct ToastView: View
{
    private let fileName: String

    public init(fileName: String)
    {
        self.fileName = fileName
    }

    public var body: some View
    {
        HStack(spacing: 8)
        {
            icon
            text
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255, opacity: 0.92))
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
        .frame(maxWidth: 360)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("toast-container")
        .accessibilityLabel("保存成功 Toast 容器")
    }

    private var icon: some View
    {
        ZStack
        {
            Circle()
                .fill(Color(red: 0x34 / 255, green: 0xc7 / 255, blue: 0x59 / 255))
                .frame(width: 20, height: 20)
            Path { path in
                path.move(to: CGPoint(x: 5, y: 10))
                path.addLine(to: CGPoint(x: 8.5, y: 13.5))
                path.addLine(to: CGPoint(x: 15, y: 7))
            }
            .stroke(Color.white, lineWidth: 2)
            .frame(width: 20, height: 20)
        }
        .accessibilityIdentifier("toast-success-icon")
        .accessibilityLabel("保存成功图标")
    }

    private var text: some View
    {
        Text(fileName)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityIdentifier("toast-filename-text")
            .accessibilityValue(fileName)
    }
}
