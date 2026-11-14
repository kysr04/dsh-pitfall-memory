#Requires -Version 5.1
<#
  meow-memory 手工安装 / 回滚工具（desktop profile）
  用法:
    meow-memory-setup.ps1 rollback    # 完全卸载，恢复安装前状态
    meow-memory-setup.ps1 status      # 检查当前是否装着
    meow-memory-setup.ps1 install     # 重新装回（需 _repos/dsh-meow-memory 已构建）
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Action = 'status',
    # meow-memory 源码目录（已构建出 lib/index.js 的那份）
    [string]$SourceDir = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$ProfileDir = Join-Path $env:USERPROFILE '.dsh\profiles\desktop'
$PkgJson    = Join-Path $ProfileDir 'package.json'
$PatchYml   = Join-Path $ProfileDir 'cordis.patch.yml'
$Junction   = Join-Path $ProfileDir 'node_modules\meow-memory'

# 源码目录：优先用 -SourceDir，其次环境变量 DSH_MEOW_SRC，最后按常见位置探测
$SrcDir = $SourceDir
if (-not $SrcDir) { $SrcDir = $env:DSH_MEOW_SRC }
if (-not $SrcDir -or -not (Test-Path (Join-Path $SrcDir 'lib\index.js'))) {
    $probe = @(
        (Join-Path $env:USERPROFILE 'dsh-meow-memory'),
        (Join-Path $env:USERPROFILE 'Downloads\dsh-meow-memory'),
        (Join-Path $env:USERPROFILE '_repos\dsh-meow-memory'),
        'F:\工作区\_repos\dsh-meow-memory'
    ) | Where-Object { $_ -and (Test-Path (Join-Path $_ 'lib\index.js')) }
    if (@($probe).Count -gt 0) { $SrcDir = @($probe)[0] }
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-Status {
    $linked = Test-Path $Junction
    $inDeps = $false; $inBundles = $false
    if (Test-Path $PkgJson) {
        $j = Get-Content $PkgJson -Raw -Encoding UTF8 | ConvertFrom-Json
        $inDeps = $null -ne $j.dependencies.'meow-memory'
        $inBundles = @($j.dsh.profile.bundles) -contains 'meow-memory'
    }
    $inPatch = (Test-Path $PatchYml) -and [bool](Select-String -Path $PatchYml -Pattern '^-\s*id:\s*meow-memory' -Quiet)
    [pscustomobject]@{
        Junction = $linked; Deps = $inDeps; Bundles = $inBundles; PatchConfig = $inPatch
        Installed = ($linked -and $inDeps -and $inBundles -and $inPatch)
    }
}

switch ($Action.ToLower()) {
    'status' {
        $s = Get-Status
        "Junction      : $($s.Junction)"
        "dependencies  : $($s.Deps)"
        "bundles       : $($s.Bundles)"
        "patch config  : $($s.PatchConfig)"
        "=> Installed  : $($s.Installed)"
        ""
        "源目录存在: $(Test-Path $SrcDir)"
        "构建产物存在: $(Test-Path (Join-Path $SrcDir 'lib\index.js'))"
    }

    'rollback' {
        $bk = Join-Path $env:USERPROFILE (".dsh\profiles\_backup-desktop-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Force -Path $bk | Out-Null
        foreach ($f in @('package.json', 'cordis.patch.yml')) {
            $src = Join-Path $ProfileDir $f
            if (Test-Path $src) { Copy-Item $src $bk -Force }
        }
        "已备份到: $bk"

        if (Test-Path $Junction) {
            cmd /c "rmdir `"$Junction`"" 2>$null
            if (Test-Path $Junction) { "!! junction 删除失败，可能被进程占用" } else { "junction 已删除" }
        }

        if (Test-Path $PkgJson) {
            $t = Get-Content $PkgJson -Raw -Encoding UTF8
            $t = $t -replace '(?m)^\s*"meow-memory":\s*"link:[^"]*",?\s*\r?\n', ''
            $t = $t -replace '(?m)^(\s*)"dshmarket",\s*\r?\n(\s*)"meow-memory"\s*\r?\n', "`$1`"dshmarket`"`r`n"
            Write-Utf8NoBom $PkgJson $t
            try { $null = Get-Content $PkgJson -Raw -Encoding UTF8 | ConvertFrom-Json; "package.json 已清理（JSON 合法）" }
            catch { "!! package.json JSON 非法，请用备份恢复: $bk" }
        }

        if (Test-Path $PatchYml) {
            $lines = Get-Content $PatchYml -Encoding UTF8
            $out = New-Object System.Collections.Generic.List[string]
            $skip = $false
            foreach ($l in $lines) {
                if ($l -match '^#\s*---\s*meow-memory') { $skip = $true; continue }
                if ($skip -and $l -match '^-\s*id:\s*meow-memory') { $skip = $true; continue }
                if ($skip) {
                    if ($l -match '^\s+\S' -or $l -match '^\s*$') { continue } else { $skip = $false }
                }
                $out.Add($l)
            }
            Write-Utf8NoBom $PatchYml (($out -join "`r`n") + "`r`n")
            "cordis.patch.yml 已清理"
        }

        ""
        "回滚完成。重启 DeepSeek Harness 后生效。"
        "如果 DSH 无法启动，用备份整份覆盖: $bk"
    }

    'install' {
        if (-not (Test-Path (Join-Path $SrcDir 'lib\index.js'))) {
            throw "构建产物缺失，先在 $SrcDir 跑: pnpm install --ignore-scripts; node build.mjs"
        }
        $nm = Join-Path $ProfileDir 'node_modules'
        if (-not (Test-Path $nm)) { New-Item -ItemType Directory -Force -Path $nm | Out-Null }
        if (-not (Test-Path $Junction)) {
            New-Item -ItemType Junction -Path $Junction -Target $SrcDir | Out-Null
            "junction 已建立"
        } else { "junction 已存在" }
        "下一步手工确认 package.json 的 dependencies 与 bundles 含 meow-memory，然后重启 DSH。"
    }

    default { "未知动作: $Action（status / install / rollback）" }
}