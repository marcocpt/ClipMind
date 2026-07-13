import SwiftUI

/// 引导步骤枚举
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case permissions
    case apiKey
    case privacy
    case completed
}

/// 首次启动引导主容器视图
///
/// 管理引导步骤的导航，完成后设置 hasCompletedOnboarding 标记。
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    @State private var currentStep: OnboardingStep = .welcome
    @State private var showSkipAlert = false

    var body: some View {
        VStack(spacing: 0) {
            stepContent
            Divider()
            navigationBar
        }
        .frame(width: 560, height: 480)
        .accessibilityIdentifier("onboardingView")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            WelcomeView()
        case .permissions:
            PermissionRequestView()
        case .apiKey:
            APIKeyGuideView(
                triggerSkipAlert: $showSkipAlert,
                onSkipConfirmed: { withAnimation { moveForward() } }
            )
        case .privacy:
            PrivacyNoticeView(onFinish: completeOnboarding)
        case .completed:
            EmptyView()
        }
    }

    private var navigationBar: some View {
        HStack {
            if currentStep != .welcome {
                Button("上一步") {
                    withAnimation { moveBackward() }
                }
                .accessibilityIdentifier("backButton")
            }

            Spacer()

            if currentStep == .welcome {
                Button("开始使用") {
                    withAnimation { moveForward() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("startButton")
            } else if currentStep == .permissions {
                HStack(spacing: 8) {
                    Text("可稍后设置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("下一步") {
                        withAnimation { moveForward() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("nextButton")
                }
            } else if currentStep == .apiKey {
                HStack(spacing: 8) {
                    Button("跳过") {
                        showSkipAlert = true
                    }
                    .accessibilityIdentifier("skipButton")
                    Button("下一步") {
                        withAnimation { moveForward() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("nextButton")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func moveForward() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex + 1 < OnboardingStep.allCases.count else { return }
        currentStep = OnboardingStep.allCases[currentIndex + 1]
    }

    private func moveBackward() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        currentStep = OnboardingStep.allCases[currentIndex - 1]
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        currentStep = .completed
        LogCategory.app.info("首次启动引导完成")
    }
}
