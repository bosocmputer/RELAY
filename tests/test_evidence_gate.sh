#!/usr/bin/env bash
# ชุดทดสอบใบงาน 20261103-test-evidence-gate: ด่านเทสต์ที่สคริปต์รันเอง (ENV_CHECK/TEST) • ประวัติ QA • codex เปิดเน็ต
# ไม่ใช้โควต้า AI: แยก HOME ชั่วคราว และแทนฟังก์ชันที่เปิด agent ด้วยตัวจำลอง
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELAY_SH="$REPO_ROOT/relay.sh"

TMP_ROOT="$(mktemp -d -t relay-evidence-gate.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
ok()  { echo "  ✅ PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
bad() { echo "  ❌ FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
check() { if eval "$1"; then ok "$2"; else bad "$2"; fi; }

export HOME="$TMP_ROOT/home"
mkdir -p "$HOME/.agents"
unset GIT_CONFIG_GLOBAL XDG_CONFIG_HOME RELAY_WORKSPACE
export GIT_CONFIG_NOSYSTEM=1
printf '[user]\n\tname = relay-test\n\temail = relay-test@example.com\n' > "$HOME/.gitconfig"

P="$TMP_ROOT/proj"
T=t1
TD="$P/.relay/tasks/$T"
WT="$P/.relay/worktrees/$T"
WTD="$WT/.relay/tasks/$T"
mkdir -p "$TD"
printf '# spec\n- [ ] ยอดรวม 100\n' > "$TD/SPEC.md"

# ตัวจำลอง: ไม่เปิด AI จริง • @dev ทำตาม $DEV_ACTION • @qa ทำตาม $QA_ACTION
STUBS='require_all_roles_ready(){ :; }; ensure_or_create_task(){ :; }; check_role_quota_safe(){ :; }; ensure_qa_playwright_mcp(){ :; };
prepare_task_worktree(){ TASK_WORK_DIR="$PROJECT_DIR/.relay/worktrees/t1"; mkdir -p "$TASK_WORK_DIR/.relay/tasks"; cp -R "$RELAY_DIR/tasks/t1" "$TASK_WORK_DIR/.relay/tasks/"; };
launch_provider_cli(){ echo "LAUNCHED:$3"; case "$3" in *@qa*) eval "${QA_ACTION:-}" ;; *) eval "${DEV_ACTION:-}" ;; esac; }'
rs() { (cd "$P" && printf "${2:-}" | RELAY_SOURCE_ONLY=1 bash -c "source \"$RELAY_SH\"; $STUBS; PROJECT_DIR=\"\$PWD\"; refresh_project_paths; ACTIVE_TASK=t1; $1") 2>&1 | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g'; }
approve() { rs 'gate_commands_sig' > "$TD/GATE_APPROVED"; }

echo "=== [AC1] codex ทุกบทบาทเปิดเน็ตใน sandbox ==="
check 'grep -q "^RELAY_CODEX_NET_CONFIG='"'"'sandbox_workspace_write.network_access=true'"'"'" "$RELAY_SH"' "ค่าเปิดเน็ตของ codex ถูกต้อง"
check '[ "$(grep -c "codex .*-c \"\$RELAY_CODEX_NET_CONFIG\"" "$RELAY_SH")" = "2" ]' "ทั้ง codex interactive และ codex exec (loop) ส่ง -c เปิดเน็ต"

echo "=== [AC2] อ่าน ENV_CHECK/TEST จาก PLAN.md ได้หลายรูปแบบ ==="
cat > "$TD/PLAN.md" <<'EOF'
1. ทำอย่างอื่น (TEST: ไม่ใช่บรรทัดคำสั่ง)
ENV_CHECK: test -d .
- `TEST: echo a`
- **TEST:** `echo b`
TEST: `echo c`
PRETEST: echo ไม่นับ
EOF
out="$(rs 'plan_gate_commands TEST | tr "\n" "|"; echo; plan_gate_commands ENV_CHECK')"
check '[ "$(printf "%s" "$out" | sed -n 1p)" = "echo a|echo b|echo c|" ] && [ "$(printf "%s" "$out" | sed -n 2p)" = "test -d ." ]' "ได้ TEST 3 คำสั่ง (bullet/ตัวหนา/backtick) และ ENV_CHECK 1 คำสั่ง ไม่นับข้อความทั่วไป"

echo "=== [AC3] ต้องอนุมัติคำสั่งก่อนรัน ==="
printf 'ENV_CHECK: test -d .\nTEST: echo ok\n' > "$TD/PLAN.md"
out="$(rs 'gate_ensure_approved && echo APPROVED || echo DECLINED' 'n\n')"
check 'printf "%s" "$out" | grep -q "TEST      : echo ok" && printf "%s" "$out" | grep -q DECLINED && [ ! -f "$TD/GATE_APPROVED" ]' "แสดงรายการคำสั่ง • เลือก [n] ➔ ไม่อนุมัติ ไม่บันทึก"
out="$(rs 'gate_ensure_approved && echo APPROVED || echo DECLINED' '')"
check 'printf "%s" "$out" | grep -q DECLINED && [ ! -f "$TD/GATE_APPROVED" ]' "ไม่มีคนตอบ (EOF) ➔ ไม่อนุมัติเอง"
out="$(rs 'gate_ensure_approved && echo APPROVED || echo DECLINED' 'y\n')"
check 'printf "%s" "$out" | grep -q APPROVED && [ -s "$TD/GATE_APPROVED" ]' "เลือก [y] ➔ อนุมัติและบันทึก"
out="$(rs 'gate_ensure_approved && echo APPROVED || echo DECLINED' '')"
check 'printf "%s" "$out" | grep -q APPROVED && ! printf "%s" "$out" | grep -q "อนุมัติให้ RELAY"' "อนุมัติแล้ว ➔ ไม่ถามซ้ำ"
printf 'TEST: rm -rf src\n' >> "$TD/PLAN.md"
out="$(rs 'gate_ensure_approved && echo APPROVED || echo DECLINED' '')"
check 'printf "%s" "$out" | grep -q "rm -rf src" && printf "%s" "$out" | grep -q DECLINED' "PLAN.md เปลี่ยนคำสั่ง ➔ ถามใหม่ (ไม่ใช้การอนุมัติเดิม)"
out="$(rs 'printf "" > "$RELAY_DIR/tasks/t1/PLAN.md"; gate_ensure_approved && echo APPROVED || echo DECLINED; run_phase_3_dev' '')"
check 'printf "%s" "$out" | grep -q DECLINED && ! printf "%s" "$out" | grep -q "อนุมัติให้ RELAY" && printf "%s" "$out" | grep -q "LAUNCHED" && [ ! -f "$TD/EVIDENCE.log" ]' "PLAN.md ไม่มี ENV_CHECK/TEST ➔ ไม่ถาม ไม่รัน ทำงานเหมือนเดิม"

echo "=== [AC4] ENV_CHECK ไม่ผ่าน ➔ ไม่เปิด @dev ==="
printf 'ENV_CHECK: test -f "$HOME/db.ready"\nTEST: echo ok\n' > "$TD/PLAN.md"; approve
out="$(rs run_phase_3_dev 'b\n')"
check 'printf "%s" "$out" | grep -q "ENV_CHECK ไม่ผ่าน 1/1" && printf "%s" "$out" | grep -q "ยังไม่เปิด AI" && ! printf "%s" "$out" | grep -q LAUNCHED' "ENV_CHECK ไม่ผ่าน ➔ แสดงผล ไม่เปิด AI • [b] กลับ"
out="$(rs run_phase_3_dev 'c\n')"
check 'printf "%s" "$out" | grep -q LAUNCHED' "เลือก [c] ➔ เปิด @dev ต่อได้"
out="$(rs 'run_phase_3_dev' 'r\nb\n')"
check '[ "$(printf "%s" "$out" | grep -c "ENV_CHECK ไม่ผ่าน")" = "2" ] && ! printf "%s" "$out" | grep -q LAUNCHED' "เลือก [r] ➔ ตรวจซ้ำ"
touch "$HOME/db.ready"
out="$(rs run_phase_3_dev '')"
check 'printf "%s" "$out" | grep -q "ENV_CHECK ผ่านครบ 1/1" && printf "%s" "$out" | grep -q LAUNCHED' "ENV_CHECK ผ่าน ➔ เปิด @dev"

echo "=== [AC5/AC6/AC7] หลัง @dev สคริปต์รัน TEST เองและเขียน EVIDENCE.log ==="
printf 'TEST: test -f done.flag\nTEST: echo สวัสดี\n' > "$TD/PLAN.md"; approve
rm -rf "$WT"; mkdir -p "$WT"; git -C "$WT" init -q -b feat
export DEV_ACTION='echo code > "$TASK_WORK_DIR/app.txt"'
out="$(rs run_phase_3_dev 'b\n')"
unset DEV_ACTION
check 'grep -q "^RESULT: FAIL (1/2 ไม่ผ่าน)" "$TD/EVIDENCE.log" && grep -q "^\[FAIL\] exit=1 .*:: test -f done.flag" "$TD/EVIDENCE.log" && grep -q "^\[PASS\] exit=0 .*:: echo สวัสดี" "$TD/EVIDENCE.log" && grep -q "^CODE: " "$TD/EVIDENCE.log"' "EVIDENCE.log มีผล ทุกคำสั่ง exit code และสถานะโค้ด"
check 'cmp -s "$TD/EVIDENCE.log" "$WTD/EVIDENCE.log"' "มีสำเนา EVIDENCE.log ใน Worktree ให้ AI อ่าน"
check 'printf "%s" "$out" | grep -q "เทสต์ที่ RELAY รันเอง (TEST ใน PLAN.md) ยังไม่ผ่าน" && printf "%s" "$out" | grep -q "❯ \[3\]"' "เทสต์ไม่ผ่าน ➔ ขั้นถัดไปแนะนำส่งกลับ @dev [3] ก่อน"
check 'rs "get_evidence_prompt_note dev" | grep -q "EVIDENCE.log" && rs "get_evidence_prompt_note qa" | grep -q "ห้ามให้ PASS"' "prompt ของ @dev และ @qa ให้อ่าน EVIDENCE.log"
check 'rs "get_arch_gate_note" | grep -q "ENV_CHECK: <คำสั่ง>" && grep -q "คำสั่งรันทดสอบ)\$(get_arch_gate_note)\"" "$RELAY_SH" && [ "$(grep -c "คำสั่งรันทดสอบ)\$(get_arch_gate_note)\"" "$RELAY_SH")" = "2" ]' "prompt ของ @arch (ขั้น 2 และ loop) ให้ใส่ ENV_CHECK/TEST ท้าย PLAN.md"

# @qa เขียน PASS แต่ EVIDENCE ไม่ผ่าน ➔ FAIL
printf '{"verdict":"PASS","failed_criteria":[],"tests_run":["npm test"],"summary":"ok"}' > "$TD/QA_VERDICT.json"
check '[ "$(rs "qa_verdict \"\$RELAY_DIR/tasks/t1\"")" = "FAIL|evidence" ]' "@qa เขียน PASS แต่ TEST ของสคริปต์ไม่ผ่าน ➔ FAIL|evidence"
# AI แก้ EVIDENCE.log ใน Worktree เป็น PASS ➔ sync ไม่ทับของสคริปต์
sed -i.bak 's/^RESULT: FAIL.*/RESULT: PASS (0\/2 ไม่ผ่าน)/' "$WTD/EVIDENCE.log"
printf 'APPROVE-FAKE\n' > "$WTD/GATE_APPROVED"
rs 'sync_task_docs_from_worktree "$PROJECT_DIR/.relay/worktrees/t1/.relay/tasks/t1" "$RELAY_DIR/tasks/t1"' >/dev/null
check 'grep -q "^RESULT: FAIL" "$TD/EVIDENCE.log" && ! grep -q APPROVE-FAKE "$TD/GATE_APPROVED"' "EVIDENCE.log/GATE_APPROVED ที่ถูกแก้ใน Worktree ไม่ถูก sync ทับของสคริปต์"
touch "$WT/done.flag"
rs 'run_gate_commands TEST "$PROJECT_DIR/.relay/worktrees/t1" after-dev' >/dev/null
check '[ "$(rs "qa_verdict \"\$RELAY_DIR/tasks/t1\"")" = "PASS|json" ]' "TEST ผ่านแล้ว ➔ ใช้ผลของ @qa ตามปกติ (PASS|json)"

echo "=== [AC5] ก่อน @qa รัน TEST ใหม่เฉพาะเมื่อโค้ดเปลี่ยน ==="
printf 'TEST: echo run >> "$HOME/runs.txt"\n' > "$TD/PLAN.md"; approve
rm -f "$HOME/runs.txt"
( cd "$WT" && git init -q -b feat && git add -A . >/dev/null 2>&1; git commit -q -m wt --allow-empty ) >/dev/null 2>&1
rs 'run_gate_commands TEST "$PROJECT_DIR/.relay/worktrees/t1" after-dev' >/dev/null
out="$(rs 'gate_tests_before_qa "$PROJECT_DIR/.relay/worktrees/t1"')"
check 'printf "%s" "$out" | grep -q "ใช้หลักฐานเทสต์ล่าสุด" && [ "$(wc -l < "$HOME/runs.txt" | tr -d " ")" = "1" ]' "โค้ดไม่เปลี่ยน ➔ ใช้หลักฐานเดิม ไม่รันซ้ำ"
echo change > "$WT/new-file.txt"
out="$(rs 'gate_tests_before_qa "$PROJECT_DIR/.relay/worktrees/t1"')"
check '[ "$(wc -l < "$HOME/runs.txt" | tr -d " ")" = "2" ]' "โค้ดเปลี่ยนหลังหลักฐานล่าสุด ➔ รัน TEST ใหม่ก่อน @qa"

echo "=== [AC8] ขั้น 4 เก็บผลตรวจรอบก่อน + QA_HISTORY + เตือน FAIL ติดกัน ==="
rm -f "$TD"/QA_* "$TD/EVIDENCE.log" "$WTD"/QA_* "$WTD/EVIDENCE.log"
printf '' > "$TD/PLAN.md"
QAF='mkdir -p .relay/tasks/t1; printf "# QA\nVERDICT: FAIL\n" > .relay/tasks/t1/QA_REPORT.md; printf "{\"verdict\":\"FAIL\",\"failed_criteria\":[\"a\",\"b\",\"c\"],\"tests_run\":[\"x\"],\"summary\":\"s\"}" > .relay/tasks/t1/QA_VERDICT.json'
export QA_ACTION="$QAF"
rs run_phase_4_qa 'b\n' >/dev/null
rs run_phase_4_qa 'b\n' >/dev/null
check '[ -f "$TD/QA_REPORT.before-round-2.md" ] && [ -f "$TD/QA_VERDICT.before-round-2.json" ] && [ -f "$TD/QA_REPORT.md" ]' "รันขั้น 4 ซ้ำ ➔ ผลรอบก่อนถูกเก็บเป็น before-round-2 ไม่ถูกเขียนทับ"
check '[ "$(awk "END{print NR}" "$TD/QA_HISTORY.jsonl")" = "2" ] && grep -q "\"verdict\": \"FAIL\"" "$TD/QA_HISTORY.jsonl" && grep -q "\"failed\": 3" "$TD/QA_HISTORY.jsonl"' "QA_HISTORY.jsonl บันทึกผลทุกรอบพร้อมจำนวนข้อบกพร่อง"
out="$(rs run_phase_4_qa 'b\n')"
check '! printf "%s" "$out" | grep -q "ติดกัน 2 รอบ" && printf "%s" "$out" | grep -q "ตรวจไม่ผ่านติดกัน 3 รอบ" && printf "%s" "$out" | grep -q "3 → 3 → 3"' "FAIL ติดกัน 3 รอบ ➔ เตือนพร้อมแนวโน้มข้อบกพร่องต่อรอบ"
printf '{"verdict":"PASS","source":"json","failed":0}\n{"verdict":"FAIL","source":"json","failed":2}\n' > "$TD/QA_HISTORY.jsonl"
check '[ "$(rs "qa_fail_streak \"\$RELAY_DIR/tasks/t1\"")" = "1|2" ] && [ -z "$(rs "print_qa_streak_warning \"\$RELAY_DIR/tasks/t1\"")" ]' "FAIL หลัง PASS นับใหม่ (1 รอบ) ➔ ไม่เตือน"
export QA_ACTION=':'
rm -f "$TD"/QA_REPORT.md "$TD"/QA_VERDICT.json "$WTD"/QA_REPORT.md "$WTD"/QA_VERDICT.json
before="$(awk 'END{print NR}' "$TD/QA_HISTORY.jsonl")"
rs run_phase_4_qa '' >/dev/null
check '[ "$(awk "END{print NR}" "$TD/QA_HISTORY.jsonl")" = "$before" ]' "@qa ไม่เขียนผล ➔ ไม่บันทึกประวัติปลอม"

echo ""
echo "=================================================================="
echo "สรุปผลชุดทดสอบ Evidence Gate: ผ่าน ${PASS_COUNT} รายการ, ล้มเหลว ${FAIL_COUNT} รายการ"
echo "=================================================================="
[ "$FAIL_COUNT" -eq 0 ]
