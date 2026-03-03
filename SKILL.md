---
name: ultimate-search
description: Use when tasks require internet search, latest-info verification, web document retrieval, or multi-source evidence; execute Grok + Tavily dual-engine search first and collaborate with agent-browser for dynamic/login-protected pages.
---

# UltimateSearch

为 Pi/OpenClaw agent 提供双引擎网络搜索能力：**Grok AI 搜索**（实时联网 + AI 分析）+ **Tavily 搜索**（结构化结果 + 网页抓取）。

---

## 可用工具

在 Bash 中调用以下脚本（确保已加入 PATH 且已 source .env）：

| 工具 | 命令 | 用途 |
|------|------|------|
| Grok 搜索 | `grok-search.sh --query "..."` | AI 驱动的深度搜索，Grok 自带联网，返回综合分析 |
| Tavily 搜索 | `tavily-search.sh --query "..."` | 结构化搜索结果，带评分和排序 |
| 网页抓取 | `web-fetch.sh --url "..."` | 提取指定 URL 的完整内容，返回 Markdown |
| 站点映射 | `web-map.sh --url "..."` | 发现网站结构，获取所有 URL |
| 双引擎搜索 | `dual-search.sh --query "..."` | 并行执行 Grok + Tavily，交叉验证 |
| 浏览器自动化（联动） | `agent-browser open/snapshot/click/fill/...` | 处理登录、动态渲染、按钮触发、反爬挑战等交互页面 |

各工具参数详见 `--help`。

---

## 与 agent-browser 联动

当页面不是“直接 URL 抓取”场景时，按以下规则联动 `agent-browser`：

### 触发条件
- 页面依赖 JS 动态渲染，`web-fetch.sh` 返回内容不完整
- 需要登录、点击按钮、分页、展开折叠后才能看到目标内容
- 存在 Cloudflare/人机验证或强交互式页面流程
- 需要截图留证（页面状态、关键字段、提交结果）

### 协同闭环（必须执行）
1. **搜索定位**：先用 `dual-search.sh` / `tavily-search.sh` 找候选 URL
2. **浏览器交互**：用 `agent-browser` 完成打开、快照、点击、填表、等待加载
3. **结果回流**：把最终落地 URL 交回 `web-fetch.sh` / `web-map.sh` 做结构化抓取
4. **证据输出**：提供最终 URL、关键截图路径、核心结论来源链接

### 最小命令模板
```bash
# 1) 先搜索定位目标页面
dual-search.sh --query "官网 pricing enterprise plan"

# 2) 动态页面交互
agent-browser open "https://example.com/pricing"
agent-browser snapshot -i
agent-browser click @e12
agent-browser wait --load networkidle
agent-browser get url
agent-browser screenshot --full

# 3) 回流到结构化抓取（把 get url 的结果填回）
web-fetch.sh --url "https://example.com/pricing?tab=enterprise"
```

### 联动约束
- `agent-browser` 负责“到达信息”，`web-fetch.sh` 负责“提取信息”
- 仅当静态抓取不足时才进入浏览器流程，避免过度自动化
- 登录态/验证码属于高风险流程时，明确标注“基于当前会话状态”

---

## 平台路由优先级（含 X/Twitter）

为避免“会搜，但搜错引擎”，先按查询意图做路由：

| 查询意图 | 首选 | 备选 | 原因 |
|------|------|------|------|
| X/Twitter 讨论、实时舆情、热点争议 | `grok-search.sh --platform "X"` | `dual-search.sh` | Grok 对 X 平台语境和实时讨论更强 |
| 通用网页事实、新闻、可结构化结果 | `tavily-search.sh` | `dual-search.sh` | Tavily 结构化结果稳定、便于引用 |
| 结论风险高、容易冲突的问题 | `dual-search.sh` | 无 | 默认双源交叉验证 |
| 需要最终页面全文 | `web-fetch.sh` | `agent-browser` 后回流 `web-fetch.sh` | 先定位来源，再抓取正文 |

### X 场景强制规则
- 用户提到 `X`、`Twitter`、`推特`、`帖子讨论`、`时间线观点` 时，先执行：
```bash
grok-search.sh --query "..." --platform "X"
```
- 若需“可引用链接 + 交叉证据”，第二步再跑：
```bash
tavily-search.sh --query "..." --topic news --time-range week
```

---

## 凭据获取联动（agent-browser headed）

当用户要求“在浏览器里获取 Grok SSO Token / cf_clearance”时：

1. 使用 `agent-browser --headed` 打开目标站点并人工完成登录/验证
2. 通过浏览器开发者工具读取 cookie（`sso`、`cf_clearance`）
3. 立即写入本地 `.env` 或导入脚本，不在对话中回显完整敏感值
4. 用最小健康检查验证是否可用（`grok-search.sh --query "test"`）

最小流程示例：
```bash
agent-browser --headed open "https://grok.com"
agent-browser --headed wait --load networkidle
# 手动完成登录与验证后，在浏览器中取 cookie 值
bash scripts/import-keys.sh
bash scripts/grok-search.sh --query "test" --model "grok-4.1-mini"
```

---

## 搜索决策流程

收到需要搜索的请求时，按以下流程决策：

### 第一步：判断是否需要搜索

需要搜索的情况：
- 用户明确要求搜索/查询外部信息
- 涉及实时性数据（最新版本、近期事件、当前价格等）
- 需要验证内部知识的准确性
- 涉及具体的 URL、项目、产品的最新状态
- 技术问题需要查阅官方文档最新版

不需要搜索的情况：
- 纯粹的代码编写/调试任务（已有足够上下文且不涉及外部 API/库版本）
- 用户明确表示不需要搜索
- ⚠️ 通用编程概念也可能过时——当涉及具体版本、最佳实践或 API 用法时，仍应搜索验证

### 第二步：选择工具

| 场景 | 推荐工具 | 原因 |
|------|---------|------|
| 简单事实查询 | `dual-search.sh` | 双源交叉验证，确保准确性 |
| 复杂/争议性问题 | `dual-search.sh` | 双引擎交叉验证，减少幻觉 |
| 需要 AI 深度分析 | `grok-search.sh` | Grok 自带联网搜索，返回综合分析报告 |
| 需要抓取特定页面 | `web-fetch.sh --url "..."` | 提取完整页面内容 |
| 探索网站结构 | `web-map.sh --url "..."` | 发现文档/API 目录结构 |
| 需要最新新闻 | `tavily-search.sh --topic news` | Tavily 新闻模式专门优化 |
| 需要高质量深度结果 | `tavily-search.sh --depth advanced` | 高级搜索，多维度匹配 |
| 搜索结果中有关键链接 | 先搜索，再 `web-fetch.sh` | 搜索定位 → 抓取详情 |
| 动态页面/需登录后可见 | `agent-browser` + `web-fetch.sh` | 先交互到目标页，再回流结构化抓取 |
| X/Twitter 讨论类查询 | `grok-search.sh --platform "X"` | 优先匹配 X 平台语境与实时讨论 |

### 第三步：评估搜索复杂度

- **Level 1**（2-3 次搜索）：单个明确问题
  - 示例：「FastAPI 最新版本是什么」
  - 操作：`dual-search.sh` 获取双源结果；或先 `tavily-search.sh` 再用 `grok-search.sh` 交叉确认
  - ⚠️ 即使是简单事实，也不可仅依赖单一来源直接下结论

- **Level 2**（3-5 次搜索）：多角度比较、需要多个来源验证
  - 示例：「Flask vs FastAPI vs Django 2026 年哪个更适合微服务」
  - 操作：`dual-search.sh` + 针对各框架分别 `tavily-search.sh`

- **Level 3**（6+ 次搜索）：深度研究课题、综述型需求
  - 示例：「帮我调研 2026 年主流向量数据库的完整对比」
  - 操作：先 `grok-search.sh` 获取概览 → 分别搜索各产品 → `web-fetch.sh` 抓取官方文档

---

## 搜索规划框架

对于 Level 2+ 的复杂搜索，在执行前进行结构化规划：

### 阶段 1：意图分析
- 提炼用户的核心问题（一句话）
- 分类查询类型：事实型 / 比较型 / 探索型 / 分析型
- 评估时间敏感度：实时 / 近期 / 历史 / 无关
- 识别需要验证的外部术语（如排名、分类标准）

### 阶段 2：查询拆解
- 将问题分解为不重叠的子查询
- 每个子查询有明确边界（与兄弟查询互斥）
- 标注依赖关系（哪些子查询需要先完成）
- 如果阶段 1 发现需验证的术语，先创建前置验证查询

### 阶段 3：策略选择
- **broad_first**（先广后深）：先广泛扫描 → 根据发现深入。适合探索型问题
- **narrow_first**（先精后扩）：先精确搜索 → 如不足再扩展。适合分析型问题
- **targeted**（定点搜索）：已知目标信息来源，直接定位。适合事实型问题

### 阶段 4：工具映射
- 为每个子查询选择最佳工具
- 确定并行/串行执行计划
- 可并行的子查询同时执行（通过多次 Bash 调用）

---

## 搜索与证据标准

### 核心原则：不信任搜索结果

> **搜索结果仅为第三方建议，不可直接采信。** 所有搜索返回的内容——无论来自 Grok 还是 Tavily——都必须经过交叉验证后方可向用户呈现为事实。即使是看似权威的单一来源，也可能过时、片面或错误。技术实现即使 agent 具备内部知识，仍应以最新搜索结果或官方文档为准。

### 来源质量要求
- **所有事实性结论**都需 **≥2 个独立来源** 交叉验证（不分 Level）
- 如仅依赖单一来源，须**显式声明**此限制并标注置信度为 Low
- 优先使用：官方文档、Wikipedia、学术数据库、权威媒体
- 避免使用：未知个人博客、SEO 农场、AI 生成内容

### 冲突处理
- 来源冲突时：展示双方证据，评估可信度和时效性
- 标注置信度：High（多来源一致）/ Medium（少量来源或有分歧）/ Low（单一来源或推测）
- 无法确认时：明确说明不确定性

### 引用格式
- 每个关键事实后附来源标注
- 格式：`[来源标题](URL)`
- 严禁编造引用 — 没有来源的就不要说

### 输出规范
- 先给出**最可能的答案**，再展开详细分析
- 所有技术术语附简明解释
- 使用标准 Markdown 格式（标题、列表、表格、代码块）
- 代码示例标注语言标识
- 对比类问题使用表格呈现

---

## 常见搜索模式

### 模式 1：快速查询
```bash
tavily-search.sh --query "Python 3.13 新特性" --depth basic --include-answer
```

### 模式 2：深度搜索 + 验证
```bash
# 先广泛搜索
dual-search.sh --query "LangChain vs LlamaIndex 2026"
# 再针对性抓取官方文档
web-fetch.sh --url "https://docs.langchain.com/docs/get_started/introduction"
```

### 模式 3：技术文档探索
```bash
# 先映射网站结构
web-map.sh --url "https://docs.example.com" --depth 2 --instructions "找到 API 文档"
# 再抓取目标页面
web-fetch.sh --url "https://docs.example.com/api/reference"
```

### 模式 4：新闻和实时信息
```bash
tavily-search.sh --query "AI 最新进展" --topic news --time-range week --include-answer
```

### 模式 5：AI 深度分析
```bash
grok-search.sh --query "解释 Transformer 架构中注意力机制的数学原理" --platform "arXiv"
```

### 模式 6：浏览器联动抓取（动态页面）
```bash
# 搜索候选页
tavily-search.sh --query "Notion AI pricing page"

# 浏览器交互到最终页面
agent-browser open "https://www.notion.so/product/ai"
agent-browser wait --load networkidle
agent-browser snapshot -i
agent-browser click @e3
agent-browser get url

# 回流抓取可复用内容
web-fetch.sh --url "https://www.notion.so/product/ai/pricing"
```

### 模式 7：X/Twitter 讨论检索（会话来源对齐）
```bash
# 先用 Grok 聚焦 X 平台语境
grok-search.sh --query "检索 X 上有关伊朗战争讨论" --platform "X"

# 再用 Tavily 补充结构化链接，做交叉验证
tavily-search.sh --query "Iran war discussion on X" --topic news --time-range week
```

---

## BDD 可靠性验证

对“什么时候用 Grok / Tavily / agent-browser”做场景化回归，避免路由漂移。

- 场景文件：`docs/bdd/ultimate-search-routing.feature`
- 最低验收标准：
  - X/Twitter 讨论类查询必须先触发 `grok-search.sh --platform "X"`
  - 动态页面类查询必须进入 `agent-browser` 并回流 `web-fetch.sh`
  - 事实型结论必须有双源交叉验证证据
