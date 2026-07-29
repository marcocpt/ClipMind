# Phase 0：Implementation 入口 Gate

> 最后更新：2026-07-29 | 版本：v1.0

**目标：** 只验证 F1.14 的上游依赖、当前分支和 CI 起点；不修复 F1.13，不修改生产代码。

**IN：** Specification Gate 的确认提交 `5d039de` 与本实现计划。

**OUT：** 可验证的 F1.13 来源筛选基线、干净工作树和同 SHA 成功 CI；任一条件不满足即停止。

**非目标：** 标签模型、持久化、UI、筛选、设置或发布配置。

---

## 任务 1：固定工作树和规格快照

- [ ] **步骤 1：验证工作树、分支和状态**

运行：

```bash
test "$(git rev-parse --abbrev-ref HEAD)" = "feature/F1.14-user-tags"
test "$(pwd)" = "/Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.14-user-tags"
git status --short
ruby -rjson -e 'JSON.parse(File.read(ARGV.fetch(0)))' \
  "$(git rev-parse --git-dir)/feature-development-state.json"
```

预期：前两个命令退出 0，`git status --short` 只允许出现当前 Phase 已声明文件，状态 JSON 可解析。

- [ ] **步骤 2：验证四份规格仍是确认版本**

运行：

```bash
rg -n "版本：v1\\.2" docs/planning/P0/F1/F1.14_用户自定义标签_需求文档.md
rg -n "版本：v2\\.2" docs/planning/P0/F1/F1.14_用户自定义标签_设计文档.md
rg -n "视觉原型 v2\\.3" docs/planning/P0/F1/F1.14_用户自定义标签_视觉原型.html
rg -n "版本：v2\\.3" docs/planning/P0/F1/F1.14_用户自定义标签_测试用例表.md
```

预期：四个命令均命中且退出 0。版本变化时回到 Specification，不在 Phase 0 自行适配。

## 任务 2：验证 F1.13 编译依赖

- [ ] **步骤 1：验证缺失符号已有唯一生产定义**

运行：

```bash
test -f ClipMind/Utils/SourceFilterSelection.swift
test -f ClipMind/Utils/SourceAppExtractor.swift
test -f ClipMind/UI/MenuBar/SourceFilterOverlay.swift
rg -n "^struct SourceFilterSelection|^enum SourceAppExtractor|^struct SourceFilterOverlay" \
  ClipMind/Utils/SourceFilterSelection.swift \
  ClipMind/Utils/SourceAppExtractor.swift \
  ClipMind/UI/MenuBar/SourceFilterOverlay.swift
```

预期：三个文件存在，每个类型恰有一个生产定义。当前基线缺少这些文件时，记录 blocker 并停止；
修复必须在独立 F1.13 分支完成。

- [ ] **步骤 2：执行无签名编译检查**

运行：

```bash
xcodegen generate
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

预期：`** BUILD SUCCEEDED **`，不存在 `SourceFilterSelection`、
`SourceAppExtractor` 或 `SourceFilterOverlay` 缺失错误。

- [ ] **步骤 3：验证来源筛选回归**

在当前 SHA 的 CI 中运行：

```text
ClipMindTests/SourceFilterTests
ClipMindTests/UnifiedPastePanelViewModelTests
ClipMindUITests/SearchUITests
ClipMindUITests/PopoverUITests
ClipMindUITests/QuickPastePanelUITests
```

预期：主窗口、菜单栏弹窗、快捷粘贴面板的来源筛选均通过；未选标签时行为保持不变。
如果上游 F1.13 最终另增专用 filter test class，Phase 0 先用 `rg --files ClipMindTests` 验证
真实文件/class 名后再加入命令，不能计划一个当前不存在的符号。

## 任务 3：绑定 CI 起点

- [ ] **步骤 1：查询当前 SHA 的 CI**

运行：

```bash
current_branch="$(git rev-parse --abbrev-ref HEAD)"
current_sha="$(git rev-parse HEAD)"
gh run list \
  --workflow ci.yml \
  --branch "$current_branch" \
  --limit 5 \
  --json databaseId,headSha,status,conclusion
```

预期：存在 `headSha == current_sha`、`status == completed`、`conclusion == success` 的 run。
若分支尚未 push，先查询 `develop` 上同 SHA 的结果；仍无同 SHA 结果时按 CI 工作流询问是否 push，
不得降级为本地全量测试。

- [ ] **步骤 2：写入 Phase 0 恢复证据**

状态文件记录：

```json
{
  "current_stage": "implementation",
  "current_phase": 0,
  "blocking_gaps": [],
  "next_safe_action": "Start Phase 1 domain TDD from the verified F1.13 baseline.",
  "in_progress": {}
}
```

原子替换后重新解析，并验证记录的 SHA、run ID、worktree 路径仍与仓库事实一致。

## Phase 0 Gate

- F1.13 三个生产类型存在且编译。
- 来源筛选跨三个入口回归通过。
- 当前起点 SHA 有成功 CI。
- 工作树与状态一致。
- 本 Phase 不产生生产提交。

任何一项失败都保持 `current_phase=0`，将 F1.13 缺口写入 `blocking_gaps` 并停止。

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-29 | 固定 F1.13 编译、三入口来源筛选、工作树和同 SHA CI 入口 Gate。 |
