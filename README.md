# dsh-pitfall-memory 🪤

**DSH 的错题本** — 让 DSH 记住自己犯过的错，下次同类任务不再犯。

A local, zero-dependency "mistake ledger" skill for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness).
Errors get structured into Markdown entries (symptom / cause / fix / **detection signal**), then retrieved before similar tasks so the same mistake doesn't happen twice.

[![Release](https://img.shields.io/github/v/release/kysr04/dsh-pitfall-memory?label=release)](https://github.com/kysr04/dsh-pitfall-memory/releases)
[![License](https://img.shields.io/github/license/kysr04/dsh-pitfall-memory)](LICENSE)
[![DSH](https://img.shields.io/badge/DSH-skill-blue)](https://github.com/deepseek-ai/deepseek-harness)

---

## English quick start

**What you get.** A ledger of mistakes the agent has already made — one Markdown file per mistake, holding the thing that makes it recognisable next time (the *detection signal*) and the command that gets you off it. Before a task in a known-tricky area the agent reads the index and pulls the entries that match.

**Install.**

```powershell
# Windows
git clone https://github.com/kysr04/dsh-pitfall-memory "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory"
```

```sh
# macOS / Linux
git clone https://github.com/kysr04/dsh-pitfall-memory ~/.dsh/skills/dsh-pitfall-memory
```

DSH discovers `<skills-root>/<name>/SKILL.md` through its own watcher — no restart, no build, no npm. Type `/` in a session and `dsh-pitfall-memory` should be listed.

**How you know it works.** Correct the agent once, then say 记住这个坑. A file appears under `~/.dsh/pitfall-memory/entries/`, `index.md` gains a line, and `scripts/pitfall.ps1 search <keyword>` finds it again.

**What this does not do.**

- **It does not inject itself into every turn.** DSH treats a skill as optional instructions, not a session event: the agent has to decide to load it, or you ask. If you want automatic recall on every message, you need a memory plugin on top — that is a separate thing and is not included here.
- **`SKILL.md` is in Chinese.** The ledger format, the three rules and the entry template are language-neutral, but the instructions you would hand the agent are not English yet.
- **Windows is the only platform with real mileage.** `scripts/pitfall.ps1` is a Windows shortcut; elsewhere, follow the same steps by hand with `read` / `write` / `grep`. The procedure is written out in `SKILL.md`.
- `scripts/restart-dsh.ps1` and `scripts/meow-memory-setup.ps1` are the author's own machine helpers, kept for transparency. You do not need them.

**Contributing a pitfall.** Open [Submit a pitfall](../../issues/new?template=01-submit-pitfall.yml) and fill two fields — the detection signal and the fix. You do not need to know the file format.

---

## 为什么需要这个

Agent 会在不同会话里反复犯同一个错：

- 同一个编码问题踩三次
- 同一个工具的参数记错两次
- 同一类路径解析问题每次都绕一圈

你每次纠正它，它当下修好了 —— 但会话一结束，教训就蒸发了。下次从零开始。

这个技能做一件事：**把每次踩的坑变成一条可检索、带"检测信号"的记录**，下次开工前先查一遍。

---

## 安装

**推荐：直接 clone 到 DSH 的技能目录。**

```powershell
# Windows
git clone https://github.com/kysr04/dsh-pitfall-memory "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory"
```

```sh
# macOS / Linux
git clone https://github.com/kysr04/dsh-pitfall-memory ~/.dsh/skills/dsh-pitfall-memory
```

已经有一份本地副本的话，复制也行：

```powershell
Copy-Item -Recurse . "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory"
```

放好之后应该是这样：

```
~/.dsh/skills/dsh-pitfall-memory/
├── SKILL.md
├── README.md
├── LICENSE
└── scripts/
    ├── pitfall.ps1
    ├── meow-memory-setup.ps1
    └── restart-dsh.ps1
```

> ⚠️ 层级只能是**一层**。`.../dsh-pitfall-memory/dsh-pitfall-memory/SKILL.md` 不会被识别。
> ⚠️ 文件名严格是 `SKILL.md`，大小写敏感。
> ✅ **不用重启 DSH**，文件落地后下一个模型步骤技能目录就刷新。

验证：在对话里输入 `/`，能看到 `dsh-pitfall-memory` 就成了。

---

## 用法

### 你只说三种话

| 你说 | 它做什么 |
|---|---|
| **「记住这个坑」** | 建条目：现象 / 根因 / 正确做法 / 检测信号 → 重建索引 |
| **「上次那个错又犯了」** | 查库找到那条，`hits + 1` |
| **「错题本现在有啥」** | 列出全部条目 + 高频统计 |

平时什么都不用说。同类任务开工前它会翻一遍索引，报错时把命中的 `high` 条目当硬约束写进计划。

> 这里有个前提要说清楚：**DSH 的 skill 是被动加载的**（官方文档的说法是 "skill 是可选的指令而非会话事件"），模型得决定调用它。所以"开工前自动检索"这句，在不装行级注入插件的情况下是**半自动**——模型自己想起来、或你顺口提一句"查下坑库"。装了 [meow-memory](#可选接长期记忆插件) 那种每条消息注入的插件之后，才是真的每次自动。

### 手动操作

```powershell
$s = "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory\scripts\pitfall.ps1"

& $s list                 # 全部条目
& $s stats                # 高频坑（hits>=2）+ 该退役的僵尸条目
& $s search "pwsh,乱码"    # 模拟下次会怎么查
& $s show P-0001          # 看某条全文
& $s new -Title "..." -Tags "a,b" -Tools "pwsh" -Severity high -Signature "..."
& $s bump P-0001          # 命中 +1
& $s index                # 手动改文件后重建索引
& $s retire P-0001        # 标记退役
```

坑库就是普通 Markdown，在 `%USERPROFILE%\.dsh\pitfall-memory\entries\`。想直接改也行，改完跑一次 `index`。

---

## 条目格式

```markdown
---
id: P-0007
title: pwsh 直接 Get-Content 读 UTF-8 中文文件输出乱码
tags: [pwsh, encoding, utf8]
tools: [pwsh]
severity: high
signature: 输出里出现 閿欒 / 锛? / 鈥 这类连续乱码字符
created: 2026-11-14
hits: 1
last_hit: 2026-11-14
status: active
---

## 现象
## 根因
## 正确做法      ← 必须是可复制的命令或明确分支
## 错误做法（别再这么干）
## 检测信号      ← 下次怎么 3 秒认出又在踩它
```

### 三节里最重要的是「检测信号」

没有它，下次认不出来，等于没记。

| 好的写法 | 差的写法 |
|---|---|
| `输出出现 閿欒 / 锛? 这类连续乱码` | `可能出错` |
| `报错含 provider ... is not registered` | `注意网络` |
| `重启日志停在 kill 那几行之后就没后续` | `要注意进程` |

### severity 分级

| 级别 | 含义 | 注入时机 |
|---|---|---|
| `high` | 会让任务走错方向、写坏文件、浪费 ≥3 轮 | 任何同类任务开始前**必须**注入 |
| `medium` | 浪费 1～2 轮 | 命中关键词时注入 |
| `low` | 体验问题 | 只在显式检索时出现 |

---

## 设计原则

1. **不写"现象"，写"信号"** — 真正有用的是「我怎么在 3 秒内认出自己又踩了同一个坑」
2. **不写"要小心"，写"要执行的动作"** — `## 正确做法` 必须是能直接复制的命令
3. **重复的坑不新建，`hits + 1`** — 第二次踩中说明它没被检索到，该修的是关键词，不是再加一条
4. **只在用户明确说「记住这个坑」时才写** — 不自动沉淀、不主动汇报、不在用户只要「总结」时顺手写记忆
5. **报错必须当场说，不管写不写记忆** — 两个开关是分开的
6. **零依赖** — 纯 Markdown + PowerShell，不装插件、不改配置、不写数据库

第 4、5 条是刻意设计的：**自动往记忆里塞东西，比不记更烦人。**

### 为什么不用向量检索

坑库是个位数到几十条量级。关键词加权（tools 命中 +3 / tags 命中 +3 / title 命中 +2 / 正文命中 +1 / high +5）比 embedding 更可控 —— 你能一眼看出为什么这条被召回、为什么那条没被召回。

条目过百再考虑语义检索。

---

## 可选：接长期记忆插件

还装了 [`meow-memory`](https://github.com/Phant0Meow/dsh-meow-memory)（七层 SQLite 长期记忆，有 `lesson` 层）的话，可以双写：坑库存细节，记忆库存索引，每条消息自动注入 top-2。

**不是必须的。** 不装插件，错题本本身照样完整可用。

```powershell
$m = "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory\scripts\meow-memory-setup.ps1"
& $m status     # 检查状态
& $m rollback   # 卸载（自动备份配置）
```

手工装法（desktop profile 被 Electron 独占，`dsh plugin` 命令改不了它）：

1. 构建 meow-memory：`pnpm install --ignore-scripts && node build.mjs`，产出 `lib/`
2. `~/.dsh/profiles/desktop/node_modules/meow-memory` → junction 指向源码目录
3. `package.json` 的 `dependencies` 与 `dsh.profile.bundles` 各加一项
4. `cordis.patch.yml` 末尾加 config 段 — **只写 `- id: meow-memory` + `config`，绝不能写 `name:`**，否则会插出第二个实例
5. 重启 DeepSeek Harness

---

## 排查：装了但没出现

按顺序核对：

1. **层级超出一层** — 最常见
2. **文件名不是 `SKILL.md`** — 大小写敏感
3. **frontmatter 的 `name` 不是 kebab-case** — 必须是 `^[a-z0-9]+(-[a-z0-9]+)*$`
4. **布尔值写了非法值**（如 `maybe`）— 整个技能会被丢弃且**不报错**
5. **同根目录下另一个技能读失败** — 该根这次会被整体跳过

改完在对话里输入 `/` 看有没有。

还是不行？[开个 issue](../../issues/new?template=02-broken.yml)，表单里那几栏正好是我要排查的东西。

---

## 贡献一个坑

不用懂格式。走 [Submit a pitfall](../../issues/new?template=01-submit-pitfall.yml)，只填两栏：**检测信号**和**正确做法**。整理进库是我的事。

会写文件的话直接提 PR：`entries/P-XXXX-<ascii-slug>.md` + `index.md` 加一行，模板见 [PR 模板](.github/PULL_REQUEST_TEMPLATE.md)。

---

## 卸载

```powershell
Remove-Item "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory" -Recurse -Force
Remove-Item "$env:USERPROFILE\.dsh\pitfall-memory" -Recurse -Force   # 坑库，可选
```

坑库是独立目录，留着的话重装技能能直接接着用。

---

## 环境要求

- Windows 有完整验证（脚本用 PowerShell 5.1 / 7+）
- macOS / Linux：条目格式与流程通用，按 `SKILL.md` 里的步骤用 `read`/`write`/`grep` 手工执行，`pitfall.ps1` 用不了
- DSH 任意版本（技能机制只要支持 `<skills>/<name>/SKILL.md` 即可）

---

## License

MIT