#!/usr/bin/env bash
# ทดสอบขั้นตอนที่ 5 (AC-1, AC-2, AC-3) ด้วย git repo ชั่วคราว — ไม่ใช้โควต้า AI
# แยก HOME ชั่วคราว + CLI จำลอง (agy / codex) จึงไม่เรียก CLI จริงและไม่ขึ้นกับสถานะ Login ของเครื่อง
RELAY="$(cd "$(dirname "$0")/.." && pwd)/relay.sh"
T=20261029-demo
ROOT="$(mktemp -d -t relay-phase5.XXXXXX)"
trap 'rm -rf "$ROOT"' EXIT

export HOME="$ROOT/home"
mkdir -p "$HOME/.gemini/bin" "$HOME/.agents" "$ROOT/stub-bin"
printf '[user]\n\tname = relay-test\n\temail = relay-test@example.com\n' > "$HOME/.gitconfig"
echo "fake-token" > "$HOME/.gemini/jetski-standalone-oauth-token"
printf '#!/bin/sh\nexit 0\n' > "$HOME/.gemini/bin/agy"
printf '#!/bin/sh\n[ "$1 $2" = "login status" ] && echo "Logged in using ChatGPT"\nexit 0\n' > "$HOME/.gemini/bin/codex"
chmod +x "$HOME/.gemini/bin/agy" "$HOME/.gemini/bin/codex"
ln -s "$(command -v python3)" "$ROOT/stub-bin/python3"
export PATH="$ROOT/stub-bin:/usr/bin:/bin:/usr/sbin:/sbin"
unset GIT_CONFIG_GLOBAL XDG_CONFIG_HOME
export GIT_CONFIG_NOSYSTEM=1
pass=0; fail=0
ok()  { echo "  ✅ $1"; pass=$((pass+1)); }
bad() { echo "  ❌ $1"; fail=$((fail+1)); }

setup_repo() {
  local d="$1"
  rm -rf "$d"; mkdir -p "$d"; cd "$d" || exit 1
  git init -q -b main
  echo "base" > app.txt
  git add app.txt && git commit -q -m init
  mkdir -p ".relay/tasks/$T" && printf '# SPEC demo\n- ห้ามแก้ไขโค้ดบนกิ่ง main โดยตรง ต้องทำใน Worktree ของใบงานเสมอ\n- ต้องเขียนชุดทดสอบก่อนส่งงานให้ QA ตรวจรับทุกครั้งที่แก้ไขโค้ด\n' > ".relay/tasks/$T/SPEC.md"
  echo "state" > .relay/PROJECT_STATE.md
  git worktree add -q ".relay/worktrees/$T" -b "feat/$T"
  mkdir -p ".relay/worktrees/$T/.relay/tasks/$T"
  cp ".relay/tasks/$T/SPEC.md" ".relay/worktrees/$T/.relay/tasks/$T/"
  echo "VERDICT: PASS" > ".relay/worktrees/$T/.relay/tasks/$T/QA_REPORT.md"
}

echo "== AC-1: ไฟล์ค้างไม่ commit ใน Worktree ➔ commit อัตโนมัติแล้วผสาน =="
setup_repo $ROOT/m1
echo "feature" > ".relay/worktrees/$T/feature.txt"
printf "c\n" | bash "$RELAY" 5 > $ROOT/m1.log 2>&1
[ -f $ROOT/m1/feature.txt ] && ok "feature.txt อยู่ใน main" || bad "feature.txt ไม่อยู่ใน main"
git -C $ROOT/m1 log --oneline -1 | grep -q "merge: feat/$T" && ok "มี merge commit" || bad "ไม่มี merge commit"
git -C $ROOT/m1 ls-files | grep -q "^.relay/" && bad ".relay/ ถูก commit เข้า main" || ok ".relay/ ไม่ถูก commit"
[ ! -d "$ROOT/m1/.relay/worktrees/$T" ] && ok "ลบ Worktree หลังผสานสำเร็จ" || bad "Worktree ยังอยู่"
git -C $ROOT/m1 show-ref --quiet "refs/heads/feat/$T" && bad "กิ่งยังอยู่" || ok "ลบกิ่งแล้ว"
[ -f "$ROOT/m1/.relay/archive/$T/QA_REPORT.md" ] && ok "ใบงานเข้า archive พร้อม QA_REPORT จาก Worktree" || bad "ใบงานไม่อยู่ใน archive"
grep -q '^.relay/worktrees/$' $ROOT/m1/.gitignore 2>/dev/null && bad "ไม่ควรแก้ .gitignore ในขั้นตอนที่ 5" || ok ".gitignore ไม่ถูกแตะ"
grep -q "\`$T\` — SPEC demo (merge" $ROOT/m1/.relay/PROJECT_STATE.md && ok "บันทึกใบงานลง PROJECT_STATE.md หลังผสาน (F4)" || bad "ไม่มีรายการใน PROJECT_STATE.md"
L="$ROOT/m1/.relay/skills/project-learned"
[ "$(grep -c '^- ' $L/PENDING.md 2>/dev/null)" = "2" ] && ok "กฎที่สกัดเข้าคิว PENDING.md 2 ข้อ (F2)" || bad "PENDING.md ไม่ถูกต้อง"
[ ! -f $L/SKILL.md ] && ok "SKILL.md ยังไม่ถูกสร้างก่อนอนุมัติ" || bad "SKILL.md ถูกสร้างโดยไม่อนุมัติ"
( cd $ROOT/m1 && printf "1\n1\n" | bash "$RELAY" learn > $ROOT/m1-learn.log 2>&1 )
grep -q "ห้ามแก้ไขโค้ดบนกิ่ง main" $L/SKILL.md 2>/dev/null && ok "อนุมัติข้อ 1 ➔ เข้า SKILL.md" || bad "ข้อ 1 ไม่เข้า SKILL.md"
grep -q "ต้องเขียนชุดทดสอบ" $L/SKILL.md 2>/dev/null && bad "ข้อ 2 ไม่ได้อนุมัติแต่เข้า SKILL.md" || ok "ข้อ 2 ที่ไม่อนุมัติไม่เข้า SKILL.md"
grep -q "+ อนุมัติ" $L/LEDGER.md && grep -q -- "- ปฏิเสธ" $L/LEDGER.md && ok "LEDGER บันทึกทั้งอนุมัติและปฏิเสธ" || bad "LEDGER ไม่ครบ"
[ "$(grep -c '^- ' $L/PENDING.md 2>/dev/null)" = "0" ] && ok "คิว PENDING.md ว่างหลังทบทวน" || bad "PENDING.md ไม่ว่าง"

echo "== AC-2: Merge conflict ➔ ยกเลิก ไม่ลบอะไร =="
setup_repo $ROOT/m2
echo "from-branch" > ".relay/worktrees/$T/app.txt"
git -C ".relay/worktrees/$T" commit -q -am "branch change"
echo "from-main" > app.txt && git commit -q -am "main change"
printf "y\n" | bash "$RELAY" 5 > $ROOT/m2.log 2>&1
[ -d "$ROOT/m2/.relay/worktrees/$T" ] && ok "Worktree ยังอยู่" || bad "Worktree ถูกลบ"
[ -d "$ROOT/m2/.relay/tasks/$T" ] && ok "ใบงานยังอยู่ใน tasks/" || bad "ใบงานถูกย้าย"
[ ! -f $ROOT/m2/.git/MERGE_HEAD ] && ok "ไม่ค้างสถานะ merge" || bad "ค้างสถานะ merge"
grep -q "from-main" $ROOT/m2/app.txt && ok "main ไม่ถูกเปลี่ยน" || bad "main ถูกเปลี่ยน"
grep -q "ผสานโค้ดไม่สำเร็จ" $ROOT/m2.log && ok "แจ้งข้อผิดพลาดชัดเจน" || bad "ไม่แจ้งข้อผิดพลาด"

echo "== AC-3: กิ่งไม่มี commit ใหม่ ➔ ไม่ลบ Worktree/กิ่ง =="
setup_repo $ROOT/m3
printf "n\n" | bash "$RELAY" 5 > $ROOT/m3.log 2>&1
[ -d "$ROOT/m3/.relay/worktrees/$T" ] && ok "Worktree ยังอยู่" || bad "Worktree ถูกลบ"
git -C $ROOT/m3 show-ref --quiet "refs/heads/feat/$T" && ok "กิ่งยังอยู่" || bad "กิ่งถูกลบ"
grep -q "ไม่มีโค้ดใหม่ให้ผสาน" $ROOT/m3.log && ok "แจ้งว่าไม่มีโค้ดใหม่" || bad "ไม่แจ้งเตือน"

echo ""
echo "ผลรวม: ผ่าน $pass • ไม่ผ่าน $fail"
[ "$fail" -eq 0 ]
