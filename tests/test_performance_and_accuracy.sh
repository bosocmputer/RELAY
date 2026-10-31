#!/usr/bin/env bash
# ชุดทดสอบอัตโนมัติสำหรับใบงาน 20261031-performance-and-accuracy-cleanup (P1–P5 + ข้อความอ้างเกินจริง)
# ไม่ใช้โควต้า AI: แยก HOME ชั่วคราว ใช้ CLI จำลอง และ session log จำลอง
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELAY_SH="$REPO_ROOT/relay.sh"

TMP_ROOT="$(mktemp -d -t relay-perf-accuracy.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
ok()  { echo "  ✅ PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
bad() { echo "  ❌ FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
check() { if eval "$1"; then ok "$2"; else bad "$2"; fi; }

STUB_BIN="$TMP_ROOT/stub-bin"
mkdir -p "$STUB_BIN"
ln -s "$(command -v python3)" "$STUB_BIN/python3"
CALLS="$TMP_ROOT/cli-calls.log"
printf '#!/bin/sh\necho "claude $*" >> "%s"\n[ "$1 $2" = "auth status" ] && echo "{\\"loggedIn\\": true}"\nexit 0\n' "$CALLS" > "$STUB_BIN/claude"
printf '#!/bin/sh\necho "codex $*" >> "%s"\n[ "$1 $2" = "login status" ] && echo "Logged in using ChatGPT"\nexit 0\n' "$CALLS" > "$STUB_BIN/codex"
printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/agy"
chmod +x "$STUB_BIN"/claude "$STUB_BIN"/codex "$STUB_BIN"/agy
SAFE_PATH="$STUB_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
unset GIT_CONFIG_GLOBAL XDG_CONFIG_HOME
export GIT_CONFIG_NOSYSTEM=1

new_home() {
  local h="$TMP_ROOT/$1"
  mkdir -p "$h/.agents"
  printf '[user]\n\tname = relay-test\n\temail = relay-test@example.com\n' > "$h/.gitconfig"
  echo "$h"
}
export HOME="$(new_home base-home)"

relay_src() {
  local home="$1"
  shift
  HOME="$home" PATH="$SAFE_PATH" RELAY_SOURCE_ONLY=1 bash -c "source \"$RELAY_SH\"; $*"
}

echo "=== [P1] ผลตรวจ Login ถูกแคช 60 วินาทีในโปรเซสเดียวกัน ==="
P1_HOME="$(new_home p1)"
: > "$CALLS"
relay_src "$P1_HOME" 'refresh_cli_auth_cache; refresh_cli_auth_cache; refresh_cli_auth_cache; echo "$CLI_AUTH_CLAUDE$CLI_AUTH_CODEX"' > "$TMP_ROOT/p1.out"
check '[ "$(grep -c "claude auth status" "$CALLS")" = "1" ] && [ "$(grep -c "codex login status" "$CALLS")" = "1" ] && [ "$(cat "$TMP_ROOT/p1.out")" = "11" ]' "เรียก 3 ครั้ง ➔ ถาม claude / codex CLI ครั้งเดียว และผลยังถูกต้อง"
: > "$CALLS"
relay_src "$P1_HOME" 'refresh_cli_auth_cache; refresh_cli_auth_cache --force' >/dev/null
check '[ "$(grep -c "claude auth status" "$CALLS")" = "2" ]' "--force (หลังสั่ง login) ➔ ตรวจใหม่ทันที"
check 'grep -q "refresh_cli_auth_cache --force" "$RELAY_SH"' "login_single_provider ใช้ --force"
P1B_HOME="$(new_home p1b)"
mkdir -p "$P1B_HOME/.gemini/antigravity-cli"
got="$(relay_src "$P1B_HOME" 'refresh_cli_auth_cache; echo "$CLI_AUTH_AGY"')"
check '[ "$got" = "0" ]' "มีแค่โฟลเดอร์ ~/.gemini/antigravity-cli (ไม่มีไฟล์ login) ➔ ไม่นับว่า Login agy แล้ว"

echo "=== [P2] ไม่เรียก python ซ้ำเมื่อ session log ของ codex ไม่เปลี่ยน ==="
P2_HOME="$(new_home p2)"
sess="$P2_HOME/.codex/sessions/2026/10/31"
mkdir -p "$sess" && echo '{}' > "$sess/rollout-a.jsonl"
snap="$TMP_ROOT/p2-snap.log"
p2_stub="codex_quota_snapshot() { echo run >> '$snap'; echo 'Plus|50|-|60|-|-|-|10:00'; }"
relay_src "$P2_HOME" "$p2_stub; update_codex_quota_fast; update_codex_quota_fast; echo \"\$CODEX_5H_REM|\$CODEX_7D_REM\"" > "$TMP_ROOT/p2.out"
check '[ "$(wc -l < "$snap" | tr -d " ")" = "1" ] && [ "$(cat "$TMP_ROOT/p2.out")" = "50|60" ]' "เรียก 2 ครั้ง ไฟล์ไม่เปลี่ยน ➔ อ่าน session log ครั้งเดียว และยังได้ค่าเดิม"
rm -f "$snap"
relay_src "$P2_HOME" "$p2_stub; update_codex_quota_fast; echo more >> '$sess/rollout-a.jsonl'; update_codex_quota_fast" >/dev/null
check '[ "$(wc -l < "$snap" | tr -d " ")" = "2" ]' "session log เปลี่ยน ➔ อ่านใหม่"

echo "=== [P3] GLOBAL_AGENTS.md เหลือเฉพาะกฎที่ใช้ทุก session ==="
G="$REPO_ROOT/templates/GLOBAL_AGENTS.md"
R="$REPO_ROOT/templates/relay-roles-SKILL.md"
g_bytes="$(wc -c < "$G" | tr -d ' ')"
check '[ "$g_bytes" -lt 8000 ]' "ขนาด GLOBAL_AGENTS.md ต่ำกว่า 8,000 ไบต์ (ได้ $g_bytes)"
check 'grep -q "~/.agents/skills/relay-roles/SKILL.md" "$G" && ! grep -q "หน้าที่ความรับผิดชอบ" "$G"' "GLOBAL_AGENTS.md ชี้ไปที่ skill relay-roles และไม่มีรายละเอียดหน้าที่ของแต่ละบทบาท"
check 'grep -q "^name: relay-roles" "$R" && grep -q "@po" "$R" && grep -q "@arch" "$R" && grep -q "@dev" "$R" && grep -q "@qa" "$R" && grep -q "ไม่เกิน 40 บรรทัด" "$R"' "relay-roles/SKILL.md มีหน้าที่ครบทั้ง 4 บทบาท"
P3_HOME="$(new_home p3)"
mkdir -p "$P3_HOME/.claude/skills/user-custom"
echo "custom-skill" > "$P3_HOME/.claude/skills/user-custom/SKILL.md"
HOME="$P3_HOME" PATH="$SAFE_PATH" bash "$REPO_ROOT/setup-mac.sh" >/dev/null 2>&1
check 'cmp -s "$P3_HOME/.agents/skills/relay-roles/SKILL.md" "$R"' "setup-mac.sh ติดตั้ง ~/.agents/skills/relay-roles/SKILL.md"
check '[ -L "$P3_HOME/.claude/skills/relay-roles" ] && cmp -s "$P3_HOME/.claude/skills/relay-roles/SKILL.md" "$R" && [ -L "$P3_HOME/.claude/skills/flutter-best-practices" ]' "setup-mac.sh เชื่อม symlink ทักษะจาก ~/.agents/skills/* เข้าสู่ ~/.claude/skills/*"
check '[ -d "$P3_HOME/.claude/skills/user-custom" ] && [ ! -L "$P3_HOME/.claude/skills/user-custom" ] && [ "$(cat "$P3_HOME/.claude/skills/user-custom/SKILL.md")" = "custom-skill" ]' "ไม่เขียนทับโฟลเดอร์ทักษะจริงที่ผู้ใช้สร้างไว้เองใน ~/.claude/skills/"
check 'grep -q "relay-roles-SKILL.md" "$REPO_ROOT/setup-win.ps1" && grep -q "relay-roles-SKILL.md" "$REPO_ROOT/relay-skills.ps1" && grep -q "relay-roles-SKILL.md" "$REPO_ROOT/relay-skills.sh"' "setup-win.ps1 / relay-skills.ps1 / relay-skills.sh ติดตั้ง relay-roles ด้วย"

echo "=== [P4] นับ Token เฉพาะ session ในโฟลเดอร์ของขั้นตอนนั้น ==="
P4_HOME="$(new_home p4)"
WD="$TMP_ROOT/p4 work/proj_a"
mkdir -p "$WD"
NOW_ISO="$(python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"))')"
S_EP=$(( $(date +%s) - 60 ))
E_EP=$(( $(date +%s) + 60 ))
CL="$TMP_ROOT/claude_projects"
mine="$CL/$(python3 -c 'import re,sys; print(re.sub(r"[^A-Za-z0-9]", "-", sys.argv[1]))' "$(cd "$WD" && pwd -P)")"
mkdir -p "$mine" "$CL/-Users-someone-other-project"
printf '{"timestamp":"%s","requestId":"r1","message":{"usage":{"input_tokens":100,"output_tokens":10}}}\n' "$NOW_ISO" > "$mine/s1.jsonl"
printf '{"timestamp":"%s","requestId":"r2","message":{"usage":{"input_tokens":9000,"output_tokens":900}}}\n' "$NOW_ISO" > "$CL/-Users-someone-other-project/s2.jsonl"
got="$(RELAY_CLAUDE_PROJECTS_DIR="$CL" relay_src "$P4_HOME" "extract_step_token_usage claude $S_EP $E_EP '$WD'")"
check '[ "$got" = "110|100|0|10|1|dir" ]' "claude: นับเฉพาะ session ในโฟลเดอร์งาน ไม่รวม session อื่นที่รันพร้อมกัน (ได้ '$got')"
got="$(RELAY_CLAUDE_PROJECTS_DIR="$CL" relay_src "$P4_HOME" "extract_step_token_usage claude $S_EP $E_EP")"
check '[ "${got##*|}" = "all" ] && [ "${got%%|*}" = "10010" ]' "claude: ไม่ระบุโฟลเดอร์ ➔ รวมทุก session และระบุ scope=all"
CX="$TMP_ROOT/codex_sessions/2026/10/31"
mkdir -p "$CX"
tc() { printf '{"timestamp":"%s","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":%s,"cached_input_tokens":0,"output_tokens":%s,"total_tokens":%s}}}}\n' "$NOW_ISO" "$1" "$2" "$(( $1 + $2 ))"; }
{ printf '{"type":"session_meta","payload":{"cwd":"%s"}}\n' "$WD"; tc 200 20; } > "$CX/rollout-mine.jsonl"
{ printf '{"type":"session_meta","payload":{"cwd":"/somewhere/else"}}\n'; tc 7000 700; } > "$CX/rollout-other.jsonl"
got="$(RELAY_CODEX_SESSIONS_DIR="$TMP_ROOT/codex_sessions" relay_src "$P4_HOME" "extract_step_token_usage codex $S_EP $E_EP '$WD'")"
check '[ "$got" = "220|200|0|20|1|dir" ]' "codex: นับเฉพาะ session ที่ cwd ตรงกับโฟลเดอร์งาน (ได้ '$got')"
AG="$TMP_ROOT/agy_brain/c1/.system_generated/logs"
mkdir -p "$AG"
printf '{"type":"PLANNER_RESPONSE","created_at":"%s","step_index":1,"input_tokens":50,"output_tokens":5}\n' "$NOW_ISO" > "$AG/transcript.jsonl"
got="$(RELAY_AGY_BRAIN_DIR="$TMP_ROOT/agy_brain" relay_src "$P4_HOME" "extract_step_token_usage agy $S_EP $E_EP '$WD'")"
check '[ "${got##*|}" = "est" ]' "agy: ไม่มีข้อมูลโฟลเดอร์ ➔ ระบุว่าเป็นค่าประมาณ (scope=est)"
check 'grep -q "extract_step_token_usage \"\$provider\" \"\$run_start\" \"\$run_end\" \"\$work_dir\"" "$RELAY_SH" && [ "$(grep -c "extract_step_token_usage \"\$provider\" \"\$run_start\" \"\$run_end\" \"\$work_dir\"" "$RELAY_SH")" = "2" ]' "ทั้งโหมดกดทีละขั้นและ Auto-Loop ส่งโฟลเดอร์งานให้ตัวนับ Token"

echo "=== [P5] ไม่พบข้อมูล Token ต้องไม่แสดงเป็น 0 tokens ==="
P5_HOME="$(new_home p5)"
box="$(relay_src "$P5_HOME" 'print_step_telemetry_box "s" agy m 0 100 160 "50|50" "49|50" "0|0|0|0|0|dir"' | sed 's/\x1b\[[0-9;]*m//g')"
check 'printf "%s" "$box" | grep -q "ไม่พบข้อมูล Token" && ! printf "%s" "$box" | grep -q "0 tokens"' "แสดง 'ไม่พบข้อมูล Token' แทน '0 tokens'"
box="$(relay_src "$P5_HOME" 'print_step_telemetry_box "s" agy m 0 100 160 "50|50" "49|50" "55|50|0|5|1|est"' | sed 's/\x1b\[[0-9;]*m//g')"
check 'printf "%s" "$box" | grep -q "ค่าประมาณ"' "agy แสดงหมายเหตุว่าเป็นค่าประมาณ"
P5_PROJ="$TMP_ROOT/p5-proj"
mkdir -p "$P5_PROJ/.relay/tasks/t1"
( cd "$P5_PROJ" && relay_src "$P5_HOME" 'PROJECT_DIR="$PWD"; refresh_project_paths; ACTIVE_TASK=t1; append_run_log auto s agy m 0 100 160 "50|50" "49|50" "0|0|0|0|0|dir"' )
check 'python3 -c "import json,sys; r=json.loads(open(sys.argv[1]).readline()); sys.exit(0 if r[\"tokens\"][\"found\"] is False and r[\"tokens\"][\"scope\"]==\"dir\" else 1)" "$P5_PROJ/.relay/tasks/t1/RUN_LOG.jsonl"' "RUN_LOG บันทึก found=false และ scope"

echo "=== [ANTI-OVERCLAIM] ข้อความใน UI และเอกสาร ==="
MAIN_REPO_ROOT="$(cd "$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd || echo "$REPO_ROOT")"
hits="$(python3 - "$REPO_ROOT" "$MAIN_REPO_ROOT" <<'PYEOF'
import os, re, sys
root = sys.argv[1]
main_root = sys.argv[2]
pat = re.compile(r"เรียลไทม์|Real-Time|real-time|Live Sync|0[- ]Token|0 Token\b|\(0 tokens\)|เดินถูกเสมอ|Token จริง|Token ที่ใช้จริง|วัดจากระบบจริง|ดึงสด|โควต้าสด|ทุกตำแหน่งพร้อมทำงานต่อเนื่อง|ดึงข้อมูลจาก CLI ทั้ง 3 ค่ายโดยตรง|เริ่มสั่งงานทั้ง 4 ขั้นตอนให้อัตโนมัติ")
files = ["relay.sh", "relay.ps1", "relay-init.sh", "relay-init.ps1", "relay-skills.sh", "relay-skills.ps1", "setup-mac.sh", "setup-win.ps1", "README.md"]
for d in ("docs", "templates", "templates/scripts", "domains/business-accounting", "domains/film-video-production"):
    files += [os.path.join(d, f) for f in sorted(os.listdir(os.path.join(root, d))) if os.path.isfile(os.path.join(root, d, f))]
for f in files:
    for i, line in enumerate(open(os.path.join(root, f), encoding="utf-8", errors="ignore"), 1):
        m = pat.search(line)
        if m:
            print(f"{f}:{i}:{m.group(0)}")
ps_file = os.path.join(main_root, ".relay", "PROJECT_STATE.md")
if os.path.isfile(ps_file):
    for i, line in enumerate(open(ps_file, encoding="utf-8", errors="ignore"), 1):
        m = pat.search(line)
        if m:
            print(f".relay/PROJECT_STATE.md:{i}:{m.group(0)}")
PYEOF
)"
check '[ -z "$hits" ]' "ไม่พบคำอ้างเกินจริงในโค้ด / สคริปต์ / เอกสาร${hits:+ (พบ: $(printf "%s" "$hits" | tr '\n' ' '))}"
P6_HOME="$(new_home p6)"
box="$(relay_src "$P6_HOME" 'AGY_GEMINI_5H_REM=10; AGY_GEMINI_7D_REM=80; CODEX_5H_REM=90; CODEX_7D_REM=90; CLAUDE_5H_REM=-; CLAUDE_7D_REM=-; print_quota_report_box' | sed 's/\x1b\[[0-9;]*m//g')"
check 'printf "%s" "$box" | grep -q "โควต้าต่ำกว่า 20%: agy-Gemini 5h 10%" && printf "%s" "$box" | grep -q "ไม่มีข้อมูล: .*claude 5h"' "สรุปโควต้าแจ้งกระเป๋าที่ต่ำกว่า 20% และกระเป๋าที่ไม่มีข้อมูลตามจริง"
P7_PROJ="$TMP_ROOT/p7-proj"
mkdir -p "$P7_PROJ/.relay/tasks/t1"
out="$(cd "$P7_PROJ" && HOME="$P6_HOME" PATH="$STUB_BIN:/bin" RELAY_SOURCE_ONLY=1 /bin/bash -c "source '$RELAY_SH'; refresh_quota_cache() { :; }; extract_step_token_usage() { echo '0|0|0|0|0|dir'; }; PROJECT_DIR=\"\$PWD\"; refresh_project_paths; ACTIVE_TASK=t1; launch_provider_cli agy m test \"\$PWD\" hi" 2>&1 </dev/null | sed 's/\x1b\[[0-9;]*m//g')"
check 'printf "%s" "$out" | grep -q "คัดลอกข้อความด้านล่างไปวางเองได้"' "ไม่มี pbcopy ➔ ไม่อ้างว่าคัดลอกลง Clipboard แล้ว"

echo ""
echo "=================================================================="
echo "สรุปผลชุดทดสอบ Performance & Accuracy: ผ่าน ${PASS_COUNT} รายการ, ล้มเหลว ${FAIL_COUNT} รายการ"
echo "=================================================================="
[ "$FAIL_COUNT" -eq 0 ]
