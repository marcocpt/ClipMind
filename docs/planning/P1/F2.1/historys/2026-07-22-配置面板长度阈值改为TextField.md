> 最后更新：2026-07-22 | 版本：v1.1

# 2026-07-22 F2.1 配置面板长度阈值/文件名长度改为 TextField

## 变更摘要

将"自动保存"配置面板中的"长度阈值"与"文件名长度"两项从 `Stepper` 改为 `TextField`（数字输入框），使其与视觉原型 HTML 的 `<input type="number">` 契约一致。同时修订视觉原型提示文案、设计文档、测试用例表与实现计划。

**修订前**：Phase 1 实现时使用了 `Stepper` 控件，与视觉原型 HTML（`<input type="number">`）不一致；Stepper 在大范围（1~10000）下操作繁琐（需点击上千次），用户体验差。

**修订后**：恢复为 `TextField` + 数字键盘 + 失焦自动应用 + 越界夹紧到边界，符合视觉原型契约与用户偏好（失焦自动应用，无需回车）。

## 改了什么

### 1. 视觉原型 HTML v1.0 → v1.1

`docs/planning/P1/F2.1/F2.1_自动保存到文件_视觉原型.html`

- 长度阈值提示文本：`范围 1-10000，超出范围使用默认值 50` → `范围 1-10000，超出范围自动夹紧到边界`
- 文件名长度提示文本：`范围 1-50，超出范围使用默认值 20` → `范围 1-50，超出范围自动夹紧到边界`
- 控件类型保持 `<input type="number">` 不变（视觉原型本就正确）

### 1.1 需求文档 v1.1 → v1.2

`docs/planning/P1/F2.1/F2.1_自动保存到文件_需求文档.md`

- **C-04 修订**：`文件名前缀长度限制在 1-50 字之间，超出范围时使用默认值 20 字` → `文件名前缀长度限制在 1-50 字之间，超出范围时自动夹紧到边界`
- **C-05 修订**：`长度阈值限制在 1-10000 字之间，超出范围时使用默认值 50 字` → `长度阈值限制在 1-10000 字之间，超出范围时自动夹紧到边界`
- 修订理由：与决策 C2（夹紧到边界）一致；"使用默认值"会造成 UX 突跳（输入 10001 期望 10000，但变成 50）

### 2. AutoSaveSettingsView.swift 修改

`ClipMind/UI/Settings/AutoSaveSettingsView.swift`

- **控件替换**：`Stepper` → `TextField`，绑定到本地 `@State` 字符串（`lengthThresholdText` / `fileNameLengthText`）
- **accessibilityIdentifier 更名**：`lengthThresholdStepper` → `lengthThresholdField`，`fileNameLengthStepper` → `fileNameLengthField`
- **新增 `clampedValue(_:range:fallback:)` 工具方法**：解析字符串 → Int；失败/空值回退到 fallback；越界夹紧到 range 边界
- **新增 `applyLengthThreshold()` 与 `applyFileNameLength()` 方法**：调用 `clampedValue` → 写回 `settings` → `saveSettings()`
- **失焦捕获实现（回车 + 失焦 双保险）**：
  - `.onSubmit` 触发应用（按回车）
  - 新增 `FocusedTextField` NSViewRepresentable wrapper，监听 `controlTextDidEndEditing` 通知失焦（macOS 12.4 兼容，因为 `@FocusState` 在 macOS 12 上写入不稳定）
- **范围提示文本**：控件下方显示 `范围 1-10000 字` / `范围 1-50 字`

### 3. 测试用例表 v1.2 → v1.3

`docs/planning/P1/F2.1/F2.1_自动保存到文件_测试用例表.md`

- 新增 TC-UT-70：长度阈值 TextField 解析与夹紧（边界/越界/空值/非数字）
- 新增 TC-UT-71：文件名长度 TextField 解析与夹紧
- 修订 TC-UT-66：a11y identifier 更名（lengthThresholdStepper → lengthThresholdField）
- 新增 TC-UI-05：AC-07 配置面板验证 TextField 存在（替换原 Stepper 验证）

### 4. AutoSaveSettingsViewTests.swift 修改

`ClipMindTests/UI/AutoSaveSettingsViewTests.swift`

- 新增 `testLengthThresholdClampAboveRange`：输入 10001 → 夹紧到 10000
- 新增 `testLengthThresholdClampBelowRange`：输入 0 → 夹紧到 1
- 新增 `testLengthThresholdEmptyFallback`：空输入 → 回退到当前 settings 值
- 新增 `testLengthThresholdNonNumericFallback`：输入 "abc" → 回退到当前 settings 值
- 新增 `testFileNameLengthClamp`：同上 4 个 case 套用 fileNameLengthRange（1...50）

### 5. AutoSaveSettingsUITests.swift 修改

`ClipMindUITests/AutoSaveSettingsUITests.swift`

- AC-07 测试：a11y identifier 更名（`lengthThresholdStepper`/`fileNameLengthStepper` → `lengthThresholdField`/`fileNameLengthField`），控件类型从 `app.steppers` 改为 `app.textFields`
- 新增 AC-07 子断言：TextField 失焦后值夹紧（输入 10001 → 失焦 → 显示 10000）

### 6. 实现计划 README.md v2.1 → v2.2

`docs/planning/P1/F2.1/实现计划/README.md`

- §4.2 Phase 1 新增文件表：备注 AutoSaveSettingsView.swift 控件类型变更
- §9 版本记录追加 v2.2

### 7. 设计文档同步

`docs/planning/P1/F2.1/F2.1_自动保存到文件_设计文档.md`

- §配置面板描述：Stepper → TextField + 失焦自动应用 + 越界夹紧

## 决策记录

| 决策 | 摘要 | 理由 |
|------|------|------|
| C1 | 控件类型从 Stepper 改为 TextField | 与视觉原型 HTML `<input type="number">` 一致；Stepper 在 1~10000 范围下操作繁琐 |
| C2 | 越界处理策略：夹紧到边界 | 用户选择。比"回退到默认值"更符合用户期望（输入 10001 期望 10000，而非 50） |
| C3 | 空值/非数字处理：回退到当前 settings 值 | 不丢失原值，比回退到默认值更安全（用户可能误清空输入框） |
| C4 | 提交时机：回车 + 失焦 双保险 | 用户 profile 明确"失焦自动应用，无需回车"；同时保留回车提交作为冗余路径 |
| C5 | 失焦捕获实现：@FocusState + .onChange 监听焦点变化 | 初版设计为 NSViewRepresentable 包装 NSTextField 监听 `controlTextDidEndEditing`，但实测在 SwiftUI Form 的 Section 内渲染异常导致整个 AutoSaveSettingsView 无法显示（UI 测试 testAC07 等全部失败）。改用 SwiftUI 原生 TextField + @FocusState + .onChange(of: focused) 监听焦点丢失触发 apply，.onSubmit 监听回车。@FocusState 写入不稳定仅影响"代码强制失焦"，读取焦点变化是稳定的 |
| C6 | 范围提示文本：控件下方显示 "范围 1-10000 字" | 用户可见的边界提示，避免用户输入越界值 |

## 影响范围

### 不变项

- `AutoSaveSettings.swift`：`lengthThresholdRange` / `fileNameLengthRange` / 默认值不变
- `AutoSaveSettingsStore.swift`：持久化逻辑不变（仍由 View 层调用 `saveSettings()` 触发）
- 其他 6 个配置项（总开关、保存目录、白名单、文件格式、路径格式、敏感过滤）不变
- Phase 0 全部 13 个生产代码文件不变
- F1.x 既有模块不变
- 24 条决策（D1~D24）不受影响

### 新增文件

- 无（v1.0 设计的 `ClipMind/UI/Settings/FocusedTextField.swift` NSViewRepresentable wrapper 因渲染异常被弃用，改用 SwiftUI 原生 TextField + @FocusState）

### 修改文件

- `ClipMind/AutoSave/AutoSaveSettings.swift`（新增 clampedInt 静态方法）
- `ClipMind/UI/Settings/AutoSaveSettingsView.swift`（控件替换 + @FocusState 失焦逻辑）
- `ClipMindTests/AutoSave/AutoSaveSettingsTests.swift`（新增 8 个 clampedInt 测试 case：TC-UT-70/71）
- `ClipMindUITests/AutoSaveSettingsUITests.swift`（testAC07 新增 lengthThresholdField/fileNameLengthField 存在性断言）
- `docs/planning/P1/F2.1/F2.1_自动保存到文件_需求文档.md`（C-04/C-05 修订）
- `docs/planning/P1/F2.1/F2.1_自动保存到文件_视觉原型.html`（提示文本修订）
- `docs/planning/P1/F2.1/F2.1_自动保存到文件_设计文档.md`（描述同步）
- `docs/planning/P1/F2.1/F2.1_自动保存到文件_测试用例表.md`（新增 TC-UT-70/71 + TC-UI-05）
- `docs/planning/P1/F2.1/实现计划/README.md`（版本号 v2.2）

## 验证方式

- `swiftlint lint --strict` 通过（0 violations）
- `xcodebuild build` 通过（BUILD SUCCEEDED）
- `xcodebuild test -only-testing:'ClipMindTests'` 通过（449 tests, 0 failures，含新增 8 个 clampedInt 测试 case）
- XCUITest（AC-07 TextField 替换 Stepper）：本地环境 settings 独立窗口 accessibility 暴露问题导致 testAC07 等失败，git stash 验证确认修改前后均失败，非本次改动引入回归，由 CI 环境验证

## 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-22 | 初始版本，记录配置面板长度阈值/文件名长度改为 TextField 的设计决策 |
| v1.1 | 2026-07-22 | C5 决策修订：弃用 NSViewRepresentable wrapper（实测在 SwiftUI Form Section 内渲染异常导致整个 AutoSaveSettingsView 无法显示），改用 SwiftUI 原生 TextField + @FocusState + .onChange(of: focused) 监听焦点丢失 + .onSubmit 监听回车。移除 FocusedTextField.swift 新增文件。更新验证结果（449 单元测试通过，UI 测试环境问题已 stash 验证） |
