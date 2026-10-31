#!/usr/bin/env bash
# ทดสอบการแสดงผลโควต้า: นับถอยหลัง, เลยเวลารีเซ็ต, แคชเก่าไม่มี epoch, ค่ายที่ดึงข้อมูลไม่ได้ — ไม่ใช้โควต้า AI
RELAY="$(cd "$(dirname "$0")/.." && pwd)/relay.sh"
ROOT="$(mktemp -d -t relay-quota-test.XXXXXX)"
trap 'rm -rf "$ROOT"' EXIT
pass=0; fail=0
ok()  { echo "  ✅ $1"; pass=$((pass+1)); }
bad() { echo "  ❌ $1"; fail=$((fail+1)); }

rm -rf "$ROOT"; mkdir -p "$ROOT/home/.agents" "$ROOT/proj"
N=$(date +%s)
cat > "$ROOT/home/.agents/relay-quota.cache" <<EOF
QUOTA_UPDATED_EPOCH="$N"
QUOTA_UPDATED_AT="$(date +%H:%M:%S)"
AGY_GEMINI_5H_REM="81"
AGY_GEMINI_5H_RESET="20:27"
AGY_GEMINI_5H_RESET_EPOCH="$((N+5220))"
AGY_GEMINI_7D_REM="49"
AGY_GEMINI_7D_RESET="31 ต.ค. 08:10"
AGY_GEMINI_7D_RESET_EPOCH="$((N+133200))"
AGY_CLAUDE_5H_REM="40"
AGY_CLAUDE_5H_RESET="18:59"
AGY_CLAUDE_5H_RESET_EPOCH="$((N-60))"
AGY_CLAUDE_7D_REM="99"
AGY_CLAUDE_7D_RESET="05 พ.ย. 09:53"
AGY_CLAUDE_7D_RESET_EPOCH="-"
AGY_FETCH_OK="1"
CODEX_PLAN="Plus"
CODEX_5H_REM="15"
CODEX_5H_RESET="19:06"
CODEX_5H_RESET_EPOCH="$((N+300))"
CODEX_7D_REM="61"
CODEX_7D_RESET="04 พ.ย. 14:17"
CODEX_7D_RESET_EPOCH="$((N+500000))"
CLAUDE_PLAN="Pro"
CLAUDE_5H_REM="100"
CLAUDE_5H_RESET="พร้อมใช้"
CLAUDE_5H_RESET_EPOCH="-"
CLAUDE_7D_REM="13"
CLAUDE_7D_RESET="30 ต.ค. 15:00"
CLAUDE_7D_RESET_EPOCH="$((N+73140))"
CLAUDE_FETCH_OK="0"
CLAUDE_FETCHED_AT="18:35"
EOF

out="$(cd "$ROOT/proj" && HOME="$ROOT/home" bash "$RELAY" status < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
echo "$out" | grep -q "agy (Gemini).*อีก 1ชม.2[67]น. (20:27)" && ok "นับถอยหลัง 5 ชั่วโมง" || bad "นับถอยหลัง 5 ชั่วโมงไม่ถูกต้อง"
echo "$out" | grep -q "อีก 1วัน 1[23]ชม. (31 ต.ค. 08:10)" && ok "นับถอยหลังรายสัปดาห์เป็นวัน" || bad "นับถอยหลังรายสัปดาห์ไม่ถูกต้อง"
echo "$out" | grep -q "agy (Claude/GPT).*100% ↻ รีเซ็ตแล้ว" && ok "เลยเวลารีเซ็ต ➔ 100% และ ↻ รีเซ็ตแล้ว" || bad "กรณีเลยเวลารีเซ็ตไม่ถูกต้อง"
echo "$out" | grep -q "รีเซ็ต 05 พ.ย. 09:53" && ok "แคชเก่าไม่มี epoch ➔ แสดงเวลารีเซ็ตแบบเดิม" || bad "แคชเก่าแสดงผลผิด"
echo "$out" | grep -q "claude (Pro).*? 100% ดึงไม่ได้ • ค่าเมื่อ 18:35" && ok "ค่ายที่ดึงไม่ได้แสดง ? และเวลาของค่าล่าสุด (F7)" || bad "ไม่แสดงสถานะดึงไม่ได้"
echo "$out" | grep -q "อัปเดต .* (เมื่อสักครู่)" && ok "แสดงอายุข้อมูล" || bad "ไม่แสดงอายุข้อมูล"

echo ""
echo "ผลรวม: ผ่าน $pass • ไม่ผ่าน $fail"
[ "$fail" -eq 0 ]
