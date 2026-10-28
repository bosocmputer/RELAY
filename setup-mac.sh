#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🏃‍♂️ [RELAY Setup] กำลังตั้งค่าสมองส่วนกลาง (~/.agents/) บนเครื่อง Mac / Linux..."

# 1. สร้างโฟลเดอร์ส่วนกลางสำหรับทุกค่าย CLI
mkdir -p ~/.agents/skills/playwright-qa ~/.agents/hooks ~/.claude ~/.codex ~/.gemini

# 2. คัดลอกไฟล์กฎกลางและสกิลตรวจหน้าเว็บ
cp "$SCRIPT_DIR/templates/GLOBAL_AGENTS.md" ~/.agents/GLOBAL_AGENTS.md
cp "$SCRIPT_DIR/templates/playwright-qa-SKILL.md" ~/.agents/skills/playwright-qa/SKILL.md
cp "$SCRIPT_DIR/templates/pre-commit" ~/.agents/hooks/pre-commit
chmod +x ~/.agents/hooks/pre-commit "$SCRIPT_DIR/relay-skills.sh" "$SCRIPT_DIR/templates/install-skills.sh"

# 3. เชื่อม Symlink ไปยังทั้ง 3 ค่าย (Claude, Codex, Gemini)
ln -sf ~/.agents/GLOBAL_AGENTS.md ~/.claude/CLAUDE.md
ln -sf ~/.agents/GLOBAL_AGENTS.md ~/.codex/AGENTS.md
ln -sf ~/.agents/GLOBAL_AGENTS.md ~/.gemini/GEMINI.md

# 4. ตั้งค่า Global Git Pre-commit Hook เพื่อปกป้องทุกโปรเจกต์ในเครื่อง
git config --global core.hooksPath ~/.agents/hooks

echo "✅ [RELAY Setup] ตั้งค่าส่วนกลางเสร็จสมบูรณ์!"
echo "   • กฎกลาง: ~/.agents/GLOBAL_AGENTS.md (เชื่อมไปยัง ~/.claude, ~/.codex, ~/.gemini แล้ว)"
echo "   • สกิล QA: ~/.agents/skills/playwright-qa/SKILL.md"
echo "   • เกราะป้องกัน .env: ~/.agents/hooks/pre-commit (เปิดใช้ระดับ Global ทุกโปรเจกต์แล้ว)"
echo ""
echo "👉 ขั้นต่อไป:"
echo "   • ติดตั้งชุด Skills ครั้งแรก: ./relay-skills.sh install"
echo "   • อัปเดต Skills ให้ใหม่ล่าสุดเสมอ: ./relay-skills.sh update"
echo "   • เพิ่ม Skill ใหม่เข้าคลัง: ./relay-skills.sh add <github-url>"
