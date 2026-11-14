#Requires -Version 5.1
<#
  DSH pitfall-memory 工具
  用法:
    pitfall.ps1 new    -Title "..." [-Tags "a,b"] [-Tools "pwsh"] [-Severity high] [-Signature "..."]
    pitfall.ps1 search "<kw1,kw2>"
    pitfall.ps1 bump   <id>
    pitfall.ps1 index
    pitfall.ps1 list
    pitfall.ps1 stats
    pitfall.ps1 retire <id>
    pitfall.ps1 show   <id>
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Command = 'list',
    [Parameter(Position = 1)][string]$Arg,
    [string]$Title,
    [string]$Tags = '',
    [string]$Tools = '',
    [ValidateSet('high', 'medium', 'low')][string]$Severity = 'medium',
    [string]$Signature = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root = Join-Path $env:USERPROFILE '.dsh\pitfall-memory'
if ($env:DSH_PITFALL_ROOT) { $Root = $env:DSH_PITFALL_ROOT }
$Entries = Join-Path $Root 'entries'
$Index = Join-Path $Root 'index.md'
foreach ($d in @($Root, $Entries)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null } }

function Get-Entries {
    Get-ChildItem $Entries -Filter 'P-*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
        $txt = Get-Content $_.FullName -Encoding UTF8 -Raw
        $fm = @{}
        if ($txt -match '(?s)^---\r?\n(.*?)\r?\n---') {
            foreach ($line in ($Matches[1] -split "`r?`n")) {
                if ($line -match '^([A-Za-z_]+):\s*(.*)$') { $fm[$Matches[1]] = $Matches[2].Trim() }
            }
        }
        $body = $txt
        if ($txt -match '(?s)^---\r?\n.*?\r?\n---\r?\n(.*)$') { $body = $Matches[1] }
        [pscustomobject]@{
            Id        = $fm['id']
            Title     = $fm['title']
            Tags      = $fm['tags']
            Tools     = $fm['tools']
            Severity  = $fm['severity']
            Signature = $fm['signature']
            Hits      = [int]($fm['hits'] -replace '[^0-9]', '')
            LastHit   = $fm['last_hit']
            Status    = if ($fm['status']) { $fm['status'] } else { 'active' }
            Path      = $_.FullName
            Body      = $body
        }
    }
}

function Get-NextId {
    $max = 0
    Get-ChildItem $Entries -Filter 'P-*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -match '^P-(\d{4})') { $n = [int]$Matches[1]; if ($n -gt $max) { $max = $n } }
    }
    'P-{0:D4}' -f ($max + 1)
}

function New-Slug([string]$s) {
    # 只保留 ASCII：中文/标点一律当分隔符。
    # 理由：含中文的文件名在 git（core.quotepath）、GitHub Contents API、命令行之间
    # 反复出现编码摩擦 —— 8 进制转义、路径非法、HTTP 400。标题里保留中文即可。
    $x = $s.ToLower()
    $x = $x -replace '[^a-z0-9]+', '-'
    $x = $x.Trim('-')
    while ($x -match '--') { $x = $x -replace '--', '-' }
    if ($x.Length -gt 48) { $x = $x.Substring(0, 48).Trim('-') }
    # ASCII 有效字符太少（比如标题几乎全中文）→ 用统一兜底名
    if (-not $x -or ($x -replace '[^a-z0-9]', '').Length -lt 3) { $x = 'entry' }
    $x
}

function Rebuild-Index {
    $all = Get-Entries | Sort-Object { [int]($_.Id -replace '\D', '') }
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# DSH 错题本索引')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("> 生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm') · 共 $($all.Count) 条 · 由 pitfall.ps1 index 重建")
    [void]$sb.AppendLine('>')
    [void]$sb.AppendLine('> 检索顺序：先按 tools 命中，再按 tags 命中，severity=high 无条件优先。')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| id | sev | hits | status | title | tags |')
    [void]$sb.AppendLine('|---|---|---|---|---|---|')
    foreach ($e in $all) {
        [void]$sb.AppendLine("| $($e.Id) | $($e.Severity) | $($e.Hits) | $($e.Status) | $($e.Title) | $($e.Tags) |")
    }
    Set-Content -Path $Index -Value $sb.ToString() -Encoding UTF8
    "index 已重建: $Index ($($all.Count) 条)"
}

switch ($Command.ToLower()) {

    'new' {
        if (-not $Title) { throw '需要 -Title' }
        $id = Get-NextId
        $slug = New-Slug $Title
        $file = Join-Path $Entries "$id-$slug.md"
        $today = Get-Date -Format 'yyyy-MM-dd'
        $tagStr = if ($Tags) { "[$Tags]" } else { '[]' }
        $toolStr = if ($Tools) { "[$Tools]" } else { '[]' }
        $content = @"
---
id: $id
title: $Title
tags: $tagStr
tools: $toolStr
severity: $Severity
signature: $Signature
created: $today
hits: 1
last_hit: $today
status: active
---

## 现象
（这次具体发生了什么，一句话）

## 根因
（为什么会这样，机制层面）

## 正确做法
- （可复制的命令或明确分支）

## 错误做法（别再这么干）
- （这次的具体错法）

## 检测信号
（下次如何 3 秒认出又在踩它）
"@
        Set-Content -Path $file -Value $content -Encoding UTF8
        Rebuild-Index | Out-Null
        "已新建: $file"
        "下一步: 用 edit 工具补齐正文四节，重点是 检测信号。"
    }

    'search' {
        if (-not $Arg) { throw '需要检索词，例如: search "pwsh,encoding"' }
        $kws = $Arg -split '[,，\s]+' | Where-Object { $_ }
        $all = Get-Entries | Where-Object { $_.Status -ne 'retired' }
        $hitsOut = foreach ($e in $all) {
            $hay = (@($e.Title, $e.Tags, $e.Tools, $e.Signature, $e.Body) -join ' ').ToLower()
            $score = 0
            foreach ($k in $kws) {
                $kk = $k.ToLower()
                if ($e.Tools -and $e.Tools.ToLower().Contains($kk)) { $score += 3 }
                if ($e.Tags -and $e.Tags.ToLower().Contains($kk)) { $score += 3 }
                if ($e.Title -and $e.Title.ToLower().Contains($kk)) { $score += 2 }
                if ($hay.Contains($kk)) { $score += 1 }
            }
            if ($score -gt 0) {
                if ($e.Severity -eq 'high') { $score += 5 }
                [pscustomobject]@{ Score = $score; Entry = $e }
            }
        }
        $top = $hitsOut | Sort-Object Score -Descending | Select-Object -First 6
        if (-not $top) { "无命中（关键词: $($kws -join ',')）。继续任务，不要因此降级警惕。"; break }
        "=== 坑库命中 $($top.Count) 条 | 关键词: $($kws -join ',') ==="
        foreach ($t in $top) {
            $e = $t.Entry
            ""
            "--- [$($e.Id)] ($($e.Severity), 命中$($e.Hits)次) $($e.Title)"
            "    检测信号: $($e.Signature)"
            $correct = ($e.Body -split '(?m)^## ') | Where-Object { $_ -match '^正确做法' }
            if ($correct) { ($correct -split "`r?`n")[1..6] | Where-Object { $_ -match '\S' } | ForEach-Object { "    $_" } }
        }
        ""
        "=== 把以上 high 条目作为前置约束写进执行计划 ==="
    }

    'bump' {
        if (-not $Arg) { throw '需要 id，例如: bump P-0007' }
        $e = Get-Entries | Where-Object { $_.Id -eq $Arg }
        if (-not $e) { throw "未找到 $Arg" }
        $txt = Get-Content $e.Path -Encoding UTF8 -Raw
        $txt = $txt -replace '(?m)^hits:.*$', "hits: $($e.Hits + 1)"
        $txt = $txt -replace '(?m)^last_hit:.*$', "last_hit: $(Get-Date -Format 'yyyy-MM-dd')"
        Set-Content -Path $e.Path -Value $txt -Encoding UTF8 -NoNewline
        Rebuild-Index | Out-Null
        "$Arg hits -> $($e.Hits + 1)。记得顺手加强 signature 或 tags，让它下次更容易被搜到。"
    }

    'index' { Rebuild-Index }

    'list' {
        $all = Get-Entries | Sort-Object Severity, { [int]($_.Id -replace '\D', '') }
        if (-not $all) { "坑库为空: $Entries"; break }
        $all | Format-Table Id, Severity, Hits, Status, Title -AutoSize | Out-String -Width 200
    }

    'stats' {
        $all = Get-Entries
        if (-not $all) { "坑库为空: $Entries"; break }
        "总条目: $($all.Count)"
        "active: $(($all | Where-Object Status -eq 'active').Count)  retired: $(($all | Where-Object Status -eq 'retired').Count)"
        ""
        "== 有效坑（hits >= 2，说明真的在重复发生）=="
        $all | Where-Object { $_.Hits -ge 2 } | Sort-Object Hits -Desc | Format-Table Id, Hits, Severity, Title -AutoSize | Out-String -Width 200
        "== 僵尸坑（hits == 1 且超过 90 天未再命中，可考虑 retire）=="
        $cut = (Get-Date).AddDays(-90)
        $all | Where-Object {
            $_.Hits -le 1 -and $_.LastHit -and $_.LastHit -ne '' -and ([datetime]::Parse($_.LastHit) -lt $cut)
        } | Format-Table Id, LastHit, Severity, Title -AutoSize | Out-String -Width 200
    }

    'retire' {
        if (-not $Arg) { throw '需要 id' }
        $e = Get-Entries | Where-Object { $_.Id -eq $Arg }
        if (-not $e) { throw "未找到 $Arg" }
        $txt = Get-Content $e.Path -Encoding UTF8 -Raw
        $txt = $txt -replace '(?m)^status:.*$', 'status: retired'
        Set-Content -Path $e.Path -Value $txt -Encoding UTF8 -NoNewline
        Rebuild-Index | Out-Null
        "$Arg 已退役。"
    }

    'show' {
        if (-not $Arg) { throw '需要 id' }
        $e = Get-Entries | Where-Object { $_.Id -eq $Arg }
        if (-not $e) { throw "未找到 $Arg" }
        Get-Content $e.Path -Encoding UTF8 -Raw
    }

    default { "未知命令: $Command`n支持: new / search / bump / index / list / stats / retire / show" }
}