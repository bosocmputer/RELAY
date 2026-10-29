<#
.SYNOPSIS
    RELAY Central Terminal Hub (v1.0) — Guided 3-Stage Progressive UX สำหรับ Windows (PowerShell)
.DESCRIPTION
    • โทนสี Minimalist High-Contrast (Monochrome Blue + Status Dots)
    • ไฮไลต์บรรทัดที่เลือกด้วย ❯ + สีน้ำเงินตัวหนาทั้งบรรทัด
    • รองรับ Google AI Ultra ผ่าน Antigravity CLI (agy) พร้อมทั้ง Gemini 4 Argon, Claude Opus 5.5, Claude Sonnet 5.5 และ GPT-OSS 120B
    • ตรวจสอบความพร้อมจริง 3 ชั้น: ติดตั้ง CLI แล้ว + Login บัญชีแล้ว + เลือก Model แล้ว
    • ดึงรายชื่อ Model จาก CLI ที่ติดตั้งในเครื่องโดยตรง (agy models / Codex models_cache.json / Gemini / Claude)
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

$Script:ROLE_PO = "agy";      $Script:MODEL_PO = "default"
$Script:ROLE_ARCH = "agy";    $Script:MODEL_ARCH = "default"
$Script:ROLE_DEV = "agy";     $Script:MODEL_DEV = "default"
$Script:ROLE_QA = "codex";    $Script:MODEL_QA = "default"
$Script:CONFIG_SOURCE = "Global (~/.agents/relay-roles.conf)"
$Script:ACTIVE_TASK = ""
$Script:READY_COUNT = 0
$Script:ALL_READY = $false
$Script:UX_STAGE = 1
$Script:AGY_GEMINI_5H = "-"
$Script:AGY_GEMINI_7D = "-"
$Script:AGY_CLAUDE_5H = "-"
$Script:AGY_CLAUDE_7D = "-"
$Script:CODEX_5H = "-"
$Script:CODEX_7D = "-"
$Script:CLAUDE_5H = "-"
$Script:CLAUDE_7D = "-"
$Script:QUOTA_TIME = "-"

function Update-QuotaCache {
    $Script:QUOTA_TIME = (Get-Date).ToString("HH:mm:ss")
    if (Test-ProviderInstalled "agy") {
        try {
            $agyBin = Get-ProviderBin "agy"
            $out = (& $agyBin -p "/usage" 2>$null) -join "`n"
            foreach ($line in ($out -split "`r?`n")) {
                if ($line -match "Gemini Models\s+Weekly Limit Remaining\s+(\d+)%")     { $Script:AGY_GEMINI_7D = $Matches[1] }
                if ($line -match "Gemini Models\s+Five Hour Limit Remaining\s+(\d+)%")  { $Script:AGY_GEMINI_5H = $Matches[1] }
                if ($line -match "Claude and GPT models\s+Weekly Limit Remaining\s+(\d+)%")     { $Script:AGY_CLAUDE_7D = $Matches[1] }
                if ($line -match "Claude and GPT models\s+Five Hour Limit Remaining\s+(\d+)%")  { $Script:AGY_CLAUDE_5H = $Matches[1] }
            }
        } catch {}
    }
    try {
        $sessRoot = Join-Path $HOME ".codex\sessions"
        if (Test-Path $sessRoot) {
            $latest = Get-ChildItem -Path $sessRoot -Filter "rollout-*.jsonl" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3
            foreach ($f in $latest) {
                $lines = Get-Content $f.FullName -ErrorAction SilentlyContinue
                [array]::Reverse($lines)
                $done = $false
                foreach ($l in $lines) {
                    if ($l -match '"rate_limits"' -and $l -match '"token_count"') {
                        $obj = $l | ConvertFrom-Json
                        $rl = $obj.payload.rate_limits
                        if ($null -ne $rl.primary.used_percent)   { $Script:CODEX_5H = [string][Math]::Round(100 - [double]$rl.primary.used_percent) }
                        if ($null -ne $rl.secondary.used_percent) { $Script:CODEX_7D = [string][Math]::Round(100 - [double]$rl.secondary.used_percent) }
                        $done = $true; break
                    }
                }
                if ($done) { break }
            }
        }
    } catch {}
    if (Test-ProviderInstalled "claude") {
        try {
            $req = '{"type":"control_request","request_id":"1","request":{"subtype":"get_usage","skip_behaviors":true}}'
            $cOut = ($req | & claude -p --input-format stream-json --output-format stream-json --verbose 2>$null) -join "`n"
            foreach ($cl in ($cOut -split "`r?`n")) {
                if ($cl -match '"control_response"' -and $cl -match '"rate_limits"') {
                    $cObj = $cl | ConvertFrom-Json
                    $rl = $cObj.response.response.rate_limits
                    if ($null -ne $rl.five_hour.utilization) { $Script:CLAUDE_5H = [string][Math]::Round(100 - [double]$rl.five_hour.utilization) }
                    if ($null -ne $rl.seven_day.utilization) { $Script:CLAUDE_7D = [string][Math]::Round(100 - [double]$rl.seven_day.utilization) }
                    break
                }
            }
        } catch {}
    }
}

function Get-ProviderBin([string]$Provider) {
    if ($Provider -eq "agy") {
        $cmd = Get-Command "agy" -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
        $gemBin = Join-Path $HOME ".gemini\bin\agy.exe"
        if (Test-Path $gemBin) { return $gemBin }
        $gemBinNoExt = Join-Path $HOME ".gemini\bin\agy"
        if (Test-Path $gemBinNoExt) { return $gemBinNoExt }
        return ""
    }
    $c = Get-Command $Provider -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return ""
}

function Test-ProviderInstalled([string]$Provider) {
    return (-not [string]::IsNullOrWhiteSpace((Get-ProviderBin $Provider)))
}

function Test-ProviderLoggedIn([string]$Provider) {
    if (-not (Test-ProviderInstalled $Provider)) { return $false }
    switch ($Provider) {
        "agy" {
            $tokenFile = Join-Path $HOME ".gemini\jetski-standalone-oauth-token"
            if (Test-Path $tokenFile) { return $true }
            $agyBin = Get-ProviderBin "agy"
            $out = (& $agyBin models 2>$null) -join " "
            return ($out -match "Available models")
        }
        "claude" {
            if ($env:ANTHROPIC_API_KEY) { return $true }
            $out = (& claude auth status 2>$null) -join " "
            return ($out -match '"loggedIn"\s*:\s*true')
        }
        "gemini" {
            if ($env:GEMINI_API_KEY -or $env:GOOGLE_GENAI_USE_VERTEXAI) { return $true }
            $settingsFile = Join-Path $HOME ".gemini\settings.json"
            if (Test-Path $settingsFile) {
                $raw = Get-Content $settingsFile -Raw -ErrorAction SilentlyContinue
                return ($raw -match '"selectedType"\s*:\s*"(gemini-api-key|vertex-ai)"')
            }
            return $false
        }
        "codex" {
            if ($env:OPENAI_API_KEY) { return $true }
            $out = (& codex login status 2>&1) -join " "
            if ($out -match "Logged in") { return $true }
            return (Test-Path (Join-Path $HOME ".codex\auth.json"))
        }
    }
    return $false
}

function Get-CliDefaultModel([string]$Provider) {
    switch ($Provider) {
        "agy" {
            return "gemini-4-argon-high"
        }
        "claude" {
            $sf = Join-Path $HOME ".claude\settings.json"
            if (Test-Path $sf) {
                $raw = Get-Content $sf -Raw -ErrorAction SilentlyContinue
                if ($raw -match '"model"\s*:\s*"([^"]+)"') { return $Matches[1] }
            }
            return "sonnet"
        }
        "codex" {
            $cf = Join-Path $HOME ".codex\config.toml"
            if (Test-Path $cf) {
                $lines = Get-Content $cf -ErrorAction SilentlyContinue
                foreach ($l in $lines) {
                    if ($l -match '^\s*model\s*=\s*"([^"]+)"') { return $Matches[1] }
                }
            }
            $mc = Join-Path $HOME ".codex\models_cache.json"
            if (Test-Path $mc) {
                try {
                    $json = Get-Content $mc -Raw | ConvertFrom-Json
                    foreach ($m in $json.models) {
                        if ($m.visibility -eq "list" -and $m.slug) { return $m.slug }
                    }
                } catch {}
            }
            return "o3"
        }
        "gemini" {
            $gf = Join-Path $HOME ".gemini\settings.json"
            if (Test-Path $gf) {
                $raw = Get-Content $gf -Raw -ErrorAction SilentlyContinue
                if ($raw -match '"model"\s*:\s*"([^"]+)"') { return $Matches[1] }
            }
            return "gemini-2.5-pro"
        }
    }
    return "default"
}

function Load-RoleConfig {
    if (Test-ProviderInstalled "agy") {
        $Script:ROLE_PO = "agy";   $Script:MODEL_PO = "default"
        $Script:ROLE_ARCH = "agy"; $Script:MODEL_ARCH = "default"
        $Script:ROLE_DEV = "agy";  $Script:MODEL_DEV = "default"
    } else {
        $Script:ROLE_PO = "gemini";   $Script:MODEL_PO = "default"
        $Script:ROLE_ARCH = "claude"; $Script:MODEL_ARCH = "default"
        $Script:ROLE_DEV = "claude";  $Script:MODEL_DEV = "default"
    }
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

    if ($Script:ROLE_QA -eq "codex" -and $Script:MODEL_QA -eq "o3") {
        $realCodex = Get-CliDefaultModel "codex"
        if ($realCodex -and $realCodex -ne "o3") { $Script:MODEL_QA = $realCodex }
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

function Test-ModelExplicitlySet([string]$Model) {
    return (-not [string]::IsNullOrWhiteSpace($Model) -and $Model -ne "default" -and $Model -ne "unconfigured")
}

function Test-RoleReady([string]$Provider, [string]$Model) {
    return ((Test-ProviderInstalled $Provider) -and (Test-ProviderLoggedIn $Provider) -and (Test-ModelExplicitlySet $Model))
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
    if (-not (Test-ProviderInstalled $Provider)) { return "✖ ยังไม่ติดตั้ง CLI (กด [3])" }
    if (-not (Test-ProviderLoggedIn $Provider)) {
        if ($Provider -eq "gemini") { return "▲ ต้องใช้ API Key หรือเปลี่ยนเป็น agy (Ultra)" }
        return "▲ ยังไม่ Login บัญชี (กด [3])"
    }
    if (-not (Test-ModelExplicitlySet $Model))    { return "▲ รอเลือกโมเดล (กด [1]/[2])" }
    if ($Provider -eq "agy") { return "● พร้อมใช้งาน (Google AI Ultra)" }
    return "● พร้อมใช้งาน (Login แล้ว)"
}

function Invoke-QuickPresetMenu {
    $codexDef = Get-CliDefaultModel "codex"
    $geminiDef = Get-CliDefaultModel "gemini"
    $choice = Invoke-InteractiveMenu "เลือกชุดการตั้งค่าด่วน (ดึง Model จริงจาก Google AI Ultra / CLI ในเครื่องโดยตรง)" 0 @(
        "1|★ ชุดแนะนำ Google AI Ultra + Codex — @po=agy(gemini-4-argon-high), @arch=agy(claude-opus-5-5-high), @dev=agy(claude-sonnet-5-5-high), @qa=codex($codexDef)",
        "2|All-Google AI Ultra (100% agy) — @po=gemini-4-argon-high, @arch=claude-opus-5-5-high, @dev=claude-sonnet-5-5-high, @qa=gpt-oss-120b-medium",
        "3|Multi-Vendor แยกค่ายอิสระ      — @po=agy(gemini-4-argon-high), @arch=claude(opus), @dev=claude(sonnet), @qa=codex($codexDef)",
        "4|All-Claude CLI Preset          — ใช้ Claude CLI ทั้ง 4 ตำแหน่ง (@po=sonnet, @arch=opus, @dev=sonnet, @qa=opus)",
        "5|All-Codex CLI Preset           — ใช้ Codex CLI ทั้ง 4 ตำแหน่ง ($codexDef จาก CLI ทั้ง 4 ตำแหน่ง)",
        "b|ย้อนกลับ"
    )
    switch ($choice) {
        "1" {
            $Script:ROLE_PO="agy";      $Script:MODEL_PO="gemini-4-argon-high"
            $Script:ROLE_ARCH="agy";    $Script:MODEL_ARCH="claude-opus-5-5-high"
            $Script:ROLE_DEV="agy";     $Script:MODEL_DEV="claude-sonnet-5-5-high"
            $Script:ROLE_QA="codex";    $Script:MODEL_QA=$codexDef
            Save-RoleConfig $GlobalRolesConf
        }
        "2" {
            $Script:ROLE_PO="agy";      $Script:MODEL_PO="gemini-4-argon-high"
            $Script:ROLE_ARCH="agy";    $Script:MODEL_ARCH="claude-opus-5-5-high"
            $Script:ROLE_DEV="agy";     $Script:MODEL_DEV="claude-sonnet-5-5-high"
            $Script:ROLE_QA="agy";      $Script:MODEL_QA="gpt-oss-120b-medium"
            Save-RoleConfig $GlobalRolesConf
        }
        "3" {
            $Script:ROLE_PO="agy";      $Script:MODEL_PO="gemini-4-argon-high"
            $Script:ROLE_ARCH="claude"; $Script:MODEL_ARCH="opus"
            $Script:ROLE_DEV="claude";  $Script:MODEL_DEV="sonnet"
            $Script:ROLE_QA="codex";    $Script:MODEL_QA=$codexDef
            Save-RoleConfig $GlobalRolesConf
        }
        "4" {
            $Script:ROLE_PO="claude";   $Script:MODEL_PO="sonnet"
            $Script:ROLE_ARCH="claude"; $Script:MODEL_ARCH="opus"
            $Script:ROLE_DEV="claude";  $Script:MODEL_DEV="sonnet"
            $Script:ROLE_QA="claude";   $Script:MODEL_QA="opus"
            Save-RoleConfig $GlobalRolesConf
        }
        "5" {
            $Script:ROLE_PO="codex";   $Script:MODEL_PO=$codexDef
            $Script:ROLE_ARCH="codex"; $Script:MODEL_ARCH=$codexDef
            $Script:ROLE_DEV="codex";  $Script:MODEL_DEV=$codexDef
            $Script:ROLE_QA="codex";   $Script:MODEL_QA=$codexDef
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
    if ($Script:QUOTA_TIME -eq "-") { Update-QuotaCache }
    Write-Host ""
    Write-Host " ██╗      ██████╗  ███████╗ ██╗       █████╗  ██╗   ██╗" -ForegroundColor Blue
    Write-Host " ╚██╗     ██╔══██╗ ██╔════╝ ██║      ██╔══██╗ ╚██╗ ██╔╝" -ForegroundColor Blue
    Write-Host "  ╚██╗    ██████╔╝ █████╗   ██║      ███████║  ╚████╔╝ " -ForegroundColor Blue
    Write-Host "  ██╔╝    ██╔══██╗ ██╔══╝   ██║      ██╔══██║   ╚██╔╝  " -ForegroundColor Blue
    Write-Host " ██╔╝     ██║  ██║ ███████╗ ███████╗ ██║  ██║    ██║   " -ForegroundColor Blue
    Write-Host " ╚═╝      ╚═╝  ╚═╝ ╚══════╝ ╚══════╝ ╚═╝  ╚═╝    ╚═╝   RELAY v1.0 • Multi-Agent Handoff Hub" -ForegroundColor DarkBlue
    Write-Host "╭────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue
    if ($Script:UX_STAGE -eq 1) {
        Write-Host ("│ ลำดับงาน : ● [ขั้นที่ 1: ตั้งค่า & Login AI ({0}/4)] ──➔ ○ ขั้นที่ 2: เตรียมโปรเจกต์ ──➔ ○ ขั้นที่ 3: เริ่มสั่งงาน" -f $Script:READY_COUNT) -ForegroundColor Blue
    } elseif ($Script:UX_STAGE -eq 2) {
        Write-Host "│ ลำดับงาน : ✓ ขั้นที่ 1: ตั้งค่า & Login AI (4/4) ──➔ ● [ขั้นที่ 2: เตรียมโปรเจกต์] ──➔ ○ ขั้นที่ 3: เริ่มสั่งงาน" -ForegroundColor Blue
    } else {
        Write-Host "│ ลำดับงาน : ✓ ขั้นที่ 1: ตั้งค่า & Login AI (4/4) ──➔ ✓ ขั้นที่ 2: เตรียมโปรเจกต์ ──➔ ● [ขั้นที่ 3: เริ่มสั่งงาน]" -ForegroundColor Blue
    }
    Write-Host "├────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue
    Write-Host ("│ 1. @po (Product)    ➔ {0,-6} │ {1,-22} │ {2}" -f $Script:ROLE_PO, $Script:MODEL_PO, (Get-RoleStatusText $Script:ROLE_PO $Script:MODEL_PO))
    Write-Host ("│ 2. @arch & @pm      ➔ {0,-6} │ {1,-22} │ {2}" -f $Script:ROLE_ARCH, $Script:MODEL_ARCH, (Get-RoleStatusText $Script:ROLE_ARCH $Script:MODEL_ARCH))
    Write-Host ("│ 3. @dev (Worktree)  ➔ {0,-6} │ {1,-22} │ {2}" -f $Script:ROLE_DEV, $Script:MODEL_DEV, (Get-RoleStatusText $Script:ROLE_DEV $Script:MODEL_DEV))
    Write-Host ("│ 4. @qa & @sec       ➔ {0,-6} │ {1,-22} │ {2}" -f $Script:ROLE_QA, $Script:MODEL_QA, (Get-RoleStatusText $Script:ROLE_QA $Script:MODEL_QA))
    Write-Host "├────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue
    Write-Host ("│ โควต้าคงเหลือแต่ละค่าย (Real-Time Quota) [อัปเดต {0} • กด [u] หรือ /quota เพื่อดึงข้อมูลสด]:" -f $Script:QUOTA_TIME)
    Write-Host ("│  • agy (Gemini Models)  ➔ 5 ชม.: {0}% │ รายสัปดาห์: {1}%" -f $Script:AGY_GEMINI_5H, $Script:AGY_GEMINI_7D)
    Write-Host ("│  • agy (Claude & GPT)   ➔ 5 ชม.: {0}% │ รายสัปดาห์: {1}%" -f $Script:AGY_CLAUDE_5H, $Script:AGY_CLAUDE_7D)
    Write-Host ("│  • codex (OpenAI Plus)  ➔ 5 ชม.: {0}% │ รายสัปดาห์: {1}%" -f $Script:CODEX_5H, $Script:CODEX_7D)
    Write-Host ("│  • claude (Claude Pro)  ➔ 5 ชม.: {0}% │ รายสัปดาห์: {1}%" -f $Script:CLAUDE_5H, $Script:CLAUDE_7D)
    Write-Host "├────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue
    if ($Script:UX_STAGE -eq 1) {
        Write-Host "│ 👉 สิ่งที่ต้องทำตอนนี้ (ขั้นที่ 1/3): ตั้งค่าและ Login บัญชี CLI ให้ครบ 4 ตำแหน่ง" -ForegroundColor Blue
    } elseif ($Script:UX_STAGE -eq 2) {
        Write-Host ("│ 👉 สิ่งที่ต้องทำตอนนี้ (ขั้นที่ 2/3): เตรียมโครงสร้าง .relay/ สำหรับโปรเจกต์ '{0}' (กด Enter ที่ข้อ [1])" -f $ProjectName) -ForegroundColor Blue
    } else {
        Write-Host "│ 👉 ขั้นตอนถัดไปที่แนะนำ (ขั้นที่ 3/3): กด Enter ที่ข้อที่มีเครื่องหมาย ★ เพื่อเริ่มทำงาน" -ForegroundColor Blue
    }
    Write-Host "╰────────────────────────────────────────────────────────────────────────" -ForegroundColor Blue
}

if ($SubCommand -eq "status" -or $SubCommand -eq "quota" -or $SubCommand -eq "usage") {
    Update-QuotaCache
    Print-DashboardHeader
    exit 0
}

while ($true) {
    Print-DashboardHeader
    if ($Script:UX_STAGE -eq 1) {
        $act = Invoke-InteractiveMenu "ขั้นที่ 1/3: ตั้งค่าค่าย AI, เลือก Model และ Login ให้ครบ 4 ตำแหน่ง (พร้อม $($Script:READY_COUNT)/4)" 0 @(
            "1|★ ตั้งค่าด่วนครบ 4 ตำแหน่งในคลิกเดียว (Quick Setup — Google AI Ultra + Codex)",
            "3|เข้าสู่ระบบ (Login) ค่ายที่ยังไม่ได้เชื่อมบัญชี (agy auth login / claude auth login / codex login)",
            "q|ออกจากโปรแกรม (/quit)"
        )
        if ($act -eq "1") { Invoke-QuickPresetMenu }
        if ($act -eq "3") { & claude auth login }
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
