<#
.SYNOPSIS
    สคริปต์ตั้งค่าสมองส่วนกลาง RELAY สำหรับเครื่อง Windows (PowerShell)
.DESCRIPTION
    สร้างโฟลเดอร์ %USERPROFILE%\.agents, คัดลอกกฎกลางไปยัง Claude / Codex / Gemini,
    และเปิดใช้งาน Global Git Pre-commit Hook ป้องกันไฟล์ .env หลุดในทุกโปรเจกต์
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "🏃‍♂️ [RELAY Windows Setup] กำลังตั้งค่าสมองส่วนกลาง ($HOME\.agents) บนเครื่อง Windows..." -ForegroundColor Green

# 1. สร้างโฟลเดอร์ส่วนกลางสำหรับทุกค่าย CLI
$dirs = @(
    (Join-Path $HOME ".agents\skills\playwright-qa"),
    (Join-Path $HOME ".agents\hooks"),
    (Join-Path $HOME ".claude"),
    (Join-Path $HOME ".codex"),
    (Join-Path $HOME ".gemini")
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

# 2. คัดลอกไฟล์กฎกลางและสกิลตรวจหน้าเว็บ
$globalAgentsSrc = Join-Path $ScriptDir "templates\GLOBAL_AGENTS.md"
$globalAgentsDst = Join-Path $HOME ".agents\GLOBAL_AGENTS.md"
Copy-Item -Force $globalAgentsSrc $globalAgentsDst
Copy-Item -Force (Join-Path $ScriptDir "templates\playwright-qa-SKILL.md") (Join-Path $HOME ".agents\skills\playwright-qa\SKILL.md")
Copy-Item -Force (Join-Path $ScriptDir "templates\pre-commit") (Join-Path $HOME ".agents\hooks\pre-commit")

# 3. เชื่อมไฟล์กฎกลางไปยังทั้ง 3 ค่าย (ใช้ Copy-Item บน Windows เพื่อไม่ต้องเปิดสิทธิ์ Administrator สำหรับ Symlink)
Copy-Item -Force $globalAgentsDst (Join-Path $HOME ".claude\CLAUDE.md")
Copy-Item -Force $globalAgentsDst (Join-Path $HOME ".codex\AGENTS.md")
Copy-Item -Force $globalAgentsDst (Join-Path $HOME ".gemini\GEMINI.md")

# 4. ตั้งค่า Global Git Pre-commit Hook เพื่อปกป้องทุกโปรเจกต์ในเครื่อง
$hooksPath = (Join-Path $HOME ".agents\hooks") -replace "\\", "/"
git config --global core.hooksPath $hooksPath

Write-Host "✅ [RELAY Windows Setup] ตั้งค่าส่วนกลางเสร็จสมบูรณ์!" -ForegroundColor Green
Write-Host "   • กฎกลาง: $HOME\.agents\GLOBAL_AGENTS.md (คัดลอกไปยัง .claude, .codex, .gemini แล้ว)"
Write-Host "   • สกิล QA: $HOME\.agents\skills\playwright-qa\SKILL.md"
Write-Host "   • เกราะป้องกัน .env: $HOME\.agents\hooks\pre-commit (เปิดใช้ระดับ Global ทุกโปรเจกต์แล้ว)"
Write-Host ""
Write-Host "👉 ขั้นต่อไป: รันคำสั่ง .\relay-skills.ps1 install เพื่อดึงชุด Skills จาก GitHub เข้าคลังกลาง" -ForegroundColor Cyan
