#Requires -Version 5.1
<#
  安全重启 DeepSeek Harness
  ─ 关键：重启逻辑必须跑在 DSH 进程树之外（计划任务托管），
          否则 Start-Process 派的进程会随 DSH 一起被杀（坑 P-0006）。
  用法:
    restart-dsh.ps1            延迟 15 秒重启
    restart-dsh.ps1 -Delay 5   延迟 5 秒
    restart-dsh.ps1 -Now       立即重启（不延迟）
    restart-dsh.ps1 -Status    查看上次重启日志
#>
[CmdletBinding()]
param(
    [int]$Delay = 15,
    [switch]$Now,
    [switch]$Status,
    # 内部用：被计划任务调起时进入执行态
    [switch]$Worker
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$LogPath  = Join-Path $env:USERPROFILE ".dsh\restart-dsh.log"
$TaskName = "DSHRestartOnce"

# 自动探测 DSH 可执行文件；也可用环境变量 DSH_EXE 覆盖
$Exe = $env:DSH_EXE
if (-not $Exe -or -not (Test-Path $Exe)) {
    $cands = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'),
        (Join-Path $env:PROGRAMFILES 'DeepSeek Harness\DeepSeek Harness.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'DeepSeek Harness\DeepSeek Harness.exe')
    ) | Where-Object { $_ -and (Test-Path $_) }
    $Exe = @($cands)[0]
}
if (-not $Exe) {
    Write-Host "找不到 DeepSeek Harness.exe。请设置环境变量 DSH_EXE 指向它，或改本脚本顶部的 `$Exe。" -ForegroundColor Red
    return
}
$SelfPath = $PSCommandPath
if (-not $SelfPath) { $SelfPath = $MyInvocation.MyCommand.Path }

function W([string]$m) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Out-File -FilePath $LogPath -Append -Encoding UTF8
}

# ─────────────────────────── 执行态（计划任务里跑） ───────────────────────────
if ($Worker) {
    W "=== [worker] start, pid=$PID, ppid=$((Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId) ==="
    try {
        $ppid = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
        $parent = Get-Process -Id $ppid -ErrorAction SilentlyContinue
        W "[worker] parent process: $($parent.ProcessName) — 应当是 svchost/taskeng 而不是 DeepSeek Harness"
    } catch { W "[worker] parent lookup failed: $($_.Exception.Message)" }

    if ($Delay -gt 0) { W "[worker] waiting ${Delay}s"; Start-Sleep -Seconds $Delay }

    W "[worker] stopping all 'DeepSeek Harness' processes"
    $procs = @(Get-Process -Name "DeepSeek Harness" -ErrorAction SilentlyContinue)
    W "[worker] found $($procs.Count) process(es)"
    foreach ($p in $procs) {
        W "[worker]   kill pid $($p.Id)"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 5

    $left = @(Get-Process -Name "DeepSeek Harness" -ErrorAction SilentlyContinue)
    W "[worker] remaining: $($left.Count)"
    if ($left.Count -gt 0) {
        foreach ($p in $left) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 3
    }

    if (-not (Test-Path $Exe)) { W "[worker] FATAL: exe not found: $Exe"; return }
    W "[worker] launching: $Exe"
    try { Start-Process -FilePath $Exe; W "[worker] Start-Process returned" }
    catch { W "[worker] launch error: $($_.Exception.Message)" }

    $up = $false
    for ($i = 1; $i -le 12; $i++) {
        Start-Sleep -Seconds 3
        if (Get-Process -Name "DeepSeek Harness" -ErrorAction SilentlyContinue) {
            W "[worker] up after $($i * 3)s"
            $up = $true
            break
        }
    }
    if (-not $up) {
        W "[worker] NOT up after 36s, retry launch"
        Start-Process -FilePath $Exe
        Start-Sleep -Seconds 15
        $n = @(Get-Process -Name "DeepSeek Harness" -ErrorAction SilentlyContinue).Count
        W "[worker] after retry, count=$n"
    }
    W "=== [worker] done ==="
    schtasks /Delete /TN $TaskName /F 2>&1 | Out-Null
    return
}

# ─────────────────────────── 调度态 ───────────────────────────
if ($Status) {
    if (Test-Path $LogPath) { Get-Content $LogPath -Encoding UTF8 -Tail 40 } else { "no restart log yet: $LogPath" }
    return
}

if ($Now) { $Delay = 0 }

W "=== restart requested, delay=${Delay}s, via schtasks (脱离进程树) ==="

$argline = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SelfPath`" -Worker -Delay $Delay"

# 清掉可能残留的旧任务
schtasks /Delete /TN $TaskName /F 2>&1 | Out-Null

schtasks /Create /TN $TaskName /SC ONCE /ST 23:59 /F /TR "powershell.exe $argline" 2>&1 | ForEach-Object {
    if ($_ -match '\S') { W "  schtasks create: $_" }
}

$run = schtasks /Run /TN $TaskName 2>&1
W "  schtasks run: $run"

Start-Sleep -Seconds 2
$q = schtasks /Query /TN $TaskName /FO LIST 2>&1 | Select-String 'Status|状态' | Select-Object -First 1
W "  task status: $q"

Write-Host ""
Write-Host "重启任务已交给计划任务（$TaskName），${Delay} 秒后开始。" -ForegroundColor Green
Write-Host "日志: $LogPath"
Write-Host "查看进度: .\restart-dsh.ps1 -Status"
Write-Host ""
Write-Host "和旧版的区别：worker 的父进程是 Task Scheduler，不在 DSH 的 job object 里，不会被连带杀掉。" -ForegroundColor DarkGray