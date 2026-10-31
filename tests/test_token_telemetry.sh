#!/usr/bin/env bash
# ชุดทดสอบอัตโนมัติสำหรับระบบวัด Token จริง (agy, codex, claude), รายงาน relay stats, และโหมดด่วน Fast Track
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELAY_SH="$SCRIPT_DIR/relay.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "  ✅ $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  ❌ $1"; }

TMP_ROOT="$(mktemp -d -t relay-test-tokens.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# โหลดเฉพาะส่วนฟังก์ชันของ relay.sh โดยไม่รัน main loop
FN_FILE="$TMP_ROOT/relay_funcs.sh"
sed '/^# ─── 14\. รองรับ Subcommands/,$d' "$RELAY_SH" > "$FN_FILE"

export HOME="$TMP_ROOT/home"
export GLOBAL_DIR="$HOME/.agents"
mkdir -p "$GLOBAL_DIR/bin" "$HOME"

# สร้าง mock CLIs
for cli in agy codex claude; do
  cat <<'EOF' > "$GLOBAL_DIR/bin/$cli"
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$GLOBAL_DIR/bin/$cli"
done
export PATH="$GLOBAL_DIR/bin:$PATH"

# shellcheck disable=SC1090
source "$FN_FILE"

echo "== AC-1: ทดสอบการดึง Token จริงจาก Session Logs ของ agy, codex, claude =="

NOW_EP="$(date +%s)"
START_EP=$((NOW_EP - 30))
END_EP=$((NOW_EP + 5))
ISO_IN="$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp($NOW_EP, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
ISO_BEFORE="$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp($((START_EP - 60)), datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")"

# 1.1 ทดสอบ agy transcript.jsonl
export RELAY_AGY_BRAIN_DIR="$TMP_ROOT/agy_brain"
mkdir -p "$RELAY_AGY_BRAIN_DIR/conv-1/.system_generated/logs"
cat <<EOF > "$RELAY_AGY_BRAIN_DIR/conv-1/.system_generated/logs/transcript.jsonl"
{"step_index":0,"type":"PLANNER_RESPONSE","created_at":"$ISO_BEFORE","input_tokens":9999,"cache_read_tokens":1000,"output_tokens":500}
{"step_index":1,"type":"PLANNER_RESPONSE","created_at":"$ISO_IN","input_tokens":10000,"cache_read_tokens":5000,"output_tokens":400}
{"step_index":2,"type":"PLANNER_RESPONSE","created_at":"$ISO_IN","input_tokens":2000,"cache_read_tokens":1000,"output_tokens":100}
EOF

AGY_TOK="$(extract_step_token_usage "agy" "$START_EP" "$END_EP")"
if [ "$AGY_TOK" = "18500|18000|6000|500|2" ]; then
  pass "agy: ดึงและรวม input + cache_read + output เฉพาะในช่วงเวลาได้อย่างแม่นยำ ($AGY_TOK)"
else
  fail "agy: ค่าไม่ตรง (ได้ $AGY_TOK, คาดหวัง 18500|18000|6000|500|2)"
fi

# 1.2 ทดสอบ codex rollout-*.jsonl (หักลบ baseline ก่อนเริ่ม + ไม่นับซ้ำเมื่อมีบรรทัดซ้ำ)
export RELAY_CODEX_SESSIONS_DIR="$TMP_ROOT/codex_sessions"
mkdir -p "$RELAY_CODEX_SESSIONS_DIR/2026/10/30"
cat <<EOF > "$RELAY_CODEX_SESSIONS_DIR/2026/10/30/rollout-test.jsonl"
{"timestamp":"$ISO_BEFORE","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10000,"cached_input_tokens":8000,"output_tokens":500,"total_tokens":10500}}}}
{"timestamp":"$ISO_IN","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":25000,"cached_input_tokens":20000,"output_tokens":1200,"total_tokens":26200}}}}
{"timestamp":"$ISO_IN","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":25000,"cached_input_tokens":20000,"output_tokens":1200,"total_tokens":26200}}}}
{"timestamp":"$ISO_IN","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":30000,"cached_input_tokens":24000,"output_tokens":1500,"total_tokens":31500}}}}
EOF

CODEX_TOK="$(extract_step_token_usage "codex" "$START_EP" "$END_EP")"
if [ "$CODEX_TOK" = "21000|20000|16000|1000|2" ]; then
  pass "codex: คำนวณส่วนต่างจาก total_token_usage และไม่นับซ้ำบรรทัดเดิม ($CODEX_TOK)"
else
  fail "codex: ค่าไม่ตรง (ได้ $CODEX_TOK, คาดหวัง 21000|20000|16000|1000|2)"
fi

# 1.3 ทดสอบ claude projects/*.jsonl (กรองซ้ำด้วย requestId เมื่อมีหลาย streaming block)
export RELAY_CLAUDE_PROJECTS_DIR="$TMP_ROOT/claude_projects"
mkdir -p "$RELAY_CLAUDE_PROJECTS_DIR/proj-a"
cat <<EOF > "$RELAY_CLAUDE_PROJECTS_DIR/proj-a/session-1.jsonl"
{"timestamp":"$ISO_IN","requestId":"req_1","message":{"id":"msg_1","usage":{"input_tokens":100,"cache_creation_input_tokens":900,"cache_read_input_tokens":4000,"output_tokens":50}}}
{"timestamp":"$ISO_IN","requestId":"req_1","message":{"id":"msg_1","usage":{"input_tokens":100,"cache_creation_input_tokens":900,"cache_read_input_tokens":4000,"output_tokens":200}}}
{"timestamp":"$ISO_IN","requestId":"req_2","message":{"id":"msg_2","usage":{"input_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":4950,"output_tokens":300}}}
EOF

CLAUDE_TOK="$(extract_step_token_usage "claude" "$START_EP" "$END_EP")"
if [ "$CLAUDE_TOK" = "10500|10000|8950|500|2" ]; then
  pass "claude: กรองซ้ำตาม requestId และรวม input + cache + output ถูกต้อง ($CLAUDE_TOK)"
else
  fail "claude: ค่าไม่ตรง (ได้ $CLAUDE_TOK, คาดหวัง 10500|10000|8950|500|2)"
fi

echo "== AC-2: ทดสอบการบันทึก RUN_LOG.jsonl, Step Telemetry Box และรายงาน relay stats =="
PROJECT_DIR="$TMP_ROOT/proj"
mkdir -p "$PROJECT_DIR/.relay/tasks/20261030-demo"
RELAY_DIR="$PROJECT_DIR/.relay"
ACTIVE_TASK="20261030-demo"

append_run_log "interactive" "ขั้นตอนที่ 1: @po" "agy" "gemini-4-argon-high" "0" "$START_EP" "$END_EP" "90|50" "89|50" "$AGY_TOK"
append_run_log "auto" "ขั้นตอนที่ 4: @qa" "codex" "gpt-6.1-terra" "0" "$START_EP" "$END_EP" "80|60" "78|60" "$CODEX_TOK"

BOX_OUT="$(print_step_telemetry_box "ขั้นตอนที่ 1: @po" "agy" "gemini-4-argon-high" "0" "$START_EP" "$END_EP" "90|50" "89|50" "$AGY_TOK")"
if echo "$BOX_OUT" | grep -q "18,500 tokens" && echo "$BOX_OUT" | grep -q "90% ➔ 89% (-1%)"; then
  pass "print_step_telemetry_box แสดงจำนวน Token จริงและโควต้าที่ลดลงชัดเจน"
else
  fail "print_step_telemetry_box แสดงผลไม่ครบ: $BOX_OUT"
fi

INLINE_OUT="$(get_task_telemetry_summary_inline "$ACTIVE_TASK")"
if echo "$INLINE_OUT" | grep -q "39,500 tokens" && echo "$INLINE_OUT" | grep -q "2 ขั้น"; then
  pass "get_task_telemetry_summary_inline รวมยอด Token สะสมของใบงานถูกต้อง (39,500 tokens)"
else
  fail "get_task_telemetry_summary_inline ค่าไม่ตรง: $INLINE_OUT"
fi

REPORT_OUT="$(print_task_telemetry_report "$ACTIVE_TASK")"
if echo "$REPORT_OUT" | grep -q "agy/gemini-4-argon-high" && echo "$REPORT_OUT" | grep -q "codex/gpt-6.1-terra" && echo "$REPORT_OUT" | grep -q "39,500 tokens"; then
  pass "print_task_telemetry_report แสดงตารางแยกตามขั้นตอนและแยกตามค่าย/โมเดลครบถ้วน"
else
  fail "print_task_telemetry_report แสดงผลไม่ครบ: $REPORT_OUT"
fi

echo "== AC-3: ทดสอบโหมดด่วน Fast Track (run_fast_track_dev) =="
FT_PROJ="$TMP_ROOT/ft_proj"
mkdir -p "$FT_PROJ"
git -C "$FT_PROJ" init -b main >/dev/null 2>&1
git -C "$FT_PROJ" config user.email "test@example.com"
git -C "$FT_PROJ" config user.name "Tester"
echo "v1" > "$FT_PROJ/app.txt"
git -C "$FT_PROJ" add app.txt
git -C "$FT_PROJ" commit -m "initial" >/dev/null 2>&1

PROJECT_DIR="$FT_PROJ"
PROJECT_NAME="ft_proj"
RELAY_DIR="$FT_PROJ/.relay"
CURRENT_TASK=""
ACTIVE_TASK=""
ROLE_PO="agy";   MODEL_PO="gemini-4-argon-high"
ROLE_ARCH="agy"; MODEL_ARCH="claude-opus-5-5-high"
ROLE_DEV="agy";  MODEL_DEV="claude-sonnet-5-5-high"
ROLE_QA="codex"; MODEL_QA="gpt-6.1-terra"

# จำลองให้ทั้งหมดพร้อมใช้งานและ mock CLI ของ @dev แก้ไฟล์ใน Worktree
require_all_roles_ready() { return 0; }
export RELAY_MOCK_TOKENS="4200|3800|2000|400|1"
cat <<'EOF' > "$GLOBAL_DIR/bin/agy"
#!/usr/bin/env bash
echo "v2-fast-track" > app.txt
git add app.txt
git commit -m "feat: fast track change" >/dev/null 2>&1 || true
task_dir="$(ls -d .relay/tasks/* 2>/dev/null | head -n 1)"
if [ -n "$task_dir" ]; then
  echo '{"verdict":"PASS","failed_criteria":[],"tests_run":["fast-track"],"summary":"ok"}' > "$task_dir/QA_VERDICT.json"
fi
exit 0
EOF
chmod +x "$GLOBAL_DIR/bin/agy"

run_fast_track_dev "fix-login-button" >/dev/null

if [ -n "$ACTIVE_TASK" ] && [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ] && [ -d "$RELAY_DIR/worktrees/$ACTIVE_TASK" ]; then
  pass "Fast Track สร้างใบงาน SPEC.md ย่อ และแยก Git Worktree อัตโนมัติโดยไม่ต้องผ่าน @po/@arch"
else
  fail "Fast Track ไม่ได้สร้างใบงานหรือ Worktree"
fi

if [ "$(qa_verdict "$RELAY_DIR/tasks/$ACTIVE_TASK")" = "PASS|self" ] && grep -q '"total": 4200' "$RELAY_DIR/tasks/$ACTIVE_TASK/RUN_LOG.jsonl"; then
  pass "Fast Track ซิงก์ QA_VERDICT.json (ระบุเป็น PASS|self — @dev ตรวจเอง) และบันทึก Token (4,200 tokens) ลง RUN_LOG.jsonl"
else
  fail "Fast Track ไม่ได้ซิงก์ QA_VERDICT.json หรือ RUN_LOG.jsonl"
fi

echo ""
echo "ผลรวม: ผ่าน $PASS_COUNT • ไม่ผ่าน $FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
