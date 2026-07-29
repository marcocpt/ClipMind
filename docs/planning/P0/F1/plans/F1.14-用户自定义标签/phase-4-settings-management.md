# Phase 4：设置页全局标签管理

> 最后更新：2026-07-29 | 版本：v1.0

**目标：** 设置页展示完整系统/用户标签目录；系统标签全局只读，用户标签以独立确认完成
重命名和删除，取消或失败时保持最近成功状态。

**IN：** Phase 1 原子 rename/delete，Phase 2 `TagStore`，Phase 3 活动标签筛选。

**OUT：** 设置标签 Tab 可操作，SET-001～006 的业务状态可自动验证。

**范围：** AC-12～14、16、17、24。

**非目标：** 修改标签颜色、按条目关联、标签使用统计、标签排序。

---

## 任务 1：设置管理状态机

**文件：**

- 创建：`ClipMind/UI/Settings/TagManagementView.swift`
- 扩充：`ClipMindTests/UI/TagPickerViewModelTests.swift`

- [ ] **步骤 1：编写 RED 状态机测试**

为 `TagManagementViewModel` 覆盖：

- 系统标签不进入可编辑集合；
- 用户标签点击重命名进入 `.editing`；
- 提交有效新名只进入 `.confirmRename`，尚未调用 service；
- 取消编辑或取消确认恢复 `.idle`，未发生 mutation；
- 空白/大小写重名在进入确认前拒绝；
- 删除先进入 `.confirmDelete`，确认后才调用 service；
- service 失败回到 `.idle` 并由 `TagStore` 保持原快照；
- service 成功后所有消费者按同一 tag ID 显示新名。

- [ ] **步骤 2：实现 ViewModel**

在 `TagManagementView.swift` 定义：

```swift
@MainActor
final class TagManagementViewModel: ObservableObject
{
    enum State: Equatable
    {
        case idle
        case editing(tagID: ClipTagID)
        case confirmRename(tagID: ClipTagID, oldName: String, newName: String)
        case confirmDelete(tagID: ClipTagID, name: String)
    }

    @Published var state = State.idle
    @Published var draftName = ""
    @Published var validationMessage: String?

    private let store: TagStore

    init(store: TagStore)
    {
        self.store = store
    }
}
```

实现并测试：

```swift
func beginRename(_ tag: ClipTag)
func submitRename()
func confirmRename()
func cancelRename()
func beginDelete(_ tag: ClipTag)
func confirmDelete()
func cancelDelete()
```

`beginRename` / `beginDelete` guard `tag.source == .user`。
`submitRename()` 调用 Phase 1 的唯一
`TagNameValidator.validate(candidate:existingTags:excluding:)`，传入
`store.snapshot.allTags` 和当前 stable ID；通过后才进入 `.confirmRename`。
`TagService.renameUserTag` 提交前再次调用同一 validator 处理并发目录变化。
ViewModel 不自行 trim、fold 或遍历比较名称。

## 任务 2：标签管理视图

**文件：**

- 完成：`ClipMind/UI/Settings/TagManagementView.swift`
- 修改：`ClipMind/UI/Settings/SettingsView.swift`
- 修改：`ClipMind/App/SettingsWindowAssembly.swift`
- 修改：`ClipMind/App/ClipMindApp.swift`
- 修改：`ClipMindTests/UI/SettingsViewAutoSaveTabTests.swift`

- [ ] **步骤 1：实现目录分区**

`TagManagementView` 使用两个 section：

```swift
Section("自动分类标签")
{
    ForEach(SystemTagCatalog.all)
    { tag in
        tagIdentity(tag, metadata: "自动分类 · 可按条目移除")
            .accessibilityIdentifier("systemTagRow_\(tag.id.rawValue)")
    }
}

Section("用户自定义标签")
{
    ForEach(store.snapshot.userTags)
    { tag in
        userTagRow(tag)
            .accessibilityIdentifier("userTagRow_\(tag.id.rawValue)")
    }
}
```

`tagIdentity` 显示 `TagPillView`、来源文字和“颜色不可修改”；系统 section 不创建重命名或删除按钮。
用户按钮 identifier：

```text
renameTag_<tagID>
deleteTag_<tagID>
```

- [ ] **步骤 2：实现两阶段重命名**

编辑行显示 `TextField`、取消、提交。提交有效名称后关闭编辑行并弹独立确认 dialog：

```text
将标签“旧名称”重命名为“新名称”？此操作将影响所有关联条目。
```

确认按钮调用 `viewModel.confirmRename()`；取消调用 `cancelRename()`。
确认成功依靠 `TagStore.snapshot` 传播，不手工修改各入口字符串。

- [ ] **步骤 3：实现删除二次确认**

dialog 文案固定：

```text
删除标签“名称”？该标签将从所有条目中移除，此操作不可撤销。
```

取消不调用 service；确认调用 `.delete(tagID:)`。失败显示 `TagStore.errorMessage`
和 `settingsTagRetryButton`，错误文本不得包含标签名。

- [ ] **步骤 4：实现焦点恢复**

ViewModel 记录触发 button 的 tag ID；取消或完成后使用 `@AccessibilityFocusState`
把焦点返回对应 rename/delete button。dialog 初始焦点落在取消按钮，Tab 只遍历 dialog 控件，
Escape 等同取消。

- [ ] **步骤 5：新增 Settings Tab**

`SettingsTab` 增加 `.tags`，`tabFromArgument` 支持：

```text
--UITEST_INITIAL_TAB=tags
```

Tab label：

```swift
Label("标签", systemImage: "tag.fill")
    .accessibilityIdentifier("tagsTab")
```

原 4 个 Tab 的 raw 行为不变，未知参数仍回退 `.apiKey`。

`ClipMindApp` 的 SwiftUI Settings scene、`SettingsWindowAssembly` 的 AppKit window 与
`MainWindow.showSettingsInStandaloneWindow()` 都使用传入的同一个 `tagStore` 并调用
`SettingsView(tagStore:)`；禁止在任何设置窗口路径创建第二个 store 或数据库连接。

- [ ] **步骤 6：运行 GREEN 与设置回归**

运行：

```text
ClipMindTests/TagPickerViewModelTests
ClipMindTests/SettingsViewAutoSaveTabTests
ClipMindUITests/SettingsUITests
```

本 Phase 的 `TagSettingsUITests` 在任务 4 远程 UI Smoke 执行；Phase 5 只扩充 fail-once、
跨入口负向证据和辅助功能场景。当前步骤至少 build-for-testing 成功。

## 任务 3：全局传播和活动筛选清理

**文件：**

- 修改：`ClipMind/UI/MainWindow/MainWindow.swift`
- 修改：`ClipMind/UI/MenuBar/UnifiedPastePanelView.swift`
- 修改：`ClipMindTests/UI/CompositeClipFilterTests.swift`

- [ ] **步骤 1：测试重命名传播**

用相同 tag ID 的旧/新 snapshot 断言：

- 三入口通过 `TagStore.tags(for:)` 立即得到新名称；
- tag ID、颜色和关联顺序不变；
- 活动筛选 chip 显示新名称，resultId 集合不变。

- [ ] **步骤 2：测试删除传播**

删除 mutation 后断言：

- snapshot 用户目录不含目标；
- 所有 clip state 不含目标 ID；
- `TagFilterSelection.selectedTagIDs` 自动移除目标；
- 三入口、历史、搜索和设置都不显示目标；
- 其他搜索与来源条件保持。

- [ ] **步骤 3：实现筛选选择清理**

`MainWindow` 观察 `tagStore.snapshot.allTags.map(\.id)`：

```swift
let validTagIDs = Set(newSnapshot.allTags.map(\.id))
tagFilterSelection.selectedTagIDs.formIntersection(validTagIDs)
```

系统标签始终有效。重命名不改变 ID，因此不会清除活动条件。

- [ ] **步骤 4：提交设置管理**

```bash
git add \
  ClipMind/UI/Settings/TagManagementView.swift \
  ClipMind/UI/Settings/SettingsView.swift \
  ClipMind/App/SettingsWindowAssembly.swift \
  ClipMind/App/ClipMindApp.swift \
  ClipMind/UI/MainWindow/MainWindow.swift \
  ClipMind/UI/MenuBar/UnifiedPastePanelView.swift \
  ClipMindTests/UI
git commit -m "feat(tags): add settings tag management"
```

## 任务 4：同步设置管理 UI Smoke

**文件：**

- 创建：`ClipMindUITests/TagSettingsUITests.swift`
- 修改：`.github/workflows/tag-ui-smoke.yml`

- [ ] **步骤 1：编写 SET-001～006 当前能力测试**

通过 `--UITEST_INITIAL_TAB=tags` 驱动真实 Settings window，覆盖系统只读、用户 rename/delete
两阶段确认、取消、空白/重名拒绝、stable ID 跨入口传播、失败回滚与 retry，以及 dialog
键盘焦点恢复。测试只读取可访问性树，不读取数据库或 `TagStore.snapshot`。

- [ ] **步骤 2：把测试加入 Smoke**

workflow 新增 `TagSettingsUITests` 选择器。当前 SHA 远程成功后才可进入 Phase 5；
Phase 5 仅扩充 fail-once 组合、跨入口负向证据和辅助功能覆盖。

- [ ] **步骤 3：提交设置 Smoke**

```bash
git add \
  .github/workflows/tag-ui-smoke.yml \
  ClipMindUITests/TagSettingsUITests.swift
git commit -m "test(tags): add settings tag UI smoke"
```

## Phase 4 Local Gate

- 系统标签只读且仍可筛选。
- 用户标签重命名严格包含编辑提交和独立确认两个步骤。
- 删除明确二次确认和不可撤销影响。
- 取消、校验失败、持久化失败均保持目录与关联。
- 重命名/删除通过 stable tag ID 传播，不复制字符串状态。
- dialog 可键盘操作并恢复焦点。
- SwiftLint strict 0 violation，无签名 build succeeded。
- push 当前提交并等待 F1.14 UI Smoke；失败不得进入 Phase 5。

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-29 | 固定设置目录、两阶段重命名、删除确认、焦点和跨入口传播。 |
