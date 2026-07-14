> 最后更新：2026-07-14 | 版本：v1.7（基于设计规范 v1.7）

# ClipMind 初赛 MVP 测试用例表

**功能编号**：F1.x（Phase 01 · P0 · 初赛必做）
**文档存放路径**：`docs/planning/P0/F1/F1_ClipMind_测试用例表.md`
**关联设计规范**：`docs/planning/P0/F1/F1_ClipMind_设计规范.md` v1.7
**适用阶段**：TRAE AI 创造力大赛初赛（2026-07-15 截止）

---

## 目录

1. [概述](#1-概述)
2. [测试用例总表](#2-测试用例总表)
3. [测试用例详情](#3-测试用例详情)
4. [测试数据集准备](#4-测试数据集准备)
5. [测试执行计划](#5-测试执行计划)
6. [覆盖度统计](#6-覆盖度统计)
7. [版本记录](#版本记录)

---

## 1. 概述

### 1.1 覆盖范围

本测试用例表覆盖设计规范 v1.6 中定义的全部 26 条验收标准（AC-01 ~ AC-26），按功能模块组织：

| 模块 | AC 数量 | AC 编号范围 |
|------|---------|------------|
| F1.1 剪贴板监听与捕获 | 4 | AC-01 ~ AC-04 |
| F1.2 自动分类 | 4 | AC-05 ~ AC-08 |
| F1.3 自然语言语义搜索 | 4 | AC-09 ~ AC-12 |
| F1.4 一键处理 | 5 | AC-13 ~ AC-17 |
| F1.5 本地加密存储 | 2 | AC-18 ~ AC-19 |
| F1.6 隐私保护 | 3 | AC-20 ~ AC-22 |
| F1.7 主界面与交互 | 4 | AC-23 ~ AC-26 |
| **合计** | **26** | — |

### 1.2 覆盖状态说明

| 状态 | 含义 | 图示 |
|------|------|------|
| COVERED | 已覆盖，测试代码已实现并通过 | ✅ |
| PARTIAL | 部分覆盖，测试代码部分实现 | 🟡 |
| MISSING | 未覆盖，测试代码尚未实现 | ❌ |
| DEFERRED | 延后覆盖，计划在后续阶段实现 | ⏸️ |

> **当前状态**：Phase 4（Web + Demo 帖）已全部完成，本表根据实际测试代码逐项核对覆盖状态。已实现的测试用例标注为 ✅ COVERED；部分覆盖（如仅 mock 路径或数据集缩减）标注为 🟡 PARTIAL；真实 API 集成与截图/录屏手动验证用例统一延后至 Phase 4 T4.4，标注为 ⏸️ DEFERRED；尚未实现的（依赖 Phase 3 任务）标注为 ❌ MISSING。Phase 4 的 TC-25-02/03 已通过 browser_use 子代理验证并更新为 ✅ COVERED，TC-25-01（curl HTTP 200）需合并到 main 触发 GitHub Pages 部署后验证。

### 1.3 测试框架

| 框架 | 用途 | 适用范围 |
|------|------|---------|
| XCTest | 单元测试 + 性能测试 | 核心模块逻辑、数据模型、服务层、mock 测试 |
| XCUITest | UI 自动化测试 | 关键用户路径、首启流程、菜单栏交互、popover 弹出 |
| 手动 | 人工验证 | 真实 API 集成、UX 体验、跨设备验证 |
| curl | HTTP 探测 | Web 预览页可访问性 |

### 1.4 测试组织结构

```
ClipMindTests/
├── App/
│   ├── GlobalHotkeyServiceTests.swift
│   └── AppIconAssetTests.swift   # 新增
├── Capture/
│   ├── PasteboardWatcherTests.swift
│   ├── ClipCaptureServiceTests.swift
│   ├── ContentReaderTests.swift
│   ├── DeduplicationTests.swift
│   └── AppDetectorTests.swift
├── ClassifyTests/
│   ├── ClassificationAccuracyTests.swift
│   └── ContentTypeTests.swift
├── SearchTests/
│   ├── SearchServiceTests.swift
│   ├── CrossLanguageSearchTests.swift
│   └── SourceFilterTests.swift
├── LLMTests/
│   ├── LLMServiceTests.swift
│   ├── MultiProviderLLMServiceTests.swift
│   ├── APIKeyManagerTests.swift
│   ├── PromptTemplateTests.swift
│   ├── SummarizeTests.swift
│   ├── TranslateTests.swift
│   ├── RewriteTests.swift
│   └── ExtractTodoTests.swift
├── Storage/
│   ├── EncryptedStoreTests.swift
│   └── EncryptionTests.swift
├── ML/
│   └── LocalEmbeddingServiceTests.swift
├── Models/
│   └── ClipItemModelTests.swift
├── Privacy/                       # 新增
│   └── PermissionRequesterTests.swift   # 新增
├── UI/                            # 新增
│   ├── PermissionIconSymbolTests.swift   # 新增
│   └── MainWindowLayoutTests.swift   # 新增（F1.12 回归保护）
├── Utils/
│   └── LoggerTests.swift
├── Fixtures/
│   └── llm_mock_responses.json
└── Helpers/
    ├── TestDatabaseHelper.swift
    ├── MockLLMService.swift
    ├── InterceptingURLProtocol.swift
    └── LLMFixtureLoader.swift

ClipMindUITests/
├── ClipMindUITests.swift
├── PopoverUITests.swift
├── MainWindowUITests.swift
├── SearchUITests.swift
├── ProcessingUITests.swift
└── SettingsUITests.swift
```

> **说明**：Phase 3 涉及的 `PrivacyTests/`（SensitiveDetector / BlacklistService）与 `Storage/CleanupServiceTests.swift`、`ClipMindUITests/FirstLaunchUITests.swift`、`ClipMindUITests/PrivacyUITests.swift` 目录尚未创建，待对应任务（T3.1/T3.2/T3.3/T3.5/T3.7）实现时补充。

---

## 2. 测试用例总表

| 用例编号 | AC 编号 | 用例名称 | 前置条件 | 测试步骤 | 预期结果 | 测试框架 | 覆盖状态 | 备注 |
|---------|---------|---------|---------|---------|---------|---------|---------|------|
| TC-01-01 | AC-01 | 复制文本后 3 秒内出现在 popover | App 已启动，菜单栏图标可见 | 1. 清空 NSPasteboard<br>2. 写入字符串 "test content"<br>3. 触发 PasteboardWatcher.handlePasteboardChange()<br>4. 等待最多 3 秒 | popover 列表首条包含 "test content" | XCUITest | ✅ COVERED | PasteboardWatcherTests 覆盖 changeCount 检测与回调；ClipCaptureServiceTests.testClipboardTextChangeSavesClipItem 覆盖端到端入库；testClipUpdateNotificationPosted 覆盖 UI 刷新通知触发 |
| TC-01-02 | AC-01 | 复制文本后主窗口历史同步出现 | App 已启动，主窗口已打开 | 1. 清空 NSPasteboard<br>2. 写入字符串 "main window test"<br>3. 触发 handlePasteboardChange()<br>4. 等待最多 3 秒<br>5. 打开主窗口历史列表 | 主窗口历史列表顶部出现 "main window test" | XCUITest | 🟡 PARTIAL | MainWindowUITests 覆盖空状态；ClipCaptureServiceTests.testClipUpdateNotificationPosted 验证 clipDidUpdateNotification 发送（ClipStore 监听此通知刷新）；UI 重渲染未直接自动化，保持 PARTIAL |
| TC-01-03 | AC-01 | 文本捕获手动验证 | App 已启动 | 1. 在 Safari 选中一段文本<br>2. 按 Cmd+C<br>3. 观察菜单栏 popover | 3 秒内 popover 顶部出现该文本 | 手动 | ⏸️ DEFERRED | Safari 真实场景，延后至 Phase 4 T4.4 |
| TC-02-01 | AC-02 | 复制图片被捕获为缩略图（单元） | EncryptedStore 测试库就绪 | 1. 构造 NSImage test fixture（64x64）<br>2. 调用 PasteboardWatcher.handlePasteboardChange()<br>3. 查询数据库最新记录 | ClipItem.content 为 .image(_)<br>数据库存在该记录 | XCTest | ✅ COVERED | ContentReaderTests.testReadImage + testImageThumbnailSize 覆盖（缩略图上限 200） |
| TC-02-02 | AC-02 | 复制图片被捕获为缩略图（UI） | App 已启动 | 1. 在预览 App 复制一张图片<br>2. 打开 popover<br>3. 观察首条条目 | 显示 64x64 缩略图，原始数据加密存储 | 手动 | ⏸️ DEFERRED | 预览 App 真实场景，延后至 Phase 4 T4.4 |
| TC-03-01 | AC-03 | 复制文件路径被捕获 | App 已启动 | 1. 构造 NSPasteboard 写入 [NSURL(fileURLWithPath: "/tmp/test.txt")]<br>2. 调用 handlePasteboardChange()<br>3. 查询数据库最新记录 | ClipItem.content 为 .filePath([URL])<br>包含 "/tmp/test.txt" | XCTest | ✅ COVERED | ContentReaderTests.testReadFilePaths + testReadContentFilePath 覆盖 |
| TC-03-02 | AC-03 | 复制文件路径 UI 验证 | App 已启动 | 1. 在 Finder 选中文件<br>2. 按 Cmd+C<br>3. 打开 popover 与详情面板 | popover 显示文件路径文本<br>详情面板展示完整路径列表 | 手动 | ⏸️ DEFERRED | Finder 真实场景，延后至 Phase 4 T4.4 |
| TC-04-01 | AC-04 | 连续复制相同内容不重复入库 | EncryptedStore 测试库就绪 | 1. 记录数据库当前条目数 N<br>2. 调用 handlePasteboardChange() 传入 "duplicate content"<br>3. 再次调用 handlePasteboardChange() 传入相同 "duplicate content"<br>4. 查询数据库条目数 | 数据库条目数为 N+1（仅新增 1 条） | XCTest | ✅ COVERED | DeduplicationTests + PasteboardWatcherTests.testDuplicateContentNotForwarded 覆盖去重；ClipCaptureServiceTests.testDifferentContentSavesMultipleItems 覆盖不同内容入库多条（逆向对照） |
| TC-05-01 | AC-05 | 11 种入库类型分类准确率 ≥ 80% | 分类测试集就绪（220 条） | 1. 加载 classification_samples.json（220 条）<br>2. 遍历每条样本调用 LocalEmbeddingService.classify()<br>3. 统计正确数 / 总数 | 准确率 ≥ 0.80（≥ 176 条正确） | XCTest | 🟡 PARTIAL | ClassificationAccuracyTests 使用 33 条内联样本（11 类 × 3 条）验证准确率，220 条完整测试集待 T1.5 补充 |
| TC-06-01 | AC-06 | 代码片段识别为 code 类型 | LocalEmbeddingService 实例化 | 1. 输入内容 `func test() { print("hello") }`<br>2. 调用 classify(content:)<br>3. 读取返回值 | 返回 ContentType.code | XCTest | ✅ COVERED | ContentTypeTests.testClassifySwiftCode 覆盖 |
| TC-06-02 | AC-06 | 多语言代码片段识别为 code 类型 | LocalEmbeddingService 实例化 | 1. 输入 Python 代码 `def hello(): print("hi")`<br>2. 调用 classify(content:)<br>3. 读取返回值 | 返回 ContentType.code | XCTest | ✅ COVERED | ContentTypeTests.testClassifyPythonCode 覆盖 |
| TC-07-01 | AC-07 | 报错日志识别为 error 类型 | LocalEmbeddingService 实例化 | 1. 输入内容 `Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value`<br>2. 调用 classify(content:)<br>3. 读取返回值 | 返回 ContentType.error | XCTest | ✅ COVERED | ContentTypeTests.testClassifySwiftError 覆盖 |
| TC-07-02 | AC-07 | 堆栈报错识别为 error 类型 | LocalEmbeddingService 实例化 | 1. 输入内容包含 "Traceback (most recent call last): ... Exception"<br>2. 调用 classify(content:)<br>3. 读取返回值 | 返回 ContentType.error | XCTest | ✅ COVERED | ContentTypeTests.testClassifyPythonTraceback 覆盖 |
| TC-08-01 | AC-08 | Token 被识别为敏感内容且不入库（单元） | SensitiveDetector + EncryptedStore 就绪 | 1. 输入 `sk-proj-abcdef1234567890abcdef1234567890abcdef`<br>2. 调用 SensitiveDetector.detect()<br>3. 记录数据库当前条目数 N<br>4. 调用 EncryptedStore.save()<br>5. 查询数据库条目数 | SensitiveDetector 返回 true<br>数据库条目数为 N（无新增） | XCTest | ❌ MISSING | 依赖 T3.1 SensitiveDetector（Phase 3） |
| TC-08-02 | AC-08 | 密码模式被识别为敏感内容 | SensitiveDetector 就绪 | 1. 输入 `password=abc123`<br>2. 调用 SensitiveDetector.detect() | 返回 true | XCTest | ❌ MISSING | 依赖 T3.1 SensitiveDetector（Phase 3） |
| TC-08-03 | AC-08 | 银行卡号被识别为敏感内容 | SensitiveDetector 就绪 | 1. 输入 `6225880123456789`（通过 Luhn 校验）<br>2. 调用 SensitiveDetector.detect() | 返回 true | XCTest | ❌ MISSING | 依赖 T3.1 SensitiveDetector（Phase 3） |
| TC-08-04 | AC-08 | 身份证号被识别为敏感内容 | SensitiveDetector 就绪 | 1. 输入 `110101199001011234`（通过校验）<br>2. 调用 SensitiveDetector.detect() | 返回 true | XCTest | ❌ MISSING | 依赖 T3.1 SensitiveDetector（Phase 3） |
| TC-08-05 | AC-08 | 验证码被识别为敏感内容 | SensitiveDetector 就绪 | 1. 输入 `123456`（纯数字 4-8 位）<br>2. 调用 SensitiveDetector.detect() | 返回 true | XCTest | ❌ MISSING | 依赖 T3.1 SensitiveDetector（Phase 3） |
| TC-08-06 | AC-08 | 敏感关键词被识别 | SensitiveDetector 就绪 | 1. 输入 `api_key=sk-xxxxxxx`<br>2. 调用 SensitiveDetector.detect() | 返回 true | XCTest | ❌ MISSING | 依赖 T3.1 SensitiveDetector（Phase 3） |
| TC-08-07 | AC-08 | 复制 Token 弹出通知提示 | App 已启动，通知权限已授予 | 1. 在任意 App 复制 `sk-proj-abcdef...`<br>2. 观察系统通知 | 弹出通知"已忽略敏感内容" | 手动 | ❌ MISSING | 依赖 T3.1 SensitiveDetector（Phase 3） |
| TC-09-01 | AC-09 | 搜索响应时间 < 500ms | 数据库预填充 1000 条测试数据 | 1. 调用 embed("上次那个窗口管理的报错") 生成查询向量<br>2. 记录开始时间<br>3. 调用 search(query:limit:5)<br>4. 记录结束时间<br>5. 计算耗时 | 耗时 < 500ms | XCTest | 🟡 PARTIAL | SearchServiceTests.testSearchPerformanceUnder500ms 使用 measure{} 覆盖性能基线（5 条数据非 1000 条），未硬断言 < 500ms |
| TC-10-01 | AC-10 | Top-5 命中率 ≥ 70% | 搜索测试集就绪（50 个查询） | 1. 加载 search_queries.json（50 个查询）<br>2. 遍历每个查询调用 search()<br>3. 检查 Top-5 结果是否包含标注答案<br>4. 统计命中率 | 命中率 ≥ 0.70（≥ 35 个查询命中） | XCTest | 🟡 PARTIAL | SearchServiceTests 使用 5 条样本数据验证命中率，50 个查询完整测试集待 T1.7 补充 |
| TC-11-01 | AC-11 | 中文查询匹配英文内容 | 数据库预填充英文条目 | 1. 写入 ClipItem: "NSWindowController crash on macOS 14"<br>2. 调用 search(query: "窗口控制器崩溃", limit: 5)<br>3. 检查结果列表 | Top-5 结果中包含该英文条目 ID | XCTest | ✅ COVERED | CrossLanguageSearchTests 覆盖中文查英文路径 |
| TC-11-02 | AC-11 | 英文查询匹配中文内容 | 数据库预填充中文条目 | 1. 写入 ClipItem: "SwiftUI 状态管理实践"<br>2. 调用 search(query: "SwiftUI state management", limit: 5)<br>3. 检查结果列表 | Top-5 结果中包含该中文条目 ID | XCTest | ✅ COVERED | CrossLanguageSearchTests 覆盖英文查中文路径 |
| TC-12-01 | AC-12 | 来源 App 过滤生效 | 数据库预填充 Xcode + Safari 来源条目 | 1. 调用 search(query: "test", sourceApp: "com.apple.dt.Xcode", limit: 10)<br>2. 遍历结果列表检查 sourceApp 字段 | 所有结果 sourceApp == "com.apple.dt.Xcode" | XCTest | ✅ COVERED | SourceFilterTests 覆盖 bundleId 过滤 |
| TC-12-02 | AC-12 | 来源 App 筛选 UI 验证 | 数据库中有 Xcode 与 Safari 来源条目 | 1. 打开主窗口<br>2. 输入查询<br>3. 在筛选器中选择来源 "Xcode"<br>4. 查看结果列表 | 仅显示来自 Xcode 的条目 | XCUITest | ✅ COVERED | SearchUITests.testSourceFilterExists 覆盖 sourceFilterPicker 可见性 |
| TC-13-01 | AC-13 | 智能总结生成 3-5 句核心要点（mock） | mockLLM=true，长文本 fixture 就绪 | 1. 启用 DebugConfig.mockLLM<br>2. 输入长文本（>500 字）<br>3. 调用 LLMService.summarize()<br>4. 按句号分割返回字符串<br>5. 统计句数 | 句数为 3-5 句 | XCTest | ✅ COVERED | SummarizeTests.testSummarizeReturnsThreeToFiveSentences + 全 fixture 验证 |
| TC-13-02 | AC-13 | 智能总结结果写入 ClipItem.summary | mockLLM=true | 1. 调用 summarize() 返回结果<br>2. 写入 ClipItem.summary<br>3. 查询数据库该 ClipItem | ClipItem.summary 字段非空，内容为总结结果 | XCTest | 🟡 PARTIAL | ProcessingUITests.testSummaryResultBlockDisplayed 验证 UI 展示，ClipItem.summary 持久化未单独单元测试 |
| TC-13-03 | AC-13 | 智能总结真实 API 集成 | 真实 API Key 已配置 | 1. 选中长文本 ClipItem<br>2. 点击"智能总结"按钮<br>3. 等待最多 30 秒<br>4. 观察详情面板 | 30 秒内返回 3-5 句总结<br>详情面板展示总结区块 | 手动 | ⏸️ DEFERRED | 真实 API 集成验证，延后至 Phase 4 T4.4 |
| TC-13-04 | AC-13 | 智能总结 API 错误响应不阻塞本地 | mockLLM=true，mock 返回 HTTP 500 | 1. 配置 mock 返回 HTTP 500 错误响应<br>2. 调用 LLMService.summarize()<br>3. 检查返回结果与异常处理 | 抛出 LLMError.serverError<br>本地功能（分类/搜索/历史）不受影响<br>不崩溃 | XCTest | ✅ COVERED | SummarizeTests.testSummarizeServerErrorDoesNotBlockLocalFunctionality + MultiProviderLLMServiceTests.testThrowsServerErrorOn500 |
| TC-14-01 | AC-14 | 即时翻译生成中英对照（mock） | mockLLM=true | 1. 输入 "The NSWindowController manages window lifecycle"<br>2. 调用 LLMService.translate(from: "en", to: "zh")<br>3. 检查返回结果 | 结果包含中文翻译 + 原文对照<br>"NSWindowController"保留原文不翻译 | XCTest | ✅ COVERED | TranslateTests.testTranslateReturnsBilingualResult + testTranslatePreservesTechnicalTerms |
| TC-14-02 | AC-14 | 即时翻译结果写入 ClipItem.translation | mockLLM=true | 1. 调用 translate() 返回结果<br>2. 写入 ClipItem.translation<br>3. 查询数据库 | ClipItem.translation 字段非空 | XCTest | 🟡 PARTIAL | ProcessingUITests.testTranslationResultBlockDisplayed 验证 UI 展示，ClipItem.translation 持久化未单独单元测试 |
| TC-14-03 | AC-14 | 即时翻译真实 API 集成 | 真实 API Key 已配置 | 1. 选中英文 ClipItem<br>2. 点击"即时翻译"按钮<br>3. 等待最多 30 秒<br>4. 观察详情面板 | 30 秒内返回中英对照<br>技术术语保留原文 | 手动 | ⏸️ DEFERRED | 真实 API 集成验证，延后至 Phase 4 T4.4 |
| TC-14-04 | AC-14 | 即时翻译 API 超时不阻塞本地 | mockLLM=true，mock 配置超时响应 | 1. 配置 mock 返回延迟 >30s 的超时响应<br>2. 调用 LLMService.translate()<br>3. 检查返回结果与异常处理 | 抛出 LLMError.timeout<br>本地功能不受影响<br>不崩溃 | XCTest | ✅ COVERED | TranslateTests.testTranslateTimeoutDoesNotBlockLocalFunctionality + MultiProviderLLMServiceTests.testTimeoutThrowsTimeoutError |
| TC-15-01 | AC-15 | 智能改写提供 3 种模式（mock） | mockLLM=true | 1. 遍历 RewriteMode 枚举（adjustTone/condense/expand）<br>2. 对每种模式调用 LLMService.rewrite(mode:)<br>3. 检查返回结果 | 三种模式均返回非空字符串 | XCTest | ✅ COVERED | RewriteTests 覆盖 adjustTone/condense/expand 三模式 + 结果差异验证 |
| TC-15-02 | AC-15 | 智能改写模式选择 UI | App 已启动，API Key 已配置 | 1. 选中一条 ClipItem<br>2. 点击"智能改写"按钮<br>3. 观察弹出选项 | 弹出"调整语气/精简/扩写"三选项 | XCUITest | ✅ COVERED | ProcessingUITests.testRewriteModePickerShows 覆盖 3 个选项可见性 |
| TC-15-03 | AC-15 | 智能改写真实 API 集成 | 真实 API Key 已配置 | 1. 选中一条文本 ClipItem<br>2. 点击"智能改写"<br>3. 选择"精简"模式<br>4. 等待结果 | 返回精简后的改写结果 | 手动 | ⏸️ DEFERRED | 真实 API 集成验证，延后至 Phase 4 T4.4 |
| TC-15-04 | AC-15 | 智能改写 API 限流响应处理 | mockLLM=true，mock 返回 HTTP 429 | 1. 配置 mock 返回 HTTP 429 限流响应<br>2. 调用 LLMService.rewrite(mode: .condense)<br>3. 检查返回结果与异常处理 | 抛出 LLMError.rateLimited<br>本地功能不受影响<br>不崩溃 | XCTest | ✅ COVERED | RewriteTests.testRewriteRateLimitedDoesNotBlockLocalFunctionality + MultiProviderLLMServiceTests.testThrowsRateLimitedOn429 |
| TC-16-01 | AC-16 | 提取待办返回结构化任务列表（mock） | mockLLM=true | 1. 输入 "张三负责登录模块 06.25 前完成"<br>2. 调用 LLMService.extractTodos()<br>3. 检查返回数组 | 返回 [TodoItem]<br>包含 task="登录模块完成"<br>assignee="张三"<br>dueDate="06.25" | XCTest | ✅ COVERED | ExtractTodoTests 覆盖 task/assignee/dueDate 字段 + 多任务场景 |
| TC-16-02 | AC-16 | 提取待办结果写入 ClipItem.todos | mockLLM=true | 1. 调用 extractTodos() 返回结果<br>2. 写入 ClipItem.todos<br>3. 查询数据库 | ClipItem.todos 字段非空，包含 TodoItem 数组 | XCTest | 🟡 PARTIAL | ProcessingUITests.testTodoResultBlockDisplayed 验证 UI 展示，ClipItem.todos 持久化未单独单元测试 |
| TC-16-03 | AC-16 | 提取待办真实 API 集成 | 真实 API Key 已配置 | 1. 选中会议纪要 ClipItem<br>2. 点击"提取待办"<br>3. 等待最多 30 秒<br>4. 观察详情面板 | 返回结构化任务列表<br>展示任务项 + 负责人 + 截止时间 | 手动 | ⏸️ DEFERRED | 真实 API 集成验证，延后至 Phase 4 T4.4 |
| TC-16-04 | AC-16 | 提取待办 API 响应解析失败处理 | mockLLM=true，mock 返回非 JSON 响应 | 1. 配置 mock 返回非 JSON 格式响应<br>2. 调用 LLMService.extractTodos()<br>3. 检查返回结果与异常处理 | 抛出 LLMError.parseError<br>本地功能不受影响<br>不崩溃 | XCTest | ✅ COVERED | ExtractTodoTests.testExtractTodosParseErrorWhenJsonInvalid + MultiProviderLLMServiceTests.testExtractTodosThrowsParseErrorWhenContentNotJson |
| TC-17-01 | AC-17 | 未配置 API Key 时按钮置灰 | App 启动且未配置 API Key | 1. 清空 API Key 配置<br>2. 启动 App<br>3. 选中一条 ClipItem<br>4. 观察"智能总结"按钮状态 | 按钮置灰不可点击<br>或点击后弹窗"需配置 API Key" | XCUITest | ✅ COVERED | ProcessingUITests.testProcessingButtonsDisabledWhenNoAPIKey + APIKeyManagerTests.testIsConfiguredReturnsFalseWhenNoKey |
| TC-17-02 | AC-17 | 未配置 API Key 时点击提示 | App 启动且未配置 API Key | 1. 清空 API Key<br>2. 选中 ClipItem<br>3. 点击"智能总结"<br>4. 观察提示 | 出现提示文案"需配置 API Key" | XCUITest | 🟡 PARTIAL | 实际实现为按钮置灰（disabled），不触发点击事件；置灰逻辑已覆盖，"点击后弹窗提示"路径未实现 |
| TC-17-03 | AC-17 | 未配置 API Key 手动验证 | App 已启动 | 1. 清空 API Key<br>2. 选中一条内容<br>3. 尝试点击"智能总结" | 按钮置灰或弹窗提示 | 手动 | ⏸️ DEFERRED | UX 验证，延后至 Phase 4 T4.4 |
| TC-18-01 | AC-18 | AES-256 加密后数据库文件无明文 | EncryptedStore 写入若干条目 | 1. 调用 EncryptedStore.save() 写入包含 "test content" 的 ClipItem<br>2. 关闭应用<br>3. 读取数据库文件原始字节<br>4. 搜索 "test content" 字符串 | 文件字节中不包含明文 "test content" | XCTest | ✅ COVERED | EncryptionTests.testContentBlobIsEncrypted + testRawContentBlobIsNotPlaintextJSON 覆盖字段级加密验证 |
| TC-18-02 | AC-18 | SQLite Browser 无法直接打开 | 数据库已写入数据 | 1. 用 DB Browser for SQLite 打开 `~/Library/Application Support/ClipMind/clipmind.db`<br>2. 观察打开结果 | 无法打开或内容为乱码 | 手动 | ⏸️ DEFERRED | 工具验证，延后至 Phase 4 T4.4 |
| TC-18-03 | AC-18 | 十六进制查看器显示乱码 | 数据库已写入数据 | 1. 用 hex viewer 打开 clipmind.db<br>2. 观察文件内容 | 文件内容为乱码（无明文） | 手动 | ⏸️ DEFERRED | 二进制验证，延后至 Phase 4 T4.4 |
| TC-19-01 | AC-19 | 数据不出本机（URLProtocol 拦截） | 自定义 URLProtocol 已注册 | 1. 注册 URLProtocol 拦截所有出站请求<br>2. 执行复制内容 + 搜索 + 本地分类全流程<br>3. 收集所有出站请求 URL<br>4. 检查 URL 域名 | 所有请求域名仅命中 LLM API 白名单（api.openai.com / open.bigmodel.cn / dashscope.aliyuncs.com / api.deepseek.com）<br>无其他域名请求 | XCTest | ✅ COVERED | MultiProviderLLMServiceTests 覆盖 4 个 provider 请求 URL 验证 + LLMServiceTests.testInterceptingURLProtocolCapturesRequestURL |
| TC-19-02 | AC-19 | 数据不出本机（抓包验证） | Charles/Proxyman 已配置 | 1. 启动 Charles/Proxyman 代理<br>2. 执行复制 + 搜索 + 本地分类全流程<br>3. 观察抓包列表 | 仅在用户主动点击"一键处理"时出现 LLM API 请求<br>其他流程无出站请求 | 手动 | ⏸️ DEFERRED | 抓包验证，延后至 Phase 4 T4.5（最终 .app 构建） |
| TC-20-01 | AC-20 | 黑名单 App 复制内容自动忽略 | BlacklistService 已加载默认黑名单 | 1. 记录数据库当前条目数 N<br>2. 调用 handlePasteboardChange() 传入 sourceApp: "com.agilebits.onepassword-os"<br>3. 查询数据库条目数 | 数据库条目数为 N（无新增）<br>无提示 | XCTest | ❌ MISSING | 依赖 T3.2 BlacklistService（Phase 3） |
| TC-20-02 | AC-20 | 钥匙串访问黑名单忽略 | BlacklistService 已加载默认黑名单 | 1. 调用 handlePasteboardChange() 传入 sourceApp: "com.apple.keychainaccess"<br>2. 查询数据库 | 数据库无新增记录 | XCTest | ❌ MISSING | 依赖 T3.2 BlacklistService（Phase 3） |
| TC-20-03 | AC-20 | 自定义黑名单添加与生效 | BlacklistService 实例化 | 1. 添加 "com.test.app" 到黑名单<br>2. 调用 handlePasteboardChange() 传入 sourceApp: "com.test.app"<br>3. 查询数据库 | 数据库无新增记录 | XCTest | ❌ MISSING | 依赖 T3.2 BlacklistService（Phase 3） |
| TC-21-01 | AC-21 | 30 天前内容自动清理 | EncryptedStore 测试库就绪 | 1. 插入一条 timestamp: Date().addingTimeInterval(-31*86400) 的记录<br>2. 调用 cleanup(olderThan: 30)<br>3. 查询该记录 | 该记录被删除 | XCTest | ✅ COVERED | EncryptedStoreTests.testCleanupOldItems 覆盖 31 天清理逻辑 |
| TC-21-02 | AC-21 | 29 天前内容不被清理 | EncryptedStore 测试库就绪 | 1. 插入一条 timestamp: Date().addingTimeInterval(-29*86400) 的记录<br>2. 调用 cleanup(olderThan: 30)<br>3. 查询该记录 | 该记录保留 | XCTest | ❌ MISSING | 29 天保留边界用例未单独测试，待 T3.3 CleanupService 补充 |
| TC-21-03 | AC-21 | 应用启动时自动触发清理 | 数据库中有 31 天前的记录 | 1. 启动 App<br>2. 等待启动完成<br>3. 查询数据库 | 31 天前的记录被删除 | XCTest | ❌ MISSING | 启动触发清理依赖 T3.3 CleanupService（Phase 3） |
| TC-21-04 | AC-21 | 恰好 30 天前内容被清理（边界） | EncryptedStore 测试库就绪 | 1. 插入一条 timestamp: Date().addingTimeInterval(-30*86400) 的记录<br>2. 调用 cleanup(olderThan: 30)<br>3. 查询该记录 | 该记录被删除（恰好达到 30 天阈值触发清理） | XCTest | ✅ COVERED | EncryptedStoreTests.testCleanupBoundary 覆盖恰好 30 天边界 |
| TC-22-01 | AC-22 | 关闭敏感识别后 Token 入库 | AppSettings.sensitiveDetectionEnabled=false | 1. 设置 sensitiveDetectionEnabled=false<br>2. 输入 `sk-proj-abcdef...`<br>3. 调用捕获流程<br>4. 查询数据库 | ClipItem 入库，数据库新增 1 条记录 | XCTest | ❌ MISSING | 依赖 T3.1 SensitiveDetector（Phase 3） |
| TC-22-02 | AC-22 | 开启敏感识别后 Token 不入库 | AppSettings.sensitiveDetectionEnabled=true | 1. 设置 sensitiveDetectionEnabled=true<br>2. 输入 `sk-proj-abcdef...`<br>3. 调用捕获流程<br>4. 查询数据库 | 数据库无新增记录 | XCTest | ❌ MISSING | 依赖 T3.1 SensitiveDetector（Phase 3） |
| TC-22-03 | AC-22 | 敏感识别开关 UI 切换 | App 已启动 | 1. 打开设置面板<br>2. 切换"敏感识别"开关为关闭<br>3. 保存设置<br>4. 复制 Token<br>5. 查询数据库 | Token 入库<br>开关状态持久化 | XCUITest | ❌ MISSING | 依赖 T3.5 隐私设置 UI（Phase 3） |
| TC-23-01 | AC-23 | 菜单栏图标常驻 | App 已启动 | 1. 启动 App<br>2. 观察系统菜单栏 | 菜单栏出现 ClipMind 图标 | XCUITest | ✅ COVERED | PopoverUITests.testStatusBarItemExists 覆盖 |
| TC-23-02 | AC-23 | 点击菜单栏图标弹出 popover | App 已启动，菜单栏图标可见 | 1. 点击菜单栏 ClipMind 图标<br>2. 观察 popover | popover 弹出<br>显示最近 5-10 条剪贴内容 + 搜索框 + "查看全部"按钮 | XCUITest | ✅ COVERED | PopoverUITests.testPopoverAppearsOnIconClick + testPopoverContainsSearchField + testPopoverContainsViewAllButton |
| TC-23-03 | AC-23 | popover 手动验证 | App 已启动，已有复制内容 | 1. 点击菜单栏图标<br>2. 观察 popover 内容 | popover 显示最近条目<br>含类型标签 + 内容预览 + 来源 + 时间 | 手动 | ⏸️ DEFERRED | UX 验证，延后至 Phase 4 T4.4 |
| TC-23-04 | AC-23 | 侧边栏最小宽度为 350（F1.12 回归） | LayoutConstants 可访问 | 1. 读取 LayoutConstants.sidebarMinWidth<br>2. 与 350 比较 | sidebarMinWidth == 350（原值 700 过宽导致窗口缩小时内容溢出） | XCTest | ✅ COVERED | MainWindowLayoutTests.testSidebarMinWidthIs350 覆盖；F1.12 bug 修复回归保护 |
| TC-23-05 | AC-23 | 侧边栏最小宽度不超过窗口最小宽度一半（F1.12 回归） | LayoutConstants 可访问 | 1. 计算 LayoutConstants.mainWindowMinWidth / 2<br>2. 比较 sidebarMinWidth 与一半窗口宽度 | sidebarMinWidth ≤ mainWindowMinWidth / 2（避免详情面板被挤压） | XCTest | ✅ COVERED | MainWindowLayoutTests.testSidebarMinWidthDoesNotExceedHalfOfWindow 覆盖；F1.12 bug 修复回归保护 |
| TC-23-06 | AC-23 | 窗口缩到最小时详情面板剩余空间为正（F1.12 回归） | LayoutConstants 可访问 | 1. 计算 mainWindowMinWidth - sidebarMinWidth<br>2. 验证结果 > 0 | 剩余空间 > 0（详情面板可见） | XCTest | ✅ COVERED | MainWindowLayoutTests.testDetailPanelHasPositiveSpaceAtWindowMinimum 覆盖；F1.12 bug 修复回归保护 |
| TC-23-07 | AC-23 | 主窗口最小尺寸常量稳定（F1.12 回归） | LayoutConstants 可访问 | 1. 读取 LayoutConstants.mainWindowMinWidth<br>2. 读取 LayoutConstants.mainWindowMinHeight<br>3. 分别与 980 和 500 比较 | mainWindowMinWidth == 980<br>mainWindowMinHeight == 500 | XCTest | ✅ COVERED | MainWindowLayoutTests.testMainWindowMinimumDimensions 覆盖；F1.12 bug 修复回归保护 |
| TC-24-01 | AC-24 | 首次启动引导流程完整（UI 自动化） | UserDefaults 已清空 | 1. 清空 UserDefaults<br>2. 启动 App<br>3. 遍历引导流程<br>4. 断言每个步骤页面出现 | 依次显示：欢迎页 → 权限请求 → API Key 配置引导（可跳过）→ 隐私默认值提示 → 进入主界面 | XCUITest | ✅ COVERED | FirstLaunchUITests.testFirstLaunchOnboardingFlow |
| TC-24-02 | AC-24 | API Key 配置引导可跳过 | UserDefaults 已清空 | 1. 启动 App 进入引导<br>2. 到达 API Key 配置步骤<br>3. 点击"跳过"<br>4. 观察提示 | 提示"分类/搜索本地可用，处理需配置"<br>进入隐私默认值提示步骤 | XCUITest | ✅ COVERED | FirstLaunchUITests.testAPIKeyGuideCanBeSkipped |
| TC-24-03 | AC-24 | 首次启动引导手动验证 | App 偏好已删除 | 1. 删除 App 偏好<br>2. 启动 App<br>3. 观察引导流程 | 5 个步骤依次出现<br>权限请求正确展示 | 手动 | ❌ MISSING | 依赖 T3.7 首次启动引导（Phase 3） |
| TC-24-04 | AC-24 | 重置标志位后首启引导应显示 | hasCompletedOnboarding=true | 1. 设置 hasCompletedOnboarding=true<br>2. 使用 --reset-onboarding 启动<br>3. 验证 OnboardingView 出现 | 显示首启引导而非主窗口 | XCUITest | ✅ COVERED | FirstLaunchUITests.testOnboardingShowsAfterResetFromCompletedState |
| TC-24-05 | AC-24 | 辅助功能请求触发 TCC 提示 | PermissionRequester.axTrustedCheck 可注入 mock | 1. 注入 mock 闭包记录 prompt 参数<br>2. 调用 `PermissionRequester.requestAccessibility()`<br>3. 读取 mock 记录的 prompt 值 | mock 闭包被调用<br>prompt 参数为 true（触发系统 TCC 提示对话框） | XCTest | ✅ COVERED | PermissionRequesterTests.testRequestAccessibilityPassesPromptTrue |
| TC-24-06 | AC-24 | 点击「打开系统设置」不崩溃 | 引导流程到达权限请求页 | 1. 启动 App 进入引导<br>2. 点击「开始使用」进入权限请求页<br>3. 点击「打开系统设置」按钮<br>4. 验证 app 仍存活 | app 不崩溃退出（state != .notRunning） | XCUITest | ✅ COVERED | PermissionRequestUITests.testOpenAccessibilitySettingsDoesNotCrashApp |
| TC-25-01 | AC-25 | Web 预览页可访问（curl） | Web 页已部署到 GitHub Pages | 1. 执行 `curl -I https://marcocpt.github.io/ClipMind/`<br>2. 检查 HTTP 状态码 | 返回 HTTP 200 | curl | ⏸️ DEFERRED | 延后至 Phase 4 T4.2 GitHub Pages 部署 |
| TC-25-02 | AC-25 | Web 预览页 4 个交互流程可点击 | 浏览器已打开 Web 预览页 URL | 1. 浏览器打开 Web URL<br>2. 点击"复制演示内容"按钮<br>3. 点击"自动分类"按钮<br>4. 点击"搜索"按钮<br>5. 点击"一键处理"按钮<br>6. 观察响应 | 4 个核心流程按钮均可点击<br>每个按钮有交互响应 | 手动 | ✅ COVERED | Phase 4 已完成，browser_use 子代理验证 4 个交互流程 PASS，截图存于 docs/planning/P0/F1/screenshots/ |
| TC-25-03 | AC-25 | Web 预览页内容完整 | 浏览器已打开 Web URL | 1. 浏览器打开 Web URL<br>2. 检查页面内容 | 包含产品介绍 + 交互式模拟<br>4 个核心流程可体验 | 手动 | ✅ COVERED | Phase 4 已完成，Web 页面包含产品介绍 + 4 个交互流程演示 |
| TC-26-01 | AC-26 | "cmd+shift+v" 解析为正确 keyCode 与修饰键 | HotkeyFormatter 就绪 | 1. 调用 `HotkeyFormatter.parse(stored: "cmd+shift+v")`<br>2. 读取返回值 | 返回 `(keyCode=9, modifiers=cmdKey\|shiftKey)` | XCTest | ✅ COVERED | testParseStoredHotkey_CmdShiftV_ReturnsCorrectModifierAndKeyCode |
| TC-26-02 | AC-26 | "ctrl+opt+a" 解析为正确 keyCode 与修饰键 | HotkeyFormatter 就绪 | 1. 调用 `HotkeyFormatter.parse(stored: "ctrl+opt+a")`<br>2. 读取返回值 | 返回 `(keyCode=0, modifiers=controlKey\|optionKey)` | XCTest | ✅ COVERED | testParseStoredHotkey_CtrlOptA_ReturnsCorrectModifierAndKeyCode |
| TC-26-03 | AC-26 | "cmd+a" 解析为正确 keyCode 与修饰键 | HotkeyFormatter 就绪 | 1. 调用 `HotkeyFormatter.parse(stored: "cmd+a")`<br>2. 读取返回值 | 返回 `(keyCode=0, modifiers=cmdKey)` | XCTest | ✅ COVERED | testParseStoredHotkey_CmdOnly_ReturnsCorrectModifierAndKeyCode |
| TC-26-04 | AC-26 | 无效格式返回 nil | HotkeyFormatter 就绪 | 1. 调用 `HotkeyFormatter.parse(stored: "invalid")`<br>2. 读取返回值 | 返回 nil | XCTest | ✅ COVERED | testParseStoredHotkey_InvalidFormat_ReturnsNil |
| TC-26-05 | AC-26 | 空字符串返回 nil | HotkeyFormatter 就绪 | 1. 调用 `HotkeyFormatter.parse(stored: "")`<br>2. 读取返回值 | 返回 nil | XCTest | ✅ COVERED | testParseStoredHotkey_EmptyString_ReturnsNil |
| TC-26-06 | AC-26 | 无修饰键返回 nil | HotkeyFormatter 就绪 | 1. 调用 `HotkeyFormatter.parse(stored: "v")`<br>2. 读取返回值 | 返回 nil | XCTest | ✅ COVERED | testParseStoredHotkey_NoModifier_ReturnsNil |
| TC-26-07 | AC-26 | 未知字母返回 nil | HotkeyFormatter 就绪 | 1. 调用 `HotkeyFormatter.parse(stored: "cmd+zzz")`<br>2. 读取返回值 | 返回 nil | XCTest | ✅ COVERED | testParseStoredHotkey_UnknownKey_ReturnsNil |
| TC-26-08 | AC-26 | 有效快捷键注册正确参数 | GlobalHotkeyService + mock 注册器就绪 | 1. 设置 AppSettings.hotkey = "cmd+shift+v"<br>2. 初始化 GlobalHotkeyService<br>3. 检查 mock 注册器收到的参数 | mock 注册器收到 `keyCode=9, modifiers=cmdKey\|shiftKey`<br>注册成功 | XCTest | ✅ COVERED | testGlobalHotkeyService_InitWithValidHotkey_RegistersWithCorrectParams |
| TC-26-09 | AC-26 | 无效快捷键不注册 | GlobalHotkeyService + mock 注册器就绪 | 1. 设置 AppSettings.hotkey = "invalid"<br>2. 初始化 GlobalHotkeyService<br>3. 检查注册状态 | 未调用注册器<br>未标记为已注册 | XCTest | ✅ COVERED | testGlobalHotkeyService_InitWithInvalidHotkey_IsNotRegistered |
| TC-26-10 | AC-26 | 注销清理注册状态 | GlobalHotkeyService 已注册快捷键 | 1. 初始化 GlobalHotkeyService（有效快捷键）<br>2. 调用 `unregister()`<br>3. 检查注册状态 | 注册器 `unregister()` 被调用<br>已注册状态清除 | XCTest | ✅ COVERED | testGlobalHotkeyService_Unregister_ClearsRegistration |
| TC-26-11 | AC-26 | 空快捷键不注册 | GlobalHotkeyService + mock 注册器就绪 | 1. 设置 AppSettings.hotkey = ""<br>2. 初始化 GlobalHotkeyService<br>3. 检查注册状态 | 未调用注册器<br>未标记为已注册 | XCTest | ✅ COVERED | testGlobalHotkeyService_EmptyHotkey_IsNotRegistered |
| TC-26-12 | AC-26 | 注册器失败时不标记为已注册 | GlobalHotkeyService + mock 注册器（register 返回 false） | 1. 配置 mock 注册器 `register()` 返回 false<br>2. 初始化 GlobalHotkeyService（有效快捷键）<br>3. 检查注册状态 | 注册器 `register()` 被调用但返回 false<br>未标记为已注册 | XCTest | ✅ COVERED | testGlobalHotkeyService_RegistrarFails_IsNotRegistered |
| TC-26-13 | AC-26 | 快捷键触发发送 .openMainWindow 通知 | GlobalHotkeyService 已注册快捷键 | 1. 初始化 GlobalHotkeyService（有效快捷键）<br>2. 监听 `.openMainWindow` 通知<br>3. 模拟快捷键触发（调用 onTriggered 回调）<br>4. 检查通知是否发送 | `.openMainWindow` 通知被发送 | XCTest | ✅ COVERED | testGlobalHotkeyService_HotkeyPressed_PostsOpenMainWindowNotification |

---

## 3. 测试用例详情

### 3.1 F1.1 剪贴板监听与捕获

#### AC-01：复制文本后 3 秒内出现在 popover 与主窗口历史

**测试目标**：验证剪贴板监听器能在 3 秒内捕获文本内容并同步到 popover 与主窗口。

**TC-01-01：复制文本后 3 秒内出现在 popover**

- **前置条件**：
  - App 已启动
  - 菜单栏图标可见
  - 辅助功能权限已授予
- **测试步骤**：
  1. 调用 `NSPasteboard.general.clearContents()` 清空剪贴板
  2. 调用 `NSPasteboard.general.setString("test content", forType: .string)` 写入测试字符串
  3. 触发 `PasteboardWatcher.handlePasteboardChange()` 或等待轮询检测
  4. 等待最多 3 秒，轮询检查 popover 列表
- **预期结果**：
  - popover 列表首条内容包含 "test content"
  - 捕获延迟 < 3 秒
- **测试框架**：XCUITest
- **覆盖状态**：✅ COVERED
- **备注**：超时断言 3s，使用 `XCUIElement.waitForExistence(timeout: 3)`

**TC-01-02：复制文本后主窗口历史同步出现**

- **前置条件**：
  - App 已启动
  - 主窗口已打开
- **测试步骤**：
  1. 清空 NSPasteboard
  2. 写入字符串 "main window test"
  3. 触发 handlePasteboardChange()
  4. 等待最多 3 秒
  5. 打开主窗口历史列表
- **预期结果**：
  - 主窗口历史列表顶部出现 "main window test"
  - 与 popover 同步
- **测试框架**：XCUITest
- **覆盖状态**：🟡 PARTIAL
- **备注**：与 TC-01-01 配对验证双 UI 同步

**TC-01-03：文本捕获手动验证**

- **前置条件**：App 已启动
- **测试步骤**：
  1. 在 Safari 选中一段文本
  2. 按 Cmd+C 复制
  3. 观察菜单栏 popover
- **预期结果**：3 秒内 popover 顶部出现该文本
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：真实 Safari 场景验证

---

#### AC-02：复制图片被捕获为缩略图

**测试目标**：验证图片类型内容能被捕获、生成缩略图、原始数据加密存储。

**TC-02-01：复制图片被捕获为缩略图（单元测试）**

- **前置条件**：
  - EncryptedStore 测试库就绪
  - NSImage test fixture 已准备
- **测试步骤**：
  1. 构造 NSImage test fixture（尺寸 64x64）
  2. 模拟 NSPasteboard 写入 NSImage
  3. 调用 `PasteboardWatcher.handlePasteboardChange()`
  4. 查询数据库最新记录
- **预期结果**：
  - ClipItem.content 为 `.image(_)`
  - 数据库存在该记录
  - 缩略图尺寸不超过 64x64
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：使用 fixture 图片，避免依赖真实图片资源

**TC-02-02：复制图片被捕获为缩略图（UI 手动）**

- **前置条件**：App 已启动
- **测试步骤**：
  1. 在预览 App 打开一张图片
  2. 按 Cmd+C 复制
  3. 打开 popover
  4. 观察首条条目
- **预期结果**：
  - 显示 64x64 缩略图
  - 原始数据加密存储
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：预览 App 真实场景

---

#### AC-03：复制文件路径被捕获

**测试目标**：验证文件路径类型内容能被捕获并展示完整路径列表。

**TC-03-01：复制文件路径被捕获（单元测试）**

- **前置条件**：EncryptedStore 测试库就绪
- **测试步骤**：
  1. 构造 NSPasteboard 写入 `[NSURL(fileURLWithPath: "/tmp/test.txt")]`
  2. 调用 `PasteboardWatcher.handlePasteboardChange()`
  3. 查询数据库最新记录
- **预期结果**：
  - ClipItem.content 为 `.filePath([URL])`
  - URL 包含 "/tmp/test.txt"
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：支持多文件路径列表

**TC-03-02：复制文件路径 UI 验证**

- **前置条件**：App 已启动
- **测试步骤**：
  1. 在 Finder 选中一个文件
  2. 按 Cmd+C
  3. 打开 popover 与详情面板
- **预期结果**：
  - popover 显示文件路径文本
  - 详情面板展示完整路径列表
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：Finder 真实场景

---

#### AC-04：相同内容不重复入库

**测试目标**：验证去重逻辑，连续复制相同内容仅入库一次。

**TC-04-01：连续复制相同内容不重复入库**

- **前置条件**：EncryptedStore 测试库就绪
- **测试步骤**：
  1. 记录数据库当前条目数 N
  2. 调用 `handlePasteboardChange()` 传入 "duplicate content"
  3. 再次调用 `handlePasteboardChange()` 传入相同 "duplicate content"
  4. 查询数据库条目数
- **预期结果**：
  - 数据库条目数为 N+1（仅新增 1 条）
  - 无重复条目
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：基于内容哈希去重

---

### 3.2 F1.2 自动分类

#### AC-05：11 种入库类型自动分类准确率 ≥ 80%

**测试目标**：验证分类器在 220 条测试集上的准确率达标。

**TC-05-01：11 种入库类型分类准确率 ≥ 80%**

- **前置条件**：
  - 分类测试集就绪（`ClipMindTests/Fixtures/classification_samples.json`，220 条）
  - LocalEmbeddingService 模型已加载
- **测试步骤**：
  1. 加载 classification_samples.json
  2. 遍历 220 条样本
  3. 对每条样本调用 `LocalEmbeddingService.classify(content:)`
  4. 比对返回值与 expected_type
  5. 统计正确数 / 总数
- **预期结果**：
  - 准确率 ≥ 0.80（≥ 176 条正确）
  - 各类型准确率不低于 0.70（避免某类型严重失衡）
- **测试框架**：XCTest
- **覆盖状态**：🟡 PARTIAL
- **备注**：测试集 Phase 1 开始前准备，双人交叉抽查 10%

---

#### AC-06：代码片段被识别为 code 类型

**测试目标**：验证代码片段被正确分类为 code 类型。

**TC-06-01：Swift 代码片段识别为 code 类型**

- **前置条件**：LocalEmbeddingService 实例化
- **测试步骤**：
  1. 输入内容 `func test() { print("hello") }`
  2. 调用 `classify(content:)`
  3. 读取返回值
- **预期结果**：返回 `ContentType.code`
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：Swift 代码示例

**TC-06-02：多语言代码片段识别为 code 类型**

- **前置条件**：LocalEmbeddingService 实例化
- **测试步骤**：
  1. 输入 Python 代码 `def hello(): print("hi")`
  2. 调用 `classify(content:)`
  3. 读取返回值
- **预期结果**：返回 `ContentType.code`
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：Python 代码示例，验证跨语言代码识别

---

#### AC-07：报错日志被识别为 error 类型

**测试目标**：验证报错日志被正确分类为 error 类型。

**TC-07-01：Swift 报错识别为 error 类型**

- **前置条件**：LocalEmbeddingService 实例化
- **测试步骤**：
  1. 输入内容 `Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value`
  2. 调用 `classify(content:)`
  3. 读取返回值
- **预期结果**：返回 `ContentType.error`
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：Swift 运行时报错

**TC-07-02：Python 堆栈报错识别为 error 类型**

- **前置条件**：LocalEmbeddingService 实例化
- **测试步骤**：
  1. 输入内容包含 "Traceback (most recent call last): ... Exception"
  2. 调用 `classify(content:)`
  3. 读取返回值
- **预期结果**：返回 `ContentType.error`
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：Python 堆栈报错

---

#### AC-08：密码 Token 被识别为敏感内容且不入库

**测试目标**：验证 6 种敏感模式均能被识别，且敏感内容不入库。

**TC-08-01：Token 被识别为敏感内容且不入库**

- **前置条件**：
  - SensitiveDetector 就绪
  - EncryptedStore 就绪
- **测试步骤**：
  1. 输入 `sk-proj-abcdef1234567890abcdef1234567890abcdef`
  2. 调用 `SensitiveDetector.detect()`
  3. 记录数据库当前条目数 N
  4. 调用 `EncryptedStore.save()`
  5. 查询数据库条目数
- **预期结果**：
  - SensitiveDetector 返回 true
  - 数据库条目数为 N（无新增）
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：Token 格式前缀 `sk-` + 32+ 位

**TC-08-02：密码模式被识别为敏感内容**

- **前置条件**：SensitiveDetector 就绪
- **测试步骤**：
  1. 输入 `password=abc123`
  2. 调用 `SensitiveDetector.detect()`
- **预期结果**：返回 true
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：正则 `password\s*[=:]\s*\S+`

**TC-08-03：银行卡号被识别为敏感内容**

- **前置条件**：SensitiveDetector 就绪
- **测试步骤**：
  1. 输入 `6225880123456789`（通过 Luhn 校验）
  2. 调用 `SensitiveDetector.detect()`
- **预期结果**：返回 true
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：16-19 位数字 + Luhn 校验

**TC-08-04：身份证号被识别为敏感内容**

- **前置条件**：SensitiveDetector 就绪
- **测试步骤**：
  1. 输入 `110101199001011234`（通过校验）
  2. 调用 `SensitiveDetector.detect()`
- **预期结果**：返回 true
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：18 位 + 校验位

**TC-08-05：验证码被识别为敏感内容**

- **前置条件**：SensitiveDetector 就绪
- **测试步骤**：
  1. 输入 `123456`（纯数字 4-8 位）
  2. 调用 `SensitiveDetector.detect()`
- **预期结果**：返回 true
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：4-8 位纯数字

**TC-08-06：敏感关键词被识别**

- **前置条件**：SensitiveDetector 就绪
- **测试步骤**：
  1. 输入 `api_key=sk-xxxxxxx`
  2. 调用 `SensitiveDetector.detect()`
- **预期结果**：返回 true
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：关键词 `password|secret|api_key|access_token|private_key`

**TC-08-07：复制 Token 弹出通知提示**

- **前置条件**：
  - App 已启动
  - 通知权限已授予
- **测试步骤**：
  1. 在任意 App 复制 `sk-proj-abcdef...`
  2. 观察系统通知
- **预期结果**：弹出通知"已忽略敏感内容"
- **测试框架**：手动
- **覆盖状态**：❌ MISSING
- **备注**：通知 UX 验证

---

### 3.3 F1.3 自然语言语义搜索

#### AC-09：自然语言搜索返回结果 < 500ms

**测试目标**：验证搜索响应时间在 1000 条数据量下小于 500ms。

**TC-09-01：搜索响应时间 < 500ms**

- **前置条件**：
  - 数据库预填充 1000 条测试数据（含 embeddings）
  - LocalEmbeddingService 模型已加载
- **测试步骤**：
  1. 调用 `embed("上次那个窗口管理的报错")` 生成查询向量
  2. 记录开始时间 `Date()`
  3. 调用 `search(query:embed("..."), limit: 5)`
  4. 记录结束时间
  5. 计算耗时（毫秒）
- **预期结果**：
  - 耗时 < 500ms
  - 返回 5 条结果
- **测试框架**：XCTest
- **覆盖状态**：🟡 PARTIAL
- **备注**：使用 `XCTMetric` 或手动 `Date()` 计时

---

#### AC-10：Top-5 命中率 ≥ 70%

**测试目标**：验证搜索质量，在 50 个查询测试集上命中率达标。

**TC-10-01：Top-5 命中率 ≥ 70%**

- **前置条件**：
  - 搜索测试集就绪（`ClipMindTests/Fixtures/search_queries.json`，50 个查询）
  - 数据库预填充对应 ClipItem
- **测试步骤**：
  1. 加载 search_queries.json
  2. 遍历 50 个查询
  3. 对每个查询调用 `search(query:, limit: 5)`
  4. 检查 Top-5 结果是否包含标注答案（expected_ids）
  5. 统计命中率
- **预期结果**：
  - 命中率 ≥ 0.70（≥ 35 个查询命中）
- **测试框架**：XCTest
- **覆盖状态**：🟡 PARTIAL
- **备注**：测试集 Phase 1 开始前准备，双人交叉抽查 10%

---

#### AC-11：跨语言搜索（中文查询匹配英文内容）

**测试目标**：验证向量空间跨语言对齐，中文查询能匹配英文内容。

**TC-11-01：中文查询匹配英文内容**

- **前置条件**：数据库预填充英文条目
- **测试步骤**：
  1. 写入 ClipItem: "NSWindowController crash on macOS 14"
  2. 调用 `search(query: "窗口控制器崩溃", limit: 5)`
  3. 检查结果列表
- **预期结果**：
  - Top-5 结果中包含该英文条目 ID
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：跨语言对齐验证

**TC-11-02：英文查询匹配中文内容**

- **前置条件**：数据库预填充中文条目
- **测试步骤**：
  1. 写入 ClipItem: "SwiftUI 状态管理实践"
  2. 调用 `search(query: "SwiftUI state management", limit: 5)`
  3. 检查结果列表
- **预期结果**：
  - Top-5 结果中包含该中文条目 ID
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：反向跨语言验证

---

#### AC-12：搜索支持来源 App 过滤

**测试目标**：验证搜索结果可按来源 App 过滤。

**TC-12-01：来源 App 过滤生效（单元测试）**

- **前置条件**：数据库预填充 Xcode + Safari 来源条目
- **测试步骤**：
  1. 调用 `search(query: "test", sourceApp: "com.apple.dt.Xcode", limit: 10)`
  2. 遍历结果列表检查 sourceApp 字段
- **预期结果**：
  - 所有结果 sourceApp == "com.apple.dt.Xcode"
  - 不包含 Safari 来源条目
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：bundleId 精确匹配

**TC-12-02：来源 App 筛选 UI 验证**

- **前置条件**：数据库中有 Xcode 与 Safari 来源条目
- **测试步骤**：
  1. 打开主窗口
  2. 输入查询
  3. 在筛选器中选择来源 "Xcode"
  4. 查看结果列表
- **预期结果**：
  - 仅显示来自 Xcode 的条目
  - 筛选器状态持久化
- **测试框架**：XCUITest
- **覆盖状态**：✅ COVERED
- **备注**：UI 筛选器交互

---

### 3.4 F1.4 一键处理

#### AC-13：智能总结生成 3-5 句核心要点

**测试目标**：验证智能总结功能输出 3-5 句要点，并持久化到 ClipItem.summary。

**TC-13-01：智能总结生成 3-5 句核心要点（mock）**

- **前置条件**：
  - DebugConfig.mockLLM = true
  - 长文本 fixture 就绪（>500 字）
- **测试步骤**：
  1. 启用 `DebugConfig.mockLLM`
  2. 输入长文本（>500 字）
  3. 调用 `LLMService.summarize()`
  4. 按句号（。或 .）分割返回字符串
  5. 统计句数
- **预期结果**：
  - 句数为 3-5 句
  - 每句非空
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：mock 验证解析逻辑，使用 `llm_mock_responses.json`

**TC-13-02：智能总结结果写入 ClipItem.summary**

- **前置条件**：
  - DebugConfig.mockLLM = true
  - ClipItem 已入库
- **测试步骤**：
  1. 调用 `summarize()` 返回结果
  2. 写入 `ClipItem.summary`
  3. 调用 `EncryptedStore.update()`
  4. 查询数据库该 ClipItem
- **预期结果**：
  - ClipItem.summary 字段非空
  - 内容为总结结果
- **测试框架**：XCTest
- **覆盖状态**：🟡 PARTIAL
- **备注**：持久化验证

**TC-13-03：智能总结真实 API 集成**

- **前置条件**：
  - 真实 API Key 已配置
  - 长文本 ClipItem 已入库
- **测试步骤**：
  1. 选中长文本 ClipItem
  2. 点击"智能总结"按钮
  3. 等待最多 30 秒
  4. 观察详情面板
- **预期结果**：
  - 30 秒内返回 3-5 句总结
  - 详情面板展示"总结"区块
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：真实 API 质量验证

**TC-13-04：智能总结 API 错误响应不阻塞本地**

- **前置条件**：
  - DebugConfig.mockLLM = true
  - MockLLMService 配置为返回 HTTP 500 错误响应
- **测试步骤**：
  1. 配置 `MockLLMService.summarizeReturnError = LLMError.serverError(statusCode: 500)`
  2. 调用 `LLMService.summarize()`
  3. 捕获 throws 抛出的错误
  4. 验证本地功能：调用 `LocalEmbeddingService.classify()` 与 `EncryptedStore.query()` 确认仍可用
- **预期结果**：
  - 抛出 `LLMError.serverError` 错误
  - 不引发崩溃
  - 本地分类、搜索、历史查询功能不受影响
  - ClipItem.summary 字段保持原值（不被错误响应污染）
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：mock 错误响应验证，对应设计规范 5.2.4 节"LLM API 错误处理不阻塞本地功能"

---

#### AC-14：即时翻译生成中英对照且保留技术术语原文

**测试目标**：验证翻译功能输出中英对照，技术术语保留原文。

**TC-14-01：即时翻译生成中英对照（mock）**

- **前置条件**：
  - DebugConfig.mockLLM = true
- **测试步骤**：
  1. 输入 "The NSWindowController manages window lifecycle"
  2. 调用 `LLMService.translate(from: "en", to: "zh")`
  3. 检查返回结果
- **预期结果**：
  - 结果包含中文翻译 + 原文对照
  - "NSWindowController"保留原文不翻译
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：术语保留验证

**TC-14-02：即时翻译结果写入 ClipItem.translation**

- **前置条件**：
  - DebugConfig.mockLLM = true
  - ClipItem 已入库
- **测试步骤**：
  1. 调用 `translate()` 返回结果
  2. 写入 `ClipItem.translation`
  3. 调用 `EncryptedStore.update()`
  4. 查询数据库
- **预期结果**：
  - ClipItem.translation 字段非空
- **测试框架**：XCTest
- **覆盖状态**：🟡 PARTIAL
- **备注**：持久化验证

**TC-14-03：即时翻译真实 API 集成**

- **前置条件**：真实 API Key 已配置
- **测试步骤**：
  1. 选中英文 ClipItem
  2. 点击"即时翻译"按钮
  3. 等待最多 30 秒
  4. 观察详情面板
- **预期结果**：
  - 30 秒内返回中英对照
  - 技术术语保留原文
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：真实 API 质量验证

**TC-14-04：即时翻译 API 超时不阻塞本地**

- **前置条件**：
  - DebugConfig.mockLLM = true
  - MockLLMService 配置为返回延迟超过 30 秒的超时响应
- **测试步骤**：
  1. 配置 `MockLLMService.translateReturnError = LLMError.timeout`
  2. 调用 `LLMService.translate(from: "en", to: "zh")`
  3. 捕获 throws 抛出的错误
  4. 验证本地功能：调用 `LocalEmbeddingService.classify()` 与 `EncryptedStore.query()` 确认仍可用
- **预期结果**：
  - 抛出 `LLMError.timeout` 错误
  - 不引发崩溃
  - 本地分类、搜索、历史查询功能不受影响
  - ClipItem.translation 字段保持原值
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：mock 超时验证，对应设计规范 5.2.4 节"LLM API 错误处理不阻塞本地功能"

---

#### AC-15：智能改写提供 3 种模式

**测试目标**：验证改写功能提供"调整语气/精简/扩写"三种模式，每种模式均返回结果。

**TC-15-01：智能改写提供 3 种模式（mock）**

- **前置条件**：
  - DebugConfig.mockLLM = true
- **测试步骤**：
  1. 遍历 `RewriteMode` 枚举（adjustTone/condense/expand）
  2. 对每种模式调用 `LLMService.rewrite(mode:)`
  3. 检查返回结果
- **预期结果**：
  - 三种模式均返回非空字符串
  - 不同模式返回不同结果
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：mock 验证

**TC-15-02：智能改写模式选择 UI**

- **前置条件**：
  - App 已启动
  - API Key 已配置
- **测试步骤**：
  1. 选中一条 ClipItem
  2. 点击"智能改写"按钮
  3. 观察弹出选项
- **预期结果**：
  - 弹出"调整语气/精简/扩写"三选项
- **测试框架**：XCUITest
- **覆盖状态**：✅ COVERED
- **备注**：模式选择 UI

**TC-15-03：智能改写真实 API 集成**

- **前置条件**：真实 API Key 已配置
- **测试步骤**：
  1. 选中一条文本 ClipItem
  2. 点击"智能改写"
  3. 选择"精简"模式
  4. 等待结果
- **预期结果**：
  - 返回精简后的改写结果
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：真实 API 质量验证

**TC-15-04：智能改写 API 限流响应处理**

- **前置条件**：
  - DebugConfig.mockLLM = true
  - MockLLMService 配置为返回 HTTP 429 限流响应
- **测试步骤**：
  1. 配置 `MockLLMService.rewriteReturnError = LLMError.rateLimited(retryAfter: 60)`
  2. 调用 `LLMService.rewrite(mode: .condense)`
  3. 捕获 throws 抛出的错误
  4. 验证本地功能：调用 `LocalEmbeddingService.classify()` 与 `EncryptedStore.query()` 确认仍可用
- **预期结果**：
  - 抛出 `LLMError.rateLimited` 错误（含 retryAfter 提示）
  - 不引发崩溃
  - 本地分类、搜索、历史查询功能不受影响
  - ClipItem.rewrite 字段保持原值
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：mock 限流验证，对应设计规范 5.2.4 节"LLM API 错误处理不阻塞本地功能"

---

#### AC-16：提取待办返回结构化任务列表

**测试目标**：验证待办提取功能返回结构化 TodoItem 数组，含任务/负责人/截止时间。

**TC-16-01：提取待办返回结构化任务列表（mock）**

- **前置条件**：
  - DebugConfig.mockLLM = true
- **测试步骤**：
  1. 输入 "张三负责登录模块 06.25 前完成"
  2. 调用 `LLMService.extractTodos()`
  3. 检查返回数组
- **预期结果**：
  - 返回 [TodoItem]
  - 包含 `task="登录模块完成"`
  - 包含 `assignee="张三"`
  - 包含 `dueDate="06.25"`
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：结构化输出验证

**TC-16-02：提取待办结果写入 ClipItem.todos**

- **前置条件**：
  - DebugConfig.mockLLM = true
  - ClipItem 已入库
- **测试步骤**：
  1. 调用 `extractTodos()` 返回结果
  2. 写入 `ClipItem.todos`
  3. 调用 `EncryptedStore.update()`
  4. 查询数据库
- **预期结果**：
  - ClipItem.todos 字段非空
  - 包含 TodoItem 数组
- **测试框架**：XCTest
- **覆盖状态**：🟡 PARTIAL
- **备注**：持久化验证

**TC-16-03：提取待办真实 API 集成**

- **前置条件**：真实 API Key 已配置
- **测试步骤**：
  1. 选中会议纪要 ClipItem
  2. 点击"提取待办"
  3. 等待最多 30 秒
  4. 观察详情面板
- **预期结果**：
  - 返回结构化任务列表
  - 展示任务项 + 负责人 + 截止时间
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：真实 API 质量验证

**TC-16-04：提取待办 API 响应解析失败处理**

- **前置条件**：
  - DebugConfig.mockLLM = true
  - MockLLMService 配置为返回非 JSON 格式响应（无法解析为 [TodoItem]）
- **测试步骤**：
  1. 配置 `MockLLMService.extractTodosReturnRaw = "不是合法 JSON 的字符串"`
  2. 调用 `LLMService.extractTodos()`
  3. 捕获 throws 抛出的错误
  4. 验证本地功能：调用 `LocalEmbeddingService.classify()` 与 `EncryptedStore.query()` 确认仍可用
- **预期结果**：
  - 抛出 `LLMError.parseError` 错误
  - 不引发崩溃
  - 本地分类、搜索、历史查询功能不受影响
  - ClipItem.todos 字段保持原值
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：mock 解析失败验证，对应设计规范 5.2.4 节"LLM API 错误处理不阻塞本地功能"

---

#### AC-17：未配置 API Key 时处理按钮置灰并提示

**测试目标**：验证未配置 API Key 时，一键处理按钮置灰或点击后提示。

**TC-17-01：未配置 API Key 时按钮置灰**

- **前置条件**：
  - App 启动且未配置 API Key
- **测试步骤**：
  1. 清空 API Key 配置
  2. 启动 App
  3. 选中一条 ClipItem
  4. 观察"智能总结"按钮状态
- **预期结果**：
  - 按钮置灰不可点击
  - 或按钮可点击但点击后弹窗"需配置 API Key"
- **测试框架**：XCUITest
- **覆盖状态**：✅ COVERED
- **备注**：UI 状态验证

**TC-17-02：未配置 API Key 时点击提示**

- **前置条件**：
  - App 启动且未配置 API Key
- **测试步骤**：
  1. 清空 API Key
  2. 选中 ClipItem
  3. 点击"智能总结"
  4. 观察提示
- **预期结果**：
  - 出现提示文案"需配置 API Key"
- **测试框架**：XCUITest
- **覆盖状态**：🟡 PARTIAL
- **备注**：错误提示

**TC-17-03：未配置 API Key 手动验证**

- **前置条件**：App 已启动
- **测试步骤**：
  1. 清空 API Key
  2. 选中一条内容
  3. 尝试点击"智能总结"
- **预期结果**：
  - 按钮置灰或弹窗提示
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：UX 验证

---

### 3.5 F1.5 本地加密存储

#### AC-18：本地存储使用 AES-256 加密，数据文件无法直接读取

**测试目标**：验证数据库文件经过 AES-256 加密，无法被外部工具直接读取。

**TC-18-01：AES-256 加密后数据库文件无明文**

- **前置条件**：
  - EncryptedStore 写入若干条目
- **测试步骤**：
  1. 调用 `EncryptedStore.save()` 写入包含 "test content" 的 ClipItem
  2. 关闭应用
  3. 读取数据库文件原始字节（`Data(contentsOf:)`）
  4. 将字节转为字符串
  5. 搜索 "test content" 子串
- **预期结果**：
  - 文件字节中不包含明文 "test content"
  - 文件内容为乱码
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：加密验证

**TC-18-02：SQLite Browser 无法直接打开**

- **前置条件**：数据库已写入数据
- **测试步骤**：
  1. 用 DB Browser for SQLite 打开 `~/Library/Application Support/ClipMind/clipmind.db`
  2. 观察打开结果
- **预期结果**：
  - 无法打开或内容为乱码
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：工具验证

**TC-18-03：十六进制查看器显示乱码**

- **前置条件**：数据库已写入数据
- **测试步骤**：
  1. 用 hex viewer 打开 clipmind.db
  2. 观察文件内容
- **预期结果**：
  - 文件内容为乱码（无明文）
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：二进制验证

---

#### AC-19：数据默认不出本机

**测试目标**：验证除用户主动调用 LLM API 外，所有数据停留在本机。

**TC-19-01：数据不出本机（URLProtocol 拦截）**

- **前置条件**：
  - 自定义 URLProtocol 已注册
- **测试步骤**：
  1. 注册 URLProtocol 拦截所有出站请求
  2. 执行复制内容 + 搜索 + 本地分类全流程
  3. 收集所有出站请求 URL
  4. 检查 URL 域名
- **预期结果**：
  - 所有请求域名仅命中 LLM API 白名单
  - 白名单：`api.openai.com` / `open.bigmodel.cn` / `dashscope.aliyuncs.com` / `api.deepseek.com`
  - 无其他域名请求
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：网络隔离验证，自定义 URLProtocol 拦截

**TC-19-02：数据不出本机（抓包验证）**

- **前置条件**：
  - Charles/Proxyman 已配置
- **测试步骤**：
  1. 启动 Charles/Proxyman 代理
  2. 执行复制 + 搜索 + 本地分类全流程
  3. 观察抓包列表
- **预期结果**：
  - 仅在用户主动点击"一键处理"时出现 LLM API 请求
  - 其他流程无出站请求
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：抓包验证

---

### 3.6 F1.6 隐私保护

#### AC-20：应用黑名单中的 App 复制内容自动忽略

**测试目标**：验证黑名单 App 的复制内容被自动忽略，不入库不提示。

**TC-20-01：1Password 黑名单忽略**

- **前置条件**：
  - BlacklistService 已加载默认黑名单
- **测试步骤**：
  1. 记录数据库当前条目数 N
  2. 调用 `handlePasteboardChange()` 传入 `sourceApp: "com.agilebits.onepassword-os"`
  3. 查询数据库条目数
- **预期结果**：
  - 数据库条目数为 N（无新增）
  - 无提示
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：1Password 默认黑名单

**TC-20-02：钥匙串访问黑名单忽略**

- **前置条件**：BlacklistService 已加载默认黑名单
- **测试步骤**：
  1. 调用 `handlePasteboardChange()` 传入 `sourceApp: "com.apple.keychainaccess"`
  2. 查询数据库
- **预期结果**：
  - 数据库无新增记录
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：钥匙串默认黑名单

**TC-20-03：自定义黑名单添加与生效**

- **前置条件**：BlacklistService 实例化
- **测试步骤**：
  1. 添加 "com.test.app" 到黑名单
  2. 调用 `handlePasteboardChange()` 传入 `sourceApp: "com.test.app"`
  3. 查询数据库
- **预期结果**：
  - 数据库无新增记录
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：自定义黑名单

---

#### AC-21：30 天前内容自动清理

**测试目标**：验证 30 天前的内容被自动清理，边界用例（29 天）不被清理。

**TC-21-01：30 天前内容自动清理**

- **前置条件**：
  - EncryptedStore 测试库就绪
- **测试步骤**：
  1. 插入一条 `timestamp: Date().addingTimeInterval(-31*86400)` 的记录
  2. 调用 `cleanup(olderThan: 30)`
  3. 查询该记录
- **预期结果**：
  - 该记录被删除
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：清理逻辑

**TC-21-02：29 天前内容不被清理**

- **前置条件**：EncryptedStore 测试库就绪
- **测试步骤**：
  1. 插入一条 `timestamp: Date().addingTimeInterval(-29*86400)` 的记录
  2. 调用 `cleanup(olderThan: 30)`
  3. 查询该记录
- **预期结果**：
  - 该记录保留
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：边界用例

**TC-21-03：应用启动时自动触发清理**

- **前置条件**：数据库中有 31 天前的记录
- **测试步骤**：
  1. 启动 App
  2. 等待启动完成
  3. 查询数据库
- **预期结果**：
  - 31 天前的记录被删除
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：启动触发

**TC-21-04：恰好 30 天前内容被清理（边界用例）**

- **前置条件**：EncryptedStore 测试库就绪
- **测试步骤**：
  1. 插入一条 `timestamp: Date().addingTimeInterval(-30*86400)` 的记录（恰好 30 天前）
  2. 调用 `cleanup(olderThan: 30)`
  3. 查询该记录
- **预期结果**：
  - 该记录被删除
  - 验证边界条件：恰好达到 30 天阈值即触发清理
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：恰好边界用例，与 TC-21-02（29 天保留）形成对照

---

#### AC-22：敏感识别开关可关闭

**测试目标**：验证关闭敏感识别开关后，Token 等敏感内容可正常入库。

**TC-22-01：关闭敏感识别后 Token 入库**

- **前置条件**：
  - `AppSettings.sensitiveDetectionEnabled = false`
- **测试步骤**：
  1. 设置 `sensitiveDetectionEnabled = false`
  2. 输入 `sk-proj-abcdef...`
  3. 调用捕获流程
  4. 查询数据库
- **预期结果**：
  - ClipItem 入库
  - 数据库新增 1 条记录
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：开关关闭

**TC-22-02：开启敏感识别后 Token 不入库（对照）**

- **前置条件**：
  - `AppSettings.sensitiveDetectionEnabled = true`
- **测试步骤**：
  1. 设置 `sensitiveDetectionEnabled = true`
  2. 输入 `sk-proj-abcdef...`
  3. 调用捕获流程
  4. 查询数据库
- **预期结果**：
  - 数据库无新增记录
- **测试框架**：XCTest
- **覆盖状态**：❌ MISSING
- **备注**：开关开启（对照）

**TC-22-03：敏感识别开关 UI 切换**

- **前置条件**：App 已启动
- **测试步骤**：
  1. 打开设置面板
  2. 切换"敏感识别"开关为关闭
  3. 保存设置
  4. 复制 Token
  5. 查询数据库
- **预期结果**：
  - Token 入库
  - 开关状态持久化
- **测试框架**：XCUITest
- **覆盖状态**：❌ MISSING
- **备注**：UI 切换

---

### 3.7 F1.7 主界面与交互

#### AC-23：菜单栏图标常驻，点击弹出 popover

**测试目标**：验证菜单栏图标常驻显示，点击后弹出 popover 且内容完整。

**TC-23-01：菜单栏图标常驻**

- **前置条件**：
  - App 已启动
- **测试步骤**：
  1. 启动 App
  2. 观察系统菜单栏
- **预期结果**：
  - 菜单栏出现 ClipMind 图标
- **测试框架**：XCUITest
- **覆盖状态**：✅ COVERED
- **备注**：常驻验证

**TC-23-02：点击菜单栏图标弹出 popover**

- **前置条件**：
  - App 已启动
  - 菜单栏图标可见
- **测试步骤**：
  1. 点击菜单栏 ClipMind 图标
  2. 观察 popover
- **预期结果**：
  - popover 弹出
  - 显示最近 5-10 条剪贴内容
  - 包含搜索框
  - 包含"查看全部"按钮
- **测试框架**：XCUITest
- **覆盖状态**：✅ COVERED
- **备注**：popover 内容

**TC-23-03：popover 手动验证**

- **前置条件**：
  - App 已启动
  - 已有复制内容
- **测试步骤**：
  1. 点击菜单栏图标
  2. 观察 popover 内容
- **预期结果**：
  - popover 显示最近条目
  - 含类型标签 + 内容预览 + 来源 + 时间
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：UX 验证

**TC-23-04：侧边栏最小宽度为 350（F1.12 回归保护）**

- **前置条件**：
  - `LayoutConstants` 可访问
- **测试步骤**：
  1. 读取 `LayoutConstants.sidebarMinWidth`
  2. 与 350 比较
- **预期结果**：
  - `sidebarMinWidth == 350`（原值 700 过宽，导致窗口缩小时侧边栏无法收缩，搜索框和列表溢出窗口边界）
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：F1.12 bug 修复回归保护；MainWindowLayoutTests.testSidebarMinWidthIs350 覆盖

**TC-23-05：侧边栏最小宽度不超过窗口最小宽度一半（F1.12 回归保护）**

- **前置条件**：
  - `LayoutConstants` 可访问
- **测试步骤**：
  1. 计算 `LayoutConstants.mainWindowMinWidth / 2`
  2. 比较 `sidebarMinWidth` 与一半窗口宽度
- **预期结果**：
  - `sidebarMinWidth ≤ mainWindowMinWidth / 2`
  - 确保详情面板在窗口缩到最小时仍有合理空间
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：F1.12 bug 修复回归保护；MainWindowLayoutTests.testSidebarMinWidthDoesNotExceedHalfOfWindow 覆盖

**TC-23-06：窗口缩到最小时详情面板剩余空间为正（F1.12 回归保护）**

- **前置条件**：
  - `LayoutConstants` 可访问
- **测试步骤**：
  1. 计算 `mainWindowMinWidth - sidebarMinWidth`
  2. 验证结果 > 0
- **预期结果**：
  - 剩余空间 > 0
  - 详情面板在窗口缩到最小时仍可见，不被侧边栏完全挤压
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：F1.12 bug 修复回归保护；MainWindowLayoutTests.testDetailPanelHasPositiveSpaceAtWindowMinimum 覆盖

**TC-23-07：主窗口最小尺寸常量稳定（F1.12 回归保护）**

- **前置条件**：
  - `LayoutConstants` 可访问
- **测试步骤**：
  1. 读取 `LayoutConstants.mainWindowMinWidth`
  2. 读取 `LayoutConstants.mainWindowMinHeight`
  3. 分别与 980 和 500 比较
- **预期结果**：
  - `mainWindowMinWidth == 980`
  - `mainWindowMinHeight == 500`
  - 窗口最小尺寸常量保持稳定（回归保护）
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：F1.12 bug 修复回归保护；MainWindowLayoutTests.testMainWindowMinimumDimensions 覆盖

---

#### AC-24：首次启动引导流程完整

**测试目标**：验证首次启动引导流程的 5 个步骤依次出现，且 API Key 配置可跳过。

**TC-24-01：首次启动引导流程完整（UI 自动化）**

- **前置条件**：
  - UserDefaults 已清空（模拟首次启动）
- **测试步骤**：
  1. 清空 UserDefaults
  2. 启动 App
  3. 遍历引导流程
  4. 断言每个步骤页面出现
- **预期结果**：
  - 依次显示：欢迎页 → 权限请求 → API Key 配置引导 → 隐私默认值提示 → 进入主界面
- **测试框架**：XCUITest
- **覆盖状态**：❌ MISSING
- **备注**：完整流程

**TC-24-02：API Key 配置引导可跳过**

- **前置条件**：
  - UserDefaults 已清空
- **测试步骤**：
  1. 启动 App 进入引导
  2. 到达 API Key 配置步骤
  3. 点击"跳过"
  4. 观察提示
- **预期结果**：
  - 提示"分类/搜索本地可用，处理需配置"
  - 进入隐私默认值提示步骤
- **测试框架**：XCUITest
- **覆盖状态**：❌ MISSING
- **备注**：跳过路径

**TC-24-03：首次启动引导手动验证**

- **前置条件**：
  - App 偏好已删除
- **测试步骤**：
  1. 删除 App 偏好
  2. 启动 App
  3. 观察引导流程
- **预期结果**：
  - 5 个步骤依次出现
  - 权限请求正确展示
- **测试框架**：手动
- **覆盖状态**：❌ MISSING
- **备注**：真实场景验证

**TC-24-04：重置标志位后首启引导应显示**

- **前置条件**：
  - `hasCompletedOnboarding=true`（模拟已完成引导）
- **测试步骤**：
  1. 使用 `--UITEST_SHOW_MAIN_WINDOW` 设置 `hasCompletedOnboarding=true`
  2. 终止 App
  3. 使用 `--reset-onboarding` 重新启动
  4. 验证 OnboardingView 出现
- **预期结果**：
  - 显示首启引导而非主窗口
  - `startButton` 可见
- **测试框架**：XCUITest
- **覆盖状态**：✅ COVERED
- **备注**：验证 `applicationWillFinishLaunching` 中的通用重置机制

**TC-24-05：辅助功能请求触发 TCC 提示**

- **前置条件**：
  - `PermissionRequester.axTrustedCheck` 闭包可注入 mock
- **测试步骤**：
  1. 注入 mock 闭包记录 prompt 参数
  2. 调用 `PermissionRequester.requestAccessibility()`
  3. 读取 mock 记录的 prompt 值
- **预期结果**：
  - mock 闭包被调用
  - prompt 参数为 `true`（触发系统 TCC 提示对话框，自动把 ClipMind 加入辅助功能权限列表）
- **测试框架**：XCTest
- **覆盖状态**：✅ COVERED
- **备注**：覆盖 Bug 2 修复 — 点击「打开系统设置」前先调用 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`，确保系统自动弹出 TCC 提示并把当前 App 加入权限列表

**TC-24-06：点击「打开系统设置」不崩溃**

- **前置条件**：
  - App 通过 `--UITEST_RESET_ONBOARDING` 启动进入引导流程
- **测试步骤**：
  1. 启动 App 进入欢迎页
  2. 点击「开始使用」进入权限请求页
  3. 点击「打开系统设置」按钮
  4. 验证 app 状态
- **预期结果**：
  - app 不崩溃退出（state != .notRunning）
  - 回归保护：早期版本 `PermissionRequester.axTrustedCheck` 默认闭包使用 `kAXTrustedCheckOptionPrompt` 全局 CFString 常量，在 Hardened Runtime + 签名 app 上下文中该常量可能因 dyld 加载时序问题为 NULL，导致 `AXIsProcessTrustedWithOptions` 内部 `CFGetTypeID(nil)` 解引用偏移 0x8 崩溃。修复后改用字符串字面量 `"AXTrustedCheckOptionPrompt"`
- **测试框架**：XCUITest
- **覆盖状态**：✅ COVERED
- **备注**：覆盖 Bug 3 修复 — `kAXTrustedCheckOptionPrompt` 全局常量为 NULL 导致 EXC_BAD_ACCESS 崩溃，改用字符串字面量避免 dyld 加载时序依赖

---

#### AC-25：Web 交互预览页可访问且模拟核心流程

**测试目标**：验证 Web 预览页可访问，4 个核心流程可点击体验。

**TC-25-01：Web 预览页可访问（curl）**

- **前置条件**：
  - Web 页已部署到 GitHub Pages
  - URL: `https://marcocpt.github.io/ClipMind/`
- **测试步骤**：
  1. 执行 `curl -I https://marcocpt.github.io/ClipMind/`
  2. 检查 HTTP 状态码
- **预期结果**：
  - 返回 HTTP 200
- **测试框架**：curl
- **覆盖状态**：⏸️ DEFERRED
- **备注**：可访问性，URL 在 Phase 4 部署时确定实际用户名

**TC-25-02：Web 预览页 4 个交互流程可点击**

- **前置条件**：
  - 浏览器已打开 Web 预览页 URL
- **测试步骤**：
  1. 浏览器打开 Web URL
  2. 点击"复制演示内容"按钮
  3. 点击"自动分类"按钮
  4. 点击"搜索"按钮
  5. 点击"一键处理"按钮
  6. 观察响应
- **预期结果**：
  - 4 个核心流程按钮均可点击
  - 每个按钮有交互响应
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：交互验证

**TC-25-03：Web 预览页内容完整**

- **前置条件**：
  - 浏览器已打开 Web URL
- **测试步骤**：
  1. 浏览器打开 Web URL
  2. 检查页面内容
- **预期结果**：
  - 包含产品介绍
  - 包含交互式模拟
  - 4 个核心流程可体验
- **测试框架**：手动
- **覆盖状态**：⏸️ DEFERRED
- **备注**：内容完整性

---

## 4. 测试数据集准备

### 4.1 分类测试集

| 属性 | 值 |
|------|------|
| 文件路径 | `ClipMindTests/Fixtures/classification_samples.json` |
| 数量 | 220 条 |
| 组成 | 11 种入库类型 × 20 条 |
| 创建时机 | Phase 1 开始前 |
| 标注方式 | 人工标注正确类型（ContentType） |
| 质量保证 | 双人交叉抽查 10% 样本，分歧协商解决 |

**11 种入库类型样本分布**：

| 类型 | 标识 | 样本数 | 示例特征 |
|------|------|--------|---------|
| 代码 | code | 20 | 函数定义、语法关键字、代码缩进 |
| 链接 | link | 20 | URL 格式（http/https/www） |
| 报错 | error | 20 | "error"/"exception"/"fatal"/"traceback" |
| 文章 | article | 20 | 长文本（>200字）、段落结构 |
| 待办清单 | todo | 20 | "TODO"/"待办"/"- [ ]"/checkbox |
| 会议纪要 | meeting | 20 | "会议"/"参会"/"议题"/时间地点人物 |
| 翻译素材 | translation | 20 | 外文（英文/日文/韩文）且非代码非报错 |
| 产品需求 | requirement | 20 | "需求"/"功能"/"用户故事"/"PRD" |
| API 文档 | api_doc | 20 | "API"/"接口"/"请求"/"响应"/JSON |
| 英文资料 | english_doc | 20 | 纯英文长文本、非代码、非报错 |
| 其他 | other | 20 | 不匹配以上任何类型 |

**JSON 格式示例**：

```json
{
  "samples": [
    {
      "content": "func viewDidLoad() { super.viewDidLoad() }",
      "expected_type": "code",
      "language": "swift"
    },
    {
      "content": "Thread 1: Fatal error: Unexpectedly found nil",
      "expected_type": "error"
    },
    {
      "content": "https://developer.apple.com/documentation/swiftui",
      "expected_type": "link"
    }
  ]
}
```

### 4.2 敏感内容样本

| 属性 | 值 |
|------|------|
| 文件路径 | `ClipMindTests/Fixtures/sensitive_samples.json` |
| 数量 | 20 条 |
| 组成 | 6 种模式 + 边界用例 |
| 创建时机 | Phase 1 开始前 |
| 标注方式 | 人工标注敏感类型 |
| 质量保证 | 覆盖正则边界用例 |

**6 种敏感模式分布**：

| 模式 | 正则 | 样本数 | 示例 |
|------|------|--------|------|
| 密码模式 | `password\s*[=:]\s*\S+` | 4 | `password=abc123` |
| Token 格式 | `^(sk-\|ghp_\|gho_\|Bearer\s)` + 32+ 位 | 4 | `sk-proj-abc123...` |
| 验证码 | `^\d{4,8}$` | 3 | `123456` |
| 银行卡号 | `^\d{16,19}$` + Luhn | 3 | `6225880123456789` |
| 身份证号 | `^\d{17}[\dXx]$` + 校验 | 3 | `110101199001011234` |
| 敏感关键词 | 包含 `password\|secret\|api_key\|access_token\|private_key` | 3 | `api_key=xxx` |

> 说明：敏感内容样本由 AC-08 的 `SensitiveDetector` 单独测试覆盖，不进入 `classify()` 管线。

### 4.3 搜索测试集

| 属性 | 值 |
|------|------|
| 文件路径 | `ClipMindTests/Fixtures/search_queries.json` |
| 数量 | 50 个查询 |
| 创建时机 | Phase 1 开始前 |
| 标注方式 | 人工标注期望返回的 Top-5 条目 |
| 质量保证 | 双人交叉抽查 10% 查询，验证标注一致性 |

**JSON 格式示例**：

```json
{
  "queries": [
    {
      "query": "窗口管理报错",
      "expected_ids": ["clip-001", "clip-042"],
      "description": "应匹配 NSWindowController 崩溃日志"
    },
    {
      "query": "上次那个接口文档",
      "expected_ids": ["clip-010"],
      "description": "应匹配 API 文档条目"
    }
  ]
}
```

**查询分布**：

| 查询类型 | 数量 | 示例 |
|---------|------|------|
| 中文查询匹配中文内容 | 15 | "窗口管理报错" |
| 中文查询匹配英文内容 | 10 | "窗口控制器崩溃" → 英文条目 |
| 英文查询匹配中文内容 | 10 | "state management" → 中文条目 |
| 自然语言描述 | 10 | "上次那个接口文档" |
| 来源 App 过滤 | 5 | "Xcode 来源的代码" |

### 4.4 LLM mock 响应

| 属性 | 值 |
|------|------|
| 文件路径 | `ClipMindTests/Fixtures/llm_mock_responses.json` |
| 数量 | 4 种处理 × 3 条正常响应 + 4 种错误响应 = 16 条 |
| 创建时机 | Phase 2 开始前 |
| 标注方式 | 人工编写预期响应 |
| 质量保证 | 与 AC 预期输出格式一致 |

**正常响应分布**：

| 处理类型 | 数量 | 输出格式要求 |
|---------|------|------------|
| 智能总结 | 3 | 3-5 句核心要点，按句号分割 |
| 即时翻译 | 3 | 中英对照 + 技术术语保留原文 |
| 智能改写 | 3 | 三种模式（adjustTone/condense/expand）各 1 条 |
| 提取待办 | 3 | 结构化 JSON：task + assignee + dueDate |

**错误响应分布（用于 AC-13~AC-16 错误路径测试）**：

| 错误类型 | 对应 AC | 数量 | mock 配置 | 预期错误 |
|---------|---------|------|----------|---------|
| HTTP 500 服务器错误 | AC-13（TC-13-04） | 1 | `summarizeReturnError = LLMError.serverError(500)` | 抛出 serverError，本地功能不受影响 |
| 请求超时 | AC-14（TC-14-04） | 1 | `translateReturnError = LLMError.timeout` | 抛出 timeout，本地功能不受影响 |
| HTTP 429 限流 | AC-15（TC-15-04） | 1 | `rewriteReturnError = LLMError.rateLimited(retryAfter: 60)` | 抛出 rateLimited，本地功能不受影响 |
| 响应解析失败 | AC-16（TC-16-04） | 1 | `extractTodosReturnRaw = "非 JSON 字符串"` | 抛出 parseError，本地功能不受影响 |

**JSON 格式示例**：

```json
{
  "responses": {
    "summarize": [
      {
        "input": "长文本内容...",
        "output": "核心要点第一句。核心要点第二句。核心要点第三句。"
      }
    ],
    "translate": [
      {
        "input": "The NSWindowController manages window lifecycle",
        "output": "原文：The NSWindowController manages window lifecycle\n译文：NSWindowController 负责管理窗口生命周期"
      }
    ],
    "rewrite": [
      {
        "mode": "condense",
        "input": "原始文本内容...",
        "output": "精简后的文本。"
      }
    ],
    "extract_todo": [
      {
        "input": "张三负责登录模块 06.25 前完成",
        "output": [
          {"task": "登录模块完成", "assignee": "张三", "dueDate": "06.25"}
        ]
      }
    ]
  }
}
```

---

## 5. 测试执行计划

### 5.1 Phase 0：基础设施

**目标**：搭建可运行的 .app 骨架，实现剪贴板监听 + 本地加密存储 + 菜单栏 UI 骨架。

**测试范围**：

| AC 编号 | 用例编号 | 测试框架 | 验证内容 |
|---------|---------|---------|---------|
| AC-01 | TC-01-01, TC-01-02, TC-01-03 | XCUITest + 手动 | 文本捕获 + popover/主窗口同步 |
| AC-04 | TC-04-01 | XCTest | 去重逻辑 |
| AC-18 | TC-18-01, TC-18-02, TC-18-03 | XCTest + 手动 | AES-256 加密验证 |
| AC-23（部分） | TC-23-01, TC-23-02 | XCUITest | 菜单栏图标 + popover 骨架 |

**完成标志**：
- 单元测试通过（PasteboardWatcher + EncryptedStore）
- 复制文本后 popover 显示（无分类标签）
- 数据库加密存储可读写
- 数据库文件无法直接读取

---

### 5.2 Phase 1：核心 AI

**目标**：实现 11 种入库类型自动分类 + 敏感内容识别 + 自然语言语义搜索。

**测试范围**：

| AC 编号 | 用例编号 | 测试框架 | 验证内容 |
|---------|---------|---------|---------|
| AC-05 | TC-05-01 | XCTest | 11 种入库类型准确率 ≥ 80% |
| AC-06 | TC-06-01, TC-06-02 | XCTest | 代码片段识别为 code |
| AC-07 | TC-07-01, TC-07-02 | XCTest | 报错日志识别为 error |
| AC-09 | TC-09-01 | XCTest | 搜索响应 < 500ms |
| AC-10 | TC-10-01 | XCTest | Top-5 命中率 ≥ 70% |
| AC-11 | TC-11-01, TC-11-02 | XCTest | 跨语言搜索 |
| AC-12 | TC-12-01, TC-12-02 | XCTest + XCUITest | 来源 App 过滤 |

**测试数据集准备**：
- 分类测试集（220 条）— Phase 1 开始前完成
- 敏感内容样本（20 条）— Phase 1 开始前完成
- 搜索测试集（50 个查询）— Phase 1 开始前完成

**完成标志**：
- 11 种入库类型分类准确率 ≥ 80%（220 条测试集验证）
- 搜索响应 < 500ms（1000 条数据测试）
- 跨语言搜索可用
- 分类标签在 UI 正确显示

---

### 5.3 Phase 2：一键处理

**目标**：实现智能总结/即时翻译/智能改写/提取待办 + API Key 多提供商配置。

**测试范围**：

| AC 编号 | 用例编号 | 测试框架 | 验证内容 |
|---------|---------|---------|---------|
| AC-13 | TC-13-01, TC-13-02, TC-13-03, TC-13-04 | XCTest（mock）+ 手动 | 智能总结 3-5 句 + 错误路径 |
| AC-14 | TC-14-01, TC-14-02, TC-14-03, TC-14-04 | XCTest（mock）+ 手动 | 即时翻译 + 术语保留 + 超时处理 |
| AC-15 | TC-15-01, TC-15-02, TC-15-03, TC-15-04 | XCTest（mock）+ 手动 | 智能改写 3 模式 + 限流处理 |
| AC-16 | TC-16-01, TC-16-02, TC-16-03, TC-16-04 | XCTest（mock）+ 手动 | 提取待办结构化 + 解析失败处理 |
| AC-17 | TC-17-01, TC-17-02, TC-17-03 | XCUITest + 手动 | 未配置 Key 置灰 |

**测试数据集准备**：
- LLM mock 响应（16 条，含 4 条错误响应）— Phase 2 开始前完成

**完成标志**：
- 4 种处理在配置 API Key 后可用
- 未配置时按钮置灰并提示
- API Key 加密存储到 Keychain
- LLM API 错误不阻塞本地功能

---

### 5.4 Phase 3：隐私与设置

**目标**：实现敏感识别 + 应用黑名单 + 自动清理 + 完整设置面板 + 首次启动引导。

**测试范围**：

| AC 编号 | 用例编号 | 测试框架 | 验证内容 |
|---------|---------|---------|---------|
| AC-08 | TC-08-01 ~ TC-08-07 | XCTest + 手动 | 敏感内容识别 + 不入库 + 通知 |
| AC-20 | TC-20-01, TC-20-02, TC-20-03 | XCTest | 黑名单忽略 |
| AC-21 | TC-21-01, TC-21-02, TC-21-03, TC-21-04 | XCTest | 30 天清理 + 边界（29/30/31 天）+ 启动触发 |
| AC-22 | TC-22-01, TC-22-02, TC-22-03 | XCTest + XCUITest | 敏感识别开关 |
| AC-23 | TC-23-03 | 手动 | popover 完整内容 |
| AC-24 | TC-24-01, TC-24-02, TC-24-03, TC-24-04 | XCUITest + 手动 | 首启引导完整流程 |

**完成标志**：
- 敏感内容自动识别并忽略（6 种模式）
- 应用黑名单生效（默认 5 个 App）
- 30 天前内容自动清理
- 设置面板完整可用
- 首次启动引导流程完整

---

### 5.5 Phase 4：Web + Demo 帖

**目标**：完成 Web 交互预览页 + Demo 作品帖 + 截图 + Session ID，提交初赛。

**测试范围**：

| AC 编号 | 用例编号 | 测试框架 | 验证内容 |
|---------|---------|---------|---------|
| AC-25 | TC-25-01, TC-25-02, TC-25-03 | curl + 手动 | Web 预览页可访问 + 交互 |

**完成标志**：
- Web 页面部署到 GitHub Pages，可公开访问
- 4 个核心流程可点击体验
- Demo 作品帖发布到初赛专区
- 截图 ≥ 3 张、Session ID ≥ 3 个
- .app 可下载体验

---

## 6. 覆盖度统计

### 6.1 总体统计

| 指标 | 数值 |
|------|------|
| AC 总数 | 26 |
| 测试用例总数 | 88 |
| 平均每 AC 用例数 | 3.38 |
| AC 覆盖率 | 100%（26/26） |

### 6.2 按 AC 覆盖率

> **说明**：覆盖状态汇总各 AC 下全部 TC 的分布，✅=COVERED、🟡=PARTIAL、❌=MISSING、⏸️=DEFERRED。

| AC 编号 | 用例数 | 覆盖状态分布 |
|---------|--------|-------------|
| AC-01 | 3 | ✅1 🟡1 ⏸️1 |
| AC-02 | 2 | ✅1 ⏸️1 |
| AC-03 | 2 | ✅1 ⏸️1 |
| AC-04 | 1 | ✅1 |
| AC-05 | 1 | 🟡1 |
| AC-06 | 2 | ✅2 |
| AC-07 | 2 | ✅2 |
| AC-08 | 7 | ❌7 |
| AC-09 | 1 | 🟡1 |
| AC-10 | 1 | 🟡1 |
| AC-11 | 2 | ✅2 |
| AC-12 | 2 | ✅2 |
| AC-13 | 4 | ✅2 🟡1 ⏸️1 |
| AC-14 | 4 | ✅2 🟡1 ⏸️1 |
| AC-15 | 4 | ✅3 ⏸️1 |
| AC-16 | 4 | ✅2 🟡1 ⏸️1 |
| AC-17 | 3 | ✅1 🟡1 ⏸️1 |
| AC-18 | 3 | ✅1 ⏸️2 |
| AC-19 | 2 | ✅1 ⏸️1 |
| AC-20 | 3 | ❌3 |
| AC-21 | 4 | ✅2 ❌2 |
| AC-22 | 3 | ❌3 |
| AC-23 | 7 | ✅6 ⏸️1 |
| AC-24 | 5 | ✅4 ❌1 |
| AC-25 | 3 | ⏸️3 |
| AC-26 | 13 | ✅13 |

### 6.3 按测试框架分布

| 测试框架 | 用例数 | 占比 |
|---------|--------|------|
| XCTest | 59 | 67.05% |
| XCUITest | 12 | 14.29% |
| 手动 | 16 | 19.28% |
| curl | 1 | 1.21% |
| **合计** | **88** | **100%** |

**说明**：部分用例同时涉及 XCTest（mock）与手动（真实 API），统计时按主框架归类。

### 6.4 按覆盖状态分布

| 覆盖状态 | 用例数 | 占比 |
|---------|--------|------|
| ✅ COVERED | 49 | 55.68% |
| 🟡 PARTIAL | 8 | 9.64% |
| ❌ MISSING | 18 | 21.69% |
| ⏸️ DEFERRED | 13 | 15.66% |
| **合计** | **88** | **100%** |

> **当前状态**：Phase 4（Web + Demo 帖）已完成。46 条用例通过 XCTest/XCUITest 自动化覆盖；8 条因数据集缩减或仅 UI 路径覆盖标注为 PARTIAL；13 条真实 API 集成与截图/录屏手动验证用例延后（TC-25-01 curl 验证需合并到 main 后执行）；18 条依赖 Phase 3 任务（SensitiveDetector / BlacklistService / CleanupService / 首启引导）尚未实现，标注为 MISSING。Phase 4 的 TC-25-02/03 已通过 browser_use 子代理验证并更新为 ✅ COVERED。TC-26-01 ~ TC-26-13（全局快捷键唤醒主窗口）已通过 XCTest 自动化覆盖。TC-24-05（辅助功能请求触发 TCC 提示）已通过 XCTest 自动化覆盖。TC-24-06（点击「打开系统设置」不崩溃）已通过 XCUITest 自动化覆盖，回归保护 `kAXTrustedCheckOptionPrompt` 全局常量为 NULL 导致的 EXC_BAD_ACCESS 崩溃。TC-23-04 ~ TC-23-07（主窗口布局常量回归保护）已通过 XCTest 自动化覆盖，回归保护 F1.12 bug 修复（导航栏最小宽度从 700 调整为 350，解决窗口缩小时搜索框和列表溢出问题）。

### 6.5 按模块分布

| 模块 | AC 数 | 用例数 | XCTest | XCUITest | 手动 | curl |
|------|-------|--------|--------|----------|------|------|
| F1.1 剪贴板监听与捕获 | 4 | 8 | 3 | 2 | 3 | 0 |
| F1.2 自动分类 | 4 | 12 | 11 | 0 | 1 | 0 |
| F1.3 自然语言语义搜索 | 4 | 6 | 5 | 1 | 0 | 0 |
| F1.4 一键处理 | 5 | 19 | 11 | 3 | 5 | 0 |
| F1.5 本地加密存储 | 2 | 5 | 2 | 0 | 3 | 0 |
| F1.6 隐私保护 | 3 | 10 | 9 | 1 | 0 | 0 |
| F1.7 主界面与交互 | 4 | 28 | 18 | 5 | 4 | 1 |
| **合计** | **26** | **88** | **59** | **12** | **16** | **1** |

> **说明**：每条用例按"主测试框架"归类一次，无双重计数。F1.2 中 TC-08-07（复制 Token 弹通知）归类为手动；F1.4 新增 4 条 LLM API 错误路径用例（TC-13-04/14-04/15-04/16-04）归类为 XCTest；F1.6 新增 TC-21-04（恰好 30 天边界）归类为 XCTest；F1.7 新增 13 条全局快捷键用例（TC-26-01 ~ TC-26-13）归类为 XCTest；F1.7 新增 TC-24-05（辅助功能请求触发 TCC 提示，PermissionRequesterTests）归类为 XCTest；F1.7 新增 TC-24-06（点击「打开系统设置」不崩溃，PermissionRequestUITests）归类为 XCUITest。 F1.7 新增 4 条主窗口布局常量回归保护用例（TC-23-04 ~ TC-23-07，MainWindowLayoutTests）归类为 XCTest，对应 F1.12 bug 修复（导航栏最小宽度 700→350）。

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-12 | 初始版本，基于设计规范 v1.3，覆盖 25 条 AC，共 63 个测试用例 |
| v1.1 | 2026-07-12 | 修复 6.1~6.5 节统计错误（原 63 条实际为 64 条）；补充 AC-13~AC-16 LLM API 错误路径测试各 1 条（共 4 条）；补充 AC-21 恰好 30 天边界用例（TC-21-04）；同步 4.4 LLM mock 响应数据集（新增 4 条错误响应）；统计总数 69 条；解决 6.3 与 6.5 节 XCTest 数量矛盾；删除 6.5 节 TC-08-07 双重计数的过时备注 |
| v1.2 | 2026-07-13 | Phase 2（F1.4 一键处理）完成后根据实际测试代码逐项核对覆盖状态：第 2 节总表与第 3 节详情的 69 条用例覆盖状态全部更新（✅ COVERED 28 / 🟡 PARTIAL 8 / ❌ MISSING 18 / ⏸️ DEFERRED 15）；1.2 节当前状态说明更新；1.4 节测试组织结构树同步为实际目录结构（含 Capture/ClassifyTests/SearchTests/LLMTests/Storage/ML/Models/Utils/Fixtures/Helpers）；6.2 节改为按 AC 汇总覆盖状态分布；6.4 节统计从 0/0/69/0 更新为 28/8/18/15；备注列补充具体测试方法名或延后理由便于追溯 |
| v1.3 | 2026-07-13 | 剪贴板捕获管线接线修复后同步：TC-01-01/TC-01-02/TC-04-01 备注列补充 ClipCaptureServiceTests 测试方法名；1.4 节测试组织结构树补充 ClipCaptureServiceTests.swift；统计数字不变 |
| v1.4 | 2026-07-14 | 同步快捷键唤醒修复（基于设计规范 v1.6）：新增 AC-26 全局快捷键唤醒主窗口，新增 13 条 XCTest 测试用例（TC-26-01 ~ TC-26-13，覆盖 HotkeyFormatter.parse(stored:) 解析与 GlobalHotkeyService 注册/注销/触发）；1.1 节 F1.7 AC 数量 3→4、合计 25→26；1.4 节测试组织结构树补充 App/GlobalHotkeyServiceTests.swift；6.1 节总数 69→82、AC 覆盖率 26/26；6.3 节 XCTest 41→54；6.4 节 ✅ COVERED 30→43；6.5 节 F1.7 用例数 9→22、XCTest 0→13 |
| v1.5 | 2026-07-14 | 同步权限图标/TCC/AppIcon 修复（基于设计规范 v1.7）：新增 TC-24-05 辅助功能请求触发 TCC 提示（PermissionRequesterTests.testRequestAccessibilityPassesPromptTrue，验证 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` 调用时 prompt 参数为 true）；6.1 节总数 82→83、平均每 AC 用例数 3.15→3.19；6.2 节 AC-24 用例数 3→4（✅3 ❌1）；6.3 节 XCTest 54→55（占比 65.85%→66.27%）、合计 82→83；6.4 节 ✅ COVERED 43→44（占比 52.44%→53.01%）、合计 82→83；6.5 节 F1.7 用例数 22→23、XCTest 13→14、合计 82→83 |
| v1.6 | 2026-07-14 | 同步权限请求 EXC_BAD_ACCESS 崩溃修复（基于设计规范 v1.7）：新增 TC-24-06 点击「打开系统设置」不崩溃（PermissionRequestUITests.testOpenAccessibilitySettingsDoesNotCrashApp，XCUITest 验证点击按钮后 app 不崩溃退出，回归保护 `kAXTrustedCheckOptionPrompt` 全局常量为 NULL 导致的 EXC_BAD_ACCESS 崩溃）；6.1 节总数 83→84、平均每 AC 用例数 3.19→3.23；6.2 节 AC-24 用例数 4→5（✅4 ❌1）；6.3 节 XCUITest 11→12（占比 13.25%→14.29%）、合计 83→84；6.4 节 ✅ COVERED 44→45（占比 53.01%→53.57%）、合计 83→84；6.5 节 F1.7 用例数 23→24、XCUITest 4→5、合计 83→84 |
| v1.7 | 2026-07-14 | 同步 F1.12 导航栏宽度溢出修复（基于设计规范 v1.7）：新增 TC-23-04 ~ TC-23-07 主窗口布局常量回归保护用例 4 条（MainWindowLayoutTests.testSidebarMinWidthIs350 / testSidebarMinWidthDoesNotExceedHalfOfWindow / testDetailPanelHasPositiveSpaceAtWindowMinimum / testMainWindowMinimumDimensions，验证 sidebarMinWidth=350 / mainWindowMinWidth=980 / mainWindowMinHeight=500，回归保护导航栏最小宽度从 700 调整为 350 解决窗口缩小时搜索框和列表溢出问题）；1.4 节测试组织结构树补充 UI/MainWindowLayoutTests.swift；6.1 节总数 84→88、平均每 AC 用例数 3.23→3.38；6.2 节 AC-23 用例数 3→7（✅2 ⏸️1 → ✅6 ⏸️1）；6.3 节 XCTest 55→59（占比 66.27%→67.05%）、合计 84→88；6.4 节 ✅ COVERED 45→49（占比 53.57%→55.68%）、合计 83→88（修正原合计数据错误）；6.5 节 F1.7 用例数 24→28、XCTest 14→18、合计 84→88 |
