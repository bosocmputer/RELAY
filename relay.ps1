<#
.SYNOPSIS
    RELAY Central Terminal Hub (v1.0) — Full-Color Interactive TUI สำหรับ Windows (PowerShell)
.DESCRIPTION
    • 3D Pixel-Block Gradient Banner (> RELAY)
    • รองรับปุ่มลูกศร ↑/↓ + Enter, คีย์ลัด, Slash Commands (/model, /connect, /test)
    • ระบบ Readiness Gate: บังคับตั้งค่า Roles + Provider + Model ให้ครบทั้ง 4 ตำแหน่งก่อนเริ่มถามงาน
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
$Script:READY_COUNT = 0
$Script:ALL_READY = $false

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

function Test-ModelExplicitlySet([string]$Model) {
    return (-not [string]::IsNullOrWhiteSpace($Model) -and $Model -ne "default" -and $Model -ne "unconfigured")
}

function Test-RoleReady([string]$Provider, [string]$Model) {
    return ((Test-ProviderInstalled $Provider) -and (Test-ModelExplicitlySet $Model))
}

function Update-ReadinessState {
    Load-RoleConfig
    $c = 0
    if (Test-RoleReady $Script:ROLE_PO   $Script:MODEL_PO)   { $c++ }
    if (Test-RoleReady $Script:ROLE_ARCH $Script:MODEL_ARCH) { $c++ }
    if (Test-RoleReady $Script:ROLE_DEV  $Script:MODEL_DEV)  { $c++ }
    if (Test-RoleReady $Script:ROLE_QA   $Script:MODEL_QA)   { $c++ }
    $Script:READY_COUNT = $c
    $Script:ALL_READY = ($c -eq 4)
}

function Get-RoleStatusText([string]$Provider, [string]$Model) {
    if (-not (Test-ProviderInstalled $Provider)) { return "✖ ยังไม่ติดตั้ง CLI (กด [c]/[d])" }
    if (-not (Test-ModelExplicitlySet $Model))    { return "⚠️ รอเลือกโมเดล (กด [c])" }
    return "● พร้อมใช้งาน 100%"
}

function Invoke-InteractiveMenu([string]$Title, [int]$DefaultIndex, [string[]]$Items) {
    $selected = $DefaultIndex
    $count = $Items.Count
    if ($selected -ge $count) { $selected = 0 }
    Write-Host ""
    Write-Host $Title -ForegroundColor Yellow
    Write-Host "ใช้ปุ่มลูกศร ↑/↓ เลื่อนแถบสี • กด Enter เพื่อยืนยัน • หรือกดคีย์ลัดในวงเล็บ [...]" -ForegroundColor Gray

    $startTop = [Console]::CursorTop
    while ($true) {
        [Console]::SetCursorPosition(0, $startTop)
        for ($i = 0; $i -lt $count; $i++) {
            $parts = $Items[$i] -split '\|', 2
            $k = $parts[0]
            $lbl = $parts[1]
            if ($i -eq $selected) {
                Write-Host ("  ❯ [{0}] {1}" -f $k, $lbl) -ForegroundColor Blue
            } else {
                Write-Host ("    [{0}] {1}" -f $k, $lbl)
            }
        }
        $curKey = ($Items[$selected] -split '\|', 2)[0]
        Write-Host "╭──────────────────────────────────────────────────────────────────────────────╮" -ForegroundColor Blue
        Write-Host ("│ ❯ คำสั่งที่เลือก: [{0}] (↑/↓ เลื่อน • Enter เลือก • กด / พิมพ์คำสั่ง /model, /connect, /test) │" -f $curKey) -ForegroundColor Magenta
        Write-Host "╰──────────────────────────────────────────────────────────────────────────────╯" -ForegroundColor Blue

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
    Update-ReadinessState
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
    Write-Host ("│  1. @po (Product)   ➔ {0,-6} │ โมเดล: {1,-20} │ {2}" -f $Script:ROLE_PO, $Script:MODEL_PO, (Get-RoleStatusText $Script:ROLE_PO $Script:MODEL_PO)) -ForegroundColor Magenta
    Write-Host ("│  2. @arch & @pm     ➔ {0,-6} │ โมเดล: {1,-20} │ {2}" -f $Script:ROLE_ARCH, $Script:MODEL_ARCH, (Get-RoleStatusText $Script:ROLE_ARCH $Script:MODEL_ARCH)) -ForegroundColor Yellow
    Write-Host ("│  3. @dev (Worktree) ➔ {0,-6} │ โมเดล: {1,-20} │ {2}" -f $Script:ROLE_DEV, $Script:MODEL_DEV, (Get-RoleStatusText $Script:ROLE_DEV $Script:MODEL_DEV)) -ForegroundColor Cyan
    Write-Host ("│  4. @qa & @sec      ➔ {0,-6} │ โมเดล: {1,-20} │ {2}" -f $Script:ROLE_QA, $Script:MODEL_QA, (Get-RoleStatusText $Script:ROLE_QA $Script:MODEL_QA)) -ForegroundColor Green
    Write-Host "├──────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor Yellow
    if ($Script:ALL_READY) {
        Write-Host "│ 🔓 สถานะความพร้อม: ✅ ตั้งค่าครบทั้ง 4/4 ตำแหน่งแล้ว — พร้อมเริ่มถาม/สั่งงาน [1]-[5] ทันที!" -ForegroundColor Green
    } else {
        Write-Host ("│ 🔒 สถานะความพร้อม: ตั้งค่าพร้อม {0}/4 ตำแหน่ง — กรุณาตั้งค่าค่าย & โมเดลให้ครบทั้ง 4 ตำแหน่งใน [c] ก่อนเริ่มงาน!" -f $Script:READY_COUNT) -ForegroundColor Red
    }
    Write-Host "╰──────────────────────────────────────────────────────────────────────────────╯" -ForegroundColor Yellow
}

if ($SubCommand -eq "status") { Print-DashboardHeader; exit 0 }

while ($true) {
    Print-DashboardHeader
    $defIdx = if ($Script:ALL_READY) { 0 } else { 4 }
    $act = Invoke-InteractiveMenu "🎛️  เลือกคำสั่งการทำงาน (ใช้ปุ่มลูกศร ↑/↓ เลื่อนแถบสีแล้วกด Enter)" $defIdx @(
        "1|เริ่มขั้นตอนที่ 1 (@po)        — วิเคราะห์ความต้องการและสร้าง SPEC.md",
        "2|เริ่มขั้นตอนที่ 2 (@arch/@pm)  — อ่าน SPEC.md แล้วสร้าง ARCH.md & PLAN.md",
        "3|เริ่มขั้นตอนที่ 3 (@dev)       — แยก Git Worktree อัตโนมัติและพัฒนาโค้ด",
        "4|เริ่มขั้นตอนที่ 4 (@qa/@sec)   — รันชุดทดสอบ + ตรวจความปลอดภัย + สรุป QA_REPORT.md",
        "c|ตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่งให้ครบทั้ง 4 ตำแหน่ง (/model)",
        "d|จัดการการเชื่อมต่อ CLI, ติดตั้ง & Login ทั้ง 3 ค่าย (/connect)",
        "t|ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่ง — เช็กบทบาท & Skills (/test)",
        "q|ออกจากโปรแกรม (/quit)"
    )
    if ($act -eq "q" -or $act -eq "/quit" -or $act -eq "/exit") { exit 0 }
}
