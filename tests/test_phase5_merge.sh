#!/usr/bin/env bash
# ทดสอบขั้นตอนที่ 5 (AC-1, AC-2, AC-3) ด้วย git repo ชั่วคราว — ไม่ใช้โควต้า AI
RELAY="$(cd "$(dirname "$0")/.." && pwd)/relay.sh"
T=20261029-demo
pass=0; fail=0
ok()  { echo "  ✅ $1"; pass=$((pass+1)); }
bad() { echo "  ❌ $1"; fail=$((fail+1)); }

setup_repo() {
  local d="$1"
  rm -rf "$d"; mkdir -p "$d"; cd "$d" || exit 1
  git init -q -b main
  echo "base" > app.txt
  git add app.txt && git commit -q -m init
  mkdir -p ".relay/tasks/$T" && echo "# SPEC demo" > ".relay/tasks/$T/SPEC.md"
  echo "state" > .relay/PROJECT_STATE.md
  git worktree add -q ".relay/worktrees/$T" -b "feat/$T"
  mkdir -p ".relay/worktrees/$T/.relay/tasks/$T"
  cp ".relay/tasks/$T/SPEC.md" ".relay/worktrees/$T/.relay/tasks/$T/"
  echo "VERDICT: PASS" > ".relay/worktrees/$T/.relay/tasks/$T/QA_REPORT.md"
}

echo "== AC-1: ไฟล์ค้างไม่ commit ใน Worktree ➔ commit อัตโนมัติแล้วผสาน =="
setup_repo /tmp/relay-m1
echo "feature" > ".relay/worktrees/$T/feature.txt"
printf "c\n" | bash "$RELAY" 5 > /tmp/relay-m1.log 2>&1
[ -f /tmp/relay-m1/feature.txt ] && ok "feature.txt อยู่ใน main" || bad "feature.txt ไม่อยู่ใน main"
git -C /tmp/relay-m1 log --oneline -1 | grep -q "merge: feat/$T" && ok "มี merge commit" || bad "ไม่มี merge commit"
git -C /tmp/relay-m1 ls-files | grep -q "^.relay/" && bad ".relay/ ถูก commit เข้า main" || ok ".relay/ ไม่ถูก commit"
[ ! -d "/tmp/relay-m1/.relay/worktrees/$T" ] && ok "ลบ Worktree หลังผสานสำเร็จ" || bad "Worktree ยังอยู่"
git -C /tmp/relay-m1 show-ref --quiet "refs/heads/feat/$T" && bad "กิ่งยังอยู่" || ok "ลบกิ่งแล้ว"
[ -f "/tmp/relay-m1/.relay/archive/$T/QA_REPORT.md" ] && ok "ใบงานเข้า archive พร้อม QA_REPORT จาก Worktree" || bad "ใบงานไม่อยู่ใน archive"
grep -q '^.relay/worktrees/$' /tmp/relay-m1/.gitignore 2>/dev/null && bad "ไม่ควรแก้ .gitignore ในขั้นตอนที่ 5" || ok ".gitignore ไม่ถูกแตะ"

echo "== AC-2: Merge conflict ➔ ยกเลิก ไม่ลบอะไร =="
setup_repo /tmp/relay-m2
echo "from-branch" > ".relay/worktrees/$T/app.txt"
git -C ".relay/worktrees/$T" commit -q -am "branch change"
echo "from-main" > app.txt && git commit -q -am "main change"
printf "y\n" | bash "$RELAY" 5 > /tmp/relay-m2.log 2>&1
[ -d "/tmp/relay-m2/.relay/worktrees/$T" ] && ok "Worktree ยังอยู่" || bad "Worktree ถูกลบ"
[ -d "/tmp/relay-m2/.relay/tasks/$T" ] && ok "ใบงานยังอยู่ใน tasks/" || bad "ใบงานถูกย้าย"
[ ! -f /tmp/relay-m2/.git/MERGE_HEAD ] && ok "ไม่ค้างสถานะ merge" || bad "ค้างสถานะ merge"
grep -q "from-main" /tmp/relay-m2/app.txt && ok "main ไม่ถูกเปลี่ยน" || bad "main ถูกเปลี่ยน"
grep -q "ผสานโค้ดไม่สำเร็จ" /tmp/relay-m2.log && ok "แจ้งข้อผิดพลาดชัดเจน" || bad "ไม่แจ้งข้อผิดพลาด"

echo "== AC-3: กิ่งไม่มี commit ใหม่ ➔ ไม่ลบ Worktree/กิ่ง =="
setup_repo /tmp/relay-m3
printf "n\n" | bash "$RELAY" 5 > /tmp/relay-m3.log 2>&1
[ -d "/tmp/relay-m3/.relay/worktrees/$T" ] && ok "Worktree ยังอยู่" || bad "Worktree ถูกลบ"
git -C /tmp/relay-m3 show-ref --quiet "refs/heads/feat/$T" && ok "กิ่งยังอยู่" || bad "กิ่งถูกลบ"
grep -q "ไม่มีโค้ดใหม่ให้ผสาน" /tmp/relay-m3.log && ok "แจ้งว่าไม่มีโค้ดใหม่" || bad "ไม่แจ้งเตือน"

echo ""
echo "ผลรวม: ผ่าน $pass • ไม่ผ่าน $fail"
[ "$fail" -eq 0 ]
