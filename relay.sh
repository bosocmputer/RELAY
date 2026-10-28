#!/usr/bin/env bash
set -e

# ==============================================================================
# 🎛️ RELAY Central Terminal Hub (สำหรับ macOS / Linux)
# ศูนย์กลางการควบคุม ตั้งค่าค่าย AI/Model และตรวจสอบสถานะการเชื่อมต่อในหน้าต่างเดียว
# ==============================================================================

GLOBAL_DIR="$HOME/.agents"
GLOBAL_ROLES_CONF="$GLOBAL_DIR/relay-roles.conf"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
RELAY_DIR="$PROJECT_DIR/.relay"
PROJECT_ROLES_CONF="$RELAY_DIR/roles.conf"

# 1. โหลดการตั้งค่าจับคู่บทบาทกับค่าย AI และโมเดล (Global -> ทับด้วย Project Override ถ้ามี)
load_role_config() {
  ROLE_PO="gemini"
  MODEL_PO="default"
  ROLE_ARCH="claude"
  MODEL_ARCH="default"
  ROLE_DEV="claude"
  MODEL_DEV="default"
  ROLE_QA="codex"
  MODEL_QA="default"
  CONFIG_SOURCE="ค่าเริ่มต้นส่วนกลาง (~/.agents/relay-roles.conf)"

  if [ -r "$GLOBAL_ROLES_CONF" ]; then
    # shellcheck disable=SC1090
    source "$GLOBAL_ROLES_CONF"
  fi
  if [ -r "$PROJECT_ROLES_CONF" ]; then
    # shellcheck disable=SC1090
    source "$PROJECT_ROLES_CONF"
    CONFIG_SOURCE="เฉพาะโครงการนี้ (.relay/roles.conf)"
  fi
}

# 2. บันทึกการตั้งค่าบทบาทและโมเดล
save_role_config() {
  local target_file="$1"
  mkdir -p "$(dirname "$target_file")"
  cat << EOF > "$target_file"
# RELAY Role-to-Provider & Model Configuration
ROLE_PO="$ROLE_PO"
MODEL_PO="${MODEL_PO:-default}"
ROLE_ARCH="$ROLE_ARCH"
MODEL_ARCH="${MODEL_ARCH:-default}"
ROLE_DEV="$ROLE_DEV"
MODEL_DEV="${MODEL_DEV:-default}"
ROLE_QA="$ROLE_QA"
MODEL_QA="${MODEL_QA:-default}"
EOF
}

# 3. ตรวจสอบสถานะการติดตั้งและความพร้อมของ CLI แต่ละค่าย
get_provider_status() {
  local provider="$1"
  if ! command -v "$provider" >/dev/null 2>&1; then
    echo "❌ ยังไม่ได้ติดตั้ง CLI (กด [d] เพื่อติดตั้ง)"
    return
  fi
  local ver
  ver="$("$provider" --version 2>/dev/null | head -n 1 | tr -d '\r' || true)"
  if [ -n "$ver" ]; then
    echo "✅ พร้อมใช้งาน ($ver)"
  else
    echo "✅ พร้อมใช้งาน"
  fi
}

# 4. อ่านชื่อโมเดลที่ใช้งานจริง (ตรวจสอบจากค่าที่ตั้งไว้ หรืออ่านค่าเริ่มต้นของ CLI)
get_effective_model_label() {
  local provider="$1"
  local configured_model="${2:-default}"

  if [ -n "$configured_model" ] && [ "$configured_model" != "default" ]; then
    echo "$configured_model"
    return
  fi

  case "$provider" in
    claude)
      if [ -f "$HOME/.claude/settings.json" ]; then
        local cm
        cm="$(grep -Eo '"model"[[:space:]]*:[[:space:]]*"[^"]+"' "$HOME/.claude/settings.json" 2>/dev/null | head -n 1 | sed -E 's/.*"([^"]+)"$/\1/' || true)"
        [ -n "$cm" ] && { echo "$cm (CLI default)"; return; }
      fi
      echo "default (sonnet/opus)"
      ;;
    codex)
      if [ -f "$HOME/.codex/config.toml" ]; then
        local xm
        xm="$(grep -E '^[[:space:]]*model[[:space:]]*=' "$HOME/.codex/config.toml" 2>/dev/null | head -n 1 | sed -E 's/.*=[[:space:]]*"?([^"#[:space:]]+)"?.*/\1/' || true)"
        [ -n "$xm" ] && { echo "$xm (CLI default)"; return; }
      fi
      echo "default (o3/gpt-5)"
      ;;
    gemini)
      if [ -f "$HOME/.gemini/settings.json" ]; then
        local gm
        gm="$(grep -Eo '"model"[[:space:]]*:[[:space:]]*"[^"]+"' "$HOME/.gemini/settings.json" 2>/dev/null | head -n 1 | sed -E 's/.*"([^"]+)"$/\1/' || true)"
        [ -n "$gm" ] && { echo "$gm (CLI default)"; return; }
      fi
      echo "default (gemini-2.5-pro)"
      ;;
    *)
      echo "default"
      ;;
  esac
}

# 5. ค้นหาใบงานปัจจุบัน (Active Task) ใน .relay/tasks/
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

# 6. ฟังก์ชันเลือกค่าย AI และเลือก Model สำหรับแต่ละตำแหน่ง
select_provider_for_role() {
  local role_label="$1"
  local current_val="$2"
  echo "" >&2
  echo "เลือกค่าย AI สำหรับ $role_label (ค่าปัจจุบัน: $current_val):" >&2
  echo "  [1] claude  (Anthropic Claude Code CLI)" >&2
  echo "  [2] codex   (OpenAI Codex CLI)" >&2
  echo "  [3] gemini  (Google Gemini CLI)" >&2
  echo "  [Enter] คงค่าเดิม ($current_val)" >&2
  read -r -p "เลือกหมายเลขค่าย (1-3): " choice
  case "$choice" in
    1) echo "claude" ;;
    2) echo "codex" ;;
    3) echo "gemini" ;;
    *) echo "$current_val" ;;
  esac
}

select_model_for_provider() {
  local provider="$1"
  local role_label="$2"
  local current_model="${3:-default}"
  echo "" >&2
  echo "เลือกโมเดล (Model) ของค่าย [$provider] สำหรับ $role_label (ค่าปัจจุบัน: $current_model):" >&2
  case "$provider" in
    claude)
      echo "  [1] default (ใช้ค่าเริ่มต้นของ Claude Code)" >&2
      echo "  [2] sonnet  (Claude Sonnet — รวดเร็ว สมดุล เหมาะกับงานเขียนโค้ด)" >&2
      echo "  [3] opus    (Claude Opus — วิเคราะห์เชิงลึก เหมาะกับงานออกแบบสถาปัตยกรรม)" >&2
      echo "  [4] haiku   (Claude Haiku — ประหยัดโควตาสูงสุด)" >&2
      echo "  [5] ระบุชื่อโมเดลเอง (Custom Model ID)" >&2
      echo "  [Enter] คงค่าเดิม ($current_model)" >&2
      read -r -p "เลือกหมายเลขโมเดล (1-5): " m_choice
      case "$m_choice" in
        1) echo "default" ;;
        2) echo "sonnet" ;;
        3) echo "opus" ;;
        4) echo "haiku" ;;
        5) read -r -p "ระบุชื่อโมเดล: " custom_m; echo "${custom_m:-default}" ;;
        *) echo "$current_model" ;;
      esac
      ;;
    codex)
      echo "  [1] default (ใช้ค่าเริ่มต้นของ Codex CLI)" >&2
      echo "  [2] o3      (OpenAI o3 — เหมาะกับการตรวจสอบโค้ดและหาช่องโหว่)" >&2
      echo "  [3] o4-mini (OpenAI o4-mini — รวดเร็ว ประหยัดโควตา)" >&2
      echo "  [4] gpt-5   (OpenAI GPT-5)" >&2
      echo "  [5] ระบุชื่อโมเดลเอง (Custom Model ID)" >&2
      echo "  [Enter] คงค่าเดิม ($current_model)" >&2
      read -r -p "เลือกหมายเลขโมเดล (1-5): " m_choice
      case "$m_choice" in
        1) echo "default" ;;
        2) echo "o3" ;;
        3) echo "o4-mini" ;;
        4) echo "gpt-5" ;;
        5) read -r -p "ระบุชื่อโมเดล: " custom_m; echo "${custom_m:-default}" ;;
        *) echo "$current_model" ;;
      esac
      ;;
    gemini)
      echo "  [1] default        (ใช้ค่าเริ่มต้นของ Gemini CLI)" >&2
      echo "  [2] gemini-2.5-pro (Gemini 2.5 Pro — เหมาะกับงานวิเคราะห์ความต้องการและวางแผน)" >&2
      echo "  [3] gemini-2.5-flash (Gemini 2.5 Flash — รวดเร็วสูง)" >&2
      echo "  [4] ระบุชื่อโมเดลเอง (Custom Model ID)" >&2
      echo "  [Enter] คงค่าเดิม ($current_model)" >&2
      read -r -p "เลือกหมายเลขโมเดล (1-4): " m_choice
      case "$m_choice" in
        1) echo "default" ;;
        2) echo "gemini-2.5-pro" ;;
        3) echo "gemini-2.5-flash" ;;
        4) read -r -p "ระบุชื่อโมเดล: " custom_m; echo "${custom_m:-default}" ;;
        *) echo "$current_model" ;;
      esac
      ;;
  esac
}

# 7. เมนูตั้งค่าจับคู่บทบาทกับค่าย AI และโมเดล (Role & Model Configuration Menu)
configure_roles_menu() {
  load_role_config
  echo ""
  echo "======================================================================"
  echo "⚙️  ตั้งค่าจับคู่ตำแหน่งตัวแทน AI กับค่ายผู้ให้บริการและโมเดล (Role & Model Mapping)"
  echo "======================================================================"
  echo "คุณต้องการบันทึกการตั้งค่านี้ไว้ที่ระดับใด?"
  echo "  [1] ระดับส่วนกลางของเครื่อง (~/.agents/relay-roles.conf) — มีผลกับทุกโครงการ"
  echo "  [2] เฉพาะโครงการนี้ (.relay/roles.conf) — มีผลเฉพาะโฟลเดอร์ $PROJECT_NAME"
  read -r -p "เลือกระดับการบันทึก [1 หรือ 2, ค่าเริ่มต้น=1]: " scope_choice

  echo ""
  echo "เลือกรูปแบบการตั้งค่า (Preset หรือกำหนดเองทีละตำแหน่ง):"
  echo "  [1] กำหนดค่ายและโมเดลเองทีละตำแหน่ง (Custom — ผสมค่าย gemini / claude / codex ได้อิสระ)"
  echo "  [2] ใช้ Claude Code ทุกตำแหน่ง (All-Claude: @po=sonnet, @arch=opus, @dev=sonnet, @qa=opus)"
  echo "  [3] ใช้ Gemini CLI ทุกตำแหน่ง (All-Gemini: gemini-2.5-pro ทุกตำแหน่ง)"
  echo "  [4] ใช้ OpenAI Codex ทุกตำแหน่ง (All-Codex: o3 ทุกตำแหน่ง)"
  read -r -p "เลือกรูปแบบ [1-4, ค่าเริ่มต้น=1]: " preset_choice

  case "$preset_choice" in
    2)
      ROLE_PO="claude";   MODEL_PO="sonnet"
      ROLE_ARCH="claude"; MODEL_ARCH="opus"
      ROLE_DEV="claude";  MODEL_DEV="sonnet"
      ROLE_QA="claude";   MODEL_QA="opus"
      ;;
    3)
      ROLE_PO="gemini";   MODEL_PO="gemini-2.5-pro"
      ROLE_ARCH="gemini"; MODEL_ARCH="gemini-2.5-pro"
      ROLE_DEV="gemini";  MODEL_DEV="gemini-2.5-pro"
      ROLE_QA="gemini";   MODEL_QA="gemini-2.5-pro"
      ;;
    4)
      ROLE_PO="codex";   MODEL_PO="o3"
      ROLE_ARCH="codex"; MODEL_ARCH="o3"
      ROLE_DEV="codex";  MODEL_DEV="o3"
      ROLE_QA="codex";   MODEL_QA="o3"
      ;;
    *)
      ROLE_PO="$(select_provider_for_role "ขั้นตอนที่ 1 (@po - วิเคราะห์ความต้องการ)" "$ROLE_PO")"
      MODEL_PO="$(select_model_for_provider "$ROLE_PO" "ขั้นตอนที่ 1 (@po)" "$MODEL_PO")"

      ROLE_ARCH="$(select_provider_for_role "ขั้นตอนที่ 2 (@arch/@pm - ออกแบบและวางแผน)" "$ROLE_ARCH")"
      MODEL_ARCH="$(select_model_for_provider "$ROLE_ARCH" "ขั้นตอนที่ 2 (@arch/@pm)" "$MODEL_ARCH")"

      ROLE_DEV="$(select_provider_for_role "ขั้นตอนที่ 3 (@dev - พัฒนาโค้ดใน Git Worktree)" "$ROLE_DEV")"
      MODEL_DEV="$(select_model_for_provider "$ROLE_DEV" "ขั้นตอนที่ 3 (@dev)" "$MODEL_DEV")"

      ROLE_QA="$(select_provider_for_role "ขั้นตอนที่ 4 (@qa/@sec - ตรวจสอบคุณภาพและความปลอดภัย)" "$ROLE_QA")"
      MODEL_QA="$(select_model_for_provider "$ROLE_QA" "ขั้นตอนที่ 4 (@qa/@sec)" "$MODEL_QA")"
      ;;
  esac

  if [ "$scope_choice" = "2" ]; then
    save_role_config "$PROJECT_ROLES_CONF"
    echo "✅ บันทึกการตั้งค่าเฉพาะโครงการลงใน $PROJECT_ROLES_CONF เรียบร้อยแล้ว!"
  else
    save_role_config "$GLOBAL_ROLES_CONF"
    echo "✅ บันทึกการตั้งค่าส่วนกลางลงใน $GLOBAL_ROLES_CONF เรียบร้อยแล้ว!"
  fi
}

# 8. เมนูตรวจสอบการเชื่อมต่อ ติดตั้ง CLI และ Login (Doctor & Connection Check)
run_doctor_menu() {
  while true; do
    echo ""
    echo "======================================================================"
    echo "🩺 RELAY Doctor — ตรวจสอบสถานะการเชื่อมต่อ CLI และโมเดลของทั้ง 3 ค่าย"
    echo "======================================================================"
    for p in claude codex gemini; do
      local pkg_name="@google/gemini-cli"
      [ "$p" = "claude" ] && pkg_name="@anthropic-ai/claude-code"
      [ "$p" = "codex" ]  && pkg_name="@openai/codex"

      if command -v "$p" >/dev/null 2>&1; then
        local bin_path ver_str
        bin_path="$(command -v "$p")"
        ver_str="$("$p" --version 2>/dev/null | head -n 1 || echo "installed")"
        printf "  • %-8s : ✅ ติดตั้งแล้ว (%s | %s)\n" "$p" "$ver_str" "$bin_path"
      else
        printf "  • %-8s : ❌ ยังไม่ได้ติดตั้งในเครื่อง (แพ็กเกจ: %s)\n" "$p" "$pkg_name"
      fi
    done
    echo "----------------------------------------------------------------------"
    echo "🔗 สถานะไฟล์กฎการทำงานส่วนกลาง (Global Rules Symlinks):"
    for link_path in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md" "$HOME/.gemini/GEMINI.md"; do
      if [ -e "$link_path" ]; then
        echo "  • $link_path ➔ ✅ เชื่อมต่อแล้ว"
      else
        echo "  • $link_path ➔ ❌ ยังไม่เชื่อมต่อ"
      fi
    done
    echo "----------------------------------------------------------------------"
    echo "เลือกการดำเนินการ:"
    echo "  [1] ติดตั้ง CLI รวดเดียวครบทั้ง 3 ค่าย (claude + codex + gemini)"
    echo "  [2] ติดตั้งเฉพาะ Claude Code CLI (npm install -g @anthropic-ai/claude-code)"
    echo "  [3] ติดตั้งเฉพาะ OpenAI Codex CLI (npm install -g @openai/codex)"
    echo "  [4] ติดตั้งเฉพาะ Google Gemini CLI (npm install -g @google/gemini-cli)"
    echo "  [5] เปิด CLI เพื่อเข้าสู่ระบบ (Login) และเช็กสถานะบัญชี (เลือกค่าย)"
    echo "  [Enter หรือ b] กลับสู่หน้าจอหลักของ RELAY"
    echo "======================================================================"
    read -r -p "เลือกหมายเลข: " doc_choice
    case "$doc_choice" in
      1)
        npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli
        ;;
      2)
        npm install -g @anthropic-ai/claude-code
        ;;
      3)
        npm install -g @openai/codex
        ;;
      4)
        npm install -g @google/gemini-cli
        ;;
      5)
        read -r -p "ระบุชื่อค่ายที่ต้องการเปิดเพื่อ Login (claude / codex / gemini): " login_p
        if command -v "$login_p" >/dev/null 2>&1; then
          echo "💡 กำลังเปิด $login_p เพื่อให้คุณ Login (เมื่อเสร็จแล้วให้พิมพ์ /exit เพื่อกลับมาหน้านี้)..."
          "$login_p" || true
        else
          echo "❌ ยังไม่ได้ติดตั้ง $login_p กรุณากด 1-4 เพื่อติดตั้งก่อนครับ"
        fi
        ;;
      *)
        break
        ;;
    esac
  done
}

# 9. ฟังก์ชันเรียกใช้งาน Interactive CLI ของค่ายและโมเดลที่กำหนดในหน้าต่าง Terminal เดียวกัน
launch_provider_cli() {
  local provider="$1"
  local configured_model="$2"
  local role_name="$3"
  local work_dir="$4"
  local initial_prompt="$5"
  local model_label
  model_label="$(get_effective_model_label "$provider" "$configured_model")"

  echo ""
  echo "======================================================================"
  echo "🚀 กำลังเข้าสู่ $role_name"
  echo "   • ค่ายผู้ให้บริการ : $provider"
  echo "   • โมเดลที่ใช้     : $model_label"
  echo "   • โฟลเดอร์ทำงาน  : $work_dir"
  echo "======================================================================"
  echo "📋 คำสั่งเริ่มต้นของขั้นตอนนี้ (คัดลอกลง Clipboard ให้แล้วอัตโนมัติ):"
  echo "----------------------------------------------------------------------"
  echo "$initial_prompt"
  echo "----------------------------------------------------------------------"
  echo "💡 คำแนะนำ: เมื่อสนทนาและสร้างเอกสารของขั้นตอนนี้เสร็จแล้ว ให้พิมพ์ /exit เพื่อกลับสู่หน้าจอหลักของ RELAY"
  echo "======================================================================"

  # คัดลอกคำสั่งลง Clipboard บน macOS อัตโนมัติ
  if command -v pbcopy >/dev/null 2>&1; then
    printf "%s" "$initial_prompt" | pbcopy
  fi

  if ! command -v "$provider" >/dev/null 2>&1; then
    echo "⚠️ ไม่พบโปรแกรม '$provider' ในเครื่องของคุณ!"
    echo "   👉 คุณสามารถกด [d] ในหน้าเมนูหลักเพื่อสั่งติดตั้ง '$provider' ได้ทันที หรือกด [c] เพื่อสลับไปใช้ค่ายอื่น"
    read -r -p "กด Enter เพื่อกลับสู่เมนูหลัก..." _
    return
  fi

  (
    cd "$work_dir"
    case "$provider" in
      claude)
        if [ -n "$configured_model" ] && [ "$configured_model" != "default" ]; then
          claude --model "$configured_model" "$initial_prompt" || true
        else
          claude "$initial_prompt" || true
        fi
        ;;
      codex)
        if [ -n "$configured_model" ] && [ "$configured_model" != "default" ]; then
          codex -m "$configured_model" "$initial_prompt" || true
        else
          codex "$initial_prompt" || true
        fi
        ;;
      gemini)
        if [ -n "$configured_model" ] && [ "$configured_model" != "default" ]; then
          gemini -m "$configured_model" -i "$initial_prompt" 2>/dev/null || gemini -m "$configured_model" || true
        else
          gemini -i "$initial_prompt" 2>/dev/null || gemini || true
        fi
        ;;
      *)
        "$provider" || true
        ;;
    esac
  )
}

# 10. สร้างหรือเลือกใบงาน (Task)
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

# 11. การทำงานของแต่ละขั้นตอน (Phase 1 - 5)
run_phase_1_po() {
  ensure_or_create_task
  echo ""
  read -r -p "💡 อธิบายฟีเจอร์หรือความต้องการคร่าวๆ ที่ต้องการให้ @po วิเคราะห์: " user_goal
  local prompt="@po ฉันต้องการพัฒนาฟีเจอร์สำหรับใบงาน .relay/tasks/$ACTIVE_TASK เกี่ยวกับ: ${user_goal:-ตามที่ฉันกำลังจะอธิบายต่อไปนี้} กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md (ถ้ามี) แล้วซักถามความต้องการจากฉันทีละประเด็นจนชัดเจน เมื่อฉันยืนยันแล้วให้สรุปเป็นเอกสารกำหนดความต้องการลงในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md"
  launch_provider_cli "$ROLE_PO" "$MODEL_PO" "ขั้นตอนที่ 1: @po (Product Owner)" "$PROJECT_DIR" "$prompt"
}

run_phase_2_arch() {
  ensure_or_create_task
  local prompt="@arch @pm กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md ร่วมกับไฟล์ความต้องการ .relay/tasks/$ACTIVE_TASK/SPEC.md แล้วออกแบบโครงสร้างทางเทคนิคลงในไฟล์ .relay/tasks/$ACTIVE_TASK/ARCH.md และจัดทำแผนการดำเนินงานย่อยเป็นข้อๆ ลงในไฟล์ .relay/tasks/$ACTIVE_TASK/PLAN.md"
  launch_provider_cli "$ROLE_ARCH" "$MODEL_ARCH" "ขั้นตอนที่ 2: @arch & @pm (Architect & Planner)" "$PROJECT_DIR" "$prompt"
}

run_phase_3_dev() {
  ensure_or_create_task
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"
  local branch_name="feat/$ACTIVE_TASK"

  local target_work_dir="$PROJECT_DIR"
  if [ -d "$PROJECT_DIR/.git" ]; then
    mkdir -p "$RELAY_DIR/worktrees"
    if [ ! -d "$worktree_dir" ]; then
      echo "🌿 กำลังสร้างสภาพแวดล้อมการทำงานแยกอิสระ (Git Worktree) ที่ .relay/worktrees/$ACTIVE_TASK (กิ่ง $branch_name)..."
      git worktree add "$worktree_dir" -b "$branch_name" 2>/dev/null || git worktree add "$worktree_dir" "$branch_name" 2>/dev/null || true
    fi
    if [ -d "$worktree_dir" ]; then
      mkdir -p "$worktree_dir/.relay/tasks"
      cp -R "$RELAY_DIR/tasks/$ACTIVE_TASK" "$worktree_dir/.relay/tasks/" 2>/dev/null || true
      [ -f "$RELAY_DIR/PROJECT_STATE.md" ] && cp "$RELAY_DIR/PROJECT_STATE.md" "$worktree_dir/.relay/PROJECT_STATE.md" 2>/dev/null || true
      target_work_dir="$worktree_dir"
    fi
  fi

  local prompt="@dev กรุณาอ่านเอกสาร .relay/tasks/$ACTIVE_TASK/SPEC.md, ARCH.md และ PLAN.md แล้วดำเนินการพัฒนาโค้ดควบคู่กับชุดทดสอบ (Unit Tests) ตามแผนที่กำหนดไว้"
  launch_provider_cli "$ROLE_DEV" "$MODEL_DEV" "ขั้นตอนที่ 3: @dev (Full-Stack Developer ใน Git Worktree)" "$target_work_dir" "$prompt"
}

run_phase_4_qa() {
  ensure_or_create_task
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"
  local target_work_dir="$PROJECT_DIR"
  if [ -d "$worktree_dir" ]; then
    target_work_dir="$worktree_dir"
  fi

  local prompt="@qa @sec กรุณาตรวจสอบผลงานตามเกณฑ์ Acceptance Criteria ในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md โดย: 1. รันชุดทดสอบจริงของโครงการผ่าน Terminal (0 Token) 2. ตรวจสอบความปลอดภัยของ git diff ตามทักษะ differential-review และ semgrep 3. หากมีส่วนติดต่อผู้ใช้บนเว็บ ให้ใช้ Playwright MCP ทดสอบและบันทึกภาพหน้าจอไว้ที่ .relay/tasks/$ACTIVE_TASK/screenshots/ 4. สรุปผลการตรวจสอบลงในไฟล์ .relay/tasks/$ACTIVE_TASK/QA_REPORT.md และอัปเดตไฟล์ .relay/PROJECT_STATE.md ให้เป็นปัจจุบัน"
  launch_provider_cli "$ROLE_QA" "$MODEL_QA" "ขั้นตอนที่ 4: @qa & @sec (Quality Assurance & Security Auditor)" "$target_work_dir" "$prompt"

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
    launch_provider_cli "$ROLE_ARCH" "$MODEL_ARCH" "การสแกนโครงสร้างโครงการเดิม (@arch)" "$PROJECT_DIR" "$prompt"
  else
    "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" new
  fi
}

# 12. แสดงหน้าจอหลักของ RELAY Central Terminal Hub พร้อมสถานะการเชื่อมต่อและชื่อโมเดล
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

  local po_model arch_model dev_model qa_model
  local po_stat arch_stat dev_stat qa_stat
  po_model="$(get_effective_model_label "$ROLE_PO" "$MODEL_PO")"
  arch_model="$(get_effective_model_label "$ROLE_ARCH" "$MODEL_ARCH")"
  dev_model="$(get_effective_model_label "$ROLE_DEV" "$MODEL_DEV")"
  qa_model="$(get_effective_model_label "$ROLE_QA" "$MODEL_QA")"

  po_stat="$(get_provider_status "$ROLE_PO")"
  arch_stat="$(get_provider_status "$ROLE_ARCH")"
  dev_stat="$(get_provider_status "$ROLE_DEV")"
  qa_stat="$(get_provider_status "$ROLE_QA")"

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
  echo "🤖 สถานะตัวแทน AI, โมเดลปัจจุบัน และการเชื่อมต่อ ($CONFIG_SOURCE):"
  printf "   • ขั้นตอนที่ 1 (@po)       ➔ ค่าย: %-6s | โมเดล: %-22s | %s\n" "$ROLE_PO" "$po_model" "$po_stat"
  printf "   • ขั้นตอนที่ 2 (@arch/@pm) ➔ ค่าย: %-6s | โมเดล: %-22s | %s\n" "$ROLE_ARCH" "$arch_model" "$arch_stat"
  printf "   • ขั้นตอนที่ 3 (@dev)      ➔ ค่าย: %-6s | โมเดล: %-22s | %s\n" "$ROLE_DEV" "$dev_model" "$dev_stat"
  printf "   • ขั้นตอนที่ 4 (@qa/@sec)  ➔ ค่าย: %-6s | โมเดล: %-22s | %s\n" "$ROLE_QA" "$qa_model" "$qa_stat"
  echo "----------------------------------------------------------------------"
  echo "เลือกคำสั่งการทำงาน (พิมพ์หมายเลขหรือตัวอักษรแล้วกด Enter ในหน้าต่างนี้ได้เลย):"
  echo "  [1] เริ่มขั้นตอนที่ 1 (@po)        — วิเคราะห์ความต้องการและสร้าง SPEC.md"
  echo "  [2] เริ่มขั้นตอนที่ 2 (@arch/@pm)  — อ่าน SPEC.md แล้วสร้าง ARCH.md & PLAN.md"
  echo "  [3] เริ่มขั้นตอนที่ 3 (@dev)       — แยก Git Worktree อัตโนมัติและพัฒนาโค้ด"
  echo "  [4] เริ่มขั้นตอนที่ 4 (@qa/@sec)   — รันชุดทดสอบ + ตรวจความปลอดภัย + สรุป QA_REPORT.md"
  echo "  [5] ผสานโค้ดและจัดเก็บใบงาน      — Merge เข้ากิ่ง main และย้ายเข้า .relay/archive/"
  echo "----------------------------------------------------------------------"
  echo "  [c] ตั้งค่าค่าย AI & เลือกโมเดลประจำตำแหน่ง | [d] ตรวจสอบการเชื่อมต่อ & ติดตั้ง/Login CLI"
  echo "  [n] สร้างใบงานใหม่ (New Task)          | [i] เตรียม .relay/ (โครงการใหม่ / โครงการเดิม)"
  echo "  [s] จัดการ/อัปเดต Skills               | [q] ออกจากโปรแกรม"
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
  doctor)
    run_doctor_menu
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
  read -r -p "👉 เลือกคำสั่ง [1-5, c, d, n, i, s, q]: " action
  case "$action" in
    1) run_phase_1_po ;;
    2) run_phase_2_arch ;;
    3) run_phase_3_dev ;;
    4) run_phase_4_qa ;;
    5) run_phase_5_merge ;;
    c|C) configure_roles_menu ;;
    d|D) run_doctor_menu ;;
    n|N) create_new_task ;;
    i|I) run_init_project ;;
    s|S) run_skills_menu ;;
    q|Q|exit)
      echo "👋 ออกจากหน้าจอควบคุม RELAY เรียบร้อย"
      exit 0
      ;;
    *)
      echo "⚠️ กรุณาเลือกคำสั่งที่กำหนด (1-5, c, d, n, i, s, q)"
      ;;
  esac
done
