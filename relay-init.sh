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
- คำสั่งรันทดสอบ (Unit Tests): \`npm test\` หรือ \`pnpm test\`
- คำสั่งตรวจสอบโครงสร้างโค้ด (Build / Lint): \`npm run build\`
EOF
  echo "✅ สร้างไฟล์ตั้งต้น: $STATE_FILE"
else
  echo "ℹ️ พบไฟล์ $STATE_FILE อยู่แล้ว (ข้ามการเขียนทับ)"
fi

echo "=================================================================="
echo "✅ เตรียมโครงสร้าง .relay/ เสร็จสมบูรณ์!"
echo "📂 ตำแหน่งโฟลเดอร์เอกสาร: $TARGET_ABS/.relay/"
echo "🟣 วิธีเปิดในโปรแกรม Obsidian:"
echo "   เปิดแอป Obsidian -> คลิก 'Open folder as vault' -> เลือกโฟลเดอร์ '$TARGET_ABS/.relay'"
echo "   (หรือเลือกโฟลเดอร์ '$TARGET_ABS' แล้วเปิดตั้งค่า Settings -> Files and links -> Detect all file extensions)"
echo "=================================================================="

if [ "$MODE" = "existing" ]; then
  echo "📌 ขั้นตอนต่อไปสำหรับ [กรณีที่ 2: โครงการเดิมที่มีโค้ดอยู่แล้ว (Brownfield Project)]:"
  echo "   1. เปิด Terminal ในโฟลเดอร์โครงการ: cd \"$TARGET_ABS\""
  echo "   2. เปิดใช้งาน CLI (claude หรือ gemini) แล้วคัดลอกคำสั่งด้านล่างไปสั่งงาน:"
  echo ""
  echo "   \"@arch ช่วยสแกนโครงสร้างโปรเจกต์เดิมทั้งหมด (Tech Stack, โครงสร้างโฟลเดอร์, Database Schema, API และคำสั่งรันเทสต์) แล้วสรุปเขียนทับลงในไฟล์ .relay/PROJECT_STATE.md ให้กระชับไม่เกิน 2 หน้า โดยยังไม่ต้องแก้ไขโค้ดใดๆ\""
else
  echo "📌 ขั้นตอนต่อไปสำหรับ [กรณีที่ 1: เริ่มต้นโครงการใหม่ (Greenfield Project)]:"
  echo "   1. เปิด Terminal ในโฟลเดอร์โครงการ: cd \"$TARGET_ABS\" (และรัน git init -b main หากยังไม่ได้เริ่ม Git)"
  echo "   2. เปิดใช้งาน CLI (gemini หรือ claude) แล้วคัดลอกคำสั่งด้านล่างไปสั่งงาน:"
  echo ""
  echo "   \"@po ฉันกำลังจะสร้างโปรเจกต์ใหม่เกี่ยวกับ [ระบุรายละเอียดโปรเจกต์] ช่วยซักถามความต้องการทีละข้อจนชัดเจน แล้วสรุปเป็นไฟล์ .relay/tasks/$(date +%Y%m%d)-initial-project/SPEC.md\""
fi
echo "=================================================================="
