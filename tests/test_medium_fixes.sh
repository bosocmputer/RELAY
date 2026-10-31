#!/usr/bin/env bash
# ชุดทดสอบอัตโนมัติสำหรับใบงาน 20261031-medium-fixes-and-personal-rules (M1–M15 จากผลตรวจ Deep Audit)
# ไม่ใช้โควต้า AI: แยก HOME ชั่วคราว ใช้ CLI จำลอง และแทนฟังก์ชันที่เรียก agent ด้วยตัวบันทึกผล
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELAY_SH="$REPO_ROOT/relay.sh"

TMP_ROOT="$(mktemp -d -t relay-medium-fixes.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
ok()  { echo "  ✅ PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
bad() { echo "  ❌ FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
check() { if eval "$1"; then ok "$2"; else bad "$2"; fi; }

# Python ที่เก่าที่สุดที่รองรับ (macOS ติดตั้ง /usr/bin/python3 3.9 มากับ Command Line Tools)
OLD_PY="$(command -v python3)"
[ -x /usr/bin/python3 ] && OLD_PY=/usr/bin/python3

STUB_BIN="$TMP_ROOT/stub-bin"
mkdir -p "$STUB_BIN"
ln -s "$OLD_PY" "$STUB_BIN/python3"
for c in agy claude codex; do
  printf '#!/bin/sh\nexit 1\n' > "$STUB_BIN/$c"
  chmod +x "$STUB_BIN/$c"
done
SAFE_PATH="$STUB_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
unset GIT_CONFIG_GLOBAL XDG_CONFIG_HOME RELAY_WORKSPACE
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

new_repo() {
  local d="$TMP_ROOT/$1"
  mkdir -p "$d" && git -C "$d" init -q -b main && git -C "$d" commit -q --allow-empty -m init
  echo "$d"
}

echo "=== [M1] โค้ด Python ทุกจุดใน relay.sh ต้อง parse ได้บน $("$OLD_PY" --version 2>&1) ==="
parse_out="$("$OLD_PY" - "$RELAY_SH" <<'PYEOF'
import ast, re, sys
src = open(sys.argv[1], encoding="utf-8").read()
blocks = re.findall(r"<<'PYEOF'[^\n]*\n(.*?)\nPYEOF", src, re.S)
blocks += re.findall(r"python3 -c '\n(.*?)\n'", src, re.S)
bad = 0
for b in blocks:
    try:
        ast.parse(b)
    except SyntaxError as e:
        bad += 1
        print("SYNTAX", e)
print(f"{len(blocks)}|{bad}")
PYEOF
)"
check '[ "${parse_out##*|}" = "0" ] && [ "${parse_out%%|*}" -ge 25 ]' "parse ผ่านทุกบล็อก (บล็อก|ล้มเหลว = ${parse_out##*$'\n'})"

echo "=== [M2] โควต้า Codex จาก session log: ไม่มีข้อมูลต้องไม่เป็น 100% และเวลาเป็นของข้อมูลจริง ==="
M2_HOME="$(new_home m2)"
sess="$M2_HOME/.codex/sessions/2026/10/31"
mkdir -p "$sess"
printf '%s\n' '{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":30,"resets_at":1893456000},"plan_type":"plus"}}}' > "$sess/rollout-a.jsonl"
touch -t 202610310815 "$sess/rollout-a.jsonl"
out="$(relay_src "$M2_HOME" 'update_codex_quota_fast; echo "$CODEX_5H_REM|$CODEX_7D_REM|$CODEX_FETCHED_AT|$CODEX_FETCH_OK"')"
check '[ "$out" = "70|-|08:15|1" ]' "5h=70%, 7d ที่ไม่มีข้อมูลเป็น '-', เวลาข้อมูล 08:15 จาก mtime (ได้ '$out')"

echo "=== [M3/M4] refresh โควต้าเบื้องหลังและ lockfile ==="
M3_HOME="$(new_home m3)"
mark="$TMP_ROOT/m3-refresh-ran"
run_load() {
  relay_src "$M3_HOME" "refresh_quota_cache() { touch '$mark'; sleep 1; }; CLI_AUTH_AGY=$1; load_quota_cache; sleep 0.5; cat \"\$GLOBAL_DIR/relay-quota.lock\" 2>/dev/null || echo NO_LOCK"
}
printf 'QUOTA_UPDATED_EPOCH="%s"\nAGY_GEMINI_5H_REM="-"\n' "$(date +%s)" > "$M3_HOME/.agents/relay-quota.cache"
rm -f "$mark"; run_load 0 >/dev/null; sleep 1
check '[ ! -e "$mark" ]' "ไม่ได้ login agy + แคชใหม่ ➔ ไม่สั่ง refresh ทุกครั้งที่วาดหน้าจอ"
rm -f "$mark"; run_load 1 >/dev/null; sleep 1
check '[ -e "$mark" ]' "login agy แล้วแต่ไม่มีค่าโควต้า agy ➔ สั่ง refresh"
sleep 60 & live_pid=$!
echo "$live_pid" > "$M3_HOME/.agents/relay-quota.lock"
rm -f "$mark"; lock_now="$(run_load 1)"; sleep 1
check '[ ! -e "$mark" ] && [ "$lock_now" = "$live_pid" ]' "lock ใหม่ที่ PID ยังทำงาน ➔ ไม่สั่ง refresh ซ้ำ"
touch -t "$(date -v-5M +%Y%m%d%H%M 2>/dev/null || date -d '-5 min' +%Y%m%d%H%M)" "$M3_HOME/.agents/relay-quota.lock"
rm -f "$mark"; lock_now="$(run_load 1)"; sleep 1
check '[ -e "$mark" ] && [ "$lock_now" != "$live_pid" ]' "lock ค้างเกิน 2 นาที ➔ ถือว่าหมดอายุและ refresh ใหม่ (lock เก็บ PID ของตัว refresh: '$lock_now')"
{ kill "$live_pid"; wait "$live_pid"; } 2>/dev/null

T=20261031-demo
echo "=== [M5] verdict ที่ @dev เขียนเองใน Fast Track ==="
M5_HOME="$(new_home m5)"
R5="$(new_repo m5-repo)"
git -C "$R5" worktree add -q "$R5/.relay/worktrees/$T" -b "feat/$T"
mkdir -p "$R5/.relay/tasks/$T" && echo "# demo" > "$R5/.relay/tasks/$T/SPEC.md"
echo '{"verdict":"PASS","failed_criteria":[],"tests_run":["fast-track"],"summary":"ok"}' > "$R5/.relay/tasks/$T/QA_VERDICT.json"
echo f > "$R5/.relay/worktrees/$T/f.txt"
v="$(relay_src "$M5_HOME" "qa_verdict '$R5/.relay/tasks/$T'")"
check '[ "$v" = "PASS|self" ]' "qa_verdict คืนค่า PASS|self (ได้ '$v')"
out="$(cd "$R5" && printf 'c\n' | relay_src "$M5_HOME" 'require_all_roles_ready() { return 0; }; distill_project_learned_skills() { :; }; PROJECT_DIR="$PWD"; refresh_project_paths; run_phase_5_merge' 2>&1)"
check '[ "$(git -C "$R5" rev-list --count main)" = "1" ] && printf "%s" "$out" | grep -q "@dev ตรวจเอง"' "Step 5 ยังถามยืนยัน (ไม่ merge เมื่อไม่ได้ยืนยัน)"

echo "=== [M8] Step 5 หยุดเมื่อกิ่งหลักมีไฟล์ค้าง ==="
R8="$(new_repo m8-repo)"
git -C "$R8" worktree add -q "$R8/.relay/worktrees/$T" -b "feat/$T"
mkdir -p "$R8/.relay/tasks/$T" && echo '{"verdict":"PASS","failed_criteria":[],"tests_run":["npm test"],"summary":"ok"}' > "$R8/.relay/tasks/$T/QA_VERDICT.json"
echo f > "$R8/.relay/worktrees/$T/f.txt"
echo "v1" > "$R8/app.txt" && git -C "$R8" add app.txt && git -C "$R8" commit -q -m app
git -C "$R8" branch -f "feat/$T" main 2>/dev/null || git -C "$R8/.relay/worktrees/$T" merge -q main
echo "untracked" > "$R8/scratch.txt"
echo "งานค้างบน main" > "$R8/app.txt"
out="$(cd "$R8" && printf 'c\n' | relay_src "$M5_HOME" 'require_all_roles_ready() { return 0; }; PROJECT_DIR="$PWD"; refresh_project_paths; run_phase_5_merge' 2>&1)"
check '[ "$(git -C "$R8" rev-list --count main)" = "2" ] && printf "%s" "$out" | grep -q "app.txt"' "ไฟล์ที่ track แล้วแก้ค้างบน main ➔ ไม่ merge และแสดงไฟล์ (app.txt)"
git -C "$R8" checkout -q -- app.txt
out="$(cd "$R8" && printf 'c\n' | relay_src "$M5_HOME" 'require_all_roles_ready() { return 0; }; distill_project_learned_skills() { :; }; PROJECT_DIR="$PWD"; refresh_project_paths; run_phase_5_merge' 2>&1)"
check 'git -C "$R8" log --oneline -1 main | grep -q "merge: feat/$T"' "มีแค่ไฟล์ untracked (scratch.txt) ➔ ผสานได้ตามปกติ"

echo "=== [M6/M11] Auto-Loop: @arch รันใน Worktree และรันซ้ำไม่ทับหลักฐานเดิม ==="
M6_HOME="$(new_home m6)"
R6="$(new_repo m6-repo)"
mkdir -p "$R6/.relay/tasks/$T" && echo "# demo" > "$R6/.relay/tasks/$T/SPEC.md"
calls="$TMP_ROOT/m6-calls.log"
loop_stubs='require_all_roles_ready() { return 0; }; check_role_quota_safe() { return 0; }; refresh_quota_cache() { :; }
exec_provider_autonomous() {
  echo "$3|$4" >> "'"$calls"'"
  local td="$4/.relay/tasks/$ACTIVE_TASK"; mkdir -p "$td"
  case "$3" in
    *@arch*) echo "# ARCH" > "$td/ARCH.md"; echo "- step" > "$td/PLAN.md" ;;
    *@qa*) echo "{\"verdict\":\"PASS\",\"failed_criteria\":[],\"tests_run\":[\"t\"],\"summary\":\"ok\"}" > "$td/QA_VERDICT.json" ;;
  esac
  return 0
}
PROJECT_DIR="$PWD"; refresh_project_paths; run_auto_relay_loop --yes'
for i in 1 2 3; do
  ( cd "$R6" && relay_src "$M6_HOME" "$loop_stubs" </dev/null >/dev/null 2>&1 )
  sleep 1
done
arch_dir="$(grep '@arch' "$calls" | head -n 1 | cut -d'|' -f2)"
check '[ "$arch_dir" = "$R6/.relay/worktrees/$T" ]' "@arch รันใน Worktree (ได้ '$arch_dir')"
check '[ -f "$R6/.relay/tasks/$T/PLAN.md" ]' "PLAN.md ถูกซิงก์กลับมาที่ใบงานหลัก"
check '[ "$(grep -c "^# บันทึกการทำงานอัตโนมัติ" "$R6/.relay/tasks/$T/LOOP_LOG.md")" = "3" ]' "LOOP_LOG.md เก็บครบทั้ง 3 รอบที่รัน (ไม่ถูกทับ)"
check '[ "$(ls "$R6/.relay/tasks/$T" | grep -c "^QA_VERDICT.before-round-1")" = "2" ]' "ไฟล์ QA รอบก่อนไม่ถูกทับ (before-round-1 + ชื่อมีเวลา)"

echo "=== [M7] สลับค่ายบันทึกเฉพาะ config ของโปรเจกต์ ==="
M7_HOME="$(new_home m7)"
printf 'ROLE_DEV="agy"\nMODEL_DEV="claude-sonnet-5-5-high"\n' > "$M7_HOME/.agents/relay-roles.conf"
P7="$TMP_ROOT/m7-proj"; mkdir -p "$P7/.relay"
( cd "$P7" && relay_src "$M7_HOME" 'PROJECT_DIR="$PWD"; load_role_config; apply_role_provider_model_switch dev codex gpt-x' )
check 'grep -q "MODEL_DEV=\"gpt-x\"" "$P7/.relay/roles.conf" && grep -q "MODEL_DEV=\"claude-sonnet-5-5-high\"" "$M7_HOME/.agents/relay-roles.conf"' "เขียน .relay/roles.conf และไม่แตะ Global"
G7="$TMP_ROOT/m7-general"; mkdir -p "$G7"
( cd "$G7" && relay_src "$M7_HOME" 'PROJECT_DIR="$PWD"; load_role_config; apply_role_provider_model_switch dev codex gpt-y' )
check '[ ! -e "$G7/.relay" ] && grep -q "MODEL_DEV=\"claude-sonnet-5-5-high\"" "$M7_HOME/.agents/relay-roles.conf"' "โฟลเดอร์ที่ไม่มี .relay/ ➔ ไม่สร้าง .relay/ และไม่แตะ Global"

echo "=== [M9] ไม่เปิด CLI ซ้ำเมื่อกด Ctrl+C และบันทึก exit code จริง ==="
M9_HOME="$(new_home m9)"
M9_BIN="$TMP_ROOT/m9-bin"; mkdir -p "$M9_BIN"
printf '#!/bin/sh\necho call >> "%s"\nexit "${FAKE_AGY_RC:-0}"\n' "$TMP_ROOT/m9-agy.calls" > "$M9_BIN/agy"
chmod +x "$M9_BIN/agy"
P9="$TMP_ROOT/m9-proj"; mkdir -p "$P9/.relay/tasks/$T"
run_launch() {
  rm -f "$TMP_ROOT/m9-agy.calls" "$P9/.relay/tasks/$T/RUN_LOG.jsonl"
  ( cd "$P9" && FAKE_AGY_RC="$1" HOME="$M9_HOME" PATH="$M9_BIN:$SAFE_PATH" RELAY_SOURCE_ONLY=1 bash -c "source '$RELAY_SH'; refresh_quota_cache() { :; }; PROJECT_DIR=\"\$PWD\"; refresh_project_paths; ACTIVE_TASK='$T'; launch_provider_cli agy m 'test' \"\$PWD\" 'hi'" >/dev/null 2>&1 </dev/null )
}
run_launch 130
check '[ "$(wc -l < "$TMP_ROOT/m9-agy.calls" | tr -d " ")" = "1" ] && grep -q "\"exit_code\": 130" "$P9/.relay/tasks/$T/RUN_LOG.jsonl"' "Ctrl+C (130) ➔ เปิด agy ครั้งเดียว และ RUN_LOG บันทึก exit 130"
run_launch 2
check '[ "$(wc -l < "$TMP_ROOT/m9-agy.calls" | tr -d " ")" = "2" ]' "agy จบด้วย error อื่น (2) ➔ ลองเปิดแบบไม่มีคำสั่งเริ่มต้นตามเดิม"

echo "=== [M10] อนุมัติบทเรียนด้วยค่าที่อ่านไม่ออกต้องไม่ปฏิเสธทั้งหมด ==="
M10_HOME="$(new_home m10)"
P10="$TMP_ROOT/m10-proj"; mkdir -p "$P10/.relay/skills/project-learned"
printf '# p\n\n- rule one long enough\n- rule two long enough\n' > "$P10/.relay/skills/project-learned/PENDING.md"
( cd "$P10" && relay_src "$M10_HOME" 'PROJECT_DIR="$PWD"; refresh_project_paths; apply_learned_approval all' >/dev/null 2>&1 )
check '[ "$(grep -c "^- " "$P10/.relay/skills/project-learned/PENDING.md")" = "2" ]' "พิมพ์ 'all' ➔ กฎยังอยู่ในคิวครบ 2 ข้อ"
( cd "$P10" && relay_src "$M10_HOME" 'PROJECT_DIR="$PWD"; refresh_project_paths; apply_learned_approval 2' >/dev/null 2>&1 )
check 'grep -q "rule two" "$P10/.relay/skills/project-learned/SKILL.md" && ! grep -q "rule one" "$P10/.relay/skills/project-learned/SKILL.md"' "พิมพ์หมายเลขยังอนุมัติได้ตามปกติ"

echo "=== [M12] ปุ่ม [s] และการออกจากเมนูตั้งค่า ==="
M12_HOME="$(new_home m12)"
G12="$TMP_ROOT/m12-general"; mkdir -p "$G12"
( cd "$G12" && printf 's\nb\n' | relay_src "$M12_HOME" 'PROJECT_DIR="$PWD"; configure_roles_menu' >/dev/null 2>&1 )
check '[ ! -e "$G12/.relay" ]' "[s] ในโปรเจกต์ทั่วไป ➔ ไม่สร้าง .relay/"
check '[ ! -e "$M12_HOME/.agents/relay-roles.conf" ]' "ออกจากเมนูโดยไม่เปลี่ยนค่า ➔ ไม่เขียนไฟล์ตั้งค่า"

echo "=== [M13] เมนูปิด line-wrap ระหว่างวาด และเปิดคืนเมื่อออก ==="
M13_HOME="$(new_home m13)"
res="$(python3 - "$RELAY_SH" "$M13_HOME" "$SAFE_PATH" <<'PYEOF'
import os, pty, select, sys, time
relay, home, path = sys.argv[1:4]
script = f"export HOME='{home}' PATH='{path}' TERM=xterm RELAY_SOURCE_ONLY=1; source '{relay}'; interactive_menu t 0 'a|A' 'b|B'; echo \"RESULT=$MENU_RESULT\""
pid, fd = pty.fork()
if pid == 0:
    os.execv("/bin/bash", ["/bin/bash", "-c", script])
out = b""
def drain(t):
    global out
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try:
                d = os.read(fd, 4096)
            except OSError:
                return
            if not d:
                return
            out += d
drain(1.5)
os.write(fd, b"\r")
drain(1.5)
os.waitpid(pid, 0)
print(repr(out.decode("utf-8", "replace")))
PYEOF
)"
check 'printf "%s" "$res" | grep -q "?7l" && printf "%s" "$res" | grep -q "?7h" && printf "%s" "$res" | grep -q "RESULT=a"' "ส่ง ESC[?7l ก่อนวาด และ ESC[?7h ก่อนคืนผลลัพธ์"

echo "=== [M15] สแกนโปรเจกต์ใน ~/dev, ~/code และ RELAY_WORKSPACE ==="
M15_HOME="$(new_home m15)"
mkdir -p "$M15_HOME/dev/app-one" "$M15_HOME/code/app-two" "$M15_HOME/custom/app-three"
out="$(relay_src "$M15_HOME" 'list_workspace_projects_tsv' | cut -f2 | tr '\n' ' ')"
check 'printf "%s" "$out" | grep -q "app-one" && printf "%s" "$out" | grep -q "app-two"' "พบโปรเจกต์ใน ~/dev และ ~/code ($out)"
out="$(RELAY_WORKSPACE="$M15_HOME/dev" relay_src "$M15_HOME" 'list_workspace_projects_tsv' | cut -f2 | grep -c '^app-one$')"
check '[ "$out" = "1" ]' "RELAY_WORKSPACE ซ้ำกับรายการเริ่มต้น ➔ ไม่แสดงซ้ำ"
out="$(RELAY_WORKSPACE="$M15_HOME/custom" relay_src "$M15_HOME" 'list_workspace_projects_tsv' | cut -f2 | head -n 1)"
check '[ "$out" = "app-three" ]' "RELAY_WORKSPACE ถูกสแกนก่อน (ได้ '$out')"

echo "=== [Windows] relay-skills.ps1 ล็อกเวอร์ชัน npx ==="
check '! grep -nE "@latest|npx -y skills " "$REPO_ROOT/relay-skills.ps1"' "relay-skills.ps1 ไม่มี @latest หรือ npx skills ที่ไม่ระบุเวอร์ชัน"

echo ""
echo "=================================================================="
echo "สรุปผลชุดทดสอบ MEDIUM Fixes: ผ่าน ${PASS_COUNT} รายการ, ล้มเหลว ${FAIL_COUNT} รายการ"
echo "=================================================================="
[ "$FAIL_COUNT" -eq 0 ]
