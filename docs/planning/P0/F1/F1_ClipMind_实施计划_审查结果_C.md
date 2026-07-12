# F1 实施计划审查结果 C（可验证性 + AC/TC 覆盖完整性）

> 审查时间：2026-07-12
> 审查维度：可验证性 + AC/TC 覆盖完整性
> 待审查文档：`F1_ClipMind_实施计划.md` v1.0
> 参考文件：设计规范 v1.3、测试用例表 v1.1、规则摘要、需求摘要

---

## 1. 审查状态

**总体状态：⚠️ 发现问题**

- 必须修复的问题：**1 个**（TC-01-01 XCUITest 代码无明确编写任务归属）
- 建议：**2 个**（T0.3 手动验证步骤缺失、测试目录命名不一致）
- AC 覆盖：25/25 全覆盖，MVP 路径 23/25
- TC 覆盖：69/69 全覆盖，MVP 路径 61/69
- 验证命令：35 个任务的 xcodebuild 命令格式正确，scheme/target/destination 一致

---

## 2. 可验证性检查

### 2.1 任务验证方式明确性

**结论：✅ 基本通过（1 个建议）**

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 35 个任务均有验证方式字段 | ✅ | 每个任务表均包含「验证方式」字段 |
| XCTest 任务的验证命令完整 | ✅ | 均包含 `-only-testing` 指定测试类 |
| XCUITest 任务的验证命令完整 | ✅ | T0.7/T0.8/T1.8/T1.9/T2.5/T2.6/T3.5/T3.7 均包含 UI 测试命令 |
| 手动验证步骤明确性 | ⚠️ | T0.3 的 TC-18-02/TC-18-03 为手动用例，但验证方式仅列 xcodebuild 命令，未含手动验证步骤说明（详见建议 S-02） |
| SwiftLint 验证 | ✅ | T0.1 验证方式含 `swiftlint lint --strict`；pre-commit hook 含 SwiftLint 检查 |
| curl 验证 | ✅ | T4.2 验证方式含 `curl -I` 检查 Web 页面可访问性 |

### 2.2 验证命令正确性

**结论：✅ 通过**

| 检查项 | 结果 | 说明 |
|--------|------|------|
| `-project ClipMind.xcodeproj` | ✅ | 全部命令一致，与 T0.1 产出匹配 |
| `-scheme ClipMind` | ✅ | scheme 名称与 T0.1 初始化项目一致 |
| `-destination 'platform=macOS'` | ✅ | macOS 原生 App 正确 destination |
| `-only-testing:ClipMindTests/类名` | ✅ | XCTest 目标名 `ClipMindTests`，类名与 8.3.2 测试文件表对应 |
| `-only-testing:ClipMindUITests/类名` | ✅ | XCUITest 目标名 `ClipMindUITests`，类名与 8.3.2 测试文件表对应 |
| 测试类引用与输出文件一致 | ✅ | 35 个任务的验证命令引用的测试类均能在 8.3.2 找到对应产出文件 |
| `swiftlint lint --strict` | ✅ | T0.1 含此命令，pre-commit hook 也含此检查 |

### 2.3 Phase 完成标志可验证性

**结论：⚠️ 存在风险（与必须修复问题 M-01 相关）**

| Phase | 完成标志 | 可验证性 | 说明 |
|-------|---------|---------|------|
| Phase 0 | .app 能启动，复制文本后 popover 显示，数据库加密存储可读写 | ⚠️ | "复制文本后 popover 显示"对应 TC-01-01（XCUITest），但 TC-01-01 的测试代码无明确任务归属（详见 M-01）；可通过 TC-01-03（手动验证）部分覆盖 |
| Phase 1 | 11 种入库类型分类准确率 ≥ 80%，搜索响应 < 500ms | ✅ | TC-05-01（准确率）+ TC-09-01（响应时间）均映射到 T1.4/T1.5 |
| Phase 2 | 4 种处理在配置 API Key 后可用，未配置时置灰 | ✅ | TC-13~17 覆盖完整 |
| Phase 3 | 敏感内容自动识别，黑名单生效，30 天自动清理 | ✅ | TC-08/20/21 覆盖完整 |
| Phase 4 | Web 页面可访问，Demo 帖发布，截图 + Session ID 齐全 | ✅ | TC-25-01（curl）+ TC-25-02/03 覆盖 |

### 2.4 MVP 降级处理

**结论：✅ 通过**

| 检查项 | 结果 | 说明 |
|--------|------|------|
| MVP 任务清单明确 | ✅ | 6.1 节列出 31 个 MVP 必做任务 |
| MVP 跳过任务清单明确 | ✅ | 6.2 节列出 4 个跳过任务（T3.3/T3.5/T3.6/T3.7） |
| MVP 跳过 AC 清单明确 | ✅ | 6.3 节列出 2 条跳过 AC（AC-21/AC-24），含跳过影响与补偿措施 |
| MVP 跳过 TC 清单明确 | ✅ | 6.4 节列出 8 个跳过 TC（TC-21-01~04/TC-22-03/TC-24-01~03） |
| MVP 工时汇总 | ✅ | 6.5 节：完整 105.5h → MVP 92h，节省 13.5h |
| MVP 路径 AC 覆盖率 | ✅ | 23/25 AC 覆盖（92%），跳过的 AC-21/AC-24 非核心 Demo 功能 |
| MVP 路径 TC 覆盖率 | ✅ | 61/69 TC 覆盖（88%），跳过的 8 个 TC 均依赖跳过的任务 |

---

## 3. AC 覆盖矩阵（25 条 AC 逐条检查）

| AC 编号 | AC 描述 | 覆盖任务 | 测试用例 | 验证框架 | MVP 覆盖 | 审查结论 |
|---------|---------|---------|---------|---------|---------|---------|
| AC-01 | 复制文本后 3 秒内出现在 popover 与主窗口历史 | T0.2, T0.4, T0.6, T0.8 | TC-01-01, TC-01-02, TC-01-03 | XCUITest + 手动 | ✅ 是 | ⚠️ TC-01-01 映射问题（见 M-01） |
| AC-02 | 复制图片被捕获为缩略图 | T0.4, T0.8 | TC-02-01, TC-02-02 | XCTest + 手动 | ✅ 是 | ✅ 通过 |
| AC-03 | 复制文件路径被捕获 | T0.4, T0.8 | TC-03-01, TC-03-02 | XCTest + 手动 | ✅ 是 | ✅ 通过 |
| AC-04 | 连续复制相同内容不重复入库 | T0.4 | TC-04-01 | XCTest | ✅ 是 | ✅ 通过 |
| AC-05 | 11 种入库类型自动分类准确率 ≥ 80% | T1.1, T1.2, T1.3, T1.5 | TC-05-01 | XCTest | ✅ 是 | ✅ 通过 |
| AC-06 | 代码片段被识别为 code 类型 | T1.2, T1.3, T1.8 | TC-06-01, TC-06-02 | XCTest | ✅ 是 | ✅ 通过 |
| AC-07 | 报错日志被识别为 error 类型 | T1.2, T1.3 | TC-07-01, TC-07-02 | XCTest | ✅ 是 | ✅ 通过 |
| AC-08 | 密码 Token 被识别为敏感内容且不入库 | T1.6, T3.1 | TC-08-01~07 | XCTest + 手动 | ✅ 是 | ✅ 通过 |
| AC-09 | 自然语言搜索返回结果 < 500ms | T1.4, T1.9 | TC-09-01 | XCTest | ✅ 是 | ✅ 通过 |
| AC-10 | Top-5 命中率 ≥ 70% | T1.4, T1.7 | TC-10-01 | XCTest | ✅ 是 | ✅ 通过 |
| AC-11 | 跨语言搜索（中文查询匹配英文内容） | T1.4 | TC-11-01, TC-11-02 | XCTest | ✅ 是 | ✅ 通过 |
| AC-12 | 搜索支持来源 App 过滤 | T0.5, T1.4, T1.9 | TC-12-01, TC-12-02 | XCTest + XCUITest | ✅ 是 | ✅ 通过 |
| AC-13 | 智能总结生成 3-5 句核心要点 | T2.1, T2.3, T2.4, T2.5 | TC-13-01~04 | XCTest + 手动 | ✅ 是 | ✅ 通过 |
| AC-14 | 即时翻译生成中英对照且保留技术术语原文 | T2.1, T2.3, T2.4, T2.5 | TC-14-01~04 | XCTest + 手动 | ✅ 是 | ✅ 通过 |
| AC-15 | 智能改写提供 3 种模式 | T2.1, T2.3, T2.4, T2.5 | TC-15-01~04 | XCTest + 手动 | ✅ 是 | ✅ 通过 |
| AC-16 | 提取待办返回结构化任务列表 | T2.1, T2.3, T2.4, T2.5 | TC-16-01~04 | XCTest + 手动 | ✅ 是 | ✅ 通过 |
| AC-17 | 未配置 API Key 时处理按钮置灰并提示 | T2.2, T2.5, T2.6 | TC-17-01~03 | XCUITest + 手动 | ✅ 是 | ✅ 通过 |
| AC-18 | 本地存储使用 AES-256 加密，数据文件无法直接读取 | T0.3 | TC-18-01~03 | XCTest + 手动 | ✅ 是 | ⚠️ 手动验证步骤缺失（见 S-02） |
| AC-19 | 数据默认不出本机 | T2.1, T4.5 | TC-19-01, TC-19-02 | XCTest + 手动 | ✅ 是 | ✅ 通过 |
| AC-20 | 应用黑名单中的 App 复制内容自动忽略 | T3.2, T3.4 | TC-20-01~03 | XCTest | ✅ 是 | ✅ 通过 |
| AC-21 | 30 天前内容自动清理 | T3.3, T3.5 | TC-21-01~04 | XCTest | ❌ 否（MVP 跳过） | ✅ 通过（跳过合理） |
| AC-22 | 敏感识别开关可关闭 | T3.1, T3.5 | TC-22-01~03 | XCTest + XCUITest | ✅ 是 | ✅ 通过 |
| AC-23 | 菜单栏图标常驻，点击弹出 popover | T0.1, T0.7, T3.6 | TC-23-01~03 | XCUITest + 手动 | ✅ 是 | ✅ 通过 |
| AC-24 | 首次启动引导流程完整 | T3.7 | TC-24-01~03 | XCUITest + 手动 | ❌ 否（MVP 跳过） | ✅ 通过（跳过合理） |
| AC-25 | Web 交互预览页可访问且模拟核心流程 | T4.1, T4.2, T4.3, T4.4, T4.5 | TC-25-01~03 | curl + 手动 | ✅ 是 | ✅ 通过 |

**AC 覆盖统计：**

| 指标 | 数值 |
|------|------|
| AC 总数 | 25 |
| 完整路径覆盖 | 25/25（100%） |
| MVP 路径覆盖 | 23/25（92%） |
| MVP 跳过 AC | AC-21、AC-24 |
| 审查通过 | 23/25 |
| 审查建议 | 2/25（AC-01、AC-18） |
| 审查缺失 | 0/25 |

---

## 4. 测试用例覆盖统计

### 4.1 TC 按任务分布统计

| 任务编号 | 任务名称 | 映射 TC 数 | TC 编号 | 框架一致性 |
|---------|---------|-----------|---------|-----------|
| T0.1 | Xcode 项目初始化 + SwiftLint | 1 | TC-23-01 | ✅ |
| T0.2 | 数据模型定义 | 2 | TC-01-01（间接）、TC-16-01（间接） | ✅ |
| T0.3 | EncryptedStore.swift | 3 | TC-18-01、TC-18-02、TC-18-03 | ⚠️ TC-18-02/03 手动步骤缺失 |
| T0.4 | PasteboardWatcher.swift | 5 | TC-01-01、TC-01-03、TC-02-01、TC-03-01、TC-04-01 | ❌ TC-01-01 框架不匹配 |
| T0.5 | AppDetector.swift | 1 | TC-12-01（间接） | ✅ |
| T0.6 | Logger.swift | 2 | TC-01-01（间接）、TC-19-01（间接） | ❌ TC-01-01 框架不匹配 |
| T0.7 | 菜单栏 UI 骨架 | 3 | TC-23-01、TC-23-02、TC-23-03 | ⚠️ 缺少 TC-01-01 |
| T0.8 | 主窗口 UI 骨架 | 3 | TC-01-02、TC-02-02、TC-03-02 | ✅ |
| T1.1 | 嵌入模型准备 | 1 | TC-05-01（间接） | ✅ |
| T1.2 | LocalEmbeddingService | 4 | TC-06-01、TC-06-02、TC-07-01、TC-07-02 | ✅ |
| T1.3 | ClassificationService | 1 | TC-05-01 | ✅ |
| T1.4 | SearchService | 5 | TC-09-01、TC-10-01、TC-11-01、TC-11-02、TC-12-01 | ✅ |
| T1.5 | 分类测试集准备 | 1 | TC-05-01 | ✅ |
| T1.6 | 敏感内容样本准备 | 6 | TC-08-01~06 | ✅ |
| T1.7 | 搜索测试集准备 | 1 | TC-10-01 | ✅ |
| T1.8 | popover 分类标签 UI | 1 | TC-23-03 | ⚠️ 缺少 TC-01-01 |
| T1.9 | 主窗口搜索框 UI | 1 | TC-12-02 | ✅ |
| T2.1 | LLMService | 8 | TC-13-01、TC-13-04、TC-14-01、TC-14-04、TC-15-01、TC-15-04、TC-16-01、TC-16-04、TC-19-01 | ✅ |
| T2.2 | APIKeyManager | 2 | TC-17-01、TC-17-02 | ✅ |
| T2.3 | LLM mock 响应准备 | 8 | TC-13-01、TC-13-04、TC-14-01、TC-14-04、TC-15-01、TC-15-04、TC-16-01、TC-16-04 | ✅ |
| T2.4 | 处理 Prompt 模板 | 0 | — | ✅（间接支持） |
| T2.5 | 详情面板 UI | 7 | TC-13-02、TC-13-03、TC-14-02、TC-14-03、TC-15-02、TC-15-03、TC-16-02、TC-16-03、TC-17-01、TC-17-02、TC-17-03 | ✅ |
| T2.6 | API Key 配置 UI | 3 | TC-17-01、TC-17-02、TC-17-03 | ✅ |
| T3.1 | SensitiveDetector | 8 | TC-08-01~07、TC-22-01、TC-22-02 | ✅ |
| T3.2 | BlacklistService | 3 | TC-20-01、TC-20-02、TC-20-03 | ✅ |
| T3.3 | CleanupService | 4 | TC-21-01~04 | ✅（MVP 跳过） |
| T3.4 | 默认黑名单预置 | 2 | TC-20-01、TC-20-02 | ✅ |
| T3.5 | 隐私设置 UI | 2 | TC-21-03、TC-22-03 | ✅（MVP 跳过） |
| T3.6 | 通用设置 UI | 1 | TC-23-01 | ✅（MVP 跳过） |
| T3.7 | 首次启动引导 | 3 | TC-24-01~03 | ✅（MVP 跳过） |
| T4.1 | Web 交互预览页 | 2 | TC-25-02、TC-25-03 | ✅ |
| T4.2 | GitHub Pages 部署 | 1 | TC-25-01 | ✅ |
| T4.3 | Demo 作品帖撰写 | 1 | TC-25-03 | ✅ |
| T4.4 | 截图 + Session ID 收集 | 1 | TC-25-02 | ✅ |
| T4.5 | 最终 .app 构建 | 2 | TC-19-02、TC-25-01 | ✅ |

### 4.2 TC 按框架覆盖统计

| 框架 | 总数 | 已映射 | MVP 覆盖 | 一致性 | 说明 |
|------|------|--------|---------|--------|------|
| XCTest | 41 | 41 | 37 | ✅ | 所有 XCTest TC 均映射到创建 XCTest 文件的任务 |
| XCUITest | 11 | 11 | 8 | ❌ | TC-01-01 映射到 T0.4/T0.6（仅创建 XCTest 文件），未映射到创建 PopoverUITests.swift 的 T0.7 |
| 手动 | 16 | 16 | 14 | ✅ | 手动 TC 映射正确 |
| curl | 1 | 1 | 1 | ✅ | TC-25-01 映射到 T4.2 |
| **合计** | **69** | **69** | **61** | — | — |

**XCUITest TC 详细覆盖检查（11 个）：**

| TC 编号 | TC 名称 | 覆盖任务 | 任务产出 XCUITest 文件 | 一致性 |
|---------|---------|---------|----------------------|--------|
| TC-01-01 | 复制文本后 3 秒内出现在 popover | T0.4, T0.6 | T0.4 → 仅 XCTest；T0.6 → 仅 XCTest | ❌ 不一致 |
| TC-01-02 | 复制文本后主窗口历史同步出现 | T0.8 | T0.8 → MainWindowUITests.swift | ✅ |
| TC-12-02 | 来源 App 筛选 UI 验证 | T1.9 | T1.9 → SearchUITests.swift | ✅ |
| TC-15-02 | 智能改写模式选择 UI | T2.5 | T2.5 → ProcessingUITests.swift | ✅ |
| TC-17-01 | 未配置 API Key 时按钮置灰 | T2.2, T2.5, T2.6 | T2.5 → ProcessingUITests.swift；T2.6 → SettingsUITests.swift | ✅ |
| TC-17-02 | 未配置 API Key 时点击提示 | T2.2, T2.5, T2.6 | T2.5 → ProcessingUITests.swift；T2.6 → SettingsUITests.swift | ✅ |
| TC-22-03 | 敏感识别开关 UI 切换 | T3.5 | T3.5 → PrivacyUITests.swift | ✅（MVP 跳过） |
| TC-23-01 | 菜单栏图标常驻 | T0.1, T0.7, T3.6 | T0.7 → PopoverUITests.swift | ✅ |
| TC-23-02 | 点击菜单栏图标弹出 popover | T0.7 | T0.7 → PopoverUITests.swift | ✅ |
| TC-24-01 | 首次启动引导流程完整 | T3.7 | T3.7 → FirstLaunchUITests.swift | ✅（MVP 跳过） |
| TC-24-02 | API Key 配置引导可跳过 | T3.7 | T3.7 → FirstLaunchUITests.swift | ✅（MVP 跳过） |

### 4.3 MVP 跳过的 TC 清单

| TC 编号 | TC 名称 | 跳过理由 | 依赖任务 |
|---------|---------|---------|---------|
| TC-21-01 | 30 天前内容自动清理 | 依赖 T3.3 CleanupService | T3.3 |
| TC-21-02 | 29 天前内容不被清理 | 依赖 T3.3 CleanupService | T3.3 |
| TC-21-03 | 应用启动时自动触发清理 | 依赖 T3.3 CleanupService | T3.3, T3.5 |
| TC-21-04 | 恰好 30 天前内容被清理（边界） | 依赖 T3.3 CleanupService | T3.3 |
| TC-22-03 | 敏感识别开关 UI 切换 | 依赖 T3.5 隐私设置 UI | T3.5 |
| TC-24-01 | 首次启动引导流程完整 | 依赖 T3.7 首次启动引导 | T3.7 |
| TC-24-02 | API Key 配置引导可跳过 | 依赖 T3.7 首次启动引导 | T3.7 |
| TC-24-03 | 首次启动引导手动验证 | 依赖 T3.7 首次启动引导 | T3.7 |

**MVP TC 覆盖统计：**

| 指标 | 数值 |
|------|------|
| TC 总数 | 69 |
| 完整路径覆盖 | 69/69（100%） |
| MVP 路径覆盖 | 61/69（88%） |
| MVP 跳过 TC | 8 个（TC-21-01~04、TC-22-03、TC-24-01~03） |
| 框架一致性 | 68/69（TC-01-01 不一致） |

---

## 5. 必须修复的问题

### M-01: TC-01-01（XCUITest）的测试代码无明确编写任务归属

**严重级别：必须修复**

**问题描述：**

TC-01-01（复制文本后 3 秒内出现在 popover）是 XCUITest 用例（见测试用例表第 115 行，框架列为 XCUITest）。

TC 覆盖矩阵（8.2 节）将 TC-01-01 映射到 T0.4 和 T0.6，但：

| 任务 | 产出测试文件 | 文件类型 | TC 映射包含 TC-01-01？ |
|------|------------|---------|----------------------|
| T0.4 | PasteboardWatcherTests.swift、ContentReaderTests.swift、DeduplicationTests.swift | 仅 XCTest | ✅ 是（但无法产出 XCUITest 代码） |
| T0.6 | LoggerTests.swift | 仅 XCTest | ✅ 是（间接，但无法产出 XCUITest 代码） |
| T0.7 | **PopoverUITests.swift** | **XCUITest** | ❌ 否（TC 映射仅列 TC-23-01~03） |
| T0.8 | MainWindowUITests.swift | XCUITest | ❌ 否（TC 映射仅列 TC-01-02/TC-02-02/TC-03-02） |
| T1.8 | PopoverUITests.swift（增强） | XCUITest | ❌ 否（TC 映射仅列 TC-23-03） |

**影响：**

1. 执行 T0.4 时，开发者会写 PasteboardWatcher 的单元测试（XCTest），但 TC-01-01 需要 UI 测试（XCUITest），无法在此任务中完成
2. 执行 T0.7 时，开发者创建 PopoverUITests.swift，但 TC 映射只列了 TC-23-01~03，不会写 TC-01-01 的测试代码
3. 结果：TC-01-01 的 XCUITest 代码可能永远不会被编写，或被遗漏到无明确归属的状态
4. 连锁影响：Phase 0 完成标志"复制文本后 popover 显示"无法通过 TC-01-01 自动化验证，只能依赖 TC-01-03（手动验证）

**修复建议：**

将 TC-01-01 添加到 T0.7 的「测试用例映射」字段中。

修改前（T0.7 测试用例映射）：
```
TC-23-01（菜单栏图标常驻）、TC-23-02（点击菜单栏图标弹出 popover）、TC-23-03（popover 手动验证）
```

修改后：
```
TC-01-01（复制文本后 3 秒内出现在 popover）、TC-23-01（菜单栏图标常驻）、TC-23-02（点击菜单栏图标弹出 popover）、TC-23-03（popover 手动验证）
```

**理由：**

- T0.7 创建 `PopoverUITests.swift`（XCUITest 文件），是 TC-01-01 测试代码的自然归属
- AC-01 是 Phase 0 的 AC，T0.7 也是 Phase 0 的任务，时间线对齐
- T0.7 编写 TC-01-01 测试代码后，测试可能在 Phase 0 全部任务完成后才能通过（需要 T0.4 捕获 + T0.3 存储 + T0.7 popover 显示的完整链路），这符合 TDD 先写测试的原则

**备选方案：**

若认为 T0.7 时 popover 仅是空列表骨架、TC-01-01 无法验证，可将 TC-01-01 添加到 T1.8（popover 分类标签 UI，增强 PopoverUITests.swift），此时完整链路已打通。但 T1.8 属于 Phase 1，而 AC-01 是 Phase 0 的 AC，时间线上略有错位。

---

## 6. 建议

### S-01: 测试目录命名与设计规范/测试用例表不一致

**严重级别：建议（不影响执行）**

**问题描述：**

实施计划 8.3.2 节的测试文件路径使用以下目录名：

| 实施计划 8.3.2 | 设计规范 9.2.2 / 测试用例表 1.4 |
|---------------|-------------------------------|
| `ClipMindTests/Models/` | — （无对应目录） |
| `ClipMindTests/Storage/` | `ClipMindTests/StorageTests/` |
| `ClipMindTests/Capture/` | `ClipMindTests/CaptureTests/` |
| `ClipMindTests/Utils/` | — （无对应目录） |
| `ClipMindTests/ML/` | — （无对应目录） |
| `ClipMindTests/ClassifyTests/` | `ClipMindTests/ClassifyTests/` ✅ |
| `ClipMindTests/SearchTests/` | `ClipMindTests/SearchTests/` ✅ |
| `ClipMindTests/LLMTests/` | `ClipMindTests/LLMTests/` ✅ |
| `ClipMindTests/PrivacyTests/` | `ClipMindTests/PrivacyTests/` ✅ |
| `ClipMindTests/Helpers/` | `ClipMindTests/Helpers/` ✅ |

不一致项：`Storage/` vs `StorageTests/`、`Capture/` vs `CaptureTests/`，以及实施计划额外增加了 `Models/`、`Utils/`、`ML/` 目录。

**影响：**

- 不影响 xcodebuild 执行（`-only-testing` 使用测试类名而非目录路径）
- 可能导致执行时开发者按实施计划创建目录，而测试时参考设计规范/测试用例表，产生目录名混淆

**建议：**

统一实施计划 8.3.2 的目录命名与设计规范 9.2.2 一致：
- `Storage/` → `StorageTests/`
- `Capture/` → `CaptureTests/`
- `Models/`、`Utils/`、`ML/` 保留（设计规范未覆盖这些目录，但实施计划新增合理）

### S-02: T0.3 验证方式缺少手动验证步骤

**严重级别：建议**

**问题描述：**

T0.3（EncryptedStore.swift）的测试用例映射包含 3 个 TC：

| TC 编号 | 框架 | 验证方式中是否包含 |
|---------|------|------------------|
| TC-18-01 | XCTest | ✅ 包含（`-only-testing:ClipMindTests/EncryptedStoreTests`） |
| TC-18-02 | 手动 | ❌ 未包含手动验证步骤 |
| TC-18-03 | 手动 | ❌ 未包含手动验证步骤 |

T0.3 的验证方式仅列出了两条 xcodebuild test 命令（针对 EncryptedStoreTests 和 EncryptionTests），未包含 TC-18-02（用 DB Browser for SQLite 打开 clipmind.db 验证无法打开）和 TC-18-03（用 hex viewer 打开 clipmind.db 验证内容为乱码）的手动验证步骤。

**影响：**

- 开发者执行 T0.3 后，可能仅运行自动化测试即认为任务完成，遗漏手动验证项
- AC-18 的完整验证需要 TC-18-01（自动）+ TC-18-02（手动）+ TC-18-03（手动）三者结合

**建议：**

在 T0.3 的验证方式字段中补充手动验证步骤：

```
xcodebuild test ... -only-testing:ClipMindTests/EncryptedStoreTests；
xcodebuild test ... -only-testing:ClipMindTests/EncryptionTests；
手动验证：用 DB Browser for SQLite 打开 ~/Library/Application Support/ClipMind/clipmind.db，确认无法打开或内容为乱码（TC-18-02）；
手动验证：用 hex viewer 打开 clipmind.db，确认文件内容无明文（TC-18-03）
```

---

## 7. 审查结论

| 维度 | 结论 | 说明 |
|------|------|------|
| 可验证性 | ⚠️ 基本通过 | 35 个任务验证方式明确，Phase 0 完成标志因 TC-01-01 问题存在风险 |
| AC 覆盖完整性 | ✅ 通过 | 25/25 AC 全覆盖，MVP 23/25 |
| TC 覆盖完整性 | ⚠️ 基本通过 | 69/69 TC 全映射，但 TC-01-01 框架一致性不通过 |
| 验证命令正确性 | ✅ 通过 | xcodebuild scheme/target/destination 正确，测试类引用与产出文件一致 |
| MVP 降级处理 | ✅ 通过 | 跳过任务/AC/TC 清单完整，补偿措施合理 |

**总结：**

实施计划在 AC 覆盖（25/25）和 TC 覆盖（69/69）上数量完整，MVP 兜底路径设计合理，验证命令格式正确。存在 1 个必须修复的问题（TC-01-01 的 XCUITest 代码无明确任务归属），建议修复后再进入执行阶段。2 个建议项（目录命名统一、T0.3 手动验证步骤补充）可在执行过程中顺带修正，不阻塞计划启动。
