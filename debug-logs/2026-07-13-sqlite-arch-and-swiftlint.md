# SQLite 架构构建错误 + SwiftLint 违规修复

## 问题描述

1. **SQLite 构建错误**（用户报告）：在 feature/clipmind-phase2 worktree 构建时，`EncryptedStore.swift:5` 报错 `Could not find module 'SQLite' for target 'x86_64-apple-macos'; found: arm64-apple-macos`。
2. **SwiftLint 违规**（基线 CI 失败发现）：`APIKeyManager.swift:139` 的 `String(decoding:as:)` 触发 `optional_data_string_conversion` 规则。

## 前置：步骤 0 获取的运行日志信息

- 用户报告错误：`/Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/clipmind-phase2/ClipMind/Storage/EncryptedStore.swift:5:8: Could not find module 'SQLite' for target 'x86_64-apple-macos'; found: arm64-apple-macos, at: /Users/dengdeng/Library/Developer/Xcode/DerivedData/ClipMind-eoxxopooabzvzifqzxexcsvhtmda/Build/Products/Debug/SQLite.swiftmodule`
- 基线 CI（run_id=29211928491）失败日志：SwiftLint 阶段 `optional_data_string_conversion` 违规，未到 Build 阶段。

## 红灯：测试用例

### SwiftLint 修复

- 现有测试 `APIKeyManagerTests.testSaveAndLoadKey` 已覆盖 `loadKey` 正常行为
- 修复 `String(decoding:as:)` → `String(data:encoding:)` 后，现有测试应继续通过
- 红灯证据：CI run_id=29211928491 SwiftLint 阶段失败

### SQLite 构建配置修复

- 红灯证据：`xcodebuild -showBuildSettings` 显示 `ARCHS = arm64 x86_64` + `ONLY_ACTIVE_ARCH = NO`
- 用户报告的构建错误：x86_64 目标找不到 SQLite.swiftmodule
- 此问题为构建配置问题，无法用单元测试覆盖，以 CI 构建作为验证

## 根因调查

### SwiftLint 违规根因

- 文件：`ClipMind/LLM/APIKeyManager.swift:139`
- 代码：`return String(decoding: data, as: UTF8.self)`
- 规则：`optional_data_string_conversion` — 建议使用可失败的 `String(data:encoding:)` 初始化器
- 本地 SwiftLint 0.55.1 未检测此规则，CI 版本更新后检测
- 数据由 `saveKey` 写入（`Data(key.utf8)`），UTF-8 编码可保证，行为无变化

### SQLite 构建错误根因

- `project.yml` 未显式设置 `ONLY_ACTIVE_ARCH`
- XcodeGen 生成的项目继承默认值，但 Debug 配置 `ONLY_ACTIVE_ARCH = NO`
- `ARCHS = arm64 x86_64` — 尝试构建通用二进制
- SQLite.swift 0.15.0 的 .swiftmodule 只为 arm64 构建
- x86_64 目标找不到 SQLite.swiftmodule
- CI 用 `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES` 覆盖，故 CI 不复现

## 绿灯：修复实施

### 修复 1：SwiftLint 违规

- 文件：`ClipMind/LLM/APIKeyManager.swift:139`
- 修改：`String(decoding: data, as: UTF8.self)` → `String(data: data, encoding: .utf8)`
- 更新注释说明
- 额外修改：`.swiftlint.yml` 禁用 `non_optional_string_data_conversion` 规则
  - 原因：本地 SwiftLint 0.55.1 误报 `String(data:encoding:)`，CI 版本不检测此模式
  - CI 版本的 `non_optional_string_data_conversion` 只检测 `.data(using:)` 调用，不检测 `String(data:encoding:)`
  - 项目中唯一的 `.data(using:)` 调用是 `DetailPanel.swift:384` 的 `json.data(using: .utf8)`，`json` 是变量，默认配置不检测

### 修复 2：SQLite 构建配置

- 文件：`project.yml`
- 修改：在顶层 `settings` 中为 Debug 配置添加 `ONLY_ACTIVE_ARCH: YES`
- 效果：Debug 构建只构建当前活动架构（arm64），避免 x86_64 构建失败
- 验证：`xcodebuild -showBuildSettings` 显示 `ARCHS = arm64`，`ONLY_ACTIVE_ARCH = YES`
- Release 配置保持默认（可能需要 universal binary 用于分发）

## 运行时日志

APIKeyManager.loadKey 方法已有 LogCategory.llm 日志（warning 级别），覆盖异常路径。本次修复未改变行为，无需新增日志。

## 流程图

```
[构建启动] → [xcodegen generate] → [swiftlint lint --strict]
                                              |
                                    [SwiftLint 通过?]
                                       /         \
                                     否           是
                                      |            |
                            [CI 失败]   [xcodebuild build]
                                      |            |
                                      |     [ARCHS=arm64?]
                                      |       /         \
                                      |     否           是
                                      |      |            |
                                      | [x86_64 构建]  [构建成功]
                                      |      |
                                      | [SQLite 模块缺失]
                                      |      |
                                      | [构建失败]
                                      v
[修复] → [project.yml: ONLY_ACTIVE_ARCH=YES]
       → [APIKeyManager.swift: String(data:encoding:)]
       → [.swiftlint.yml: 禁用 non_optional_string_data_conversion]
```

## 时序图

```
开发者  XcodeGen  SwiftLint  XcodeBuild  SQLite.swift  CI
  |         |        |          |           |         |
  | 修改 project.yml |          |           |         |
  |-------->|        |          |           |         |
  | xcodegen generate|          |           |         |
  |-------->|-------->|         |           |         |
  |         | 生成 .xcodeproj   |           |         |
  |<--------|        |          |           |         |
  | swiftlint lint   |          |           |         |
  |-------->|-------->|         |           |         |
  |         |        |--pass--->|           |         |
  | xcodebuild build |          |           |         |
  |-------->|        |--------->|           |         |
  |         |        |    ARCHS=arm64       |         |
  |         |        |          |--------->|         |
  |         |        |          |  构建arm64|         |
  |         |        |          |<---------|         |
  |         |        |          |  .swiftmodule       |
  |         |        |          |           |         |
  | push 到远端     |          |           |         |
  |----------------------------------------------->|
  |         |        |          |           | CI 验证 |
  |<-----------------------------------------------|
  | CI 通过 |        |          |           |         |
```

## 总结

两个问题一起修复：
1. SwiftLint 违规：代码风格修复 + 禁用误报规则
2. SQLite 构建错误：构建配置修复，Debug 只构建当前架构

全量回归验证延迟到步骤 3.3.5，由 CI 完成。
