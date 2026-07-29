# Phase 6：发布合规与最终集成

> 最后更新：2026-07-29 | 版本：v1.0

**目标：** 在 implementation integration SHA 上关闭 App Sandbox、双架构、完整 CI、回归、
性能和人工证据 Gate，并形成可进入 Final Candidate Stage 的可重复验证基线。

**IN：** Phase 0～5 全部通过，工作树干净，F1.14 UI Smoke 成功。

**OUT：** AC-F1.14-1～24 的 integration 证据包；可以进入 Feature Workflow 的
Final Candidate Stage。Final Candidate 必须基于最新 `develop` 产生新的 exact SHA 并重跑 Gate。

**非目标：** 绕过失败测试、把主方案降到 `ClipMind-Dev`、在已验证 integration SHA 后追加
未重新验证的改动。

---

## 任务 1：主发布方案启用 App Sandbox

**文件：**

- 修改：`ClipMind/Resources/ClipMind.entitlements`
- 创建：`ClipMind/Resources/container-migration.plist`
- 修改：`project.yml`
- 创建：`ClipMindTests/App/ReleaseComplianceTests.swift`
- 创建：`ClipMindTests/App/ContainerMigrationManifestTests.swift`
- 创建：`ClipMindUITests/SandboxUpgradeUITests.swift`

- [ ] **步骤 1：编写 RED entitlement 测试**

测试读取仓库中的主 target entitlement，断言：

```swift
XCTAssertEqual(entitlements["com.apple.security.app-sandbox"] as? Bool, true)
XCTAssertEqual(entitlements["com.apple.security.network.client"] as? Bool, true)
XCTAssertEqual(entitlements["com.apple.security.files.user-selected.read-write"] as? Bool, true)
```

并断言 `project.yml` 的 ClipMind target 仍只绑定
`ClipMind/Resources/ClipMind.entitlements`，没有 F1.14 新增非必要 entitlement。
另断言项目 `MACOSX_DEPLOYMENT_TARGET == 13.0`，与产品合同的 macOS 13+ 一致。

- [ ] **步骤 2：运行 RED**

运行 `ClipMindTests/ReleaseComplianceTests`。预期：当前 `app-sandbox=false` 导致 FAIL。

- [ ] **步骤 3：增加系统 container migration manifest**

依据 Apple 的 App Sandbox container migration 机制，在 app bundle 中加入
`container-migration.plist`：

```xml
<key>Move</key>
<array>
    <array>
        <string>${ApplicationSupport}/ClipMind</string>
        <string>${ApplicationSupport}/ClipMind</string>
    </array>
</array>
```

源变量从用户 home 展开，目标变量从 app container 展开；迁移整个目录以同时覆盖
`clipmind.db`、`-wal`、`-shm`。`ContainerMigrationManifestTests` 解析 plist，断言唯一 Move
项、源/目标、bundle resource 存在，且 entitlement 没有 home-relative temporary exception。
`project.yml` 将 macOS deployment target 从 12.4 统一到 13.0。

机制与变量语义以 Apple 官方文档
[Migrating your app’s files to its App Sandbox container](https://developer.apple.com/documentation/security/migrating-your-app-s-files-to-its-app-sandbox-container)
为唯一外部依据。

- [ ] **步骤 4：启用 Sandbox**

entitlement 只改：

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

保留现有 network client 与 user-selected read-write；不增加临时例外、绝对路径、Apple Events、
Accessibility 或私有 entitlement。

- [ ] **步骤 5：运行 GREEN 和真实升级回归**

主 Scheme build/test 通过后，再用真实自动签名构建检查运行行为。若既有捕获、搜索、粘贴、
设置或存储在 Sandbox 下失败，Final Candidate 必须停止；修复合规根因后重新执行 Phase 6，
不得把 F1.14 只留在 Dev Scheme。

`SandboxUpgradeUITests` 不能用测试内直接读数据库冒充迁移，执行顺序固定为：

1. 在干净 macOS 测试账号、尚无 `~/Library/Containers/com.clipmind.app` 时，从状态文件读取
   Phase 5 已提交 SHA，在独立 detached worktree 构建 unsandboxed `ClipMind-Dev/ReleaseDev`；
   创建 disposable marker，并用专用 upgrade-seed 模式写旧生产默认路径后 checkpoint/退出；
2. 记录旧条目数、11 类 contentType、一个显式 removed disposition 和 user tag 关联；
3. 首次启动自动签名的 Sandbox Release archive，让 macOS 执行 manifest；
4. 只通过 App UI 断言旧条目、标签、removed 处置和后续 F1.14 migration 都完整；
5. 重启再断言无重复，并检查旧 home 目录/容器目标符合系统迁移结果。

测试账号/VM 每轮恢复干净快照，不靠删除当前用户真实数据。无法提供该环境时 Phase 6 标
BLOCKED，不能仅以 plist 静态测试通过 AC-15/23。

在 disposable 账号内使用以下确定命令；普通 Smoke 禁止设置这些 env/marker：

```bash
state_file="$(git rev-parse --git-path feature-development-state.json)"
phase5_sha="$(jq -er '.commits.phase_5' "$state_file")"
upgrade_root="$(mktemp -d)"
phase5_worktree="$upgrade_root/phase5"
git worktree add --detach "$phase5_worktree" "$phase5_sha"
touch "$HOME/.clipmind-f114-disposable-upgrade-account"
(cd "$phase5_worktree" && xcodegen generate)
xcodebuild build \
  -project "$phase5_worktree/ClipMind.xcodeproj" \
  -scheme ClipMind-Dev \
  -configuration ReleaseDev \
  -destination 'platform=macOS' \
  -derivedDataPath "$upgrade_root/Phase5DerivedData"
CLIPMIND_ALLOW_DEFAULT_PATH_SEED=1 \
  "$upgrade_root/Phase5DerivedData/Build/Products/ReleaseDev/ClipMind.app/Contents/MacOS/ClipMind" \
  --UITEST_UPGRADE_SEED_DEFAULT_PATH
```

随后在 Phase 6 exact SHA 的当前 worktree 构建自动签名 Release test product 并运行：

```bash
xcodegen generate
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$upgrade_root/Phase6DerivedData"
xcodebuild test-without-building \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$upgrade_root/Phase6DerivedData" \
  -only-testing:ClipMindUITests/SandboxUpgradeUITests
```

两条 `xcodebuild` 均使用项目自动签名，不传 `CODE_SIGN_*`。测试后恢复 VM/account 快照；
不对开发者当前 home 执行清理命令。

## 任务 2：原生双架构 CI

**文件：**

- 修改：`.github/workflows/ci.yml`

- [ ] **步骤 1：增加 workflow dispatch**

保留 push / pull_request，并新增：

```yaml
workflow_dispatch:
```

- [ ] **步骤 2：将 build-and-test 改为原生 runner matrix**

截至 2026-07-29，GitHub 官方 runner-images 表中 `macos-15` 是 arm64，
`macos-15-intel` 是 x86_64。计划固定显式标签，不使用会漂移的 `macos-latest`：

```yaml
strategy:
  fail-fast: false
  matrix:
    include:
      - runner: macos-15
        arch: arm64
      - runner: macos-15-intel
        arch: x86_64

runs-on: ${{ matrix.runner }}
```

官方标签来源：[GitHub Actions runner-images](https://github.com/actions/runner-images)。

Build 与 test 都传：

```yaml
ARCHS=${{ matrix.arch }}
ONLY_ACTIVE_ARCH=YES
```

两台 runner 均原生执行对应架构测试，不用 cross-compile 结果冒充功能测试。

- [ ] **步骤 3：保留高风险 UI job**

arm64 job 运行完整 `ClipMindTests`、非 panel UI 回归和 F1.14 UI Smoke；
具有 GUI 能力的 F1.14 UI Smoke workflow 继续运行三入口 panel 测试。
x86_64 job 至少运行全部 XCTest 与不依赖辅助功能/窗口焦点的 XCUITest。

任何 job 失败，matrix 结论为失败；不得 `continue-on-error`。

- [ ] **步骤 4：验证 workflow 语法**

运行：

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml"); puts "YAML_OK"'
```

预期：`YAML_OK`。若系统 Ruby 的 Psych 拒绝 GitHub 表达式，使用仓库已有 YAML linter；
不得以肉眼检查替代解析。

- [ ] **步骤 5：固定 macOS 13 runtime Gate**

当前 GitHub hosted 与仓库 runner inventory 没有可用的 macOS 13 self-hosted runner；
因此双架构 macOS 15 matrix 不能冒充最低系统运行证据。Final Gate 前必须取得一台受控
macOS 13.x 真机/VM，并在同一 code SHA 上分两条 lane：

```text
Lane A — 主 Scheme Release（无 Dev hook）
SandboxUpgradeUITests；正常启动；旧数据迁移；真实标签显示、打开 picker、关联/取消、
搜索/来源/标签组合筛选、设置系统只读与用户 rename/delete 主路径；扫描二进制无 UITEST_TAG_。

Lane B — ClipMind-Dev / ReleaseDev（确定性 fixture）
SearchUITests、PopoverUITests、QuickPastePanelUITests、SettingsUITests、
TagEntryUITests、TagPickerUITests、TagFilterUITests、TagSettingsUITests。
```

Lane A 使用自动签名的主 Release product/archive，只证明可发布构建在最低系统上的真实主路径、
Sandbox upgrade 和无测试 hook；不得传依赖 fixture 的参数。Lane B 使用 Release 优化的
Dev-only fixture 证明确定性边界/失败分支。两者记录相同 code SHA，以及 `sw_vers`、
`uname -m`、签名 identity、测试结果和截图，在 AC-23 映射中分别标注证明边界。
若仍无受控 macOS 13 环境，状态保持 `blocking_gap=macos13_runtime_unavailable`，
不得进入 Final Candidate。

## 任务 3：发布产物静态审查

**文件：**

- 扩充：`ClipMindTests/App/ReleaseComplianceTests.swift`

- [ ] **步骤 1：依赖和 API 差异**

断言：

- `project.yml` 仍只有 SQLite.swift 这一持久化依赖；
- F1.14 新文件不 import 私有 framework；
- `ClipMind` target 没有新增非公开 linker flag；
- Dev-only `TagUITestSupport` 在 Release 不可见。

- [ ] **步骤 2：真实自动签名 Archive**

遵循 AGENTS.md，使用主 Scheme `ClipMind`、Release 和项目自动签名，不传 `CODE_SIGN_*`：

```bash
xcodebuild archive \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  -archivePath build/ClipMind-F1.14.xcarchive
```

预期：`** ARCHIVE SUCCEEDED **`。

- [ ] **步骤 3：检查签名 entitlement 与架构**

```bash
app_path="build/ClipMind-F1.14.xcarchive/Products/Applications/ClipMind.app"
codesign -d --entitlements :- "$app_path"
lipo -info "$app_path/Contents/MacOS/ClipMind"
```

预期：签名 entitlement 显示 App Sandbox true；二进制同时含 `arm64` 和 `x86_64`。
记录输出到 integration evidence 包。

## 任务 4：提交前回归

- [ ] **步骤 1：运行确定性检查**

```bash
xcodegen generate
swiftlint lint --strict
git diff --check
```

预期：全部退出 0。

- [ ] **步骤 2：回归既有行为**

在工作树上至少运行：

```text
ClipMindTests
ClipMindUITests/SearchUITests
ClipMindUITests/PopoverUITests
ClipMindUITests/PopoverDoublePasteUITests
ClipMindUITests/QuickPastePanelUITests
ClipMindUITests/SettingsUITests
ClipMindUITests/SampleDataUITests
```

未选择标签时，搜索、来源筛选、系统标签显示、单击/双击/回车/Esc、置顶和设置 Tab 行为不变。
本步骤只作为提交前反馈，不能替代提交后的 exact SHA CI。

## 任务 5：提交发布合规改动

- [ ] **步骤 1：提交**

```bash
git add \
  ClipMind/Resources/ClipMind.entitlements \
  ClipMind/Resources/container-migration.plist \
  project.yml \
  ClipMind.xcodeproj/project.pbxproj \
  ClipMindTests/App/ReleaseComplianceTests.swift \
  ClipMindTests/App/ContainerMigrationManifestTests.swift \
  ClipMindUITests/SandboxUpgradeUITests.swift \
  .github/workflows/ci.yml
git commit -m "chore(tags): enforce release compliance"
```

提交后不得修改生产、测试或 workflow 文件，先进入任务 6 验证该 implementation code SHA。

## 任务 6：exact integration SHA 与证据收口

- [ ] **步骤 1：触发 implementation code SHA CI**

```bash
current_branch="$(git rev-parse --abbrev-ref HEAD)"
code_sha="$(git rev-parse HEAD)"
git push -u origin "$current_branch"

find_run_id()
{
  gh run list \
    --workflow "$1" \
    --commit "$code_sha" \
    --limit 20 \
    --json databaseId,headSha,status,conclusion \
    --jq 'map(select(.headSha == "'"$code_sha"'")) | first | .databaseId // empty'
}

for workflow in ci.yml tag-ui-smoke.yml
do
  for attempt in $(seq 1 30)
  do
    run_id="$(find_run_id "$workflow")"
    test -n "$run_id" && break
    sleep 2
  done
  test -n "$run_id"
done

ci_run_id="$(find_run_id ci.yml)"
ui_smoke_run_id="$(find_run_id tag-ui-smoke.yml)"
test -n "$ci_run_id"
test -n "$ui_smoke_run_id"
gh run watch "$ci_run_id" --exit-status
gh run watch "$ui_smoke_run_id" --exit-status
```

两个 workflow 都必须由 `git push` 的 feature branch trigger 产生；新建的
`tag-ui-smoke.yml` 在进入默认分支前不调用 `workflow_dispatch`。2 秒等待只用于有界解决
push run 的 API 可见性竞态，最多 60 秒；完成条件由 `gh run watch --exit-status` 决定，
不用固定等待冒充完成。已有同 SHA run 时直接复用。
在同一 `code_sha` 上执行任务 1 的真实 Sandbox upgrade、任务 2 的 macOS 13 runtime、
主 Scheme Release/ReleaseDev 的 PERF-001～004、STAB-002、A11Y-002，以及任务 3 的自动签名
archive/codesign/lipo；所有 artifact 明确记录 `code_sha`。任何一项失败都先修改实现并重新提交，
不得继续生成证据清单。

- [ ] **步骤 2：复算 AC 和 Test Matrix**

为 24 条 AC 逐项填写：

```text
AC -> test case -> run ID / artifact -> result -> implementation code SHA
```

没有实际 run 或人工证据的 AC 不得标 PASS。STAB-002、A11Y-002 和发布 archive 必须引用
Phase 5/6 的真实路径与 SHA。

- [ ] **步骤 3：提交证据清单**

写：

```text
docs/planning/P0/F1/evidence/F1.14/<code-sha>/integration-evidence.md
```

包含：

- implementation code SHA / branch；
- arm64/x86_64 CI run；
- UI Smoke run；
- archive、codesign、lipo；
- PERF 原始样本与 p95；
- STAB `.trace`；
- A11Y Inspector；
- 已知边界为 0 blocker。

该文档和人工证据只描述已经验证的 code SHA，避免自引用提交。提交：

```bash
git add \
  docs/planning/P0/F1/evidence/F1.14/
git commit -m "docs(tags): record integration evidence"
```

- [ ] **步骤 4：验证最终 exact integration SHA**

证据提交只允许包含 `docs/planning/P0/F1/evidence/F1.14/`。记录：

```bash
integration_sha="$(git rev-parse HEAD)"
```

执行 `git push origin "$current_branch"`，按步骤 1 的同 SHA 有界查询等待 push 自动产生的
`ci.yml` 与 `tag-ui-smoke.yml`。最终 run ID、headSha
和结论写入 git worktree 外的 `feature-development-state.json`。

同一 `integration_sha` 还必须重新执行并上传 SHA 绑定 artifact：

- macOS 15 arm64：主 Scheme Release 的 PERF-001/003、ReleaseDev 的 PERF-002/004，
  每项预热 1 次 + 20 次原始样本 + nearest-rank p95；
- 自动签名主 Scheme Release archive、`codesign` entitlement 和 universal `lipo` 输出；
- 自动签名 ReleaseDev 的 STAB-002 Instruments `.trace`/摘要；
- ReleaseDev 的 A11Y-002 VoiceOver/Inspector 记录；
- macOS 13 runtime 任务的兼容记录。

这些 final artifact 由 CI/任务存储按 exact SHA 归档，路径与 run ID 写状态文件；不得再次修改
仓库内证据文档造成自引用循环。确认 `git diff --exit-code`、`git status --short` 均无输出。

## Phase 6 Gate

- 主 Scheme App Sandbox=true，无新增不必要 entitlement。
- arm64 与 x86_64 在原生 runner 上 build/test 成功。
- F1.14 UI Smoke 与既有 UI 回归成功。
- 主 Scheme Release 自动签名 archive 成功，codesign/lipo 证据存在。
- 24 条 AC 均绑定 implementation code SHA 的测试或人工证据，且 exact integration SHA
  相比它只多一个 evidence-only commit；exact integration SHA 的完整 CI/UI Smoke 再次通过。
- SwiftLint、git diff check、完整 CI 全部通过。
- 工作树干净，状态记录 integration SHA/run，才可进入 Final Candidate。
- Final Candidate 合入最新 `develop` 后生成新的 exact candidate SHA，重复 Phase 6 的完整
  CI、UI Smoke、PERF-001～004、STAB-002、A11Y-002、macOS 13 runtime、archive 和 AC
  证据映射；任何新失败都返回对应 Implementation Phase 修复，不能引用较早 Phase 5 SHA 代替。

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-29 | 固定 Sandbox、GitHub 原生双架构 runner、archive、完整 CI 和 AC 证据收口。 |
