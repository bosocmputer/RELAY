#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
MODE="${2:-new}"

mkdir -p "$TARGET_DIR"
TARGET_ABS="$(cd "$TARGET_DIR" && pwd)"
PROJECT_NAME="$(basename "$TARGET_ABS")"

echo "⚙️ [RELAY Init] กำลังเตรียมโครงสร้างระบบ RELAY สำหรับโครงการ: $PROJECT_NAME ($TARGET_ABS)"

# 1. สร้างโครงสร้างโฟลเดอร์ .relay/
mkdir -p "$TARGET_ABS/.relay/tasks" "$TARGET_ABS/.relay/archive"
touch "$TARGET_ABS/.relay/archive/.gitkeep"

# 2. สร้างไฟล์ PROJECT_STATE.md ตั้งต้น (หากยังไม่มี)
STATE_FILE="$TARGET_ABS/.relay/PROJECT_STATE.md"
if [ ! -f "$STATE_FILE" ]; then
  cat << EOF > "$STATE_FILE"
# สถานะปัจจุบันของโครงการ (PROJECT_STATE.md)
- **ชื่อโครงการ:** $PROJECT_NAME
- **วันที่อัปเดตล่าสุด:** $(date +%Y-%m-%d)
- **คำแนะนำ:** เอกสารนี้ใช้เก็บสรุปสถาปัตยกรรม โครงสร้างฐานข้อมูล และรายการ API ล่าสุดของโครงการ (ความยาวไม่เกิน 2 หน้า) เพื่อให้ตัวแทน AI เข้าใจบริบทของระบบโดยไม่ต้องอ่านใบงานเก่าทั้งหมด

## 1. ภาพรวมและเทคโนโลยีที่ใช้ (Tech Stack & Overview)
- (ระบุภาษา เฟรมเวิร์ก และฐานข้อมูลที่ใช้ หรือสั่งให้ @arch สแกนโค้ดเพื่อสรุปข้อมูลลงในส่วนนี้)

## 2. โครงสร้างโมดูลและไฟล์สำคัญ (Core Modules & Architecture)
- (ระบุโฟลเดอร์หลักและหน้าที่ของแต่ละส่วน)

## 3. คำสั่งสำคัญสำหรับการตรวจสอบและทดสอบ (Build & Test Commands)
- โครงการ Web / Node.js: \`npm test\` (หรือ \`pnpm test\`) และ \`npm run build\`
- โครงการ Flutter / Dart: \`flutter analyze\` และ \`flutter test\`
EOF
  echo "✅ สร้างไฟล์ตั้งต้น: $STATE_FILE"
else
  echo "ℹ️ พบไฟล์ $STATE_FILE อยู่แล้ว (ข้ามการเขียนทับ)"
fi

echo "=================================================================="
echo "✅ เตรียมโครงสร้าง .relay/ เสร็จสมบูรณ์!"
echo "📂 ตำแหน่งโฟลเดอร์เอกสาร: $TARGET_ABS/.relay/"
echo "🟣 (ทางเลือกเสริม — ไม่บังคับ) หากต้องการเปิดดูเอกสารใน Obsidian:"
echo "   เปิดแอป Obsidian -> คลิก 'Open folder as vault' -> เลือกโฟลเดอร์ '$TARGET_ABS/.relay'"
echo "=================================================================="

if [ "$MODE" = "existing" ]; then
  echo "📌 ขั้นตอนต่อไปสำหรับ [กรณีที่ 2: โครงการเดิมที่มีโค้ดอยู่แล้ว (Brownfield Project)]:"
  echo "   1. เปิด Terminal ในโฟลเดอร์โครงการ: cd \"$TARGET_ABS\""
  echo "   2. พิมพ์คำสั่ง: relay"
  echo "      (ระบบจะนำทางสแกนสร้าง .relay/PROJECT_STATE.md และเริ่มสั่งงานทั้ง 4 ขั้นตอนให้อัตโนมัติ)"
else
  echo "📌 ขั้นตอนต่อไปสำหรับ [กรณีที่ 1: เริ่มต้นโครงการใหม่ (Greenfield Project)]:"
  echo "   1. เปิด Terminal ในโฟลเดอร์โครงการ: cd \"$TARGET_ABS\""
  echo "   2. พิมพ์คำสั่ง: relay"
  echo "      (กด [1] เพื่อเริ่มคุยกับ @po สร้าง SPEC.md หรือกด [c] เพื่อสลับค่าย/โมเดล AI ได้อิสระ)"
fi
echo "=================================================================="
