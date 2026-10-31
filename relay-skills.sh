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

# ล็อกเวอร์ชันแพ็กเกจที่ npx ดาวน์โหลดมารัน (ไม่ใช้ latest แบบไม่ระบุ) • ปรับได้ผ่านตัวแปรสภาพแวดล้อม
SKILLS_CLI_PKG="${RELAY_SKILLS_CLI_PKG:-skills@1.7.4}"
PLAYWRIGHT_MCP_PKG="${RELAY_PLAYWRIGHT_MCP_PKG:-@playwright/mcp@0.0.83}"

show_help() {
  echo "=================================================================="
  echo "🧰 RELAY Skill Manager (สำหรับ macOS / Linux)"
  echo "=================================================================="
  echo "คำสั่งที่รองรับ:"
  echo "  ./relay-skills.sh install                                   # ติดตั้งชุด Skills มาตรฐาน + Script Tools + Playwright MCP"
  echo "  ./relay-skills.sh update                                    # ดึงอัปเดตเวอร์ชันใหม่ล่าสุดจากผู้พัฒนาต้นทางทุกตัว"
  echo "  ./relay-skills.sh add <repo_url> [skill_name]               # เพิ่มสกิลใหม่เข้าเครื่องและบันทึกลง skills-manifest.txt"
  echo "  ./relay-skills.sh create <skill_name> [desc] [target_dir]   # สร้างโฟลเดอร์ Skill มาตรฐาน (SKILL.md + scripts/)"
  echo "  ./relay-skills.sh list                                      # แสดงรายการสกิลทั้งหมดพร้อมสารบัญ Progressive Disclosure"
  echo "=================================================================="
}

scaffold_skill_folder() {
  local raw_name="${1:-}"
  local desc="${2:-ความเชี่ยวชาญและขั้นตอนมาตรฐานสำหรับงานเฉพาะทางในโปรเจกต์นี้}"
  local base_dir="${3:-$(pwd)/.relay/skills}"
  local slug
  slug="$(printf "%s" "$raw_name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_-' '-' | sed -E 's/^-+|-+$//g')"
  if [ -z "$slug" ]; then
    echo "❌ กรุณาระบุชื่อสกิลภาษาอังกฤษ เช่น: ./relay-skills.sh create api-contract-check \"ตรวจสอบโครงสร้าง API\""
    exit 1
  fi
  local skill_dir="${base_dir%/}/$slug"
  mkdir -p "$skill_dir/scripts"

  local skill_md="$skill_dir/SKILL.md"
  if [ ! -f "$skill_md" ]; then
    local tmp_md="${skill_md}.tmp.$$"
    {
      printf -- "---\n"
      printf -- "name: %s\n" "$slug"
      printf -- "description: %s\n" "$desc"
      printf -- "---\n\n"
      printf -- "# ทักษะเฉพาะทาง: %s\n\n" "$slug"
      printf -- "## 1. เมื่อไหร่ควรเปิดใช้ทักษะนี้ (When to Use — Progressive Disclosure)\n"
      printf -- "- เปิดอ่านไฟล์นี้เฉพาะเมื่อได้รับมอบหมายงานที่เกี่ยวข้องกับ: %s\n\n" "$desc"
      printf -- "## 2. ขั้นตอนการปฏิบัติมาตรฐาน (Procedural Knowledge)\n"
      printf -- "- ตรวจสอบโครงสร้างโค้ดและข้อกำหนดที่เกี่ยวข้องก่อนแก้ไข\n"
      printf -- "- รันสคริปต์ช่วยตรวจสอบในโฟลเดอร์ \`scripts/\` เพื่อลดการเขียนคำสั่งซ้ำด้วยมือ\n\n"
      printf -- "## 3. เครื่องมือสคริปต์ประจำทักษะ (Scripts as Tools)\n"
      printf -- "- \`bash %s/scripts/run-check.sh\` — สคริปต์ตรวจสอบอัตโนมัติของทักษะนี้\n" "$skill_dir"
    } > "$tmp_md"
    mv -f "$tmp_md" "$skill_md"
  fi

  local script_file="$skill_dir/scripts/run-check.sh"
  if [ ! -f "$script_file" ]; then
    cat <<'EOF' > "$script_file"
#!/usr/bin/env bash
# สคริปต์ตรวจสอบประจำ Skill (Scripts as Tools — เรียกใช้ซ้ำได้โดยไม่ต้องให้ AI เขียนคำสั่งใหม่ทุกครั้ง)
set -euo pipefail
echo "● [Skill Script] รันการตรวจสอบอัตโนมัติสำเร็จ"
EOF
    chmod +x "$script_file"
  fi

  echo "✅ สร้างโครงสร้าง Skill มาตรฐานเรียบร้อย: $skill_dir"
  echo "   • เอกสารขั้นตอน : $skill_md"
  echo "   • สคริปต์เครื่องมือ: $script_file"
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
      npx -y "$SKILLS_CLI_PKG" add "$repo" --skill "$skill" -g -y < /dev/null
    else
      npx -y "$SKILLS_CLI_PKG" add "$repo" -g -y < /dev/null
    fi
  done < "$MANIFEST_FILE"

  # คัดลอกสกิล playwright-qa, flutter-best-practices และสกิลมาตรฐานไอคอน (lucide-icons, simple-icons) ของ RELAY ให้เป็นเวอร์ชันล่าสุดเสมอ
  mkdir -p ~/.agents/skills/relay-roles ~/.agents/skills/playwright-qa ~/.agents/skills/flutter-best-practices ~/.agents/skills/lucide-icons ~/.agents/skills/simple-icons
  if [ -f "$QA_TEMPLATE" ] && [ "$QA_TEMPLATE" != "$HOME/.agents/skills/playwright-qa/SKILL.md" ]; then
    cp "$QA_TEMPLATE" ~/.agents/skills/playwright-qa/SKILL.md
  fi
  [ -f "$SCRIPT_DIR/templates/relay-roles-SKILL.md" ] && cp "$SCRIPT_DIR/templates/relay-roles-SKILL.md" ~/.agents/skills/relay-roles/SKILL.md || true
  [ -f "$SCRIPT_DIR/templates/flutter-best-practices-SKILL.md" ] && cp "$SCRIPT_DIR/templates/flutter-best-practices-SKILL.md" ~/.agents/skills/flutter-best-practices/SKILL.md || true
  [ -f "$SCRIPT_DIR/templates/lucide-icons-SKILL.md" ] && cp "$SCRIPT_DIR/templates/lucide-icons-SKILL.md" ~/.agents/skills/lucide-icons/SKILL.md || true
  [ -f "$SCRIPT_DIR/templates/simple-icons-SKILL.md" ] && cp "$SCRIPT_DIR/templates/simple-icons-SKILL.md" ~/.agents/skills/simple-icons/SKILL.md || true
  if [ -f "$SCRIPT_DIR/templates/scripts/verify-relay-task.sh" ]; then
    mkdir -p ~/.agents/bin ~/.agents/skills/verification-before-completion/scripts
    cp "$SCRIPT_DIR/templates/scripts/verify-relay-task.sh" ~/.agents/bin/relay-verify-task
    cp "$SCRIPT_DIR/templates/scripts/verify-relay-task.sh" ~/.agents/skills/verification-before-completion/scripts/verify-relay-task.sh
    chmod +x ~/.agents/bin/relay-verify-task ~/.agents/skills/verification-before-completion/scripts/verify-relay-task.sh
  fi
  [ -d ~/.agents/skills/founder-plan ] && [ ! -e ~/.agents/skills/founder-skill ] && ln -sf ~/.agents/skills/founder-plan ~/.agents/skills/founder-skill || true

  # ผูก Playwright MCP เข้ากับ CLI (หากมี claude หรือ codex ในเครื่อง)
  if command -v claude >/dev/null 2>&1; then
    echo "🔌 ตรวจสอบ/ผูก Playwright MCP เข้ากับ Claude Code..."
    claude mcp add -s user playwright npx "$PLAYWRIGHT_MCP_PKG" 2>/dev/null || true
  fi

  if command -v codex >/dev/null 2>&1; then
    echo "🔌 ตรวจสอบ/ผูก Playwright MCP เข้ากับ Codex CLI..."
    codex mcp add playwright -- npx "$PLAYWRIGHT_MCP_PKG" 2>/dev/null || true
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
      npx -y "$SKILLS_CLI_PKG" add "$REPO_URL" --skill "$SKILL_NAME" -g
    else
      npx -y "$SKILLS_CLI_PKG" add "$REPO_URL" -g
    fi
    # บันทึกลง skills-manifest.txt หากยังไม่มี
    ENTRY="${REPO_URL}|${SKILL_NAME}|${DESC}"
    if ! grep -Fq "${REPO_URL}|${SKILL_NAME}|" "$MANIFEST_FILE"; then
      echo "$ENTRY" >> "$MANIFEST_FILE"
      echo "📝 บันทึกสกิลนี้ลงใน skills-manifest.txt เรียบร้อย (จะถูกอัปเดตอัตโนมัติเมื่อรัน ./relay-skills.sh update)"
    fi
    echo "✅ เพิ่มสกิลใหม่สำเร็จ!"
    ;;
  create)
    scaffold_skill_folder "${2:-}" "${3:-}" "${4:-}"
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
