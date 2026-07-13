> 最后更新：2026-07-14 | 版本：v1.2

# F1.8 内置示例数据 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 首启引导完成后自动注入 13 条覆盖 11 种 ContentType 的示例剪贴内容（带实时计算的 embeddings），并在设置面板提供一键清除功能，真实复制内容不受影响。

**架构：** 在 `ClipItem` 上新增 `isSample: Bool` 字段并实现 Codable 向后兼容；`EncryptedStore` 增加 `is_sample` 列与幂等迁移；新增 `SampleDataSeeder` 负责生成示例、实时计算 embeddings、注入存储并通知 UI 刷新；`OnboardingView.completeOnboarding()` 异步触发注入，`GeneralSettingsView` 提供清除按钮。

**技术栈：** Swift 5.7 / macOS 13+ / SwiftUI / SQLite.swift 0.15.0（SPM） / NaturalLanguage.NLEmbedding / XCTest + XCUITest

---

## 设计规范与评审

| 文档 | 路径 | 版本 |
|------|------|------|
| 设计规范 | `docs/planning/P0/F1/F1.8_内置示例数据_设计规范.md` | v1.2 |
| 测试用例表 | `docs/planning/P0/F1/F1.8_内置示例数据_测试用例表.md` | v1.2 |
| 设计评审摘要 | `docs/planning/P0/F1/F1.8_内置示例数据_设计评审摘要.md` | v1.0 |

评审结论：3 轮审核全部通过，UI 可观测性 3/3 通过，所有必须修复项已修复。剩余可选优化（不阻塞）：测试用例表 TC-F18-028 归类、AC1 条数统一（≥10 vs 13）、注入失败重试 / 清除后不重新注入等边界场景用例补充。

---

## Phase 列表

本特性为单 Phase 设计，规模较小，整体在 1 个 Phase 内完成。

| Phase | 标题 | 目标 | 任务数 | 预计耗时 |
|-------|------|------|--------|---------|
| Phase 1 | 内置示例数据 | 完成注入、清除、迁移、UI 集成、单元 + UI 测试 | 9 | 3-4 小时 |

详见 [phase-1-内置示例数据.md](./phase-1-内置示例数据.md)。

---

## 涉及文件总览

### 修改文件（7 个）

| 文件 | 职责变更 |
|------|---------|
| `ClipMind/Models/ClipItem.swift` | 新增 `isSample: Bool` 字段；自定义 `init(from:)` 实现向后兼容；工厂方法新增 `isSample` 默认参数 |
| `ClipMind/Storage/EncryptedStore.swift` | 新增 `isSampleColumn`、`migrateSchemaIfNeeded()`、`countSamples()`、`deleteSamples()`；`createTables()` 加列；`save()` 写入 `is_sample` |
| `ClipMind/Utils/ClipTestData.swift` | 新增 `sampleClipsForSeeding`（13 条）和 `makeSample` 私有辅助方法 |
| `ClipMind/UI/Onboarding/OnboardingView.swift` | `completeOnboarding()` 中异步调用 `SampleDataSeeder.seedIfNeeded` |
| `ClipMind/UI/Settings/GeneralSettingsView.swift` | 新增 `sampleDataSection` + `clearSampleData` + `confirmationDialog` |
| `ClipMind/UI/MainWindow/HistoryListView.swift` | 新增 `historyList` 和 `historyEmptyState` accessibilityIdentifier |
| `ClipMind/App/ClipMindApp.swift` | 新增 `--UITEST_PREPOPULATE_SAMPLE_AND_REAL` 启动参数处理 + `prepopulateTestData(store:)` 方法（UI 测试预置数据） |

### 新增文件（1 个）

| 文件 | 职责 |
|------|------|
| `ClipMind/SampleData/SampleDataSeeder.swift` | 注入示例数据的核心逻辑（幂等检查、embeddings 计算、通知发送） |

### 新增测试文件（6 个）

| 文件 | 覆盖 |
|------|------|
| `ClipMindTests/Models/ClipItemDecodingTests.swift` | TC-F18-017/018/019/020，Codable 向后兼容 |
| `ClipMindTests/Storage/EncryptedStoreSampleTests.swift` | TC-F18-011/012/013/014/015/016/028，存储层扩展 |
| `ClipMindTests/Storage/EncryptedStoreMigrationTests.swift` | TC-F18-034/035/036/037/038，旧库迁移 |
| `ClipMindTests/SampleData/SampleDataSeederTests.swift` | TC-F18-001~010/021/039，注入器核心逻辑 |
| `ClipMindTests/SampleData/SampleDataSearchTests.swift` | TC-F18-029/030/031/032，语义搜索命中 |
| `ClipMindUITests/SampleDataUITests.swift` | TC-F18-022/023/024/025/026/027/033/040，UI 端到端 |

> **注意**：所有新增文件需要添加到 `project.yml` 对应 target 的 `sources` 路径下后执行 `xcodegen generate` 才能进入工程。新增 `ClipMind/SampleData/` 目录需要在 `ClipMind` target 的 `sources: - path: ClipMind`（已存在，子目录自动包含）下；新增测试文件分别在 `ClipMindTests` 和 `ClipMindUITests` 的对应子目录下。

---

## 全局验证命令

以下命令在 Phase 完成时统一执行，参考 `AGENTS.md` 第 7 节。

### 1. SwiftLint（含 Swift 改动时 commit 前强制 strict）

```bash
swiftlint lint --strict
```

预期：`Done linting! Found 0 violations, 0 serious violations in X files.`

### 2. 重新生成 Xcode 工程（修改 project.yml 或新增文件后需要）

```bash
xcodegen generate
```

预期：`Successfully generated project at /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.8-sample-data/ClipMind.xcodeproj`（生成器可执行无报错；新增文件被自动纳入对应 target）。

### 3. 完整测试（CI 与本地基线测试复用同一命令）

```bash
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

预期：`** TEST SUCCEEDED **`，所有 F1.8 相关测试用例（TC-F18-001~008、011~040 共 38 条，TC-F18-009/010 延后覆盖）全部通过。

### 4. 快速编译检查（仅编译不跑测试，用于中间验证）

```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

预期：`** BUILD SUCCEEDED **`

---

## 最终验收方式

### 验收检查清单

按以下顺序验收，全部通过才算 F1.8 完成。

1. **SwiftLint 通过**：执行 `swiftlint lint --strict`，0 violation。
2. **单元测试通过**：执行全局测试命令，38 条 F1.8 测试用例全部 PASS（TC-F18-009/010 延后覆盖），覆盖 7 条 AC。
3. **手动验证首启注入**：
   - 删除 `~/Library/Application Support/ClipMind/clipmind.db` 和 `hasCompletedOnboarding` UserDefaults
   - 启动 App 完成引导
   - 主窗口显示 ≥ 10 条示例，每条带类型标签
   - 搜索框输入"报错"命中 error 类型示例
   - 设置 → 通用 → 点击"清除示例数据" → 确认 → 示例消失
4. **手动验证旧库迁移**（可选）：用旧版本（无 is_sample 列）的 clipmind.db 启动新 App，断言数据不丢失、isSample 字段为 false（可通过日志或调试断点确认）。
5. **文档同步**：按 `.trae/rules/docs.md` 同步实现计划、实施草案（如有）和 history 日志。

### 完成标志

- 首启引导完成后主窗口显示 ≥ 10 条示例，覆盖 11 种 ContentType
- 语义搜索"报错/代码/链接"命中对应类型示例
- 设置面板可清除示例数据，真实数据保留
- 二次启动不重复注入
- 旧数据库迁移后 is_sample 列存在，旧数据不丢失
- CI 全部测试通过 + SwiftLint 通过

---

## 关键技术约束（执行时必须遵守）

| # | 约束 | 说明 |
|---|------|------|
| 1 | ClipItem.isSample 的 Codable 兼容 | 使用 `decodeIfPresent(Bool.self, forKey: .isSample) ?? false`，确保旧 JSON 解码不抛 keyNotFound |
| 2 | EncryptedStore 迁移 | `PRAGMA table_info(clips)` 检查列存在性，`ALTER TABLE clips ADD COLUMN is_sample INTEGER DEFAULT 0` |
| 3 | embeddings 类型转换 | `LocalEmbeddingService.embed()` 返回 `[Double]?`，需 `.map { Float($0) }` 转为 `[Float]` |
| 4 | 注入异步执行 | `DispatchQueue.global(qos: .userInitiated).async`，不阻塞 UI 切换 |
| 5 | 幂等检查 | `countSamples() > 0` 则跳过注入并记录 info 日志 |
| 6 | 清除后刷新 | `deleteSamples()` 后发送 `clipDidUpdateNotification`，ClipStore 监听后自动 `loadClips` |
| 7 | UI 测试预置数据 | 通过 `EncryptedStore` 直接写入预置数据，**禁止使用** `--UITEST_PREVIEW_DATA`（会让 MainWindow 使用 `ClipTestData.previewClips` 绕过注入逻辑，导致假通过） |
| 8 | 单条 embeddings 失败不阻塞 | warning 日志，该条目仍入库（搜索时 EncryptedStore.search 自动过滤无 embeddings 的条目） |
| 9 | 全部注入完成后统一发一次通知 | 不是每条 save 后都发，避免 ClipStore 多次 loadClips 抖动 |
| 10 | SwiftLint strict | 含 Swift 改动的 commit 前必须通过 |

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-14 | 初始版本，基于设计规范 v1.2 和测试用例表 v1.1 编写，单 Phase 9 任务，覆盖 7 条 AC 和 40 条测试用例 |
| v1.1 | 2026-07-14 | check-plan 第 1 轮修复：修改文件清单补充 ClipMindApp.swift；补充 TC-F18-021/023/033/040 测试方法；修复 alert 按钮定位 |
| v1.2 | 2026-07-14 | check-plan 第 2 轮修复：同步测试方法计数（12→13、4→5）；更新测试用例表版本至 v1.2；同步 TC-F18-023/040 测试方法路径 |
