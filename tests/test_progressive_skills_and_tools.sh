#!/usr/bin/env bash
# ชุดทดสอบอัตโนมัติสำหรับใบงาน 20261030-progressive-skills-and-script-tools
# ครอบคลุม AC-1 (Progressive Skill Index), AC-2 (Scripts as Tools & Scaffolding), AC-3 (Evidence-Based Distillation)
set -euo pipefail

export RELAY_SOURCE_ONLY=1
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELAY_SH="$REPO_ROOT/relay.sh"
RELAY_SKILLS_SH="$REPO_ROOT/relay-skills.sh"
VERIFY_SCRIPT="$REPO_ROOT/templates/scripts/verify-relay-task.sh"

TMP_ROOT="$(mktemp -d -t relay-prog-skills.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="$3"
  if printf "%s" "$haystack" | grep -qF -- "$needle"; then
    echo "  ✅ PASS: $msg"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ❌ FAIL: $msg (missing '$needle')"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "=== AC-1 & AC-2: ทดสอบ relay-skills.sh create และ Progressive Disclosure Skill Index ==="
PROJ_DIR="$TMP_ROOT/proj"
GLOBAL_TEST_DIR="$TMP_ROOT/global"
mkdir -p "$PROJ_DIR/.relay/skills" "$GLOBAL_TEST_DIR/skills/flutter-best-practices"

cat > "$GLOBAL_TEST_DIR/skills/flutter-best-practices/SKILL.md" <<'EOF'
---
name: flutter-best-practices
description: มาตรฐานสถาปัตยกรรม Flutter และการจัดการ State
---
# Flutter Best Practices
EOF

# ทดสอบสร้าง Project Skill พร้อมโฟลเดอร์ scripts/ ด้วย relay-skills.sh create
bash "$RELAY_SKILLS_SH" create "api-contract-check" "ตรวจสอบความถูกต้องของ OpenAPI Schema และ Response Code" "$PROJ_DIR/.relay/skills" >/dev/null

if [ -f "$PROJ_DIR/.relay/skills/api-contract-check/SKILL.md" ] && [ -x "$PROJ_DIR/.relay/skills/api-contract-check/scripts/run-check.sh" ]; then
  echo "  ✅ PASS: relay-skills.sh create สร้างโฟลเดอร์ SKILL.md พร้อม YAML Frontmatter และสคริปต์ใน scripts/ สำเร็จ"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ❌ FAIL: relay-skills.sh create ไม่ได้สร้างไฟล์ครบตามโครงสร้าง"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

INDEX_OUT="$(
  export HOME="$TMP_ROOT/home"
  mkdir -p "$HOME"
  cd "$PROJ_DIR"
  source "$RELAY_SH"
  GLOBAL_DIR="$GLOBAL_TEST_DIR"
  PROJECT_DIR="$PROJ_DIR"
  RELAY_DIR="$PROJ_DIR/.relay"
  get_core_role_prompt_note "dev"
)"

assert_contains "$INDEX_OUT" "Progressive Skills Index" "แนบหัวข้อ Progressive Skills Index ใน Prompt ของ @dev"
assert_contains "$INDEX_OUT" "flutter-best-practices" "ดึง Global Skill ที่ตรงกับบทบาทพร้อมคำอธิบายจาก YAML Frontmatter"
assert_contains "$INDEX_OUT" "มาตรฐานสถาปัตยกรรม Flutter" "แสดงคำอธิบายย่อจาก YAML Frontmatter ของ Global Skill"
assert_contains "$INDEX_OUT" "api-contract-check" "ดึง Project-local Skill ใน .relay/skills/ เข้าสารบัญอัตโนมัติ"
assert_contains "$INDEX_OUT" "scripts/run-check.sh" "แสดงพาธสคริปต์ในโฟลเดอร์ scripts/ (Scripts as Tools) ในสารบัญ"

echo "=== AC-2: ทดสอบ verify-relay-task.sh (Scripts as Tools สำหรับตรวจเอกสารและไฟล์ความลับ) ==="
git -C "$PROJ_DIR" init -q -b main
git -C "$PROJ_DIR" config user.email "test@example.com"
git -C "$PROJ_DIR" config user.name "Relay Test"
TASK_PATH="$PROJ_DIR/.relay/tasks/20261030-demo"
mkdir -p "$TASK_PATH"
printf "# SPEC\n- Goal\n" > "$TASK_PATH/SPEC.md"
printf "# ARCH\n- File\n" > "$TASK_PATH/ARCH.md"
printf "# PLAN\n- Step\n" > "$TASK_PATH/PLAN.md"
printf "# QA\nVERDICT: PASS\n" > "$TASK_PATH/QA_REPORT.md"
printf '{"verdict":"PASS","failed_criteria":[],"tests_run":["npm test"],"summary":"all good"}\n' > "$TASK_PATH/QA_VERDICT.json"

VERIFY_PASS_OUT="$(bash "$VERIFY_SCRIPT" "$TASK_PATH" "$PROJ_DIR")"
assert_contains "$VERIFY_PASS_OUT" "ผ่านการตรวจสอบครบทุกข้อ" "verify-relay-task.sh ตรวจผ่านเมื่อเอกสารไม่เกินเพดานบรรทัดและไม่มีไฟล์ความลับ"

# ทดสอบกรณีมีไฟล์ .env และ SPEC.md เกิน 40 บรรทัด
touch "$PROJ_DIR/.env"
for i in $(seq 1 45); do echo "- line $i" >> "$TASK_PATH/SPEC.md"; done
if VERIFY_FAIL_OUT="$(bash "$VERIFY_SCRIPT" "$TASK_PATH" "$PROJ_DIR" 2>&1)"; then
  echo "  ❌ FAIL: verify-relay-task.sh ควรคืนค่า exit != 0 เมื่อ SPEC.md เกิน 40 บรรทัดและมีไฟล์ .env"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  assert_contains "$VERIFY_FAIL_OUT" "เกินเพดาน 40 บรรทัด" "ตรวจจับ SPEC.md เกิน 40 บรรทัดได้แม่นยำ"
  assert_contains "$VERIFY_FAIL_OUT" ".env" "ตรวจจับไฟล์ความลับต้องห้าม .env ใน Git ได้แม่นยำ"
fi
rm -f "$PROJ_DIR/.env"

echo "=== AC-3: ทดสอบ Evidence-Based Skill Distillation จาก QA_VERDICT.before-round-*.json ==="
printf '{"verdict":"FAIL","failed_criteria":["ลืมตรวจ null token ใน auth middleware"],"tests_run":["npm test"],"summary":"failed round 1"}\n' > "$TASK_PATH/QA_VERDICT.before-round-2.json"
printf '{"verdict":"PASS","failed_criteria":[],"tests_run":["npm test"],"summary":"เพิ่ม guard ตรวจ null token ก่อน verify JWT"}\n' > "$TASK_PATH/QA_VERDICT.json"

(
  export HOME="$TMP_ROOT/home"
  cd "$PROJ_DIR"
  source "$RELAY_SH"
  PROJECT_DIR="$PROJ_DIR"
  RELAY_DIR="$PROJ_DIR/.relay"
  ACTIVE_TASK="20261030-demo"
  distill_project_learned_skills "20261030-demo" "auto" >/dev/null
)

PENDING_CONTENT="$(cat "$PROJ_DIR/.relay/skills/project-learned/PENDING.md")"
assert_contains "$PENDING_CONTENT" "[บทเรียนแก้บั๊กจาก 20261030-demo]" "สกัดบทเรียนจากหลักฐานการแก้บั๊กข้ามรอบ (FAIL -> PASS) เข้าคิว PENDING.md"
assert_contains "$PENDING_CONTENT" "ลืมตรวจ null token ใน auth middleware" "บันทึกสาเหตุที่พังจริงจาก failed_criteria รอบก่อนหน้า"
assert_contains "$PENDING_CONTENT" "เพิ่ม guard ตรวจ null token ก่อน verify JWT" "บันทึกวิธีแก้ไขที่ผ่านการตรวจรับจาก summary รอบที่ผ่าน"

echo ""
echo "=================================================================="
echo "สรุปผลชุดทดสอบ Progressive Skills & Script Tools: ผ่าน ${PASS_COUNT} รายการ, ล้มเหลว ${FAIL_COUNT} รายการ"
echo "=================================================================="
[ "$FAIL_COUNT" -eq 0 ]
