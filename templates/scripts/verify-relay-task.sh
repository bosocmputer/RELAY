#!/usr/bin/env bash
# ==============================================================================
# RELAY Script-as-Tool: verify-relay-task.sh
# ตรวจสอบเอกสารของ Task, ไฟล์ความลับต้องห้าม และโครงสร้าง QA_VERDICT.json ด้วยสคริปต์ (ไม่เรียก AI)
# การใช้งาน: relay-verify-task [.relay/tasks/<task-id>] [work_dir]
# ==============================================================================
set -euo pipefail

TASK_DIR="${1:-}"
WORK_DIR="${2:-.}"

if [ -z "$TASK_DIR" ]; then
  if [ -d "$WORK_DIR/.relay/tasks" ]; then
    latest_t="$(ls -1 "$WORK_DIR/.relay/tasks" 2>/dev/null | grep -v '^\.' | sort | tail -n 1 || true)"
    [ -n "$latest_t" ] && TASK_DIR="$WORK_DIR/.relay/tasks/$latest_t"
  fi
fi

if [ -z "$TASK_DIR" ] || [ ! -d "$TASK_DIR" ]; then
  echo "✖ [verify-relay-task] ไม่พบโฟลเดอร์ Task ที่ต้องการตรวจสอบ (${TASK_DIR:-ไม่ได้ระบุ})"
  exit 1
fi

ERR_COUNT=0
ok()  { printf "  ● PASS: %s\n" "$1"; }
err() { printf "  ✖ FAIL: %s\n" "$1"; ERR_COUNT=$((ERR_COUNT + 1)); }

check_max_lines() {
  local file="$1"
  local max_lines="$2"
  local label="$3"
  if [ ! -f "$file" ]; then
    return 0
  fi
  local lines
  lines="$(wc -l < "$file" | tr -d ' ')"
  if [ "$lines" -le "$max_lines" ]; then
    ok "${label} มีความยาว ${lines}/${max_lines} บรรทัด (อยู่ในเกณฑ์)"
  else
    err "${label} มีความยาว ${lines} บรรทัด (เกินเพดาน ${max_lines} บรรทัด)"
  fi
}

echo "🔎 [RELAY Verify Tool] กำลังตรวจสอบ Task: $TASK_DIR"

# 1. ตรวจเพดานความยาวเอกสารตามมาตรฐาน RELAY
if [ -f "$TASK_DIR/SPEC.md" ]; then
  check_max_lines "$TASK_DIR/SPEC.md" 40 "SPEC.md"
else
  err "ไม่พบเอกสารบังคับ SPEC.md ใน $TASK_DIR"
fi

check_max_lines "$TASK_DIR/ARCH.md" 30 "ARCH.md"
check_max_lines "$TASK_DIR/PLAN.md" 30 "PLAN.md"
if [ -f "$TASK_DIR/ARCH.md" ] && [ -f "$TASK_DIR/PLAN.md" ]; then
  arch_l="$(wc -l < "$TASK_DIR/ARCH.md" | tr -d ' ')"
  plan_l="$(wc -l < "$TASK_DIR/PLAN.md" | tr -d ' ')"
  total_ap=$((arch_l + plan_l))
  if [ "$total_ap" -le 60 ]; then
    ok "ARCH.md + PLAN.md รวมกัน ${total_ap}/60 บรรทัด"
  else
    err "ARCH.md + PLAN.md รวมกัน ${total_ap} บรรทัด (เกินเพดานรวม 60 บรรทัด)"
  fi
fi
check_max_lines "$TASK_DIR/QA_REPORT.md" 30 "QA_REPORT.md"

# 2. ตรวจหาไฟล์ความลับและฐานข้อมูลต้องห้ามใน Git Worktree / Repository
if git -C "$WORK_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  forbidden=""
  while IFS= read -r path; do
    path="${path#\"}"
    path="${path%\"}"
    [ -z "$path" ] && continue
    bname="$(basename "$path")"
    case "$bname" in
      .env.example|.env.sample|.env.template|.env.schema) continue ;;
      .env|.env.*|*.key|*.pem|*.sqlite|*.sqlite3|*.db)
        forbidden="${forbidden}${path} "
        ;;
    esac
  done < <(git -C "$WORK_DIR" status --porcelain -- . ':(exclude).relay' 2>/dev/null | sed -E 's/^.. //' | sed -E 's/.* -> //' || true)

  if [ -z "$forbidden" ]; then
    ok "ไม่พบไฟล์ความลับหรือฐานข้อมูลต้องห้าม (.env*, *.key, *.pem, *.sqlite*, *.db) ในสถานะ Git"
  else
    err "พบไฟล์ความลับหรือฐานข้อมูลต้องห้ามในสถานะ Git: ${forbidden}"
  fi
fi

# 3. ตรวจโครงสร้าง QA_VERDICT.json (ถ้ามี)
if [ -f "$TASK_DIR/QA_VERDICT.json" ] && command -v python3 >/dev/null 2>&1; then
  if v_msg="$(python3 - "$TASK_DIR/QA_VERDICT.json" <<'PYEOF'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p, encoding="utf-8"))
except Exception as e:
    print(f"INVALID_JSON:{e}")
    sys.exit(1)
v = str(d.get("verdict", "")).strip().upper()
fc = d.get("failed_criteria")
tr = d.get("tests_run")
sm = d.get("summary")
if v not in ("PASS", "FAIL"):
    print("BAD_VERDICT:verdict ต้องเป็น PASS หรือ FAIL")
    sys.exit(1)
if not isinstance(fc, list) or not isinstance(tr, list) or not isinstance(sm, str):
    print("BAD_FIELDS:ต้องมี failed_criteria (list), tests_run (list), summary (str)")
    sys.exit(1)
if v == "PASS" and len(fc) > 0:
    print("CONTRADICTION:verdict เป็น PASS แต่ failed_criteria ไม่ว่าง")
    sys.exit(1)
print(f"OK:{v} (tests={len(tr)})")
PYEOF
  )"; then
    ok "QA_VERDICT.json โครงสร้างถูกต้อง (${v_msg#OK:})"
  else
    err "QA_VERDICT.json ไม่ถูกต้อง (${v_msg})"
  fi
fi

if [ "$ERR_COUNT" -eq 0 ]; then
  echo "✅ [RELAY Verify Tool] ผ่านการตรวจสอบครบทุกข้อ"
  exit 0
else
  echo "❌ [RELAY Verify Tool] พบข้อผิดพลาด ${ERR_COUNT} รายการ"
  exit 1
fi
