#!/usr/bin/env bash
# ชุดทดสอบระบบ Smart Quota Failover, 1-Click Switcher และ 0-Token Worktree Handoff (AC-1 ถึง AC-4)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELAY_SRC="$REPO_DIR/relay.sh"

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf "  ✅ %s\n" "$1"; }
bad() { fail=$((fail + 1)); printf "  ❌ %s\n" "$1"; }

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/relay-failover-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

setup_env() {
  rm -rf "$TMP_ROOT"/*
  export HOME="$TMP_ROOT/home"
  mkdir -p "$HOME/.agents/bin" "$HOME/.gemini/bin" "$HOME/.gemini/antigravity" "$HOME/.codex" "$HOME/.claude" "$TMP_ROOT/bin"
  cp "$RELAY_SRC" "$HOME/.agents/bin/relay"
  chmod +x "$HOME/.agents/bin/relay"
  FUNC_FILE="$TMP_ROOT/relay_funcs.sh"
  sed '/^# ─── 14\. รองรับ Subcommands/,$d' "$RELAY_SRC" > "$FUNC_FILE"

  # ปลอมสถานะ Login ครบทั้ง 3 ค่าย (agy, codex, claude)
  echo "token" > "$HOME/.gemini/jetski-standalone-oauth-token"
  printf 'model = "gpt-6.1-terra"\n' > "$HOME/.codex/config.toml"
  echo '{"auth":true}' > "$HOME/.codex/auth.json"

  cat <<'EOF' > "$HOME/.agents/relay-roles.conf"
ROLE_PO="agy"
MODEL_PO="gemini-4-argon-high"
ROLE_ARCH="agy"
MODEL_ARCH="claude-opus-5-5-high"
ROLE_DEV="agy"
MODEL_DEV="claude-sonnet-5-5-high"
ROLE_QA="codex"
MODEL_QA="gpt-6.1-terra"
EOF

  # สร้างไบนารีจำลองสำหรับ agy, codex, claude
  cat <<'EOF' > "$TMP_ROOT/bin/fake-cli"
#!/usr/bin/env bash
CLI_NAME="$(basename "$0")"
PROMPT="${*: -1}"

if [ "${1:-}" = "auth" ] && [ "${2:-}" = "status" ]; then
  echo '{"loggedIn": true, "authMethod": "oauth"}'
  exit 0
fi
if [ "${1:-}" = "login" ]; then
  echo "Logged in using ChatGPT"
  exit 0
fi

# ตอบกลับสำหรับ /usage ของ agy
if [[ "$*" == *"/usage"* ]]; then
  cat <<USAGE
Gemini Models                   Five Hour Limit Remaining   ${MOCK_AGY_GEM_5H:-92}%  2099-12-31T23:59:00Z
Gemini Models                   Weekly Limit Remaining      ${MOCK_AGY_GEM_7D:-90}%  2099-12-31T23:59:00Z
Claude and GPT models           Five Hour Limit Remaining   ${MOCK_AGY_CL_5H:-12}%   2099-12-31T23:59:00Z
Claude and GPT models           Weekly Limit Remaining      ${MOCK_AGY_CL_7D:-80}%   2099-12-31T23:59:00Z
USAGE
  exit 0
fi

# ตอบกลับสำหรับ get_usage ของ claude
if [[ "$*" == *"stream-json"* ]]; then
  echo "{\"type\":\"control_response\",\"response\":{\"response\":{\"subscription_type\":\"pro\",\"rate_limits\":{\"five_hour\":{\"utilization\":$((100 - ${MOCK_CLAUDE_5H:-64}))},\"seven_day\":{\"utilization\":$((100 - ${MOCK_CLAUDE_7D:-70}))}}}}}"
  exit 0
fi

TASK_DIR="$(ls -d .relay/tasks/* 2>/dev/null | head -n 1 || true)"

if [[ "$PROMPT" == *"@arch"* ]]; then
  echo "# ARCH" > "$TASK_DIR/ARCH.md"
  echo "# PLAN" > "$TASK_DIR/PLAN.md"
  exit 0
fi

if [[ "$PROMPT" == *"@dev"* ]]; then
  echo "${CLI_NAME}|${PROMPT}" >> "$HOME/dev_invocations.log"
  if [ "${SIMULATE_MID_STEP_FAIL_ON_CODEX:-0}" = "1" ] && [ "$CLI_NAME" = "codex" ]; then
    echo "partial work from codex before quota exhausted" > partial_feature.txt
    exit 1
  fi
  echo "completed by $CLI_NAME" > feature_done.txt
  git add -A -- . ':(exclude).relay' >/dev/null 2>&1 || true
  git commit -m "feat: completed by $CLI_NAME" >/dev/null 2>&1 || true
  exit 0
fi

if [[ "$PROMPT" == *"@qa"* ]]; then
  echo "VERDICT: PASS" > "$TASK_DIR/QA_REPORT.md"
  cat <<JSON > "$TASK_DIR/QA_VERDICT.json"
{"verdict": "PASS", "failed_criteria": [], "tests_run": ["unit"], "summary": "ok"}
JSON
  exit 0
fi
exit 0
EOF
  chmod +x "$TMP_ROOT/bin/fake-cli"
  ln -sf "$TMP_ROOT/bin/fake-cli" "$HOME/.gemini/bin/agy"
  ln -sf "$TMP_ROOT/bin/fake-cli" "$TMP_ROOT/bin/agy"
  ln -sf "$TMP_ROOT/bin/fake-cli" "$TMP_ROOT/bin/codex"
  ln -sf "$TMP_ROOT/bin/fake-cli" "$TMP_ROOT/bin/claude"
  export PATH="$TMP_ROOT/bin:$HOME/.gemini/bin:$PATH"

  # เขียนแคชโควต้าจำลอง:
  # - agy Gemini: 92% / 90% (min 90%)
  # - codex: 85% / 88% (min 85%)
  # - claude: 64% / 70% (min 64%)
  # - agy Claude/GPT: 12% / 80% (min 12% -> ต่ำกว่าเกณฑ์ 20%)
  local future=$(( $(date +%s) + 7200 ))
  cat <<EOF > "$HOME/.agents/relay-quota.cache"
QUOTA_UPDATED_EPOCH="$(date +%s)"
QUOTA_UPDATED_AT="12:00:00"
AGY_GEMINI_5H_REM="92"
AGY_GEMINI_7D_REM="90"
AGY_GEMINI_5H_RESET_EPOCH="$future"
AGY_GEMINI_7D_RESET_EPOCH="$future"
AGY_CLAUDE_5H_REM="12"
AGY_CLAUDE_7D_REM="80"
AGY_CLAUDE_5H_RESET_EPOCH="$future"
AGY_CLAUDE_7D_RESET_EPOCH="$future"
CODEX_PLAN="Plus"
CODEX_5H_REM="85"
CODEX_7D_REM="88"
CODEX_5H_RESET_EPOCH="$future"
CODEX_7D_RESET_EPOCH="$future"
CLAUDE_PLAN="Pro"
CLAUDE_5H_REM="64"
CLAUDE_7D_REM="70"
CLAUDE_5H_RESET_EPOCH="$future"
CLAUDE_7D_RESET_EPOCH="$future"
AGY_FETCH_OK="1"
CODEX_FETCH_OK="1"
CLAUDE_FETCH_OK="1"
EOF

  # เตรียมโปรเจกต์จำลอง
  PROJ="$TMP_ROOT/proj"
  mkdir -p "$PROJ/.relay/tasks/20261030-demo"
  git -C "$PROJ" init -b main >/dev/null 2>&1
  git -C "$PROJ" config user.email "test@example.com"
  git -C "$PROJ" config user.name "Test"
  echo "# Demo" > "$PROJ/README.md"
  echo "# State" > "$PROJ/.relay/PROJECT_STATE.md"
  echo "# Spec" > "$PROJ/.relay/tasks/20261030-demo/SPEC.md"
  echo "# Plan" > "$PROJ/.relay/tasks/20261030-demo/PLAN.md"
  git -C "$PROJ" add README.md
  git -C "$PROJ" commit -m "init" >/dev/null 2>&1
}

echo "== AC-1: ทดสอบ 0-Token Worktree Handoff Context (get_worktree_handoff_context_note) =="
setup_env
WT="$PROJ/.relay/worktrees/20261030-demo"
git -C "$PROJ" worktree add -b feat/20261030-demo "$WT" main >/dev/null 2>&1

clean_note="$(bash -c "source '$FUNC_FILE'; get_worktree_handoff_context_note '$WT'")"
[ -z "$clean_note" ] && ok "Worktree สะอาด ➔ ไม่แนบข้อความส่วนเกิน (0 Token)" || bad "Worktree สะอาดแต่มีข้อความ: $clean_note"

echo "step 1" > "$WT/step1.txt"
git -C "$WT" add step1.txt
git -C "$WT" commit -m "feat: add step1" >/dev/null 2>&1
echo "unfinished code" > "$WT/src_auth.ts"
mkdir -p "$WT/.relay/tasks/20261030-demo"
echo "ignore relay doc" > "$WT/.relay/tasks/20261030-demo/ARCH.md"

dirty_note="$(bash -c "source '$FUNC_FILE'; get_worktree_handoff_context_note '$WT'")"
echo "$dirty_note" | grep -q "add step1" && ok "ระบุ commit ก่อนหน้าในกิ่งนี้ได้ถูกต้อง" || bad "ไม่พบ commit ก่อนหน้าใน handoff note: $dirty_note"
echo "$dirty_note" | grep -q "src_auth.ts" && ok "ระบุชื่อไฟล์ที่ทำค้างไว้ (src_auth.ts) ได้ถูกต้อง" || bad "ไม่พบไฟล์ที่ทำค้างใน handoff note: $dirty_note"
! echo "$dirty_note" | grep -q "ARCH.md" && ok "ไม่นำไฟล์ใน .relay/ มาปะปนในรายการไฟล์โค้ดที่ค้าง" || bad "มีไฟล์ .relay/ ปะปนใน handoff note"

echo "== AC-2: ทดสอบการจัดอันดับกระเป๋าโควต้าทางเลือก (list_quota_failover_candidates) =="
setup_env
cands="$(cd "$PROJ" && bash -c "
  export HOME='$HOME'
  source '$FUNC_FILE'
  check_all_roles_ready
  list_quota_failover_candidates 'agy' 'claude-sonnet-5-5-high' 'dev'
")"
first_cand="$(printf "%s\n" "$cands" | sed -n '1p')"
second_cand="$(printf "%s\n" "$cands" | sed -n '2p')"
third_cand="$(printf "%s\n" "$cands" | sed -n '3p')"

[[ "$first_cand" == "agy|gemini-4-argon-high|90|"* ]] && ok "อันดับ 1 คือกระเป๋า agy Gemini (โควต้าต่ำสุด 90%)" || bad "อันดับ 1 ไม่ถูกต้อง: $first_cand"
[[ "$second_cand" == "codex|gpt-6.1-terra|85|"* ]] && ok "อันดับ 2 คือกระเป๋า codex (โควต้าต่ำสุด 85%)" || bad "อันดับ 2 ไม่ถูกต้อง: $second_cand"
[[ "$third_cand" == "claude|sonnet|64|"* ]] && ok "อันดับ 3 คือกระเป๋า claude (โควต้าต่ำสุด 64%)" || bad "อันดับ 3 ไม่ถูกต้อง: $third_cand"

echo "== AC-3: ทดสอบการสลับกระเป๋าโควต้าอัตโนมัติ (Auto-Failover) และเมนูสลับในคลิกเดียวเมื่อโควต้า < 20% =="
setup_env
( cd "$PROJ" && "$HOME/.agents/bin/relay" loop --yes --auto-failover < /dev/null > "$TMP_ROOT/auto_out.txt" 2>&1 )
grep -q "Smart Auto-Failover" "$TMP_ROOT/auto_out.txt" && ok "แสดงแจ้งเตือน Smart Auto-Failover เมื่อโควต้า @dev (12%) < 20%" || bad "ไม่แสดง Smart Auto-Failover"
grep -q "\[FAILOVER\].*agy/claude-sonnet-5-5-high.*agy/gemini-4-argon-high" "$PROJ/.relay/tasks/20261030-demo/LOOP_LOG.md" && ok "บันทึกการสลับไปใช้ agy/gemini-4-argon-high ลงใน LOOP_LOG.md" || bad "ไม่พบบันทึก FAILOVER ใน LOOP_LOG.md"
grep -q 'MODEL_DEV="gemini-4-argon-high"' "$HOME/.agents/relay-roles.conf" && ok "อัปเดต MODEL_DEV เป็น gemini-4-argon-high ลงไฟล์ตั้งค่าอัตโนมัติ" || bad "ไม่อัปเดตไฟล์ตั้งค่า"
grep -q "\[PASS\]" "$PROJ/.relay/tasks/20261030-demo/LOOP_LOG.md" && ok "รันลูปต่อจนผ่านการตรวจรับ (PASS) โดยไม่สะดุดหยุด" || bad "ลูปไม่ผ่าน PASS หลัง Auto-Failover"

# ทดสอบเมนู Interactive 1-Click Switcher (เลือก [1] และเลือก [f] ฝืนรันต่อ)
setup_env
switch_res="$(cd "$PROJ" && printf "1\n" | RELAY_FORCE_QUOTA_PROMPT=1 bash -c "
  export HOME='$HOME'
  source '$FUNC_FILE'
  check_all_roles_ready
  check_role_quota_safe 'agy' 'claude-sonnet-5-5-high' 'ขั้นตอนที่ 3: @dev' 20 'dev' >/dev/null
  echo \"\$ROLE_DEV|\$MODEL_DEV\"
")"
[ "$switch_res" = "agy|gemini-4-argon-high" ] && ok "กด [1] ในเมนูเตือนโควต้า ➔ สลับไปใช้กระเป๋าอันดับ 1 ทันที" || bad "กด [1] แล้วไม่สลับโมเดล: $switch_res"

setup_env
override_rc=0
( cd "$PROJ" && printf "f\n" | RELAY_FORCE_QUOTA_PROMPT=1 bash -c "
  export HOME='$HOME'
  source '$FUNC_FILE'
  check_all_roles_ready
  check_role_quota_safe 'agy' 'claude-sonnet-5-5-high' 'ขั้นตอนที่ 3: @dev' 20 'dev' >/dev/null
" ) || override_rc=$?
[ "$override_rc" -eq 0 ] && ok "กด [f] ในเมนูเตือนโควต้า ➔ อนุญาตให้ฝืนรันต่อด้วยโมเดลเดิมได้" || bad "กด [f] แล้วไม่อนุญาตให้รันต่อ (rc=$override_rc)"

echo "== AC-4: ทดสอบการกู้คืนงานเมื่อโควต้าหมดกลางคัน (Mid-Step Failover + Worktree Handoff) =="
setup_env
# ตั้งค่าเริ่มต้นให้ @dev ใช้ codex (โควต้าก่อนเริ่ม 85%) แต่จำลองให้ codex ล้มเหลวกลางคันหลังจากสร้างไฟล์ partial_feature.txt
sed -i.bak 's/ROLE_DEV="agy"/ROLE_DEV="codex"/; s/MODEL_DEV="claude-sonnet-5-5-high"/MODEL_DEV="gpt-6.1-terra"/' "$HOME/.agents/relay-roles.conf"
rm -f "$HOME/.agents/relay-roles.conf.bak"
( cd "$PROJ" && SIMULATE_MID_STEP_FAIL_ON_CODEX=1 MOCK_AGY_CL_5H=12 "$HOME/.agents/bin/relay" loop --yes --auto-failover < /dev/null > "$TMP_ROOT/mid_out.txt" 2>&1 )

grep -q "Mid-Step Failover Guard" "$TMP_ROOT/mid_out.txt" && ok "ตรวจจับการจบด้วย error กลางคันของ @dev (codex) ได้ถูกต้อง" || bad "ไม่แสดง Mid-Step Failover Guard"
grep -q "partial_feature.txt" "$HOME/dev_invocations.log" && ok "ส่งต่อชื่อไฟล์ที่ทำค้างไว้ (partial_feature.txt) ให้ AI ตัวใหม่ (@dev agy) รับไม้ต่ออัตโนมัติ" || bad "ไม่พบ partial_feature.txt ใน Prompt ของ AI ตัวที่รับไม้ต่อ"
[ -f "$PROJ/.relay/worktrees/20261030-demo/feature_done.txt" ] && ok "AI ตัวใหม่ทำงานต่อใน Git Worktree เดิมจนเสร็จสมบูรณ์" || bad "ไม่พบไฟล์ผลงานจาก AI ตัวใหม่ใน Worktree"
grep -q "\[PASS\]" "$PROJ/.relay/tasks/20261030-demo/LOOP_LOG.md" && ok "ลูปทำงานต่อจนผ่าน QA (VERDICT: PASS) สำเร็จ" || bad "ลูปไม่ผ่าน PASS หลัง Mid-Step Failover"

echo ""
echo "ผลรวมชุดทดสอบ Smart Quota Failover & Worktree Handoff: ผ่าน $pass • ไม่ผ่าน $fail"
[ "$fail" -eq 0 ]
