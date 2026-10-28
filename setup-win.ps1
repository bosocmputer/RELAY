<#
.SYNOPSIS
    สคริปต์ติดตั้งการตั้งค่าส่วนกลางของระบบ RELAY สำหรับเครื่อง Windows (PowerShell)
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "⚙️ [RELAY Windows Setup] กำลังติดตั้งการตั้งค่าส่วนกลาง ($HOME\.agents) สำหรับ Windows..." -ForegroundColor Green

# 1. สร้างโฟลเดอร์ส่วนกลางสำหรับทุกค่าย CLI
$BinDir = Join-Path $HOME ".agents\bin"
$dirs = @(
    (Join-Path $HOME ".agents\skills\playwright-qa"),
    (Join-Path $HOME ".agents\hooks"),
    $BinDir,
    (Join-Path $HOME ".claude"),
    (Join-Path $HOME ".codex"),
    (Join-Path $HOME ".gemini")
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

# 2. คัดลอกไฟล์กฎการทำงานส่วนกลาง สคริปต์เริ่มต้นโครงการ และสคริปต์หน้าจอควบคุมกลาง (relay)
$globalAgentsSrc = Join-Path $ScriptDir "templates\GLOBAL_AGENTS.md"
$globalAgentsDst = Join-Path $HOME ".agents\GLOBAL_AGENTS.md"
Copy-Item -Force $globalAgentsSrc $globalAgentsDst
Copy-Item -Force (Join-Path $ScriptDir "templates\playwright-qa-SKILL.md") (Join-Path $HOME ".agents\skills\playwright-qa\SKILL.md")
Copy-Item -Force (Join-Path $ScriptDir "templates\pre-commit") (Join-Path $HOME ".agents\hooks\pre-commit")
Copy-Item -Force (Join-Path $ScriptDir "relay-init.ps1") (Join-Path $BinDir "relay-init.ps1")
Copy-Item -Force (Join-Path $ScriptDir "relay.ps1") (Join-Path $BinDir "relay.ps1")

$rolesConfDst = Join-Path $HOME ".agents\relay-roles.conf"
if (-not (Test-Path $rolesConfDst)) {
    Copy-Item -Force (Join-Path $ScriptDir "templates\relay-roles.conf") $rolesConfDst
}

# 3. เพิ่ม %USERPROFILE%\.agents\bin เข้าสู่ User PATH ของ Windows เพื่อให้พิมพ์คำสั่ง relay ได้จากทุกโฟลเดอร์
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$BinDir;$userPath", "User")
    $env:Path = "$BinDir;$env:Path"
}

# 4. คัดลอกไฟล์กฎการทำงานส่วนกลางไปยังทั้ง 3 ค่าย (Claude, Codex, Gemini)
Copy-Item -Force $globalAgentsDst (Join-Path $HOME ".claude\CLAUDE.md")
Copy-Item -Force $globalAgentsDst (Join-Path $HOME ".codex\AGENTS.md")
Copy-Item -Force $globalAgentsDst (Join-Path $HOME ".gemini\GEMINI.md")

# 5. ตั้งค่า Global Git Pre-commit Hook เพื่อตรวจสอบความปลอดภัยก่อน Commit ในทุกโครงการ
$hooksPath = (Join-Path $HOME ".agents\hooks") -replace "\\", "/"
git config --global core.hooksPath $hooksPath

Write-Host "✅ [RELAY Windows Setup] ติดตั้งการตั้งค่าส่วนกลางเสร็จสมบูรณ์!" -ForegroundColor Green
Write-Host "   • คำสั่งหน้าจอควบคุมกลาง: พิมพ์ 'relay' ใน PowerShell ได้จากทุกโฟลเดอร์"
Write-Host "   • ไฟล์จับคู่ตำแหน่งกับค่าย AI: $rolesConfDst (ตั้งค่าผ่านคำสั่ง 'relay config')"
Write-Host "   • กฎการทำงานส่วนกลาง: $globalAgentsDst"
Write-Host ""
Write-Host "👉 ขั้นตอนต่อไป:" -ForegroundColor Cyan
Write-Host "   1. ตั้งค่าว่าแต่ละตำแหน่ง (@po, @arch, @dev, @qa) จะใช้ AI ค่ายไหน: relay config"
Write-Host "   2. เปิดหน้าจอควบคุมกลางในโปรเจกต์ใดก็ได้: relay"
