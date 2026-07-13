/**
 * ClipMind Web 交互预览页 - 交互逻辑
 * 实现 4 个核心流程：复制 → 分类 → 搜索 → 处理
 */

(function () {
  'use strict';

  // ============================================================
  // Mock 数据
  // ============================================================

  /** 6 种示例内容（每种类型至少 1 条） */
  const MOCK_EXAMPLES = [
    {
      id: 'ex-code',
      type: 'CODE',
      label: 'Swift 代码片段',
      content: 'func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {\n    let window = UIWindow(frame: UIScreen.main.bounds)\n    window.rootViewController = UINavigationController(rootViewController: MainViewController())\n    window.makeKeyAndVisible()\n    return true\n}'
    },
    {
      id: 'ex-error',
      type: 'ERROR',
      label: 'Xcode 崩溃日志',
      content: 'Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value\n  at ClipMind.ViewController.viewDidLoad() (ViewController.swift:42)\n  at UIKit.UIScreen.main()\n  at Foundation._initializeMain()'
    },
    {
      id: 'ex-link',
      type: 'LINK',
      label: 'Apple 开发者文档链接',
      content: 'https://developer.apple.com/documentation/swiftui/navigationstack'
    },
    {
      id: 'ex-meeting',
      type: 'MEETING',
      label: '产品周会纪要',
      content: '产品周会 2026.06.18\n参会人：张三、李四、王五\n议题：Q2 产品迭代评审\n1. 登录模块需在 06.25 前完成，负责人张三\n2. 支付联调推迟到 06.28，李四跟进\n3. 王五负责下周用户调研问卷设计'
    },
    {
      id: 'ex-todo',
      type: 'TODO',
      label: '本周任务清单',
      content: 'TODO - 本周任务：\n- [ ] 完成登录模块 UI 设计\n- [ ] 修复剪贴板监听崩溃问题\n- [x] 提交 App Store 审核\n- [ ] 编写用户使用文档\n截止时间：周五下班前'
    },
    {
      id: 'ex-text',
      type: 'TEXT',
      label: 'Transformer 论文摘录',
      content: 'The Transformer follows this overall architecture using stacked self-attention and point-wise, fully connected layers for both the encoder and decoder, shown in the left and right halves of Figure 1, respectively.'
    }
  ];

  /** 分类规则：基于关键词与正则模式匹配 */
  const CLASSIFICATION_RULES = {
    CODE: {
      keywords: ['func', 'def', 'class ', 'import ', 'const ', 'let ', 'var ', 'function', 'return ', 'public ', 'private ', 'override', '->', '=>', '{', '}', ';', 'UIWindow', 'UIViewController'],
      patterns: [/func\s+\w+\s*\(/, /def\s+\w+\s*\(/, /class\s+\w+/, /import\s+\w+/, /=>\s*[\({]/, /\)\s*->\s*\w+/, /\{\s*\n?\s*\}/],
      color: 'violet'
    },
    ERROR: {
      keywords: ['error', 'Error', 'exception', 'Exception', 'fatal', 'Fatal', 'crash', 'Traceback', 'Thread', 'nil', 'unwrapping', 'stack'],
      patterns: [/Thread\s+\d+/, /Error:/, /Exception/, /fatal error/i, /Traceback/, /at\s+[\w.]+\(\)/, /found nil/i],
      color: 'rose'
    },
    LINK: {
      keywords: ['http://', 'https://', 'www.', '.com', '.org', '.io', '.dev', '.apple', '.github'],
      patterns: [/https?:\/\/[^\s]+/, /^www\.[^\s]+/, /[a-z0-9-]+\.[a-z]{2,}\/[^\s]+/],
      color: 'cyan'
    },
    MEETING: {
      keywords: ['会议', '参会', '议题', '纪要', 'meeting', 'attendees', '主持', '讨论', '评审', '周会', '参会人', '决策'],
      patterns: [/会议/, /参会/, /议题/, /周会/, /meeting/i],
      color: 'emerald'
    },
    TODO: {
      keywords: ['TODO', 'todo', '待办', '任务', '负责', 'deadline', '截止', '需完成', '- [ ]', '- [x]', '跟进', '清单'],
      patterns: [/TODO/i, /- \[[ x]\]/, /待办/, /截止/, /任务/],
      color: 'amber'
    }
  };

  /** 搜索语义映射：将自然语言查询映射到类型/关键词 */
  const SEARCH_SEMANTIC_MAP = {
    '报错': { types: ['ERROR'], keywords: ['error', 'fatal', 'nil', 'Thread', 'crash'] },
    '错误': { types: ['ERROR'], keywords: ['error', 'fatal', 'nil', 'Thread', 'crash'] },
    'bug': { types: ['ERROR'], keywords: ['error', 'fatal', 'nil', 'Thread', 'crash'] },
    '代码': { types: ['CODE'], keywords: ['func', 'class', 'import', 'let', 'var', 'return'] },
    '函数': { types: ['CODE'], keywords: ['func', 'function', 'def', 'return'] },
    '链接': { types: ['LINK'], keywords: ['http', 'https', 'www', '.com', '.org'] },
    '网址': { types: ['LINK'], keywords: ['http', 'https', 'www', '.com', '.org'] },
    '会议': { types: ['MEETING'], keywords: ['会议', '参会', '议题', '周会'] },
    '纪要': { types: ['MEETING'], keywords: ['会议', '参会', '议题', '纪要'] },
    '待办': { types: ['TODO'], keywords: ['TODO', '待办', '任务', '截止'] },
    '任务': { types: ['TODO'], keywords: ['TODO', '待办', '任务', '截止'] },
    '论文': { types: ['TEXT'], keywords: ['transformer', 'attention', 'encoder', 'decoder'] },
    '文章': { types: ['TEXT'], keywords: ['transformer', 'attention', 'encoder', 'decoder'] }
  };

  /** 类型显示配置 */
  const TYPE_CONFIG = {
    CODE: { label: 'CODE', tagClass: 'tag-code', color: 'var(--accent-violet)' },
    ERROR: { label: 'ERROR', tagClass: 'tag-error', color: 'var(--accent-rose)' },
    LINK: { label: 'LINK', tagClass: 'tag-link', color: 'var(--accent-cyan)' },
    MEETING: { label: 'MEETING', tagClass: 'tag-meeting', color: 'var(--accent-emerald)' },
    TODO: { label: 'TODO', tagClass: 'tag-todo', color: 'var(--accent-amber)' },
    TEXT: { label: 'TEXT', tagClass: 'tag-text', color: 'var(--text-1)' }
  };

  // ============================================================
  // 状态管理
  // ============================================================

  /** 剪贴板历史（共享状态，4 个流程共同操作） */
  let clipboardHistory = [];
  let historyIdCounter = 0;

  // ============================================================
  // 工具函数
  // ============================================================

  /** 生成唯一 ID */
  function generateId() {
    historyIdCounter += 1;
    return 'clip-' + historyIdCounter;
  }

  /** 获取内容的简短预览（单行） */
  function getPreview(content, maxLength) {
    const max = maxLength || 60;
    const firstLine = content.split('\n')[0].trim();
    if (firstLine.length <= max) return firstLine;
    return firstLine.substring(0, max) + '...';
  }

  /** HTML 转义 */
  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  /** 获取相对时间文本 */
  function getRelativeTime() {
    return '刚刚';
  }

  // ============================================================
  // 流程 1 & 2：复制内容 + 自动分类
  // ============================================================

  /**
   * 基于关键词与正则模式对内容进行自动分类
   * @param {string} content - 待分类内容
   * @returns {string} 类型标签（CODE/ERROR/LINK/MEETING/TODO/TEXT）
   */
  function classifyContent(content) {
    const scores = {};

    Object.keys(CLASSIFICATION_RULES).forEach(function (type) {
      const rule = CLASSIFICATION_RULES[type];
      let score = 0;

      // 关键词匹配
      rule.keywords.forEach(function (kw) {
        if (content.toLowerCase().includes(kw.toLowerCase())) {
          score += 1;
        }
      });

      // 正则模式匹配（权重更高）
      rule.patterns.forEach(function (pattern) {
        if (pattern.test(content)) {
          score += 3;
        }
      });

      scores[type] = score;
    });

    // 找出得分最高的类型
    let bestType = 'TEXT';
    let bestScore = 0;
    Object.keys(scores).forEach(function (type) {
      if (scores[type] > bestScore) {
        bestScore = scores[type];
        bestType = type;
      }
    });

    return bestScore > 0 ? bestType : 'TEXT';
  }

  /** 渲染示例内容列表 */
  function renderExampleList() {
    const container = document.getElementById('example-list');
    if (!container) return;

    const html = MOCK_EXAMPLES.map(function (ex) {
      const config = TYPE_CONFIG[ex.type];
      return '' +
        '<div class="example-item" role="listitem" data-id="' + ex.id + '">' +
          '<span class="example-tag ' + config.tagClass + '">' + config.label + '</span>' +
          '<div class="example-content">' +
            '<div class="example-preview">' + escapeHtml(getPreview(ex.content, 50)) + '</div>' +
            '<div class="example-label">' + escapeHtml(ex.label) + '</div>' +
          '</div>' +
          '<button class="copy-btn" data-id="' + ex.id + '" aria-label="复制 ' + escapeHtml(ex.label) + '">' +
            '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>' +
            '复制' +
          '</button>' +
        '</div>';
    }).join('');

    container.innerHTML = html;

    // 绑定复制按钮事件
    container.querySelectorAll('.copy-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        handleCopy(btn.dataset.id);
      });
    });
  }

  /**
   * 处理复制操作
   * 1. 显示 toast 提示
   * 2. 将内容加入历史
   * 3. 触发自动分类动画
   * 4. 更新搜索和处理组件状态
   */
  function handleCopy(exampleId) {
    const example = MOCK_EXAMPLES.find(function (ex) { return ex.id === exampleId; });
    if (!example) return;

    // 按钮复制成功视觉反馈
    const btn = document.querySelector('.copy-btn[data-id="' + exampleId + '"]');
    const item = document.querySelector('.example-item[data-id="' + exampleId + '"]');
    if (btn) {
      btn.classList.add('copied');
      btn.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>已复制';
      setTimeout(function () {
        btn.classList.remove('copied');
        btn.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>复制';
      }, 2000);
    }
    if (item) {
      item.classList.add('copied');
      setTimeout(function () { item.classList.remove('copied'); }, 2000);
    }

    // Toast 提示
    showToast('success', '已复制到剪贴板：' + example.label);

    // 加入历史并触发分类
    addToHistory(example);
  }

  /**
   * 将内容加入剪贴板历史并触发自动分类动画
   */
  function addToHistory(example) {
    const historyItem = {
      id: generateId(),
      content: example.content,
      label: example.label,
      type: null,
      time: getRelativeTime(),
      classifying: true
    };

    clipboardHistory.unshift(historyItem);
    renderHistory();
    updateHistoryCount();
    updateProcessSelector();

    // 模拟分类过程：延迟后显示分类结果
    setTimeout(function () {
      historyItem.type = classifyContent(historyItem.content);
      historyItem.classifying = false;
      renderHistory();
      updateProcessSelector();
      showToast('info', '自动分类完成：' + TYPE_CONFIG[historyItem.type].label);
    }, 1200);
  }

  /** 渲染剪贴板历史列表 */
  function renderHistory() {
    const container = document.getElementById('history-list');
    if (!container) return;

    if (clipboardHistory.length === 0) {
      container.innerHTML = '' +
        '<div class="empty-state" id="empty-history">' +
          '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/></svg>' +
          '<p>暂无内容，请从左侧"复制演示内容"</p>' +
        '</div>';
      return;
    }

    const html = clipboardHistory.map(function (item) {
      const config = item.type ? TYPE_CONFIG[item.type] : null;
      const tagHtml = item.classifying
        ? '<span class="classifying-indicator"><span class="spinner"></span>识别中</span>'
        : '<span class="tag ' + config.tagClass + '">' + config.label + '</span>';

      return '' +
        '<div class="history-item' + (item.classifying ? ' classifying' : '') + '" role="listitem" data-id="' + item.id + '">' +
          '<div class="history-item-row">' + tagHtml + '</div>' +
          '<div class="history-item-content">' + escapeHtml(getPreview(item.content, 70)) + '</div>' +
          '<div class="history-item-meta">' +
            '<span>' + escapeHtml(item.label) + '</span>' +
            '<span>' + item.time + '</span>' +
          '</div>' +
        '</div>';
    }).join('');

    container.innerHTML = html;
  }

  /** 更新历史计数 */
  function updateHistoryCount() {
    const el = document.getElementById('history-count');
    if (el) {
      el.textContent = clipboardHistory.length + ' 条';
    }
  }

  // ============================================================
  // 流程 3：语义搜索
  // ============================================================

  /**
   * 语义搜索算法
   * 支持自然语言查询、类型语义映射、模糊关键词匹配
   * @param {string} query - 用户输入的查询
   * @returns {Array} 搜索结果数组（按相关度排序）
   */
  function searchContent(query) {
    if (!query || !query.trim()) return [];

    const queryLower = query.toLowerCase().trim();
    const results = [];

    clipboardHistory.forEach(function (item) {
      if (!item.type) return; // 跳过尚未分类完成的内容

      let score = 0;
      const contentLower = item.content.toLowerCase();
      const labelLower = item.label.toLowerCase();

      // 1. 语义映射匹配（如"报错"匹配 ERROR 类型）
      Object.keys(SEARCH_SEMANTIC_MAP).forEach(function (key) {
        if (queryLower.includes(key.toLowerCase())) {
          const semantic = SEARCH_SEMANTIC_MAP[key];
          if (semantic.types.includes(item.type)) {
            score += 40;
          }
          semantic.keywords.forEach(function (kw) {
            if (contentLower.includes(kw.toLowerCase())) {
              score += 15;
            }
          });
        }
      });

      // 2. 直接关键词匹配（拆分查询为多个词）
      const queryWords = queryLower.split(/[\s,，。、]+/).filter(function (w) { return w.length > 0; });
      queryWords.forEach(function (word) {
        if (contentLower.includes(word)) {
          score += 20;
        }
        if (labelLower.includes(word)) {
          score += 15;
        }
      });

      // 3. 模糊匹配（单个字符重叠）
      if (score === 0) {
        let charMatches = 0;
        for (let i = 0; i < queryLower.length; i++) {
          if (contentLower.includes(queryLower[i])) {
            charMatches += 1;
          }
        }
        if (charMatches > queryLower.length * 0.4) {
          score += 10;
        }
      }

      // 4. 类型标签匹配
      if (queryLower.includes(item.type.toLowerCase())) {
        score += 30;
      }

      if (score > 0) {
        results.push({
          item: item,
          score: score,
          maxScore: 100
        });
      }
    });

    // 计算相关度百分比并排序
    const maxScore = results.length > 0 ? Math.max.apply(null, results.map(function (r) { return r.score; })) : 1;
    results.forEach(function (r) {
      r.relevance = Math.min(99, Math.round((r.score / maxScore) * 100));
      if (r.score === maxScore) r.relevance = Math.max(r.relevance, 95);
    });

    results.sort(function (a, b) { return b.score - a.score; });
    return results;
  }

  /** 执行搜索并渲染结果 */
  function executeSearch(query) {
    const container = document.getElementById('search-results');
    if (!container) return;

    if (clipboardHistory.length === 0) {
      container.innerHTML = '' +
        '<div class="empty-state">' +
          '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>' +
          '<p>先复制一些内容，再输入关键词搜索</p>' +
        '</div>';
      return;
    }

    const results = searchContent(query);

    if (results.length === 0) {
      container.innerHTML = '<div class="search-no-result">未找到匹配的内容，试试其他关键词</div>';
      return;
    }

    const html = results.map(function (r) {
      const item = r.item;
      const config = TYPE_CONFIG[item.type];
      const preview = escapeHtml(getPreview(item.content, 60));
      const highlighted = highlightMatch(preview, query);

      return '' +
        '<div class="search-result-item" role="listitem">' +
          '<div class="result-relevance">' + r.relevance + '%</div>' +
          '<div class="result-info">' +
            '<div class="result-title-row">' +
              '<span class="result-type-tag ' + config.tagClass + '">' + config.label + '</span>' +
              '<span style="font-size:11px;color:var(--text-3)">' + escapeHtml(item.label) + '</span>' +
            '</div>' +
            '<div class="result-content">' + highlighted + '</div>' +
          '</div>' +
        '</div>';
    }).join('');

    container.innerHTML = html;
  }

  /** 高亮搜索匹配关键词 */
  function highlightMatch(text, query) {
    if (!query) return text;
    const queryWords = query.split(/[\s,，。、]+/).filter(function (w) { return w.length > 0; });
    let result = text;
    queryWords.forEach(function (word) {
      if (word.length < 1) return;
      const escaped = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const regex = new RegExp(escaped, 'gi');
      result = result.replace(regex, '<em>$&</em>');
    });
    // 语义关键词高亮
    Object.keys(SEARCH_SEMANTIC_MAP).forEach(function (key) {
      if (query.toLowerCase().includes(key.toLowerCase())) {
        SEARCH_SEMANTIC_MAP[key].keywords.forEach(function (kw) {
          const escaped = kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
          const regex = new RegExp(escaped, 'gi');
          result = result.replace(regex, '<em>$&</em>');
        });
      }
    });
    return result;
  }

  // ============================================================
  // 流程 4：一键处理
  // ============================================================

  /**
   * 生成 AI 处理的 Mock 响应
   * @param {string} action - 处理类型（summarize/translate/rewrite/extract）
   * @param {object} item - 历史内容项
   * @returns {string} 处理结果文本
   */
  function getProcessResult(action, item) {
    const content = item.content;
    const type = item.type;

    if (action === 'summarize') {
      return getSummarizeResult(content, type);
    }
    if (action === 'translate') {
      return getTranslateResult(content, type);
    }
    if (action === 'rewrite') {
      return getRewriteResult(content, type);
    }
    if (action === 'extract') {
      return getExtractResult(content, type);
    }
    return '处理完成';
  }

  /** 智能总结 Mock */
  function getSummarizeResult(content, type) {
    if (type === 'CODE') {
      return '▸ 代码摘要\n' +
        '该代码为 iOS App 启动入口，主要功能：\n' +
        '1. 创建 UIWindow 并设置屏幕尺寸\n' +
        '2. 将 MainViewController 作为根视图控制器\n' +
        '3. 使用 UINavigationController 包裹导航\n' +
        '4. 将窗口设为主窗口并显示\n\n' +
        '▸ 技术要点\n使用了 UIApplication 生命周期方法，通过 UIWindow 管理视图层级。';
    }
    if (type === 'ERROR') {
      return '▸ 错误摘要\n' +
        '错误类型：Optional 强制解包时遇到 nil 值\n' +
        '错误位置：ViewController.swift 第 42 行\n' +
        '调用栈：viewDidLoad() → UIScreen.main()\n\n' +
        '▸ 修复建议\n使用 if let 或 guard let 进行安全解包，避免强制解包可选值。';
    }
    if (type === 'LINK') {
      return '▸ 链接摘要\n' +
        '该链接指向 Apple 官方 SwiftUI 文档。\n' +
        '主题：NavigationStack 导航栈组件\n' +
        '适用：iOS 16+ / macOS 13+\n\n' +
        '▸ 核心内容\nNavigationStack 是 SwiftUI 中用于管理导航层级的容器，替代已废弃的 NavigationView。';
    }
    if (type === 'MEETING') {
      return '▸ 会议摘要\n' +
        '时间：2026.06.18\n' +
        '参会：张三、李四、王五\n' +
        '议题：Q2 产品迭代评审\n\n' +
        '▸ 核心决策\n1. 登录模块 06.25 前交付（张三）\n2. 支付联调推迟至 06.28（李四）\n3. 下周启动用户调研（王五）';
    }
    if (type === 'TODO') {
      return '▸ 待办清单摘要\n' +
        '本周共 4 项任务，已完成 1 项，待完成 3 项\n' +
        '完成进度：25%\n\n' +
        '▸ 关键任务\n1. 登录模块 UI 设计（未完成）\n2. 修复剪贴板监听崩溃（未完成）\n3. 编写用户使用文档（未完成）\n4. 提交 App Store 审核（已完成）';
    }
    return '▸ 内容摘要\n' +
      '该内容讨论了 Transformer 架构的整体设计。\n\n' +
      '▸ 核心要点\n' +
      '1. 采用堆叠的自注意力层\n' +
      '2. 使用全连接层（point-wise）\n' +
      '3. 编码器与解码器均使用相同结构\n' +
      '4. 通过 Figure 1 展示左右两半部分';
  }

  /** 即时翻译 Mock */
  function getTranslateResult(content, type) {
    if (type === 'CODE') {
      return '▸ 中文注释翻译\n' +
        '// 应用启动入口函数\n' +
        'func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: ...) -> Bool {\n' +
        '    // 创建主窗口，尺寸为屏幕大小\n' +
        '    let window = UIWindow(frame: UIScreen.main.bounds)\n' +
        '    // 设置导航控制器为根视图\n' +
        '    window.rootViewController = UINavigationController(rootViewController: MainViewController())\n' +
        '    // 设为关键窗口并显示\n' +
        '    window.makeKeyAndVisible()\n' +
        '    return true\n' +
        '}';
    }
    if (type === 'ERROR') {
      return '▸ 错误信息翻译\n' +
        '线程 1：致命错误：在解包可选值时发现 nil\n' +
        '  位于 ClipMind.ViewController.viewDidLoad() (ViewController.swift:42)\n' +
        '  位于 UIKit.UIScreen.main()\n' +
        '  位于 Foundation._initializeMain()\n\n' +
        '▸ 原因分析\n试图对一个为 nil 的可选值进行强制解包（!），导致运行时崩溃。';
    }
    if (type === 'TEXT') {
      return '▸ 中文翻译\n' +
        'Transformer 遵循这一整体架构，在编码器和解码器中均使用堆叠的自注意力层和逐位置的全连接层，分别如图 1 的左半部分和右半部分所示。\n\n' +
        '▸ 关键术语\n' +
        '• self-attention：自注意力机制\n' +
        '• point-wise fully connected layers：逐位置全连接层\n' +
        '• encoder/decoder：编码器/解码器';
    }
    if (type === 'LINK') {
      return '▸ 链接信息翻译\n' +
        '链接：https://developer.apple.com/documentation/swiftui/navigationstack\n\n' +
        '▸ 页面标题\nSwiftUI NavigationStack 文档\n\n' +
        '▸ 摘要翻译\nNavigationStack 是一个容器视图，用于管理 SwiftUI 中的导航栈。它提供了堆栈式的导航体验，支持 push 和 pop 操作。';
    }
    return '▸ 翻译结果\n' + content + '\n\n（该内容为中文，已提供原文展示。如需翻译为其他语言，请选择英文内容。）';
  }

  /** 智能改写 Mock */
  function getRewriteResult(content, type) {
    if (type === 'CODE') {
      return '▸ 优化改写\n' +
        '// 优化后的启动入口 - 使用 guard let 安全解包\n' +
        'func application(_ application: UIApplication,\n' +
        '    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?\n' +
        ') -> Bool {\n' +
        '    let window = UIWindow(frame: UIScreen.main.bounds)\n' +
        '    let rootVC = MainViewController()\n' +
        '    window.rootViewController = UINavigationController(rootViewController: rootVC)\n' +
        '    window.makeKeyAndVisible()\n' +
        '    self.window = window\n' +
        '    return true\n' +
        '}\n\n' +
        '▸ 改进点：增加 window 属性引用，优化参数换行格式';
    }
    if (type === 'ERROR') {
      return '▸ 修复后的安全代码\n' +
        'guard let value = optionalValue else {\n' +
        '    print("Warning: optionalValue is nil")\n' +
        '    return\n' +
        '}\n' +
        '// 使用 value 进行后续操作\n\n' +
        '▸ 改写说明\n将强制解包（!）改为 guard let 安全解包，避免运行时崩溃。';
    }
    if (type === 'MEETING') {
      return '▸ 会议纪要改写（精简版）\n' +
        '【产品周会 2026.06.18】\n' +
        '参会：张三、李四、王五\n' +
        '议题：Q2 迭代评审\n\n' +
        '决议：\n' +
        '• 登录模块 → 张三，06.25 交付\n' +
        '• 支付联调 → 李四，06.28 推进\n' +
        '• 用户调研 → 王五，下周启动';
    }
    if (type === 'TODO') {
      return '▸ 任务清单改写（优先级排序）\n' +
        '🔴 高优先级\n' +
        '  □ 修复剪贴板监听崩溃问题（影响核心功能）\n' +
        '  □ 完成登录模块 UI 设计\n\n' +
        '🟡 中优先级\n' +
        '  □ 编写用户使用文档\n\n' +
        '🟢 已完成\n' +
        '  ✅ 提交 App Store 审核\n\n' +
        '截止：周五下班前';
    }
    return '▸ 改写结果（更简洁的学术表达）\n' +
      'Transformer 的整体架构由编码器和解码器组成，两者均采用堆叠的自注意力机制与逐位置全连接层，如图 1 的左右两部分所示。\n\n' +
      '▸ 改写说明\n调整了句式结构，使表达更紧凑，同时保留核心技术术语。';
  }

  /** 提取待办 Mock */
  function getExtractResult(content, type) {
    if (type === 'MEETING') {
      return '▸ 已提取 3 项待办\n\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>登录模块完成 · <span class="assignee">张三</span> · 06.25</span></div>\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>支付联调跟进 · <span class="assignee">李四</span> · 06.28</span></div>\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>用户调研问卷设计 · <span class="assignee">王五</span> · 下周</span></div>\n\n' +
        '▸ 自动归档至"产品迭代"项目';
    }
    if (type === 'TODO') {
      return '▸ 已提取 4 项待办\n\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>完成登录模块 UI 设计</span></div>\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>修复剪贴板监听崩溃问题</span></div>\n' +
        '<div class="todo-item"><span class="checkbox">✅</span><span>提交 App Store 审核（已完成）</span></div>\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>编写用户使用文档</span></div>\n\n' +
        '▸ 截止时间：周五下班前';
    }
    if (type === 'ERROR') {
      return '▸ 从报错中提取待办\n\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>检查 ViewController.swift:42 处的 Optional 解包</span></div>\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>使用 guard let 替换强制解包</span></div>\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>添加单元测试覆盖 nil 场景</span></div>';
    }
    if (type === 'CODE') {
      return '▸ 从代码中提取待办\n\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>为 MainViewController 添加初始化测试</span></div>\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>验证 UINavigationController 配置是否正确</span></div>\n' +
        '<div class="todo-item"><span class="checkbox">☐</span><span>考虑提取 window 为类属性以便后续引用</span></div>';
    }
    return '▸ 未检测到明显的待办事项\n\n' +
      '该内容为技术文档摘录，暂无可提取的任务项。\n' +
      '建议使用"智能总结"获取内容要点。';
  }

  /** 更新处理内容选择器 */
  function updateProcessSelector() {
    const select = document.getElementById('process-select');
    if (!select) return;

    const classifiedItems = clipboardHistory.filter(function (item) { return !item.classifying; });

    if (classifiedItems.length === 0) {
      select.innerHTML = '<option value="">— 请先复制一些内容 —</option>';
      disableProcessButtons(true);
      return;
    }

    const html = classifiedItems.map(function (item) {
      const config = TYPE_CONFIG[item.type];
      return '<option value="' + item.id + '">[' + config.label + '] ' + escapeHtml(getPreview(item.content, 30)) + '</option>';
    }).join('');

    select.innerHTML = html;
    disableProcessButtons(false);
  }

  /** 启用/禁用处理按钮 */
  function disableProcessButtons(disabled) {
    document.querySelectorAll('.process-btn').forEach(function (btn) {
      btn.disabled = disabled;
    });
  }

  /** 执行 AI 处理 */
  function handleProcess(action) {
    const select = document.getElementById('process-select');
    const resultContainer = document.getElementById('process-result');
    if (!select || !resultContainer) return;

    const itemId = select.value;
    if (!itemId) {
      showToast('warning', '请先选择要处理的内容');
      return;
    }

    const item = clipboardHistory.find(function (i) { return i.id === itemId; });
    if (!item) return;

    // 找到对应的按钮并显示加载状态
    const btn = document.querySelector('.process-btn[data-action="' + action + '"]');
    if (btn) {
      btn.classList.add('loading');
    }

    // 显示加载动画
    const actionLabels = {
      summarize: '智能总结',
      translate: '即时翻译',
      rewrite: '智能改写',
      extract: '提取待办'
    };

    resultContainer.innerHTML = '' +
      '<div class="process-loading">' +
        '<div class="loader"></div>' +
        '<div class="loading-text">AI 正在执行' + actionLabels[action] + '...</div>' +
      '</div>';

    // 模拟 AI 处理延迟
    setTimeout(function () {
      const result = getProcessResult(action, item);
      const config = TYPE_CONFIG[item.type];
      const actionTagClass = action;

      resultContainer.innerHTML = '' +
        '<div class="result-card">' +
          '<div class="result-card-header">' +
            '<span class="action-tag ' + actionTagClass + '">' + actionLabels[action] + '</span>' +
            '<span class="target-label">处理对象：' + escapeHtml(item.label) + ' · ' + config.label + '</span>' +
          '</div>' +
          '<div class="result-card-body">' + result + '</div>' +
        '</div>';

      if (btn) {
        btn.classList.remove('loading');
      }
    }, 1500);
  }

  // ============================================================
  // Toast 提示
  // ============================================================

  /** 显示 Toast 通知 */
  function showToast(type, message) {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const icons = {
      success: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>',
      info: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>',
      warning: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><path d="M12 9v4M12 17h.01"/></svg>'
    };

    const toast = document.createElement('div');
    toast.className = 'toast ' + type;
    toast.innerHTML = '' +
      '<div class="toast-icon">' + (icons[type] || icons.info) + '</div>' +
      '<div class="toast-message">' + escapeHtml(message) + '</div>';

    container.appendChild(toast);

    // 自动移除
    setTimeout(function () {
      toast.classList.add('removing');
      setTimeout(function () {
        if (toast.parentNode) {
          toast.parentNode.removeChild(toast);
        }
      }, 300);
    }, 3000);
  }

  // ============================================================
  // 初始化与事件绑定
  // ============================================================

  /** 初始化所有交互 */
  function init() {
    // 渲染示例列表
    renderExampleList();

    // 搜索功能
    const searchInput = document.getElementById('search-input');
    const searchBtn = document.getElementById('search-btn');

    if (searchBtn) {
      searchBtn.addEventListener('click', function () {
        executeSearch(searchInput.value);
      });
    }

    if (searchInput) {
      searchInput.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') {
          executeSearch(searchInput.value);
        }
      });
    }

    // 搜索建议词
    document.querySelectorAll('.suggestion-chip').forEach(function (chip) {
      chip.addEventListener('click', function () {
        const query = chip.dataset.query;
        if (searchInput) {
          searchInput.value = query;
          executeSearch(query);
        }
      });
    });

    // 处理按钮
    document.querySelectorAll('.process-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        if (btn.disabled) return;
        handleProcess(btn.dataset.action);
      });
    });

    // 导航栏滚动效果
    const nav = document.querySelector('nav');
    window.addEventListener('scroll', function () {
      if (window.scrollY > 50) {
        nav.classList.add('scrolled');
      } else {
        nav.classList.remove('scrolled');
      }
    });

    // 滚动揭示动画
    const observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
        }
      });
    }, { threshold: 0.1, rootMargin: '0px 0px -50px 0px' });

    document.querySelectorAll('.reveal').forEach(function (el) {
      observer.observe(el);
    });

    // 平滑滚动
    document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
      anchor.addEventListener('click', function (e) {
        const href = this.getAttribute('href');
        if (href === '#') return;
        e.preventDefault();
        const target = document.querySelector(href);
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      });
    });

    // URL 参数演示模式（用于截图和自动化展示）
    handleDemoParam();
  }

  /**
   * 处理 URL ?demo= 参数
   * 支持值：copy（复制内容展示分类）、search（复制并搜索）、process（复制并处理）
   * 用于无头浏览器截取不同状态的截图
   */
  function handleDemoParam() {
    const params = new URLSearchParams(window.location.search);
    const demo = params.get('demo');
    if (!demo) return;

    // 延迟执行，确保 DOM 完全渲染
    setTimeout(function () {
      if (demo === 'copy') {
        // 自动复制两条内容展示分类效果
        handleCopy('ex-code');
        setTimeout(function () { handleCopy('ex-error'); }, 500);
      } else if (demo === 'search') {
        // 先复制内容，再执行搜索
        handleCopy('ex-code');
        handleCopy('ex-error');
        handleCopy('ex-meeting');
        // 等待分类完成后执行搜索
        setTimeout(function () {
          const searchInput = document.getElementById('search-input');
          if (searchInput) {
            searchInput.value = '报错';
            executeSearch('报错');
          }
          // 滚动到搜索区域
          const searchSection = document.getElementById('card-search');
          if (searchSection) {
            searchSection.scrollIntoView({ behavior: 'instant', block: 'start' });
          }
        }, 2000);
      } else if (demo === 'process') {
        // 复制内容并执行处理
        handleCopy('ex-meeting');
        setTimeout(function () {
          const processBtn = document.querySelector('.process-btn[data-action="summarize"]');
          if (processBtn && !processBtn.disabled) {
            handleProcess('summarize');
          }
          // 滚动到处理区域
          const processSection = document.getElementById('card-process');
          if (processSection) {
            processSection.scrollIntoView({ behavior: 'instant', block: 'start' });
          }
        }, 2000);
      }
    }, 500);
  }

  // DOM 加载完成后初始化
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
