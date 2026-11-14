# dsh-pitfall-memory 🪤

**DSH 的错题本** — 让 DSH 记住自己犯过的错，下次同类任务不再犯。

A local, zero-dependency "mistake ledger" skill for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness).
Errors get structured into Markdown entries (symptom / cause / fix / **detection signal**), then retrieved before similar tasks so the same mistake doesn't happen twice.

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

**把整个目录复制到你的 DSH 技能目录：**

```powershell
# Windows
Copy-Item -Recurse . "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory"
```

也可以手动：把本仓库整个文件夹放进 `%USERPROFILE%\.dsh\skills\`，变成：

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

平时什么都不用说。同类任务开工前它会自己检索，报错时把命中的 `high` 条目当硬约束写进计划。

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

---

## 卸载

```powershell
Remove-Item "$env:USERPROFILE\.dsh\skills\dsh-pitfall-memory" -Recurse -Force
Remove-Item "$env:USERPROFILE\.dsh\pitfall-memory" -Recurse -Force   # 坑库，可选
```

坑库是独立目录，留着的话重装技能能直接接着用。

---

## 环境要求

- Windows（脚本用 PowerShell）
- PowerShell 5.1 或 7+
- DSH 任意版本（技能机制只要支持 `<skills>/<name>/SKILL.md` 即可）

---

## License

MIT