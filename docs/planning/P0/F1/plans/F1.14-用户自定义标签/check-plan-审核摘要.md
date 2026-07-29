# F1.14 用户自定义标签实现计划 check-plan 审核摘要

> 最后更新：2026-07-29 | 版本：v1.0

## 1. 审查对象

- 主计划：`README.md`
- 子计划：`phase-0-implementation-entry-gates.md` 至 `phase-6-release-integration.md`
- 规格基线：Requirements v1.2、Design v2.2、Visual Prototype v2.3、Test Matrix v2.3
- 代码基线：Planning 开始时 HEAD `5d039de`
- 审查等级：Standard，1 名独立 reviewer
- 审查视角：
  - Review A：FR/NFR/AC、范围、阶段和文件覆盖
  - Review B：规格语义、架构、并发、存储、合规与阶段边界
  - Review C：TDD、UI 可观测性、CI/SHA、性能和人工证据可执行性

## 2. 审查轨迹

| 轮次 | 结论 | 主要发现 | 处理结果 |
|------|------|---------|---------|
| 初审 | RETRY | 旧 `ClipItem` 可能覆盖最新标签；`TagStore` 取消模型会丢 mutation/中断迁移；日志端口可接任意字符串；设置 preflight 重复规则；搜索变为输入即搜；粘贴 positive control 不会发送真实事件；性能/人工证据不绑定 exact SHA；Sandbox 首启可能看不到旧库；缺 macOS 13 runtime；测试名、提交边界和 Smoke 阶段矛盾 | 建立原子 merge、三通道任务模型、闭集日志、共享 validator、committed query、armed paste policy、Release/ReleaseDev 与 exact-SHA Gate、container migration、macOS 13 双 lane，并统一测试/提交 |
| Retry 1 | RETRY | reviewer 的 Phase 2 fixture 结论来自陈旧读取；有效新增问题是 upgrade seed 与隔离 DB 冲突，以及主 Release 不能运行 Dev fixture 套件 | 证明 Phase 2 已创建 repository-backed fixture；新增 disposable default-path seeder；macOS 13 拆为主 Release Lane A 与 ReleaseDev Lane B |
| Retry 2 | RETRY | reviewer 对 project staging 有部分陈旧读取；有效剩余问题是首次 Phase 6 build 前需生成工程，新 workflow 在默认分支前不能依赖 `workflow_dispatch` | 所有 `project.yml` 变更前置 `xcodegen generate` 并提交 pbxproj；UI Smoke 增加无 paths 限制的 `feature/**` push trigger，Phase 6 只等待 push run |
| Retry 3 | PASS | 无新的 Must-fix | Review A、B、C 全部通过 |

## 3. 最终修订结果

### Review A：通过

- 15 条 FR、7 条 NFR、24 条 AC 均有 Phase、自动化或人工证据承载。
- Phase 0 明确保留 F1.13 外部编译 blocker，不把上游修复混入 F1.14。
- 内容编辑、标签 mutation、迁移、设置、Sandbox 旧库迁移、macOS 13 runtime 和双架构均有明确文件与 Gate。
- Phase 2 起即建立真实加密数据库 fixture 和 UI Smoke；Phase 3/4 随生产能力扩充，不把测试债推迟到 Phase 5。

### Review B：通过

- `EncryptedStore.update(_:)` 事务内读取最新条目并保留 `tagState`，消除旧内容快照回滚标签。
- `TagStore` 的 load、FIFO mutation、migration 三个 task 生命周期互不取消。
- 名称规则由 `TagNameValidator` 单一实现；日志端口只接受闭集 operation/result/error。
- 主窗口保留 `SearchBar.onCommit` 语义，组合筛选只消费 `committedQuery`。
- Sandbox 使用 Apple container migration manifest；upgrade seeder 仅允许 disposable account/VM。
- Implementation integration 与 Final Candidate 分层，后者必须合入最新 `develop` 后重跑全部 Gate。

### Review C：通过

- 三入口标签事件使用共享组件，粘贴负向证据包含 armed real Cmd+V positive control、焦点 guard、receiver text 和 event count。
- UI fixture/probe 仅编入 `CLIPMIND_DEV`；主 Release 对统一 `UITEST_TAG_` 前缀和类型符号做排除扫描。
- 性能固定 macOS 15 arm64、Release/ReleaseDev、1000 条夹具、20 次 nearest-rank p95。
- exact integration 和 Final Candidate 均重跑 PERF-001～004、STAB-002、A11Y-002、Sandbox upgrade、macOS 13、archive 和完整 CI。
- 新 UI Smoke 由 `feature/**` push 触发，evidence-only commit 也产生 exact-SHA run；不依赖尚未进入默认分支的 manual dispatch。

## 4. 已采纳的非阻断建议

- 标签条采用横向滚动和视觉截断，同时保留完整 accessibility 语义。
- 首次 snapshot load 前显示 loading/unavailable，不把 `.empty` 当真实无标签状态。
- UI Smoke 给出可执行 YAML 骨架、SwiftLint、exact SHA、xcresult artifact。
- GitHub run 查询先复用同 SHA run，再进行有界 API 可见性轮询。
- `project.yml` 与生成的 `ClipMind.xcodeproj/project.pbxproj` 保持同提交。

## 5. 验证证据

- 8 份计划文档均有统一元数据和版本记录。
- README 的 24 条 AC 映射完整。
- 相对 Markdown 链接均可解析。
- 无 TODO、TBD、未决实现占位符或已知未定义符号。
- 文档逐文件 whitespace check 无输出。
- 最终独立复验：Review A PASS、Review B PASS、Review C PASS，0 Must-fix。

## 6. Gate 与后续边界

- Planning Gate：通过。
- 允许状态进入 Implementation / Phase 0。
- F1.13 来源筛选基线仍阻止 Phase 1。
- macOS 13 runtime 环境当前不可用，作为 Phase 6 / Final Candidate blocker 持续跟踪。
- 本次只提交文档，不修改生产代码、测试代码、workflow、entitlement 或 Xcode 配置。

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-29 | 记录初审至 Retry 3 的修订轨迹、A/B/C 最终 PASS、验证证据和后续 blocker。 |
