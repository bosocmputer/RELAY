<#
.SYNOPSIS
    RELAY Central Terminal Hub (v1.0) — Guided 3-Stage Progressive UX สำหรับ Windows (PowerShell)
.DESCRIPTION
    • โทนสี Minimalist High-Contrast (Monochrome Blue + Status Dots)
    • ไฮไลต์บรรทัดที่เลือกด้วย ❯ + สีน้ำเงินตัวหนาทั้งบรรทัด
    • ระบบนำทาง 3 ขั้นตอนอัตโนมัติ (Guided 3-Stage Progressive UX):
      ขั้นที่ 1: ตั้งค่า AI ให้ครบ 4 ตำแหน่ง (Quick Setup คลิกเดียวเสร็จ ซ่อนเมนูที่ยังไม่ถึงคิว)
      ขั้นที่ 2: เตรียมโฟลเดอร์โปรเจกต์ (.relay/PROJECT_STATE.md)
      ขั้นที่ 3: เริ่มสั่งงานตามใบงาน 1-5 (เลื่อนตัวชี้ ❯ ไปยังขั้นตอนถัดไปอัตโนมัติ)
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
$Script:UX_STAGE = 1

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

    $hasProjectState = Test-Path (Join-Path $RelayDir "PROJECT_STATE.md")
    if (-not $Script:ALL_READY) {
        $Script:UX_STAGE = 1
    } elseif (($ProjectDir -eq $HOME) -or (-not $hasProjectState)) {
        $Script:UX_STAGE = 2
    } else {
        $Script:UX_STAGE = 3
    }
}

function Get-RoleStatusText([string]$Provider, [string]$Model) {
    if (-not (Test-ProviderInstalled $Provider)) { return "✖ ยังไม่ติดตั้ง CLI" }
    if (-not (Test-ModelExplicitlySet $Model))    { return "▲ รอเลือกโมเดล" }
    return "● พร้อมใช้งาน"
}

function Invoke-QuickPresetMenu {
    $choice = Invoke-InteractiveMenu "เลือกชุดการตั้งค่าด่วน (กำหนดค่ายและ Model ให้ครบทั้ง 4 ตำแหน่งในคลิกเดียว)" 0 @(
        "1|★ ชุดแนะนำ Multi-Vendor — @po=gemini(2.5-pro), @arch=claude(opus), @dev=claude(sonnet), @qa=codex(o3)",
        "2|All-Claude Preset       — ใช้ Claude ทั้ง 4 ตำแหน่ง (@po=sonnet, @arch=opus, @dev=sonnet, @qa=opus)",
        "3|All-Gemini Preset       — ใช้ Gemini ทั้ง 4 ตำแหน่ง (gemini-2.5-pro ทั้ง 4 ตำแหน่ง)",
        "4|All-Codex Preset        — ใช้ Codex ทั้ง 4 ตำแหน่ง (o3 ทั้ง 4 ตำแหน่ง)",
        "b|ย้อนกลับ"
    )
    switch ($choice) {
        "1" {
            $Script:ROLE_PO="gemini";   $Script:MODEL_PO="gemini-2.5-pro"
            $Script:ROLE_ARCH="claude"; $Script:MODEL_ARCH="opus"
            $Script:ROLE_DEV="claude";  $Script:MODEL_DEV="sonnet"
            $Script:ROLE_QA="codex";    $Script:MODEL_QA="o3"
            Save-RoleConfig $GlobalRolesConf
        }
        "2" {
            $Script:ROLE_PO="claude";   $Script:MODEL_PO="sonnet"
            $Script:ROLE_ARCH="claude"; $Script:MODEL_ARCH="opus"
            $Script:ROLE_DEV="claude";  $Script:MODEL_DEV="sonnet"
            $Script:ROLE_QA="claude";   $Script:MODEL_QA="opus"
            Save-RoleConfig $GlobalRolesConf
        }
        "3" {
            $Script:ROLE_PO="gemini";   $Script:MODEL_PO="gemini-2.5-pro"
            $Script:ROLE_ARCH="gemini"; $Script:MODEL_ARCH="gemini-2.5-pro"
            $Script:ROLE_DEV="gemini";  $Script:MODEL_DEV="gemini-2.5-pro"
            $Script:ROLE_QA="gemini";   $Script:MODEL_QA="gemini-2.5-pro"
            Save-RoleConfig $GlobalRolesConf
        }
        "4" {
            $Script:ROLE_PO="codex";   $Script:MODEL_PO="o3"
            $Script:ROLE_ARCH="codex"; $Script:MODEL_ARCH="o3"
            $Script:ROLE_DEV="codex";  $Script:MODEL_DEV="o3"
            $Script:ROLE_QA="codex";   $Script:MODEL_QA="o3"
            Save-RoleConfig $GlobalRolesConf
        }
    }
}

function Invoke-InteractiveMenu([string]$Title, [int]$DefaultIndex, [string[]]$Items) {
    $selected = $DefaultIndex
    $count = $Items.Count
    if ($selected -ge $count) { $selected = 0 }
    Write-Host ""
    Write-Host $Title
    Write-Host "ใช้ปุ่มลูกศร ↑/↓ เลื่อนเลือก • กด Enter ยืนยัน • หรือกดคีย์ลัด [...] ได้ทันที" -ForegroundColor DarkGray

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
        Write-Host "╭────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue
        Write-Host ("│ ❯ คำสั่งที่เลือก: [{0}] (↑/↓ เลื่อน • Enter ยืนยัน • กด / พิมพ์ /model, /connect, /test)" -f $curKey) -ForegroundColor Blue
        Write-Host "╰────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue

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
    Write-Host " ██╗      ██████╗  ███████╗ ██╗       █████╗  ██╗   ██╗" -ForegroundColor Blue
    Write-Host " ╚██╗     ██╔══██╗ ██╔════╝ ██║      ██╔══██╗ ╚██╗ ██╔╝" -ForegroundColor Blue
    Write-Host "  ╚██╗    ██████╔╝ █████╗   ██║      ███████║  ╚████╔╝ " -ForegroundColor Blue
    Write-Host "  ██╔╝    ██╔══██╗ ██╔══╝   ██║      ██╔══██║   ╚██╔╝  " -ForegroundColor Blue
    Write-Host " ██╔╝     ██║  ██║ ███████╗ ███████╗ ██║  ██║    ██║   " -ForegroundColor Blue
    Write-Host " ╚═╝      ╚═╝  ╚═╝ ╚══════╝ ╚══════╝ ╚═╝  ╚═╝    ╚═╝   RELAY v1.0 • Multi-Agent Handoff Hub" -ForegroundColor DarkBlue
    Write-Host "╭────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue
    if ($Script:UX_STAGE -eq 1) {
        Write-Host ("│ ลำดับงาน : ● [ขั้นที่ 1: ตั้งค่า AI ({0}/4)] ──➔ ○ ขั้นที่ 2: เตรียมโปรเจกต์ ──➔ ○ ขั้นที่ 3: เริ่มสั่งงาน" -f $Script:READY_COUNT) -ForegroundColor Blue
    } elseif ($Script:UX_STAGE -eq 2) {
        Write-Host "│ ลำดับงาน : ✓ ขั้นที่ 1: ตั้งค่า AI (4/4) ──➔ ● [ขั้นที่ 2: เตรียมโปรเจกต์] ──➔ ○ ขั้นที่ 3: เริ่มสั่งงาน" -ForegroundColor Blue
    } else {
        Write-Host "│ ลำดับงาน : ✓ ขั้นที่ 1: ตั้งค่า AI (4/4) ──➔ ✓ ขั้นที่ 2: เตรียมโปรเจกต์ ──➔ ● [ขั้นที่ 3: เริ่มสั่งงาน]" -ForegroundColor Blue
    }
    Write-Host "├────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue
    Write-Host ("│ 1. @po (Product)    ➔ {0,-6} │ {1,-18} │ {2}" -f $Script:ROLE_PO, $Script:MODEL_PO, (Get-RoleStatusText $Script:ROLE_PO $Script:MODEL_PO))
    Write-Host ("│ 2. @arch & @pm      ➔ {0,-6} │ {1,-18} │ {2}" -f $Script:ROLE_ARCH, $Script:MODEL_ARCH, (Get-RoleStatusText $Script:ROLE_ARCH $Script:MODEL_ARCH))
    Write-Host ("│ 3. @dev (Worktree)  ➔ {0,-6} │ {1,-18} │ {2}" -f $Script:ROLE_DEV, $Script:MODEL_DEV, (Get-RoleStatusText $Script:ROLE_DEV $Script:MODEL_DEV))
    Write-Host ("│ 4. @qa & @sec       ➔ {0,-6} │ {1,-18} │ {2}" -f $Script:ROLE_QA, $Script:MODEL_QA, (Get-RoleStatusText $Script:ROLE_QA $Script:MODEL_QA))
    Write-Host "├────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue
    if ($Script:UX_STAGE -eq 1) {
        Write-Host "│ 👉 สิ่งที่ต้องทำตอนนี้ (ขั้นที่ 1/3): กด Enter ที่ข้อ [1] เพื่อตั้งค่า AI ครบทั้ง 4 ตำแหน่งในคลิกเดียว" -ForegroundColor Blue
    } elseif ($Script:UX_STAGE -eq 2) {
        Write-Host ("│ 👉 สิ่งที่ต้องทำตอนนี้ (ขั้นที่ 2/3): เตรียมโครงสร้าง .relay/ สำหรับโปรเจกต์ '{0}' (กด Enter ที่ข้อ [1])" -f $ProjectName) -ForegroundColor Blue
    } else {
        Write-Host "│ 👉 ขั้นตอนถัดไปที่แนะนำ (ขั้นที่ 3/3): กด Enter ที่ข้อที่มีเครื่องหมาย ★ เพื่อเริ่มทำงาน" -ForegroundColor Blue
    }
    Write-Host "╰────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue
}

if ($SubCommand -eq "status") { Print-DashboardHeader; exit 0 }

while ($true) {
    Print-DashboardHeader
    if ($Script:UX_STAGE -eq 1) {
        $act = Invoke-InteractiveMenu "ขั้นที่ 1/3: ตั้งค่าค่าย AI & Model ให้ครบ 4 ตำแหน่งก่อนเริ่มใช้งาน (พร้อม $($Script:READY_COUNT)/4)" 0 @(
            "1|★ ตั้งค่าด่วนครบ 4 ตำแหน่งในคลิกเดียว (Quick Setup — แนะนำสำหรับเริ่มต้น)",
            "q|ออกจากโปรแกรม (/quit)"
        )
        if ($act -eq "1") { Invoke-QuickPresetMenu }
        if ($act -eq "q" -or $act -eq "/quit" -or $act -eq "/exit") { exit 0 }
    } elseif ($Script:UX_STAGE -eq 2) {
        $act = Invoke-InteractiveMenu "ขั้นที่ 2/3: เตรียมโครงสร้าง .relay/ สำหรับโปรเจกต์ '$ProjectName'" 0 @(
            "1|★ เริ่มโปรเจกต์ใหม่ตั้งแต่ศูนย์ในโฟลเดอร์นี้ (Greenfield — สร้าง .relay/ ทันที)",
            "q|ออกจากโปรแกรม (/quit)"
        )
        if ($act -eq "1") { & (Join-Path $GlobalDir "bin\relay-init.ps1") $ProjectDir "new" }
        if ($act -eq "q" -or $act -eq "/quit" -or $act -eq "/exit") { exit 0 }
    } else {
        $act = Invoke-InteractiveMenu "ขั้นที่ 3/3: เลือกขั้นตอนการทำงานสำหรับโปรเจกต์ '$ProjectName'" 0 @(
            "1|★ [แนะนำให้เริ่มที่นี่] ขั้นตอนที่ 1 (@po) — วิเคราะห์ความต้องการและสร้าง SPEC.md",
            "2|ขั้นตอนที่ 2 (@arch/@pm) — สร้าง ARCH.md & PLAN.md",
            "3|ขั้นตอนที่ 3 (@dev)      — แยก Git Worktree อัตโนมัติและเขียนโค้ด",
            "4|ขั้นตอนที่ 4 (@qa/@sec)  — รันชุดทดสอบ + ตรวจความปลอดภัย + QA_REPORT.md",
            "c|ตั้งค่าค่าย AI & เปลี่ยน Model ประจำตำแหน่ง (/model)",
            "q|ออกจากโปรแกรม (/quit)"
        )
        if ($act -eq "c") { Invoke-QuickPresetMenu }
        if ($act -eq "q" -or $act -eq "/quit" -or $act -eq "/exit") { exit 0 }
    }
}
