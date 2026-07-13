> 最后更新：2026-07-14 | 版本：v1.1

# F1.8 内置示例数据 check-plan 审核摘要

**审核步骤**：dd-feature-development-workflow Step 3.5 check-plan
**审核时间**：2026-07-14
**审核输入**：实现计划（README.md + phase-1-内置示例数据.md）、设计规范 v1.2、设计评审摘要、测试用例表 v1.2

---

## 1. 三子代理审核结论

| 方向 | 子代理 | 结论 | 必须修复 | 建议修复 | 可选优化 |
|------|--------|------|----------|----------|----------|
| A - 覆盖与范围 | 审核子代理 A | 需修复后重审 | 3 | 3 | 3 |
| B - 一致与正确 | 审核子代理 B | 需修复后重审 | 4 | 4 | 4 |
| C - 可验证与可观测 | 审核子代理 C | 需修复后重审 | 5 | 5 | 3 |

## 2. UI 可观测性必检项投票

| 检查项 | 方向 A | 方向 B | 方向 C | 汇总 |
|--------|--------|--------|--------|------|
| UI 验证路径是否真实 | 是 | 是 | 部分是 | 存在覆盖缺失 |
| 是否存在内部状态误判 | 否 | 否 | 否 | 0/3 无误判 |
| 投票结果 | 0/3 | 0/3 | 1/3 | 最严格结论：存在 UI 问题 |

**UI 内部状态误判**：0/3 子代理发现。TC-F18-026/027 严格通过 `historyList.cells.count` 变化验证，不访问 store 层。

**UI 覆盖缺失**：方向 C 发现 TC-F18-021/023/033/040 四条 UI 相关测试用例缺少实际实现。

## 3. 必须修复项汇总（去重后 7 项）

### 3.1 README.md 修改文件清单遗漏 ClipMindApp.swift（A+B 共识）

- **问题**：README 第 41 行标称"修改文件（7 个）"，表格仅列 6 个，缺失 `ClipMind/App/ClipMindApp.swift`
- **修复**：在表格中补充 ClipMindApp.swift，职责为"新增 --UITEST_PREPOPULATE_SAMPLE_AND_REAL 启动参数处理 + prepopulateTestData(store:) 方法"

### 3.2 TC-F18-023 类型标签断言缺失但验收对照表标 PASS（A+B+C 共识 3/3）

- **问题**：testFirstLaunchShowsSamples 仅断言 `cells.count >= 10`，无类型标签断言；但验收对照表标记 ✅ PASS
- **修复**：在 testFirstLaunchShowsSamples 中追加类型标签断言（typeTag_code、typeTag_error）

### 3.3 TC-F18-033 UI 搜索测试缺失但声称"间接覆盖"（A+B+C 共识 3/3）

- **问题**：验收对照表声称"TC-F18-033 由 UI-SD-01 间接覆盖"，但 UI-SD-01 不执行搜索操作
- **修复**：新增 testUISearchErrorHitsSample 测试方法，或在验收对照表中明确标注为延后

### 3.4 phase-1 覆盖说明 38 条与实际不一致（B）

- **问题**：phase-1 声明覆盖 38 条，但 TC-F18-021/023/033/040 无对应测试方法，实际约 34 条
- **修复**：补充缺失测试方法后保持 38 条，或修正覆盖说明为实际数量

### 3.5 TC-F18-040 异步不阻塞 UI 未实际验证（C）

- **问题**：testFirstLaunchShowsSamples 未显式验证"主窗口立即可交互"
- **修复**：在引导完成后立即断言主窗口可见（不等数据加载）

### 3.6 TC-F18-021 completeOnboarding 触发注入测试缺失（C）

- **问题**：SampleDataSeederTests.swift 中无 testCompleteOnboardingTriggersSeeding 方法
- **修复**：新增单元测试验证 completeOnboarding 触发注入，或明确标注由 UI-SD-01 间接覆盖并更新测试用例表

### 3.7 UI 测试 alert 按钮定位错误（C）

- **问题**：testFirstLaunchShowsSamples 使用 `app.sheets.buttons["确定"]` 定位 alert 按钮，但 APIKeyGuideView 使用 `.alert` 修饰符
- **修复**：改为 `app.alerts.buttons["确定"]`

## 4. 建议修复项（自动跳过，记录备查）

1. TC-F18-009/010 状态未更新为 DEFERRED（测试用例表仍标 MISSING）
2. UI 测试预置数据方式与设计规范 9.3.3 偏离（设计规范说"测试 setup 直接写入"，计划用启动参数预置）
3. --UITEST_PREPOPULATE_SAMPLE_AND_REAL 同步阻塞 App 启动风险（实现时跳过 embeddings 或减量）
4. TC-F18-028 弱集成测试（设计评审摘要已列为可选优化）
5. phase-1 "UI 证据任务"表缺失 UI-AC-SD-02/03

## 5. 可选优化项（自动跳过）

1. testClearConfirmationCancelDoesNotClear 未映射 TC 编号
2. testMigrationAddsIsSampleColumn 间接验证 PRAGMA
3. TC-F18-040 覆盖较弱
4. CODING_STANDARDS Allman 要求与实际 K&R 风格不一致（项目层面问题）
5. UI-SD-01 引导流程超时设置与 CI 环境适配

## 6. 处理决策

- **必须修复项**：自动采纳并修复，修复后重新调度 3 子代理并行检查
- **建议修复项**：自动跳过（不涉及重大架构变化），记录到本摘要
- **可选优化项**：自动跳过

## 7. 版本记录

- v1.0（2026-07-14）：首次 check-plan 审核摘要，3 子代理均需修复后重审
- v1.1（2026-07-14）：第 2-3 轮审核结果汇总
  - 第 2 轮：7 项第 1 轮必须修复全部修复到位；新发现 2 项计数不一致（12→13、4→5），已修复；方向 C 通过
  - 第 3 轮：方向 A/C 通过，方向 B 发现 3 项遗留路径不一致（TC-F18-005/024/025），用户选择自动修复
  - 最终结论：3 方向全部通过，UI 可观测性 3/3 无内部状态误判

## 8. 最终审核结论

**check-plan 通过**。3 轮审核共修复 12 项必须修复项（7+2+3），3 方向全部通过。UI 可观测性 3/3 无内部状态误判。计划可提交并进入 TDD 实现阶段。
