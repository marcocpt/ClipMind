# F1.14 用户自定义标签实现计划

> 最后更新：2026-07-29 | 版本：v1.0

> **面向 AI 代理的工作者：** 必需子技能：使用 `subagent-driven-development`（推荐）或
> `executing-plans` 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法跟踪进度。

**目标：** 在不改变剪贴板捕获和分类规则的前提下，为 `ClipItem` 增加加密、可迁移的统一标签状态，
并在主窗口、菜单栏弹窗、快捷粘贴面板和设置页提供一致的标签编辑、筛选和全局管理行为。

**架构：** 标签定义使用稳定 ID；11 个系统标签由 `SystemTagCatalog` 提供唯一名称与颜色映射，
用户标签目录作为一个 AES-256-GCM 加密 blob 持久化，条目关联与系统标签处置状态随
`ClipItem` 一起进入已有加密 `content_blob`。`TagService` 是创建、关联、上限、来源资格、
重命名、删除和迁移的唯一规则边界，`TagStore` 只把已持久化快照投影到 SwiftUI。
历史列表和搜索结果统一使用 `CompositeClipFilter` 解释搜索、来源和标签交集条件。

**技术栈：** Swift 5.7+、macOS 13+ 产品合同、SwiftUI、AppKit、Combine、CryptoKit、
SQLite.swift 0.15.0、XCTest、XCUITest、GitHub Actions。

---

## 1. 已批准规格

| 文档 | 确认版本 | 路径 |
|------|---------|------|
| Requirements | v1.2 | `docs/planning/P0/F1/F1.14_用户自定义标签_需求文档.md` |
| Design | v2.2 | `docs/planning/P0/F1/F1.14_用户自定义标签_设计文档.md` |
| Visual Prototype | v2.3 | `docs/planning/P0/F1/F1.14_用户自定义标签_视觉原型.html` |
| Test Matrix | v2.3 | `docs/planning/P0/F1/F1.14_用户自定义标签_测试用例表.md` |

四份规格及其独立审查记录已经关闭 Specification Gate。实现不得重新解释
F1.14-D01：系统标签只允许按条目移除/恢复，设置页全局只读。

## 2. Implementation 入口 Gate

Phase 1 前必须先完成 [Phase 0](./phase-0-implementation-entry-gates.md)：

1. 当前工作树必须仍为 `feature/F1.14-user-tags` 且无无关改动。
2. F1.13 来源筛选基线必须恢复编译，至少存在并可编译：
   - `ClipMind/Utils/SourceFilterSelection.swift`
   - `ClipMind/Utils/SourceAppExtractor.swift`
   - `ClipMind/UI/MenuBar/SourceFilterOverlay.swift`
3. 主窗口、菜单栏弹窗和快捷粘贴面板的来源筛选回归必须通过。
4. Phase 0 的入口验证 SHA 必须有成功的 `ci.yml` 结果。

截至本计划编写时，第 2～4 项未满足；因此 Planning 可以完成，但 Implementation 必须停在
Phase 0，不得把 F1.13 修复混入 F1.14 提交。

当前 `ClipMind/Resources/ClipMind.entitlements` 的 App Sandbox 为 `false`，且
`.github/workflows/ci.yml` 仅验证 arm64。两项不阻止计划编写，但必须在 Phase 6 关闭，
否则 AC-F1.14-23 和 Final Candidate Gate 不通过。

## 3. 文件结构与职责

### 3.1 新增生产文件

| 文件 | 单一职责 |
|------|---------|
| `ClipMind/Models/ClipTag.swift` | 标签 ID、来源、颜色、标签值类型 |
| `ClipMind/Models/ClipTagState.swift` | 条目关联顺序、系统标签处置和迁移版本 |
| `ClipMind/Models/SystemTagCatalog.swift` | 11 个 `ContentType` 到系统标签名称/颜色的唯一映射 |
| `ClipMind/Tags/TagError.swift` | 不含敏感输入的业务错误与错误码 |
| `ClipMind/Tags/TagNameValidator.swift` | 名称 trim、全局唯一和重命名排除自身的单一规则 |
| `ClipMind/Tags/TagSnapshot.swift` | 标签目录、条目关联与查询投影 |
| `ClipMind/Tags/TagRepository.swift` | 加密存储端口和原子 mutation 值类型 |
| `ClipMind/Tags/TagService.swift` | 名称、上限、来源资格和权限的唯一裁决边界 |
| `ClipMind/Tags/TagOperationLogger.swift` | 仅记录操作、结果、错误码和数量 |
| `ClipMind/Tags/TagMigrationCoordinator.swift` | 分批、幂等、可恢复的旧条目迁移 |
| `ClipMind/App/TagBackendAssembly.swift` | 生产 `TagService` 与迁移协调器的唯一装配根 |
| `ClipMind/Storage/EncryptedStore+Tags.swift` | 加密目录 blob 与条目关联原子事务 |
| `ClipMind/UI/Tags/TagStore.swift` | `@MainActor` 标签 UI 状态和回滚快照 |
| `ClipMind/UI/Tags/TagPillView.swift` | 标签名称、颜色、来源与辅助功能语义 |
| `ClipMind/UI/Tags/ClipTagStripView.swift` | 有标签显示标签，无标签显示“+” |
| `ClipMind/UI/Tags/TagPickerView.swift` | 搜索、多选、创建、上限和失败重试 |
| `ClipMind/UI/Tags/TagFilterView.swift` | 全部系统/用户标签的多选交集入口 |
| `ClipMind/UI/MainWindow/CompositeClipFilter.swift` | 搜索、来源、标签条件的统一 AND 解释 |
| `ClipMind/UI/Settings/TagManagementView.swift` | 用户标签两阶段重命名/删除确认和系统只读列表 |
| `ClipMind/App/TagUITestSupport.swift` | `CLIPMIND_DEV` UI-test 夹具、失败注入和粘贴负向探针 |
| `ClipMind/Resources/container-migration.plist` | 首次 Sandbox 启动的旧 Application Support 迁移清单 |

### 3.2 修改生产与配置文件

| 文件 | 修改职责 |
|------|---------|
| `ClipMind/Models/ClipItem.swift` | 向后兼容解码 `tagState`，新条目默认关联自身系统标签 |
| `ClipMind/Storage/EncryptedStore.swift` | 向跨文件 extension 开放最小内部事务/编解码能力 |
| `ClipMind/UI/MainWindow/EditableContentArea.swift` | 内容编辑重建值时显式保留当前 `tagState` |
| `ClipMind/Capture/ClipCaptureService.swift` | 保持“分类后、完整保存成功后再通知”的发布单元 |
| `ClipMind/UI/ClipStore.swift` | 标签 mutation/迁移通知后刷新条目 |
| `ClipMind/UI/MenuBar/TypeTagView.swift` | 兼容包装统一 `TagPillView`，删除重复颜色映射 |
| `ClipMind/UI/MenuBar/ClipRowView.swift` | 标签触发与条目单击/双击事件隔离 |
| `ClipMind/UI/MenuBar/UnifiedPastePanelView.swift` | 注入 `TagStore` 并显示共享标签条 |
| `ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift` | 过滤后索引与标签快照更新 |
| `ClipMind/UI/MenuBar/StatusItemController.swift` | 菜单栏弹窗装配共享 `TagStore` |
| `ClipMind/App/QuickPasteAssembly.swift` | 快捷粘贴面板装配共享 `TagStore` |
| `ClipMind/App/StatusItemAssembly.swift` | Dev probe 模式下装配受控真实粘贴 positive control |
| `ClipMind/App/PopoverPreviewWindowFactory.swift` | UI-test 弹窗装配标签夹具和粘贴探针 |
| `ClipMind/App/ClipMindApp.swift` | 启动可恢复迁移并向主窗口/设置页注入 `TagStore` |
| `ClipMind/App/SettingsWindowAssembly.swift` | AppKit 设置窗口装配同一 `TagStore` |
| `ClipMind/App/AppDelegate+UITestOverrides.swift` | 解析命名化的 F1.14 UI-test 参数 |
| `ClipMind/UI/MainWindow/MainWindow.swift` | 单一完整筛选意图与标签筛选状态 |
| `ClipMind/UI/MainWindow/HistoryListView.swift` | 消费已过滤结果并区分两类空状态 |
| `ClipMind/UI/MainWindow/SearchResultsView.swift` | 使用统一筛选空状态语义 |
| `ClipMind/UI/Settings/SettingsView.swift` | 新增“标签”Tab 和 UI-test 初始 Tab |
| `ClipMind/Utils/ClipTestData.swift` | 稳定标签夹具与跨入口相同 ID |
| `project.yml` | 增加仅测试用、Release 优化的 `ReleaseDev` 配置 |
| `ClipMind.xcodeproj/project.pbxproj` | 由 xcodegen 同步 ReleaseDev、macOS 13 和资源配置 |
| `.github/workflows/ci.yml` | arm64/x86_64 完整验证 |
| `.github/workflows/tag-ui-smoke.yml` | 按阶段增长的 F1.14 高风险 UI Smoke |
| `ClipMind/Resources/ClipMind.entitlements` | 主发布 target 启用 App Sandbox |

### 3.3 新增测试文件

| 测试文件 | Test Matrix 覆盖 |
|---------|------------------|
| `ClipMindTests/Tags/SystemTagCatalogTests.swift` | DOM-001、DOM-002 |
| `ClipMindTests/Tags/TagServiceTests.swift` | DOM-002～005 |
| `ClipMindTests/Tags/TagAssociationTests.swift` | DOM-006～010 |
| `ClipMindTests/Tags/NewClipTagIntegrationTests.swift` | DOM-011 |
| `ClipMindTests/Storage/EncryptedTagStoreTests.swift` | DOM-005～009、SEC-001 |
| `ClipMindTests/Storage/EncryptedStoreUpdateTests.swift` | 非标签更新不覆盖最新标签状态 |
| `ClipMindTests/UI/EditableContentAreaTests.swift` | 内容编辑产物保留当前 `tagState` |
| `ClipMindTests/Storage/TagMigrationTests.swift` | MIG-001～003 |
| `ClipMindTests/Tags/TagLogSanitizationTests.swift` | SEC-002 |
| `ClipMindTests/UI/TagPickerViewModelTests.swift` | UI-MENU-001～011 的业务状态 |
| `ClipMindTests/UI/CompositeClipFilterTests.swift` | FLT-001、FLT-005、REG-002 |
| `ClipMindTests/Performance/TagPerformanceTests.swift` | PERF-001、PERF-003 |
| `ClipMindTests/Performance/TagStabilityTests.swift` | STAB-001 |
| `ClipMindUITests/TagEntryUITests.swift` | UI-ENTRY-001～006 |
| `ClipMindUITests/TagPickerUITests.swift` | UI-MENU-001～011 |
| `ClipMindUITests/TagFilterUITests.swift` | FLT-002～006 |
| `ClipMindUITests/TagSettingsUITests.swift` | SET-001～006 |
| `ClipMindUITests/TagMigrationUITests.swift` | MIG-004～005 |
| `ClipMindUITests/TagAccessibilityUITests.swift` | A11Y-001 |
| `ClipMindUITests/TagPerformanceUITests.swift` | PERF-002、PERF-004 |
| `ClipMindTests/App/ContainerMigrationManifestTests.swift` | 旧数据库目录迁移清单与 bundle 资源 |
| `ClipMindUITests/SandboxUpgradeUITests.swift` | 真实 Sandbox 首启保留并迁移旧数据 |

## 4. Phase 列表

| Phase | 子计划 | 交付结果 | 主要 AC |
|------|-------|---------|--------|
| 0 | [Implementation 入口 Gate](./phase-0-implementation-entry-gates.md) | F1.13 基线与 CI 前置证据 | AC-10、23、24 前置 |
| 1 | [领域、加密持久化与迁移](./phase-1-domain-storage-migration.md) | 统一标签模型、原子 mutation、旧数据迁移、新条目完整发布 | AC-5～9、15～19 |
| 2 | [共享标签条与标签选择菜单](./phase-2-shared-tag-picker.md) | 三入口共享标签显示、搜索、多选、创建、回滚 | AC-1～9、16、17、22 |
| 3 | [主窗口组合筛选](./phase-3-composite-filter.md) | 搜索 + 来源 + 多标签交集和双空状态 | AC-10、11、14、24 |
| 4 | [设置页全局管理](./phase-4-settings-management.md) | 系统只读、用户标签确认式重命名/删除 | AC-12～14、16、17、24 |
| 5 | [跨入口 UI 证据与稳定性](./phase-5-ui-evidence-hardening.md) | 确定性负向探针、失败注入、性能、稳定性、辅助功能证据 | AC-1～22、24 |
| 6 | [发布合规与最终集成](./phase-6-release-integration.md) | Sandbox、双架构、完整 CI、回归和回滚证据 | AC-20～24 |

Phase 必须按顺序执行。每个 Phase 的最后一个提交是可独立回滚的边界；未通过 Local Gate
不得进入下一 Phase。

## 5. 验证与执行位置

### 5.1 TDD 快速反馈

每个任务只运行当前测试类，使用 AGENTS.md 规定的无签名基线参数：

```bash
test_class="${TEST_CLASS:?Set TEST_CLASS, for example SystemTagCatalogTests}"
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:"ClipMindTests/$test_class"
```

如果当前项目规则或 CI 状态要求 CI 优先，则将相同 `-only-testing` 选择器放入
`ci.yml` 的 workflow dispatch 输入，绑定当前提交 SHA；不得用本地结果替代远程 Gate。

### 5.2 Phase Local Gate

```bash
xcodegen generate
swiftlint lint --strict
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

`project.yml` 未修改时仍运行 `xcodegen generate`，确认新增文件已被 target 自动纳入。

### 5.3 高风险 UI Smoke 与集成 CI

- Phase 2 创建 F1.14 UI Smoke；Phase 3、4、5 随生产能力同步扩充。每个高风险 UI Phase
  提交后 push，并等待当前 SHA 的 F1.14 UI Smoke，不把测试债集中推迟到 Phase 5。
- Phase 6 对 integration SHA 执行 `ci.yml` 全量 arm64/x86_64 build/test、SwiftLint 和
  entitlement/API 静态审查；进入 Final Candidate Stage 后，基于最新 `develop` 形成新的
  exact candidate SHA，并重复同一组 Gate。
- 任何 run 失败都回到对应 TDD Task；本地通过不能替代远程失败。

### 5.4 用户可见证据

真实 App 证据使用 `ClipMind-Dev` / `DebugDev` 和项目自动签名，不传任何 `CODE_SIGN_*`：

```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev
```

截图、Accessibility Inspector 记录、Instruments `.trace` 和对应 SHA 放在：

```text
docs/planning/P0/F1/evidence/F1.14/<sha>/
```

## 6. 提交与回滚边界

| 边界 | Conventional Commit | 回滚影响 |
|------|---------------------|---------|
| Phase 1A | `feat(tags): persist encrypted tag state` | 回滚模型、规则、加密目录和关联事务 |
| Phase 1B | `feat(tags): migrate system tag links` | 回滚迁移接入，保留旧 `ClipItem` 可解码 |
| Phase 2 | `feat(tags): add shared tag picker` | 回滚三个入口标签交互 |
| Phase 3 | `feat(tags): add composite tag filtering` | 回滚标签条件，保留来源筛选 |
| Phase 4 | `feat(tags): add settings tag management` | 回滚全局管理 UI |
| Phase 5 | `test(tags): add observable tag coverage` | 仅测试夹具和证据探针 |
| Phase 6 | `chore(tags): enforce release compliance` | 回滚 CI/entitlement 前必须确认发布策略 |
| Planning | `docs(F1.14): add implementation plan` | 仅计划与 history |

生产提交不得包含实现中间失败状态。RED 测试证据保存在 CI run 或任务记录中，GREEN 后与最小实现
一起提交。任何数据 schema 回滚都必须先证明旧版本仍可解码带 `tagState` 的 `content_blob`。

## 7. AC 到 Phase / Test / Evidence 映射

| AC | Phase | 自动化 / 证据 |
|----|-------|---------------|
| 1 | 2、5 | `TagEntryUITests` 三入口已标记条目 + 粘贴负向探针 |
| 2 | 2、5 | `TagEntryUITests` 三入口“+” + 全未选 + 事件隔离 |
| 3 | 2 | `TagPickerUITests` 搜索与清空 |
| 4 | 2 | `TagPickerUITests` 无匹配创建入口 |
| 5 | 1、2 | DOM-005 + 创建成功 XCUITest |
| 6 | 1、2 | DOM-006 + 勾选/取消/重启 |
| 7 | 2 | 无确认 dialog 的 XCUITest |
| 8 | 1、2 | DOM-004/005 + 第六标签/孤立标签负向 UI |
| 9 | 1、2 | DOM-002/007、MIG-003 + 移除/重启/恢复 UI |
| 10 | 3 | FLT-001～004 + 主窗口结果/空状态截图 |
| 11 | 3 | FLT-005 精确 resultId 交集 |
| 12 | 1、4 | DOM-009 + SET-001/006 |
| 13 | 1、4 | DOM-003/008 + SET-002～004/006 |
| 14 | 1、3、4 | DOM-002 + SET-005 + FLT-006 |
| 15 | 1、5 | DOM-001 + MIG-001～004 + 兼容截图 |
| 16 | 1、2、4 | DOM-003 + UI-MENU-010 + SET-003 |
| 17 | 1、2、4、5 | DOM-005/011、MIG-002/005、失败回滚 UI |
| 18 | 1 | SEC-001 原始数据库字节与解密回读 |
| 19 | 1、5 | SEC-002 哨兵日志全文扫描 |
| 20 | 5、6 | PERF-001～004 的 20 次 nearest-rank p95 |
| 21 | 5 | STAB-001 自动快照 + STAB-002 Instruments `.trace` |
| 22 | 2、4、5 | A11Y-001 XCUITest + A11Y-002 Inspector 记录 |
| 23 | 6 | arm64/x86_64 CI、Sandbox entitlement、API/依赖差异 |
| 24 | 3、4、5 | DOM-010、FLT-002、SET-004、REG-002 |

24 条 AC 均有 Phase、自动化或人工证据承载；没有 `DEFERRED`。

## 8. 最终 Planning Gate

- 所有子计划均无未决实现占位符或未定义符号；`<sha>`、`<clipID>` 等只表示运行时命名值，
  命令中的 test/run ID 均由已定义 shell 变量解析。
- 每个生产行为先有 RED 测试，再有最小 GREEN 实现和回归。
- 三个入口只通过共享标签条消费标签事件。
- 标签敏感数据和关联不进入明文列或日志。
- UI 断言读取真实控件、resultId、接收文本、粘贴计数和窗口状态。
- Phase 0 未通过时，执行者必须停止，不得进入 Phase 1。
- Phase 6 未通过时，执行者必须停止，不得创建 Final Candidate。

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-29 | 基于四份已确认规格创建 7-Phase 总计划，固定文件职责、TDD、UI 证据、AC 映射、提交与回滚边界。 |
