<#
.SYNOPSIS
    สคริปต์ติดตั้งการตั้งค่าส่วนกลางของระบบ RELAY สำหรับเครื่อง Windows (PowerShell)
.DESCRIPTION
    สร้างโฟลเดอร์ %USERPROFILE%\.agents, คัดลอกกฎการทำงานส่วนกลางไปยัง Claude / Codex / Gemini,
    และเปิดใช้งาน Global Git Pre-commit Hook เพื่อป้องกันการบันทึกไฟล์ความลับในทุกโครงการ
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "⚙️ [RELAY Windows Setup] กำลังติดตั้งการตั้งค่าส่วนกลาง ($HOME\.agents) สำหรับ Windows..." -ForegroundColor Green

# 1. สร้างโฟลเดอร์ส่วนกลางสำหรับทุกค่าย CLI
$dirs = @(
    (Join-Path $HOME ".agents\skills\playwright-qa"),
    (Join-Path $HOME ".agents\hooks"),
    (Join-Path $HOME ".agents\bin"),
    (Join-Path $HOME ".claude"),
    (Join-Path $HOME ".codex"),
    (Join-Path $HOME ".gemini")
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

# 2. คัดลอกไฟล์กฎการทำงานส่วนกลาง ทักษะตรวจสอบหน้าเว็บ และสคริปต์เริ่มต้นโครงการ
$globalAgentsSrc = Join-Path $ScriptDir "templates\GLOBAL_AGENTS.md"
$globalAgentsDst = Join-Path $HOME ".agents\GLOBAL_AGENTS.md"
Copy-Item -Force $globalAgentsSrc $globalAgentsDst
Copy-Item -Force (Join-Path $ScriptDir "templates\playwright-qa-SKILL.md") (Join-Path $HOME ".agents\skills\playwright-qa\SKILL.md")
Copy-Item -Force (Join-Path $ScriptDir "templates\pre-commit") (Join-Path $HOME ".agents\hooks\pre-commit")
Copy-Item -Force (Join-Path $ScriptDir "relay-init.ps1") (Join-Path $HOME ".agents\bin\relay-init.ps1")

# 3. คัดลอกไฟล์กฎการทำงานส่วนกลางไปยังทั้ง 3 ค่าย (Claude, Codex, Gemini)
Copy-Item -Force $globalAgentsDst (Join-Path $HOME ".claude\CLAUDE.md")
Copy-Item -Force $globalAgentsDst (Join-Path $HOME ".codex\AGENTS.md")
Copy-Item -Force $globalAgentsDst (Join-Path $HOME ".gemini\GEMINI.md")

# 4. ตั้งค่า Global Git Pre-commit Hook เพื่อตรวจสอบความปลอดภัยก่อน Commit ในทุกโครงการ
$hooksPath = (Join-Path $HOME ".agents\hooks") -replace "\\", "/"
git config --global core.hooksPath $hooksPath

Write-Host "✅ [RELAY Windows Setup] ติดตั้งการตั้งค่าส่วนกลางเสร็จสมบูรณ์!" -ForegroundColor Green
Write-Host "   • กฎการทำงานส่วนกลาง: $HOME\.agents\GLOBAL_AGENTS.md (คัดลอกไปยัง .claude, .codex, .gemini)"
Write-Host "   • ทักษะการตรวจสอบ UI: $HOME\.agents\skills\playwright-qa\SKILL.md"
Write-Host "   • สคริปต์สร้างโครงสร้างโครงการ: $HOME\.agents\bin\relay-init.ps1"
Write-Host "   • กลไกป้องกันไฟล์ความลับ: $HOME\.agents\hooks\pre-commit (เปิดใช้งานระดับ Global)"
Write-Host ""
Write-Host "👉 ขั้นตอนต่อไป: รันคำสั่ง .\relay-skills.ps1 install เพื่อติดตั้งชุดทักษะมาตรฐานจาก GitHub" -ForegroundColor Cyan
