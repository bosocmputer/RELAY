#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "⚙️ [RELAY Setup] กำลังติดตั้งการตั้งค่าส่วนกลาง (~/.agents/) สำหรับ macOS / Linux..."

# 1. สร้างโฟลเดอร์ส่วนกลางสำหรับทุกค่าย CLI
mkdir -p ~/.agents/skills/playwright-qa ~/.agents/hooks ~/.agents/bin ~/.claude ~/.codex ~/.gemini

# 2. คัดลอกไฟล์กฎกลาง สกิลตรวจรับงาน และสคริปต์เริ่มต้นโครงการ
cp "$SCRIPT_DIR/templates/GLOBAL_AGENTS.md" ~/.agents/GLOBAL_AGENTS.md
cp "$SCRIPT_DIR/templates/playwright-qa-SKILL.md" ~/.agents/skills/playwright-qa/SKILL.md
cp "$SCRIPT_DIR/templates/pre-commit" ~/.agents/hooks/pre-commit
cp "$SCRIPT_DIR/relay-init.sh" ~/.agents/bin/relay-init
chmod +x ~/.agents/hooks/pre-commit ~/.agents/bin/relay-init "$SCRIPT_DIR/relay-init.sh" "$SCRIPT_DIR/relay-skills.sh" "$SCRIPT_DIR/templates/install-skills.sh"

# 3. เชื่อม Symlink กฎการทำงานส่วนกลางไปยังทั้ง 3 ค่าย (Claude, Codex, Gemini)
ln -sf ~/.agents/GLOBAL_AGENTS.md ~/.claude/CLAUDE.md
ln -sf ~/.agents/GLOBAL_AGENTS.md ~/.codex/AGENTS.md
ln -sf ~/.agents/GLOBAL_AGENTS.md ~/.gemini/GEMINI.md

# 4. ตั้งค่า Global Git Pre-commit Hook เพื่อตรวจสอบความปลอดภัยก่อน Commit ในทุกโครงการ
git config --global core.hooksPath ~/.agents/hooks

echo "✅ [RELAY Setup] ติดตั้งการตั้งค่าส่วนกลางเสร็จสมบูรณ์!"
echo "   • กฎการทำงานส่วนกลาง: ~/.agents/GLOBAL_AGENTS.md (เชื่อมต่อไปยัง ~/.claude, ~/.codex, ~/.gemini)"
echo "   • ทักษะการตรวจสอบ UI: ~/.agents/skills/playwright-qa/SKILL.md"
echo "   • สคริปต์สร้างโครงสร้างโครงการ: ~/.agents/bin/relay-init"
echo "   • กลไกป้องกันไฟล์ความลับ: ~/.agents/hooks/pre-commit (เปิดใช้งานระดับ Global)"
echo ""
echo "👉 ขั้นตอนต่อไป:"
echo "   • ติดตั้งชุดทักษะมาตรฐานครั้งแรก: ./relay-skills.sh install"
echo "   • อัปเดตทักษะทั้งหมดให้เป็นเวอร์ชันล่าสุด: ./relay-skills.sh update"
echo "   • เพิ่มทักษะใหม่เข้าคลัง: ./relay-skills.sh add <github-url>"
