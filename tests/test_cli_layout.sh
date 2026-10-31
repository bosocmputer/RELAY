#!/usr/bin/env bash
# ==============================================================================
# ชุดทดสอบหน้าจอหลักแบบแบ่งซ้าย-ขวา, โลโก้ RELAY,
# 4-Level Quiet Color Hierarchy, หน้าจอภาษาไทยเป็นหลัก & แถบปุ่มลัด
# รันด้วย: bash tests/test_cli_layout.sh (ไม่ใช้โควต้า AI จริง)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELAY_SH="$REPO_DIR/relay.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf "  ✅ %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  ❌ %s\n" "$1"; }

TMP_ROOT="$(mktemp -d -t relay-cli-layout-test.XXXXXX)"
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

echo "== AC-1: ทดสอบโลโก้ RELAY และหน้าจอหลักแบบแบ่งซ้าย-ขวา =="

logo_out="$(render_relay_logo_lines | sed 's/\x1b\[[0-9;]*m//g')"
logo_lines="$(printf "%s\n" "$logo_out" | wc -l | tr -d ' ')"
if [ "$logo_lines" = "9" ] && printf "%s" "$logo_out" | grep -q "▐█████▄" && printf "%s" "$logo_out" | grep -q "R E L A Y" && ! grep -q "⣠⣤⡀" "$REPO_DIR/relay.sh"; then
  pass "render_relay_logo_lines วาดโลโก้ RELAY ของโครงการเอง 9 บรรทัด (ไม่มีโลโก้แอปเปิลเดิม) และเปลี่ยนรูปได้ที่ฟังก์ชันเดียว"
else
  fail "render_relay_logo_lines แสดงผลไม่ถูกต้อง ($logo_lines lines)"
fi

dash_raw="$(SUBCOMMAND=status print_dashboard_header)"
dash_clean="$(printf "%s" "$dash_raw" | sed 's/\x1b\[[0-9;]*m//g')"

if printf "%s" "$dash_clean" | grep -q "╭.*RELAY v1.0.0.*╮" && \
   printf "%s" "$dash_clean" | grep -q "ตำแหน่ง AI" && \
   printf "%s" "$dash_clean" | grep -q "โควต้า (5 ชม. / 7 วัน)" && \
   printf "%s" "$dash_clean" | grep -q "ความคืบหน้าและสถิติ" && \
   printf "%s" "$dash_clean" | grep -q "งาน: 20261030-ui-redesign"; then
  pass "print_dashboard_header แสดงกรอบแบ่งซ้าย-ขวาเป็นภาษาไทย พร้อมหมวด ตำแหน่ง AI, โควต้า (5 ชม. / 7 วัน), ความคืบหน้าและสถิติ และงานปัจจุบัน"
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
menu_out="$(interactive_menu "ขั้นตอนการทำงาน (↑/↓ เลือก • Enter รัน • หรือกดปุ่ม)" 0 \
  "1|@po            Define Spec (SPEC.md)" \
  "2|@arch & @pm    Design Architecture & Plan" \
  "3|@dev           Implement in Git Worktree" \
  "4|@qa & @sec     Verify Tests & Security" \
  "5|Merge          Merge Branch to main" \
  "a|Auto Loop      Run Steps 2 → 3 ⇄ 4" \
  "x|Fast Track     Quick Spec + Step 3 → 4" <<< "u" | sed 's/\x1b\[[0-9;]*m//g')"

if printf "%s" "$menu_out" | grep -q "ขั้นตอนการทำงาน" && \
   printf "%s" "$menu_out" | grep -q "ปุ่มลัด" && \
   printf "%s" "$menu_out" | grep -q "\[c\] โมเดล" && \
   printf "%s" "$menu_out" | grep -q "\[q\] ออก"; then
  pass "interactive_menu แสดงเมนูขั้นตอนการทำงานแยกจากแถบปุ่มลัดด้านล่าง (ภาษาไทย)"
else
  fail "interactive_menu ไม่ได้แสดง Shortcuts bar:\n$menu_out"
fi

echo "== AC-4: ทดสอบการจัดเรียงโปรเจกต์ ● [RELAY] ขึ้นก่อน ○ [ทั่วไป] และกฎ On-Demand Per-Project =="
mkdir -p "$HOME/Projects/Alpha_Plain" \
         "$HOME/Projects/Beta_Plain" \
         "$HOME/Projects/Zeta_Relay/.relay/tasks/20261031-auth-flow" \
         "$HOME/Projects/Omega_Relay/.relay"
echo "# Project State" > "$HOME/Projects/Zeta_Relay/.relay/PROJECT_STATE.md"
echo "# Project State" > "$HOME/Projects/Omega_Relay/.relay/PROJECT_STATE.md"

proj_tsv="$(list_workspace_projects_tsv)"
first_two_flags="$(printf "%s\n" "$proj_tsv" | head -n 2 | cut -f1 | tr '\n' ',')"
if [ "$first_two_flags" = "1,1," ] && \
   printf "%s\n" "$proj_tsv" | grep -q "Zeta_Relay.*งาน: 20261031-auth-flow" && \
   printf "%s\n" "$proj_tsv" | grep -q "Omega_Relay.*พร้อมเริ่มงานใหม่"; then
  pass "list_workspace_projects_tsv จัดเรียงโปรเจกต์ที่มี .relay/ ไว้บนสุดเสมอ พร้อมแสดงสถานะ Task ปัจจุบัน"
else
  fail "list_workspace_projects_tsv จัดเรียงหรือแสดงสถานะไม่ถูกต้อง:\n$proj_tsv"
fi

sel_menu_raw="$(interactive_menu "เลือกโฟลเดอร์โปรเจกต์" 1 \
  "n|★ สร้างโฟลเดอร์โปรเจกต์ใหม่" \
  "1|● [RELAY]   Omega_Relay                ~/Projects/Omega_Relay (พร้อมเริ่มงานใหม่)" \
  "2|○ [ทั่วไป]   Alpha_Plain                ~/Projects/Alpha_Plain" <<< "b")"
if printf "%s" "$sel_menu_raw" | grep -q "● \[RELAY\]" && \
   printf "%s" "$sel_menu_raw" | grep -q "○ \[ทั่วไป\]"; then
  pass "interactive_menu แสดงป้ายจำแนก ● [RELAY] และ ○ [ทั่วไป] อย่างชัดเจน"
else
  fail "interactive_menu ไม่ได้แสดงป้าย ● [RELAY] / ○ [ทั่วไป]"
fi

if grep -q "เฉพาะในโครงการที่มีโฟลเดอร์ \`.relay/\`" "$REPO_DIR/templates/GLOBAL_AGENTS.md" && \
   grep -q "กรณีโครงการทั่วไปที่ไม่มีโฟลเดอร์ \`.relay/\`" "$REPO_DIR/templates/GLOBAL_AGENTS.md"; then
  pass "templates/GLOBAL_AGENTS.md กำหนดขอบเขต On-Demand & Per-Project ชัดเจน ไม่บังคับใช้ทีมในโปรเจกต์ทั่วไป"
else
  fail "templates/GLOBAL_AGENTS.md ยังไม่ได้ระบุขอบเขต On-Demand & Per-Project"
fi

echo ""
printf "ผลรวม: ผ่าน %d • ไม่ผ่าน %d\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
