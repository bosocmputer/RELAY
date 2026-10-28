<#
.SYNOPSIS
    RELAY Central Terminal Hub สำหรับ Windows (PowerShell)
.DESCRIPTION
    ศูนย์กลางการควบคุมและสั่งงานตัวแทน AI ทั้ง 4 ขั้นตอนผ่านหน้าต่าง PowerShell เดียว
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

$Script:ROLE_PO = "gemini"
$Script:ROLE_ARCH = "claude"
$Script:ROLE_DEV = "claude"
$Script:ROLE_QA = "codex"
$Script:CONFIG_SOURCE = "ค่าเริ่มต้นส่วนกลาง (~/.agents/relay-roles.conf)"
$Script:ACTIVE_TASK = ""

function Load-RoleConfig {
    $Script:ROLE_PO = "gemini"
    $Script:ROLE_ARCH = "claude"
    $Script:ROLE_DEV = "claude"
    $Script:ROLE_QA = "codex"
    $Script:CONFIG_SOURCE = "ค่าเริ่มต้นส่วนกลาง ($GlobalRolesConf)"

    foreach ($confFile in @($GlobalRolesConf, $ProjectRolesConf)) {
        if (Test-Path $confFile) {
            if ($confFile -eq $ProjectRolesConf) {
                $Script:CONFIG_SOURCE = "เฉพาะโครงการนี้ (.relay/roles.conf)"
            }
            Get-Content $confFile -Encoding UTF8 | ForEach-Object {
                $line = $_.Trim()
                if ($line -match '^ROLE_PO="([^"]+)"')   { $Script:ROLE_PO = $Matches[1] }
                if ($line -match '^ROLE_ARCH="([^"]+)"') { $Script:ROLE_ARCH = $Matches[1] }
                if ($line -match '^ROLE_DEV="([^"]+)"')  { $Script:ROLE_DEV = $Matches[1] }
                if ($line -match '^ROLE_QA="([^"]+)"')   { $Script:ROLE_QA = $Matches[1] }
            }
        }
    }
}

function Save-RoleConfig([string]$TargetFile) {
    $parent = Split-Path -Parent $TargetFile
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $content = @"
# RELAY Role-to-Provider Configuration (claude | codex | gemini)
ROLE_PO="$($Script:ROLE_PO)"
ROLE_ARCH="$($Script:ROLE_ARCH)"
ROLE_DEV="$($Script:ROLE_DEV)"
ROLE_QA="$($Script:ROLE_QA)"
"@
    Set-Content -Path $TargetFile -Value $content -Encoding UTF8
}

function Get-ActiveTask {
    $tasksPath = Join-Path $RelayDir "tasks"
    if (-not (Test-Path $tasksPath)) {
        $Script:ACTIVE_TASK = ""
        return
    }
    $dirs = Get-ChildItem -Path $tasksPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name
    if ($dirs -and $dirs.Count -gt 0) {
        $Script:ACTIVE_TASK = $dirs[-1].Name
    } else {
        $Script:ACTIVE_TASK = ""
    }
}

function Select-ProviderForRole([string]$RoleLabel, [string]$CurrentVal) {
    Write-Host ""
    Write-Host "เลือกค่าย AI สำหรับ $RoleLabel (ค่าปัจจุบัน: $CurrentVal):" -ForegroundColor Cyan
    Write-Host "  [1] claude  (Anthropic Claude Code CLI)"
    Write-Host "  [2] codex   (OpenAI Codex CLI)"
    Write-Host "  [3] gemini  (Google Gemini CLI)"
    $choice = Read-Host "เลือกหมายเลข (1-3 หรือกด Enter เพื่อคงค่าเดิม $CurrentVal)"
    switch ($choice) {
        "1" { return "claude" }
        "2" { return "codex" }
        "3" { return "gemini" }
        default { return $CurrentVal }
    }
}

function Configure-RolesMenu {
    Load-RoleConfig
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "⚙️  ตั้งค่าจับคู่ตำแหน่งตัวแทน AI กับค่ายผู้ให้บริการ (Role-to-Provider Mapping)" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  [1] ระดับส่วนกลางของเครื่อง ($GlobalRolesConf) — มีผลกับทุกโครงการ"
    Write-Host "  [2] เฉพาะโครงการนี้ ($ProjectRolesConf) — มีผลเฉพาะโฟลเดอร์ $ProjectName"
    $scope = Read-Host "เลือกระดับการบันทึก [1 หรือ 2, ค่าเริ่มต้น=1]"

    $Script:ROLE_PO   = Select-ProviderForRole "ขั้นตอนที่ 1 (@po - วิเคราะห์ความต้องการ)" $Script:ROLE_PO
    $Script:ROLE_ARCH = Select-ProviderForRole "ขั้นตอนที่ 2 (@arch/@pm - ออกแบบและวางแผน)" $Script:ROLE_ARCH
    $Script:ROLE_DEV  = Select-ProviderForRole "ขั้นตอนที่ 3 (@dev - พัฒนาโค้ดใน Git Worktree)" $Script:ROLE_DEV
    $Script:ROLE_QA   = Select-ProviderForRole "ขั้นตอนที่ 4 (@qa/@sec - ตรวจสอบคุณภาพและความปลอดภัย)" $Script:ROLE_QA

    if ($scope -eq "2") {
        Save-RoleConfig $ProjectRolesConf
        Write-Host "✅ บันทึกการตั้งค่าเฉพาะโครงการลงใน $ProjectRolesConf เรียบร้อยแล้ว!" -ForegroundColor Green
    } else {
        Save-RoleConfig $GlobalRolesConf
        Write-Host "✅ บันทึกการตั้งค่าส่วนกลางลงใน $GlobalRolesConf เรียบร้อยแล้ว!" -ForegroundColor Green
    }
}

function Launch-ProviderCli([string]$Provider, [string]$RoleName, [string]$WorkDir, [string]$InitialPrompt) {
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "🚀 กำลังเข้าสู่ $RoleName ผ่านค่าย [$Provider] ในโฟลเดอร์: $WorkDir" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "📋 คำสั่งเริ่มต้นของขั้นตอนนี้ (คัดลอกลง Clipboard ให้แล้วอัตโนมัติ):" -ForegroundColor Yellow
    Write-Host $InitialPrompt
    Write-Host "----------------------------------------------------------------------"
    Write-Host "💡 เมื่อสนทนาและสร้างเอกสารเสร็จแล้ว ให้พิมพ์ /exit เพื่อกลับสู่หน้าจอหลักของ RELAY" -ForegroundColor Cyan

    try { Set-Clipboard -Value $InitialPrompt } catch {}

    if (-not (Get-Command $Provider -ErrorAction SilentlyContinue)) {
        Write-Host "⚠️ ไม่พบโปรแกรม '$Provider' ในเครื่องของคุณ! กรุณาติดตั้งด้วย npm install -g หรือกด [c] เพื่อเปลี่ยนค่าย AI" -ForegroundColor Red
        Read-Host "กด Enter เพื่อกลับสู่เมนูหลัก"
        return
    }

    Push-Location $WorkDir
    try {
        if ($Provider -eq "claude") {
            & claude $InitialPrompt
        } elseif ($Provider -eq "codex") {
            & codex $InitialPrompt
        } elseif ($Provider -eq "gemini") {
            & gemini -i $InitialPrompt
        } else {
            & $Provider
        }
    } catch {}
    Pop-Location
}

function Create-NewTask {
    $tasksDir = Join-Path $RelayDir "tasks"
    $archiveDir = Join-Path $RelayDir "archive"
    New-Item -ItemType Directory -Force -Path $tasksDir, $archiveDir | Out-Null
    $slug = Read-Host "📝 ตั้งชื่อย่อของใบงานใหม่ (ภาษาอังกฤษ เช่น user-auth หรือ payment-api)"
    if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "feature" }
    $slug = ($slug.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
    $today = Get-Date -Format "yyyyMMdd"
    $Script:ACTIVE_TASK = "$today-$slug"
    New-Item -ItemType Directory -Force -Path (Join-Path $tasksDir "$($Script:ACTIVE_TASK)\screenshots") | Out-Null
    Write-Host "✅ สร้างใบงานใหม่เรียบร้อย: .relay/tasks/$($Script:ACTIVE_TASK)" -ForegroundColor Green
}

function Ensure-OrCreateTask {
    Get-ActiveTask
    if ([string]::IsNullOrWhiteSpace($Script:ACTIVE_TASK)) {
        Create-NewTask
    }
}

function Run-Phase1Po {
    Ensure-OrCreateTask
    $goal = Read-Host "💡 อธิบายฟีเจอร์หรือความต้องการคร่าวๆ ที่ต้องการให้ @po วิเคราะห์"
    if ([string]::IsNullOrWhiteSpace($goal)) { $goal = "ตามที่ฉันกำลังจะอธิบายต่อไปนี้" }
    $prompt = "@po ฉันต้องการพัฒนาฟีเจอร์สำหรับใบงาน .relay/tasks/$($Script:ACTIVE_TASK) เกี่ยวกับ: $goal กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md (ถ้ามี) แล้วซักถามความต้องการจากฉันทีละประเด็นจนชัดเจน เมื่อฉันยืนยันแล้วให้สรุปเป็นเอกสารกำหนดความต้องการลงในไฟล์ .relay/tasks/$($Script:ACTIVE_TASK)/SPEC.md"
    Launch-ProviderCli $Script:ROLE_PO "ขั้นตอนที่ 1: @po (Product Owner)" $ProjectDir $prompt
}

function Run-Phase2Arch {
    Ensure-OrCreateTask
    $prompt = "@arch @pm กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md ร่วมกับไฟล์ความต้องการ .relay/tasks/$($Script:ACTIVE_TASK)/SPEC.md แล้วออกแบบโครงสร้างทางเทคนิคลงในไฟล์ .relay/tasks/$($Script:ACTIVE_TASK)/ARCH.md และจัดทำแผนการดำเนินงานย่อยเป็นข้อๆ ลงในไฟล์ .relay/tasks/$($Script:ACTIVE_TASK)/PLAN.md"
    Launch-ProviderCli $Script:ROLE_ARCH "ขั้นตอนที่ 2: @arch & @pm (Architect & Planner)" $ProjectDir $prompt
}

function Run-Phase3Dev {
    Ensure-OrCreateTask
    $prompt = "@dev กรุณาอ่านเอกสาร .relay/tasks/$($Script:ACTIVE_TASK)/SPEC.md, ARCH.md และ PLAN.md แล้วดำเนินการพัฒนาโค้ดควบคู่กับชุดทดสอบ (Unit Tests) ตามแผนที่กำหนดไว้"
    Launch-ProviderCli $Script:ROLE_DEV "ขั้นตอนที่ 3: @dev (Full-Stack Developer)" $ProjectDir $prompt
}

function Run-Phase4Qa {
    Ensure-OrCreateTask
    $prompt = "@qa @sec กรุณาตรวจสอบผลงานตามเกณฑ์ Acceptance Criteria ในไฟล์ .relay/tasks/$($Script:ACTIVE_TASK)/SPEC.md โดยรันชุดทดสอบจริงของโครงการ ตรวจสอบความปลอดภัยของ git diff ทดสอบ UI ด้วย Playwright MCP และสรุปผลลงใน .relay/tasks/$($Script:ACTIVE_TASK)/QA_REPORT.md พร้อมอัปเดต .relay/PROJECT_STATE.md"
    Launch-ProviderCli $Script:ROLE_QA "ขั้นตอนที่ 4: @qa & @sec (Quality Assurance & Security Auditor)" $ProjectDir $prompt
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
    if ($Script:ACTIVE_TASK) {
        Write-Host "📋 ใบงานปัจจุบัน   : $($Script:ACTIVE_TASK)" -ForegroundColor Yellow
    } else {
        Write-Host "📋 ใบงานปัจจุบัน   : (ยังไม่มีใบงาน — กด [1] หรือ [n] เพื่อเริ่มใบงานใหม่)"
    }
    Write-Host "----------------------------------------------------------------------"
    Write-Host "🤖 การจับคู่ตำแหน่งกับค่าย AI ($($Script:CONFIG_SOURCE)):"
    Write-Host "   • ขั้นตอนที่ 1 (@po)        ➔ ค่าย: $($Script:ROLE_PO)"
    Write-Host "   • ขั้นตอนที่ 2 (@arch/@pm)  ➔ ค่าย: $($Script:ROLE_ARCH)"
    Write-Host "   • ขั้นตอนที่ 3 (@dev)       ➔ ค่าย: $($Script:ROLE_DEV)"
    Write-Host "   • ขั้นตอนที่ 4 (@qa/@sec)   ➔ ค่าย: $($Script:ROLE_QA)"
    Write-Host "----------------------------------------------------------------------"
    Write-Host "  [1] เริ่มขั้นตอนที่ 1 (@po)        | [2] เริ่มขั้นตอนที่ 2 (@arch/@pm)"
    Write-Host "  [3] เริ่มขั้นตอนที่ 3 (@dev)       | [4] เริ่มขั้นตอนที่ 4 (@qa/@sec)"
    Write-Host "  [n] สร้างใบงานใหม่ (New Task)    | [i] เตรียม .relay/ (โครงการใหม่ / โครงการเดิม)"
    Write-Host "  [c] ตั้งค่าเปลี่ยนค่าย AI ประจำตำแหน่ง | [q] ออกจากโปรแกรม"
    Write-Host "======================================================================" -ForegroundColor Cyan
}

if ($SubCommand -eq "status") { Print-Dashboard; exit 0 }
if ($SubCommand -eq "config") { Configure-RolesMenu; exit 0 }
if ($SubCommand -eq "init")   { & (Join-Path $GlobalDir "bin\relay-init.ps1") $ProjectDir $Arg2; exit 0 }

while ($true) {
    Print-Dashboard
    $action = Read-Host "👉 เลือกคำสั่ง [1-4, n, i, c, q]"
    switch ($action.ToLower()) {
        "1" { Run-Phase1Po }
        "2" { Run-Phase2Arch }
        "3" { Run-Phase3Dev }
        "4" { Run-Phase4Qa }
        "n" { Create-NewTask }
        "i" { & (Join-Path $GlobalDir "bin\relay-init.ps1") $ProjectDir "new" }
        "c" { Configure-RolesMenu }
        "q" { exit 0 }
        "exit" { exit 0 }
    }
}
