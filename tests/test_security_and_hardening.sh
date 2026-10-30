#!/usr/bin/env bash
# ชุดทดสอบอัตโนมัติสำหรับใบงาน 20261030-core-security-and-reliability-hardening
# ครอบคลุม SEC-1..SEC-3 และ REL-1..REL-5
set -euo pipefail

export RELAY_SOURCE_ONLY=1
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELAY_SH="$REPO_ROOT/relay.sh"
RELAY_INIT_SH="$REPO_ROOT/relay-init.sh"

TMP_ROOT="$(mktemp -d -t relay-sec-hardening.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ PASS: $msg"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ❌ FAIL: $msg (expected='$expected', actual='$actual')"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

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

echo "=== [1/8] SEC-1: Safe Config & Quota Cache Parser (บล็อกการรันคำสั่งจาก roles.conf และ relay-quota.cache) ==="
SEC1_DIR="$TMP_ROOT/sec1"
mkdir -p "$SEC1_DIR/.relay" "$SEC1_DIR/global"
PWN_FILE="$SEC1_DIR/pwned_marker"

cat > "$SEC1_DIR/.relay/roles.conf" <<EOF
ROLE_PO="claude"
MODEL_PO="claude-sonnet-4-6"
ROLE_DEV="\$(touch $PWN_FILE; echo codex)"
MODEL_DEV="gpt-5.4; touch $PWN_FILE"
$(printf 'touch %s\n' "$PWN_FILE")
EOF

cat > "$SEC1_DIR/global/relay-quota.cache" <<EOF
QUOTA_UPDATED_EPOCH="$(date +%s)"
CLAUDE_PLAN="\$(touch $PWN_FILE; echo Max)"
CLAUDE_5H_REM="84"
\`touch $PWN_FILE\`
EOF

SEC1_OUT="$(
  export HOME="$SEC1_DIR/home"
  export RELAY_SOURCE_ONLY=1
  mkdir -p "$HOME"
  cd "$SEC1_DIR"
  source "$RELAY_SH"
  GLOBAL_DIR="$SEC1_DIR/global"
  GLOBAL_ROLES_CONF="$GLOBAL_DIR/roles.conf"
  QUOTA_CACHE_FILE="$GLOBAL_DIR/relay-quota.cache"
  PROJECT_DIR="$SEC1_DIR"
  RELAY_DIR="$SEC1_DIR/.relay"
  PROJECT_ROLES_CONF="$RELAY_DIR/roles.conf"
  CLAUDE_PLAN="-"
  load_role_config
  safe_load_quota_cache "$QUOTA_CACHE_FILE"
  printf "PO=%s/%s|DEV=%s/%s|CLAUDE_PCT=%s|CLAUDE_PLAN=%s" "$ROLE_PO" "$MODEL_PO" "$ROLE_DEV" "$MODEL_DEV" "$CLAUDE_5H_REM" "$CLAUDE_PLAN"
)"

if [ ! -e "$PWN_FILE" ]; then
  echo "  ✅ PASS: ไม่มีการรันคำสั่งอันตรายจาก roles.conf หรือ relay-quota.cache"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ❌ FAIL: คำสั่งที่ฝังในไฟล์ config ถูกรันจริง!"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
assert_contains "$SEC1_OUT" "PO=claude/claude-sonnet-4-6" "โหลดค่าที่ปลอดภัยจาก roles.conf ได้ถูกต้อง"
assert_contains "$SEC1_OUT" "CLAUDE_PCT=84" "โหลดตัวเลขโควต้าที่ปลอดภัยจาก relay-quota.cache ได้ถูกต้อง"
assert_contains "$SEC1_OUT" "CLAUDE_PLAN=-" "ปฏิเสธค่าที่มี \$(...) ใน relay-quota.cache"

echo "=== [2/8] SEC-2: ป้องกัน Command Expansion จาก Backtick / \$() ใน Fast Track SPEC.md และ relay-init.sh ==="
SEC2_DIR="$TMP_ROOT/sec2/proj-\$(touch $TMP_ROOT/init_pwned)"
mkdir -p "$SEC2_DIR"
bash "$RELAY_INIT_SH" "$SEC2_DIR" >/dev/null
if [ ! -e "$TMP_ROOT/init_pwned" ] && [ -f "$SEC2_DIR/.relay/PROJECT_STATE.md" ]; then
  echo "  ✅ PASS: relay-init.sh สร้าง PROJECT_STATE.md โดยไม่รันคำสั่งในชื่อโฟลเดอร์"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ❌ FAIL: relay-init.sh รันคำสั่งแฝงหรือไม่ได้สร้างไฟล์"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

FT_DIR="$TMP_ROOT/sec2_ft"
mkdir -p "$FT_DIR/.relay/tasks/20261030-fast"
FT_PWN="$TMP_ROOT/ft_pwned"
(
  cd "$FT_DIR"
  source "$RELAY_SH"
  RELAY_DIR="$FT_DIR/.relay"
  ACTIVE_TASK="20261030-fast"
  fast_goal="แก้บั๊กในฟังก์ชัน \`touch $FT_PWN\` และ \$(touch $FT_PWN)"
  safe_goal="${fast_goal:-แก้ไขโค้ดและชุดทดสอบตามคำสั่งของผู้ใช้}"
  {
    printf "# ใบงานด่วน (Fast Track SPEC — %s)\n" "$ACTIVE_TASK"
    printf -- "- **โหมด:** Fast Track (ข้าม @po และ @arch เพื่อลด Ceremony Overhead สำหรับงานขนาดเล็ก)\n"
    printf -- "- **เป้าหมาย:** %s\n\n" "$safe_goal"
  } > "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md"
)
if [ ! -e "$FT_PWN" ] && grep -qF "\`touch $FT_PWN\`" "$FT_DIR/.relay/tasks/20261030-fast/SPEC.md"; then
  echo "  ✅ PASS: Fast Track เขียน backtick และ \$() ลง SPEC.md ตามตัวอักษรโดยไม่รันคำสั่ง"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ❌ FAIL: Fast Track ตีความ backtick หรือ \$() เป็นคำสั่ง"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo "=== [3/8] SEC-3: Safe JSON/TOML Update & Model ID Sanitizer ใน set_cli_default_model ==="
SEC3_HOME="$TMP_ROOT/sec3_home"
mkdir -p "$SEC3_HOME/.claude" "$SEC3_HOME/.codex"
printf '{\n  "theme": "dark",\n  "model": "claude-sonnet-4-5"\n}\n' > "$SEC3_HOME/.claude/settings.json"
printf 'model = "gpt-5"\napproval_policy = "on-request"\n' > "$SEC3_HOME/.codex/config.toml"

(
  export HOME="$SEC3_HOME"
  source "$RELAY_SH"
  set_cli_default_model "claude" "claude-opus-4-6"
  set_cli_default_model "codex" "gpt-5.4/mini"
  # ทดสอบส่งค่าที่มีอักขระอันตราย ต้องถูกตัดทิ้งและเขียนเป็น JSON/TOML ที่ถูกต้อง
  set_cli_default_model "claude" 'claude-sonnet-4-6";rm -rf /'
)

CLAUDE_MODEL_NOW="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["model"])' "$SEC3_HOME/.claude/settings.json")"
assert_eq "$CLAUDE_MODEL_NOW" "claude-sonnet-4-6rm-rf/" "sanitize_model_id ล้างอักขระพิเศษและรักษาโครงสร้าง JSON ของ ~/.claude/settings.json ให้ถูกต้องเสมอ"
assert_contains "$(cat "$SEC3_HOME/.codex/config.toml")" 'model = "gpt-5.4/mini"' "อัปเดต ~/.codex/config.toml รองรับชื่อโมเดลที่มีเครื่องหมาย / โดยไม่พัง"

echo "=== [4/8] REL-1: Atomic File Writes & Quota Lockfile ==="
REL1_DIR="$TMP_ROOT/rel1"
mkdir -p "$REL1_DIR/.relay"
(
  export HOME="$REL1_DIR"
  source "$RELAY_SH"
  PROJECT_DIR="$REL1_DIR"
  RELAY_DIR="$REL1_DIR/.relay"
  PROJECT_ROLES_CONF="$RELAY_DIR/roles.conf"
  save_role_config "$PROJECT_ROLES_CONF"
  upsert_custom_agent "$RELAY_DIR/custom-agents.json" "db-audit" "DB Auditor" "claude" "claude-sonnet-4-6" "project" "" "ตรวจ schema"
)
LEFT_TMP="$(find "$REL1_DIR" -name '*.tmp.*' | wc -l | tr -d ' ')"
assert_eq "$LEFT_TMP" "0" "เขียนไฟล์ roles.conf และ custom-agents.json แบบ Atomic โดยไม่ทิ้งไฟล์ .tmp ค้าง"

echo "=== [5/8] REL-2: Auto-Prune Stale Git Worktree ใน prepare_task_worktree ==="
REL2_DIR="$TMP_ROOT/rel2"
mkdir -p "$REL2_DIR"
git -C "$REL2_DIR" init -q -b main
git -C "$REL2_DIR" config user.email "test@example.com"
git -C "$REL2_DIR" config user.name "Relay Test"
echo "hello" > "$REL2_DIR/app.txt"
git -C "$REL2_DIR" add app.txt
git -C "$REL2_DIR" commit -q -m "init"

(
  cd "$REL2_DIR"
  source "$RELAY_SH"
  PROJECT_DIR="$REL2_DIR"
  RELAY_DIR="$REL2_DIR/.relay"
  ACTIVE_TASK="20261030-stale-wt"
  mkdir -p "$RELAY_DIR/tasks/$ACTIVE_TASK"
  prepare_task_worktree >/dev/null
  # จำลองผู้ใช้สั่ง rm -rf โฟลเดอร์ worktree ทิ้งโดยไม่ได้ git worktree remove
  rm -rf "$RELAY_DIR/worktrees/$ACTIVE_TASK"
  # เรียก prepare_task_worktree ซ้ำ ต้อง prune อัตโนมัติและสร้างใหม่สำเร็จ
  prepare_task_worktree >/dev/null
)
if [ -d "$REL2_DIR/.relay/worktrees/20261030-stale-wt" ]; then
  echo "  ✅ PASS: prepare_task_worktree ล้างทะเบียน Worktree ค้างและสร้างใหม่สำเร็จหลังโฟลเดอร์ถูกลบ"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ❌ FAIL: prepare_task_worktree ล้มเหลวเมื่อโฟลเดอร์ Worktree ถูกลบด้วยมือ"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo "=== [6/8] REL-3: Secret & Database File Guard ในขั้นตอนที่ 5 (worktree_forbidden_files) ==="
WT_PATH="$REL2_DIR/.relay/worktrees/20261030-stale-wt"
touch "$WT_PATH/.env" "$WT_PATH/.env.production" "$WT_PATH/.env.example" "$WT_PATH/private.key" "$WT_PATH/local.sqlite" "$WT_PATH/safe.js"
FORBIDDEN_LIST="$(
  cd "$REL2_DIR"
  source "$RELAY_SH"
  PROJECT_DIR="$REL2_DIR"
  worktree_forbidden_files "$WT_PATH" "main" "feat/20261030-stale-wt"
)"
assert_contains "$FORBIDDEN_LIST" ".env" "ตรวจพบไฟล์ .env ใน Worktree"
assert_contains "$FORBIDDEN_LIST" ".env.production" "ตรวจพบไฟล์ .env.production ใน Worktree"
assert_contains "$FORBIDDEN_LIST" "private.key" "ตรวจพบไฟล์ *.key ใน Worktree"
assert_contains "$FORBIDDEN_LIST" "local.sqlite" "ตรวจพบไฟล์ *.sqlite ใน Worktree"
if printf "%s" "$FORBIDDEN_LIST" | grep -qF ".env.example"; then
  echo "  ❌ FAIL: ไม่ควรบล็อกไฟล์ตัวอย่าง .env.example"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  ✅ PASS: อนุญาตไฟล์ตัวอย่าง .env.example ได้ตามปกติ"
  PASS_COUNT=$((PASS_COUNT + 1))
fi

echo "=== [7/8] REL-4: Child Process Tree Termination ใน run_with_timeout ==="
CHILD_PID_FILE="$TMP_ROOT/child.pid"
(
  source "$RELAY_SH"
  rc=0
  run_with_timeout 1 bash -c 'sleep 30 & echo $! > "'"$CHILD_PID_FILE"'"; wait' || rc=$?
  exit "$rc"
) || TIMEOUT_RC=$?
assert_eq "${TIMEOUT_RC:-0}" "124" "run_with_timeout คืนค่า 124 เมื่อหมดเวลา"
sleep 0.3
CHILD_PID="$(cat "$CHILD_PID_FILE" 2>/dev/null || echo "")"
if [ -n "$CHILD_PID" ] && ! kill -0 "$CHILD_PID" 2>/dev/null; then
  echo "  ✅ PASS: โปรเซสลูก (child process) ถูกส่งสัญญาณหยุดพร้อมโปรเซสแม่เมื่อหมดเวลา"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  [ -n "$CHILD_PID" ] && kill -9 "$CHILD_PID" 2>/dev/null || true
  echo "  ❌ FAIL: โปรเซสลูกยังคงค้างอยู่หลังหมดเวลา (PID=$CHILD_PID)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo "=== [8/8] REL-5: ป้องกันรหัสงานซ้ำในวันเดียวกัน (create_new_task deduplication) ==="
REL5_DIR="$TMP_ROOT/rel5"
mkdir -p "$REL5_DIR/.relay/tasks" "$REL5_DIR/.relay/archive"
DUP_OUT="$(
  cd "$REL5_DIR"
  source "$RELAY_SH"
  PROJECT_DIR="$REL5_DIR"
  RELAY_DIR="$REL5_DIR/.relay"
  create_new_task "auth-flow" >/dev/null
  t1="$ACTIVE_TASK"
  # ย้ายใบแรกเข้า archive แล้วสร้างชื่อซ้ำในวันเดียวกัน
  mv "$RELAY_DIR/tasks/$t1" "$RELAY_DIR/archive/$t1"
  create_new_task "auth-flow" >/dev/null
  t2="$ACTIVE_TASK"
  create_new_task "auth-flow" >/dev/null
  t3="$ACTIVE_TASK"
  printf "%s|%s|%s" "$t1" "$t2" "$t3"
)"
TODAY_STR="$(date +%Y%m%d)"
assert_eq "$DUP_OUT" "${TODAY_STR}-auth-flow|${TODAY_STR}-auth-flow-2|${TODAY_STR}-auth-flow-3" "ต่อท้าย -2, -3 อัตโนมัติเมื่อชื่อซ้ำกับใน tasks/ หรือ archive/"

echo ""
echo "=================================================================="
echo "สรุปผลชุดทดสอบ Security & Hardening: ผ่าน ${PASS_COUNT} รายการ, ล้มเหลว ${FAIL_COUNT} รายการ"
echo "=================================================================="
[ "$FAIL_COUNT" -eq 0 ]
