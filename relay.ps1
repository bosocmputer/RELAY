<#
.SYNOPSIS
    RELAY Central Terminal Hub (v1.0) — Modern Interactive TUI สำหรับ Windows (PowerShell)
.DESCRIPTION
    รองรับปุ่มลูกศร ↑/↓ + Enter, คีย์ลัด, Slash Commands (/model, /connect, /test)
    พร้อมตั้งค่าการเชื่อมต่อ CLI และเลือก Model ของแต่ละค่าย/ตำแหน่งในหน้าจอเดียว
#>
param(
    [Parameter(Position=0)]
    [string]$SubCommand = "hub",

    [Parameter(Position=1)]
    [string]$Arg2 = "new"
)

$ErrorActionPreference = "Stop"
$GlobalDir = Join-Path $HOME ".agents"
$GlobalRolesConf = Join-Path $GlobalDir "relay-roles.conf"
$ProjectDir = (Get-Location).Path
$ProjectName = Split-Path -Leaf $ProjectDir
$RelayDir = Join-Path $ProjectDir ".relay"
$ProjectRolesConf = Join-Path $RelayDir "roles.conf"

$Script:ROLE_PO = "gemini";   $Script:MODEL_PO = "default"
$Script:ROLE_ARCH = "claude"; $Script:MODEL_ARCH = "default"
$Script:ROLE_DEV = "claude";  $Script:MODEL_DEV = "default"
$Script:ROLE_QA = "codex";    $Script:MODEL_QA = "default"
$Script:CONFIG_SOURCE = "Global (~/.agents/relay-roles.conf)"
$Script:ACTIVE_TASK = ""

function Load-RoleConfig {
    $Script:ROLE_PO = "gemini";   $Script:MODEL_PO = "default"
    $Script:ROLE_ARCH = "claude"; $Script:MODEL_ARCH = "default"
    $Script:ROLE_DEV = "claude";  $Script:MODEL_DEV = "default"
    $Script:ROLE_QA = "codex";    $Script:MODEL_QA = "default"
    $Script:CONFIG_SOURCE = "Global (~/.agents/relay-roles.conf)"

    foreach ($confFile in @($GlobalRolesConf, $ProjectRolesConf)) {
        if (Test-Path $confFile) {
            if ($confFile -eq $ProjectRolesConf) {
                $Script:CONFIG_SOURCE = "Project (.relay/roles.conf)"
            }
            Get-Content $confFile -Encoding UTF8 | ForEach-Object {
                $line = $_.Trim()
                if ($line -match '^ROLE_PO="([^"]+)"')    { $Script:ROLE_PO = $Matches[1] }
                if ($line -match '^MODEL_PO="([^"]+)"')   { $Script:MODEL_PO = $Matches[1] }
                if ($line -match '^ROLE_ARCH="([^"]+)"')  { $Script:ROLE_ARCH = $Matches[1] }
                if ($line -match '^MODEL_ARCH="([^"]+)"') { $Script:MODEL_ARCH = $Matches[1] }
                if ($line -match '^ROLE_DEV="([^"]+)"')   { $Script:ROLE_DEV = $Matches[1] }
                if ($line -match '^MODEL_DEV="([^"]+)"')  { $Script:MODEL_DEV = $Matches[1] }
                if ($line -match '^ROLE_QA="([^"]+)"')    { $Script:ROLE_QA = $Matches[1] }
                if ($line -match '^MODEL_QA="([^"]+)"')   { $Script:MODEL_QA = $Matches[1] }
            }
        }
    }
}

function Save-RoleConfig([string]$TargetFile) {
    $parent = Split-Path -Parent $TargetFile
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $content = @"
# RELAY Role-to-Provider & Model Configuration
ROLE_PO="$($Script:ROLE_PO)"
MODEL_PO="$($Script:MODEL_PO)"
ROLE_ARCH="$($Script:ROLE_ARCH)"
MODEL_ARCH="$($Script:MODEL_ARCH)"
ROLE_DEV="$($Script:ROLE_DEV)"
MODEL_DEV="$($Script:MODEL_DEV)"
ROLE_QA="$($Script:ROLE_QA)"
MODEL_QA="$($Script:MODEL_QA)"
"@
    Set-Content -Path $TargetFile -Value $content -Encoding UTF8
}

function Test-ProviderInstalled([string]$Provider) {
    return [bool](Get-Command $Provider -ErrorAction SilentlyContinue)
}

function Get-EffectiveModelLabel([string]$Provider, [string]$ConfiguredModel) {
    if (-not [string]::IsNullOrWhiteSpace($ConfiguredModel) -and $ConfiguredModel -ne "default") {
        return $ConfiguredModel
    }
    switch ($Provider) {
        "claude" { return "sonnet (CLI default)" }
        "codex"  { return "o3 (CLI default)" }
        "gemini" { return "gemini-2.5-pro (CLI default)" }
        default  { return "default" }
    }
}

function Get-ActiveTask {
    $tasksPath = Join-Path $RelayDir "tasks"
    if (-not (Test-Path $tasksPath)) { $Script:ACTIVE_TASK = ""; return }
    $dirs = Get-ChildItem -Path $tasksPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name
    if ($dirs -and $dirs.Count -gt 0) { $Script:ACTIVE_TASK = $dirs[-1].Name } else { $Script:ACTIVE_TASK = "" }
}

function Invoke-InteractiveMenu([string]$Title, [string[]]$Items) {
    $selected = 0
    $count = $Items.Count
    Write-Host ""
    Write-Host $Title -ForegroundColor Yellow
    Write-Host "ใช้ปุ่มลูกศร ↑/↓ เพื่อเลื่อนแถบสี แล้วกด Enter เพื่อเลือก (หรือกดคีย์ลัดในวงเล็บ [...])" -ForegroundColor DarkGray

    $startTop = [Console]::CursorTop
    while ($true) {
        [Console]::SetCursorPosition(0, $startTop)
        for ($i = 0; $i -lt $count; $i++) {
            $parts = $Items[$i] -split '\|', 2
            $k = $parts[0]
            $lbl = $parts[1]
            if ($i -eq $selected) {
                Write-Host ("  ❯ [{0}] {1,-66}" -f $k, $lbl) -BackgroundColor DarkCyan -ForegroundColor White
            } else {
                Write-Host ("    [{0}] {1,-66}" -f $k, $lbl) -ForegroundColor Gray
            }
        }
        $curKey = ($Items[$selected] -split '\|', 2)[0]
        Write-Host "╭──────────────────────────────────────────────────────────────────────────────╮" -ForegroundColor DarkGray
        Write-Host ("│ ❯ เลือก: [{0}] (↑/↓ เลื่อน • Enter ยืนยัน • พิมพ์ / เพื่อใช้คำสั่ง /model, /connect, /test) │" -f $curKey) -ForegroundColor Cyan
        Write-Host "╰──────────────────────────────────────────────────────────────────────────────╯" -ForegroundColor DarkGray

        $keyInfo = [Console]::ReadKey($true)
        if ($keyInfo.Key -eq [ConsoleKey]::UpArrow) {
            $selected = ($selected - 1 + $count) % $count
        } elseif ($keyInfo.Key -eq [ConsoleKey]::DownArrow) {
            $selected = ($selected + 1) % $count
        } elseif ($keyInfo.Key -eq [ConsoleKey]::Enter) {
            return ($Items[$selected] -split '\|', 2)[0]
        } elseif ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            return "b"
        } elseif ($keyInfo.KeyChar -eq '/') {
            $cmd = Read-Host "❯ /"
            return "/$cmd"
        } else {
            $ch = $keyInfo.KeyChar.ToString().ToLower()
            foreach ($item in $Items) {
                $ik = ($item -split '\|', 2)[0].ToLower()
                if ($ch -eq $ik) { return $ik }
            }
        }
    }
}

function Print-DashboardHeader {
    Load-RoleConfig
    Get-ActiveTask
    Write-Host ""
    Write-Host "╭──────────────────────────────────────────────────────────────────────────────╮" -ForegroundColor DarkYellow
    Write-Host "│ ✻ Welcome to RELAY v1.0 — Multi-Agent Specification & Handoff Orchestrator   │" -ForegroundColor Yellow
    Write-Host "╰──────────────────────────────────────────────────────────────────────────────╯" -ForegroundColor DarkYellow
    Write-Host " ██╗      ██████╗  ███████╗ ██╗       █████╗  ██╗   ██╗" -ForegroundColor Cyan
    Write-Host " ╚██╗     ██╔══██╗ ██╔════╝ ██║      ██╔══██╗ ╚██╗ ██╔╝" -ForegroundColor Cyan
    Write-Host "  ╚██╗    ██████╔╝ █████╗   ██║      ███████║  ╚████╔╝ " -ForegroundColor Blue
    Write-Host "  ██╔╝    ██╔══██╗ ██╔══╝   ██║      ██╔══██║   ╚██╔╝  " -ForegroundColor Magenta
    Write-Host " ██╔╝     ██║  ██║ ███████╗ ███████╗ ██║  ██║    ██║   " -ForegroundColor Magenta
    Write-Host " ╚═╝      ╚═╝  ╚═╝ ╚══════╝ ╚══════╝ ╚═╝  ╚═╝    ╚═╝   " -ForegroundColor Red
    Write-Host "╭─────────────────────── RELAY v1.0 • Control Center ──────────────────────────╮" -ForegroundColor Yellow
    Write-Host ("│  1. @po (Product)   ➔ {0,-6} │ โมเดล: {1,-22} │ {2}" -f $Script:ROLE_PO, (Get-EffectiveModelLabel $Script:ROLE_PO $Script:MODEL_PO), $(if (Test-ProviderInstalled $Script:ROLE_PO) { "● พร้อมใช้งาน" } else { "○ ยังไม่ติดตั้ง" }))
    Write-Host ("│  2. @arch & @pm     ➔ {0,-6} │ โมเดล: {1,-22} │ {2}" -f $Script:ROLE_ARCH, (Get-EffectiveModelLabel $Script:ROLE_ARCH $Script:MODEL_ARCH), $(if (Test-ProviderInstalled $Script:ROLE_ARCH) { "● พร้อมใช้งาน" } else { "○ ยังไม่ติดตั้ง" }))
    Write-Host ("│  3. @dev (Worktree) ➔ {0,-6} │ โมเดล: {1,-22} │ {2}" -f $Script:ROLE_DEV, (Get-EffectiveModelLabel $Script:ROLE_DEV $Script:MODEL_DEV), $(if (Test-ProviderInstalled $Script:ROLE_DEV) { "● พร้อมใช้งาน" } else { "○ ยังไม่ติดตั้ง" }))
    Write-Host ("│  4. @qa & @sec      ➔ {0,-6} │ โมเดล: {1,-22} │ {2}" -f $Script:ROLE_QA, (Get-EffectiveModelLabel $Script:ROLE_QA $Script:MODEL_QA), $(if (Test-ProviderInstalled $Script:ROLE_QA) { "● พร้อมใช้งาน" } else { "○ ยังไม่ติดตั้ง" }))
    Write-Host "╰──────────────────────────────────────────────────────────────────────────────╯" -ForegroundColor Yellow
}

if ($SubCommand -eq "status") { Print-DashboardHeader; exit 0 }

while ($true) {
    Print-DashboardHeader
    $act = Invoke-InteractiveMenu "🎛️  เลือกคำสั่งการทำงาน (ใช้ปุ่มลูกศร ↑/↓ เลื่อนแถบสีแล้วกด Enter)" @(
        "1|เริ่มขั้นตอนที่ 1 (@po)        — วิเคราะห์ความต้องการและสร้าง SPEC.md",
        "2|เริ่มขั้นตอนที่ 2 (@arch/@pm)  — อ่าน SPEC.md แล้วสร้าง ARCH.md & PLAN.md",
        "3|เริ่มขั้นตอนที่ 3 (@dev)       — แยก Git Worktree อัตโนมัติและพัฒนาโค้ด",
        "4|เริ่มขั้นตอนที่ 4 (@qa/@sec)   — รันชุดทดสอบ + ตรวจความปลอดภัย + สรุป QA_REPORT.md",
        "c|ตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่ง (/model)",
        "d|จัดการการเชื่อมต่อ CLI, ติดตั้ง & Login ทั้ง 3 ค่าย (/connect)",
        "t|ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่ง — เช็กบทบาท & Skills (/test)",
        "q|ออกจากโปรแกรม (/quit)"
    )
    if ($act -eq "q" -or $act -eq "/quit" -or $act -eq "/exit") { exit 0 }
}
