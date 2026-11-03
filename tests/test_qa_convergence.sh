#!/usr/bin/env bash
# ชุดทดสอบใบงาน 20261103-qa-convergence: ตัดสินตามระดับความร้ายแรง • รอบแก้ตรวจเฉพาะ diff • ใช้ EVIDENCE ก่อน • หยุดเมื่อไม่ลู่เข้า
# ไม่ใช้โควต้า AI: แยก HOME ชั่วคราว และแทนฟังก์ชันที่เปิด agent ด้วยตัวจำลอง
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELAY_SH="$REPO_ROOT/relay.sh"
VERIFY_SH="$REPO_ROOT/templates/scripts/verify-relay-task.sh"

TMP_ROOT="$(mktemp -d -t relay-qa-convergence.XXXXXX)"
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
TD="$P/.relay/tasks/t1"
WT="$P/.relay/worktrees/t1"
mkdir -p "$TD" "$WT/.relay/tasks/t1"
printf '# spec\n- [ ] AC1\n' > "$TD/SPEC.md"
git -C "$WT" init -q -b feat && git -C "$WT" commit -q --allow-empty -m c1
C1="$(git -C "$WT" rev-parse --short HEAD)"

STUBS='require_all_roles_ready(){ :; }; ensure_or_create_task(){ :; }; check_role_quota_safe(){ :; }; ensure_qa_playwright_mcp(){ :; };
launch_provider_cli(){ printf "PROMPT<<%s>>\n" "$5"; eval "${QA_ACTION:-}"; }'
rs() { (cd "$P" && printf "${2:-}" | RELAY_SOURCE_ONLY=1 bash -c "source \"$RELAY_SH\"; $STUBS; PROJECT_DIR=\"\$PWD\"; refresh_project_paths; ACTIVE_TASK=t1; $1") 2>&1 | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g'; }
verdict() { printf '%s' "$1" > "$TD/QA_VERDICT.json"; rs 'qa_verdict "$RELAY_DIR/tasks/t1"'; }

echo "=== [AC1/AC2] สคริปต์ตัดสินจากระดับความร้ายแรง ==="
check '[ "$(verdict '"'"'{"verdict":"FAIL","findings":[{"severity":"high","issue":"ข้าม tenant","repro":"psql -f t.sql"}],"follow_ups":[],"tests_run":["x"],"summary":"s"}'"'"')" = "FAIL|json" ]' "high ที่มี repro ➔ FAIL"
check '[ "$(verdict '"'"'{"verdict":"FAIL","findings":[{"severity":"critical","issue":"a","repro":"curl"},{"severity":"low","issue":"b"}],"tests_run":["x"],"summary":"s"}'"'"')" = "FAIL|json" ]' "critical ที่มี repro ➔ FAIL"
check '[ "$(verdict '"'"'{"verdict":"FAIL","findings":[{"severity":"high","issue":"อ่านโค้ดแล้วน่าจะผิด","repro":""},{"severity":"medium","issue":"m"}],"follow_ups":["f"],"tests_run":["pnpm test"],"summary":"s"}'"'"')" = "PASS|severity" ]' "@qa เขียน FAIL แต่ high ไม่มี repro + medium ➔ PASS|severity (ไม่มีวิธีพิสูจน์ = งานภายหลัง)"
check 'rs "verdict_source_note severity" | grep -q "ระดับความร้ายแรง"' "แสดงเหตุผลเมื่อสคริปต์ตัดสินต่างจาก @qa"
check '[ "$(verdict '"'"'{"verdict":"PASS","findings":[],"follow_ups":[],"tests_run":[],"summary":"s"}'"'"')" = "FAIL|no-tests" ]' "ไม่มีข้อที่บล็อกแต่ไม่มีหลักฐานเทสต์เลย ➔ FAIL|no-tests"
printf 'RESULT: PASS (0/1 ไม่ผ่าน)\n' > "$TD/EVIDENCE.log"
check '[ "$(verdict '"'"'{"verdict":"FAIL","findings":[],"follow_ups":[],"tests_run":[],"summary":"sandbox รัน test:db ไม่ได้"}'"'"')" = "PASS|severity" ]' "@qa รันใน sandbox ไม่ได้ (tests_run ว่าง) แต่ EVIDENCE.log ผ่าน ➔ PASS"
printf 'RESULT: FAIL (1/1 ไม่ผ่าน)\n' > "$TD/EVIDENCE.log"
check '[ "$(verdict '"'"'{"verdict":"PASS","findings":[{"severity":"low","issue":"l"}],"tests_run":["x"],"summary":"s"}'"'"')" = "FAIL|evidence" ]' "EVIDENCE.log ไม่ผ่าน ➔ FAIL|evidence เหมือนเดิม"
rm -f "$TD/EVIDENCE.log"
check '[ "$(verdict '"'"'{"verdict":"FAIL","failed_criteria":["x"],"tests_run":["x"],"summary":"s"}'"'"')" = "FAIL|json" ] && [ "$(verdict '"'"'{"verdict":"PASS","failed_criteria":[],"tests_run":["x"],"summary":"s"}'"'"')" = "PASS|json" ] && [ "$(verdict '"'"'{"verdict":"PASS","failed_criteria":[],"tests_run":["fast-track"],"summary":"s"}'"'"')" = "PASS|self" ]' "รูปแบบเดิม (failed_criteria / Fast Track) ทำงานเหมือนเดิม"
verdict '{"verdict":"PASS","findings":[{"severity":"high","issue":"h"},{"severity":"low","issue":"l"}],"follow_ups":["a","b"],"tests_run":["x"],"summary":"s"}' >/dev/null
check '[ "$(rs "qa_followup_count \"\$RELAY_DIR/tasks/t1\"")" = "4" ]' "นับงานภายหลัง = follow_ups + findings ที่ไม่บล็อก"
out="$(rs 'offer_next_step 4' 'b\n')"
check 'printf "%s" "$out" | grep -q "งานภายหลัง 4 ข้อ"' "ผ่านแล้วแสดงจำนวนงานภายหลังในเมนูถัดไป"

echo "=== [AC3/AC4] prompt ของ @qa: ใช้ EVIDENCE ก่อน • รอบแรกตรวจทั้งงาน • รอบแก้ตรวจเฉพาะ diff ==="
contract="$(rs get_qa_prompt_contract)"
check 'printf "%s" "$contract" | grep -q "\"findings\"" && printf "%s" "$contract" | grep -q "sandbox" && printf "%s" "$contract" | grep -q "EVIDENCE.log ของ RELAY ผ่านให้ใช้ผลนั้น" && printf "%s" "$contract" | grep -q "FAIL เฉพาะเมื่อมี critical/high ที่มี repro"' "สัญญาผลตรวจ: findings + severity + repro และข้อจำกัด sandbox ไม่ใช่ข้อบกพร่อง"
rm -f "$TD/QA_HISTORY.jsonl" "$TD/QA_VERDICT.json"
check 'rs "get_qa_scope_note \"\$RELAY_DIR/tasks/t1\" \"$WT\"" | grep -q "รายงานข้อบกพร่องทั้งหมดที่พบในรอบเดียว"' "ยังไม่มีประวัติ ➔ ตรวจทั้งงานและรายงานทุกข้อในรอบเดียว"
# รอบที่ 1 FAIL ➔ บันทึก commit ที่ตรวจ
export QA_ACTION='mkdir -p .relay/tasks/t1; printf "{\"verdict\":\"FAIL\",\"findings\":[{\"severity\":\"high\",\"issue\":\"a\",\"repro\":\"r\"},{\"severity\":\"low\",\"issue\":\"b\"}],\"follow_ups\":[\"c\"],\"tests_run\":[\"x\"],\"summary\":\"s\"}" > .relay/tasks/t1/QA_VERDICT.json'
out1="$(rs run_phase_4_qa 'b\n')"
check 'grep -q "\"head\": \"$C1\"" "$TD/QA_HISTORY.jsonl" && grep -q "\"blocking\": 1" "$TD/QA_HISTORY.jsonl" && grep -q "\"follow_ups\": 2" "$TD/QA_HISTORY.jsonl"' "QA_HISTORY บันทึก commit ที่ตรวจ จำนวนข้อที่บล็อก และงานภายหลัง"
check 'printf "%s" "$out1" | grep -q "รายงานข้อบกพร่องทั้งหมดที่พบในรอบเดียว"' "prompt รอบแรกของขั้น 4 ให้ตรวจทั้งงาน"
git -C "$WT" commit -q --allow-empty -m c2
out2="$(rs run_phase_4_qa 'b\n')"
check 'printf "%s" "$out2" | grep -q "git diff $C1..HEAD" && printf "%s" "$out2" | grep -q "ไม่ต้องตรวจทั้งแอปใหม่" && printf "%s" "$out2" | grep -q "carry_over"' "รอบแก้ไข ➔ prompt ให้ตรวจเฉพาะ git diff ตั้งแต่ commit ที่ QA ตรวจล่าสุด และยืนยันข้อเดิม"
printf '{"verdict":"PASS","head":"%s"}\n' "$C1" >> "$TD/QA_HISTORY.jsonl"
check 'rs "get_qa_scope_note \"\$RELAY_DIR/tasks/t1\" \"$WT\"" | grep -q "ตรวจทั้งงาน"' "รอบก่อน PASS ➔ กลับมาตรวจทั้งงาน"
printf '{"verdict":"FAIL","head":"deadbee"}\n' >> "$TD/QA_HISTORY.jsonl"
check 'rs "get_qa_scope_note \"\$RELAY_DIR/tasks/t1\" \"$WT\"" | grep -q "ตรวจทั้งงาน"' "commit ในประวัติหาไม่เจอ (เช่น rebase) ➔ ตรวจทั้งงานแทน ไม่ส่ง diff ผิด"

echo "=== [AC5] หยุดเมื่อไม่ลู่เข้า ==="
nc() { printf "$1" > "$TD/QA_HISTORY.jsonl"; rs 'qa_nonconverging "$RELAY_DIR/tasks/t1" && echo YES || echo NO'; }
check '[ "$(nc '"'"'{"verdict":"FAIL","blocking":2}\n{"verdict":"FAIL","blocking":1}\n{"verdict":"FAIL","blocking":2}\n'"'"')" = "YES" ]' "FAIL 3 รอบ ข้อที่บล็อก 2 → 1 → 2 (ไม่ลดลง) ➔ ไม่ลู่เข้า"
check '[ "$(nc '"'"'{"verdict":"FAIL","blocking":3}\n{"verdict":"FAIL","blocking":2}\n{"verdict":"FAIL","blocking":1}\n'"'"')" = "NO" ]' "ข้อที่บล็อก 3 → 2 → 1 (ลดลง) ➔ ยังลู่เข้า"
check '[ "$(nc '"'"'{"verdict":"FAIL","blocking":2}\n{"verdict":"FAIL","blocking":2}\n'"'"')" = "NO" ] && [ "$(nc '"'"'{"verdict":"FAIL","blocking":2}\n{"verdict":"PASS","blocking":0}\n{"verdict":"FAIL","blocking":2}\n'"'"')" = "NO" ]' "น้อยกว่า 3 รอบ หรือมี PASS คั่น ➔ ไม่ถือว่าไม่ลู่เข้า"
check '[ "$(nc '"'"'{"verdict":"FAIL","failed":2}\n{"verdict":"FAIL","failed":2}\n{"verdict":"FAIL","failed":2}\n'"'"')" = "YES" ]' "ประวัติแบบเดิม (failed) ใช้นับได้"
nc '{"verdict":"FAIL","blocking":2}\n{"verdict":"FAIL","blocking":1}\n{"verdict":"FAIL","blocking":2}\n' >/dev/null
verdict '{"verdict":"FAIL","findings":[{"severity":"high","issue":"a","repro":"r"}],"tests_run":["x"],"summary":"s"}' >/dev/null
out="$(rs 'offer_next_step 4' 'b\n')"
check 'printf "%s" "$out" | grep -q "ข้อที่บล็อกไม่ลดลงใน 3 รอบล่าสุด" && printf "%s" "$out" | grep -q "❯ \[s\] ★ หยุดวนก่อน" && printf "%s" "$out" | grep -q "ข้อที่บล็อกต่อรอบ : 2 → 1 → 2"' "ไม่ลู่เข้า ➔ ค่าเริ่มต้นคือหยุดวน ไม่ใช่ส่ง @dev ซ้ำ และแสดงแนวโน้มข้อที่บล็อก"

echo "=== [AC6] relay-verify-task รับรูปแบบใหม่ ==="
V="$TMP_ROOT/vproj"; mkdir -p "$V/.relay/tasks/t1"; git -C "$V" init -q -b main; printf '# spec\n' > "$V/.relay/tasks/t1/SPEC.md"
# เก็บผลลงตัวแปรก่อน grep (pipefail + exit 1 ของสคริปต์ตรวจ ทำให้ pipeline ล้มเอง)
vt() { printf '%s' "$1" > "$V/.relay/tasks/t1/QA_VERDICT.json"; VT_OUT="$(cd "$V" && bash "$VERIFY_SH" .relay/tasks/t1 2>&1)"; printf '%s\n' "$VT_OUT"; }
check 'vt_out=$(vt '"'"'{"verdict":"PASS","findings":[{"severity":"medium","issue":"m"}],"follow_ups":["f"],"tests_run":["x"],"summary":"s"}'"'"'); printf "%s" "$vt_out" | grep -q "blocking=0, findings=1"' "รูปแบบใหม่ที่ถูกต้อง ➔ ผ่าน และบอกจำนวนข้อที่บล็อก"
check 'vt_out=$(vt '"'"'{"verdict":"PASS","findings":[{"severity":"high","issue":"h","repro":"r"}],"tests_run":["x"],"summary":"s"}'"'"'); printf "%s" "$vt_out" | grep -q "CONTRADICTION"' "PASS แต่มี high ที่มี repro ➔ แจ้งขัดแย้ง"
check 'vt_out=$(vt '"'"'{"verdict":"FAIL","findings":[{"severity":"urgent","issue":"x"}],"tests_run":["x"],"summary":"s"}'"'"'); printf "%s" "$vt_out" | grep -q "BAD_FINDING"' "severity ไม่ถูกต้อง ➔ แจ้งรูปแบบผิด"
check 'vt_out=$(vt '"'"'{"verdict":"FAIL","failed_criteria":["x"],"tests_run":["x"],"summary":"s"}'"'"'); printf "%s" "$vt_out" | grep -q "OK:FAIL\|โครงสร้างถูกต้อง"' "รูปแบบเดิมยังผ่านการตรวจ"

echo "=== [AC6] สกัดบทเรียนอ่าน findings ได้ ==="
printf '{"verdict":"FAIL","findings":[{"severity":"high","issue":"ลืมตรวจ tenant ของโต๊ะใน open_bill","repro":"sql"},{"severity":"low","issue":"ชื่อตัวแปร"}],"tests_run":["x"],"summary":"s"}' > "$TD/QA_VERDICT.before-round-2.json"
printf '{"verdict":"PASS","findings":[],"tests_run":["x"],"summary":"เพิ่มการตรวจ tenant"}' > "$TD/QA_VERDICT.json"
rs 'distill_project_learned_skills t1 auto' >/dev/null
check 'grep -rq "ลืมตรวจ tenant ของโต๊ะใน open_bill" "$P/.relay/skills/project-learned/PENDING.md" && ! grep -rq "ชื่อตัวแปร" "$P/.relay/skills/project-learned/PENDING.md"' "บทเรียนมาจาก finding ระดับ high เท่านั้น ไม่เอาข้อ low"

echo ""
echo "=================================================================="
echo "สรุปผลชุดทดสอบ QA Convergence: ผ่าน ${PASS_COUNT} รายการ, ล้มเหลว ${FAIL_COUNT} รายการ"
echo "=================================================================="
[ "$FAIL_COUNT" -eq 0 ]
