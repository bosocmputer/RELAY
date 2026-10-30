#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "⚙️ [RELAY Setup] กำลังติดตั้งการตั้งค่าส่วนกลาง (~/.agents/) สำหรับ macOS / Linux..."

# 1. สร้างโฟลเดอร์ส่วนกลางสำหรับทุกค่าย CLI
mkdir -p ~/.agents/skills/playwright-qa ~/.agents/skills/flutter-best-practices ~/.agents/skills/lucide-icons ~/.agents/skills/simple-icons ~/.agents/hooks ~/.agents/bin ~/.claude ~/.codex ~/.gemini

# 2. คัดลอกไฟล์กฎกลาง สกิลตรวจรับงาน สกิล Flutter สกิลมาตรฐานไอคอน และสคริปต์ควบคุมศูนย์กลาง (relay, relay-init, relay-skills)
cp "$SCRIPT_DIR/templates/GLOBAL_AGENTS.md" ~/.agents/GLOBAL_AGENTS.md
cp "$SCRIPT_DIR/templates/playwright-qa-SKILL.md" ~/.agents/skills/playwright-qa/SKILL.md
cp "$SCRIPT_DIR/templates/flutter-best-practices-SKILL.md" ~/.agents/skills/flutter-best-practices/SKILL.md
cp "$SCRIPT_DIR/templates/lucide-icons-SKILL.md" ~/.agents/skills/lucide-icons/SKILL.md
cp "$SCRIPT_DIR/templates/simple-icons-SKILL.md" ~/.agents/skills/simple-icons/SKILL.md
[ -d ~/.agents/skills/founder-plan ] && [ ! -e ~/.agents/skills/founder-skill ] && ln -sf ~/.agents/skills/founder-plan ~/.agents/skills/founder-skill || true
cp "$SCRIPT_DIR/templates/pre-commit" ~/.agents/hooks/pre-commit
cp "$SCRIPT_DIR/skills-manifest.txt" ~/.agents/skills-manifest.txt
cp "$SCRIPT_DIR/relay-init.sh" ~/.agents/bin/relay-init
cp "$SCRIPT_DIR/relay-skills.sh" ~/.agents/bin/relay-skills
cp "$SCRIPT_DIR/relay.sh" ~/.agents/bin/relay

# เชื่อม Symlink คำสั่ง agy (Google AI Ultra / Antigravity CLI) เข้าสู่ ~/.agents/bin หากมีอยู่ใน ~/.gemini/bin/agy
if [ -x "$HOME/.gemini/bin/agy" ]; then
  ln -sf "$HOME/.gemini/bin/agy" ~/.agents/bin/agy
fi

# สร้างหรืออัปเดตไฟล์ตั้งค่าการจับคู่ค่าย AI และโมเดลเริ่มต้น
if [ ! -f ~/.agents/relay-roles.conf ] || ! grep -Fq "MODEL_PO=" ~/.agents/relay-roles.conf 2>/dev/null; then
  cp "$SCRIPT_DIR/templates/relay-roles.conf" ~/.agents/relay-roles.conf
fi

chmod +x ~/.agents/hooks/pre-commit ~/.agents/bin/relay-init ~/.agents/bin/relay-skills ~/.agents/bin/relay \
         "$SCRIPT_DIR/relay.sh" "$SCRIPT_DIR/relay-init.sh" "$SCRIPT_DIR/relay-skills.sh" "$SCRIPT_DIR/templates/install-skills.sh"

# 3. เพิ่ม ~/.agents/bin เข้าสู่ PATH ใน ~/.zshrc และ ~/.bashrc เพื่อให้พิมพ์คำสั่ง relay ได้จากทุกโฟลเดอร์
for rc_file in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$rc_file" ] || [ "$rc_file" = "$HOME/.zshrc" ]; then
    if ! grep -Fq '/.agents/bin' "$rc_file" 2>/dev/null; then
      echo '' >> "$rc_file"
      echo '# RELAY Central Terminal Hub PATH' >> "$rc_file"
      echo 'export PATH="$HOME/.agents/bin:$PATH"' >> "$rc_file"
    fi
  fi
done

# 4. เชื่อม Symlink กฎการทำงานส่วนกลางไปยังทั้ง 3 ค่าย (Claude, Codex, Gemini)
ln -sf ~/.agents/GLOBAL_AGENTS.md ~/.claude/CLAUDE.md
ln -sf ~/.agents/GLOBAL_AGENTS.md ~/.codex/AGENTS.md
ln -sf ~/.agents/GLOBAL_AGENTS.md ~/.gemini/GEMINI.md

# 5. ตั้งค่า Global Git Pre-commit Hook เพื่อตรวจสอบความปลอดภัยก่อน Commit ในทุกโครงการ
git config --global core.hooksPath ~/.agents/hooks

echo "✅ [RELAY Setup] ติดตั้งการตั้งค่าส่วนกลางเสร็จสมบูรณ์!"
echo "   • คำสั่งหน้าจอควบคุมกลาง: ~/.agents/bin/relay (พิมพ์คำว่า 'relay' ได้จากทุกโฟลเดอร์)"
echo "   • ไฟล์จับคู่ตำแหน่งกับค่าย AI: ~/.agents/relay-roles.conf (ตั้งค่าผ่านคำสั่ง 'relay config')"
echo "   • กฎการทำงานส่วนกลาง: ~/.agents/GLOBAL_AGENTS.md (เชื่อมต่อไปยัง ~/.claude, ~/.codex, ~/.gemini)"
echo "   • กลไกป้องกันไฟล์ความลับ: ~/.agents/hooks/pre-commit (เปิดใช้งานระดับ Global)"
echo ""
echo "👉 ขั้นตอนต่อไป:"
echo "   1. โหลด PATH ใหม่ในหน้าต่างปัจจุบัน: source ~/.zshrc"
echo "   2. ตั้งค่าว่าแต่ละตำแหน่ง (@po, @arch, @dev, @qa) จะใช้ AI ค่ายไหน: relay config"
echo "   3. เปิดหน้าจอควบคุมกลางในโปรเจกต์ใดก็ได้: relay"
