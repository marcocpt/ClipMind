> 最后更新：2026-07-23 | 版本：v1.2

# F1.9 快捷粘贴面板 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法跟踪进度。每个 Phase 内任务按顺序执行，跨 Phase 严格串行（Phase 1 → 2 → 3 → 4）。Phase 4 涉及 App Store 合规高风险，必须读完整个 Phase 4 子计划再动手。

**目标：** 把"粘贴历史内容"从"切换应用上下文"中解放出来——用户在任意应用按全局快捷键直接在 caret 附近呼出独立快速粘贴面板，单击高亮、双击粘贴、方向键导航、回车粘贴、Esc/失焦/粘贴后自动关闭；无辅助功能权限时降级为"写入剪贴板 + 浮层提示用户手动 Cmd+V"，浮层在剪贴板被消费或超时后消失。

**架构：** 在现有 `UI` 模块下新增 4 个独立控制器（快速粘贴面板控制器 / 快速粘贴面板视图 / 粘贴流程协调器 / 降级浮层控制器）+ 4 个辅助模块（辅助功能服务 / 模拟粘贴按键模块 / 剪贴板写入模块 / 剪贴板消费监听器），全部通过初始化器注入依赖；修改全局快捷键服务把触发行为从"唤起主窗口"改为"呼出快速粘贴面板"，修改列表行视图增加单击/双击/回车回调，修改应用设置新增浮层超时兜底时长字段。**主 Scheme `ClipMind` 必须保持 App Store 合规**：Phase 1-3（无权限降级路径）纯沙盒内实现，完全合规；Phase 4（有权限自动粘贴路径）标注「合规待定」，使用公开 API + 标准 TCC 权限流程，若 App Store 审核拒绝则暂存到 `ClipMind-Dev` Scheme。

**技术栈：** Swift 5.7 / macOS 12.4+ / SwiftUI + AppKit（NSPanel/NSWindow/NSHostingController）/ Carbon RegisterEventHotKey（全局快捷键，现有）/ ApplicationServices（辅助功能权限检测，现有）/ XCTest + XCUITest / SQLite.swift 0.15.0（SPM，现有）

---

## 设计规范与评审

| 文档 | 路径 | 版本 |
|------|------|------|
| 需求文档 | `docs/planning/P0/F1/F1.9_快捷粘贴面板_需求文档.md` | v1.1 |
| 设计文档 | `docs/planning/P0/F1/F1.9_快捷粘贴面板_设计文档.md` | v1.1 |
| 视觉原型 | `docs/planning/P0/F1/F1.9_快捷粘贴面板_视觉原型.html` | v1.0 |
| 测试用例表 | `docs/planning/P0/F1/F1.9_快捷粘贴面板_测试用例表.md` | v1.0 |
| F1 主设计规范 | `docs/planning/P0/F1/F1_ClipMind_设计规范.md` | v1.9 |
| 编码规范 | `docs/CODING_STANDARDS.md` | — |
| 文档同步规则 | `.trae/rules/docs.md` | — |
| 提交规范 | `.trae/rules/git-commit-message.md` | — |

**评审结论**：需求/设计/测试用例表 3 子代理审查全部通过，所有 P0 铁律违规已修复（框架 API 与类名转换为业务术语）。设计文档第 10.3 节明确 Phase 4 方案1（有权限自动粘贴路径）合规待定，回退方案为暂存到 `ClipMind-Dev` Scheme。

---

## Phase 列表

本特性按"风险递增 + 依赖递增"原则拆分为 4 个 Phase，严格串行执行。每个 Phase 完成后必须回归前序 Phase 的测试用例。

| Phase | 标题 | 目标 | 涉及 AC | 任务数 | TDD 步骤数 | UI 证据任务数 | 合规风险 | 预计耗时 |
|-------|------|------|---------|--------|-----------|--------------|---------|---------|
| Phase 1 | 基础面板 | 快捷键改呼出独立 NSPanel + 屏幕中央/上次位置定位 + Esc/失焦关闭 + 默认高亮第一行 + AppSettings 新增浮层超时字段 | AC-F1.9-1, 3, 8, 9, 10（无权限路径） | 7 | 42 | 3 | 低（纯沙盒） | 4-5 小时 |
| Phase 2 | 列表交互 | ClipRowView 单击选中 + 双击触发回调 + 方向键导航 + 回车粘贴回调 + 图片/文件路径类型提示 | AC-F1.9-4, 5, 11 | 6 | 36 | 3 | 低（纯沙盒） | 3-4 小时 |
| Phase 3 | 无权限降级 | 粘贴流程协调器（无权限分支）+ 剪贴板写入模块 + 降级浮层控制器 + 剪贴板消费监听器 + 浮层超时配置生效 | AC-F1.9-7, 12（降级逻辑） | 8 | 48 | 4 | 低（纯沙盒） | 5-6 小时 |
| Phase 4 | Accessibility 路径 | 辅助功能服务（运行时检测 + caret 定位）+ 模拟粘贴按键模块 + 有权限路径协调器分支 + 权限撤销自动降级 | AC-F1.9-2, 6, 10（有权限路径）, 12（真实环境） | 7 | 42 | 4 | **高（合规待定）** | 5-6 小时 |
| **合计** | — | 12 AC 全覆盖 | AC-F1.9-1 ~ AC-F1.9-12 | 28 | 168 | 14 | — | 17-21 小时 |

详见各 Phase 子计划：

- [phase-1-基础面板.md](./phase-1-基础面板.md)
- [phase-2-列表交互.md](./phase-2-列表交互.md)
- [phase-3-无权限降级.md](./phase-3-无权限降级.md)
- [phase-4-accessibility路径.md](./phase-4-accessibility路径.md)

---

## 涉及文件总览

### 新增生产代码文件（10 个，全部位于 `ClipMind/UI/QuickPaste/` 或对应模块下）

| 文件 | 所属 Phase | 职责 |
|------|-----------|------|
| `ClipMind/UI/QuickPaste/QuickPastePanelController.swift` | Phase 1 | 独立 NSPanel 控制器：创建、定位（屏幕中央/上次位置/caret）、显示、关闭、键盘焦点、失焦监听、位置记忆 |
| `ClipMind/UI/QuickPaste/QuickPasteView.swift` | Phase 1 | 面板内容 SwiftUI 视图：搜索框 + LazyVStack 列表 + 默认高亮第一行 + Esc/方向键/回车键盘事件 + 双击回调 |
| `ClipMind/Models/QuickPasteSettings.swift` | Phase 1 | 浮层超时兜底时长持久化（UserDefaults，默认 5 秒，范围 1-30 秒）+ 变更通知 |
| `ClipMind/UI/QuickPaste/PasteCoordinator.swift` | Phase 3 | 粘贴流程协调器：接收双击/回车事件 → 检测权限 → 写剪贴板 → 关闭面板 → 分支有权限/无权限路径 |
| `ClipMind/UI/QuickPaste/ClipboardWriter.swift` | Phase 3 | 剪贴板写入模块：仅写入文本内容，错误返回 |
| `ClipMind/UI/QuickPaste/PasteOverlayController.swift` | Phase 3 | 降级浮层控制器：显示"已复制，按 Cmd+V 粘贴"浮层 + 启动消费监听 + 启动超时计时器 |
| `ClipMind/UI/QuickPaste/ClipboardConsumerWatcher.swift` | Phase 3 | 剪贴板消费监听器：轮询 changeCount，再次变化即视为消费 |
| `ClipMind/Privacy/AccessibilityService.swift` | Phase 4 | 辅助功能服务：运行时查询权限（不弹 TCC）+ 有权限时获取前台应用 caret 位置 + 无 caret 降级到鼠标位置 |
| `ClipMind/UI/QuickPaste/PasteSimulator.swift` | Phase 4 | 模拟粘贴按键模块：仅发送系统标准 Cmd+V 按键事件 |
| `ClipMind/UI/QuickPaste/CaretPanelLocator.swift` | Phase 4 | caret 附近面板定位（有 caret 用 caret，无 caret 降级鼠标位置，无权限降级屏幕中央/上次位置） |

### 修改的现有文件（4 个）

| 文件 | 所属 Phase | 职责变更 |
|------|-----------|---------|
| `ClipMind/App/GlobalHotkeyService.swift` | Phase 1 | `handleHotkeyPressed()` 改发 `.openQuickPaste` 通知（原 `.openMainWindow`） |
| `ClipMind/App/ClipMindApp.swift` | Phase 1 | `AppDelegate` 新增 `quickPastePanelController` 持有 + 监听 `.openQuickPaste` 通知 + 初始化控制器；`StatusItemController` 的 `.openMainWindow` 监听保留 |
| `ClipMind/UI/MenuBar/ClipRowView.swift` | Phase 2 | 新增 `isSelected: Bool` 参数（高亮视觉）+ `onSingleClick` / `onDoubleClick` 可选回调；菜单栏 popover 不传回调即不触发新交互 |
| `ClipMind/UI/Settings/GeneralSettingsView.swift` | Phase 3 | 新增"快速粘贴"分区：浮层超时兜底时长 Stepper（1-30 秒）+ 说明文案 |

### 新增测试文件（14 个）

| 文件 | 所属 Phase | 覆盖 |
|------|-----------|------|
| `ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift` | Phase 1 | TC-F1.9-1-02，验证触发行为变更 |
| `ClipMindTests/UI/QuickPastePanelControllerTests.swift` | Phase 1 | TC-F1.9-3-01/02, TC-F1.9-8-01, TC-F1.9-9-01（单元层）, TC-F1.9-S-02 |
| `ClipMindTests/UI/QuickPasteViewTests.swift` | Phase 1 + 2 | TC-F1.9-4-03/04, TC-F1.9-5-03, TC-F1.9-4-01/02, TC-F1.9-5-01/02, TC-F1.9-11-01/02/03 |
| `ClipMindTests/Models/QuickPasteSettingsTests.swift` | Phase 1 | 浮层超时配置默认值/范围/持久化/变更通知 |
| `ClipMindTests/UI/ClipRowViewInteractionTests.swift` | Phase 2 | TC-F1.9-4-01, TC-F1.9-5-01（单元层验证 isSelected 与回调） |
| `ClipMindTests/UI/PasteCoordinatorTests.swift` | Phase 3 + 4 | TC-F1.9-7-01, TC-F1.9-10-02, TC-F1.9-12-01（降级逻辑）, TC-F1.9-6-01, TC-F1.9-10-01, TC-F1.9-SEC-03 |
| `ClipMindTests/UI/PasteOverlayControllerTests.swift` | Phase 3 | TC-F1.9-7-02/03/04, TC-F1.9-SEC-02 |
| `ClipMindTests/UI/ClipboardConsumerWatcherTests.swift` | Phase 3 | 消费监听器 changeCount 变化检测 |
| `ClipMindTests/UI/ClipboardWriterTests.swift` | Phase 3 | 剪贴板写入模块单元测试 |
| `ClipMindTests/Privacy/AccessibilityServiceTests.swift` | Phase 4 | TC-F1.9-12-01（权限检测不缓存）, TC-F1.9-2-01/02（caret 定位 mock） |
| `ClipMindTests/UI/PasteSimulatorTests.swift` | Phase 4 | TC-F1.9-SEC-03（仅发送标准粘贴按键） |
| `ClipMindTests/UI/CaretPanelLocatorTests.swift` | Phase 4 | caret 定位与降级逻辑 |
| `ClipMindUITests/QuickPastePanelUITests.swift` | Phase 1 + 2 | TC-F1.9-1-01, TC-F1.9-3-01/02, TC-F1.9-4-01/02/03/04, TC-F1.9-5-01/02/03, TC-F1.9-8-01, TC-F1.9-9-01, TC-F1.9-11-01/02/03 |
| `ClipMindUITests/QuickPasteOverlayUITests.swift` | Phase 3 + 4 | TC-F1.9-7-01/02/03/04, TC-F1.9-10-01/02, TC-F1.9-SEC-02 |

### 不修改的复用文件（仅读取/调用，不动）

| 文件 | 复用方式 |
|------|---------|
| `ClipMind/Privacy/PermissionRequester.swift` | Phase 4 复用其 `axTrustedCheck` 闭包（仅查询，`prompt: false`），不调用 `requestAccessibility()`（避免弹 TCC 提示） |
| `ClipMind/UI/ClipStore.swift` | Phase 1 复用其 `clips` 数据源 |
| `ClipMind/Models/ClipItem.swift` | 复用其 `content` / `contentType` 字段判断类型 |
| `ClipMind/UI/MenuBar/StatusItemController.swift` | 不修改，菜单栏 popover 与快速粘贴面板是两个独立入口 |
| `ClipMind/UI/MenuBar/PopoverView.swift` | 不修改，菜单栏 popover 视觉骨架参考 |
| `ClipMind/Utils/LogCategory.swift` / `Logger.swift` | 复用日志分类（`ui` / `app` / `privacy`） |
| `ClipMind/UI/Settings/HotkeyRecorder.swift` | 不修改，快捷键配置 UI 保留 |

---

## 全局验证命令

每个 Phase 完成后必须运行以下命令验证。命令在 worktree 根目录执行：

```bash
# 工作目录（禁止切换到主仓库）
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel

# 1. SwiftLint strict（含 Swift 改动时强制运行，commit 前必过）
swiftlint lint --strict

# 2. 重新生成 Xcode 工程（新增/删除文件后必须）
xcodegen generate

# 3. 完整测试（CI 与本地基线复用同一命令）
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# 4. 快速编译检查（无需跑测试时用）
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

**单测试文件快速验证命令模板**（开发过程中频繁使用）：

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/<TestClassName> \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

**XCUITest 单测试类快速验证**：

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindUITests/<UITestClassName> \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

> **注意**：XCUITest 在本地 macOS 15 上可运行，但部分用例（涉及真实辅助功能权限、真实前台应用 caret）需手动验证，详见各 Phase 的"手动验收"章节。

---

## 最终验收方式

### 自动化验收（CI 必过）

1. `swiftlint lint --strict` 零违规
2. `xcodebuild test` 全量通过（XCTest 单元 + XCUITest UI）
3. 12 条 AC 中可自动化的部分全部 PASS：
   - AC-F1.9-1（XCUITest：快捷键呼出快速粘贴面板）
   - AC-F1.9-3（XCUITest：无权限屏幕中央/上次位置定位）
   - AC-F1.9-4（XCUITest：单击高亮 + 方向键导航 + 默认高亮第一行 + 边界）
   - AC-F1.9-5（XCUITest：双击/回车触发粘贴流程 + 空列表回车无效）
   - AC-F1.9-7（XCUITest + XCTest：降级浮层 + 消费消失 + 超时消失 + 配置变更生效）
   - AC-F1.9-8（XCUITest：Esc 关闭不粘贴）
   - AC-F1.9-9（XCUITest：失焦自动关闭）
   - AC-F1.9-10（XCUITest：粘贴后关闭，有权限/无权限两路径）
   - AC-F1.9-11（XCUITest：图片/文件路径双击提示 + 非阻塞）
   - AC-F1.9-12（XCTest：降级逻辑正确性，权限检测不缓存）

### 手动验收（发布前必做，需真实环境）

1. **AC-F1.9-2**：在备忘录点击光标 → 按快捷键 → 截图对比面板位置与 caret 距离 ≤ 50px
2. **AC-F1.9-2**：在访达（无 caret）→ 按快捷键 → 截图对比面板位置与鼠标位置
3. **AC-F1.9-6**：在备忘录点击光标 → 打开面板 → 双击文本行 → 录屏观察备忘录 caret 位置插入文本
4. **AC-F1.9-12**：在系统设置撤销辅助功能权限 → 触发粘贴 → 观察 自动走降级路径
5. **NFR-001 性能**：用 Instruments 测量快捷键触发到面板出现 ≤ 200ms、双击到剪贴板写入 ≤ 100ms、模拟粘贴 ≤ 300ms、列表交互 ≤ 16ms
6. **NFR-002 稳定性**：连续 100 次打开-粘贴-关闭循环，无崩溃、内存增长 < 5MB
7. **NFR-003 安全性**：收集日志确认无剪贴板原文、浮层仅显示通用文案、模拟粘贴仅发送 Cmd+V
8. **NFR-004 兼容性**：在 macOS 12.4 环境全流程验证
9. **NFR-005 可访问性**：VoiceOver 遍历所有元素、高亮对色盲用户可识别（边框+颜色）
10. **NFR-006 合规性**：代码审查确认无权限降级方案纯沙盒内、有权限方案标注「合规待定」

### App Store 合规验收（Phase 4 完成后）

1. 主 Scheme `ClipMind` 构建产物提交 App Store 审核前，确认：
   - 无权限降级路径（Phase 1-3）使用沙盒内公开 API，无私有 API
   - 有权限路径（Phase 4）使用公开 API（辅助功能 API + 模拟按键 API）+ 标准 TCC 权限流程
   - 设计文档第 10.3 节「合规待定」标注完整
   - 审核备注模板（设计文档第 10.3 节末尾）已准备
2. 若 App Store 审核拒绝有权限路径：
   - 将 Phase 4 代码通过 `#if CLIPMIND_DEV` 编译条件暂存到 `ClipMind-Dev` Scheme
   - 主 Scheme `ClipMind` 仅保留无权限降级路径
   - 在 Phase 4 子计划的"合规回退方案"章节记录决策
   - 提交信息中说明合规方案

---

## 关键技术约束（所有 Phase 必须遵守）

### 编码规范（来自 `docs/CODING_STANDARDS.md`）

1. **Allman 大括号**：所有类型、函数、初始化器、闭包、控制流的开括号独占一行
2. **4 空格缩进**，禁止 tab
3. **日志**：使用 `LogCategory.ui` / `.app` / `.privacy`，禁止 `print()`；日志仅记录元数据（如"已写入剪贴板，长度 256"），**禁止输出剪贴板原文、密码、Token、验证码**
4. **错误处理**：不吞错误，`do-catch` 必须日志 + 重新抛出或映射为项目错误类型
5. **并发**：UI 状态更新必须在 `@MainActor` 或主线程；`actor` 保护共享可变状态；禁止用 `sleep` 等待异步
6. **常量**：无魔术数字/字符串，配置键、通知名、accessibilityIdentifier 使用命名常量
7. **架构**：`UI → 业务模块 → Models/Utils`，禁止反向依赖；依赖通过初始化器注入
8. **测试**：不 mock 被测对象本身，只 mock 外部依赖；异步测试禁止 `sleep`；测试验证行为不验证实现

### F1.9 特定约束（来自需求文档第 11 节 + 设计文档第 10 节）

1. **禁止使用私有 API**：所有实现必须使用公开 API（NFR-006）
2. **禁止绕过沙盒**：所有实现在 App Sandbox 内完成
3. **禁止缓存辅助功能权限状态**：每次粘贴流程重新检测（AC-F1.9-12）
4. **禁止弹 TCC 提示对话框**：快速粘贴面板触发粘贴时仅查询权限状态，不调用 `AXIsProcessTrustedWithOptions(prompt: true)`
5. **禁止日志输出剪贴板原文**：所有日志仅记录元数据
6. **禁止发送任意按键序列**：模拟粘贴仅发送系统标准 Cmd+V
7. **禁止浮层显示剪贴板原文**：浮层仅显示"已复制，按 Cmd+V 粘贴"
8. **禁止修改主窗口功能**：主窗口入口改为菜单栏点击或"查看全部"按钮
9. **禁止删除菜单栏原 popover**：菜单栏 StatusItem toggle 行为保留
10. **禁止用固定 sleep 等待异步**：浮层消失条件用 changeCount 轮询 + DispatchTimer，不用 sleep

### macOS 12.4+ 兼容性约束

1. 不使用 macOS 13+ 专有 API（如 `SwiftUI.onKeyPress`，改用 `NSEvent.addLocalMonitorForEvents`）
2. `NSPanel` 使用 `.nonactivatingPanel` styleMask 实现不抢焦点
3. `AXUIElement` API 在 macOS 12.4 可用
4. `CGEvent` 创建粘贴按键在 macOS 12.4 可用

---

## 面向 AI 代理的工作者说明

### 执行顺序

1. **严格串行**：Phase 1 → 2 → 3 → 4，禁止并行或跳跃
2. **Phase 内任务串行**：每个 Phase 的任务按编号顺序执行，前一个任务的测试通过后才能开始下一个
3. **TDD 四步循环**：每个任务必须先写失败测试 → 运行验证失败 → 写最少实现 → 运行验证通过 → SwiftLint → commit
4. **回归验证**：每个 Phase 完成后必须运行前序 Phase 的测试用例确认无回归

### 提交规范（来自 `.trae/rules/git-commit-message.md`）

- 格式：`<type>(<scope>): <subject>`
- type：`feat` / `fix` / `refactor` / `test` / `docs` / `chore`
- scope：`quick-paste` / `hotkey` / `settings` / `clip-row` / `paste-coordinator` / `overlay` / `accessibility` / `paste-simulator`
- subject：简洁祈使语气，不超过 50 字符
- 示例：`feat(quick-paste): add QuickPastePanelController with screen center positioning`

### 文档同步（来自 `.trae/rules/docs.md`）

- 每个 Phase 完成后，在 `docs/planning/P0/F1/historys/` 追加 `YYYY-MM-DD-F1.9-PhaseN-修改摘要.md`
- Markdown 标题后第一行使用 `> 最后更新：YYYY-MM-DD | 版本：vX.Y`
- 涉及行为变化时同步更新设计文档的"状态变化"章节

### 合规决策点（Phase 4 关键）

Phase 4 开始前必须确认：
1. 主 Scheme `ClipMind` 的 entitlements 文件是否已包含辅助功能权限声明
2. `ClipMind-Dev` Scheme 是否已存在（若不存在需先创建）
3. 是否准备好 App Store 审核备注模板（设计文档第 10.3 节末尾）

若上述任一未就绪，停止 Phase 4 并向用户确认。

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-23 | 初始版本，F1.9 快捷粘贴面板实现计划，4 Phase 28 任务，覆盖 12 AC + 6 NFR，Phase 4 标注合规待定 |
| v1.1 | 2026-07-23 | 修订：修正生产代码/测试文件计数（Fix 2/3）；同步各 Phase 计划修订（Fix 1-20），包括 test hook、accessibilityIdentifier 后缀、testOverlayTimeout 逻辑、PasteCoordinator init 改 Any?、UI 证据保存路径、AC-F1.9-1 手动验收脚本等 |
| v1.2 | 2026-07-23 | 修复第二轮 check-plan 发现的 8 项必须修复项（文件计数、Fix 10 行为一致性、UI 测试 import/identifier/谓词） |