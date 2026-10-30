#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/skills-manifest.txt" ]; then
  MANIFEST_FILE="$SCRIPT_DIR/skills-manifest.txt"
  QA_TEMPLATE="$SCRIPT_DIR/templates/playwright-qa-SKILL.md"
else
  MANIFEST_FILE="$HOME/.agents/skills-manifest.txt"
  QA_TEMPLATE="$HOME/.agents/skills/playwright-qa/SKILL.md"
fi

show_help() {
  echo "=================================================================="
  echo "🧰 RELAY Skill Manager (สำหรับ macOS / Linux)"
  echo "=================================================================="
  echo "คำสั่งที่รองรับ:"
  echo "  ./relay-skills.sh install                     # ติดตั้งชุด Skills มาตรฐานทั้งหมด + Playwright MCP"
  echo "  ./relay-skills.sh update                      # ดึงอัปเดตเวอร์ชันใหม่ล่าสุดจากผู้พัฒนาต้นทางทุกตัว"
  echo "  ./relay-skills.sh add <repo_url> [skill_name] # เพิ่มสกิลใหม่เข้าเครื่องและบันทึกลง skills-manifest.txt"
  echo "  ./relay-skills.sh list                        # แสดงรายการสกิลทั้งหมดในคลัง"
  echo "=================================================================="
}

sync_manifest_skills() {
  local mode_label="$1"
  echo "🚀 [RELAY Skills] กำลัง${mode_label}ชุด Skills จาก skills-manifest.txt..."

  while IFS='|' read -r repo skill desc || [ -n "$repo" ]; do
    # ข้ามบรรทัดว่างหรือคอมเมนต์
    [[ -z "$repo" || "$repo" =~ ^[[:space:]]*# ]] && continue

    echo "------------------------------------------------------------------"
    echo "📦 ${desc:-Skill}: $repo ${skill:+(skill: $skill)}"
    if [ -n "$skill" ]; then
      npx -y skills add "$repo" --skill "$skill" -g -y < /dev/null
    else
      npx -y skills add "$repo" -g -y < /dev/null
    fi
  done < "$MANIFEST_FILE"

  # คัดลอกสกิล playwright-qa, flutter-best-practices และสกิลมาตรฐานไอคอน (lucide-icons, simple-icons) ของ RELAY ให้เป็นเวอร์ชันล่าสุดเสมอ
  mkdir -p ~/.agents/skills/playwright-qa ~/.agents/skills/flutter-best-practices ~/.agents/skills/lucide-icons ~/.agents/skills/simple-icons
  if [ -f "$QA_TEMPLATE" ] && [ "$QA_TEMPLATE" != "$HOME/.agents/skills/playwright-qa/SKILL.md" ]; then
    cp "$QA_TEMPLATE" ~/.agents/skills/playwright-qa/SKILL.md
  fi
  [ -f "$SCRIPT_DIR/templates/flutter-best-practices-SKILL.md" ] && cp "$SCRIPT_DIR/templates/flutter-best-practices-SKILL.md" ~/.agents/skills/flutter-best-practices/SKILL.md || true
  [ -f "$SCRIPT_DIR/templates/lucide-icons-SKILL.md" ] && cp "$SCRIPT_DIR/templates/lucide-icons-SKILL.md" ~/.agents/skills/lucide-icons/SKILL.md || true
  [ -f "$SCRIPT_DIR/templates/simple-icons-SKILL.md" ] && cp "$SCRIPT_DIR/templates/simple-icons-SKILL.md" ~/.agents/skills/simple-icons/SKILL.md || true
  [ -d ~/.agents/skills/founder-plan ] && [ ! -e ~/.agents/skills/founder-skill ] && ln -sf ~/.agents/skills/founder-plan ~/.agents/skills/founder-skill || true

  # ผูก Playwright MCP เข้ากับ CLI (หากมี claude หรือ codex ในเครื่อง)
  if command -v claude >/dev/null 2>&1; then
    echo "🔌 ตรวจสอบ/ผูก Playwright MCP เข้ากับ Claude Code..."
    claude mcp add -s user playwright npx @playwright/mcp@latest 2>/dev/null || true
  fi

  if command -v codex >/dev/null 2>&1; then
    echo "🔌 ตรวจสอบ/ผูก Playwright MCP เข้ากับ Codex CLI..."
    codex mcp add playwright -- npx @playwright/mcp@latest 2>/dev/null || true
  fi

  echo "=================================================================="
  echo "✅ [RELAY Skills] ${mode_label}เสร็จสมบูรณ์! ทุกสกิลเป็นเวอร์ชันล่าสุดแล้ว"
}

COMMAND="${1:-help}"

case "$COMMAND" in
  install)
    sync_manifest_skills "ติดตั้ง"
    ;;
  update)
    sync_manifest_skills "อัปเดตเวอร์ชันล่าสุดของ"
    ;;
  add)
    REPO_URL="$2"
    SKILL_NAME="$3"
    DESC="${4:-[Custom Skill] สกิลเพิ่มเติมโดยผู้ใช้}"
    if [ -z "$REPO_URL" ]; then
      echo "❌ กรุณาระบุลิงก์ GitHub Repo เช่น: ./relay-skills.sh add https://github.com/owner/repo [ชื่อสกิล]"
      exit 1
    fi
    echo "➕ กำลังติดตั้งสกิลใหม่จาก: $REPO_URL ${SKILL_NAME:+(skill: $SKILL_NAME)}..."
    if [ -n "$SKILL_NAME" ]; then
      npx -y skills add "$REPO_URL" --skill "$SKILL_NAME" -g
    else
      npx -y skills add "$REPO_URL" -g
    fi
    # บันทึกลง skills-manifest.txt หากยังไม่มี
    ENTRY="${REPO_URL}|${SKILL_NAME}|${DESC}"
    if ! grep -Fq "${REPO_URL}|${SKILL_NAME}|" "$MANIFEST_FILE"; then
      echo "$ENTRY" >> "$MANIFEST_FILE"
      echo "📝 บันทึกสกิลนี้ลงใน skills-manifest.txt เรียบร้อย (จะถูกอัปเดตอัตโนมัติเมื่อรัน ./relay-skills.sh update)"
    fi
    echo "✅ เพิ่มสกิลใหม่สำเร็จ!"
    ;;
  list)
    echo "📋 รายการ Skills ใน skills-manifest.txt:"
    echo "------------------------------------------------------------------"
    grep -v '^[[:space:]]*#' "$MANIFEST_FILE" | grep -v '^[[:space:]]*$' | awk -F'|' '{printf "  • %-32s (%s)\n    Repo: %s\n", ($2 ? $2 : "ทั้ง Repo"), $3, $1}'
    echo "------------------------------------------------------------------"
    if [ -d ~/.agents/skills ]; then
      echo "📂 โฟลเดอร์สกิลที่ติดตั้งแล้วในเครื่อง (~/.agents/skills/):"
      ls -1 ~/.agents/skills
    fi
    ;;
  *)
    show_help
    ;;
esac
