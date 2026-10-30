#!/usr/bin/env bash
# ==============================================================================
# ชุดทดสอบระบบนำทางย้อนกลับทุกเมนู (Back Navigation) และการจัดการบทบาท Agent / Prompt / Skills
# รันด้วย: bash tests/test_custom_agents_and_back_nav.sh (ไม่ใช้โควต้า AI จริง)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELAY_SH="$REPO_DIR/relay.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf "  ✅ %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  ❌ %s\n" "$1"; }

TMP_ROOT="$(mktemp -d -t relay-agents-test.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

FUNC_FILE="$TMP_ROOT/relay_funcs.sh"
sed '/^# ─── 14\. รองรับ Subcommands/,$d' "$RELAY_SH" > "$FUNC_FILE"

export HOME="$TMP_ROOT/home"
export GLOBAL_DIR="$HOME/.agents"
mkdir -p "$GLOBAL_DIR/skills/impeccable" "$GLOBAL_DIR/skills/lucide-icons" "$GLOBAL_DIR/skills/brainstorming"

# shellcheck disable=SC1090
source "$FUNC_FILE"

echo "== AC-1: ทดสอบปุ่ม [b] ย้อนกลับในหน้าเลือก Model, หน้าเลือกค่าย และช่องรับข้อความ =="
PROJECT_DIR="$TMP_ROOT/proj1"
mkdir -p "$PROJECT_DIR/.relay/tasks"
refresh_project_paths

# 1. ทดสอบกด b ใน choose_model_interactive ต้องคืนค่า 1 และคงโมเดลเดิมไว้
out_m=""
rc_m=0
out_m="$(choose_model_interactive "agy" "ขั้นตอนที่ 1 (@po)" "gemini-4-argon-high" <<< "b")" || rc_m=$?
if [ "$rc_m" -ne 0 ] && printf "%s" "$out_m" | grep -q "ย้อนกลับ"; then
  pass "choose_model_interactive แสดงตัวเลือก [b] ย้อนกลับ และยกเลิกการเปลี่ยนโมเดลเมื่อกด b"
else
  fail "choose_model_interactive ไม่ได้ย้อนกลับอย่างถูกต้อง (rc=$rc_m)"
fi

# 2. ทดสอบกด b ใน choose_provider_interactive ต้องคืนค่า 1
rc_p=0
choose_provider_interactive "ขั้นตอนที่ 1 (@po)" "agy" <<< "b" >/dev/null || rc_p=$?
if [ "$rc_p" -ne 0 ]; then
  pass "choose_provider_interactive คืนค่าสถานะย้อนกลับทันทีเมื่อกด b (ไม่บังคับไปหน้าเลือก Model ต่อ)"
else
  fail "choose_provider_interactive ไม่ได้คืนค่าย้อนกลับเมื่อกด b"
fi

# 3. ทดสอบพิมพ์ b ใน create_new_task ต้องไม่สร้างโฟลเดอร์ใบงาน
rc_t=0
create_new_task <<< "b" >/dev/null || rc_t=$?
task_cnt="$(ls -1 "$PROJECT_DIR/.relay/tasks" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$rc_t" -ne 0 ] && [ "$task_cnt" = "0" ]; then
  pass "ช่องรับข้อความ (create_new_task / @po / Fast Track) รองรับการพิมพ์ b เพื่อย้อนกลับโดยไม่สร้างไฟล์ขยะ"
else
  fail "create_new_task สร้างใบงานทั้งที่พิมพ์ b (rc=$rc_t, count=$task_cnt)"
fi

echo "== AC-2: ทดสอบการปรับแต่ง 4 ตำแหน่งหลัก และการเพิ่ม/แก้ไข/ลบ Agent ตำแหน่งใหม่ =="
PROJECT_DIR="$TMP_ROOT/proj2"
mkdir -p "$PROJECT_DIR/.relay"
refresh_project_paths

# 1. ปรับแต่งตำแหน่งหลัก @po (Title + Custom Prompt + Skills)
set_core_role_override "$PROJECT_AGENTS_CONF" "po" "title" "Lead Product Strategist"
set_core_role_override "$PROJECT_AGENTS_CONF" "po" "prompt" "เน้นวิเคราะห์ KPI และความคุ้มค่าทางธุรกิจ"
set_core_role_override "$PROJECT_AGENTS_CONF" "po" "skills" "brainstorming impeccable"

t_po="$(get_core_role_title po)"
s_po="$(get_core_role_skills po)"
n_po="$(get_core_role_prompt_note po)"
if [ "$t_po" = "Lead Product Strategist" ] && [ "$s_po" = "brainstorming impeccable" ] && printf "%s" "$n_po" | grep -q "เน้นวิเคราะห์ KPI"; then
  pass "ปรับแต่งชื่อบทบาท, คำสั่ง Prompt และทักษะ (Skills) ของตำแหน่งหลัก (@po) ได้ครบถ้วน"
else
  fail "ข้อมูลปรับแต่งของ @po ไม่ตรงตามที่บันทึก: title=$t_po skills=$s_po note=$n_po"
fi

# รีเซ็ตกลับค่ามาตรฐาน
set_core_role_override "$PROJECT_AGENTS_CONF" "po" "reset" ""
if [ "$(get_core_role_title po)" = "Product Owner" ]; then
  pass "รีเซ็ตตำแหน่งหลัก (@po) กลับเป็นค่ามาตรฐานเริ่มต้นได้ถูกต้อง"
else
  fail "รีเซ็ตตำแหน่งหลัก (@po) ไม่สำเร็จ"
fi

if printf "%s" "$(get_core_role_default_skills dev)" | grep -q "flutter-best-practices" && [ -f "$REPO_DIR/templates/flutter-best-practices-SKILL.md" ]; then
  pass "ตำแหน่ง @dev มีทักษะมาตรฐาน flutter-best-practices และไฟล์แม่แบบพร้อมใช้งาน"
else
  fail "ไม่พบทักษะ flutter-best-practices ใน @dev"
fi

# 2. เพิ่ม Agent ตำแหน่งใหม่ (@ux และ @devops)
upsert_custom_agent "$PROJECT_AGENTS_CONF" "@ux" "UX/UI Designer" "agy" "gemini-4-argon-high" "project" "impeccable lucide-icons" "ออกแบบโครงสร้างหน้าจอและลำดับการใช้งาน"
upsert_custom_agent "$PROJECT_AGENTS_CONF" "devops" "DevOps & Cloud Engineer" "codex" "gpt-6.1-terra" "worktree" "systematic-debugging" "ดูแล Dockerfile และระบบ CI/CD"

tsv_out="$(list_custom_agents_tsv "$PROJECT_AGENTS_CONF")"
if printf "%s" "$tsv_out" | grep -q "^ux	UX/UI Designer	agy	gemini-4-argon-high	project" && \
   printf "%s" "$tsv_out" | grep -q "^devops	DevOps & Cloud Engineer	codex	gpt-6.1-terra	worktree"; then
  pass "เพิ่มตำแหน่ง Agent ใหม่ (@ux และ @devops) พร้อมกำหนด Prompt, ทักษะ และ Model สำเร็จ"
else
  fail "รายการ Custom Agents ไม่ถูกต้อง: $tsv_out"
fi

# 3. ตรวจสอบการแสดงผลบน Dashboard หลัก
ROLE_PO="agy"; MODEL_PO="gemini-4-argon-high"
ROLE_ARCH="agy"; MODEL_ARCH="claude-opus-5-5-high"
ROLE_DEV="agy"; MODEL_DEV="claude-sonnet-5-5-high"
ROLE_QA="codex"; MODEL_QA="gpt-6.1-terra"
dash_out="$(SUBCOMMAND=status print_dashboard_header)"
if printf "%s" "$dash_out" | grep -q "@ux" && printf "%s" "$dash_out" | grep -q "@devops"; then
  pass "หน้าจอหลัก (Dashboard) แสดงตำแหน่ง Agent ที่เพิ่มใหม่ (@ux, @devops) พร้อมค่ายและโมเดล"
else
  fail "หน้าจอหลักไม่แสดง @ux หรือ @devops"
fi

echo "== AC-3: ทดสอบการสั่งรัน Agent ตำแหน่งใหม่ใน Git Worktree และการวัด Token จริง =="
PROJECT_DIR="$TMP_ROOT/proj3"
mkdir -p "$PROJECT_DIR/.relay/tasks" "$PROJECT_DIR/.relay/archive"
echo "# Project State" > "$PROJECT_DIR/.relay/PROJECT_STATE.md"
git -C "$PROJECT_DIR" init -b main >/dev/null 2>&1
git -C "$PROJECT_DIR" config user.email "test@example.com"
git -C "$PROJECT_DIR" config user.name "Relay Tester"
echo "hello" > "$PROJECT_DIR/app.txt"
git -C "$PROJECT_DIR" add app.txt
git -C "$PROJECT_DIR" commit -m "init" >/dev/null 2>&1

cd "$PROJECT_DIR"
refresh_project_paths

upsert_custom_agent "$PROJECT_AGENTS_CONF" "devops" "DevOps Engineer" "codex" "gpt-6.1-terra" "worktree" "systematic-debugging" "ปรับปรุงโครงสร้าง CI/CD"

# จำลอง CLI codex และ Token Telemetry
codex() {
  echo "devops-ok" > "$PWD/devops.txt"
  git add devops.txt >/dev/null 2>&1 || true
  git commit -m "feat: add devops config" >/dev/null 2>&1 || true
  return 0
}
export RELAY_MOCK_TOKENS="6800|5800|3000|1000|2"

run_custom_agent_task "devops" "สร้างไฟล์ตั้งค่าไปป์ไลน์" >/dev/null
get_active_task

if [ -n "$ACTIVE_TASK" ] && [ -f "$PROJECT_DIR/.relay/worktrees/$ACTIVE_TASK/devops.txt" ] && \
   grep -q '"total": 6800' "$PROJECT_DIR/.relay/tasks/$ACTIVE_TASK/RUN_LOG.jsonl" && \
   grep -q '@devops' "$PROJECT_DIR/.relay/tasks/$ACTIVE_TASK/RUN_LOG.jsonl"; then
  pass "สั่งรัน Agent ตำแหน่งใหม่ (@devops) ใน Git Worktree และบันทึก Token จริง (6,800 tokens) ลง RUN_LOG.jsonl สำเร็จ"
else
  fail "การรัน @devops หรือการบันทึก RUN_LOG.jsonl ไม่สมบูรณ์"
fi

delete_custom_agent "$PROJECT_AGENTS_CONF" "devops"
if [ -z "$(get_custom_agent_field "devops" "title" "$PROJECT_AGENTS_CONF")" ]; then
  pass "ลบตำแหน่ง Agent (@devops) ออกจากไฟล์ตั้งค่าได้ถูกต้อง"
else
  fail "ลบตำแหน่ง @devops ไม่สำเร็จ"
fi

echo ""
printf "ผลรวม: ผ่าน %d • ไม่ผ่าน %d\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
