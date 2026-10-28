<#
.SYNOPSIS
    สคริปต์สร้างโครงสร้าง .relay/ สำหรับโครงการใหม่ (Greenfield) หรือโครงการเดิม (Brownfield) บน Windows
#>
param(
    [Parameter(Position=0)]
    [string]$TargetDir = ".",

    [Parameter(Position=1)]
    [ValidateSet("new", "existing")]
    [string]$Mode = "new"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
$TargetAbs = (Resolve-Path $TargetDir).Path
$ProjectName = Split-Path -Leaf $TargetAbs
$TodayIso = Get-Date -Format "yyyy-MM-dd"
$TodayCompact = Get-Date -Format "yyyyMMdd"

Write-Host "⚙️ [RELAY Init] กำลังเตรียมโครงสร้างระบบ RELAY สำหรับโครงการ: $ProjectName ($TargetAbs)" -ForegroundColor Cyan

# 1. สร้างโครงสร้างโฟลเดอร์ .relay/
$TasksDir = Join-Path $TargetAbs ".relay\tasks"
$ArchiveDir = Join-Path $TargetAbs ".relay\archive"
New-Item -ItemType Directory -Force -Path $TasksDir | Out-Null
New-Item -ItemType Directory -Force -Path $ArchiveDir | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $ArchiveDir ".gitkeep") | Out-Null

# 2. สร้างไฟล์ PROJECT_STATE.md ตั้งต้น (หากยังไม่มี)
$StateFile = Join-Path $TargetAbs ".relay\PROJECT_STATE.md"
if (-not (Test-Path $StateFile)) {
    $StateContent = @"
# สถานะปัจจุบันของโครงการ (PROJECT_STATE.md)
- **ชื่อโครงการ:** $ProjectName
- **วันที่อัปเดตล่าสุด:** $TodayIso
- **คำแนะนำ:** เอกสารนี้ใช้เก็บสรุปสถาปัตยกรรม โครงสร้างฐานข้อมูล และรายการ API ล่าสุดของโครงการ (ความยาวไม่เกิน 2 หน้า) เพื่อให้ตัวแทน AI เข้าใจบริบทของระบบโดยไม่ต้องอ่านใบงานเก่าทั้งหมด

## 1. ภาพรวมและเทคโนโลยีที่ใช้ (Tech Stack & Overview)
- (ระบุภาษา เฟรมเวิร์ก และฐานข้อมูลที่ใช้ หรือสั่งให้ @arch สแกนโค้ดเพื่อสรุปข้อมูลลงในส่วนนี้)

## 2. โครงสร้างโมดูลและไฟล์สำคัญ (Core Modules & Architecture)
- (ระบุโฟลเดอร์หลักและหน้าที่ของแต่ละส่วน)

## 3. คำสั่งสำคัญสำหรับการตรวจสอบและทดสอบ (Build & Test Commands)
- คำสั่งรันทดสอบ (Unit Tests): ``npm test`` หรือ ``pnpm test``
- คำสั่งตรวจสอบโครงสร้างโค้ด (Build / Lint): ``npm run build``
"@
    Set-Content -Path $StateFile -Value $StateContent -Encoding UTF8
    Write-Host "✅ สร้างไฟล์ตั้งต้น: $StateFile" -ForegroundColor Green
} else {
    Write-Host "ℹ️ พบไฟล์ $StateFile อยู่แล้ว (ข้ามการเขียนทับ)" -ForegroundColor Yellow
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "✅ เตรียมโครงสร้าง .relay/ เสร็จสมบูรณ์!" -ForegroundColor Green
Write-Host "📂 ตำแหน่งโฟลเดอร์เอกสาร: $TargetAbs\.relay\"
Write-Host "🟣 วิธีเปิดในโปรแกรม Obsidian:"
Write-Host "   เปิดแอป Obsidian -> คลิก 'Open folder as vault' -> เลือกโฟลเดอร์ '$TargetAbs\.relay'"
Write-Host "==================================================================" -ForegroundColor Cyan

if ($Mode -eq "existing") {
    Write-Host "📌 ขั้นตอนต่อไปสำหรับ [กรณีที่ 2: โครงการเดิมที่มีโค้ดอยู่แล้ว (Brownfield Project)]:" -ForegroundColor Yellow
    Write-Host "   1. เปิด PowerShell ในโฟลเดอร์โครงการ: cd `"$TargetAbs`""
    Write-Host "   2. เปิดใช้งาน CLI (claude หรือ gemini) แล้วคัดลอกคำสั่งด้านล่างไปสั่งงาน:"
    Write-Host ""
    Write-Host "   `"@arch ช่วยสแกนโครงสร้างโปรเจกต์เดิมทั้งหมด (Tech Stack, โครงสร้างโฟลเดอร์, Database Schema, API และคำสั่งรันเทสต์) แล้วสรุปเขียนทับลงในไฟล์ .relay/PROJECT_STATE.md ให้กระชับไม่เกิน 2 หน้า โดยยังไม่ต้องแก้ไขโค้ดใดๆ`"" -ForegroundColor Green
} else {
    Write-Host "📌 ขั้นตอนต่อไปสำหรับ [กรณีที่ 1: เริ่มต้นโครงการใหม่ (Greenfield Project)]:" -ForegroundColor Yellow
    Write-Host "   1. เปิด PowerShell ในโฟลเดอร์โครงการ: cd `"$TargetAbs`" (และรัน git init -b main หากยังไม่ได้เริ่ม Git)"
    Write-Host "   2. เปิดใช้งาน CLI (gemini หรือ claude) แล้วคัดลอกคำสั่งด้านล่างไปสั่งงาน:"
    Write-Host ""
    Write-Host "   `"@po ฉันกำลังจะสร้างโปรเจกต์ใหม่เกี่ยวกับ [ระบุรายละเอียดโปรเจกต์] ช่วยซักถามความต้องการทีละข้อจนชัดเจน แล้วสรุปเป็นไฟล์ .relay/tasks/$TodayCompact-initial-project/SPEC.md`"" -ForegroundColor Green
}
Write-Host "==================================================================" -ForegroundColor Cyan
