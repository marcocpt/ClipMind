> 最后更新：2026-07-24 | 版本：v1.0

# Phase 1：替换模式与错误降级 实现计划

**目标：** 实现 Toast 协调模块的替换中状态（D2 状态机第 5 状态）与替换模式行为（FR-007），完成 7 个错误场景降级（E1~E7），通过 XCUITest 验证 AC-04 替换、AC-05 跳过、AC-07 失败、AC-08 动画，并补全手动验收脚本。

**依赖：** Phase 0 完成

**任务数：** 6

---

## 任务 8：替换中状态与替换模式实现（FR-007、D2）

**文件：**
- 修改：`ClipMind/Toast/ToastCoordinator.swift`
- 修改：`ClipMindTests/Toast/ToastCoordinatorTests.swift`（追加替换模式测试）

### 步骤 1：编写失败的测试

追加到 `ToastCoordinatorTests.swift`：

```swift
// MARK: - TC-UT-03 出现中 → 替换中

func testAppearingToReplacingOnNewNotification()
{
    let first = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
    coordinator.handleSavedNotification(first)
    XCTAssertEqual(coordinator.currentState, .appearing)

    // 进入动画进行中收到新通知
    let second = ToastCoordinatorFixtures.makeSavedNotification(fileName: "b.md")
    coordinator.handleSavedNotification(second)

    XCTAssertEqual(coordinator.currentState, .replacing, "出现中收到新通知应转为替换中")
    XCTAssertTrue(windowManager.closeImmediatelyCalled, "应立即关闭旧窗口")
}

// MARK: - TC-UT-04 已显示 → 替换中

func testDisplayedToReplacingOnNewNotification()
{
    let first = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
    coordinator.handleSavedNotification(first)
    windowManager.simulateDidAppear()
    XCTAssertEqual(coordinator.currentState, .displayed)

    // 2 秒计时未结束收到新通知
    timerSource.advance(by: 1.0)
    let second = ToastCoordinatorFixtures.makeSavedNotification(fileName: "b.md")
    coordinator.handleSavedNotification(second)

    XCTAssertEqual(coordinator.currentState, .replacing, "已显示收到新通知应转为替换中")
    XCTAssertTrue(windowManager.closeImmediatelyCalled, "应立即关闭旧窗口")
}

// MARK: - TC-UT-06 替换中 → 出现中（新 Toast）

func testReplacingToAppearingOnCloseImmediately()
{
    let first = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
    coordinator.handleSavedNotification(first)
    windowManager.simulateDidAppear()

    let second = ToastCoordinatorFixtures.makeSavedNotification(fileName: "b.md")
    coordinator.handleSavedNotification(second)
    XCTAssertEqual(coordinator.currentState, .replacing)

    // 模拟旧窗口立即关闭完成
    windowManager.simulateDidCloseImmediately()

    XCTAssertEqual(coordinator.currentState, .appearing, "替换中关闭完成应转为出现中（新 Toast）")
    XCTAssertEqual(windowManager.lastShownFileName, "b.md", "应触发新 Toast 显示 b.md")
}

// MARK: - TC-UT-07 替换中收到新通知（合并为最新）

func testReplacingToReplacingOnNewNotification()
{
    let first = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
    coordinator.handleSavedNotification(first)
    windowManager.simulateDidAppear()

    let second = ToastCoordinatorFixtures.makeSavedNotification(fileName: "b.md")
    coordinator.handleSavedNotification(second)
    XCTAssertEqual(coordinator.currentState, .replacing)

    // 替换中再收到新通知 c.md
    let third = ToastCoordinatorFixtures.makeSavedNotification(fileName: "c.md")
    coordinator.handleSavedNotification(third)

    XCTAssertEqual(coordinator.currentState, .replacing, "替换中收到新通知应保持替换中")
    // 最新通知胜出，待替换完成后显示 c.md
    windowManager.simulateDidCloseImmediately()
    XCTAssertEqual(windowManager.lastShownFileName, "c.md", "应显示最新文件名 c.md")
}

// MARK: - TC-UT-08 消失中 → 替换中

func testDisappearingToReplacingOnNewNotification()
{
    let first = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
    coordinator.handleSavedNotification(first)
    windowManager.simulateDidAppear()
    timerSource.advance(by: 2.0)
    XCTAssertEqual(coordinator.currentState, .disappearing)

    // 退出动画进行中收到新通知
    let second = ToastCoordinatorFixtures.makeSavedNotification(fileName: "b.md")
    coordinator.handleSavedNotification(second)

    XCTAssertEqual(coordinator.currentState, .replacing, "消失中收到新通知应转为替换中")
    XCTAssertTrue(windowManager.closeImmediatelyCalled, "应立即关闭旧窗口（取消退出动画）")
}

// MARK: - TC-UT-10 替换模式 2 秒计时重置（FR-007）

func testTimerResetsOnReplace()
{
    // 第一次触发 a.md
    let first = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
    coordinator.handleSavedNotification(first)
    windowManager.simulateDidAppear()
    XCTAssertEqual(coordinator.currentState, .displayed)

    // 推进 1 秒（剩余 1 秒）
    timerSource.advance(by: 1.0)

    // 触发替换 b.md
    let second = ToastCoordinatorFixtures.makeSavedNotification(fileName: "b.md")
    coordinator.handleSavedNotification(second)
    windowManager.simulateDidCloseImmediately()
    XCTAssertEqual(coordinator.currentState, .appearing)

    windowManager.simulateDidAppear()
    XCTAssertEqual(coordinator.currentState, .displayed)

    // 推进 1 秒（如果旧计时器未取消，会触发消失，这是 bug）
    timerSource.advance(by: 1.0)
    XCTAssertEqual(coordinator.currentState, .displayed, "新 Toast 2 秒计时不应在 1 秒后触发")

    // 再推进 1 秒，新计时器到期，应触发消失
    timerSource.advance(by: 1.0)
    XCTAssertEqual(coordinator.currentState, .disappearing, "新 Toast 2 秒后应触发消失")
}
```

### 步骤 2：运行测试验证失败

运行：
```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorTests' 2>&1 | tail -30
```
预期：FAIL，6 个新替换模式测试失败（当前 Phase 0 实现中 triggerToast 在非 hidden/disappearing 状态下仅记录日志不触发替换）。

### 步骤 3：修改最少实现代码

修改 `ClipMind/Toast/ToastCoordinator.swift`，替换任务 4 中的 `triggerToast` 和 `handleDidCloseImmediately` 方法。`pendingFileName` 属性已在任务 4 中声明（`private var pendingFileName: String?`），无需重复声明。`handleDidAppear` 方法保持任务 4 的实现不变（已包含 2 秒计时启动逻辑）：

```swift
// 替换任务 4 中的 triggerToast 方法
private func triggerToast(fileName: String)
{
    switch currentState
    {
    case .hidden:
        startAppearing(fileName: fileName)
    case .appearing, .displayed, .disappearing, .replacing:
        startReplacing(fileName: fileName)
    }
}

/// 启动替换流程：取消旧计时器 → 立即关闭旧窗口 → 等待关闭完成 → 触发新 Toast 进入。
private func startReplacing(fileName: String)
{
    currentState = .replacing
    pendingFileName = fileName
    logger.info("Toast replace: old=\(currentFileName ?? "nil", privacy: .public) new=\(fileName, privacy: .public)")

    // R-03：取消旧计时器，保证同时只有一个有效计时器
    currentTimerHandle?.cancel()
    currentTimerHandle = nil

    // D2 + R-02：立即关闭旧窗口（无退出动画），等待 onDidCloseImmediately 回调后触发新进入
    windowManager.closeImmediately()
}

// 替换任务 4 中的 handleDidCloseImmediately 方法（任务 4 为空实现，本任务补充替换逻辑）
private func handleDidCloseImmediately()
{
    // 替换模式专用：旧窗口立即关闭完成后，触发新 Toast 进入
    guard currentState == .replacing else { return }
    guard let newFileName = pendingFileName else
    {
        // 防御：无待显示文件名，回到隐藏
        currentState = .hidden
        currentFileName = nil
        return
    }
    pendingFileName = nil
    startAppearing(fileName: newFileName)
}
```

> **注意**：`handleDidAppear` 方法保持任务 4 的实现不变（已包含 `currentTimerHandle?.cancel()` + `timerSource.schedule(duration:)` 2 秒计时启动逻辑）。替换模式下 `handleDidAppear` 会被重新调用（新 Toast 进入动画完成时），此时 `currentState == .appearing` 满足 guard 条件，会正常启动新 2 秒计时。

### 步骤 4：运行测试验证通过

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorTests' 2>&1 | tail -30
```
预期：PASS，17 个测试通过（原 11 + 新 6）。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMind/Toast/ToastCoordinator.swift ClipMindTests/Toast/ToastCoordinatorTests.swift
git commit -m "feat(F2.1.1): implement replacing state and replace mode (FR-007)

- triggerToast 在 appearing/displayed/disappearing/replacing 状态下进入替换流程
- 替换流程：取消旧计时器（R-03）+ 立即关闭旧窗口（D2 + R-02）+ 等待关闭完成 + 触发新进入
- pendingFileName 暂存待显示文件名，替换中收到新通知时最新胜出
- 2 秒计时从新 Toast 出现时刻重新计算（FR-007）
- 落地设计文档 §5.3 替换模式处理逻辑 + TC-UT-03/04/06/07/08/10 测试"
```

---

## 任务 9：替换模式 XCUITest（AC-04）

**文件：**
- 修改：`ClipMind/App/ClipMindApp.swift`（支持 --UITEST_TOAST_TRIGGER_MULTIPLE 启动参数）
- 创建：`ClipMindUITests/Toast/ToastReplaceUITests.swift`

### 步骤 1：编写失败的测试

```swift
// ClipMindUITests/Toast/ToastReplaceUITests.swift
import XCTest

final class ToastReplaceUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    // AC-04 快速多次保存触发替换
    func testAC04RapidReplaceShowsLatestFileName() throws
    {
        let app = XCUIApplication()
        app.launchArguments += ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_ONBOARDING"]
        // 触发两次快速保存：500ms 间隔，分别 a.md 与 b.md
        app.launchArguments += ["--UITEST_TOAST_TRIGGER_MULTIPLE", "a.md|500|b.md"]
        app.launch()

        let fileNameText = app.staticTexts["toast-filename-text"]
        XCTAssertTrue(fileNameText.waitForExistence(timeout: 3.0), "Toast 应出现显示 a.md")

        // 等待第二次触发（500ms 后）+ 进入动画完成（200ms）
        let expectation = expectation(description: "wait for b.md")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5)
        {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(fileNameText.value as? String, "b.md", "AC-04: Toast 应切换显示最新文件名 b.md")

        // 仅存在一个 toast-container（无新旧并存）
        let toastContainers = app.descendants(matching: .any).matching(identifier: "toast-container").allElementsBoundByIndex
        XCTAssertEqual(toastContainers.count, 1, "AC-04: 不应新旧 Toast 并存")

        // 从切换时刻起 2 秒后消失（含退出动画余量）
        let disappearExpectation = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: fileNameText, handler: nil)
        wait(for: [disappearExpectation], timeout: 3.5)
        XCTAssertFalse(fileNameText.exists, "AC-04: 2 秒后 Toast 应消失")
    }
}
```

### 步骤 2：运行 XCUITest 编译验证

运行：
```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```
预期：BUILD SUCCEEDED for Testing。

### 步骤 3：编写 UITEST 多次触发启动参数支持

**替换任务 7 中的 `handleToastUITestTriggerIfNeeded` 方法整体**（在原有单次触发逻辑基础上追加多次触发分支）：

```swift
private func handleToastUITestTriggerIfNeeded()
{
    // 单次触发
    if let triggerIndex = CommandLine.arguments.firstIndex(of: "--UITEST_TOAST_TRIGGER")
    {
        let fileName: String
        if triggerIndex + 1 < CommandLine.arguments.count
        {
            fileName = CommandLine.arguments[triggerIndex + 1]
        }
        else
        {
            fileName = "test.md"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
        {
            NotificationCenter.default.post(
                name: AutoSaveService.savedNotification,
                object: nil,
                userInfo: ["eventId": "uitest-toast-trigger", "fileName": fileName, "skipped": false]
            )
        }
    }

    // 多次触发：--UITEST_TOAST_TRIGGER_MULTIPLE "a.md|500|b.md|1000|c.md"
    if let multiIndex = CommandLine.arguments.firstIndex(of: "--UITEST_TOAST_TRIGGER_MULTIPLE")
    {
        let payload: String
        if multiIndex + 1 < CommandLine.arguments.count
        {
            payload = CommandLine.arguments[multiIndex + 1]
        }
        else
        {
            payload = "test.md"
        }

        let parts = payload.split(separator: "|").map(String.init)
        // parts: [fileName, intervalMs, fileName, intervalMs, ...]
        var delay: TimeInterval = 0.5
        var index = 0
        for part in parts
        {
            if let intervalMs = Double(part)
            {
                delay += intervalMs / 1000.0
            }
            else
            {
                let fileName = part
                let fireDelay = delay
                let fireIndex = index
                DispatchQueue.main.asyncAfter(deadline: .now() + fireDelay)
                {
                    NotificationCenter.default.post(
                        name: AutoSaveService.savedNotification,
                        object: nil,
                        userInfo: [
                            "eventId": "uitest-toast-trigger-\(fireIndex)",
                            "fileName": fileName,
                            "skipped": false
                        ]
                    )
                }
                index += 1
            }
        }
    }
}
```

### 步骤 4：运行编译验证通过

运行：
```bash
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
预期：BUILD SUCCEEDED for Testing。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMindUITests/Toast/ToastReplaceUITests.swift ClipMind/App/ClipMindApp.swift
git commit -m "test(F2.1.1): add ToastReplaceUITests for AC-04 rapid replace

- AC-04 快速多次保存触发替换：500ms 间隔触发 a.md 与 b.md
- 断言 Toast 切换显示最新文件名 b.md
- 断言 toast-container 仅存在一个（无新旧并存）
- 断言 2 秒后消失（从切换时刻重新计算）
- AppDelegate 支持 --UITEST_TOAST_TRIGGER_MULTIPLE 多次触发启动参数"
```

---

## 任务 10：错误场景降级（E4~E7）

**文件：**
- 修改：`ClipMind/Toast/ToastCoordinator.swift`（添加 `handleShowFailed` 方法 + 监听 `onShowFailed` 回调）

> **说明**：`ToastWindowManager` 的 `onShowFailed` 回调已在任务 2 中添加（`public var onShowFailed: (() -> Void)?`），且 `show` 方法在 `NSScreen.main == nil` 时已调用 `onShowFailed?()`（E4/E5 路径）。`completionHandler` 中的 `[weak self]` 已处理 self 为 nil 的情况（E6 兜底）。本任务只需在 `ToastCoordinator` 中监听 `onShowFailed` 并添加 `handleShowFailed` 方法回到 hidden 状态。

### 步骤 1：编写失败的测试

追加到 `ClipMindTests/Toast/ToastCoordinatorTests.swift`：

```swift
// MARK: - E4 屏幕信息查询失败

func testE4ScreenQueryFailureDoesNotTriggerToast()
{
    let windowManager = NoScreenToastWindowManager()
    let coordinator = ToastCoordinator(
        windowManager: windowManager,
        timerSource: timerSource,
        isEnabledProvider: { true }
    )
    let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
    coordinator.handleSavedNotification(notification)

    // show 失败应保持隐藏状态
    XCTAssertEqual(coordinator.currentState, .hidden, "E4: 屏幕查询失败应保持隐藏")
    XCTAssertNil(coordinator.currentFileName)
}

// MARK: - E6 动画异常跳到目标状态

func testE6AnimationFailureSkipsToDisplayed()
{
    let windowManager = AnimFailureToastWindowManager()
    let coordinator = ToastCoordinator(
        windowManager: windowManager,
        timerSource: timerSource,
        isEnabledProvider: { true }
    )
    let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
    coordinator.handleSavedNotification(notification)

    // 进入动画异常时，windowManager.simulateDidAppear 兜底触发
    windowManager.simulateDidAppear()
    XCTAssertEqual(coordinator.currentState, .displayed, "E6: 动画异常应跳到已显示")
}

// MARK: - E7 计时器异常（备用超时检查）

func testE7TimerFiresButStateAlreadyHidden()
{
    let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
    coordinator.handleSavedNotification(notification)
    windowManager.simulateDidAppear()
    XCTAssertEqual(coordinator.currentState, .displayed)

    // 模拟状态已被外部清理（hide 完成或 stop 调用）
    coordinator.stop()

    // 推进计时器（应被 guard 拦截，不改变状态）
    timerSource.advance(by: 2.0)
    XCTAssertEqual(coordinator.currentState, .hidden, "E7: 计时器异常应被 guard 拦截")
}

/// 测试专用：模拟 NSScreen.main 为 nil 的窗口承载模块。
final class NoScreenToastWindowManager: ToastWindowManager
{
    override func show(fileName: String)
    {
        // 模拟屏幕查询失败：直接触发 onShowFailed 回调
        onShowFailed?()
    }
}

/// 测试专用：模拟进入动画失败的窗口承载模块（onDidAppear 由测试手动触发兜底）。
final class AnimFailureToastWindowManager: ToastWindowManager
{
    override func show(fileName: String)
    {
        // 模拟动画启动异常但仍触发 onDidAppear（兜底跳到已显示）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
        {
            self.onDidAppear?()
        }
    }
}
```

### 步骤 2：运行测试验证失败

运行：
```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorTests' 2>&1 | tail -30
```
预期：FAIL，E4 测试失败（ToastCoordinator 未监听 onShowFailed，状态卡在 appearing 而非回到 hidden）。

### 步骤 3：修改最少实现代码

修改 `ClipMind/Toast/ToastCoordinator.swift` 的 `setupWindowManagerCallbacks` 方法，追加 `onShowFailed` 监听，并添加 `handleShowFailed` 方法：

```swift
// 替换任务 4 中的 setupWindowManagerCallbacks 方法，追加 onShowFailed 监听
private func setupWindowManagerCallbacks()
{
    windowManager.onDidAppear = { [weak self] in
        self?.handleDidAppear()
    }
    windowManager.onDidHide = { [weak self] in
        self?.handleDidHide()
    }
    windowManager.onDidCloseImmediately = { [weak self] in
        self?.handleDidCloseImmediately()
    }
    windowManager.onShowFailed = { [weak self] in
        self?.handleShowFailed()
    }
}

// 新增 handleShowFailed 方法（E4/E5 处理）
private func handleShowFailed()
{
    // E4/E5：show 失败，回到隐藏状态，清理计时器与待显示文件名
    logger.error("Toast show failed, fallback to hidden")
    currentTimerHandle?.cancel()
    currentTimerHandle = nil
    pendingFileName = nil
    currentFileName = nil
    currentState = .hidden
}
```

> **E6 动画异常兜底说明**：`ToastWindowManager.show` 和 `hide` 的 `completionHandler` 已使用 `[weak self]` 捕获并强制设置 `isWindowVisible` 与触发回调（任务 2 实现）。即使 `NSAnimationContext` 动画异常导致 `completionHandler` 延迟调用，`self` 仍存在时会正常触发 `onDidAppear`/`onDidHide`，协调模块状态机正常推进。测试中 `AnimFailureToastWindowManager` 通过手动触发 `onDidAppear` 验证此兜底路径。
>
> **E7 计时器异常兜底说明**：`handleTimerFired` 已包含 `guard currentState == .displayed else { return }`（任务 4 实现），拦截 stop 后的计时器触发。替换模式下旧计时器通过 `currentTimerHandle?.cancel()` 取消（任务 8 实现），`VirtualTimerSource` 的 cancel 标记确保回调不触发。

### 步骤 4：运行测试验证通过

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorTests' 2>&1 | tail -30
```
预期：PASS，20 个测试通过（原 17 + 新 3）。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMind/Toast/ToastWindowManager.swift ClipMind/Toast/ToastCoordinator.swift ClipMindTests/Toast/ToastCoordinatorTests.swift
git commit -m "feat(F2.1.1): handle E4/E5/E6 error cases with fallback

- E4 NSScreen.main 为 nil：onShowFailed 回调通知 Coordinator 回到 hidden
- E5 窗口创建失败：onShowFailed 同上路径
- E6 动画异常：completionHandler 兜底强制设置可见并触发 onDidAppear/onDidHide
- Coordinator handleShowFailed：清理计时器与待显示文件名，状态回到 hidden
- 落地设计文档 §8.4 错误处理约束：不影响 F2.1 既有流程"
```

---

## 任务 11：错误场景单元测试完整覆盖（E1~E7）

**文件：**
- 创建：`ClipMindTests/Toast/ToastCoordinatorErrorTests.swift`

### 步骤 1：编写失败的测试

```swift
// ClipMindTests/Toast/ToastCoordinatorErrorTests.swift
import XCTest
@testable import ClipMind

/// F2.1.1 7 个错误场景降级单元测试（设计文档 §8.4）。
///
/// E1/E2/E3 已在 ToastCoordinatorTests 中覆盖，本测试补全 E4~E7 完整场景。
final class ToastCoordinatorErrorTests: XCTestCase
{
    private var windowManager: TestToastWindowManager!
    private var timerSource: VirtualTimerSource!
    private var coordinator: ToastCoordinator!

    override func setUp()
    {
        super.setUp()
        windowManager = TestToastWindowManager()
        timerSource = VirtualTimerSource()
        coordinator = ToastCoordinator(
            windowManager: windowManager,
            timerSource: timerSource,
            isEnabledProvider: { true }
        )
    }

    override func tearDown()
    {
        coordinator?.stop()
        coordinator = nil
        windowManager = nil
        timerSource = nil
        super.tearDown()
    }

    // E1 通知载荷缺失文件名（已在 ToastCoordinatorTests.testE1MissingFileNameDoesNotTriggerToast 覆盖）
    func testE1MissingFileNameLogsErrorAndDoesNotTrigger()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: nil, skipped: false)
        coordinator.handleSavedNotification(notification)
        XCTAssertEqual(coordinator.currentState, .hidden)
    }

    // E2 通知载荷事件标识缺失（已在 ToastCoordinatorTests.testE2MissingEventIdStillTriggersToast 覆盖）
    func testE2MissingEventIdStillTriggersToast()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(eventId: "", fileName: "test.md")
        coordinator.handleSavedNotification(notification)
        XCTAssertEqual(coordinator.currentState, .appearing)
    }

    // E3 F2.1 总开关查询失败（已在 ToastCoordinatorTests.testE3IsEnabledProviderThrowsDoesNotTriggerToast 覆盖）
    func testE3IsEnabledProviderThrowsDoesNotTrigger()
    {
        let throwingProvider: () throws -> Bool = { throw NSError(domain: "test", code: 1) }
        let coordinator = ToastCoordinator(
            windowManager: windowManager,
            timerSource: timerSource,
            isEnabledProvider: throwingProvider
        )
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
        coordinator.handleSavedNotification(notification)
        XCTAssertEqual(coordinator.currentState, .hidden)
    }

    // E4 屏幕信息查询失败（已在 ToastCoordinatorTests.testE4ScreenQueryFailureDoesNotTriggerToast 覆盖）
    func testE4ScreenQueryFailureFallsBackToHidden()
    {
        let noScreenManager = NoScreenToastWindowManager()
        let coordinator = ToastCoordinator(
            windowManager: noScreenManager,
            timerSource: timerSource,
            isEnabledProvider: { true }
        )
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
        coordinator.handleSavedNotification(notification)
        XCTAssertEqual(coordinator.currentState, .hidden)
    }

    // E5 窗口创建失败（模拟 NSPanel 初始化返回 nil 不易，用 onShowFailed 路径覆盖）
    func testE5WindowCreationFailureFallsBackToHidden()
    {
        let failManager = FailOnShowToastWindowManager()
        let coordinator = ToastCoordinator(
            windowManager: failManager,
            timerSource: timerSource,
            isEnabledProvider: { true }
        )
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
        coordinator.handleSavedNotification(notification)
        XCTAssertEqual(coordinator.currentState, .hidden, "E5: 窗口创建失败应回到隐藏")
    }

    // E6 动画异常跳到目标状态（已在 ToastCoordinatorTests.testE6AnimationFailureSkipsToDisplayed 覆盖）
    func testE6AnimationFailureSkipsToDisplayed()
    {
        let animFailManager = AnimFailureToastWindowManager()
        let coordinator = ToastCoordinator(
            windowManager: animFailManager,
            timerSource: timerSource,
            isEnabledProvider: { true }
        )
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
        coordinator.handleSavedNotification(notification)

        let expectation = XCTestExpectation(description: "didAppear fires")
        animFailManager.onDidAppear = {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(coordinator.currentState, .displayed)
    }

    // E7 计时器异常（已在 ToastCoordinatorTests.testE7TimerFiresButStateAlreadyHidden 覆盖）
    func testE7TimerFiresAfterStopDoesNotChangeState()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)
        windowManager.simulateDidAppear()
        XCTAssertEqual(coordinator.currentState, .displayed)

        coordinator.stop()
        timerSource.advance(by: 2.0)
        XCTAssertEqual(coordinator.currentState, .hidden, "E7: stop 后计时器触发应被 guard 拦截")
    }

    // E7 补充：替换模式下计时器句柄替换，旧句柄 cancel 后不触发
    func testE7OldTimerHandleCancelDoesNotFire()
    {
        let first = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(first)
        windowManager.simulateDidAppear()

        // 推进 1 秒
        timerSource.advance(by: 1.0)

        // 触发替换
        let second = ToastCoordinatorFixtures.makeSavedNotification(fileName: "b.md")
        coordinator.handleSavedNotification(second)
        windowManager.simulateDidCloseImmediately()
        windowManager.simulateDidAppear()

        // 旧计时器已被 cancel，推进不应有副作用
        // 新计时器 2 秒后应触发
        timerSource.advance(by: 1.0)
        XCTAssertEqual(coordinator.currentState, .displayed, "新计时器 1 秒不应触发")

        timerSource.advance(by: 1.0)
        XCTAssertEqual(coordinator.currentState, .disappearing, "新计时器 2 秒应触发消失")
    }
}

/// 测试专用：模拟 show 失败的窗口承载模块（E5 场景）。
final class FailOnShowToastWindowManager: ToastWindowManager
{
    override func show(fileName: String)
    {
        onShowFailed?()
    }
}
```

### 步骤 2：运行测试验证失败

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorErrorTests' 2>&1 | tail -30
```
预期：FAIL（首次运行，需要确认依赖类型一致性与继承可见性）。

### 步骤 3：验证类型一致性（无需修改实现，仅确认测试与 Phase 0/任务 8/10 一致）

如果 `NoScreenToastWindowManager` 与 `AnimFailureToastWindowManager` 在任务 10 已定义在 `ToastCoordinatorTests.swift`，本测试文件无法访问，需要将它们移到 `ToastCoordinatorFixtures.swift`：

```swift
// ClipMindTests/Toast/Fixtures/ToastCoordinatorFixtures.swift 追加：

/// 测试专用：模拟 NSScreen.main 为 nil 的窗口承载模块（E4 场景）。
final class NoScreenToastWindowManager: ToastWindowManager
{
    override func show(fileName: String)
    {
        onShowFailed?()
    }
}

/// 测试专用：模拟进入动画失败的窗口承载模块（E6 场景）。
final class AnimFailureToastWindowManager: ToastWindowManager
{
    override func show(fileName: String)
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
        {
            self.onDidAppear?()
        }
    }
}

/// 测试专用：模拟 show 失败的窗口承载模块（E5 场景）。
final class FailOnShowToastWindowManager: ToastWindowManager
{
    override func show(fileName: String)
    {
        onShowFailed?()
    }
}
```

并从 `ToastCoordinatorTests.swift` 中移除重复的 `NoScreenToastWindowManager` 与 `AnimFailureToastWindowManager` 定义。

### 步骤 4：运行测试验证通过

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorErrorTests' \
  -only-testing:'ClipMindTests/ToastCoordinatorTests' 2>&1 | tail -10
```
预期：PASS，错误场景测试全部通过。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMindTests/Toast/ToastCoordinatorErrorTests.swift \
  ClipMindTests/Toast/Fixtures/ToastCoordinatorFixtures.swift \
  ClipMindTests/Toast/ToastCoordinatorTests.swift
git commit -m "test(F2.1.1): cover 7 error scenarios E1~E7 with dedicated tests

- E1 通知载荷缺失文件名
- E2 通知载荷 eventId 缺失（降级仍触发）
- E3 isEnabledProvider 抛异常（保守不显示）
- E4 NSScreen.main 为 nil（onShowFailed 回退）
- E5 窗口创建失败（onShowFailed 同路径）
- E6 动画异常（completionHandler 兜底强制状态转换）
- E7 计时器异常（guard 拦截 + 旧句柄 cancel 不触发）
- 共享 Mock 类型移至 Fixtures（NoScreen/AnimFailure/FailOnShow）"
```

---

## 任务 12：跳过与失败场景 XCUITest（AC-05/07）

**文件：**
- 修改：`ClipMind/App/ClipMindApp.swift`（支持 --UITEST_TOAST_SKIP 与 --UITEST_TOAST_FAIL 启动参数）
- 创建：`ClipMindUITests/Toast/ToastSkipFailUITests.swift`

### 步骤 1：编写失败的测试

```swift
// ClipMindUITests/Toast/ToastSkipFailUITests.swift
import XCTest

final class ToastSkipFailUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    // AC-05 跳过场景不弹 Toast
    func testAC05NoToastOnSkipScenario() throws
    {
        let app = XCUIApplication()
        app.launchArguments += ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_ONBOARDING"]
        // 触发跳过场景（skipped=true）
        app.launchArguments += ["--UITEST_TOAST_SKIP"]
        app.launch()

        let toastContainer = app.otherElements["toast-container"]
        // 轮询 1.5 秒确认 Toast 不出现
        let notAppeared = !toastContainer.waitForExistence(timeout: 1.5)
        XCTAssertTrue(notAppeared, "AC-05: 跳过场景不应弹 Toast")
    }

    // AC-07 失败场景不弹 Toast，错误弹窗存在
    func testAC07NoToastOnFailureScenario() throws
    {
        let app = XCUIApplication()
        app.launchArguments += ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_ONBOARDING"]
        // 触发失败场景（skipped=true + errorNotification）
        app.launchArguments += ["--UITEST_TOAST_FAIL"]
        app.launch()

        let toastContainer = app.otherElements["toast-container"]
        let notAppeared = !toastContainer.waitForExistence(timeout: 1.5)
        XCTAssertTrue(notAppeared, "AC-07: 失败场景不应弹 Toast")

        // 错误弹窗应存在（accessibility identifier 前缀 error-）
        // F2.1 既有错误弹窗使用 NSAlert，无固定 identifier，通过窗口标题断言
        let errorAlert = app.dialogs["自动保存失败"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2.0), "AC-07: 失败场景应弹出错误弹窗")
    }
}
```

### 步骤 2：运行 XCUITest 编译验证

运行：
```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```
预期：BUILD SUCCEEDED for Testing。

### 步骤 3：编写跳过与失败启动参数支持

**在任务 9 的 `handleToastUITestTriggerIfNeeded` 方法末尾追加**以下两个 if 块（保留任务 7 单次触发与任务 9 多次触发的既有逻辑不变）：

```swift
// 跳过场景：--UITEST_TOAST_SKIP
if CommandLine.arguments.contains("--UITEST_TOAST_SKIP")
{
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
    {
        NotificationCenter.default.post(
            name: AutoSaveService.savedNotification,
            object: nil,
            userInfo: ["eventId": "uitest-toast-skip", "skipped": true]
        )
    }
}

// 失败场景：--UITEST_TOAST_FAIL（发送 skipped 通知 + 错误通知）
if CommandLine.arguments.contains("--UITEST_TOAST_FAIL")
{
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
    {
        NotificationCenter.default.post(
            name: AutoSaveService.savedNotification,
            object: nil,
            userInfo: ["eventId": "uitest-toast-fail", "skipped": true]
        )
        NotificationCenter.default.post(
            name: AutoSaveService.errorNotification,
            object: nil,
            userInfo: ["errorCode": "uitest-failure"]
        )
    }
}
```

### 步骤 4：运行编译验证通过

运行：
```bash
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
预期：BUILD SUCCEEDED for Testing。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMindUITests/Toast/ToastSkipFailUITests.swift ClipMind/App/ClipMindApp.swift
git commit -m "test(F2.1.1): add ToastSkipFailUITests for AC-05/07

- AC-05 跳过场景不弹 Toast（--UITEST_TOAST_SKIP 派发 skipped=true 通知）
- AC-07 失败场景不弹 Toast + 错误弹窗存在（--UITEST_TOAST_FAIL 派发 skipped 通知 + errorNotification）
- AppDelegate 支持两个新启动参数"
```

---

## 任务 13：动画验证 XCUITest + 手动验收脚本

**文件：**
- 创建：`ClipMindUITests/Toast/ToastAnimationUITests.swift`
- 创建：`docs/planning/P1/F2.1/实现计划/F2.1.1/manual-acceptance-script.md`

### 步骤 1：编写失败的测试

```swift
// ClipMindUITests/Toast/ToastAnimationUITests.swift
import XCTest

final class ToastAnimationUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    // AC-08 进入/退出动画存在（进入动画启动后立即断言 Toast 容器存在）
    func testAC08ToastContainerExistsDuringEntryAnimation() throws
    {
        let app = XCUIApplication()
        app.launchArguments += ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_ONBOARDING"]
        app.launchArguments += ["--UITEST_TOAST_TRIGGER", "hello-world.md"]
        app.launch()

        // 进入动画启动后立即断言 toast-container 存在（不等待 0.2s 动画完成）
        let toastContainer = app.otherElements["toast-container"]
        let appeared = toastContainer.waitForExistence(timeout: 1.0)
        XCTAssertTrue(appeared, "AC-08: 进入动画启动后 Toast 容器应立即存在")

        // 断言动画期间 toast-container 仍可见
        XCTAssertTrue(toastContainer.isHittable, "AC-08: 进入动画期间 Toast 应可点击（可见）")
    }
}
```

### 步骤 2：运行 XCUITest 编译验证

运行：
```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
预期：BUILD SUCCEEDED for Testing。

### 步骤 3：编写手动验收脚本

```markdown
# 手动验收脚本（手动执行，对应 D8 三层测试策略第 3 层：手动 OS 边界测试）

> 最后更新：2026-07-24 | 版本：v1.0

## 1. 验收范围

本脚本覆盖 XCUITest 无法自动化的 OS 边界场景，包括：

- 动画视觉效果录屏（AC-08 视觉部分）
- 源 App 全屏遮挡（R-05）
- TCC 弹窗验证（AC-10）
- Instruments 性能验证（NFR-001/002/003）
- 跨应用前台语义验证（AC-11 手动部分）

## 2. 前置条件

- 主 Scheme `ClipMind` 构建成功（`xcodebuild build` 通过）
- F2.1 总开关启用，白名单含 Safari 与 Notes
- 保存目录配置为可写路径（如 `~/Documents/ClipMind-AutoSave`）
- 长度阈值默认 50 字

## 3. 验收用例

### 3.1 AC-08 动画视觉效果录屏

**步骤：**
1. 启动 ClipMind App
2. 打开屏幕录制（macOS 系统屏幕录制或 QuickTime）
3. 切换到 Safari，复制一段 ≥50 字的长内容
4. 观察屏幕顶部 Toast 出现，录制 0.5 秒
5. 等待 2 秒，观察 Toast 消失，录制 0.5 秒
6. 停止录制

**预期：**
- 进入动画：从顶部滑入 + 淡入，约 0.2 秒
- 退出动画：反向滑出 + 淡出，约 0.2 秒
- 动画流畅无卡顿

**录屏存放：** `docs/planning/P1/F2.1/recordings/2026-07-24-ac08-animation.mp4`

### 3.2 R-05 源 App 全屏遮挡

**步骤：**
1. 启动 ClipMind App
2. 切换到 Safari，进入全屏模式（Cmd+Ctrl+F）
3. 在 Safari 中复制 ≥50 字长内容
4. 观察屏幕顶部

**预期：**
- Toast 在屏幕顶部居中显示（不依赖 Safari 全屏，由 NSPanel.level = .floating 保证覆盖普通 App）
- 若 Safari 全屏遮挡 Toast，记录日志（属 R-05 已知风险，不在本特性范围）

**验收记录：** 文档化 Toast 是否可见，截图存放 `docs/planning/P1/F2.1/screenshots/2026-07-24-r05-fullscreen.png`

### 3.3 AC-10 App Sandbox 合规验证

**步骤：**
1. 主 Scheme 构建：`xcodebuild build -project ClipMind.xcodeproj -scheme ClipMind -configuration Debug`
2. 运行 App，触发保存成功
3. 录屏整个 Toast 显示与消失过程
4. 检查 macOS 系统通知中心：是否有 TCC 权限弹窗残留

**预期：**
- 主 Scheme 构建成功
- Toast 显示与消失正常
- 无 TCC 权限弹窗（如辅助功能、屏幕录制、输入监控等）
- macOS 通知中心无新增通知（C-03 不污染系统通知中心）

**验收记录：** 录屏存放 `docs/planning/P1/F2.1/recordings/2026-07-24-ac10-sandbox.mp4`

### 3.4 NFR-001 响应性能验证

**步骤：**
1. 启动 Instruments（Time Profiler）
2. 启动 ClipMind App，开始录制
3. 切换到 Safari，复制 ≥50 字长内容
4. 观察 Toast 出现时机
5. 停止录制

**预期：**
- 保存成功到 Toast 出现延迟 ≤ 0.3 秒（含动画启动时间）
- 主线程耗时 < 100ms

**验收记录：** Instruments trace 存放 `docs/planning/P1/F2.1/recordings/2026-07-24-nfr001-perf.trace`

### 3.5 NFR-002 动画帧率验证

**步骤：**
1. 启动 Instruments（Core Animation）
2. 启动 ClipMind App，开始录制
3. 触发保存成功，观察 Toast 进入与退出动画
4. 停止录制

**预期：**
- 进入动画保持 60fps
- 退出动画保持 60fps
- 无掉帧

**验收记录：** Instruments trace 存放 `docs/planning/P1/F2.1/recordings/2026-07-24-nfr002-fps.trace`

### 3.6 NFR-003 资源占用与释放验证

**步骤：**
1. 启动 Instruments（Allocations）
2. 启动 ClipMind App，开始录制
3. 触发保存成功，等待 Toast 显示
4. 等待 Toast 消失
5. 再触发一次保存成功，重复 3-4 步骤 5 次
6. 停止录制

**预期：**
- Toast 显示期间 CPU 占用不可感知（< 1%）
- Toast 显示期间内存占用 < 5MB
- Toast 消失后窗口对象立即释放（Allocations 显示 NSPanel 实例数归零）
- 5 次触发后无内存增长（无泄漏）

**验收记录：** Instruments trace 存放 `docs/planning/P1/F2.1/recordings/2026-07-24-nfr003-mem.trace`

### 3.7 AC-11 跨应用前台语义验证

**步骤：**
1. 启动 ClipMind App
2. 切换到 Safari，使其处于前台
3. 在 Safari 中复制 ≥50 字长内容
4. 截图（Cmd+Shift+3）

**预期：**
- Toast 在屏幕顶部居中显示
- Safari 仍处于前台（菜单栏显示 Safari 菜单）
- ClipMind 主窗口未被激活（不在 Dock 中显示为活动 App）

**验收记录：** 截图存放 `docs/planning/P1/F2.1/screenshots/2026-07-24-ac11-foreground.png`

## 4. 验收结果汇总

| 用例 | 验收日期 | 验收人 | 结果 | 证据路径 |
|------|---------|-------|------|---------|
| AC-08 动画 | 待执行 | | | |
| R-05 全屏 | 待执行 | | | |
| AC-10 Sandbox | 待执行 | | | |
| NFR-001 性能 | 待执行 | | | |
| NFR-002 帧率 | 待执行 | | | |
| NFR-003 资源 | 待执行 | | | |
| AC-11 前台 | 待执行 | | | |

## 5. 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-24 | 初始版本，覆盖 7 个手动验收用例（动画、全屏、Sandbox、性能、帧率、资源、前台） |
```

### 步骤 4：运行编译验证通过

运行：
```bash
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
预期：BUILD SUCCEEDED for Testing。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMindUITests/Toast/ToastAnimationUITests.swift \
  docs/planning/P1/F2.1/实现计划/F2.1.1/manual-acceptance-script.md
git commit -m "test(F2.1.1): add ToastAnimationUITests and manual acceptance script

- AC-08 进入动画启动后立即断言 Toast 容器存在（验证窗口先创建后启动动画）
- 手动验收脚本覆盖 7 个 OS 边界用例：
  - AC-08 动画视觉效果录屏
  - R-05 源 App 全屏遮挡
  - AC-10 App Sandbox 合规验证
  - NFR-001 响应性能（≤0.3s）
  - NFR-002 动画帧率（60fps）
  - NFR-003 资源占用与释放
  - AC-11 跨应用前台语义"
```

---

## Phase 1 完成验收

完成所有 6 个任务后，运行以下验证：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast

# 1. SwiftLint strict
swiftlint lint --strict

# 2. 完整编译
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5

# 3. Toast 单元测试全部通过
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorTests' \
  -only-testing:'ClipMindTests/ToastCoordinatorErrorTests' \
  -only-testing:'ClipMindTests/ToastWindowManagerTests' \
  -only-testing:'ClipMindTests/ToastViewTests' \
  -only-testing:'ClipMindTests/TimerSourceTests' 2>&1 | tail -10

# 4. F2.1 既有测试回归（不破坏 F2.1 既有行为）
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveServiceTests' 2>&1 | tail -10

# 5. XCUITest 编译验证（不运行）
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

预期：
- SwiftLint：0 violations
- Build：BUILD SUCCEEDED
- Toast 单元测试：全部 PASS（约 30 个测试，含 8 个状态转换 + 7 个错误场景 + 替换模式 + 计时器源 + 窗口承载）
- F2.1 既有测试：全部 PASS（无回归）
- XCUITest 编译：BUILD SUCCEEDED for Testing

Phase 1 完成后进入 Step 4：TDD 实现按本计划逐任务执行；Step 5~9：合并候选 + CI + 文档检查 + Lint/Push + 清理。
