# Phase 5：跨入口 UI 证据与稳定性

> 最后更新：2026-07-29 | 版本：v1.0

**目标：** 用真实入口、真实可访问性元素、确定性失败注入和粘贴 positive control 证明 F1.14
用户行为；建立性能、稳定性和辅助功能 Gate。

**IN：** Phase 1～4 的完整生产能力。

**OUT：** UI-ENTRY、UI-MENU、FLT、SET、MIG、PERF、STAB、A11Y、REG 的自动化和人工证据。

**非目标：** 用 View 属性、mock、日志、layer 数量或静态截图替代用户可见行为。

---

## 任务 1：Dev-only UI-test 夹具与失败注入

**文件：**

- 扩充：`ClipMind/App/TagUITestSupport.swift`
- 修改：`ClipMind/App/AppDelegate+UITestOverrides.swift`
- 修改：`ClipMind/App/ClipMindApp.swift`
- 修改：`ClipMind/App/QuickPasteAssembly.swift`
- 修改：`ClipMind/App/StatusItemAssembly.swift`
- 修改：`ClipMind/App/PopoverPreviewWindowFactory.swift`
- 创建：`ClipMind/App/SandboxUpgradeSeedSupport.swift`
- 修改：`ClipMind/UI/QuickPaste/PasteSimulator.swift`
- 修改：`ClipMindTests/UI/PasteSimulatorTests.swift`

- [ ] **步骤 1：定义命名启动参数**

在 Phase 2 基本 fixture 上，只在 `#if CLIPMIND_DEV` 扩充以下参数：

```text
--UITEST_TAG_MIGRATION_FIXTURE
--UITEST_TAG_PASTE_PROBE
--UITEST_UPGRADE_SEED_DEFAULT_PATH
```

Release 构建不得创建夹具数据库、失败 decorator、接收窗口、可访问性探针或测试通知。

`SandboxUpgradeSeedSupport` 与普通隔离 fixture 是两条明确分开的路径。它只在
`CLIPMIND_DEV + --UITEST_UPGRADE_SEED_DEFAULT_PATH` 下启用，并同时要求：

- 环境变量 `CLIPMIND_ALLOW_DEFAULT_PATH_SEED=1`；
- 当前 home 存在 `.clipmind-f114-disposable-upgrade-account` marker；
- app 当前没有 Sandbox entitlement（Phase 5 已提交 unsandboxed SHA）。

缺一项立即以固定错误码退出。满足时才通过生产 `EncryptedStore()` 向旧默认
`${ApplicationSupport}/ClipMind` 写入 upgrade fixture、执行 SQLite checkpoint、关闭连接并退出。
普通 Phase 2～5 Smoke 永远使用隔离 DB，不设置这组 marker/env，不能污染开发者真实数据。

- [ ] **步骤 2：验证并复用 fail-once repository decorator**

Phase 2 已实现全 operation 的 decorator；本 Phase 不创建第二份失败注入。下面是必须保持的
闭集合同，新增 paste/migration 组合测试前先用单元测试逐分支验证：

```swift
#if CLIPMIND_DEV
final class FailOnceTagRepository: TagRepository
{
    private let wrapped: TagRepository
    private let failingOperation: TagOperation
    private var hasFailed = false

    init(wrapped: TagRepository, failingOperation: TagOperation)
    {
        self.wrapped = wrapped
        self.failingOperation = failingOperation
    }

    func loadSnapshot() throws -> TagSnapshot
    {
        try wrapped.loadSnapshot()
    }

    func apply(_ mutation: TagMutation) throws
    {
        let operation = mutation.operation
        if operation == failingOperation, !hasFailed
        {
            hasFailed = true
            throw TagError.persistenceFailed
        }
        try wrapped.apply(mutation)
    }

    func migrateNextBatch(limit: Int) throws -> TagMigrationBatchResult
    {
        if failingOperation == .migrate, !hasFailed
        {
            hasFailed = true
            throw TagError.persistenceFailed
        }
        return try wrapped.migrateNextBatch(limit: limit)
    }
}
#endif
```

`TagMutation.operation` 是 exhaustive 计算属性。decorator 不读取或记录 associated 标签名。

- [ ] **步骤 3：扩充确定性标签夹具**

复用 Phase 2 的固定 UUID、内容、来源、系统/用户标签和关联；新增 migration 与 fail-once
组合。任何扩充仍通过正式 `EncryptedStore` / `TagService`，不直接修改 View 状态。

- [ ] **步骤 4：验证 Release 排除**

运行：

```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath build/F1.14-release-probe \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
if strings "build/F1.14-release-probe/Build/Products/Release/ClipMind.app/Contents/MacOS/ClipMind" \
  | rg "UITEST_TAG_|TagUITestSupport|FailOnceTagRepository|TagPasteProbe|SandboxUpgradeSeedSupport"
then
  echo "Dev-only tag support leaked into Release"
  exit 1
fi
```

预期：Release build succeeded，扫描无命中且脚本退出 0。

## 任务 2：粘贴 negative evidence 探针

**文件：**

- 扩充：`ClipMind/App/TagUITestSupport.swift`
- 修改：`ClipMind/UI/MenuBar/UnifiedPastePanelView.swift`
- 扩充：`ClipMindUITests/TagEntryUITests.swift`

- [ ] **步骤 1：实现受控接收窗口**

`TagPasteProbe` 仅在 `#if CLIPMIND_DEV && --UITEST_TAG_PASTE_PROBE` 创建：

- 一个真实可编辑 `NSTextField`，初始值 `TAG_PASTE_SENTINEL`；
- `controlTextDidChange` 在真实文本变化时增加 `pasteEventCount`；
- reset 恢复 sentinel 和 count 0；
- panel 内只读暴露 `pasteReceiverText`、`pasteEventCount`、`tagPasteProbeReset`。
- 暴露只读 `pasteReceiverFocused`，只有 probe window 为 key window 且 `NSTextField`
  是 first responder 时才为 true。

探针不写磁盘，不发送日志，不在 Release 编译。

- [ ] **步骤 2：为 UI-test 模式增加受控真实事件例外**

当前 `PasteSimulator` 遇到 `--UITEST_QUICK_PASTE_PANEL` 会无条件跳过 CGEvent，因此本任务必须
先改变这条生产 Dev 路径，而不能声称“复用已有真实路径”。

在 `PasteSimulator.swift` 定义 `PasteEventSafetyChecking`。默认策略在任何 UI-test 参数下
返回 false；`TagPasteProbeSafetyPolicy` 只有同时满足以下条件才返回 true：

- 存在 `--UITEST_TAG_PASTE_PROBE`；
- probe window 仍是 key window；
- receiver 仍是 first responder；
- receiver sentinel 和 eventCount 都处于已 reset 状态。

`simulatePaste()` 的分支固定为：

1. 有注入 `eventSender` 时走 mock（单元测试）；
2. 普通 `--UITEST_QUICK_PASTE_PANEL` 继续跳过；
3. probe 模式且 safety policy 为 true 时调用真实 `sendViaCGEvent()`；
4. probe 模式但安全条件失败时跳过并发布仅含固定结果码的可访问性失败状态。

`QuickPasteAssembly`、`StatusItemAssembly` 和 `PopoverPreviewWindowFactory` 仅在
`CLIPMIND_DEV + --UITEST_TAG_PASTE_PROBE` 注入该策略/PasteSimulator。`PasteSimulatorTests`
覆盖普通 UI-test 跳过、armed probe 发送完整 Cmd+V 四事件、失焦 probe 拒绝发送。

- [ ] **步骤 3：编写 positive control**

每个菜单栏弹窗和快捷粘贴测试先：

1. 激活接收文本框；
2. 等待 `pasteReceiverFocused == true`；
3. 打开对应 nonactivating panel，并再次断言 receiver 仍聚焦；
4. 对文本条目执行双击粘贴路径；
5. 等待 `pasteReceiverText != TAG_PASTE_SENTINEL` 且 `pasteEventCount == 1`；
6. 点击 `tagPasteProbeReset`，确认 sentinel、0 和 focused 状态恢复。

等待使用 `XCTNSPredicateExpectation` / `waitForExistence`，不得固定 sleep。

- [ ] **步骤 4：编写标签点击负向断言**

`TagEntryUITests` 覆盖 UI-ENTRY-001～006：

- 主窗口点击标签/“+”：picker 出现，row 未选中，detail 未打开；
- 菜单栏弹窗点击标签/“+”：picker 出现，panel 不关闭，receiver sentinel，count 0；
- 快捷粘贴面板点击标签/“+”：picker 出现，高亮 ID 不变，panel 不关闭，receiver sentinel，count 0。

测试读取：

```text
tagPickerSearch
selectedRowId
detailPanelState
pasteReceiverText
pasteEventCount
popoverSearchField / quickPasteSearchField
```

只检查 panel 可见或内部回调计数不能单独通过。

## 任务 3：标签菜单和设置端到端测试

**文件：**

- 扩充：`ClipMindUITests/TagPickerUITests.swift`
- 扩充：`ClipMindUITests/TagSettingsUITests.swift`

- [ ] **步骤 1：实现 UI-MENU 测试**

按 Test Matrix 一一实现：

| 测试 | 必须读取的真实结果 |
|------|-------------------|
| UI-MENU-001 | 可见 `tagOption_*` 名称集合过滤/恢复 |
| UI-MENU-002 | `tagCreateEntry` 可见文本 |
| UI-MENU-003 | 新 pill、已选择 value、搜索清空 |
| UI-MENU-004 | pill 立即增删、dialog 数为 0 |
| UI-MENU-005 | 重启后 pill 集合 |
| UI-MENU-006 | 上限提示、checkbox 未选、计数仍 5 |
| UI-MENU-007 | 设置目录无候选名、条目仍 5 |
| UI-MENU-008 | 系统 pill 移除并在重启后保持 |
| UI-MENU-009 | 满额恢复拒绝、释放后恢复、其他系统项不存在 |
| UI-MENU-010 | 11 个具名色按钮、无自定义色输入、无颜色编辑 |
| UI-MENU-011 | fail-once 后原 pill、safe error、retry 后成功 |

- [ ] **步骤 2：实现 SET 测试**

`TagSettingsUITests` 覆盖：

- 删除取消保持、再次删除确认后目录/三个入口/结果消失；
- 重命名编辑提交后出现独立确认框；
- 取消、空白、系统重名和用户重名保持原状态；
- 确认后 stable ID 的名称跨入口更新、顺序不变；
- 系统标签无 rename/delete button，用户标签有；
- fail-once 时全局回滚，retry 成功；
- dialog 初始焦点、Tab 循环、Escape、焦点返回。

测试不得访问数据库或 `TagStore.snapshot`。

## 任务 4：组合筛选和迁移端到端测试

**文件：**

- 扩充：`ClipMindUITests/TagFilterUITests.swift`
- 创建：`ClipMindUITests/TagMigrationUITests.swift`

- [ ] **步骤 1：实现 FLT UI 测试**

使用 Phase 3 固定 resultId：

1. 搜索“需求” + 来源 Pages + “重要” → `{tag-result-1, tag-result-2}`；
2. 再选“待处理” → `{tag-result-1}`；
3. 选 CODE → 真实筛选空态；
4. 移除 CODE → `{tag-result-1}`；
5. 清空全部标签 → 搜索和 Pages chip 仍在；
6. 清空数据库启动 → `historyEmptyState`，不得出现筛选空态；
7. 历史/搜索容器应用同 intent 时 resultId 集合相同。

- [ ] **步骤 2：实现迁移 UI 测试**

`--UITEST_TAG_MIGRATION_FIXTURE` 创建 100 条 legacy 数据和一个 removed disposition 条目。
断言：

- 首个 `mainWindowInteractive` 在迁移完成前可见；
- fail-once 后 `tagMigrationRetryButton` 与不含标签名/内容的安全错误可见；
- 重启继续且最终 100 条无重复；
- removed 条目仍显示“+”；
- CODE/LINK/ERROR 文本、颜色 accessibility value 与旧基线一致。

## 任务 5：性能与稳定性

**文件：**

- 创建：`ClipMindTests/Performance/TagPerformanceTests.swift`
- 创建：`ClipMindTests/Performance/TagStabilityTests.swift`
- 创建：`ClipMindUITests/TagPerformanceUITests.swift`
- 修改：`project.yml`

- [ ] **步骤 1：领域性能**

固定 macOS 15 arm64 Release、1000 条夹具。每项预热 1 次、测量 20 次：

- `tagSearch` p95 ≤ 100ms；
- `tagAssociationToggle` p95 ≤ 50ms；
- `tagFilter` p95 ≤ 200ms；
- `tagMigration` p95 ≤ 3s。

每次保存原始毫秒样本；升序第 19 个是 nearest-rank p95。signpost 只使用固定操作名和结果码。
领域与迁移性能使用主 Scheme `ClipMind`、`Release`、`ARCHS=arm64`。

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -configuration Release \
  -destination 'platform=macOS' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests/TagPerformanceTests
```

- [ ] **步骤 2：UI 性能**

`project.yml` 增加 `ReleaseDev: release` 配置，仅设置
`SWIFT_ACTIVE_COMPILATION_CONDITIONS: CLIPMIND_DEV`；它继承 Release 优化和主 target 生产代码，
只让确定性 fixture/probe 可用。`ClipMind-Dev` 不增加 archive 动作。修改后运行
`xcodegen generate`，把生成的 `ClipMind.xcodeproj/project.pbxproj` 与 `project.yml`
放在同一提交。

三个真实入口分别测量：

- 激活标签到 `tagPickerSearch` hittable ≤ 200ms；
- 确认创建到新 `clipTag_*` hittable ≤ 200ms；
- 20 组无迁移/1000 条迁移交替启动，`mainWindowInteractive` 差值 p95 ≤ 200ms。

使用 `XCTOSSignpostMetric` 或显式 `ContinuousClock` 样本；不以进程启动结束替代可交互结果。
在 macOS 15 arm64 上使用 `ClipMind-Dev` / `ReleaseDev` 执行；证据记录
`SWIFT_OPTIMIZATION_LEVEL`、runner image、CPU、内存和架构，不能使用 `DebugDev` 数值判阈值。

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -configuration ReleaseDev \
  -destination 'platform=macOS' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindUITests/TagPerformanceUITests
```

- [ ] **步骤 3：自动稳定性**

`TagStabilityTests` 对 create/attach/detach/rename/delete 各 100 次，
每轮校验目录 ID 唯一、关联引用有效、每条 ≤ 5、系统资格正确。
随后执行组合/清空筛选和迁移中断恢复，断言 resultId、计数和快照一致。

- [ ] **步骤 4：固定 Instruments 程序**

定义在 `ClipMind-Dev` / `ReleaseDev` 自动签名 App 上执行同一 100 次脚本和
Allocations/Leaks 的步骤。Phase 5 只验证脚本可启动；具有验收效力的证据必须在 Phase 6
exact integration SHA 和 Final Candidate exact SHA 各重跑一次，保存：

```text
docs/planning/P0/F1/evidence/F1.14/<sha>/STAB-002.trace
docs/planning/P0/F1/evidence/F1.14/<sha>/STAB-002-summary.md
```

通过条件：0 leak，稳定阶段无持续单向内存增长，结束后标签交互仍可完成。

## 任务 6：辅助功能人工与自动证据

**文件：**

- 创建：`ClipMindUITests/TagAccessibilityUITests.swift`

- [ ] **步骤 1：键盘 XCUITest**

仅用键盘遍历并激活：

- 三入口 pill 和“+”；
- picker 搜索、checkbox、11 色、创建/取消；
- filter 候选和活动 chip 删除；
- 设置 rename/delete 和确认 dialog。

断言 focus 状态、动作结果、dialog 焦点返回。

- [ ] **步骤 2：固定 VoiceOver / Inspector 程序**

定义用真实 `ClipMind-Dev` / `ReleaseDev` 记录每类控件名称、角色、值、状态和颜色名称的
步骤。Phase 6 exact integration SHA 与 Final Candidate exact SHA 均需重新执行并保存：

```text
docs/planning/P0/F1/evidence/F1.14/<sha>/A11Y-002.md
docs/planning/P0/F1/evidence/F1.14/<sha>/A11Y-002-*.png
```

任何只朗读颜色、不朗读标签名/来源/选择状态的控件都判失败。

## 任务 7：提交 UI 证据套件

- [ ] **步骤 1：构建 UI test bundle**

远程 Smoke 的真实 panel、粘贴 positive control 和 Dev-only probe 使用
`ClipMind-Dev` / `DebugDev`，按 CI 基线策略禁用签名：

```bash
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

预期：`** TEST BUILD SUCCEEDED **`。

需要人工可见、Accessibility Inspector 或 Instruments 的本机真实 App 证据，另按 README
使用 `ClipMind-Dev` / `DebugDev` 自动签名构建，不传 `CODE_SIGN_*`。主 Scheme 的无签名
build/test 仍按 README Local Gate 单独执行，证明 F1.14 生产代码未只进入 Dev Scheme；
Dev Scheme 仅承载受 `#if CLIPMIND_DEV` 约束的 UI 观测设施。

- [ ] **步骤 2：扩充远程 UI Smoke**

修改 `.github/workflows/tag-ui-smoke.yml`，执行当前 Phase 的 TagEntry、TagPicker、TagFilter、
TagSettings、TagMigration、TagAccessibility 测试；性能长测留在显式 workflow dispatch，
但必须绑定同一 SHA 并保存原始样本 artifact。

- [ ] **步骤 3：提交**

```bash
git add \
  .github/workflows/tag-ui-smoke.yml \
  project.yml \
  ClipMind.xcodeproj/project.pbxproj \
  ClipMind/App/TagUITestSupport.swift \
  ClipMind/App/AppDelegate+UITestOverrides.swift \
  ClipMind/App/ClipMindApp.swift \
  ClipMind/App/QuickPasteAssembly.swift \
  ClipMind/App/StatusItemAssembly.swift \
  ClipMind/App/PopoverPreviewWindowFactory.swift \
  ClipMind/App/SandboxUpgradeSeedSupport.swift \
  ClipMind/UI/QuickPaste/PasteSimulator.swift \
  ClipMind/UI/MenuBar/UnifiedPastePanelView.swift \
  ClipMindTests/Performance \
  ClipMindTests/UI/PasteSimulatorTests.swift \
  ClipMindUITests/TagEntryUITests.swift \
  ClipMindUITests/TagPickerUITests.swift \
  ClipMindUITests/TagFilterUITests.swift \
  ClipMindUITests/TagSettingsUITests.swift \
  ClipMindUITests/TagMigrationUITests.swift \
  ClipMindUITests/TagAccessibilityUITests.swift \
  ClipMindUITests/TagPerformanceUITests.swift
git commit -m "test(tags): add observable tag coverage"
```

## Phase 5 Gate

- UI-ENTRY、UI-MENU、FLT、SET、MIG、A11Y 自动测试通过。
- 菜单栏/快捷粘贴标签点击均有真实 paste positive control 和 sentinel/count negative evidence。
- fail-once 覆盖 6 类操作，失败后 UI 是最近成功状态。
- Release/ReleaseDev 性能、Instruments 和 Inspector 程序可在固定环境执行；
  本 Phase 的快速样本只作校准，验收样本留给 Phase 6 exact SHA。
- STAB-001 自动通过；STAB-002/A11Y-002 的最终 artifact 不引用 pre-commit SHA。
- Release 二进制无测试探针字符串。
- SwiftLint strict 0 violation，无签名 build/build-for-testing succeeded。
- 当前 SHA 的远程 UI Smoke 成功。

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-29 | 固定 Dev-only 夹具、真实粘贴负向探针、端到端、性能、稳定性和辅助功能证据。 |
