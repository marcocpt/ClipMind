# F1.13 来源过滤 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将主窗口来源过滤器从单选改为多选 Checkbox，让历史列表和搜索结果均受来源过滤影响；为弹窗新增来源筛选按钮和 App 多选浮层，使弹窗列表也受来源过滤影响；来源应用列表从数据动态提取，主窗口与弹窗过滤状态独立，过滤状态不持久化。

**架构：** 主窗口的 SourceFilter 组件从单选 Picker 改为多选 Checkbox，选中状态从 `String?` 改为 `Set<String>`。历史列表视图新增来源过滤参数，在视图层过滤剪贴项。搜索服务适配从单值到集合的来源过滤参数。弹窗新增来源筛选浮层组件（SourceFilterOverlay），由 UnifiedPastePanelViewModel 管理过滤状态。两处 Checkbox 联动逻辑独立实现（逻辑一致），来源应用列表提取逻辑集中在 SourceAppExtractor 工具方法中。

**技术栈：** Swift 5.7+ / macOS 13.0+ / SwiftUI / XCTest / XCUITest

---

## 规格文档路径

| 文档 | 路径 |
|------|------|
| 需求文档 | `docs/planning/P0/F1/F1.13_来源过滤_需求文档.md` |
| 设计文档 | `docs/planning/P0/F1/F1.13_来源过滤_设计文档.md` |
| 视觉原型 | `docs/planning/P0/F1/F1.13_来源过滤_视觉原型.html` |
| 测试用例表 | `docs/planning/P0/F1/F1.13_来源过滤_测试用例表.md` |
| 审查结果 | `docs/planning/P0/F1/F1.13_来源过滤_需求文档_审查结果.md` |

---

## Phase 列表

| Phase | 子计划文件 | 范围 | 涉及 AC |
|-------|-----------|------|---------|
| Phase 0 | [phase-0.md](./phase-0.md) | SourceFilter 多选改造 + 主窗口历史列表过滤 + 搜索结果适配 + 来源应用列表提取 + 空状态提示 + 状态独立 + 不持久化 | AC-F1.13-1 ~ AC-F1.13-3, AC-F1.13-6 ~ AC-F1.13-9 |
| Phase 1 | [phase-1.md](./phase-1.md) | 弹窗筛选按钮 + App 多选浮层 + 弹窗列表过滤 + 浮层点击外部关闭 + 弹窗空状态提示 | AC-F1.13-4, AC-F1.13-5, AC-F1.13-7(弹窗), AC-F1.13-10 |

---

## 涉及文件总览

### 新增文件

| 文件路径 | 职责 |
|---------|------|
| `ClipMind/Utils/SourceAppExtractor.swift` | 来源应用列表动态提取（去重、排序），供主窗口和弹窗共享 |
| `ClipMind/UI/MenuBar/SourceFilterOverlay.swift` | 弹窗来源筛选浮层组件，Checkbox 多选列表 |
| `ClipMindTests/SourceFilter/SourceAppExtractorTests.swift` | 来源应用列表提取单元测试 |
| `ClipMindTests/SourceFilter/SourceFilterViewModelTests.swift` | 来源过滤器多选逻辑（Checkbox 联动）单元测试 |
| `ClipMindTests/SourceFilter/SourceFilterStateIndependenceTests.swift` | 主窗口与弹窗过滤状态独立单元测试 |
| `ClipMindTests/SourceFilter/SearchServiceMultiSelectAdapterTests.swift` | 搜索服务集合过滤适配单元测试 |
| `ClipMindTests/UI/UnifiedPastePanelViewModelFilterTests.swift` | 统一粘贴面板视图状态管理器过滤逻辑单元测试 |

### 修改文件

| 文件路径 | 修改内容 |
|---------|---------|
| `ClipMind/UI/MainWindow/SourceFilter.swift` | 从单选 Picker 改为多选 Checkbox；选中状态从 `@Binding var selectedApp: String?` 改为 `@Binding var selectedSources: Set<String>`；新增「全部」选项与各应用 Checkbox 联动逻辑 |
| `ClipMind/UI/MainWindow/MainWindow.swift` | `selectedSourceApp: String?` 改为 `selectedSources: Set<String>`；传入来源应用列表改为动态提取；历史列表传递过滤参数；搜索结果适配集合过滤 |
| `ClipMind/UI/MainWindow/HistoryListView.swift` | 新增 `sourceFilter: Set<String>` 参数；根据过滤条件过滤剪贴项；过滤后无匹配结果显示空状态提示 |
| `ClipMind/UI/MainWindow/SearchResultsView.swift` | 新增空状态提示文案区分「搜索无结果」与「来源过滤无匹配」 |
| `ClipMind/Search/SearchService.swift` | `sourceApp: String?` 参数改为 `sourceApps: Set<String>?`；适配集合过滤 |
| `ClipMind/UI/MenuBar/UnifiedPastePanelView.swift` | 新增来源筛选按钮（漏斗图标）；点击弹出 SourceFilterOverlay；列表根据过滤条件过滤；空状态提示 |
| `ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift` | 新增 `selectedSources: Set<String>` 过滤状态；新增 `sourceApps: [String]` 来源应用列表；新增 `isFilterOverlayShown: Bool` 浮层状态；新增过滤后剪贴项列表计算 |
| `ClipMindTests/SearchTests/SourceFilterTests.swift` | 适配 `sourceApps: Set<String>?` 参数变更 |

---

## 全局验证命令

```bash
# Lint（含 Swift 改动时 commit 前强制 strict）
swiftlint lint --strict

# 编译检查
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

# 单元测试（Phase 0 / Phase 1 各自完成后执行）
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
  -only-testing:ClipMindTests

# 完整测试（CI，合并前执行）
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
```

---

## 最终验收方式

1. **Lint 通过**：`swiftlint lint --strict` 无错误
2. **编译通过**：xcodebuild build 成功
3. **单元测试全通过**：所有新增和修改的单元测试通过
4. **10 条 AC 验证**：
   - AC-F1.13-1 ~ AC-F1.13-3：主窗口多选 Checkbox、历史列表过滤、搜索结果过滤（Phase 0 单元测试 + 手动验证）
   - AC-F1.13-4 ~ AC-F1.13-5：弹窗筛选按钮、浮层、弹窗列表过滤（Phase 1 单元测试 + 手动验证）
   - AC-F1.13-6：来源应用列表动态提取（单元测试）
   - AC-F1.13-7：空状态提示（手动验证 + 单元测试）
   - AC-F1.13-8：主窗口与弹窗过滤状态独立（单元测试）
   - AC-F1.13-9：过滤状态不持久化（单元测试 + 手动验证）
   - AC-F1.13-10：浮层点击外部关闭（手动验证）
5. **代码审查通过**：无反向依赖、无敏感信息日志、无持久化过滤状态代码

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-27 | 初始版本，包含 Phase 0 和 Phase 1 两个子计划 |
