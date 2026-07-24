> 最后更新：2026-07-24 | 版本：v1.0

# F2.1.1 保存成功 Toast 提示 手动验收脚本

**功能编号**：F2.1.1
**优先级**：P1（复赛扩展）
**适用阶段**：复赛扩展阶段（F2.1 自动保存到文件之后）
**前置文档**：`F2.1.1_保存成功Toast_需求文档.md`（v1.0）+ `F2.1.1_保存成功Toast_设计文档.md`（v1.1）+ `F2.1.1_保存成功Toast_视觉原型.html`（v1.2）+ `F2.1.1_保存成功Toast_测试用例表.md`（v1.1）

---

## 1. 验收范围

本脚本覆盖 XCUITest 无法自动化的 OS 边界场景（设计文档 §8.5 + 测试用例表第 1 节第 3 行手动测试），包括：

- AC-08 动画视觉效果录屏（视觉部分）
- R-05 源 App 全屏遮挡
- AC-10 App Sandbox 合规验证
- NFR-001 响应性能验证（≤0.3s）
- NFR-002 动画帧率验证（60fps）
- NFR-003 资源占用与释放验证
- AC-11 跨应用前台语义验证（手动部分）

**对应三层测试策略第 3 层**：仅验证 OS 边界行为，不重复 XCTest 已覆盖的业务逻辑，不重复 XCUITest 已覆盖的 UI 交互。

---

## 2. 前置条件

- 主 Scheme `ClipMind` 构建成功：`xcodebuild build -project ClipMind.xcodeproj -scheme ClipMind -configuration Debug` 通过
- F2.1 总开关启用，白名单含 Safari 与 Notes
- 保存目录配置为可写路径（如 `~/Documents/ClipMind-AutoSave`）
- 长度阈值默认 50 字
- 关闭其他可能干扰 Toast 显示的窗口管理工具（如 magnet、rectangle）

---

## 3. 验收用例

### 3.1 AC-08 动画视觉效果录屏

**对应 AC**：AC-08 进入/退出动画存在
**对应 FR**：FR-005（进入动画）、FR-006（退出动画）
**对应 NFR**：NFR-002（60fps 流畅）

**步骤：**
1. 启动 ClipMind App
2. 打开屏幕录制（macOS 系统屏幕录制 `Cmd+Shift+5` 或 QuickTime Player）
3. 切换到 Safari，复制一段 ≥50 字的长内容（如本文件前 100 字）
4. 观察屏幕顶部 Toast 出现，录制 0.5 秒
5. 等待 2 秒，观察 Toast 消失，录制 0.5 秒
6. 停止录制

**预期：**
- 进入动画：从顶部滑入 + 淡入，约 0.2 秒（FR-005）
- 退出动画：反向滑出 + 淡出，约 0.2 秒（FR-006）
- 动画流畅无卡顿（NFR-002）

**证据存放**：`docs/planning/P1/F2.1/recordings/2026-07-24-ac08-animation.mp4`

**验收记录**：

| 项 | 内容 |
|----|------|
| 验收日期 | |
| 验收人 | |
| 结果 | ⏸️ 待执行 |
| 录屏路径 | |

### 3.2 R-05 源 App 全屏遮挡

**对应风险**：R-05 源 App 全屏状态下 Toast 不可见
**对应 FR**：FR-011（不依赖窗口焦点）

**步骤：**
1. 启动 ClipMind App
2. 切换到 Safari，进入全屏模式（`Cmd+Ctrl+F`）
3. 在 Safari 中复制 ≥50 字长内容
4. 观察屏幕顶部

**预期：**
- Toast 在屏幕顶部居中显示（由 `NSPanel.level = .floating` 保证覆盖普通 App 窗口）
- 若 Safari 全屏遮挡 Toast，记录日志（属 R-05 已知风险，不在本特性范围，未来 FC-02 多种 Toast 类型扩展时考虑）

**证据存放**：`docs/planning/P1/F2.1/screenshots/2026-07-24-r05-fullscreen.png`

**验收记录**：

| 项 | 内容 |
|----|------|
| 验收日期 | |
| 验收人 | |
| 结果 | ⏸️ 待执行 |
| 截图路径 | |
| 是否被遮挡 | |

### 3.3 AC-10 App Sandbox 合规验证

**对应 AC**：AC-10 App Sandbox 合规
**对应 NFR**：NFR-006（App Sandbox 合规）
**对应约束**：C-06（合规优先）

**步骤：**
1. 主 Scheme 构建：
   ```bash
   xcodebuild build \
     -project ClipMind.xcodeproj \
     -scheme ClipMind \
     -configuration Debug \
     CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
   ```
2. 运行 App，触发保存成功（在 Safari 中复制 ≥50 字长内容）
3. 录屏整个 Toast 显示与消失过程（约 3 秒）
4. 检查 macOS 系统通知中心：是否有 TCC 权限弹窗残留

**预期：**
- 主 Scheme 构建成功
- Toast 显示与消失正常
- 无 TCC 权限弹窗（如辅助功能、屏幕录制、输入监控、文件夹访问等）
- macOS 通知中心无新增通知（C-03 不污染系统通知中心）

**证据存放**：
- 录屏：`docs/planning/P1/F2.1/recordings/2026-07-24-ac10-sandbox.mp4`
- 构建日志：`docs/planning/P1/F2.1/recordings/2026-07-24-ac10-build.log`

**验收记录**：

| 项 | 内容 |
|----|------|
| 验收日期 | |
| 验收人 | |
| 主 Scheme 构建结果 | |
| TCC 弹窗 | |
| 通知中心残留 | |
| 录屏路径 | |

### 3.4 NFR-001 响应性能验证

**对应 NFR**：NFR-001（通知接收到 Toast 出现延迟 ≤ 0.3 秒）

**步骤：**
1. 启动 Instruments（Time Profiler）
2. 启动 ClipMind App，开始录制
3. 切换到 Safari，复制 ≥50 字长内容
4. 观察 Toast 出现时机
5. 停止录制
6. 在 Instruments 中标记"复制操作"与"Toast 出现"两个时间点，计算延迟

**预期：**
- 保存成功到 Toast 出现延迟 ≤ 0.3 秒（含动画启动时间）
- 主线程耗时 < 100ms
- 通知回调主线程派发延迟 < 1ms（D6）

**证据存放**：`docs/planning/P1/F2.1/recordings/2026-07-24-nfr001-perf.trace`

**验收记录**：

| 项 | 内容 |
|----|------|
| 验收日期 | |
| 验收人 | |
| 复制时间点 | |
| Toast 出现时间点 | |
| 实测延迟 | |
| 是否 ≤ 0.3s | |

### 3.5 NFR-002 动画帧率验证

**对应 NFR**：NFR-002（进入/退出动画保持 60fps 流畅）

**步骤：**
1. 启动 Instruments（Core Animation 模板）
2. 启动 ClipMind App，开始录制
3. 触发保存成功，观察 Toast 进入动画
4. 等待 2 秒，观察 Toast 退出动画
5. 停止录制
6. 检查 fps 曲线

**预期：**
- 进入动画保持 60fps
- 退出动画保持 60fps
- 无掉帧（fps 不低于 55）

**证据存放**：`docs/planning/P1/F2.1/recordings/2026-07-24-nfr002-fps.trace`

**验收记录**：

| 项 | 内容 |
|----|------|
| 验收日期 | |
| 验收人 | |
| 进入动画 fps | |
| 退出动画 fps | |
| 是否 60fps | |

### 3.6 NFR-003 资源占用与释放验证

**对应 NFR**：NFR-003（Toast 显示期间不占用可感知 CPU/内存，消失后立即释放）

**步骤：**
1. 启动 Instruments（Allocations 模板）
2. 启动 ClipMind App，开始录制
3. 触发保存成功，等待 Toast 显示
4. 等待 Toast 消失
5. 再触发一次保存成功，重复 3-4 步骤 5 次
6. 停止录制
7. 在 Instruments 中筛选 `NSPanel` 与 `ToastView` 实例，检查创建与释放

**预期：**
- Toast 显示期间 CPU 占用不可感知（< 1%）
- Toast 显示期间内存占用 < 5MB
- Toast 消失后窗口对象立即释放（Allocations 显示 NSPanel 实例数归零）
- 5 次触发后无内存增长（无泄漏）

**证据存放**：`docs/planning/P1/F2.1/recordings/2026-07-24-nfr003-mem.trace`

**验收记录**：

| 项 | 内容 |
|----|------|
| 验收日期 | |
| 验收人 | |
| 显示期间 CPU | |
| 显示期间内存 | |
| 消失后 NSPanel 实例数 | |
| 5 次触发后内存增长 | |
| 是否无泄漏 | |

### 3.7 AC-11 跨应用前台语义验证

**对应 AC**：AC-11（Toast 不依赖窗口焦点，手动部分）

**步骤：**
1. 启动 ClipMind App
2. 切换到 Safari，使其处于前台（菜单栏显示 Safari 菜单）
3. 在 Safari 中复制 ≥50 字长内容
4. 截图（`Cmd+Shift+3`）
5. 检查菜单栏最左侧 App 名称

**预期：**
- Toast 在屏幕顶部居中显示
- Safari 仍处于前台（菜单栏显示 Safari 菜单）
- ClipMind 主窗口未被激活（不在 Dock 中显示为活动 App）

**证据存放**：`docs/planning/P1/F2.1/screenshots/2026-07-24-ac11-foreground.png`

**验收记录**：

| 项 | 内容 |
|----|------|
| 验收日期 | |
| 验收人 | |
| Toast 是否可见 | |
| Safari 是否前台 | |
| ClipMind 是否未抢焦点 | |
| 截图路径 | |

---

## 4. 验收结果汇总

| 用例 | 对应 AC/NFR | 验收日期 | 验收人 | 结果 | 证据路径 |
|------|------------|---------|-------|------|---------|
| AC-08 动画 | AC-08, NFR-002 | | | ⏸️ 待执行 | |
| R-05 全屏 | R-05, FR-011 | | | ⏸️ 待执行 | |
| AC-10 Sandbox | AC-10, NFR-006 | | | ⏸️ 待执行 | |
| NFR-001 性能 | NFR-001 | | | ⏸️ 待执行 | |
| NFR-002 帧率 | NFR-002 | | | ⏸️ 待执行 | |
| NFR-003 资源 | NFR-003 | | | ⏸️ 待执行 | |
| AC-11 前台 | AC-11 | | | ⏸️ 待执行 | |

---

## 5. 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-24 | 初始版本，覆盖 7 个手动验收用例（AC-08 动画、R-05 全屏、AC-10 Sandbox、NFR-001 性能、NFR-002 帧率、NFR-003 资源、AC-11 前台），对齐测试用例表第 1 节第 3 行手动测试策略 |
