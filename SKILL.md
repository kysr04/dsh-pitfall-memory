---
name: dsh-pitfall-memory
description: DSH 自身的长期错题本。当 DSH 执行任务出错、被用户纠正、工具/环境踩坑（pwsh 编码、路径、skill 未加载、插件安装、子代理、文件锁）之后，把这次坑结构化写进坑库；并在每次开始同类任务前检索坑库注入上下文，避免重复犯同一个错。用户说"记住这个坑""上次那个错又犯了""别再犯"或任务涉及 Windows/pwsh、编码、skill、插件、子代理、路径解析时使用。
whenToUse: 任务开始前同类检索、任务中报错、任务结束自评、用户显式要求记住教训
user-invocable: true
disable-model-invocation: false
---

# DSH 错题本（pitfall-memory）

**只记 DSH 自己的执行问题，不记业务知识、不记用户偏好、不记代码内容。**
判断标准一句话：**这条能防止我下次把任务搞砸吗？** 不能就不写。

库根目录（固定，跨项目共享）：`%USERPROFILE%\.dsh\pitfall-memory\`

```
pitfall-memory/
├── index.md          # 索引，一行一条，检索先读这里
└── entries/
    └── P-0001-<slug>.md
```

---

## 三条铁律

1. **不写"现象"，写"信号"。** 下次真正有用的是"我怎么在 3 秒内认出自己又踩了同一个坑"，不是这次报了什么错。
2. **不写"要小心"，写"要执行的动作"。** `## 正确做法` 必须是可复制的命令或可执行的分支逻辑。
3. **重复的坑不新建，`hits + 1`。** 同一条目被第二次踩中，说明它没被检索到 —— 修的是检索关键词，不是再加一条。

---

## 零、必报（和写记忆是两件事）

**出错必须当场说，不管写不写记忆。**

| 情况 | 说不说 |
|---|---|
| 重试 ≥2 次才成功 | **必须说** |
| 绕了弯路（换工具、换路径、换方案） | **必须说** |
| 跳过某步强行往下走 | **必须说** |
| 没被要求就改了文件 / 动了配置 | **必须说** |
| 自己发现前面判断错了，用户还没发现 | **必须主动说** |
| 一次过、小错立刻自愈 | 不用说 |

**固定格式，一句话，不写小作文：**

```
⚠️ 中间出过一次：<一句话是什么>，已改成 <怎么解决的>
```

**绝对禁止**：修好之后当没发生、把重试痕迹藏在工具调用里、等用户自己从日志里发现。

> 报告是当轮的，记忆是跨会话的。不写记忆 ≠ 不报告。

---

## 一、什么时候写（只认显式指令）

**唯一触发条件：用户说了「记住这个坑」或同义指令**（"记一下这个""这条记进去""别忘了这个坑"）。

| 情况 | 动作 |
|---|---|
| 用户说「记住这个坑」/「记一下」/「记进去」 | **写**。走完整流程：`new` → 补四问 → `index` → `memory_remember` 双写 |
| 用户说「上次那个错又犯了」 | **查 + bump**，不新建 |
| 没说话，任务报错了 | **不写。** 心里记着这轮发生过什么就行 |
| 没说话，被纠正了 | **不写。** 最多在回复末尾加一行「这条可以记进错题本，要记说一声」——只加一次，不加第二次 |
| 任务结束 | **不写，不自评，不输出任何关于记忆的话** |

### 绝对禁止

- ❌ 自动往 `memory_remember` 写任何东西（meow 的 `reflect` 和 `dream` 已由用户要求关闭，我这边也不能自己补上）
- ❌ 在用户只是要「总结一下」「说一下」「解释下」的时候顺手写记忆
- ❌ 干完活主动汇报「我已把这次教训记入错题本」
- ❌ 因为"这条很重要"而绕过规则 —— **重要不等于用户要记**

### 检索是另一回事

**检索不用等指令，随时可以做**（`search` 只读不写，不污染记忆库）。任务开始前先查一遍坑，这是默认动作。

---

## 二、条目格式

文件名：`entries/P-<四位序号>-<kebab-slug>.md`

```markdown
---
id: P-0007
title: pwsh 直接 Get-Content 读 UTF-8 中文文件输出乱码
tags: [pwsh, encoding, utf8, windows, 乱码]
tools: [pwsh]
severity: high
signature: 输出里出现 閿欒 / 锛? / 娓呯悊 这类连续乱码字符
created: 2026-11-14
hits: 1
last_hit: 2026-11-14
status: active
---

## 现象
用 pwsh 的 Get-Content 读 UTF-8 中文 README，控制台输出成乱码。

## 根因
PowerShell 默认按系统 ANSI 代码页（GBK/936）解码无 BOM 的 UTF-8 文件。

## 正确做法
- 用 read 工具读文本文件（它按 UTF-8 解码）
- 必须用 pwsh 时：`Get-Content -Encoding UTF8 <path>`
- 输出前设：`[Console]::OutputEncoding=[Text.Encoding]::UTF8`

## 错误做法
- `Get-Content <path>` 直接用，然后拿乱码结果当内容分析
- 看到乱码以为是文件本身坏了，去重写文件

## 检测信号
输出中出现成片的 `閿欒`、`锛?`、`鈥`、`娓` 等字符 → 立刻停，换 read 工具或加 -Encoding UTF8。
```

### severity 分级（决定检索时是否默认注入）

- `high`：会让任务走错方向、写坏文件、浪费 ≥3 轮。**任何同类任务开始前必须注入。**
- `medium`：浪费 1–2 轮。**命中关键词时注入。**
- `low`：体验问题。**只在显式检索时出现。**

### signature 是灵魂

`signature` 一行写"下次怎么认出它"。要具体到**可观察的字符串/状态**：
- 好：`ffuf 返回 0 结果且 exit 0`、`skill 调用报 not found 但目录存在`
- 差：`可能出错`、`注意路径`

---

## 三、检索与注入（任务开始前）

**在动手前，判断本次任务用到的工具/平台/动作，拼出 2–4 个检索词。**

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory\scripts\pitfall.ps1" search "pwsh,encoding"
```

输出命中的 `id / severity / title / signature / 正确做法`。把命中的 `high` 条目**贴进自己的执行计划**，作为前置约束。

**这一步不是可选的。** 跳过检索直接干活，就是第 N 次踩同一个坑。

### 无需检索就默认常驻的三类（记忆里过一遍即可）

1. **Windows 环境类**：pwsh 编码、路径反斜杠、PortableGit 在 `~/.dsh/tools`、node 在 `~/.dsh/tools/node/node.exe`
2. **DSH 机制类**：skill 只扫描一层（`<root>/<name>/SKILL.md`）、frontmatter 布尔值写错会让整个 skill 被丢弃、同根下一个 skill 读失败会让该根整体跳过
3. **自身行为类**：没读文件就改、跳过验证就宣称完成、用 `cat`/`grep`/`find` 而不是 read/grep/glob 工具

---

## 四、写入（三种方式）

### 方式 1：脚本建条目（推荐）

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory\scripts\pitfall.ps1" new `
  -Title "pwsh 读 UTF-8 中文乱码" `
  -Tags "pwsh,encoding,utf8" `
  -Tools "pwsh" `
  -Severity high `
  -Signature "输出出现乱码字符"
```

打印出新建文件路径，然后**用 edit 工具补齐四个正文小节**（现象/根因/正确做法/错误做法+检测信号）。

### 方式 2：手动写

直接 write 到 `entries/P-XXXX-<slug>.md`，序号取当前最大 +1。

### 方式 3：重复命中

已经存在同类条目 → 不要新建：

```powershell
pwsh -NoProfile -File "...\pitfall.ps1" bump P-0007
```

`bump` 会把 `hits + 1`、更新 `last_hit`，并**要求你顺手改 signature 或 tags**（让它下次更容易被检索到）。改完重建索引：

```powershell
pwsh -NoProfile -File "...\pitfall.ps1" index
```

---

## 五、任务结束自评（默认关，不要输出）

收尾时在心里过一遍即可：哪步返工了 / 哪步是猜的 / 被纠正了吗。

**过完就完，不写记忆、不输出自评。** 只有 用户说了「记住这个坑」，才把刚才那些整理成条目写进去。

---

## 六、坑库健康维护

| 命令 | 用途 |
|---|---|
| `pitfall.ps1 list` | 列出全部条目（id/severity/hits/title） |
| `pitfall.ps1 search "<kw,kw>"` | 检索并打印注入块 |
| `pitfall.ps1 index` | 重建 `index.md` |
| `pitfall.ps1 bump <id>` | 命中 +1 |
| `pitfall.ps1 stats` | 看高命中项（有效坑）和僵尸项（从没再命中） |
| `pitfall.ps1 retire <id>` | 标记 `status: retired`，检索时跳过 |

**退役规则**：`hits == 1` 且 `last_hit` 超过 90 天 → 候选退役。但 `severity: high` 的永不自动退役。

**合并规则**：两条条目的 `signature` 描述的是同一个可观察信号 → 合并成一条，把两者的 tags 并集塞进去。

---

## 七、反模式（这些做法等于白建库）

- ❌ 把整段对话或整篇报错原文塞进条目 → 检索会命中噪音，注入会撑爆上下文
- ❌ 写"需要更小心"这类没有动作的话
- ❌ 只写现象不写 detection signal → 下次认不出来，等于没记
- ❌ 检索时把所有条目全量注入 → 上下文被挤占，反而更容易出错
- ❌ 建完库就不再看 → 这类库 90% 死于此
- ❌ 把业务知识/项目规范写进来 → 那是 CLAUDE.md / AGENTS.md 的活，不是错题本的

---

## 与插件的关系

本 skill 是**零依赖方案**：纯 Markdown 文件 + PowerShell 检索，不装任何插件、不改任何配置、热加载即生效。

如果后期需要语义检索、自动召回、跨窗口沉淀，再接 DSH 记忆插件（`dsh-meow-memory` 有 `lesson` 层、`Aik358/dsh-auto-memory` 有技能晋升审批），把它当**检索后端**，本 skill 的条目格式与写入纪律保持不变。

---

## 八、meow-memory 已装：双写规则

本机 desktop profile 已手工接入 `meow-memory`（七层 SQLite，含 `lesson` 层）。

### 分工

| 层 | 谁写 | 特点 | 检索时机 |
|---|---|---|---|
| **坑库**（本 skill） | 我，手工精筛 | 结构化四问 + 检测信号 + severity | 任务开始前主动 `search` |
| **meow-memory `lesson`** | 我，写条目后同步一条 | 一句话摘要，BM25 关键词命中自动注入 | 每条用户消息自动 top-2 |

**坑库是硬约束，meow 是软提醒。** 两者不重复劳动：坑库存细节，meow 存索引。

### 写入后必须双写

每写完一个坑库条目，立刻调 **一次** `memory_remember`：

```
level: lesson
project: "全局"
importance: 3（high）/ 2（medium）/ 1（low）
content: 【坑 P-XXXX】<title>｜信号: <signature>｜做法: <一句话正确做法>
keywords: <取条目 tags + tools + 症状词，8–13 个>
```

例：
```
content: 【坑 P-0001】pwsh 读 UTF-8 中文文件乱码｜信号: 输出出现 閿欒/锛? ｜做法: 用 read 工具或 Get-Content -Encoding UTF8，写 .ps1 必须带 BOM
keywords: [pwsh, 乱码, UTF8, BOM, 编码, PowerShell, ParseException, 中文, Get-Content, read工具]
```

### 检索顺序

1. 先 `pitfall.ps1 search "<关键词>"` —— 拿可执行命令
2. meow-memory 的自动注入会额外带出历史 lesson —— 看到 `P-XXXX` 编号就去 `pitfall.ps1 show P-XXXX` 拿全文

### 坑库与 meow 冲突时

以坑库为准（它更新、更结构化）。同时把 meow 里那条旧 lesson 用 `memory_update` 标 `stale`。

### 维护命令

```powershell
$m = "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory\scripts\meow-memory-setup.ps1"
& $m status                                  # 检查插件是否装着
& $m rollback                                # 出问题时完全卸载，恢复安装前状态
& $m install -SourceDir "<meow-memory 源码目录>"  # 重新装回
```

**已知装法**（desktop profile 被 Electron 独占，`dsh plugin` 命令改不了它，只能手工）：
`~/.dsh/profiles/desktop/node_modules/meow-memory` → junction 到本机存放 meow-memory 源码的目录（需先 `pnpm install --ignore-scripts && node build.mjs` 构建出 `lib/`），
`package.json` 的 `dependencies` 与 `dsh.profile.bundles` 各加一项，`cordis.patch.yml` 末尾加 config 段。
改完必须重启 DeepSeek Harness。

> 跨盘注意：若源码目录不在 C 盘，包内的 `node_modules/@deepseek-ai` 会解析到它自己装的旧版本（见坑 P-0005）。需要把该目录整个 junction 到宿主 `…\app\dsh\node_modules\@deepseek-ai`。