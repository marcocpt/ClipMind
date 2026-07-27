# F1.12 详细窗口内容可编辑 实现计划

> 最后更新：2026-07-27 | 版本：v1.0

> **面向 AI 代理的工作者：** 必需子技能：使用 subagent-driven-development（推荐）或 executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在主窗口详情面板中增加内容编辑能力：文本和文件路径类型支持点击进入编辑模式、实时自动保存、Cmd+Z 撤销；图片类型显示不可编辑提示；编辑后同步到系统剪贴板。

**架构：** 新增 EditableContentArea SwiftUI 视图组件封装编辑逻辑，在 DetailPanel 中替换只读 Text；新增 EncryptedStore.update() 和 ClipStore.updateClip() 方法支持数据库更新；使用 Task 防抖实现自动保存。

**技术栈：** Swift 5.7+ / SwiftUI / macOS 13+ / SQLite.swift

**需求文档：** `docs/planning/P0/F1/F1.12_详细窗口内容可编辑_需求文档.md`

**设计文档：** `docs/planning/P0/F1/F1.12_详细窗口内容可编辑_设计文档.md`

**视觉原型：** `docs/planning/P0/F1/F1.12_详细窗口内容可编辑_视觉原型.html`

**测试用例表：** `docs/planning/P0/F1/F1.12_详细窗口内容可编辑_测试用例表.md`

---

## Phase 列表

| Phase | 目标 | 子计划文件 | 依赖 |
|-------|------|-----------|------|
| 0 | 文本内容编辑 + 自动保存 + 撤销 | [phase-0-text-edit-save-undo.md](phase-0-text-edit-save-undo.md) | 无 |
| 1 | 文件路径编辑 + 图片提示 + 剪贴板同步 | [phase-1-filepath-image-clipboard.md](phase-1-filepath-image-clipboard.md) | Phase 0 |

## 全局验证命令

```bash
# Lint 检查
swiftlint lint --strict

# 编译检查
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# 完整测试
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

## 最终验收方式

8 条 AC（AC-F1.12-1 ~ AC-F1.12-8）全部通过 XCTest + XCUITest 验证。

| AC 编号 | AC 描述 | 验证方式 | 覆盖 Phase |
|---------|---------|---------|-----------|
| AC-F1.12-1 | 点击文本区域进入编辑模式 | XCUITest | Phase 0 |
| AC-F1.12-2 | 编辑文本内容实时自动保存到数据库 | XCTest + XCUITest | Phase 0 |
| AC-F1.12-3 | Cmd+Z 撤销编辑 | XCUITest | Phase 0 |
| AC-F1.12-4 | 切换到其他条目时自动保存 | XCUITest | Phase 0 |
| AC-F1.12-5 | 编辑保存后同步到系统剪贴板 | XCTest | Phase 1 |
| AC-F1.12-6 | 文件路径类型可编辑 | XCUITest | Phase 1 |
| AC-F1.12-7 | 图片类型显示不可编辑提示 | XCUITest | Phase 1 |
| AC-F1.12-8 | 编辑后 AI 处理按钮仍可正常使用 | XCUITest | Phase 1 |

## 变更文件汇总

| 文件路径 | 变更类型 | Phase | 说明 |
|---------|---------|-------|------|
| `ClipMind/Storage/EncryptedStore.swift` | 修改 | 0 | 新增 `update(_ item: ClipItem) throws` 方法 |
| `ClipMind/UI/ClipStore.swift` | 修改 | 0 | 新增 `updateClip(_ item: ClipItem) throws` 方法 |
| `ClipMind/UI/MainWindow/EditableContentArea.swift` | 新增 | 0 | 可编辑内容区域 SwiftUI 视图组件 |
| `ClipMind/UI/MainWindow/DetailPanel.swift` | 修改 | 0 | 替换只读 Text 为 EditableContentArea |
| `ClipMindTests/Storage/EncryptedStoreUpdateTests.swift` | 新增 | 0 | EncryptedStore.update 单元测试 |
| `ClipMindTests/UI/ClipStoreUpdateTests.swift` | 新增 | 0 | ClipStore.updateClip 单元测试 |
| `ClipMindUITests/F1_12_DetailContentEditableTests.swift` | 新增 | 0+1 | F1.12 UI 测试 |

## 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-27 | 初始版本，2 Phase、6 Task（Phase 0）+ 5 Task（Phase 1） |
