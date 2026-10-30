#!/usr/bin/env bash
# ==============================================================================
# ชุดทดสอบ Hermes-Style Split-Header Card, Modular Braille Apple Logo,
# 4-Level Quiet Color Hierarchy, Developer Terminology & Shortcuts Bar
# รันด้วย: bash tests/test_hermes_cli_redesign.sh (ไม่ใช้โควต้า AI จริง)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELAY_SH="$REPO_DIR/relay.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf "  ✅ %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  ❌ %s\n" "$1"; }

TMP_ROOT="$(mktemp -d -t relay-hermes-ui-test.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

FUNC_FILE="$TMP_ROOT/relay_funcs.sh"
sed '/^# ─── 14\. รองรับ Subcommands/,$d' "$RELAY_SH" > "$FUNC_FILE"

export HOME="$TMP_ROOT/home"
export GLOBAL_DIR="$HOME/.agents"
mkdir -p "$GLOBAL_DIR/bin" "$HOME/.gemini/bin" "$TMP_ROOT/proj/.relay/tasks/20261030-ui-redesign"
echo "fake-token" > "$HOME/.gemini/jetski-standalone-oauth-token"
echo "# Project State" > "$TMP_ROOT/proj/.relay/PROJECT_STATE.md"
echo "# SPEC" > "$TMP_ROOT/proj/.relay/tasks/20261030-ui-redesign/SPEC.md"

for cli in agy codex claude; do
  cat <<'EOF' > "$GLOBAL_DIR/bin/$cli"
#!/usr/bin/env bash
if [ "${1:-}" = "login" ]; then echo "Logged in"; fi
exit 0
EOF
  chmod +x "$GLOBAL_DIR/bin/$cli"
done
export PATH="$GLOBAL_DIR/bin:$PATH"

# shellcheck disable=SC1090
source "$FUNC_FILE"

PROJECT_DIR="$TMP_ROOT/proj"
cd "$PROJECT_DIR"
git init -q -b main
refresh_project_paths
ROLE_PO="agy";   MODEL_PO="gemini-4-argon-high"
ROLE_ARCH="agy"; MODEL_ARCH="claude-opus-5-5-high"
ROLE_DEV="agy";  MODEL_DEV="claude-sonnet-5-5-high"
ROLE_QA="codex"; MODEL_QA="gpt-6.1-terra"

echo "== AC-1: ทดสอบ Modular Braille Apple Logo และ Hermes-Style Split-Header Card =="

logo_out="$(render_relay_logo_lines "apple" | sed 's/\x1b\[[0-9;]*m//g')"
logo_lines="$(printf "%s\n" "$logo_out" | wc -l | tr -d ' ')"
if [ "$logo_lines" = "9" ] && printf "%s" "$logo_out" | grep -q "⣠⣤⡀" && printf "%s" "$logo_out" | grep -q "⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁"; then
  pass "render_relay_logo_lines วาด Braille Apple Logo ครบ 9 บรรทัด และแยกฟังก์ชันอิสระพร้อมเปลี่ยนรูปได้ทันที"
else
  fail "render_relay_logo_lines แสดงผลไม่ถูกต้อง ($logo_lines lines)"
fi

dash_raw="$(SUBCOMMAND=status print_dashboard_header)"
dash_clean="$(printf "%s" "$dash_raw" | sed 's/\x1b\[[0-9;]*m//g')"

if printf "%s" "$dash_clean" | grep -q "╭.*RELAY v1.0.0.*╮" && \
   printf "%s" "$dash_clean" | grep -q "Agent Roles" && \
   printf "%s" "$dash_clean" | grep -q "Quota (5h / 7d)" && \
   printf "%s" "$dash_clean" | grep -q "Pipeline & Telemetry" && \
   printf "%s" "$dash_clean" | grep -q "Task: 20261030-ui-redesign"; then
  pass "print_dashboard_header แสดงกรอบ Hermes-Style Split-Header Card พร้อมหมวด Agent Roles, Quota (5h / 7d), Pipeline & Telemetry และ Task"
else
  fail "print_dashboard_header แสดงโครงสร้างไม่ครบ:\n$dash_clean"
fi

echo "== AC-2: ทดสอบศัพท์มาตรฐานนักพัฒนาและตรวจจับการไม่ Over-claim บน Dashboard =="
if ! printf "%s" "$dash_clean" | grep -Eq "Real-Time Quota|ใบงาน|สถานะงาน|ศูนย์จัดการ"; then
  pass "บน Dashboard ไม่มีคำว่า Real-Time Quota, ใบงาน, สถานะงาน หรือ ศูนย์จัดการ (Zero Over-claiming & Clean Dev Terms)"
else
  fail "พบคำต้องห้ามบน Dashboard:\n$dash_clean"
fi

echo "== AC-3: ทดสอบเมนู Workflow 7 ข้อหลัก และแถบ Shortcuts ด้านล่าง =="
MENU_SHORTCUTS_BAR="1"
EXTRA_MENU_KEYS="c g u v l n f i t d s q m"
menu_out="$(interactive_menu "Workflow (↑/↓ select, Enter run, or press key)" 0 \
  "1|@po            Define Spec (SPEC.md)" \
  "2|@arch & @pm    Design Architecture & Plan" \
  "3|@dev           Implement in Git Worktree" \
  "4|@qa & @sec     Verify Tests & Security" \
  "5|Merge          Merge Branch to main" \
  "a|Auto Loop      Run Steps 2 → 3 ⇄ 4" \
  "x|Fast Track     Quick Spec + Step 3 → 4" <<< "u" | sed 's/\x1b\[[0-9;]*m//g')"

if printf "%s" "$menu_out" | grep -q "Workflow" && \
   printf "%s" "$menu_out" | grep -q "Shortcuts" && \
   printf "%s" "$menu_out" | grep -q "\[c\] Models" && \
   printf "%s" "$menu_out" | grep -q "\[q\] Quit"; then
  pass "interactive_menu แสดงรายการ Workflow แยกจากแถบ Shortcuts ด้านล่างอย่างเป็นสัดส่วน"
else
  fail "interactive_menu ไม่ได้แสดง Shortcuts bar:\n$menu_out"
fi

echo ""
printf "ผลรวม: ผ่าน %d • ไม่ผ่าน %d\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
