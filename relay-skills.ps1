<#
.SYNOPSIS
    RELAY Skill Manager สำหรับ Windows (PowerShell)
.DESCRIPTION
    จัดการ ติดตั้ง อัปเดตเวอร์ชันล่าสุด และเพิ่ม Skills ใหม่เข้าคลังกลางของเครื่อง Windows
#>
param(
    [Parameter(Position=0)]
    [ValidateSet("install", "update", "add", "list", "help")]
    [string]$Command = "help",

    [Parameter(Position=1)]
    [string]$RepoUrl = "",

    [Parameter(Position=2)]
    [string]$SkillName = "",

    [Parameter(Position=3)]
    [string]$Description = "[Custom Skill] สกิลเพิ่มเติมโดยผู้ใช้"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestFile = Join-Path $ScriptDir "skills-manifest.txt"

function Show-Help {
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "🧰 RELAY Skill Manager (สำหรับ Windows PowerShell)" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "คำสั่งที่รองรับ:"
    Write-Host "  .\relay-skills.ps1 install                     # ติดตั้งชุด Skills มาตรฐานทั้งหมด + Playwright MCP"
    Write-Host "  .\relay-skills.ps1 update                      # ดึงอัปเดตเวอร์ชันใหม่ล่าสุดจากผู้พัฒนาต้นทางทุกตัว"
    Write-Host "  .\relay-skills.ps1 add <repo_url> [skill_name] # เพิ่มสกิลใหม่เข้าเครื่องและบันทึกลง skills-manifest.txt"
    Write-Host "  .\relay-skills.ps1 list                        # แสดงรายการสกิลทั้งหมดในคลัง"
    Write-Host "==================================================================" -ForegroundColor Cyan
}

function Sync-ManifestSkills([string]$ModeLabel) {
    Write-Host "🚀 [RELAY Skills] กำลัง$ModeLabelชุด Skills จาก skills-manifest.txt..." -ForegroundColor Green

    $lines = Get-Content $ManifestFile -Encoding UTF8
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }
        $parts = $trimmed -split "\|"
        $repo = $parts[0]
        $skill = if ($parts.Count -ge 2) { $parts[1] } else { "" }
        $desc = if ($parts.Count -ge 3) { $parts[2] } else { "Skill" }

        Write-Host "------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "📦 $desc : $repo $skill" -ForegroundColor Yellow
        if (-not [string]::IsNullOrWhiteSpace($skill)) {
            npx -y skills add $repo --skill $skill -g
        } else {
            npx -y skills add $repo -g
        }
    }

    $localSkills = @(
        @{ Name = "playwright-qa"; File = "templates\playwright-qa-SKILL.md" },
        @{ Name = "flutter-best-practices"; File = "templates\flutter-best-practices-SKILL.md" },
        @{ Name = "lucide-icons"; File = "templates\lucide-icons-SKILL.md" },
        @{ Name = "simple-icons"; File = "templates\simple-icons-SKILL.md" }
    )
    foreach ($ls in $localSkills) {
        $skillDir = Join-Path $HOME ".agents\skills\$($ls.Name)"
        New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
        $srcFile = Join-Path $ScriptDir $ls.File
        if (Test-Path $srcFile) {
            Copy-Item -Force $srcFile (Join-Path $skillDir "SKILL.md")
        }
    }

    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Host "🔌 ผูก Playwright MCP เข้ากับ Claude Code..." -ForegroundColor Cyan
        try { claude mcp add -s user playwright cmd /c npx `@playwright/mcp`@latest } catch {}
    }
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        Write-Host "🔌 ผูก Playwright MCP เข้ากับ Codex CLI..." -ForegroundColor Cyan
        try { codex mcp add playwright -- cmd /c npx `@playwright/mcp`@latest } catch {}
    }

    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "✅ [RELAY Skills] $ModeLabelเสร็จสมบูรณ์! ทุกสกิลเป็นเวอร์ชันล่าสุดแล้ว" -ForegroundColor Green
}

switch ($Command) {
    "install" { Sync-ManifestSkills "ติดตั้ง" }
    "update"  { Sync-ManifestSkills "อัปเดตเวอร์ชันล่าสุดของ" }
    "add" {
        if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
            Write-Host "❌ กรุณาระบุลิงก์ GitHub Repo เช่น: .\relay-skills.ps1 add https://github.com/owner/repo [ชื่อสกิล]" -ForegroundColor Red
            exit 1
        }
        Write-Host "➕ กำลังติดตั้งสกิลใหม่จาก: $RepoUrl $SkillName..." -ForegroundColor Green
        if (-not [string]::IsNullOrWhiteSpace($SkillName)) {
            npx -y skills add $RepoUrl --skill $SkillName -g
        } else {
            npx -y skills add $RepoUrl -g
        }
        $entry = "$RepoUrl|$SkillName|$Description"
        $existing = Get-Content $ManifestFile -Encoding UTF8
        if ($existing -notcontains $entry) {
            Add-Content -Path $ManifestFile -Value $entry -Encoding UTF8
            Write-Host "📝 บันทึกลง skills-manifest.txt เรียบร้อย (อัปเดตอัตโนมัติเมื่อรัน .\relay-skills.ps1 update)" -ForegroundColor Cyan
        }
        Write-Host "✅ เพิ่มสกิลใหม่สำเร็จ!" -ForegroundColor Green
    }
    "list" {
        Write-Host "📋 รายการ Skills ใน skills-manifest.txt:" -ForegroundColor Cyan
        Get-Content $ManifestFile -Encoding UTF8 | Where-Object { $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") } | ForEach-Object {
            $p = $_ -split "\|"
            $sName = if ($p[1]) { $p[1] } else { "ทั้ง Repo" }
            Write-Host "  • $sName ($($p[2])) -> $($p[0])"
        }
    }
    default { Show-Help }
}
