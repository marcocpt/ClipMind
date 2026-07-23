# F2.1 文件名特殊符号处理：过滤 → 替换

> 日期：2026-07-23 | 功能：F2.1 自动保存到文件

## 问题描述

F2.1 文件名生成器（`FileNameGenerator.swift` D9 步骤 4）当前对特殊字符采用**过滤删除**策略，且字符集仅覆盖文件系统非法字符（`/ \ : * ? " < > | [ ]`）。

用户反馈：
- 复制内容含**标点符号**（中英文逗号、句号、问号等）、**Markdown 格式符号**（`#` `` ` `` `~` 等）、**Shell 特殊字符**（`%` `&` `;` `$` `(` `)` `{` `}` `'` `!` 等）时，文件名保留这些符号，导致：
  - 文件名在 shell/终端/AI 工具中需要手动转义
  - Markdown 链接显示混乱
  - 跨平台兼容性风险

期望行为：将这些特殊符号**替换为 `_`**（而非删除），保留分隔语义，提升可读性与安全性。

## 前置

- 无运行时日志（用户主动反馈，非崩溃/异常）
- 相关代码：`ClipMind/AutoSave/FileNameGenerator.swift`
- 相关设计：`docs/planning/P1/F2.1/F2.1_自动保存到文件_设计文档.md` D9 步骤 4、D16 URI 编码

## 根因调查

### 当前实现

`FileNameGenerator.swift` 步骤 4：
```swift
private static let illegalCharacters: Set<Character> = [
    "\n", "\r", "\t",
    "/", "\\",
    ":", "*", "?", "\"", "<", ">", "|",
    "[", "]"
]

let filtered = prefix.filter { !Self.illegalCharacters.contains($0) }
```

### 问题分析

1. **策略问题**：`filter` 直接删除字符，`"hello/world"` → `"helloworld"`，丢失分隔语义
2. **字符集不足**：未覆盖 Markdown 符号（`#` `` ` `` `~`）、Shell 特殊字符（`%` `&` `;` `$` `(` `)` `{` `}` `'` `!`）、中文标点（`，` `。` `！` `？` `：` `；` `""` `''` `（` `）` `【` `】` 《》` `—` `…` `·`）、英文标点（`,` `;` `:` `!` `?` `'` `(` `)`）

### 设计约束

- D9 步骤 4 原文："过滤非法字符" → 需修订为"替换特殊字符为 `_`"
- D16：`file://` URI 标准编码覆盖 `#` `%` 括号等，但文件名本身允许保留 → 现改为文件名直接替换，减少 URI 编码负担
- AC-10：保留中文 → 不受影响，中文字符不在替换集
- 步骤 5：首尾空白与首尾的点去除 → 需扩展为首尾 `_` 也去除
- 步骤 6：为空时备用文件名 → 需考虑全特殊字符内容替换后为空的情况

### 替换字符集定义

| 类别 | 字符 | 说明 |
|------|------|------|
| 路径分隔符 | `/` `\` | 文件系统非法 |
| 文件系统特殊 | `:` `*` `?` `"` `<` `>` `\|` | 文件系统非法 |
| Markdown 符号 | `#` `` ` `` `~` `[` `]` | 格式符号 |
| Shell 特殊 | `%` `&` `;` `$` `(` `)` `{` `}` `'` `!` | 需转义 |
| 中文标点 | `，` `。` `、` `；` `：` `！` `？` `“` `”` `‘` `’` `（` `）` `【` `】` `《` `》` `—` `…` `·` | 中文标点 |
| 英文标点 | `,` `;` `:` `!` `?` `'` `(` `)` | 英文标点（不含 `.` `-`） |

**保留字符**：中英文字母、数字、`.`（点，版本号/扩展名常用）、`-`（连字符）、`_`（下划线）、`+` `@`、空格（步骤 2 已折叠）、emoji。

**后处理**：连续 `_` 折叠为单个 `_`；首尾 `_` 去除。

## 红灯：测试用例

新增/更新测试覆盖：
- `testSpecialCharacterReplacement`：路径分隔符 + 文件系统特殊 → 替换为 `_`
- `testMarkdownSymbolsReplacement`：`#` `` ` `` `~` → 替换为 `_`
- `testShellSpecialCharsReplacement`：`%` `&` `;` `$` `(` `)` `{` `}` `'` `!` → 替换为 `_`
- `testChinesePunctuationReplacement`：`，` `。` `！` `？` 等 → 替换为 `_`
- `testEnglishPunctuationReplacement`：`,` `!` `?` `:` `;` `'` `(` `)` → 替换为 `_`
- `testConsecutiveUnderscoreCollapse`：连续特殊字符 → 折叠为单个 `_`
- `testLeadingTrailingUnderscoreTrim`：首尾 `_` 去除
- `testAllSpecialCharsUsesFallback`：全特殊字符 → `clip-{timestamp}` 备用名
- 更新 `testIllegalCharacterFiltering` → `testSpecialCharacterReplacement`

## 绿灯：修复实施

修改 `FileNameGenerator.swift`：
1. 重命名 `illegalCharacters` → `specialCharacters`
2. 扩大字符集（新增 Markdown/Shell/标点）
3. 步骤 4 从 `filter` 改为 `map { 替换为 _ }`
4. 新增步骤 4.5：折叠连续 `_`
5. 步骤 5 扩展：首尾 `_` 去除（与空白、点一起）

## 总结

- 策略变更：过滤删除 → 替换为 `_` + 折叠 + 修剪
- 字符集扩大：新增 Markdown 符号、Shell 特殊字符、中英文标点
- 保留：中文、字母、数字、`.` `-` `_` `+` `@` 空格 emoji
- 设计文档 D9 步骤 4 需同步修订（步骤 5 完成）
