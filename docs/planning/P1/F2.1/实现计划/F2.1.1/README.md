> 最后更新：2026-07-24 | 版本：v1.0

# F2.1.1 保存成功 Toast 提示 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。本计划基于 v1.1 设计文档套件，落地 7 条决策（D1~D7）+ 7 个错误场景降级。每个任务严格按 TDD 五步执行（编写失败测试 → 验证失败 → 最小实现 → 验证通过 → commit）。

**目标：** 在 F2.1 自动保存成功后，从屏幕顶部居中弹出轻量 Toast（成功图标 + 实际文件名），2 秒后自动消失（带 0.2s 滑入/淡入与反向退出动画）；多次保存采用替换模式（旧 Toast 立即关闭，新 Toast 触发进入，2s 计时重置）；跟随 F2.1 总开关；仅在保存成功（非跳过、非失败）时触发；不依赖 ClipMind 主窗口焦点。

**架构：** Toast 协调模块通过 `NotificationCenter` 订阅 `AutoSaveService.savedNotification`（D3 中心化通知订阅），在主线程派发回调（D6）。协调模块采用 5 状态显式状态机：隐藏 → 出现中 → 已显示 → 替换中 → 消失中 → 隐藏（D2）。Toast 窗口承载模块使用 `NSPanel`（透明背景 + `.nonactivatingPanel` 行为）承载 SwiftUI 视图，作为屏幕级浮层不抢焦点（D1）。F2.1 总开关通过依赖注入闭包查询（D4），避免修改 F2.1 公共接口（C-04）。动画使用 `NSWindow.alphaValue` + `NSWindow.setFrame` 原生窗口能力（D5）。2 秒计时器与 0.2 秒动画时长通过依赖注入的计时器源（D7），单元测试使用虚拟计时器源加速推进，禁用固定 sleep。

**技术栈：** Swift 5.7+ / macOS 12.4+ / SwiftUI + AppKit（NSPanel、NSWindow、NSHostingController、NSPasteboard）/ Foundation（NotificationCenter、DispatchQueue）/ XCTest + XCUITest / SwiftLint strict / xcodegen / Conventional Commits

---

## 1. 必读资料

执行任何任务前必须完整阅读以下文档（按顺序）：

| 序号 | 文档 | 版本 | 路径（相对仓库根） | 用途 |
|------|------|------|--------------------|------|
| 1 | 设计文档 | v1.1 | `docs/planning/P1/F2.1/F2.1.1_保存成功Toast_设计文档.md` | 架构契约，7 条决策（D1~D7）+ 7 个错误场景 + 双状态机同步关系 |
| 2 | 需求文档 | v1.0 | `docs/planning/P1/F2.1/F2.1.1_保存成功Toast_需求文档.md` | 单一需求来源（11 FR + 6 NFR + 11 AC + 6 约束 + 8 Out of Scope） |
| 3 | 测试用例表 | v1.1 | `docs/planning/P1/F2.1/F2.1.1_保存成功Toast_测试用例表.md` | 测试契约（55 单元测试 + 11 AC 覆盖矩阵 + 6 NFR 矩阵 + UI 可观测性矩阵） |
| 4 | 视觉原型 | v1.2 | `docs/planning/P1/F2.1/F2.1.1_保存成功Toast_视觉原型.html` | 视觉细节（背景色/圆角/字体/accessibility identifier 命名） |
| 5 | 编码规范 | v1.0 | `docs/CODING_STANDARDS.md` | Allman 大括号 + 4 空格 + LogCategory + 并发规则 |
| 6 | 项目规则 | v1.1 | `AGENTS.md` + `.trae/rules/docs.md` + `.trae/rules/git-commit-message.md` | 工作流 + 文档同步 + 提交规范 + App Store 合规 |
| 7 | F2.1 设计文档 | v1.1 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_设计文档.md` | F2.1 `savedNotification` 通知契约来源 |
| 8 | F2.1 实现计划 | v2.3 | `docs/planning/P1/F2.1/实现计划/README.md` | F2.1 D17 PollingHelper 与日志规范参考 |

---

## 2. 7 条决策（D1~D7）落地位置索引

| 决策 | 摘要 | 落地 Phase | 落地任务 |
|------|------|-----------|----------|
| D1 | 独立透明窗口屏幕级浮层（NSPanel `.nonactivatingPanel` + `.floating` level） | Phase 0 | 任务 2（ToastWindowManager） |
| D2 | 5 状态显式状态机（隐藏/出现中/已显示/替换中/消失中） | Phase 0 + Phase 1 | 任务 4（基础 4 状态）+ 任务 8（替换中状态） |
| D3 | 中心化通知订阅（NotificationCenter 监听 `savedNotification`） | Phase 0 | 任务 4（ToastCoordinator 通知订阅） |
| D4 | 依赖注入闭包查询 F2.1 总开关 | Phase 0 | 任务 4（注入闭包）+ 任务 6（AppDelegate 装配注入真实闭包） |
| D5 | 原生窗口透明度与位置动画（`NSWindow.alphaValue` + `setFrame`） | Phase 0 | 任务 2（ToastWindowManager 动画） |
| D6 | 通知回调主线程派发 + 主线程边界 | Phase 0 | 任务 4（ToastCoordinator 主线程派发）+ 任务 2（ToastWindowManager 主线程边界） |
| D7 | 可注入时钟与计时器源（生产 MainTimerSource + 测试 VirtualTimerSource） | Phase 0 | 任务 3（TimerSource 协议）+ 任务 4（注入计时器源）+ 任务 5（2 秒计时集成） |

---

## 3. 7 个错误场景（设计文档 §8.4）落地位置索引

| 错误场景 | 触发条件 | 处理策略 | 落地任务 |
|---------|---------|---------|----------|
| E1 通知载荷缺失文件名 | `skipped != true` 但 `fileName == nil` | 记录错误日志（含 eventId），不触发 Toast | 任务 10 |
| E2 通知载荷事件标识缺失 | `eventId == nil` | 记录错误日志，仍尝试触发 Toast（降级处理） | 任务 10 |
| E3 F2.1 总开关查询失败 | 注入闭包抛出异常 | 默认不显示 Toast（保守策略） | 任务 10 |
| E4 屏幕信息查询失败 | `NSScreen.main == nil` | 不触发 Toast，记录日志 | 任务 10 |
| E5 窗口创建失败 | `NSPanel` 初始化失败或资源不足 | 记录错误日志，不触发 Toast，不影响 F2.1 既有流程 | 任务 10 |
| E6 动画异常 | 进入或退出动画异常或超时 | 直接跳到目标状态（已显示/隐藏），启动 2 秒计时或释放资源 | 任务 10 |
| E7 计时器异常 | 计时器未触发或重复触发 | 协调模块保证同时只有一个有效计时器；备用超时检查清理 | 任务 10 |

---

## 4. Phase 列表

| Phase | 目标 | 子计划文件 | 依赖 | 任务数 |
|-------|------|-----------|------|--------|
| Phase 0 | 核心 Toast 显示：ToastView、ToastWindowManager、TimerSource 协议、ToastCoordinator 状态机基础（隐藏/出现中/已显示/消失中）、2 秒计时器、AppDelegate 装配、基础 XCTest + XCUITest | `phase-0-core-toast.md` | 无 | 7 |
| Phase 1 | 替换模式与错误降级：替换中状态、替换模式 XCUITest、7 个错误场景降级、跳过/失败场景 XCUITest、动画验证 XCUITest、手动验收脚本 | `phase-1-replace-and-errors.md` | Phase 0 完成 | 6 |

**总任务数：** 13 个任务（Phase 0：7，Phase 1：6）

---

## 5. 文件结构

### 5.1 Phase 0 新增文件（10 个，含测试）

| 文件路径 | 职责 | 对应任务 |
|----------|------|----------|
| `ClipMind/Toast/ToastView.swift` | SwiftUI 视图：成功图标 + 文件名文字，accessibility identifier `toast-container` / `toast-filename-text` / `toast-success-icon` | 任务 1 |
| `ClipMind/Toast/ToastWindowManager.swift` | 窗口承载模块：NSPanel 创建、定位顶部居中、进入/退出动画（0.2s）、关闭与释放、不抢焦点 | 任务 2 |
| `ClipMind/Toast/TimerSource.swift` | 计时器源协议（D7）+ `MainTimerSource` 生产实现（DispatchSourceTimer 主线程）+ `VirtualTimerSource` 测试实现 | 任务 3 |
| `ClipMind/Toast/ToastCoordinator.swift` | 协调模块：5 状态机 + 通知订阅 + 跳过/总开关校验 + 2 秒计时 + 主线程派发 | 任务 4、5 |
| `ClipMindTests/Toast/ToastViewTests.swift` | ToastView 单元测试（图标渲染、文件名显示、accessibility identifier） | 任务 1 |
| `ClipMindTests/Toast/ToastWindowManagerTests.swift` | ToastWindowManager 单元测试（窗口创建、定位、动画状态） | 任务 2 |
| `ClipMindTests/Toast/TimerSourceTests.swift` | TimerSource 协议测试（MainTimerSource 真实计时、VirtualTimerSource 虚拟推进） | 任务 3 |
| `ClipMindTests/Toast/ToastCoordinatorTests.swift` | ToastCoordinator 状态机单元测试（Phase 0：8 个状态转换中前 5 个 + 跳过/总开关校验 + 通知订阅） | 任务 4、5 |
| `ClipMindTests/Toast/Fixtures/ToastCoordinatorFixtures.swift` | 测试 Fixtures：构造 `savedNotification` 通知、Mock 总开关查询闭包、Mock 计时器源 | 任务 4 |
| `ClipMindUITests/Toast/ToastBasicUITests.swift` | XCUITest：AC-01 Toast 出现、AC-02 2 秒消失、AC-03 文件名显示、AC-06 总开关关闭、AC-09 位置顶部居中、AC-11 不依赖焦点 | 任务 7 |

### 5.2 Phase 1 新增文件（4 个，含测试）

| 文件路径 | 职责 | 对应任务 |
|----------|------|----------|
| `ClipMindUITests/Toast/ToastReplaceUITests.swift` | XCUITest：AC-04 替换模式（快速多次保存触发替换） | 任务 9 |
| `ClipMindTests/Toast/ToastCoordinatorErrorTests.swift` | 7 个错误场景降级单元测试（E1~E7） | 任务 11 |
| `ClipMindUITests/Toast/ToastSkipFailUITests.swift` | XCUITest：AC-05 跳过场景、AC-07 失败场景 | 任务 12 |
| `ClipMindUITests/Toast/ToastAnimationUITests.swift` | XCUITest：AC-08 进入动画启动后立即可见 | 任务 13 |
| `docs/planning/P1/F2.1/实现计划/F2.1.1/manual-acceptance-script.md` | 手动验收脚本：动画录屏、源 App 前台截图、Sandbox 合规验证、Instruments 性能验证 | 任务 13 |

### 5.3 修改文件（2 个，仅装配）

| 文件路径 | 修改内容 | 对应任务 |
|----------|----------|----------|
| `ClipMind/App/ClipMindApp.swift` | AppDelegate `setupCaptureService` 中装配 `ToastCoordinator`，注入 F2.1 总开关查询闭包（读取 `AutoSaveSettingsStore.load().isEnabled`）与 `MainTimerSource`；新增 `handleToastUITestTriggerIfNeeded` 方法支持 XCUITest 启动参数 | 任务 6、7、9、12 |
| `ClipMind/Utils/LogCategory.swift` | 新增 `toast` 分类（公共文件修改，加 `PublicFile` tag），用于 Toast 状态变更日志。**必须在任务 2 中添加**，因 ToastWindowManager 使用 `LogCategory.toast.logger` 输出日志 | 任务 2 |

### 5.4 不修改文件

- `ClipMind/AutoSave/AutoSaveService.swift`（C-04：不修改 F2.1 公共接口）
- `ClipMind/AutoSave/AutoSaveSettingsStore.swift`（C-04：仅读取 `load().isEnabled`）
- `ClipMind/UI/Settings/AutoSaveSettingsView.swift`（O-08：不修改 F2.1 配置面板 UI）
- F1.x 既有模块（`ClipCaptureService`、`PasteboardWatcher`、`EncryptedStore`、`StatusItemController` 等）
- `project.yml`（本特性无需修改 xcodegen 配置，源码目录自动扫描）

---

## 6. 全局验证命令

### 6.1 本地允许执行的验证

```bash
# 工作目录
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast

# 生成 Xcode 工程（修改 project.yml 后必跑；本特性不修改 project.yml，仅在首次拉取 worktree 后需要）
xcodegen generate

# SwiftLint strict（任何 Swift 改动 commit 前必跑，未通过不得提交）
swiftlint lint --strict

# 快速编译检查（验证类型一致性与编译错误）
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# 单文件单元测试（Phase 0/1 任务验证，-only-testing 限定单个测试类）
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorTests'

# XCUITest 本地编译验证（仅编译，不运行，避免污染本机 UI 状态）
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindUITests/ToastBasicUITests'
```

### 6.2 CI 必跑（本地不执行）

```bash
# 全量测试（CI 兜底，含 XCUITest 全量回归）
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### 6.3 失败处理

- **SwiftLint strict 失败**：必须修复后才能 commit，禁止用 `// swiftlint:disable` 绕过（除非有明确架构理由并在 commit message 说明）。
- **xcodebuild build 失败**：修复类型一致性错误（D 决策落地位置索引中的类型签名必须前后一致）。
- **xcodebuild test -only-testing 失败**：按 TDD 循环修复，不得跳过测试或降低断言强度。
- **XCUITest 失败（仅 CI）**：由 CI 报告，本地不执行；修复后由 CI 重新验证。

---

## 7. 三层测试策略

| 层级 | 工具 | 覆盖 AC | 执行位置 | 负责任务 |
|------|------|---------|----------|----------|
| 第 1 层：XCTest 单元测试 | XCTest | 状态机 8 个转换、7 个错误场景、跳过/总开关校验、通知订阅、计时器源、窗口承载模块内部逻辑（业务可验证部分） | 本地 `-only-testing` + CI 全量 | Phase 0 任务 1~5、Phase 1 任务 11 |
| 第 2 层：XCUITest UI 测试 | XCUITest | AC-01 Toast 出现、AC-02 2 秒消失、AC-03 文件名、AC-04 替换、AC-05 跳过、AC-06 总开关关闭、AC-07 失败、AC-08 动画、AC-09 位置、AC-10 Sandbox 合规、AC-11 不依赖焦点 | 仅 CI（本地不执行，避免污染本机 UI 状态） | Phase 0 任务 7、Phase 1 任务 9、12、13 |
| 第 3 层：手动 OS 边界测试 | 人工 | 动画视觉效果录屏、源 App 全屏遮挡、TCC 弹窗验证、Instruments 性能验证、跨应用前台语义 | 开发者本机手动 | Phase 1 任务 13 |

**原则：** XCTest 覆盖所有业务逻辑可验证的状态转换与错误场景；XCUITest 只验证 UI 交互（不重复 XCTest 已覆盖的逻辑）；手动测试只验证 OS 边界（真实 Safari/Notes 复制、动画视觉、Instruments 性能、TCC 弹窗），不验证可自动化的逻辑。

---

## 8. 全局约束（每步必检，共 10 条）

1. **禁止占位符**：任何步骤不得出现"待定"/"TODO"/"后续实现"/"类似任务 N"/"添加适当的错误处理"等模糊描述。每个代码步骤必须包含完整可执行代码。
2. **TDD 优先**：每个任务严格按"编写失败测试 → 运行验证失败 → 编写最少实现 → 运行验证通过 → commit"五步执行。不得跳过失败验证步骤。
3. **每步即提交**：每个任务完成后立即 commit，commit message 遵守 Conventional Commits：`<type>(F2.1.1): <subject>`。type 限定为 `feat`/`fix`/`test`/`refactor`/`docs`/`chore`。
4. **SwiftLint strict**：任何包含 Swift 代码的 commit 前必须运行 `swiftlint lint --strict` 并通过。禁止用 `// swiftlint:disable` 绕过。
5. **Allman 大括号 + 4 空格缩进**：所有 Swift 代码必须遵守 `docs/CODING_STANDARDS.md` §4.1。类型/函数/初始化器/控制流的大括号起始行必须独占一行。
6. **LogCategory 日志白名单（设计文档 §8.5 + NFR-005）**：日志只能输出：`module`、`operation`、`phase`、`result`、`errorCode`、`state`、`eventId`、`fileName`（不含路径）。禁止输出：剪贴板原文、文件完整路径（含用户名）、密码、Token、验证码。使用新增的 `LogCategory.toast` 分类，必要时复用 `LogCategory.app`。
7. **不修改 F2.1 既有公共接口（C-04）**：仅监听 `AutoSaveService.savedNotification`，不修改通知名与载荷结构；仅读取 `AutoSaveSettingsStore.load().isEnabled`，不修改 F2.1 配置模块；不修改 F2.1 错误弹窗逻辑。
8. **macOS 12.4 兼容性**：不得使用 macOS 13+ 专属 API（如 `NavigationStack`、`@Observable`）。`NSPanel`、`NSWindow`、`DispatchSourceTimer`、`NotificationCenter` API 必须在 macOS 12.4 可用。
9. **不引入新外部依赖**：仅使用 Foundation/AppKit/SwiftUI/XCTest/XCUITest + 既有 SQLite.swift。不得新增 SPM 依赖。
10. **类型一致性**：后续任务中使用的类型、方法签名、属性名必须与前面任务中定义的完全一致。例如 `ToastCoordinator.State` 在所有任务中必须是同一枚举类型，`TimerSource.schedule(duration:callback:)` 在所有任务中必须是同一方法签名。

---

## 9. 双状态机同步关系（设计文档 §5.4 + R-06）

实现时必须保证以下同步关系，避免状态错配：

| Toast 协调模块状态 | Toast 窗口承载模块状态 | 同步动作 |
|------|------|------|
| 隐藏 | 未创建 | 无窗口资源 |
| 出现中 | 创建中 → 已就绪 | 协调模块调用 `windowManager.show(fileName:)` → 窗口承载模块创建 NSPanel + 启动进入动画 → 完成后回调 `onDidAppear` |
| 已显示 | 已就绪 | 窗口已就绪，2 秒计时进行中 |
| 替换中 | 立即关闭 → 未创建 → 创建中 → 已就绪 | 协调模块调用 `windowManager.closeImmediately()` → 等待 `onDidClose` 回调 → 调用 `windowManager.show(fileName:)` 触发新 Toast |
| 消失中 | 关闭中 → 未创建 | 协调模块调用 `windowManager.hide()` → 启动退出动画 → 完成后回调 `onDidHide` |

**关键不变量：** 协调模块保证"旧关闭"完成后再触发"新进入"，避免新旧窗口并发（R-02 缓解）。

---

## 10. 最终验收方式

### 10.1 Phase 0 验收（核心 Toast 显示）

- [ ] 7 个任务全部 commit 完成，commit history 可查
- [ ] `swiftlint lint --strict` 通过
- [ ] `xcodebuild build` 通过
- [ ] Phase 0 单元测试全部通过（本地 `-only-testing` 逐文件验证）
- [ ] XCUITest `ToastBasicUITests` 编译通过（仅本地 build-for-testing 验证，运行留 CI）
- [ ] AC-01、AC-02、AC-03、AC-06、AC-09、AC-11 的 XCTest 部分通过

### 10.2 Phase 1 验收（替换模式与错误降级）

- [ ] 6 个任务全部 commit 完成
- [ ] `swiftlint lint --strict` 通过
- [ ] `xcodebuild build` 通过
- [ ] 7 个错误场景降级单元测试全部通过
- [ ] F2.1 既有单元测试全部回归通过（不破坏 F2.1 既有行为）
- [ ] XCUITest（AC-04/05/07/08）由 CI 验证通过
- [ ] 手动验收脚本由开发者本机执行并记录结果

### 10.3 整体验收（F2.1.1 功能完整交付）

- [ ] 11 条 AC（AC-01~11）全部覆盖：XCTest 覆盖业务逻辑，XCUITest 覆盖 UI 交互，手动测试覆盖 OS 边界
- [ ] 6 条 NFR（NFR-001~006）全部满足：性能（NFR-001~003）、主线程安全（NFR-004）、日志可检索（NFR-005）、Sandbox 合规（NFR-006）
- [ ] 6 条约束（C-01~06）全部遵守
- [ ] 7 条决策（D1~D7）全部落地，可在代码中追溯
- [ ] 7 个错误场景（E1~E7）全部降级处理
- [ ] 主 Scheme `ClipMind` 构建成功，无需暂存到 `ClipMind-Dev`（合规优先，AGENTS.md 第 10 节）

---

## 11. 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-24 | 初始版本，基于 v1.1 设计文档套件编写；落地 7 条决策（D1~D7）+ 7 个错误场景降级；Phase 0 含 7 任务（ToastView/ToastWindowManager/TimerSource/ToastCoordinator 基础状态机/2 秒计时/AppDelegate 装配/基础 XCUITest），Phase 1 含 6 任务（替换中状态/替换 XCUITest/错误降级/错误单元测试/跳过失败 XCUITest/动画 XCUITest + 手动脚本）；总 13 任务 |
