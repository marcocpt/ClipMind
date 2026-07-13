# Trae 使用：macOS XCTest 测试与回归规范

**版本**：v3.1 Trae 友好版  
**适用基线**：macOS App、Xcode 15+、XCTest、Swift 5.7+ 代码库  
**适用工具**：Trae Project Rules、Agent Rules、Chat Prompt  
**更新日期**：2026-07-14  
**目标**：让 AI 生成的测试稳定、快速、可读、可维护，并能针对代码变更准确补充回归保护。

---

## 0. 在 Trae 中如何使用

不要把整份长规范复制到每次聊天中。推荐分三层使用：

| 层级 | 放置位置 | 使用内容 | 作用 |
|---|---|---|---|
| Project Rules | Trae 项目规则 | 第 1 节短规则 | 每次修改代码时默认遵守 |
| Agent Rules | 测试 Agent 规则 | 第 2 节工作流 | 约束 AI 先分析、再设计、再实现 |
| Chat Prompt | 当前任务 | 第 15 节模板 | 提供当前代码、需求和边界 |

建议把本文保存到项目中：

```text
docs/AI/trae-xctest-rules.md
```

任务中显式要求：

```text
请先阅读 docs/AI/trae-xctest-rules.md，并严格遵守其中的测试和回归规则。
```

---

## 1. 可直接粘贴到 Trae Project Rules 的短规则

```markdown
# macOS XCTest 与回归测试规则

本项目使用 macOS + Xcode 15+ + XCTest。AI 生成、修改或审查测试时必须遵守：

1. 使用 XCTest，不使用 Swift Testing；不得生成 `@Test`、`#expect`、`#require`、`confirmation`、`tags`。
2. 测试行为，不测试实现；优先验证公开可观察结果，不直接测试私有方法、私有属性或内部调用路径。
3. 每个测试只验证一个核心行为；允许多个断言，但必须服务于同一个行为。
4. 测试名称使用 `test_入口点_场景_期望行为`。
5. 每个测试使用 AAA：Arrange / Act / Assert，并只保留一个主要 Act。
6. 不访问真实网络、真实当前时间、真实随机数、真实 UUID、生产数据库、生产用户目录或真实外部服务。
7. 不使用 `sleep`、`usleep`、`Thread.sleep`、`DispatchQueue.asyncAfter` 等固定等待测试异步行为。
8. Swift 并发优先使用 `async/await`；回调、delegate、Notification、Combine 使用 `XCTestExpectation`。
9. 可选值使用 `XCTUnwrap`，不强制解包；浮点比较必须指定 `accuracy`。
10. 错误测试必须验证具体错误类型或错误值。
11. 只在外部交互本身是业务行为时使用 Mock；普通输入依赖优先使用 Stub。
12. 测试替身必须小而明确，不模拟完整系统，不在 Mock 中写业务逻辑。
13. 不为覆盖率生成没有断言、只执行代码或无法证明业务行为的测试。
14. 如生产代码难以测试，先说明最小重构点，不直接大改生产代码。
15. 输出测试代码前，先给出测试目标、用例表、依赖处理和 Stub/Mock 选择。
16. 每次修改生产代码后，必须分析直接和间接影响的已有行为，不能只测试新增功能。
17. 修复可复现 Bug 时，优先先写一个能够复现该 Bug 的失败回归测试，再修改生产代码。
18. 不得仅根据修改文件列表决定回归范围；必须结合调用关系、数据流、共享模型、配置、持久化格式和用户流程判断。
19. 不得为了让测试通过而随意修改旧测试预期；必须先确认需求是否真的改变。
20. 每次修改完成后，必须列出：新增测试、更新测试、应执行的测试集合、暂缓自动化的场景及原因。
```

---

## 2. Trae Agent Rules：测试生成与回归工作流

```markdown
# XCTest Test Agent Workflow

你是 macOS XCTest 测试与回归分析 Agent。收到任务后按以下步骤工作：

## Step 1：识别变更
输出：
- 本次新增或修改的行为
- 直接修改的文件和符号
- 直接调用方与被调用方
- 共享模型、协议、配置、持久化格式
- 可能受影响的用户流程

## Step 2：识别测试目标
输出：
- 被测入口点
- 被测场景
- 可观察出口点
- 不可控依赖
- 推荐测试层级
- 是否需要 Stub / Mock / Spy

## Step 3：确定回归范围
输出：
- 必须新增的测试
- 必须更新的测试
- 必须执行的已有测试
- 可暂缓自动化的场景及原因
- 是否需要调整 CI 测试集合

## Step 4：设计测试用例表
使用表格：
| 用例 | 场景 | 输入 | 替身 | 期望 | 类型 |

类型可选：新功能测试、Bug 回归测试、兼容性测试、迁移测试、冒烟测试、已有回归测试。

## Step 5：生成 XCTest 代码
要求：
- 测试类继承 XCTestCase
- 命名使用 `test_入口点_场景_期望行为`
- 使用 AAA
- 不使用 Swift Testing
- 不访问真实外部依赖
- 不使用 sleep
- 不直接测试私有方法
- 每个测试只验证一个核心行为

## Step 6：验证
如可运行测试，先运行最小相关测试集合，再运行受影响测试集合。
不得声称测试通过，除非实际执行成功。

## Step 7：自检
回答：
- 测试失败时是否说明生产行为有问题？
- 是否存在网络、时间、随机数、顺序或本机环境依赖？
- 是否绑定内部实现？
- 是否过度 Mock？
- 是否遗漏受影响的旧行为？
- 是否错误修改了旧测试预期？
- 是否适合进入 CI？
```

---

## 3. 核心测试原则

### 3.1 测试行为，不测试实现

验证用户或外部系统能够观察到的结果：

- 返回值
- 具体错误
- 公开状态变化
- 发布事件
- 持久化结果
- UI 可见状态
- 必要的外部交互

不要验证：

- 私有方法是否调用
- 内部 helper 调用次数
- 算法中间步骤
- 无业务价值的调用顺序
- 私有属性状态

### 3.2 每个测试只验证一个核心行为

一个测试可以有多个断言，但这些断言必须描述同一个行为。

### 3.3 测试必须可重复

必须隔离：

- 当前时间
- 随机数和 UUID
- 网络
- 文件系统
- 数据库
- UserDefaults、Keychain
- NotificationCenter
- 系统权限
- Pasteboard
- AppKit 窗口环境
- 真实外部服务

### 3.4 测试代码不复制生产逻辑

测试应使用明确预期值，不要在测试中重新实现一遍生产算法。

---

## 4. 什么时候新增或更新回归测试

回归测试用于确认已有行为没有因为代码、配置、依赖或运行环境变化而被破坏。

回归测试不等于每次新增大量测试，也不等于每次都执行所有测试。应依据**变更影响和业务风险**，决定新增、更新和执行哪些测试。

### 4.1 新增或修改业务行为

当需求或代码发生变化时，必须：

1. 为新增行为添加测试。
2. 更新需求已经明确改变的行为测试。
3. 分析受影响的已有行为。
4. 为缺少保护的高风险路径补充回归测试。

影响范围不能只根据修改文件判断，还应检查：

- 调用方和被调用方
- 公共协议和数据模型
- 状态机和业务规则
- 文件格式和持久化结构
- 错误映射和异常路径
- UI 状态和用户流程
- 模块接口契约
- Feature Flag 和默认配置

不得为了让测试通过而直接修改旧测试预期。必须先确认：

- 是需求真的发生变化；还是
- 生产代码意外破坏了旧行为。

### 4.2 修复 Bug

每个可稳定复现的 Bug，修复前应优先增加一个能够复现问题的失败测试。

推荐流程：

1. 编写能够复现 Bug 的测试。
2. 运行并确认测试因该 Bug 失败。
3. 修改最少的生产代码修复问题。
4. 运行新测试并确认通过。
5. 运行受影响的回归测试，确认没有破坏其他行为。

Bug 回归测试必须验证对外可观察行为，不得只锁定内部实现。

若 Bug 只能在系统集成、特定权限、真实窗口或 UI 环境中复现，应使用相应的组件测试、集成测试或 UI 测试，不要为了强行单元测试而过度改造代码。

### 4.3 配置、依赖或运行环境变化

即使业务代码未修改，出现以下变化时也必须做影响分析：

- 数据库或数据格式升级
- macOS 版本兼容性变化
- 第三方 SDK 或依赖版本升级
- 编译器或 Xcode 版本变化
- 权限、签名、沙盒配置变化
- 网络协议或服务端接口变化
- Feature Flag 或默认配置变化

通常优先补充或执行：

- 核心读写冒烟测试
- 数据迁移测试
- 接口契约测试
- 关键集成测试
- 核心用户路径 UI 测试

---

## 5. 什么时候值得自动化

满足以下任一条件时，应优先考虑自动化：

- 属于高风险或核心业务流程。
- 失败会造成数据损坏、用户无法使用、隐私安全问题或严重投诉。
- 每次发布都需要重复验证。
- 需要在多个环境或配置下重复验证。
- 手工执行耗时长、步骤复杂或容易遗漏。
- 测试数据准备复杂，但能够稳定脚本化。
- 曾发生过缺陷，存在再次出现的风险。
- 自动化结果有稳定、明确、可机器判断的出口点。

"手工执行超过 3 次"可以作为提醒，但不能作为唯一判断标准。应综合判断：

```text
自动化价值
= 执行频率
× 业务风险
× 手工成本
× 可重复性
- 编写成本
- 维护成本
- 不稳定成本
```

不要求计算精确数值，但 AI 必须说明自动化建议的理由。

### 5.1 可以暂缓自动化

以下场景可以暂缓自动化，但仍需人工验证：

- 一次性、低风险、即将下线的功能。
- 需求和交互仍处于快速探索阶段。
- 自动化无法稳定判断结果。
- 测试环境暂时无法隔离。
- 自动化维护成本明显高于风险收益。
- 视觉细节频繁变化且不影响核心业务行为。

"暂缓自动化"不等于"不测试"。

UI 频繁变化的核心流程仍应自动化稳定的业务入口和结果；避免验证颜色、字体、坐标和内部控件层级。

---

## 6. 变更影响分析规范

每次生产代码变更后，AI 必须输出：

| 分析项 | 内容 |
|---|---|
| 直接修改行为 | 本次明确新增或修改的行为 |
| 直接依赖 | 调用修改代码或被修改代码调用的模块 |
| 间接依赖 | 共享模型、协议、存储、状态、配置或格式的模块 |
| 高风险路径 | 文件、数据、权限、同步、迁移等关键路径 |
| 必须新增的测试 | 当前缺少保护的新行为或 Bug |
| 必须更新的测试 | 需求已经明确改变的旧行为 |
| 必须执行的测试 | 与影响范围相关的已有测试集合 |
| 可暂缓自动化 | 低风险或维护收益较低的场景及原因 |

禁止只根据 Git 修改文件列表决定回归范围。必须结合：

- 调用关系
- 数据流
- 状态变化
- 共享协议与模型
- 配置与持久化格式
- 用户流程

---

## 7. 测试层级选择

优先选择最低且足够可信的测试层级：

1. 单元测试
2. 组件测试
3. 集成测试
4. UI 测试

| 场景 | 推荐测试层级 |
|---|---|
| 纯业务规则、解析、校验 | 单元测试 |
| ViewModel 状态变化 | 单元测试 |
| 文件、数据库、模块协作 | 组件或集成测试 |
| 数据迁移和接口契约 | 集成测试 |
| 关键用户路径 | UI 测试 |
| 大文件解析、批处理 | 性能测试 |

能用低层级稳定验证的，不升级为 UI 测试。

---

## 8. 测试命名与结构

统一命名：

```swift
func test_入口点_场景_期望行为()
```

推荐：

```swift
func test_classify_whenContentIsCode_returnsCodeType()
func test_search_whenQueryIsEmpty_returnsEmptyResults()
func test_store_whenEncryptionFails_throwsStorageError()
```

禁止：

```swift
func testSuccess()
func testFailure()
func testExample()
func test_bug123()
```

每个测试使用 AAA：

```swift
func test_classify_whenContentIsCode_returnsCodeType()
{
    // Arrange
    let service = ClassificationServiceStub(result: .success(.code))
    let classifier = Classifier(service: service)

    // Act
    let result = classifier.classify("print('hello')")

    // Assert
    XCTAssertEqual(result, .code)
}
```

---

## 9. XCTest 断言规范

| 场景 | 推荐断言 | 避免 |
|---|---|---|
| 相等 | `XCTAssertEqual(a, b)` | `XCTAssertTrue(a == b)` |
| 不相等 | `XCTAssertNotEqual(a, b)` | `XCTAssertTrue(a != b)` |
| 布尔真 | `XCTAssertTrue(value)` | `XCTAssertEqual(value, true)` |
| 布尔假 | `XCTAssertFalse(value)` | `XCTAssertEqual(value, false)` |
| nil | `XCTAssertNil(value)` | `value == nil` |
| 非 nil | `XCTUnwrap(value)` | `value!` |
| 抛错 | `XCTAssertThrowsError` | `try?` |
| 浮点 | `XCTAssertEqual(a, b, accuracy:)` | 直接比较浮点 |

错误测试必须验证具体错误：

```swift
func test_parse_whenInputIsEmpty_throwsEmptyInputError()
{
    XCTAssertThrowsError(try parser.parse("")) { error in
        XCTAssertEqual(error as? ParseError, .emptyInput)
    }
}
```

---

## 10. 异步与 Combine 测试

Swift 并发优先使用 `async/await`：

```swift
func test_search_whenServiceReturnsResults_updatesLoadedState() async throws
{
    // Arrange
    let service = SearchServiceStub(result: .success([ClipItem.fixture()]))
    let viewModel = HistoryViewModel(searchService: service)

    // Act
    await viewModel.search("test")

    // Assert
    XCTAssertEqual(viewModel.state, .loaded([ClipItem.fixture()]))
}
```

回调、delegate、Notification、Combine 使用 `XCTestExpectation`。

禁止：

```swift
Thread.sleep(forTimeInterval: 1.0)
usleep(500_000)
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
```

超时时间应短且合理，通常从 1 秒开始；若需很长时间，应检查是否测试层级过高或依赖未隔离。

### 10.1 含 MainActor Task hop 的异步链路

**例外场景**：当被测链路含多个 `Task { @MainActor in }` hop（如剪贴板捕获 → 分类 → 存储），CI 环境（xcodebuild + LLDB）的 MainActor 调度延迟可能累积超过短 timeout，导致 flaky。即使依赖已隔离，此类链路仍需特殊处理。

**推荐做法**：

- **优先用 `async` 测试 + 条件轮询**（如 `waitForConditionAsync`）：实际等待时间 = 链路完成时间，timeout 仅为安全边界，消除对调度延迟的敏感性
- **若必须用 `expectation + wait(timeout:)`**：timeout 需考虑 CI 调度延迟（建议 ≥ 5s），并注释说明为何需要更长 timeout
- **禁止**：为"修复"flaky 而缩短 timeout 或移除等待机制

示例（轮询优于 expectation）：

```swift
// ✅ 推荐：async + 条件轮询，对 MainActor 调度延迟不敏感
func test_capture_whenClipboardChanges_storesNewItem() async
{
    // ... arrange ...
    pasteboardWatcher.simulateChange(content: "test content")
    let stored = await waitForConditionAsync(timeout: 5.0) {
        store.itemCount >= 1
    }
    XCTAssertTrue(stored, "捕获应在 5s 内完成存储")
}

// ⚠️ 避免：expectation + 短 timeout，对 MainActor 调度延迟敏感
func test_capture_whenClipboardChanges_storesNewItem()
{
    let exp = expectation(description: "capture stored")
    // ... arrange ...
    pasteboardWatcher.simulateChange(content: "test content")
    wait(for: [exp], timeout: 3.0)  // CI 环境可能 flaky
}
```

**判断 MainActor Task hop 链路的信号**：

- 被测代码含 `Task { @MainActor in ... }` 嵌套
- 链路中有 `await` + MainActor 调度（如 `await captureService.capture()` 后调用 MainActor 方法更新 UI）
- CI（xcodebuild）下偶发 timeout 失败，本地稳定通过

---

## 11. Stub、Mock、Spy 与依赖注入

| 替身 | 用途 |
|---|---|
| Stub | 提供稳定输入或返回值 |
| Mock | 验证必要外部交互 |
| Spy | 记录调用参数 |
| Fake | 提供简化但可运行的实现 |

使用 Mock 前必须回答：

> 如果这个调用没有发生，用户或系统会观察到什么错误？

回答不了，就不要 Mock。

要求：

- Mock 只实现当前测试需要的行为。
- Mock 中不得包含业务逻辑。
- 不验证无业务意义的调用次数和顺序。
- 不把所有对象都抽象成协议。
- 只抽象慢、不稳定、不可控或外部依赖。
- 优先使用 initializer injection。

---

## 12. macOS 分层测试建议

### 12.1 Domain / Core Logic

优先单元测试：校验、解析、状态机、排序、权限规则、错误映射、路径生成和业务策略。

ClipMind 核心逻辑包括：内容分类（`Classify`）、敏感检测（`Privacy`）、搜索匹配（`Search`）、去重逻辑（`Capture`）。

### 12.2 ViewModel / Presenter

测试用户意图到公开状态的映射，不启动真实窗口，不验证私有属性。

### 12.3 SwiftUI

复杂逻辑下沉到 ViewModel、Reducer 或纯函数。View 层只验证关键内容、action 和稳定的 accessibility identifier。

ViewInspector 不是强制依赖。项目已使用时可做轻量验证；未使用时不要仅为简单视图测试强行引入。

### 12.4 AppKit

尽量将逻辑移出 `NSViewController`、`NSWindowController`，Controller 只负责绑定和转发。

AppKit 按钮交互优先使用：

```swift
button.performClick(nil)
```

### 12.5 文件、数据库和网络

| 依赖 | 测试策略 |
|---|---|
| 文件 | 临时目录，并在 tearDown 清理 |
| 数据库 | 测试数据库或内存数据库（SQLite in-memory） |
| 网络 | URLProtocol Stub 或协议抽象（`LLMServicing`） |
| 系统服务 | 协议封装后注入替身（`PasteboardWatching`） |
| Pasteboard | 协议抽象，不访问真实系统剪贴板 |

---

## 13. CI 与回归测试分层

| 阶段 | 测试内容 | 目标 |
|---|---|---|
| 本地开发 | 当前模块单元测试、Bug 回归测试 | 快速验证当前修改 |
| PR / MR | Fast Unit、受影响组件测试、核心冒烟测试 | 阻止明显回归进入主分支 |
| 合并主分支后 | 更完整的组件和集成测试 | 验证模块协作 |
| 夜间或发布前 | UI、全量回归、性能测试 | 覆盖低频高价值场景 |

PR 测试应追求快速反馈，但不机械限定统一时长。团队应依据项目规模设定时间预算。

要求：

- 快速测试稳定、可重复。
- 慢测试不混入快速反馈集合。
- CI 失败能定位具体行为。
- 保存 `.xcresult` 用于排查。
- 覆盖率只作为辅助指标。

CI 使用 `xcodebuild test -project ClipMind.xcodeproj -scheme ClipMind` 执行测试，详见 `.github/workflows/ci.yml`。

---

## 14. AI 输出格式

AI 每次生成或修改测试时，必须优先输出：

```markdown
## 变更影响分析

## 测试目标

## 用例设计

| 用例 | 场景 | 输入 | 替身 | 期望 | 类型 |
|---|---|---|---|---|---|

## 依赖处理

## 测试代码

## 建议执行的测试集合

## 自检结果
```

不允许直接丢出测试代码而不说明影响范围、测试目标和依赖处理。

---

## 15. Trae Prompt 模板

### 15.1 新增或修改功能

```text
请先阅读 docs/AI/trae-xctest-rules.md。

请为以下 macOS Swift 代码设计并生成 Xcode 15+ 可运行的 XCTest。

先不要直接写代码，请先输出：
1. 本次变更的直接和间接影响。
2. 被测入口点、场景和可观察结果。
3. 必须新增、更新和执行的测试。
4. 用例表。
5. 依赖隔离方案。

要求：
- 使用 XCTest，不使用 Swift Testing。
- 测试行为，不测试私有实现。
- 使用 AAA。
- 不访问真实外部依赖。
- 不使用 sleep。
- 每个测试只验证一个核心行为。
- 如代码不易测试，只提出最小重构方案，不直接大改。

变更说明：

被测代码：
```

### 15.2 修复 Bug

```text
请先阅读 docs/AI/trae-xctest-rules.md。

下面是一个可复现 Bug。请先设计一个能够稳定复现该问题的失败 XCTest，再提出最小修复方案。

要求：
1. 先说明 Bug 的对外可观察行为。
2. 先写失败回归测试，再修改生产代码。
3. 不测试私有方法或内部调用路径。
4. 列出受影响的旧行为和应执行的回归测试。
5. 不得为了测试通过而随意修改旧测试预期。

Bug 描述：

相关代码：
```

### 15.3 Review 已有测试

```text
请根据 docs/AI/trae-xctest-rules.md 审查下面的 XCTest。

重点检查：
- 是否测试行为而不是实现。
- 是否遗漏变更影响到的旧行为。
- 是否有无断言或只为覆盖率存在的测试。
- 是否依赖网络、时间、随机数、执行顺序或 sleep。
- 是否存在强制解包、浮点无 accuracy、错误未验证具体类型。
- 是否过度 Mock。
- 测试是否适合进入对应 CI 集合。

输出：总体评价、必须修改、建议优化、修改后代码、应执行的回归集合。
```

---

## 16. 禁止清单

AI 不得生成：

- 没有断言的测试。
- 只为了覆盖率执行代码的测试。
- 依赖真实网络、时间、随机数或生产环境的单元测试。
- 使用固定等待的异步测试。
- 测试私有方法或无业务意义调用顺序的测试。
- 一个测试覆盖多个无关行为。
- Mock 中包含业务逻辑。
- 过度 Mock 所有依赖。
- 因内部重构就频繁失败的测试。
- Xcode 15+ 项目中的 Swift Testing API。
- 使用 `try?` 吞掉测试错误。
- 依赖测试执行顺序或共享可变状态的测试。
- 仅依据修改文件列表圈定回归范围。
- 为让测试通过而未经确认地修改旧测试预期。

---

## 17. 代码评审检查表

| 检查项 | 通过标准 |
|---|---|
| XCTest | 使用 XCTest，不使用 Swift Testing |
| 行为验证 | 验证公开可观察行为 |
| 命名 | 包含入口点、场景、期望行为 |
| 结构 | AAA 清晰，一个主要 Act |
| 断言 | 有明确断言，错误验证具体类型 |
| 稳定性 | 不依赖网络、时间、随机数、顺序 |
| 异步 | async/await 或 expectation，不使用 sleep |
| Mock | 只验证必要外部交互 |
| 回归范围 | 包含直接和间接影响分析 |
| Bug 修复 | 优先有失败回归测试 |
| 旧测试 | 未未经确认地修改旧预期 |
| 自动化价值 | 能说明收益与维护成本 |
| CI | 放入合适的测试集合 |

---

## 18. 最终验收标准

AI 生成或修改的测试只有同时满足以下条件，才允许合并：

1. 验证明确的业务行为。
2. 使用 Xcode 15+ 支持的 XCTest。
3. 有明确断言和清晰失败原因。
4. 不依赖真实外部环境。
5. 运行稳定、快速、可重复。
6. 不过度 Mock。
7. 不绑定私有实现。
8. 对重构友好。
9. 已分析直接和间接影响。
10. Bug 修复已尽可能固化为回归测试。
11. 已列出建议执行的测试集合。
12. 能在对应 CI 阶段可靠运行。

---

## 19. 极简版规则

```markdown
本项目使用 macOS + Xcode 15+ + XCTest。测试行为，不测试实现；命名使用 `test_入口点_场景_期望行为`；使用 AAA；每个测试只验证一个核心行为；不访问真实网络、时间、随机数或生产环境；不使用 sleep；可选值用 XCTUnwrap；浮点比较用 accuracy；错误测试验证具体错误；只有外部交互本身是业务行为时才 Mock。每次修改生产代码后必须分析直接和间接影响，列出新增、更新和执行的回归测试；修复可复现 Bug 时优先先写失败测试；不得仅根据修改文件列表决定回归范围，也不得为了通过而随意修改旧测试预期。
```
