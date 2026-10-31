<#
.SYNOPSIS
    RELAY Skill Manager สำหรับ Windows (PowerShell)
.DESCRIPTION
    จัดการ ติดตั้ง อัปเดตเวอร์ชันล่าสุด และเพิ่ม Skills ใหม่เข้าคลังกลางของเครื่อง Windows
#>
param(
    [Parameter(Position=0)]
    [ValidateSet("install", "update", "add", "list", "link-claude", "help")]
    [string]$Command = "help",

    [Parameter(Position=1)]
    [string]$RepoUrl = "",

    [Parameter(Position=2)]
    [string]$SkillName = "",

    [Parameter(Position=3)]
    [string]$Description = "[Custom Skill] สกิลเพิ่มเติมโดยผู้ใช้"
)

# ล็อกเวอร์ชันแพ็กเกจที่ npx ดาวน์โหลดมารัน (ไม่ใช้ latest แบบไม่ระบุ) • ปรับได้ผ่านตัวแปรสภาพแวดล้อม (เหมือน relay-skills.sh)
$SkillsCliPkg = if ($env:RELAY_SKILLS_CLI_PKG) { $env:RELAY_SKILLS_CLI_PKG } else { "skills@1.7.4" }
$PlaywrightMcpPkg = if ($env:RELAY_PLAYWRIGHT_MCP_PKG) { $env:RELAY_PLAYWRIGHT_MCP_PKG } else { "@playwright/mcp@0.0.83" }

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

# คัดลอก skill จาก ~/.agents/skills เข้า ~/.claude/skills เฉพาะเมื่อเลือกเปิดเอง (เหมือน sync_claude_skill_links ใน relay-skills.sh)
# คำอธิบายของทุก skill ใน ~/.claude/skills ถูกโหลดเข้าทุก session ของ Claude Code • คัดลอกทั้งโฟลเดอร์ (scripts/, references/) แทน symlink
# $env:RELAY_LINK_CLAUDE_SKILLS = "all" | "relay-roles playwright-qa" | ว่าง (ค่าเริ่มต้น: ไม่คัดลอก และลบสำเนาเดิมที่ RELAY สร้าง)
# แตะเฉพาะโฟลเดอร์ที่มีไฟล์ .relay-managed หรือสำเนา SKILL.md เดี่ยวที่ตรงกับต้นฉบับ (สำเนาจากเวอร์ชันก่อน) — โฟลเดอร์อื่นของผู้ใช้ไม่ถูกแตะ
function Test-RelayManagedSkillDir([string]$Dir, [string]$AgentsSkills) {
    if (Test-Path (Join-Path $Dir ".relay-managed")) { return $true }
    $items = @(Get-ChildItem -Path $Dir -Force -ErrorAction SilentlyContinue)
    $src = Join-Path (Join-Path $AgentsSkills (Split-Path $Dir -Leaf)) "SKILL.md"
    if ($items.Count -eq 1 -and $items[0].Name -eq "SKILL.md" -and (Test-Path $src)) {
        return (Get-FileHash $items[0].FullName).Hash -eq (Get-FileHash $src).Hash
    }
    return $false
}

function Sync-ClaudeSkillCopies {
    $wanted = ("$env:RELAY_LINK_CLAUDE_SKILLS" -replace ',', ' ').Trim()
    $wantedList = @($wanted -split '\s+' | Where-Object { $_ })
    $agentsSkills = Join-Path $HOME ".agents\skills"
    $claudeSkills = Join-Path $HOME ".claude\skills"
    if (Test-Path $claudeSkills) {
        foreach ($d in (Get-ChildItem -Path $claudeSkills -Directory -ErrorAction SilentlyContinue)) {
            if (-not (Test-RelayManagedSkillDir $d.FullName $agentsSkills)) { continue }
            if ($wanted -ne "all" -and $wantedList -notcontains $d.Name) { Remove-Item -Recurse -Force $d.FullName }
        }
    }
    $copied = @()
    if ($wanted) {
        New-Item -ItemType Directory -Force -Path $claudeSkills | Out-Null
        foreach ($s in (Get-ChildItem -Path $agentsSkills -Directory -ErrorAction SilentlyContinue)) {
            if ($s.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if (-not (Test-Path (Join-Path $s.FullName "SKILL.md"))) { continue }
            if ($wanted -ne "all" -and $wantedList -notcontains $s.Name) { continue }
            $dst = Join-Path $claudeSkills $s.Name
            if (Test-Path $dst) {
                if (-not (Test-RelayManagedSkillDir $dst $agentsSkills)) { continue }
                Remove-Item -Recurse -Force $dst
            }
            Copy-Item -Recurse -Force $s.FullName $dst
            New-Item -ItemType File -Force -Path (Join-Path $dst ".relay-managed") | Out-Null
            $copied += $s.Name
        }
    }
    $label = if ($copied.Count) { $copied -join " " } else { "ไม่มี (เปิดได้ด้วย `$env:RELAY_LINK_CLAUDE_SKILLS = 'all' หรือรายชื่อ skill)" }
    Write-Host "🔗 [RELAY Skills] คัดลอกเข้า $claudeSkills : $label"
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
            npx -y $SkillsCliPkg add $repo --skill $skill -g
        } else {
            npx -y $SkillsCliPkg add $repo -g
        }
    }

    $localSkills = @(
        @{ Name = "relay-roles"; File = "templates\relay-roles-SKILL.md" },
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
        try { claude mcp add -s user playwright cmd /c npx $PlaywrightMcpPkg } catch {}
    }
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        Write-Host "🔌 ผูก Playwright MCP เข้ากับ Codex CLI..." -ForegroundColor Cyan
        try { codex mcp add playwright -- cmd /c npx $PlaywrightMcpPkg } catch {}
    }

    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "✅ [RELAY Skills] $ModeLabelเสร็จสมบูรณ์! ทุกสกิลเป็นเวอร์ชันล่าสุดแล้ว" -ForegroundColor Green
}

switch ($Command) {
    "install" { Sync-ManifestSkills "ติดตั้ง"; Sync-ClaudeSkillCopies }
    "link-claude" { Sync-ClaudeSkillCopies }
    "update"  { Sync-ManifestSkills "อัปเดตเวอร์ชันล่าสุดของ"; Sync-ClaudeSkillCopies }
    "add" {
        if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
            Write-Host "❌ กรุณาระบุลิงก์ GitHub Repo เช่น: .\relay-skills.ps1 add https://github.com/owner/repo [ชื่อสกิล]" -ForegroundColor Red
            exit 1
        }
        Write-Host "➕ กำลังติดตั้งสกิลใหม่จาก: $RepoUrl $SkillName..." -ForegroundColor Green
        if (-not [string]::IsNullOrWhiteSpace($SkillName)) {
            npx -y $SkillsCliPkg add $RepoUrl --skill $SkillName -g
        } else {
            npx -y $SkillsCliPkg add $RepoUrl -g
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
