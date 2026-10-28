<#
.SYNOPSIS
    RELAY Central Terminal Hub สำหรับ Windows (PowerShell)
.DESCRIPTION
    ศูนย์กลางการควบคุม ตั้งค่าค่าย AI/Model และตรวจสอบสถานะการเชื่อมต่อในหน้าต่าง PowerShell เดียว
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
$Script:CONFIG_SOURCE = "ค่าเริ่มต้นส่วนกลาง ($GlobalRolesConf)"
$Script:ACTIVE_TASK = ""

function Load-RoleConfig {
    $Script:ROLE_PO = "gemini";   $Script:MODEL_PO = "default"
    $Script:ROLE_ARCH = "claude"; $Script:MODEL_ARCH = "default"
    $Script:ROLE_DEV = "claude";  $Script:MODEL_DEV = "default"
    $Script:ROLE_QA = "codex";    $Script:MODEL_QA = "default"
    $Script:CONFIG_SOURCE = "ค่าเริ่มต้นส่วนกลาง ($GlobalRolesConf)"

    foreach ($confFile in @($GlobalRolesConf, $ProjectRolesConf)) {
        if (Test-Path $confFile) {
            if ($confFile -eq $ProjectRolesConf) {
                $Script:CONFIG_SOURCE = "เฉพาะโครงการนี้ (.relay/roles.conf)"
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

function Get-ProviderStatus([string]$Provider) {
    if (Get-Command $Provider -ErrorAction SilentlyContinue) {
        return "✅ พร้อมใช้งาน"
    }
    return "❌ ยังไม่ได้ติดตั้ง CLI (กด [d] เพื่อติดตั้ง)"
}

function Get-EffectiveModelLabel([string]$Provider, [string]$ConfiguredModel) {
    if (-not [string]::IsNullOrWhiteSpace($ConfiguredModel) -and $ConfiguredModel -ne "default") {
        return $ConfiguredModel
    }
    switch ($Provider) {
        "claude" { return "default (sonnet/opus)" }
        "codex"  { return "default (o3/gpt-5)" }
        "gemini" { return "default (gemini-2.5-pro)" }
        default  { return "default" }
    }
}

function Get-ActiveTask {
    $tasksPath = Join-Path $RelayDir "tasks"
    if (-not (Test-Path $tasksPath)) { $Script:ACTIVE_TASK = ""; return }
    $dirs = Get-ChildItem -Path $tasksPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name
    if ($dirs -and $dirs.Count -gt 0) { $Script:ACTIVE_TASK = $dirs[-1].Name } else { $Script:ACTIVE_TASK = "" }
}

function Select-ProviderForRole([string]$RoleLabel, [string]$CurrentVal) {
    Write-Host ""
    Write-Host "เลือกค่าย AI สำหรับ $RoleLabel (ค่าปัจจุบัน: $CurrentVal):" -ForegroundColor Cyan
    Write-Host "  [1] claude  (Anthropic Claude Code CLI)"
    Write-Host "  [2] codex   (OpenAI Codex CLI)"
    Write-Host "  [3] gemini  (Google Gemini CLI)"
    $choice = Read-Host "เลือกหมายเลขค่าย (1-3 หรือกด Enter เพื่อคงค่าเดิม $CurrentVal)"
    switch ($choice) {
        "1" { return "claude" }
        "2" { return "codex" }
        "3" { return "gemini" }
        default { return $CurrentVal }
    }
}

function Select-ModelForProvider([string]$Provider, [string]$RoleLabel, [string]$CurrentModel) {
    Write-Host ""
    Write-Host "เลือกโมเดล (Model) ของค่าย [$Provider] สำหรับ $RoleLabel (ค่าปัจจุบัน: $CurrentModel):" -ForegroundColor Cyan
    if ($Provider -eq "claude") {
        Write-Host "  [1] default (ค่าเริ่มต้นของ Claude Code) | [2] sonnet | [3] opus | [4] haiku | [5] ระบุชื่อเอง"
        $m = Read-Host "เลือกหมายเลข (1-5 หรือ Enter คงค่าเดิม)"
        switch ($m) { "1" { return "default" } "2" { return "sonnet" } "3" { return "opus" } "4" { return "haiku" } "5" { return (Read-Host "ระบุชื่อโมเดล") } default { return $CurrentModel } }
    } elseif ($Provider -eq "codex") {
        Write-Host "  [1] default (ค่าเริ่มต้นของ Codex) | [2] o3 | [3] o4-mini | [4] gpt-5 | [5] ระบุชื่อเอง"
        $m = Read-Host "เลือกหมายเลข (1-5 หรือ Enter คงค่าเดิม)"
        switch ($m) { "1" { return "default" } "2" { return "o3" } "3" { return "o4-mini" } "4" { return "gpt-5" } "5" { return (Read-Host "ระบุชื่อโมเดล") } default { return $CurrentModel } }
    } else {
        Write-Host "  [1] default (ค่าเริ่มต้นของ Gemini) | [2] gemini-2.5-pro | [3] gemini-2.5-flash | [4] ระบุชื่อเอง"
        $m = Read-Host "เลือกหมายเลข (1-4 หรือ Enter คงค่าเดิม)"
        switch ($m) { "1" { return "default" } "2" { return "gemini-2.5-pro" } "3" { return "gemini-2.5-flash" } "4" { return (Read-Host "ระบุชื่อโมเดล") } default { return $CurrentModel } }
    }
}

function Configure-RolesMenu {
    Load-RoleConfig
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "⚙️  ตั้งค่าจับคู่ตำแหน่งตัวแทน AI กับค่ายผู้ให้บริการและโมเดล (Role & Model Mapping)" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  [1] ระดับส่วนกลางของเครื่อง ($GlobalRolesConf) — มีผลกับทุกโครงการ"
    Write-Host "  [2] เฉพาะโครงการนี้ ($ProjectRolesConf) — มีผลเฉพาะโฟลเดอร์ $ProjectName"
    $scope = Read-Host "เลือกระดับการบันทึก [1 หรือ 2, ค่าเริ่มต้น=1]"

    $Script:ROLE_PO    = Select-ProviderForRole "ขั้นตอนที่ 1 (@po)" $Script:ROLE_PO
    $Script:MODEL_PO   = Select-ModelForProvider $Script:ROLE_PO "ขั้นตอนที่ 1 (@po)" $Script:MODEL_PO
    $Script:ROLE_ARCH  = Select-ProviderForRole "ขั้นตอนที่ 2 (@arch/@pm)" $Script:ROLE_ARCH
    $Script:MODEL_ARCH = Select-ModelForProvider $Script:ROLE_ARCH "ขั้นตอนที่ 2 (@arch/@pm)" $Script:MODEL_ARCH
    $Script:ROLE_DEV   = Select-ProviderForRole "ขั้นตอนที่ 3 (@dev)" $Script:ROLE_DEV
    $Script:MODEL_DEV  = Select-ModelForProvider $Script:ROLE_DEV "ขั้นตอนที่ 3 (@dev)" $Script:MODEL_DEV
    $Script:ROLE_QA    = Select-ProviderForRole "ขั้นตอนที่ 4 (@qa/@sec)" $Script:ROLE_QA
    $Script:MODEL_QA   = Select-ModelForProvider $Script:ROLE_QA "ขั้นตอนที่ 4 (@qa/@sec)" $Script:MODEL_QA

    if ($scope -eq "2") { Save-RoleConfig $ProjectRolesConf } else { Save-RoleConfig $GlobalRolesConf }
    Write-Host "✅ บันทึกการตั้งค่าเรียบร้อยแล้ว!" -ForegroundColor Green
}

function Run-DoctorMenu {
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "🩺 RELAY Doctor — ตรวจสอบสถานะการเชื่อมต่อ CLI และโมเดลของทั้ง 3 ค่าย" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    foreach ($p in @("claude", "codex", "gemini")) {
        $cmd = Get-Command $p -ErrorAction SilentlyContinue
        if ($cmd) {
            Write-Host "  • $p : ✅ ติดตั้งแล้ว ($($cmd.Source))" -ForegroundColor Green
        } else {
            Write-Host "  • $p : ❌ ยังไม่ได้ติดตั้งในเครื่อง" -ForegroundColor Red
        }
    }
    Write-Host "----------------------------------------------------------------------"
    Write-Host "  [1] ติดตั้ง CLI รวดเดียวครบทั้ง 3 ค่าย (npm install -g ...)"
    Write-Host "  [2] เปิด CLI เพื่อเข้าสู่ระบบ (Login)"
    Write-Host "  [Enter] กลับสู่หน้าจอหลัก"
    $c = Read-Host "เลือกหมายเลข"
    if ($c -eq "1") { npm install -g `@anthropic-ai/claude-code `@openai/codex `@google/gemini-cli }
    elseif ($c -eq "2") {
        $lp = Read-Host "ระบุชื่อค่ายที่ต้องการ Login (claude / codex / gemini)"
        if (Get-Command $lp -ErrorAction SilentlyContinue) { & $lp }
    }
}

function Print-Dashboard {
    Load-RoleConfig
    Get-ActiveTask
    $stateFile = Join-Path $RelayDir "PROJECT_STATE.md"
    $stateStatus = if (Test-Path $stateFile) { "✅ พร้อมใช้งาน (.relay/PROJECT_STATE.md)" } else { "❌ ยังไม่มี (กด [i] เพื่อสร้าง)" }

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "🎛️  RELAY Central Terminal Hub (v1.0) — โครงการ: $ProjectName" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "📂 โฟลเดอร์โครงการ : $ProjectDir"
    Write-Host "📌 สถานะโครงการ  : $stateStatus"
    Write-Host "📋 ใบงานปัจจุบัน   : $(if ($Script:ACTIVE_TASK) { $Script:ACTIVE_TASK } else { '(ยังไม่มีใบงาน — กด [1] หรือ [n] เพื่อเริ่มใบงานใหม่)' })"
    Write-Host "----------------------------------------------------------------------"
    Write-Host "🤖 สถานะตัวแทน AI, โมเดลปัจจุบัน และการเชื่อมต่อ ($($Script:CONFIG_SOURCE)):"
    Write-Host "   • ขั้นตอนที่ 1 (@po)       ➔ ค่าย: $($Script:ROLE_PO) | โมเดล: $(Get-EffectiveModelLabel $Script:ROLE_PO $Script:MODEL_PO) | $(Get-ProviderStatus $Script:ROLE_PO)"
    Write-Host "   • ขั้นตอนที่ 2 (@arch/@pm) ➔ ค่าย: $($Script:ROLE_ARCH) | โมเดล: $(Get-EffectiveModelLabel $Script:ROLE_ARCH $Script:MODEL_ARCH) | $(Get-ProviderStatus $Script:ROLE_ARCH)"
    Write-Host "   • ขั้นตอนที่ 3 (@dev)      ➔ ค่าย: $($Script:ROLE_DEV) | โมเดล: $(Get-EffectiveModelLabel $Script:ROLE_DEV $Script:MODEL_DEV) | $(Get-ProviderStatus $Script:ROLE_DEV)"
    Write-Host "   • ขั้นตอนที่ 4 (@qa/@sec)  ➔ ค่าย: $($Script:ROLE_QA) | โมเดล: $(Get-EffectiveModelLabel $Script:ROLE_QA $Script:MODEL_QA) | $(Get-ProviderStatus $Script:ROLE_QA)"
    Write-Host "----------------------------------------------------------------------"
    Write-Host "  [1] เริ่มขั้นตอนที่ 1 (@po)        | [2] เริ่มขั้นตอนที่ 2 (@arch/@pm)"
    Write-Host "  [3] เริ่มขั้นตอนที่ 3 (@dev)       | [4] เริ่มขั้นตอนที่ 4 (@qa/@sec)"
    Write-Host "  [c] ตั้งค่าค่าย AI & เลือกโมเดล     | [d] ตรวจสอบการเชื่อมต่อ & ติดตั้ง CLI"
    Write-Host "  [n] สร้างใบงานใหม่ (New Task)    | [i] เตรียม .relay/ | [q] ออกจากโปรแกรม"
    Write-Host "======================================================================" -ForegroundColor Cyan
}

if ($SubCommand -eq "status") { Print-Dashboard; exit 0 }
if ($SubCommand -eq "config") { Configure-RolesMenu; exit 0 }
if ($SubCommand -eq "doctor") { Run-DoctorMenu; exit 0 }

while ($true) {
    Print-Dashboard
    $action = Read-Host "👉 เลือกคำสั่ง [1-4, c, d, n, i, q]"
    switch ($action.ToLower()) {
        "c" { Configure-RolesMenu }
        "d" { Run-DoctorMenu }
        "q" { exit 0 }
        "exit" { exit 0 }
    }
}
