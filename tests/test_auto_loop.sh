#!/usr/bin/env bash
# ทดสอบ Auto-Relay Loop (AC-4, AC-5, AC-6) ด้วย CLI จำลอง — ไม่ใช้โควต้า AI จริง
RELAY="$(cd "$(dirname "$0")/.." && pwd)/relay.sh"
ROOT="$(mktemp -d -t relay-loop-test.XXXXXX)"
trap 'rm -rf "$ROOT"' EXIT
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
    printf '%s\n' "$prompt" >> "$FAKE_LOG.dev-prompts"
    if [ -n "$FAKE_DEV_SLEEP" ]; then
      trap 'kill $SP 2>/dev/null; touch "$FAKE_LOG.terminated"; exit 143' TERM
      sleep "$FAKE_DEV_SLEEP" & SP=$!; wait $SP
    fi
    echo "code $(date +%s%N)" >> app.txt
    [ -n "$FAKE_DEV_EDIT_SPEC" ] && echo "- [ ] เกณฑ์ที่ @dev เพิ่มเอง" >> "$td/SPEC.md"
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
    printf '%s\n' "$*" >> "$FAKE_LOG.qa-prompts"
    n=$(( $(cat "$FAKE_LOG.qa-count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$FAKE_LOG.qa-count"
    v=$(echo "$FAKE_QA_SEQUENCE" | cut -d, -f"$n")
    td=".relay/tasks/$FAKE_TASK"; mkdir -p "$td"
    echo "HACKED-BY-QA" > .relay/PROJECT_STATE.md
    case "$v" in
      PASS) printf "# QA\n**VERDICT: PASS**\n" > "$td/QA_REPORT.md"; printf '{"verdict":"PASS","failed_criteria":[],"tests_run":["npm test"],"summary":"ok"}' > "$td/QA_VERDICT.json" ;;
      FAIL) printf "# QA\nVERDICT: FAIL\n- bug\n" > "$td/QA_REPORT.md"; printf '{"verdict":"FAIL","failed_criteria":["AC-1"],"tests_run":[],"summary":"bug"}' > "$td/QA_VERDICT.json" ;;
      NONE) printf "# QA\nทุกอย่างดูดี\n" > "$td/QA_REPORT.md" ;;
      MDPASS) printf "# QA\nVERDICT: PASS\n" > "$td/QA_REPORT.md" ;;
      JSONBAD) printf "# QA\nVERDICT: PASS\n" > "$td/QA_REPORT.md"; printf '{verdict: PASS' > "$td/QA_VERDICT.json" ;;
      JSONCONTRA) printf "# QA\nVERDICT: PASS\n" > "$td/QA_REPORT.md"; printf '{"verdict":"PASS","failed_criteria":["AC-2 ยังไม่ผ่าน"]}' > "$td/QA_VERDICT.json" ;;
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
grep -qx "state" "$ROOT/proj/.relay/PROJECT_STATE.md" && ok "PROJECT_STATE.md ของกิ่งหลักไม่ถูก @qa แก้ (F4)" || bad "PROJECT_STATE.md ถูกแก้ก่อนผสาน"
[ -f "$ROOT/proj/.relay/tasks/$T/QA_VERDICT.before-round-2.json" ] && ok "เก็บ QA_VERDICT.json รอบก่อน" || bad "ไม่มี QA_VERDICT.before-round-2.json"
nlines=$(wc -l < "$ROOT/proj/.relay/tasks/$T/RUN_LOG.jsonl" 2>/dev/null | tr -d ' ')
[ "$nlines" = "5" ] && ok "RUN_LOG.jsonl มี 5 บรรทัด (arch + dev×2 + qa×2) (F5)" || bad "RUN_LOG.jsonl มี ${nlines:-0} บรรทัด"
python3 -c "import json,sys; [json.loads(l) for l in open(sys.argv[1])]" "$ROOT/proj/.relay/tasks/$T/RUN_LOG.jsonl" 2>/dev/null && ok "RUN_LOG.jsonl เป็น JSON ที่อ่านได้" || bad "RUN_LOG.jsonl อ่านไม่ได้"
grep -q "สรุปการทำงานของลูป" "$ROOT/out.log" && ok "แสดงสรุปเวลาและโควต้าท้ายลูป" || bad "ไม่แสดงสรุปท้ายลูป"
[ "$(grep -c "คุณภาพโค้ด (ทุกภาษา)" "$ROOT/fake.dev-prompts" 2>/dev/null)" = "2" ] && ok "prompt ของ @dev ทั้ง 2 รอบมีกฎคุณภาพโค้ด (ใช้ของเดิมซ้ำ ยึดแบบแผนเดิม)" || bad "prompt ของ @dev ไม่มีกฎคุณภาพโค้ดครบทุกรอบ"
[ "$(grep -c "ตรวจ git diff ด้านคุณภาพโค้ด" "$ROOT/fake.qa-prompts" 2>/dev/null)" = "2" ] && ok "prompt ของ @qa ทั้ง 2 รอบให้ตรวจคุณภาพโค้ดใน diff" || bad "prompt ของ @qa ไม่มีการตรวจคุณภาพโค้ด"

echo "== AC-5: QA_REPORT ไม่มี VERDICT ➔ ไม่นับว่าผ่าน =="
setup
FAKE_QA_SEQUENCE="NONE,NONE,NONE" run_loop
LOG | grep -q "\[PASS\]" && bad "ถูกนับว่าผ่าน" || ok "ไม่ถูกนับว่าผ่าน"
LOG | grep -q "ไม่มี VERDICT" && ok "บันทึกเหตุผล ไม่มี VERDICT" || bad "ไม่บันทึกเหตุผล"
LOG | grep -q "ครบเพดาน 3 รอบ" && ok "หยุดเมื่อครบ 3 รอบ" || bad "ไม่หยุดที่ 3 รอบ"

echo "== F3: ผลตรวจรับแบบ JSON =="
setup
FAKE_QA_SEQUENCE="JSONCONTRA,JSONBAD,MDPASS" run_loop
LOG | sed -n '/รอบที่ 1\/3/p' | grep -q "RETRY" && ok "JSON PASS แต่มี failed_criteria ➔ ไม่ผ่าน" || bad "JSON ขัดแย้งถูกนับว่าผ่าน"
LOG | grep -q "รูปแบบไม่ถูกต้อง" && ok "JSON เสีย ➔ ไม่ผ่านและบันทึกเหตุผล" || bad "JSON เสียไม่ถูกตรวจจับ"
LOG | grep -q "\[PASS\] รอบที่ 3/3.*ทางสำรอง" && ok "ไม่มี JSON แต่ MD มี PASS ➔ ผ่านพร้อมบันทึกว่าใช้ทางสำรอง" || bad "ทางสำรอง MD ไม่ทำงาน"

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

setup
FAKE_DEV_EDIT_SPEC=1 FAKE_QA_SEQUENCE="PASS" run_loop
grep -q "@dev แก้ไข SPEC.md" "$ROOT/out.log" && ! grep -q "เกณฑ์ที่ @dev เพิ่มเอง" "$ROOT/proj/.relay/tasks/$T/SPEC.md" && LOG | grep -q "PASS" && ok "Auto-Loop: @dev แก้ SPEC.md ➔ แจ้งเตือนและคืนฉบับเดิม (ค่าเริ่มต้น) แล้วลูปทำต่อ" || bad "Auto-Loop ไม่กันการแก้ SPEC.md"

echo "== Evidence Gate: ด่านเทสต์ที่สคริปต์รันเองในลูป =="
TDIR="$ROOT/proj/.relay/tasks/$T"
gate_sig() { (cd "$ROOT/proj" && HOME="$ROOT/home" RELAY_SOURCE_ONLY=1 bash -c "source \"$RELAY\"; PROJECT_DIR=\"\$PWD\"; refresh_project_paths; ACTIVE_TASK=$T; gate_commands_sig"); }
setup
# app.txt เริ่ม 1 บรรทัด • @dev จำลองเพิ่มรอบละ 1 บรรทัด ➔ รอบ 1 ไม่ผ่าน รอบ 2 ผ่าน
printf 'TEST: [ "$(wc -l < app.txt)" -ge 3 ]\n' > "$TDIR/PLAN.md"
gate_sig > "$TDIR/GATE_APPROVED"
FAKE_QA_SEQUENCE="PASS" run_loop
LOG | grep -q "รอบที่ 1/3: เทสต์ที่ RELAY รันเอง.*ข้าม @qa" && LOG | grep -q "\[PASS\] รอบที่ 2/3" && [ "$(cat "$ROOT/fake.qa-count")" = "1" ] && ok "TEST ไม่ผ่านหลัง @dev ➔ ข้าม @qa รอบนั้น • รอบถัดไปผ่าน ➔ @qa ถูกเรียกครั้งเดียว" || bad "ลูปไม่ข้าม @qa เมื่อเทสต์ของสคริปต์ไม่ผ่าน"
grep -q "^RESULT: PASS" "$TDIR/EVIDENCE.log" && [ "$(grep -c "EVIDENCE.log" "$ROOT/fake.dev-prompts")" = "1" ] && grep -q "EVIDENCE.log" "$ROOT/fake.qa-prompts" && ok "EVIDENCE.log ล่าสุดเป็น PASS • prompt @dev รอบแก้และ @qa ให้อ่าน EVIDENCE.log" || bad "EVIDENCE.log หรือ prompt ไม่ถูกต้อง"
setup
printf 'ENV_CHECK: test -f "$HOME/no-such-db"\nTEST: true\n' > "$TDIR/PLAN.md"
gate_sig > "$TDIR/GATE_APPROVED"
FAKE_QA_SEQUENCE="PASS" run_loop
LOG | grep -q "สภาพแวดล้อมยังรันเทสต์ไม่ได้" && [ ! -f "$ROOT/fake.dev-prompts" ] && ok "ENV_CHECK ไม่ผ่าน ➔ ลูปหยุดก่อนเปิด @dev พร้อมเหตุผล" || bad "ลูปไม่หยุดเมื่อ ENV_CHECK ไม่ผ่าน"
setup
printf 'TEST: false\n' > "$TDIR/PLAN.md"
FAKE_QA_SEQUENCE="PASS" run_loop
grep -q "TEST      : false" "$ROOT/out.log" && LOG | grep -q "\[PASS\] รอบที่ 1/3" && [ ! -f "$TDIR/EVIDENCE.log" ] && ok "ยังไม่อนุมัติคำสั่ง (ไม่มีคนตอบ) ➔ ไม่รันคำสั่งจาก PLAN ลูปทำงานเหมือนเดิม" || bad "รันคำสั่งที่ยังไม่อนุมัติ หรือลูปเปลี่ยนพฤติกรรม"
setup
FAKE_QA_SEQUENCE="FAIL,FAIL,FAIL" run_loop
grep -q "ตรวจไม่ผ่านติดกัน 3 รอบ" "$ROOT/out.log" && [ "$(awk 'END{print NR}' "$TDIR/QA_HISTORY.jsonl")" = "3" ] && ok "ครบเพดานรอบ ➔ QA_HISTORY 3 รอบ และเตือน FAIL ติดกันพร้อมสาเหตุที่พบบ่อย" || bad "ไม่เตือน FAIL ติดกันในลูป"

echo "== QA Convergence: ลูปหยุดเมื่อข้อที่บล็อกไม่ลดลง =="
setup
printf '{"verdict":"FAIL","blocking":2}\n{"verdict":"FAIL","blocking":1}\n{"verdict":"FAIL","blocking":2}\n' > "$TDIR/QA_HISTORY.jsonl"
FAKE_QA_SEQUENCE="PASS" run_loop
LOG | grep -q "ไม่ลู่เข้า" && [ ! -f "$ROOT/fake.dev-prompts" ] && ok "ประวัติ FAIL 3 รอบที่ข้อบล็อกไม่ลดลง ➔ ลูปหยุดก่อนเปิด @dev" || bad "ลูปไม่หยุดเมื่อไม่ลู่เข้า"
setup
FAKE_QA_SEQUENCE="FAIL,PASS" run_loop
grep -q "รายงานข้อบกพร่องทั้งหมดที่พบในรอบเดียว" "$ROOT/fake.qa-prompts" && sed -n 2p "$ROOT/fake.qa-prompts" | grep -q "git diff .*\.\.HEAD" && ok "ลูป: @qa รอบแรกตรวจทั้งงาน • รอบแก้ตรวจเฉพาะ git diff ตั้งแต่ commit ที่ตรวจรอบก่อน" || bad "ขอบเขตการตรวจของ @qa ในลูปไม่ถูกต้อง"

echo ""
echo "ผลรวม: ผ่าน $pass • ไม่ผ่าน $fail"
[ "$fail" -eq 0 ]
