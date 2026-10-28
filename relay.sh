#!/usr/bin/env bash
set -e

# ==============================================================================
# 🎛️ RELAY Central Terminal Hub (สำหรับ macOS / Linux)
# ศูนย์กลางการควบคุมและสั่งงานตัวแทน AI ทั้ง 4 ขั้นตอนผ่านหน้าต่าง Terminal เดียว
# ==============================================================================

GLOBAL_DIR="$HOME/.agents"
GLOBAL_ROLES_CONF="$GLOBAL_DIR/relay-roles.conf"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
RELAY_DIR="$PROJECT_DIR/.relay"
PROJECT_ROLES_CONF="$RELAY_DIR/roles.conf"

# 1. โหลดการตั้งค่าจับคู่บทบาทกับค่าย AI (Global -> ทับด้วย Project Override ถ้ามี)
load_role_config() {
  ROLE_PO="gemini"
  ROLE_ARCH="claude"
  ROLE_DEV="claude"
  ROLE_QA="codex"
  CONFIG_SOURCE="ค่าเริ่มต้นส่วนกลาง (~/.agents/relay-roles.conf)"

  if [ -f "$GLOBAL_ROLES_CONF" ]; then
    # shellcheck disable=SC1090
    source "$GLOBAL_ROLES_CONF"
  fi
  if [ -f "$PROJECT_ROLES_CONF" ]; then
    # shellcheck disable=SC1090
    source "$PROJECT_ROLES_CONF"
    CONFIG_SOURCE="เฉพาะโครงการนี้ (.relay/roles.conf)"
  fi
}

# 2. บันทึกการตั้งค่าบทบาท
save_role_config() {
  local target_file="$1"
  mkdir -p "$(dirname "$target_file")"
  cat << EOF > "$target_file"
# RELAY Role-to-Provider Configuration (claude | codex | gemini)
ROLE_PO="$ROLE_PO"
ROLE_ARCH="$ROLE_ARCH"
ROLE_DEV="$ROLE_DEV"
ROLE_QA="$ROLE_QA"
EOF
}

# 3. ค้นหาใบงานปัจจุบัน (Active Task) ใน .relay/tasks/
get_active_task() {
  if [ ! -d "$RELAY_DIR/tasks" ]; then
    ACTIVE_TASK=""
    return
  fi
  if [ -n "$CURRENT_TASK" ] && [ -d "$RELAY_DIR/tasks/$CURRENT_TASK" ]; then
    ACTIVE_TASK="$CURRENT_TASK"
    return
  fi
  ACTIVE_TASK="$(ls -1 "$RELAY_DIR/tasks" 2>/dev/null | tail -n 1 || true)"
}

# 4. ฟังก์ชันเลือกค่าย AI สำหรับแต่ละตำแหน่ง
select_provider_for_role() {
  local role_label="$1"
  local current_val="$2"
  echo "" >&2
  echo "เลือกค่าย AI สำหรับ $role_label (ค่าปัจจุบัน: $current_val):" >&2
  echo "  [1] claude  (Anthropic Claude Code CLI)" >&2
  echo "  [2] codex   (OpenAI Codex CLI)" >&2
  echo "  [3] gemini  (Google Gemini CLI)" >&2
  echo "  [Enter] คงค่าเดิม ($current_val)" >&2
  read -r -p "เลือกหมายเลข (1-3): " choice
  case "$choice" in
    1) echo "claude" ;;
    2) echo "codex" ;;
    3) echo "gemini" ;;
    *) echo "$current_val" ;;
  esac
}

# 5. เมนูตั้งค่าจับคู่บทบาทกับค่าย AI (Role Configuration Menu)
configure_roles_menu() {
  load_role_config
  echo ""
  echo "======================================================================"
  echo "⚙️  ตั้งค่าจับคู่ตำแหน่งตัวแทน AI กับค่ายผู้ให้บริการ (Role-to-Provider Mapping)"
  echo "======================================================================"
  echo "คุณต้องการบันทึกการตั้งค่านี้ไว้ที่ระดับใด?"
  echo "  [1] ระดับส่วนกลางของเครื่อง (~/.agents/relay-roles.conf) — มีผลกับทุกโครงการ"
  echo "  [2] เฉพาะโครงการนี้ (.relay/roles.conf) — มีผลเฉพาะโฟลเดอร์ $PROJECT_NAME"
  read -r -p "เลือกระดับการบันทึก [1 หรือ 2, ค่าเริ่มต้น=1]: " scope_choice

  ROLE_PO="$(select_provider_for_role "ขั้นตอนที่ 1 (@po - วิเคราะห์ความต้องการ)" "$ROLE_PO")"
  ROLE_ARCH="$(select_provider_for_role "ขั้นตอนที่ 2 (@arch/@pm - ออกแบบและวางแผน)" "$ROLE_ARCH")"
  ROLE_DEV="$(select_provider_for_role "ขั้นตอนที่ 3 (@dev - พัฒนาโค้ดใน Git Worktree)" "$ROLE_DEV")"
  ROLE_QA="$(select_provider_for_role "ขั้นตอนที่ 4 (@qa/@sec - ตรวจสอบคุณภาพและความปลอดภัย)" "$ROLE_QA")"

  if [ "$scope_choice" = "2" ]; then
    save_role_config "$PROJECT_ROLES_CONF"
    echo "✅ บันทึกการตั้งค่าเฉพาะโครงการลงใน $PROJECT_ROLES_CONF เรียบร้อยแล้ว!"
  else
    save_role_config "$GLOBAL_ROLES_CONF"
    echo "✅ บันทึกการตั้งค่าส่วนกลางลงใน $GLOBAL_ROLES_CONF เรียบร้อยแล้ว!"
  fi
}

# 6. ฟังก์ชันเรียกใช้งาน Interactive CLI ของค่ายที่กำหนดในหน้าต่าง Terminal เดียวกัน
launch_provider_cli() {
  local provider="$1"
  local role_name="$2"
  local work_dir="$3"
  local initial_prompt="$4"

  echo ""
  echo "======================================================================"
  echo "🚀 กำลังเข้าสู่ $role_name ผ่านค่าย [$provider] ในโฟลเดอร์: $work_dir"
  echo "======================================================================"
  echo "📋 คำสั่งเริ่มต้นของขั้นตอนนี้ (คัดลอกลง Clipboard ให้แล้วอัตโนมัติ):"
  echo "----------------------------------------------------------------------"
  echo "$initial_prompt"
  echo "----------------------------------------------------------------------"
  echo "💡 คำแนะนำ: เมื่อสนทนาและสร้างเอกสารของขั้นตอนนี้เสร็จแล้ว ให้พิมพ์ /exit เพื่อกลับสู่หน้าจอหลักของ RELAY"
  echo "======================================================================"

  # คัดลอกคำสั่งลง Clipboard บน macOS อัตโนมัติ (เผื่อผู้ใช้ต้องการกด Cmd+V)
  if command -v pbcopy >/dev/null 2>&1; then
    printf "%s" "$initial_prompt" | pbcopy
  fi

  if ! command -v "$provider" >/dev/null 2>&1; then
    echo "⚠️ ไม่พบโปรแกรม '$provider' ในเครื่องของคุณ!"
    echo "   • วิธีติดตั้ง: npm install -g $( [ "$provider" = "claude" ] && echo "@anthropic-ai/claude-code" || ( [ "$provider" = "codex" ] && echo "@openai/codex" || echo "@google/gemini-cli" ) )"
    echo "   • หรือกด [c] ในหน้าเมนูหลักเพื่อเปลี่ยนตำแหน่งนี้ไปใช้ค่ายอื่นที่คุณติดตั้งไว้แล้ว"
    read -r -p "กด Enter เพื่อกลับสู่เมนูหลัก..." _
    return
  fi

  (
    cd "$work_dir"
    case "$provider" in
      claude)
        claude "$initial_prompt" || true
        ;;
      codex)
        codex "$initial_prompt" || true
        ;;
      gemini)
        gemini -i "$initial_prompt" 2>/dev/null || gemini || true
        ;;
      *)
        "$provider" || true
        ;;
    esac
  )
}

# 7. สร้างหรือเลือกใบงาน (Task)
ensure_or_create_task() {
  mkdir -p "$RELAY_DIR/tasks" "$RELAY_DIR/archive"
  get_active_task
  if [ -z "$ACTIVE_TASK" ]; then
    create_new_task
  fi
}

create_new_task() {
  mkdir -p "$RELAY_DIR/tasks" "$RELAY_DIR/archive"
  echo ""
  read -r -p "📝 ตั้งชื่อย่อของใบงานใหม่ (ภาษาอังกฤษ เช่น user-auth หรือ payment-api): " slug
  slug="$(echo "${slug:-feature}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')"
  local today
  today="$(date +%Y%m%d)"
  CURRENT_TASK="${today}-${slug}"
  mkdir -p "$RELAY_DIR/tasks/$CURRENT_TASK/screenshots"
  ACTIVE_TASK="$CURRENT_TASK"
  echo "✅ สร้างใบงานใหม่เรียบร้อย: .relay/tasks/$ACTIVE_TASK"
}

# 8. การทำงานของแต่ละขั้นตอน (Phase 1 - 5)
run_phase_1_po() {
  ensure_or_create_task
  echo ""
  read -r -p "💡 อธิบายฟีเจอร์หรือความต้องการคร่าวๆ ที่ต้องการให้ @po วิเคราะห์: " user_goal
  local prompt="@po ฉันต้องการพัฒนาฟีเจอร์สำหรับใบงาน .relay/tasks/$ACTIVE_TASK เกี่ยวกับ: ${user_goal:-ตามที่ฉันกำลังจะอธิบายต่อไปนี้} กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md (ถ้ามี) แล้วซักถามความต้องการจากฉันทีละประเด็นจนชัดเจน เมื่อฉันยืนยันแล้วให้สรุปเป็นเอกสารกำหนดความต้องการลงในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md"
  launch_provider_cli "$ROLE_PO" "ขั้นตอนที่ 1: @po (Product Owner)" "$PROJECT_DIR" "$prompt"
}

run_phase_2_arch() {
  ensure_or_create_task
  local prompt="@arch @pm กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md ร่วมกับไฟล์ความต้องการ .relay/tasks/$ACTIVE_TASK/SPEC.md แล้วออกแบบโครงสร้างทางเทคนิคลงในไฟล์ .relay/tasks/$ACTIVE_TASK/ARCH.md และจัดทำแผนการดำเนินงานย่อยเป็นข้อๆ ลงในไฟล์ .relay/tasks/$ACTIVE_TASK/PLAN.md"
  launch_provider_cli "$ROLE_ARCH" "ขั้นตอนที่ 2: @arch & @pm (Architect & Planner)" "$PROJECT_DIR" "$prompt"
}

run_phase_3_dev() {
  ensure_or_create_task
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"
  local branch_name="feat/$ACTIVE_TASK"

  # สร้าง Git Worktree แยกอิสระอัตโนมัติหากโปรเจกต์เป็น Git Repository
  local target_work_dir="$PROJECT_DIR"
  if [ -d "$PROJECT_DIR/.git" ]; then
    mkdir -p "$RELAY_DIR/worktrees"
    if [ ! -d "$worktree_dir" ]; then
      echo "🌿 กำลังสร้างสภาพแวดล้อมการทำงานแยกอิสระ (Git Worktree) ที่ .relay/worktrees/$ACTIVE_TASK (กิ่ง $branch_name)..."
      git worktree add "$worktree_dir" -b "$branch_name" 2>/dev/null || git worktree add "$worktree_dir" "$branch_name" 2>/dev/null || true
    fi
    if [ -d "$worktree_dir" ]; then
      # คัดลอกโฟลเดอร์ใบงานล่าสุดเข้าสู่ Worktree เพื่อให้ AI อ่านไฟล์ได้โดยตรง
      mkdir -p "$worktree_dir/.relay/tasks"
      cp -R "$RELAY_DIR/tasks/$ACTIVE_TASK" "$worktree_dir/.relay/tasks/" 2>/dev/null || true
      [ -f "$RELAY_DIR/PROJECT_STATE.md" ] && cp "$RELAY_DIR/PROJECT_STATE.md" "$worktree_dir/.relay/PROJECT_STATE.md" 2>/dev/null || true
      target_work_dir="$worktree_dir"
    fi
  fi

  local prompt="@dev กรุณาอ่านเอกสาร .relay/tasks/$ACTIVE_TASK/SPEC.md, ARCH.md และ PLAN.md แล้วดำเนินการพัฒนาโค้ดควบคู่กับชุดทดสอบ (Unit Tests) ตามแผนที่กำหนดไว้"
  launch_provider_cli "$ROLE_DEV" "ขั้นตอนที่ 3: @dev (Full-Stack Developer ใน Git Worktree)" "$target_work_dir" "$prompt"
}

run_phase_4_qa() {
  ensure_or_create_task
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"
  local target_work_dir="$PROJECT_DIR"
  if [ -d "$worktree_dir" ]; then
    target_work_dir="$worktree_dir"
  fi

  local prompt="@qa @sec กรุณาตรวจสอบผลงานตามเกณฑ์ Acceptance Criteria ในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md โดย: 1. รันชุดทดสอบจริงของโครงการผ่าน Terminal (0 Token) 2. ตรวจสอบความปลอดภัยของ git diff ตามทักษะ differential-review และ semgrep 3. หากมีส่วนติดต่อผู้ใช้บนเว็บ ให้ใช้ Playwright MCP ทดสอบและบันทึกภาพหน้าจอไว้ที่ .relay/tasks/$ACTIVE_TASK/screenshots/ 4. สรุปผลการตรวจสอบลงในไฟล์ .relay/tasks/$ACTIVE_TASK/QA_REPORT.md และอัปเดตไฟล์ .relay/PROJECT_STATE.md ให้เป็นปัจจุบัน"
  launch_provider_cli "$ROLE_QA" "ขั้นตอนที่ 4: @qa & @sec (Quality Assurance & Security Auditor)" "$target_work_dir" "$prompt"

  # ซิงก์รายงาน QA_REPORT.md และ PROJECT_STATE.md จาก Worktree กลับมายังโฟลเดอร์หลัก
  if [ -d "$worktree_dir/.relay/tasks/$ACTIVE_TASK" ]; then
    cp -R "$worktree_dir/.relay/tasks/$ACTIVE_TASK/"* "$RELAY_DIR/tasks/$ACTIVE_TASK/" 2>/dev/null || true
    [ -f "$worktree_dir/.relay/PROJECT_STATE.md" ] && cp "$worktree_dir/.relay/PROJECT_STATE.md" "$RELAY_DIR/PROJECT_STATE.md" 2>/dev/null || true
  fi
}

run_phase_5_merge() {
  get_active_task
  if [ -z "$ACTIVE_TASK" ]; then
    echo "⚠️ ยังไม่มีใบงานที่กำลังดำเนินการใน .relay/tasks/"
    return
  fi
  local branch_name="feat/$ACTIVE_TASK"
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"

  echo ""
  echo "======================================================================"
  echo "🏁 ขั้นตอนที่ 5: การผสานโค้ดเข้าสู่กิ่งหลัก (Merge) และจัดเก็บใบงาน ($ACTIVE_TASK)"
  echo "======================================================================"

  if [ -d "$worktree_dir" ]; then
    echo "📊 สถานะการเปลี่ยนแปลงใน Worktree ($branch_name):"
    git -C "$worktree_dir" status -s || true
  fi

  read -r -p "ยืนยันการผสานโค้ดเข้าสู่กิ่งหลักและย้ายใบงานเข้าสู่ .relay/archive/ หรือไม่? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    if [ -d "$PROJECT_DIR/.git" ] && git show-ref --verify --quiet "refs/heads/$branch_name"; then
      git merge "$branch_name" || true
      if [ -d "$worktree_dir" ]; then
        git worktree remove "$worktree_dir" --force 2>/dev/null || rm -rf "$worktree_dir"
      fi
      git branch -d "$branch_name" 2>/dev/null || true
    fi
    mkdir -p "$RELAY_DIR/archive"
    mv "$RELAY_DIR/tasks/$ACTIVE_TASK" "$RELAY_DIR/archive/$ACTIVE_TASK"
    CURRENT_TASK=""
    echo "✅ ผสานโค้ดและย้ายใบงานไปที่ .relay/archive/$ACTIVE_TASK เรียบร้อยแล้ว!"
  else
    echo "ℹ️ ยกเลิกการผสานโค้ด"
  fi
}

run_init_project() {
  echo ""
  echo "เลือกประเภทโครงการที่ต้องการเตรียมโครงสร้าง .relay/:"
  echo "  [1] โครงการใหม่ตั้งแต่ศูนย์ (Greenfield Project)"
  echo "  [2] โครงการเดิมที่มีโค้ดอยู่แล้ว (Brownfield / Existing Project — สแกนสร้าง PROJECT_STATE.md)"
  read -r -p "เลือกหมายเลข [1 หรือ 2]: " init_choice
  if [ "$init_choice" = "2" ]; then
    "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" existing
    local prompt="@arch ช่วยสำรวจและวิเคราะห์โครงสร้างของโครงการเดิมนี้ทั้งหมด (ประกอบด้วย Tech Stack, โครงสร้างโฟลเดอร์สำคัญ, รูปแบบฐานข้อมูล/Schema, รายการ API หลัก และคำสั่งที่ใช้ในการ Build/Test) แล้วสรุปเขียนทับลงในไฟล์ .relay/PROJECT_STATE.md ให้มีความชัดเจนและกระชับ (ความยาวไม่เกิน 2 หน้า) โดยห้ามแก้ไขไฟล์โค้ดใดๆ ของระบบ"
    launch_provider_cli "$ROLE_ARCH" "การสแกนโครงสร้างโครงการเดิม (@arch)" "$PROJECT_DIR" "$prompt"
  else
    "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" new
  fi
}

# 9. แสดงหน้าจอหลักของ RELAY Central Terminal Hub
print_dashboard() {
  load_role_config
  get_active_task

  local state_status="❌ ยังไม่มี (กด [i] เพื่อสร้าง)"
  [ -f "$RELAY_DIR/PROJECT_STATE.md" ] && state_status="✅ พร้อมใช้งาน (.relay/PROJECT_STATE.md)"

  local spec_mark="[ ]"
  local plan_mark="[ ]"
  local qa_mark="[ ]"
  if [ -n "$ACTIVE_TASK" ]; then
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ] && spec_mark="[✓]"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/PLAN.md" ] && plan_mark="[✓]"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_REPORT.md" ] && qa_mark="[✓]"
  fi

  echo ""
  echo "======================================================================"
  echo "🎛️  RELAY Central Terminal Hub (v1.0) — โครงการ: $PROJECT_NAME"
  echo "======================================================================"
  echo "📂 โฟลเดอร์โครงการ : $PROJECT_DIR"
  echo "📌 สถานะโครงการ  : $state_status"
  if [ -n "$ACTIVE_TASK" ]; then
    echo "📋 ใบงานปัจจุบัน   : $ACTIVE_TASK"
    echo "   สถานะเอกสาร   : $spec_mark SPEC.md   $plan_mark ARCH.md & PLAN.md   $qa_mark QA_REPORT.md"
  else
    echo "📋 ใบงานปัจจุบัน   : (ยังไม่มีใบงานที่กำลังดำเนินการ — กด [1] หรือ [n] เพื่อเริ่มใบงานใหม่)"
  fi
  echo "----------------------------------------------------------------------"
  echo "🤖 การจับคู่ตำแหน่งกับค่าย AI ($CONFIG_SOURCE):"
  echo "   • ขั้นตอนที่ 1 (@po)        ➔ ค่าย: $ROLE_PO"
  echo "   • ขั้นตอนที่ 2 (@arch/@pm)  ➔ ค่าย: $ROLE_ARCH"
  echo "   • ขั้นตอนที่ 3 (@dev)       ➔ ค่าย: $ROLE_DEV (แยกกิ่ง Git Worktree อัตโนมัติ)"
  echo "   • ขั้นตอนที่ 4 (@qa/@sec)   ➔ ค่าย: $ROLE_QA"
  echo "----------------------------------------------------------------------"
  echo "เลือกคำสั่งการทำงาน (พิมพ์หมายเลขหรือตัวอักษรแล้วกด Enter ในหน้าต่างนี้ได้เลย):"
  echo "  [1] เริ่มขั้นตอนที่ 1 (@po)        — วิเคราะห์ความต้องการและสร้าง SPEC.md"
  echo "  [2] เริ่มขั้นตอนที่ 2 (@arch/@pm)  — อ่าน SPEC.md แล้วสร้าง ARCH.md & PLAN.md"
  echo "  [3] เริ่มขั้นตอนที่ 3 (@dev)       — แยก Git Worktree อัตโนมัติและพัฒนาโค้ด"
  echo "  [4] เริ่มขั้นตอนที่ 4 (@qa/@sec)   — รันชุดทดสอบ + ตรวจความปลอดภัย + สรุป QA_REPORT.md"
  echo "  [5] ผสานโค้ดและจัดเก็บใบงาน      — Merge เข้ากิ่ง main และย้ายเข้า .relay/archive/"
  echo "----------------------------------------------------------------------"
  echo "  [n] สร้างใบงานใหม่ (New Task)    | [i] เตรียม .relay/ (โครงการใหม่ / สแกนโครงการเดิม)"
  echo "  [c] ตั้งค่าเปลี่ยนค่าย AI ประจำตำแหน่ง | [s] จัดการ/อัปเดต Skills | [q] ออกจากโปรแกรม"
  echo "======================================================================"
}

run_skills_menu() {
  echo ""
  echo "เลือกการจัดการชุดทักษะ (RELAY Skills):"
  echo "  [1] แสดงรายการทักษะทั้งหมด (list)"
  echo "  [2] ติดตั้งชุดทักษะมาตรฐานทั้งหมด (install)"
  echo "  [3] อัปเดตทักษะทั้งหมดให้เป็นเวอร์ชันล่าสุดจาก GitHub (update)"
  echo "  [4] เพิ่มทักษะใหม่จาก GitHub (add)"
  read -r -p "เลือกหมายเลข [1-4]: " sk_choice
  local skills_cmd="$GLOBAL_DIR/bin/relay-skills"
  [ ! -x "$skills_cmd" ] && skills_cmd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/relay-skills.sh"
  case "$sk_choice" in
    1) "$skills_cmd" list ;;
    2) "$skills_cmd" install ;;
    3) "$skills_cmd" update ;;
    4)
      read -r -p "ระบุ GitHub Repo URL: " repo_url
      read -r -p "ระบุชื่อ Skill ย่อย (หรือกด Enter หากติดตั้งทั้ง Repo): " skill_sub
      "$skills_cmd" add "$repo_url" "$skill_sub"
      ;;
  esac
}

# รองรับการเรียกใช้งานผ่าน Subcommand โดยตรง หรือเปิดหน้าจอ Interactive Hub
SUBCOMMAND="${1:-hub}"
case "$SUBCOMMAND" in
  status)
    print_dashboard
    exit 0
    ;;
  config)
    configure_roles_menu
    exit 0
    ;;
  init)
    "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" "${2:-new}"
    exit 0
    ;;
  1) run_phase_1_po; exit 0 ;;
  2) run_phase_2_arch; exit 0 ;;
  3) run_phase_3_dev; exit 0 ;;
  4) run_phase_4_qa; exit 0 ;;
  5) run_phase_5_merge; exit 0 ;;
esac

# Interactive Main Loop ในหน้าต่าง Terminal เดียว
while true; do
  print_dashboard
  read -r -p "👉 เลือกคำสั่ง [1-5, n, i, c, s, q]: " action
  case "$action" in
    1) run_phase_1_po ;;
    2) run_phase_2_arch ;;
    3) run_phase_3_dev ;;
    4) run_phase_4_qa ;;
    5) run_phase_5_merge ;;
    n|N) create_new_task ;;
    i|I) run_init_project ;;
    c|C) configure_roles_menu ;;
    s|S) run_skills_menu ;;
    q|Q|exit)
      echo "👋 ออกจากหน้าจอควบคุม RELAY เรียบร้อย"
      exit 0
      ;;
    *)
      echo "⚠️ กรุณาเลือกคำสั่งที่กำหนด (1-5, n, i, c, s, q)"
      ;;
  esac
done
