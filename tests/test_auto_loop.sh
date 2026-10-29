#!/usr/bin/env bash
# ทดสอบ Auto-Relay Loop (AC-4, AC-5, AC-6) ด้วย CLI จำลอง — ไม่ใช้โควต้า AI จริง
RELAY="$(cd "$(dirname "$0")/.." && pwd)/relay.sh"
ROOT=/tmp/relay-lt
T=20261029-loopdemo
pass=0; fail=0
ok()  { echo "  ✅ $1"; pass=$((pass+1)); }
bad() { echo "  ❌ $1"; fail=$((fail+1)); }

setup() {
  rm -rf "$ROOT"
  mkdir -p "$ROOT/home/.gemini/bin" "$ROOT/home/.agents" "$ROOT/proj"
  echo "fake-token" > "$ROOT/home/.gemini/jetski-standalone-oauth-token"

  cat > "$ROOT/home/.gemini/bin/agy" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "--version" ] && { echo "agy-fake 0.0"; exit 0; }
prompt=""
while [ $# -gt 0 ]; do
  case "$1" in -p) prompt="$2"; shift 2 ;; *) echo "$1" >> "$FAKE_LOG.agy-args"; shift ;; esac
done
[ "$prompt" = "/usage" ] && exit 0
td=".relay/tasks/$FAKE_TASK"
case "$prompt" in
  *"@arch"*) mkdir -p "$td"; echo "# ARCH" > "$td/ARCH.md"; echo "- [ ] T1" > "$td/PLAN.md" ;;
  *"@dev"*)
    if [ -n "$FAKE_DEV_SLEEP" ]; then
      trap 'kill $SP 2>/dev/null; touch "$FAKE_LOG.terminated"; exit 143' TERM
      sleep "$FAKE_DEV_SLEEP" & SP=$!; wait $SP
    fi
    echo "code $(date +%s%N)" >> app.txt
    exit "${FAKE_DEV_RC:-0}"
    ;;
esac
exit 0
EOF

  cat > "$ROOT/home/.gemini/bin/codex" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --version) echo "codex-cli fake"; exit 0 ;;
  login) echo "Logged in using ChatGPT"; exit 0 ;;
  exec)
    n=$(( $(cat "$FAKE_LOG.qa-count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$FAKE_LOG.qa-count"
    v=$(echo "$FAKE_QA_SEQUENCE" | cut -d, -f"$n")
    td=".relay/tasks/$FAKE_TASK"; mkdir -p "$td"
    case "$v" in
      PASS) printf "# QA\n**VERDICT: PASS**\n" > "$td/QA_REPORT.md" ;;
      FAIL) printf "# QA\nVERDICT: FAIL\n- bug\n" > "$td/QA_REPORT.md" ;;
      NONE) printf "# QA\nทุกอย่างดูดี\n" > "$td/QA_REPORT.md" ;;
      MISSING) : ;;
    esac
    exit 0 ;;
esac
exit 0
EOF
  chmod +x "$ROOT/home/.gemini/bin/agy" "$ROOT/home/.gemini/bin/codex"

  cat > "$ROOT/home/.agents/relay-roles.conf" <<'EOF'
ROLE_PO="agy"
MODEL_PO="gemini-4-argon-high"
ROLE_ARCH="agy"
MODEL_ARCH="claude-opus-5-5-high"
ROLE_DEV="agy"
MODEL_DEV="claude-sonnet-5-5-high"
ROLE_QA="codex"
MODEL_QA="gpt-6.1-terra"
EOF
  local N; N=$(date +%s)
  cat > "$ROOT/home/.agents/relay-quota.cache" <<EOF
QUOTA_UPDATED_EPOCH="$N"
AGY_GEMINI_5H_REM="90"
AGY_GEMINI_7D_REM="90"
AGY_CLAUDE_5H_REM="90"
AGY_CLAUDE_7D_REM="90"
CODEX_5H_REM="90"
CODEX_7D_REM="90"
EOF
  cd "$ROOT/proj" || exit 1
  git init -q -b main && echo base > app.txt && git add app.txt && git commit -q -m init
  mkdir -p ".relay/tasks/$T" && echo "# SPEC" > ".relay/tasks/$T/SPEC.md" && echo state > .relay/PROJECT_STATE.md
}

run_loop() {
  ( cd "$ROOT/proj" && HOME="$ROOT/home" FAKE_TASK="$T" FAKE_LOG="$ROOT/fake" bash "$RELAY" loop --yes ) < /dev/null > "$ROOT/out.log" 2>&1
}

LOG() { cat "$ROOT/proj/.relay/tasks/$T/LOOP_LOG.md" 2>/dev/null; }

echo "== AC-4: QA รอบ 1 FAIL, รอบ 2 PASS =="
setup
FAKE_QA_SEQUENCE="FAIL,PASS" run_loop
[ -f "$ROOT/proj/.relay/tasks/$T/PLAN.md" ] && ok "@arch สร้าง PLAN.md" || bad "ไม่มี PLAN.md"
LOG | grep -q "\[PASS\] รอบที่ 2/3" && ok "ผ่านในรอบที่ 2" || bad "ไม่ผ่านในรอบที่ 2"
[ -f "$ROOT/proj/.relay/tasks/$T/QA_REPORT.before-round-2.md" ] && ok "เก็บรายงานรอบก่อนเป็น before-round-2" || bad "ไม่มี QA_REPORT.before-round-2.md"
[ -d "$ROOT/proj/.relay/worktrees/$T" ] && ok "ทำงานใน Worktree" || bad "ไม่มี Worktree"
grep -q '^.relay/worktrees/$' "$ROOT/proj/.gitignore" && ok "เพิ่ม .relay/worktrees/ ใน .gitignore" || bad ".gitignore ไม่ถูกอัปเดต"
grep -q -- "--mode" "$ROOT/fake.agy-args" && grep -q "^auto$" "$ROOT/fake.agy-args" && ok "agy ถูกเรียกด้วย --mode auto" || bad "ไม่พบ --mode auto"
git -C "$ROOT/proj" diff --quiet HEAD -- app.txt && ok "main ไม่ถูกแก้โค้ด" || bad "main ถูกแก้"

echo "== AC-5: QA_REPORT ไม่มี VERDICT ➔ ไม่นับว่าผ่าน =="
setup
FAKE_QA_SEQUENCE="NONE,NONE,NONE" run_loop
LOG | grep -q "\[PASS\]" && bad "ถูกนับว่าผ่าน" || ok "ไม่ถูกนับว่าผ่าน"
LOG | grep -q "ไม่มี VERDICT" && ok "บันทึกเหตุผล ไม่มี VERDICT" || bad "ไม่บันทึกเหตุผล"
LOG | grep -q "ครบเพดาน 3 รอบ" && ok "หยุดเมื่อครบ 3 รอบ" || bad "ไม่หยุดที่ 3 รอบ"

echo "== AC-6: agent ค้างเกินเวลา ➔ หยุดลูป =="
setup
start=$(date +%s)
RELAY_STEP_TIMEOUT=3 FAKE_DEV_SLEEP=30 FAKE_QA_SEQUENCE="PASS" run_loop
dur=$(( $(date +%s) - start ))
LOG | grep -q "เกินเพดานเวลา" && ok "บันทึกเหตุผล เกินเพดานเวลา" || bad "ไม่บันทึกเหตุผลหมดเวลา"
[ "$dur" -lt 20 ] && ok "หยุดภายใน ${dur} วินาที (ไม่รอครบ 30)" || bad "ใช้เวลา ${dur} วินาที"
sleep 1
[ -f "$ROOT/fake.terminated" ] && ok "agent ได้รับสัญญาณ TERM และหยุดจริง" || bad "agent ไม่ได้ถูกหยุด"
[ ! -f "$ROOT/fake.qa-count" ] && ok "ไม่เรียก @qa หลังหยุด" || bad "ยังเรียก @qa"

echo "== เพิ่มเติม: @qa ไม่เขียนรายงาน / @dev error =="
setup
FAKE_QA_SEQUENCE="MISSING" run_loop
LOG | grep -q "ไม่ได้เขียน" && ok "หยุดเมื่อ @qa ไม่เขียน QA_REPORT.md" || bad "ไม่หยุดเมื่อไม่มีรายงาน"
setup
FAKE_DEV_RC=1 FAKE_QA_SEQUENCE="PASS" run_loop
LOG | grep -q "exit 1" && ok "หยุดเมื่อ @dev จบด้วย error" || bad "ไม่หยุดเมื่อ @dev error"

echo ""
echo "ผลรวม: ผ่าน $pass • ไม่ผ่าน $fail"
[ "$fail" -eq 0 ]
