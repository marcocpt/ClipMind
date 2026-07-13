# 快捷键无法唤醒 app

## 问题描述

用户按下预设的全局快捷键（默认 cmd+shift+v）时，ClipMind app 无法从隐藏/后台状态激活到前台。

## 前置信息

- 日志来源：无运行日志（用户选择跳过日志获取）
- 复现条件：app 已启动但非前台时按快捷键无响应
- 期望行为：按快捷键后 app 立即激活到前台

## 根因调查

### 代码审查

1. **AppSettings.swift** (L11): `var hotkey: String = "cmd+shift+v"` — 配置已存储
2. **HotkeyRecorder.swift**: 仅录制快捷键配置并写入 AppSettings，不负责注册全局监听
3. **StatusItemController.swift**: 只处理状态栏按钮点击（togglePopover），无快捷键逻辑
4. **ClipMindApp.swift / AppDelegate**:
   - `applicationDidFinishLaunching` 调用 `configureActivationPolicy()`
   - `configureActivationPolicy()` 设置 activation policy、创建 StatusItemController、启动服务
   - `handleOpenMainWindow()` 已有激活 app 到前台的逻辑（通过 `.openMainWindow` 通知触发）

### 关键发现

搜索整个 `ClipMind/` 源码目录：
- `Carbon` — 无匹配
- `RegisterEventHotKey` — 无匹配
- `InstallEventHandler` — 无匹配
- `EventHotKey` — 无匹配
- `HotkeyService` / `GlobalHotkey` — 无匹配

**全局快捷键注册逻辑完全缺失**。虽然用户可以配置快捷键（HotkeyRecorder），配置也正确存储（AppSettings.hotkey），但没有任何代码读取这个配置并使用 Carbon API 注册全局快捷键监听器。`AppDelegate` 从未调用过快捷键注册。

### 数据流

```
用户配置快捷键 → HotkeyRecorder → AppSettings.hotkey（存储）
                                          ↓
                               [缺失] 应读取配置并注册全局快捷键
                                          ↓
                      [缺失] 快捷键触发 → 发送 .openMainWindow 通知
                                          ↓
            AppDelegate.handleOpenMainWindow()（已存在）→ 激活 app
```

### 假设与验证

**假设**：全局快捷键注册功能从未实现，导致按快捷键时无代码响应。

**验证**：全局搜索确认无 Carbon API 调用、无全局快捷键监听代码。假设成立。

## 根本原因

全局快捷键注册功能缺失。需要：
1. 在 `HotkeyFormatter` 添加 `parse(stored:)` 方法，将存储格式解析为 Carbon API 需要的修饰键 mask 和 keyCode
2. 创建 `GlobalHotkeyService`，使用 Carbon API 的 `RegisterEventHotKey` 注册全局快捷键
3. 快捷键触发时发送 `.openMainWindow` 通知（已有 `handleOpenMainWindow` 处理激活）
4. 在 `AppDelegate` 中初始化 `GlobalHotkeyService`

## 红灯测试

`ClipMindTests/App/GlobalHotkeyServiceTests.swift` — 测试 `HotkeyFormatter.parse(stored:)` 和 `GlobalHotkeyService`，因代码不存在编译失败。

## 绿灯修复

### 修复方案

1. **HotkeyFormatter.parse(stored:)** — 新增方法，将存储格式 "cmd+shift+v" 解析为 Carbon API 需要的 `ParsedHotkey(modifiers:keyCode:)`
2. **HotkeyRegistering 协议** — 将 Carbon API 调用抽象为协议，便于测试注入 mock
3. **CarbonHotkeyRegistrar** — 基于 Carbon API（RegisterEventHotKey + InstallEventHandler）的注册器实现
4. **GlobalHotkeyService** — 读取 AppSettings.hotkey 配置，通过注册器注册全局快捷键，触发时发送 `.openMainWindow` 通知
5. **AppDelegate.setupHotkeyService()** — 在 `configureActivationPolicy()` 中初始化 GlobalHotkeyService

### 修改文件

- `ClipMind/UI/Settings/HotkeyRecorder.swift` — 添加 `parse(stored:)` 方法和 `ParsedHotkey` 结构体
- `ClipMind/App/GlobalHotkeyService.swift` — 新建，包含 HotkeyRegistering 协议、CarbonHotkeyRegistrar、GlobalHotkeyService
- `ClipMind/App/ClipMindApp.swift` — 添加 hotkeyService 属性和 setupHotkeyService() 调用
- `ClipMindTests/App/GlobalHotkeyServiceTests.swift` — 新建，13 个测试用例

### 单测试文件绿灯结果

13 个测试全部通过（0.017 秒）：
- 7 个 HotkeyFormatter.parse(stored:) 解析测试
- 5 个 GlobalHotkeyService 注册/注销/失败处理测试
- 1 个快捷键触发通知测试

### 全量回归

延迟到步骤 3.3.5 走 CI 验证。

## 流程图

```
应用启动
  │
  ▼
applicationDidFinishLaunching
  │
  ▼
configureActivationPolicy()
  │
  ├─ hasCompletedOnboarding == true
  │   │
  │   ├─ setActivationPolicy(.accessory)
  │   ├─ StatusItemController.setup()
  │   ├─ setupServices()
  │   └─ setupHotkeyService()  ← [新增]
  │       │
  │       ▼
  │   GlobalHotkeyService.init(hotkey:)
  │       │
  │       ▼
  │   HotkeyFormatter.parse(stored:)  ← 解析 "cmd+shift+v"
  │       │
  │       ├─ 解析成功 → registrar.register(keyCode:modifiers:onTriggered:)
  │       │   │
  │       │   ├─ InstallEventHandler (Carbon API)
  │       │   ├─ RegisterEventHotKey (Carbon API)
  │       │   └─ 返回 true/false
  │       │
  │       └─ 解析失败 → 记录错误日志，不注册
  │
  └─ hasCompletedOnboarding == false
      └─ setActivationPolicy(.regular) (不注册快捷键)

快捷键按下时:
  │
  ▼
Carbon 事件处理器回调
  │
  ▼
GlobalHotkeyService.handleHotkeyPressed()
  │
  ▼
NotificationCenter.post(.openMainWindow)
  │
  ▼
AppDelegate.handleOpenMainWindow()
  │
  ├─ setActivationPolicy(.regular)
  ├─ activate(ignoringOtherApps: true)
  └─ makeKeyAndOrderFront (主窗口前置)
```

## 时序图

```
用户          macOS          CarbonHotkeyRegistrar     GlobalHotkeyService      AppDelegate
 │             │                     │                        │                       │
 │  按下快捷键  │                     │                        │                       │
 │────────────▶│                     │                        │                       │
 │             │  HotKeyPressed 事件 │                        │                       │
 │             │────────────────────▶│                        │                       │
 │             │                     │  onTriggered()         │                       │
 │             │                     │───────────────────────▶│                       │
 │             │                     │                        │  post(.openMainWindow)│
 │             │                     │                        │──────────────────────▶│
 │             │                     │                        │                       │ setActivationPolicy(.regular)
 │             │                     │                        │                       │ activate(ignoringOtherApps:)
 │             │                     │                        │                       │ makeKeyAndOrderFront
 │  看到主窗口  │                     │                        │                       │
 │◀────────────│                     │                        │                       │
```
