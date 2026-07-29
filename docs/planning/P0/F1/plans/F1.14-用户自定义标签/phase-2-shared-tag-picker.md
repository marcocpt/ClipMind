# Phase 2：共享标签条与标签选择菜单

> 最后更新：2026-07-29 | 版本：v1.0

**目标：** 在主窗口、菜单栏弹窗和快捷粘贴面板复用同一标签条与标签选择菜单，
完成搜索、多选、创建、系统标签移除/恢复、上限和持久化失败回滚。

**IN：** Phase 1 的 `TagService`、`TagSnapshot`、迁移与加密 mutation。

**OUT：** UI-MENU-001～011 的状态测试通过；三个入口已接入相同 `TagStore` 和 `ClipTagStripView`。

**范围：** AC-1～9、16、17、22 的 UI 生产能力。

**非目标：** 主窗口标签过滤、设置页全局管理、最终 XCUITest 证据。

---

## 任务 1：`TagStore` 最近成功快照与失败回滚

**文件：**

- 创建：`ClipMind/UI/Tags/TagStore.swift`
- 创建：`ClipMindTests/UI/TagPickerViewModelTests.swift`

- [ ] **步骤 1：编写 RED 状态测试**

使用 `TagServicing` fake，只模拟外部 service 端口，覆盖：

- 首次 load 前是 `.loading`，不把已有条目误显示成可操作“+”；
- 较旧 load 后返回时，不覆盖更新 generation 已发布的新 snapshot；
- create/toggle 快速连续入队，按用户顺序全部执行、不取消、不丢失；
- mutation 成功只在 service 返回后发布新快照；
- mutation service 失败保持当前 `snapshot`（最近成功值），队列停止在失败项；
- 错误文案等于 `TagError.errorDescription` 且不含标签名；
- retry 重放同一结构化失败 operation，成功后继续后续队列；
- migration 每批发布 load 通知时 migration task 不被取消；
- View 消失只取消 load/migration，不取消已经接受的 mutation；AppDelegate 级 store 生命周期负责排空。

- [ ] **步骤 2：实现 `TagStore`**

```swift
import Foundation

@MainActor
final class TagStore: ObservableObject
{
    enum LoadState: Equatable
    {
        case loading
        case ready
        case unavailable
    }

    enum MutationOperation: Equatable
    {
        case create(name: String, color: ClipTagColor, clipID: UUID)
        case setAttached(Bool, tagID: ClipTagID, clipID: UUID)
        case rename(tagID: ClipTagID, name: String)
        case delete(tagID: ClipTagID)
    }

    enum FailedOperation: Equatable
    {
        case mutation(MutationOperation)
        case migration
    }

    @Published private(set) var snapshot: TagSnapshot = .empty
    @Published private(set) var loadState = LoadState.loading
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var failedOperation: FailedOperation?

    private let service: TagServicing
    private let migrationCoordinator: TagMigrationCoordinator
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var mutationTask: Task<Void, Never>?
    private var pendingOperations: [MutationOperation] = []
    private var migrationTask: Task<Void, Never>?

    init(service: TagServicing, migrationCoordinator: TagMigrationCoordinator)
    {
        self.service = service
        self.migrationCoordinator = migrationCoordinator
    }

    deinit
    {
        loadTask?.cancel()
        migrationTask?.cancel()
    }

    func tags(for clipID: UUID) -> [ClipTag]
    {
        snapshot.tags(for: clipID)
    }

    func load()
    {
        // 增加 generation；只允许最新 generation 发布结果。
        // loadTask 可取消，但不得触碰 mutationTask / migrationTask。
    }

    func perform(_ operation: MutationOperation)
    {
        // 把 operation 追加到 pendingOperations；若无 drain，再启动 drainMutationQueue()。
        // 已接受的 operation 不因后续点击或 load 通知而取消。
    }

    func retry()
    {
        // .mutation 放回队首并继续串行 drain；.migration 调 resumeMigration()。
    }

    func resumeMigration()
    {
        // migrationTask 独立调用 coordinator.resume()；失败记录 .migration。
        // 批次通知只触发 load()，不会取消本 task。
    }
}
```

同文件实现三个互不取消的通道：

1. `load()`：取消的只有上一个 `loadTask`；捕获开始时的 generation，只在仍为最新且
   `mutationTask == nil` 时发布结果，否则在 mutation 排空后再 load。
2. `drainMutationQueue()`：单一 `mutationTask` FIFO 执行；每项用 exhaustive `switch`
   调 `TagServicing`，成功发布 service 返回 snapshot；失败保留最近成功快照、记录闭集
   `.mutation(operation)` 并暂停，不吞掉排在其后的意图。
3. `resumeMigration()`：单一独立 `migrationTask` 调 `try await coordinator.resume()`；
   成功再 `load()`，失败记录 `.migration`；批次通知只安排新 generation load。

捕获 `CancellationError` 不显示错误；其他错误映射固定安全文案。所有 View 在
`loadState != .ready` 时显示 loading/unavailable 语义并禁用 mutation，不能把 `.empty`
当作真实无标签状态。不做 optimistic snapshot mutation。

不得把 `Task`、标签名或底层 `localizedDescription` 写日志。

- [ ] **步骤 3：运行 GREEN**

运行 `ClipMindTests/TagPickerViewModelTests` 中 `TagStore` 测试组。预期：全部 PASS。

## 任务 2：统一标签视觉和辅助功能语义

**文件：**

- 创建：`ClipMind/UI/Tags/TagPillView.swift`
- 创建：`ClipMind/UI/Tags/ClipTagStripView.swift`
- 修改：`ClipMind/UI/MenuBar/TypeTagView.swift`
- 修改：`ClipMindTests/UI/ClipRowViewInteractionTests.swift`

- [ ] **步骤 1：编写 RED 视觉契约测试**

纯值断言覆盖：

- 11 个 `ClipTagColor` 各有稳定 `Color` token 和中文颜色名；
- 系统标签 accessibility label 包含“自动分类标签”；
- 用户标签 accessibility label 包含“用户标签”；
- 空标签条暴露 `tagAdd_<clipID>`；
- 标签触发 identifier 为 `clipTag_<clipID>_<tagID>`。

- [ ] **步骤 2：实现 `TagPillView`**

`ClipTagColor` 的 SwiftUI 映射只在此文件定义：

```swift
extension ClipTagColor
{
    var displayName: String
    {
        switch self
        {
        case .violet: return "紫罗兰"
        case .cyan: return "青色"
        case .rose: return "玫红"
        case .blue: return "蓝色"
        case .amber: return "琥珀"
        case .emerald: return "翡翠"
        case .purple: return "紫色"
        case .orange: return "橙色"
        case .teal: return "青绿"
        case .slate: return "石板灰"
        case .gray: return "灰色"
        }
    }

    var swiftUIColor: Color
    {
        switch self
        {
        case .violet: return Color(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255)
        case .cyan: return Color(red: 0x22 / 255, green: 0xD3 / 255, blue: 0xEE / 255)
        case .rose: return Color(red: 0xF4 / 255, green: 0x3F / 255, blue: 0x5E / 255)
        case .blue: return Color(red: 0x3B / 255, green: 0x82 / 255, blue: 0xF6 / 255)
        case .amber: return Color(red: 0xF5 / 255, green: 0x9E / 255, blue: 0x0B / 255)
        case .emerald: return Color(red: 0x10 / 255, green: 0xB9 / 255, blue: 0x81 / 255)
        case .purple: return Color(red: 0xA8 / 255, green: 0x55 / 255, blue: 0xF7 / 255)
        case .orange: return Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
        case .teal: return Color(red: 0x14 / 255, green: 0xB8 / 255, blue: 0xA6 / 255)
        case .slate: return Color(red: 0x64 / 255, green: 0x74 / 255, blue: 0x8B / 255)
        case .gray: return Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
        }
    }
}
```

`TagPillView` 接收 `ClipTag` 和 `isInteractive`，文本、圆角和字体保持原 `TypeTagView` 视觉；
辅助功能名称为“名称，自动分类标签/用户标签，颜色名”。

- [ ] **步骤 3：实现标签条**

```swift
struct ClipTagStripView: View
{
    let clipID: UUID
    let tags: [ClipTag]
    let onActivate: () -> Void

    var body: some View
    {
        HStack(spacing: 6)
        {
            if tags.isEmpty
            {
                Button(action: onActivate)
                {
                    Image(systemName: "plus")
                        .frame(minWidth: 22, minHeight: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加标签")
                .accessibilityIdentifier("tagAdd_\(clipID.uuidString)")
            }
            else
            {
                ForEach(tags)
                { tag in
                    Button(action: onActivate)
                    {
                        TagPillView(tag: tag, isInteractive: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "clipTag_\(clipID.uuidString)_\(tag.id.rawValue)"
                    )
                }
            }
        }
    }
}
```

`TypeTagView` 变为兼容包装：

```swift
TagPillView(tag: SystemTagCatalog.tag(for: contentType), isInteractive: false)
```

删除 `TypeTagView` 私有颜色表，避免两套系统标签映射；兼容包装继续暴露既有
`typeTag_<contentType>` identifier，保证旧系统标签 XCUITest 不因内部复用而失效。

非空标签条外层使用 `ScrollView(.horizontal, showsIndicators: false)`，最多 5 个 pill 保持
单行可横向访问；单个 pill 文字 `lineLimit(1)`、最大视觉宽度 96pt、尾部截断，但完整名称、
来源和颜色仍保留在 accessibility label/value。不得让长名称扩大 row 命中区或挤掉主内容。

- [ ] **步骤 4：运行 GREEN**

运行 `SystemTagCatalogTests` 与 `ClipRowViewInteractionTests`。预期：全部 PASS。

## 任务 3：标签选择状态与菜单

**文件：**

- 创建：`ClipMind/UI/Tags/TagPickerView.swift`
- 扩充：`ClipMindTests/UI/TagPickerViewModelTests.swift`

- [ ] **步骤 1：编写 RED picker 状态测试**

覆盖：

- 候选 = 当前条目自身系统标签 + 全部用户标签；
- 其他 10 个系统标签不存在；
- 搜索大小写不敏感包含匹配，清空恢复；
- 无匹配且名称有效时显示创建入口；
- 5 个标签时未选项和创建入口禁用，已选项仍可取消；
- 创建成功后搜索清空并回浏览状态；
- 系统标签移除后仍在候选中且未勾选；
- error 状态显示安全文案，retry 调用 `TagStore.retry()`。

- [ ] **步骤 2：实现 `TagPickerViewModel`**

将可测试状态放在 `TagPickerView.swift`：

```swift
@MainActor
final class TagPickerViewModel: ObservableObject
{
    enum Mode: Equatable
    {
        case browse
        case create
    }

    @Published var searchText = ""
    @Published var proposedName = ""
    @Published var selectedColor = ClipTagColor.violet
    @Published var mode = Mode.browse

    let clipID: UUID
    let contentType: ContentType
    private let store: TagStore

    init(clipID: UUID, contentType: ContentType, store: TagStore)
    {
        self.clipID = clipID
        self.contentType = contentType
        self.store = store
    }
}
```

同类型实现并测试以下确定 API：

```swift
var candidateTags: [ClipTag]
var filteredTags: [ClipTag]
var selectedTagIDs: Set<ClipTagID>
var canCreate: Bool
var isAtLimit: Bool
func isSelected(_ tag: ClipTag) -> Bool
func isDisabled(_ tag: ClipTag) -> Bool
func toggle(_ tag: ClipTag)
func beginCreate()
func confirmCreate()
func cancelCreate()
func retry()
```

所有规则结果由 `TagService` 最终裁决；ViewModel 的禁用态只作及时表达，不复制重名/来源权限。

- [ ] **步骤 3：实现 `TagPickerView`**

布局固定为：

1. 标题“选择标签”；
2. 自动聚焦搜索框 `tagPickerSearch`；
3. `ScrollView` 内候选 button，每项包含 checkbox、颜色、名称和来源；
4. 无匹配时 `tagCreateEntry`；
5. 创建模式名称输入、11 色具名按钮、取消/创建；
6. 满额提示“每条条目最多 5 个标签”；
7. `TagStore.errorMessage` 安全错误 + `tagRetryButton`。

候选项使用：

```swift
.accessibilityIdentifier("tagOption_\(tag.id.rawValue)")
.accessibilityValue(viewModel.isSelected(tag) ? "已选择" : "未选择")
.disabled(viewModel.isDisabled(tag))
```

颜色按钮 identifier 为 `tagColor_<rawValue>`，label 同时包含中文颜色名。
禁止使用仅颜色或内部 layer 数量作为验证点。

- [ ] **步骤 4：运行 GREEN**

运行 `TagPickerViewModelTests`。预期：全部 PASS。

## 任务 4：在 `ClipRowView` 隔离标签事件

**文件：**

- 修改：`ClipMind/UI/MenuBar/ClipRowView.swift`
- 修改：`ClipMindTests/UI/ClipRowViewInteractionTests.swift`

- [ ] **步骤 1：编写 RED 回调隔离测试**

新增可注入 `onTagActivate`，直接触发时断言 `onSingleClick`、`onDoubleClick` 未调用；
主动作回调仍分别工作。

- [ ] **步骤 2：重组 Row 命中区域**

`ClipRowView` 新增：

```swift
let tagStore: TagStore
var onTagActivate: (() -> Void)?
@State private var isTagPickerPresented = false
```

标签条与内容主动作必须是兄弟区域：

```swift
ClipTagStripView(
    clipID: clip.id,
    tags: tagStore.tags(for: clip.id),
    onActivate:
    {
        onTagActivate?()
        isTagPickerPresented = true
    }
)
.popover(isPresented: $isTagPickerPresented, arrowEdge: .bottom)
{
    TagPickerView(clipID: clip.id, contentType: clip.contentType, store: tagStore)
}

VStack(alignment: .leading, spacing: 6)
{
    contentPreviewView
    metadataView
}
.contentShape(Rectangle())
.onTapGesture(count: 2) { onDoubleClick?() }
.onTapGesture(count: 1) { onSingleClick?() }
```

不得把 `.onTapGesture` 挂在同时包含 `ClipTagStripView` 的共同父容器。

- [ ] **步骤 3：运行 GREEN**

运行 `ClipRowViewInteractionTests`。预期：标签、单击、双击三类回调互不传播。

## 任务 5：三个入口装配同一标签状态

**文件：**

- 修改：`ClipMind/App/ClipMindApp.swift`
- 修改：`ClipMind/UI/MainWindow/MainWindow.swift`
- 修改：`ClipMind/UI/MainWindow/HistoryListView.swift`
- 修改：`ClipMind/UI/MainWindow/SearchResultsView.swift`
- 修改：`ClipMind/UI/MenuBar/UnifiedPastePanelView.swift`
- 修改：`ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift`
- 修改：`ClipMind/UI/MenuBar/StatusItemController.swift`
- 修改：`ClipMind/App/QuickPasteAssembly.swift`
- 修改：`ClipMind/App/PopoverPreviewWindowFactory.swift`
- 修改：`ClipMind/Utils/ClipTestData.swift`

- [ ] **步骤 1：创建唯一生产 `TagStore`**

复用 Phase 1 的唯一 `TagBackend`，不得在 UI 层再次创建 `EncryptedStore` 或 `TagService`。

`AppDelegate` 保存：

```swift
@MainActor
lazy var tagStore = TagStore(
    service: tagBackend.service,
    migrationCoordinator: tagBackend.migrationCoordinator
)
```

`ClipMindApp` 把 `appDelegate.tagStore` 显式传给 `MainWindow` 和 `SettingsView`；
StatusItem、QuickPaste、PopoverPreview 三个装配点也传同一实例。`setupServices()` 继续拥有
捕获用 `EncryptedStore` 连接；它与 `tagBackend` 指向同一默认数据库，SQLite 事务负责
跨连接串行。

初始化失败时仍显示原有 ClipItem 列表，但标签编辑显示安全错误并禁用；
不得用空 snapshot 宣称保存成功。

首个界面完成装配后，`ClipMindApp` 调用 `tagStore.resumeMigration()`。失败时
`failedOperation == .migration`。`MainWindow` 在不遮挡历史列表的 banner 中显示固定
安全错误、`tagMigrationRetryButton` 和关闭动作；重试调用同一 `retry()`，关闭只隐藏本次
提示而不篡改最近成功快照。成功批次通过 `.clipTagsDidUpdate` 渐进刷新，
不得等待全部迁移完成才发布 `mainWindowInteractive`。

- [ ] **步骤 2：适配三个结果容器**

所有 `ClipRowView` 调用点必须传同一个 `tagStore`。`UnifiedPastePanelViewModel.clips`
保持条目 identity；标签变化由观察的 `TagStore.snapshot` 刷新标签条，不修改高亮索引。

`ClipTestData` 增加稳定 UUID 和 `tagState`，确保同一夹具跨三个 UI-test 入口具有相同 ID、
系统标签和用户标签关系。

`TagStore` 监听 `ClipCaptureService.clipDidUpdateNotification` 与 `.clipTagsDidUpdate`；
收到任一通知都取消旧 load 并重新读取快照。这样新捕获、迁移和其他连接完成的标签事务
会进入共享 UI 状态。监听 token 在 `deinit` 移除，通知 payload 不携带内容或标签名。

- [ ] **步骤 3：编译与现有交互回归**

运行：

```text
ClipMindTests/ClipRowViewInteractionTests
ClipMindTests/UnifiedPastePanelViewModelTests
ClipMindTests/MainWindowLayoutTests
ClipMindTests/StatusItemControllerTests
ClipMindTests/QuickPastePanelControllerTests
```

预期：全部 PASS；现有单击、双击、回车、Esc、方向键和来源筛选不变。

- [ ] **步骤 4：提交共享 picker**

```bash
git add \
  ClipMind/UI/Tags \
  ClipMind/UI/MenuBar/TypeTagView.swift \
  ClipMind/UI/MenuBar/ClipRowView.swift \
  ClipMind/UI/MenuBar/UnifiedPastePanelView.swift \
  ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift \
  ClipMind/UI/MenuBar/StatusItemController.swift \
  ClipMind/UI/MainWindow \
  ClipMind/App/ClipMindApp.swift \
  ClipMind/App/QuickPasteAssembly.swift \
  ClipMind/App/PopoverPreviewWindowFactory.swift \
  ClipMind/Utils/ClipTestData.swift \
  ClipMindTests/UI
git commit -m "feat(tags): add shared tag picker"
```

## 任务 6：建立第一版高风险 UI Smoke

**文件：**

- 创建：`.github/workflows/tag-ui-smoke.yml`
- 创建：`ClipMind/App/TagUITestSupport.swift`
- 创建：`ClipMindUITests/TagEntryUITests.swift`
- 创建：`ClipMindUITests/TagPickerUITests.swift`
- 修改：`ClipMind/App/AppDelegate+UITestOverrides.swift`

- [ ] **步骤 1：先写当前 Phase 可通过的 UI 用例**

`TagEntryUITests` 先覆盖三个入口的 pill/“+”可点击、picker 出现、主窗口 row/detail 不误触；
`TagPickerUITests` 先覆盖搜索、多选、创建、5 个上限、系统标签移除/恢复和持久化重启。
菜单栏/快捷粘贴的“未触发粘贴”在当前 Phase 只记录为待 Phase 5 探针关闭的可观察缺口，
不得仅凭 panel 未关闭判定 UI-ENTRY-003/005 已完全通过。

`TagUITestSupport.swift` 从本 Phase 起只在 `#if CLIPMIND_DEV` 编译，提供
`--UITEST_TAG_FIXTURE`、`--UITEST_TAG_EMPTY_CLIP`、`--UITEST_TAG_LIMIT_FIXTURE` 的隔离数据库；
固定数据通过正式 `EncryptedStore`/`TagService` 写入。Phase 5 只扩充 migration fixture
和 paste probe，并组合 fail-once，不重新创建这套基本 fixture。

同文件同时提供
`--UITEST_TAG_FAIL_ONCE=create|attach|detach|rename|delete|migrate` 与
`FailOnceTagRepository`：它包装正式 repository，每种闭集 operation 仅第一次抛
`.persistenceFailed`，不读取或记录 associated value。这样 Phase 2 picker 与 Phase 4
Settings Smoke 都能在所属 Phase 验证失败回滚/retry；Phase 5 只组合这些能力形成跨入口证据。

- [ ] **步骤 2：创建远程 Smoke workflow**

workflow 支持无 paths 限制的 `feature/**` push、`workflow_dispatch` 和相关路径的
`pull_request`，在 `macos-15` 上安装
xcodegen/SwiftLint、生成工程，并使用 `ClipMind-Dev` / `DebugDev` 构建 UI test bundle。
CI 按 AGENTS.md 的基线策略显式传 `CODE_SIGN_IDENTITY="-"`、
`CODE_SIGNING_REQUIRED=NO`、`CODE_SIGNING_ALLOWED=NO`；只执行上述两个测试类，不设置现有
`CLIPMIND_SKIP_PANEL_UI_TESTS`。

run 必须绑定当前提交 `headSha`，失败不得 `continue-on-error`。如果 GitHub hosted runner
缺少 panel GUI 前提，则该 Gate 记录为 BLOCKED，并先补经批准的 macOS GUI runner；
当前仓库没有已登记的 self-hosted runner，不能虚构 label 或回退为静态 View 测试。

首版 workflow 至少包含可直接执行的主体；后续 Phase 只扩充 test selector：

```yaml
name: F1.14 Tag UI Smoke
on:
  push:
    branches:
      - "feature/**"
  workflow_dispatch:
  pull_request:
    paths:
      - "ClipMind/**"
      - "ClipMindUITests/**"
      - "project.yml"
      - ".github/workflows/tag-ui-smoke.yml"

permissions:
  contents: read

jobs:
  tag-ui-smoke:
    runs-on: macos-15
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - run: brew install swiftlint xcodegen xcbeautify
      - run: xcodegen generate
      - run: swiftlint lint --strict --reporter github-actions-logging
      - name: Print exact SHA
        run: test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
      - name: Run F1.14 UI smoke
        run: |
          set -o pipefail
          xcodebuild test \
            -project ClipMind.xcodeproj \
            -scheme ClipMind-Dev \
            -configuration DebugDev \
            -destination 'platform=macOS' \
            -derivedDataPath build/TagUISmoke \
            -resultBundlePath build/TagUISmoke.xcresult \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            -only-testing:ClipMindUITests/TagEntryUITests \
            -only-testing:ClipMindUITests/TagPickerUITests \
            | xcbeautify
      - name: Upload xcresult
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: tag-ui-smoke-${{ github.sha }}
          path: build/TagUISmoke.xcresult
          if-no-files-found: error
```

`push` 不设置 paths filter，确保 Phase 6 的 evidence-only exact integration commit 也产生同
SHA run。`workflow_dispatch` 只作为 workflow 已进入默认分支后的人工重跑入口；新建 workflow
在 feature 分支阶段不依赖它，符合 GitHub 对
[workflow_dispatch](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch)
必须存在于默认分支的约束。

- [ ] **步骤 3：提交 Smoke**

```bash
git add \
  .github/workflows/tag-ui-smoke.yml \
  ClipMind/App/TagUITestSupport.swift \
  ClipMind/App/AppDelegate+UITestOverrides.swift \
  ClipMindUITests/TagEntryUITests.swift \
  ClipMindUITests/TagPickerUITests.swift
git commit -m "test(tags): add initial tag UI smoke"
```

## Phase 2 Local Gate

- `TagPickerViewModelTests` 全部通过。
- 三个入口编译且只使用一个 `ClipTagStripView` / `TagPickerView`。
- 标签主动作不传播到条目选择、详情或粘贴回调。
- 11 色均有文字名称、焦点和 identifier。
- 持久化失败保持最近成功快照并可重试。
- SwiftLint strict 0 violation，无签名 build succeeded。
- `tag-ui-smoke.yml` 的三入口/Picker 当前能力通过；粘贴负向探针仅在 Phase 5 关闭。
- push 当前提交并等待 F1.14 UI Smoke；run 失败不得进入 Phase 3。

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-29 | 固定共享 TagStore、标签视觉、picker 状态、事件隔离和三入口装配。 |
