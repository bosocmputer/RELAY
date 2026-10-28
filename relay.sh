#!/usr/bin/env bash
set -e

# ==============================================================================
# 🎛️ RELAY Central Terminal Hub (v1.0) — Modern Interactive TUI (macOS / Linux)
# รองรับปุ่มลูกศร ↑/↓ + Enter, คีย์ลัด, Slash Commands (/model, /connect, /test)
# พร้อมตั้งค่าการเชื่อมต่อ CLI และเลือก Model ของแต่ละค่าย/ตำแหน่งในหน้าจอเดียว
# ==============================================================================

GLOBAL_DIR="$HOME/.agents"
GLOBAL_ROLES_CONF="$GLOBAL_DIR/relay-roles.conf"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
RELAY_DIR="$PROJECT_DIR/.relay"
PROJECT_ROLES_CONF="$RELAY_DIR/roles.conf"

# ─── รหัสสี ANSI มาตรฐาน (256-Color & Styling) ─────────────────────────────
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_CYAN="\033[38;5;51m"
C_BLUE="\033[38;5;75m"
C_INDIGO="\033[38;5;111m"
C_VIOLET="\033[38;5;141m"
C_PINK="\033[38;5;211m"
C_CORAL="\033[38;5;209m"
C_GOLD="\033[38;5;221m"
C_GREEN="\033[38;5;84m"
C_RED="\033[38;5;203m"
C_GRAY="\033[38;5;245m"
C_WHITE="\033[38;5;255m"
C_SEL_BG="\033[48;5;24m\033[38;5;255m\033[1m"

# ─── 1. โหลดและบันทึกการตั้งค่า Role & Model ─────────────────────────────────
load_role_config() {
  ROLE_PO="gemini";   MODEL_PO="default"
  ROLE_ARCH="claude"; MODEL_ARCH="default"
  ROLE_DEV="claude";  MODEL_DEV="default"
  ROLE_QA="codex";    MODEL_QA="default"
  CONFIG_SOURCE="Global (~/.agents/relay-roles.conf)"

  if [ -r "$GLOBAL_ROLES_CONF" ]; then
    # shellcheck disable=SC1090
    source "$GLOBAL_ROLES_CONF"
  fi
  if [ -r "$PROJECT_ROLES_CONF" ]; then
    # shellcheck disable=SC1090
    source "$PROJECT_ROLES_CONF"
    CONFIG_SOURCE="Project (.relay/roles.conf)"
  fi
}

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

# ─── 2. ตรวจสอบสถานะ CLI และอ่าน/บันทึก Default Model ของแต่ละค่าย ─────────
is_provider_installed() {
  command -v "$1" >/dev/null 2>&1
}

get_provider_version() {
  local provider="$1"
  if ! is_provider_installed "$provider"; then
    echo "ยังไม่ได้ติดตั้ง CLI"
    return
  fi
  local ver
  ver="$("$provider" --version 2>/dev/null | head -n 1 | tr -d '\r' || true)"
  echo "${ver:-installed}"
}

get_provider_status_badge() {
  local provider="$1"
  if is_provider_installed "$provider"; then
    local ver
    ver="$(get_provider_version "$provider")"
    printf "${C_GREEN}● พร้อมใช้งาน${C_RESET} ${C_DIM}(%s)${C_RESET}" "$ver"
  else
    printf "${C_RED}○ ยังไม่ติดตั้ง CLI${C_RESET} ${C_DIM}(กด [d] หรือ [c] เพื่อติดตั้ง)${C_RESET}"
  fi
}

get_cli_default_model() {
  local provider="$1"
  case "$provider" in
    claude)
      if [ -r "$HOME/.claude/settings.json" ]; then
        local cm
        cm="$(grep -Eo '"model"[[:space:]]*:[[:space:]]*"[^"]+"' "$HOME/.claude/settings.json" 2>/dev/null | head -n 1 | sed -E 's/.*"([^"]+)"$/\1/' || true)"
        [ -n "$cm" ] && { echo "$cm"; return; }
      fi
      echo "sonnet"
      ;;
    codex)
      if [ -r "$HOME/.codex/config.toml" ]; then
        local xm
        xm="$(grep -E '^[[:space:]]*model[[:space:]]*=' "$HOME/.codex/config.toml" 2>/dev/null | head -n 1 | sed -E 's/.*=[[:space:]]*"?([^"#[:space:]]+)"?.*/\1/' || true)"
        [ -n "$xm" ] && { echo "$xm"; return; }
      fi
      echo "o3"
      ;;
    gemini)
      if [ -r "$HOME/.gemini/settings.json" ]; then
        local gm
        gm="$(grep -Eo '"model"[[:space:]]*:[[:space:]]*"[^"]+"' "$HOME/.gemini/settings.json" 2>/dev/null | head -n 1 | sed -E 's/.*"([^"]+)"$/\1/' || true)"
        [ -n "$gm" ] && { echo "$gm"; return; }
      fi
      echo "gemini-2.5-pro"
      ;;
    *)
      echo "default"
      ;;
  esac
}

set_cli_default_model() {
  local provider="$1"
  local new_model="$2"
  [ -z "$new_model" ] || [ "$new_model" = "default" ] && return 0

  case "$provider" in
    claude)
      mkdir -p "$HOME/.claude"
      if [ -f "$HOME/.claude/settings.json" ] && grep -q '"model"' "$HOME/.claude/settings.json" 2>/dev/null; then
        sed -i.bak -E "s/\"model\"[[:space:]]*:[[:space:]]*\"[^\"]+\"/\"model\": \"$new_model\"/" "$HOME/.claude/settings.json" && rm -f "$HOME/.claude/settings.json.bak"
      elif [ ! -f "$HOME/.claude/settings.json" ]; then
        printf '{\n  "model": "%s"\n}\n' "$new_model" > "$HOME/.claude/settings.json"
      fi
      ;;
    gemini)
      mkdir -p "$HOME/.gemini"
      if [ -f "$HOME/.gemini/settings.json" ] && grep -q '"model"' "$HOME/.gemini/settings.json" 2>/dev/null; then
        sed -i.bak -E "s/\"model\"[[:space:]]*:[[:space:]]*\"[^\"]+\"/\"model\": \"$new_model\"/" "$HOME/.gemini/settings.json" && rm -f "$HOME/.gemini/settings.json.bak"
      elif [ ! -f "$HOME/.gemini/settings.json" ]; then
        printf '{\n  "model": "%s"\n}\n' "$new_model" > "$HOME/.gemini/settings.json"
      fi
      ;;
    codex)
      mkdir -p "$HOME/.codex"
      if [ -f "$HOME/.codex/config.toml" ] && grep -Eq '^[[:space:]]*model[[:space:]]*=' "$HOME/.codex/config.toml" 2>/dev/null; then
        sed -i.bak -E "s/^[[:space:]]*model[[:space:]]*=.*/model = \"$new_model\"/" "$HOME/.codex/config.toml" && rm -f "$HOME/.codex/config.toml.bak"
      else
        printf 'model = "%s"\n' "$new_model" >> "$HOME/.codex/config.toml"
      fi
      ;;
  esac
}

get_effective_model_label() {
  local provider="$1"
  local configured_model="${2:-default}"
  if [ -n "$configured_model" ] && [ "$configured_model" != "default" ]; then
    echo "$configured_model"
    return
  fi
  local cli_def
  cli_def="$(get_cli_default_model "$provider")"
  echo "$cli_def (CLI default)"
}

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

# ─── 3. Interactive Arrow-Key Selector Engine (รองรับลูกศร ↑/↓ + Enter + คีย์ลัด) ───
# การใช้งาน: interactive_menu "หัวข้อเมนู" "คีย์1|ข้อความ1" "คีย์2|ข้อความ2" ...
# ผลลัพธ์จะถูกเก็บไว้ในตัวแปร MENU_RESULT
MENU_RESULT=""
interactive_menu() {
  local title="$1"
  shift
  local items=("$@")
  local count="${#items[@]}"
  local selected=0

  # หากไม่ได้รันใน Interactive TTY (เช่น ทดสอบผ่าน Pipe) ให้รับค่าบรรทัดเดียวตามปกติ
  if [ ! -t 0 ]; then
    echo -e "\n${C_BOLD}${C_CYAN}${title}${C_RESET}"
    local idx=0
    while [ "$idx" -lt "$count" ]; do
      local entry="${items[$idx]}"
      local key="${entry%%|*}"
      local label="${entry#*|}"
      echo -e "  [${key}] ${label}"
      idx=$((idx + 1))
    done
    local input_val=""
    read -r input_val || true
    if [ -z "$input_val" ]; then
      MENU_RESULT="${items[0]%%|*}"
    else
      MENU_RESULT="$input_val"
    fi
    return 0
  fi

  echo -e "\n${C_BOLD}${C_GOLD}${title}${C_RESET}"
  echo -e "${C_DIM}ใช้ปุ่มลูกศร ↑/↓ เพื่อเลื่อนแถบสี แล้วกด Enter เพื่อเลือก (หรือกดคีย์ลัดในวงเล็บ [...] ได้ทันที)${C_RESET}"

  # ซ่อนเคอร์เซอร์ชั่วคราวขณะเลื่อนเมนู
  tput civis 2>/dev/null || true
  trap 'tput cnorm 2>/dev/null || true' EXIT INT TERM

  local first_draw=1
  while true; do
    if [ "$first_draw" -eq 0 ]; then
      printf "\033[%dA" "$((count + 3))"
    fi
    first_draw=0

    local i=0
    while [ "$i" -lt "$count" ]; do
      local entry="${items[$i]}"
      local key="${entry%%|*}"
      local label="${entry#*|}"
      printf "\033[2K\r"
      if [ "$i" -eq "$selected" ]; then
        printf "  ${C_SEL_BG} ❯ [%s] %-66s ${C_RESET}\n" "$key" "$label"
      else
        printf "    ${C_CYAN}[%s]${C_RESET} %s\n" "$key" "$label"
      fi
      i=$((i + 1))
    done

    local cur_key="${items[$selected]%%|*}"
    printf "\033[2K\r${C_GRAY}╭──────────────────────────────────────────────────────────────────────────────╮${C_RESET}\n"
    printf "\033[2K\r${C_GRAY}│${C_RESET} ${C_CYAN}❯${C_RESET} เลือก: ${C_BOLD}[%s]${C_RESET} ${C_DIM}(↑/↓ เลื่อน • Enter ยืนยัน • พิมพ์ / เพื่อใช้คำสั่ง /model, /connect, /test)${C_RESET}\n" "$cur_key"
    printf "\033[2K\r${C_GRAY}╰──────────────────────────────────────────────────────────────────────────────╯${C_RESET}\n"

    local k1="" k2="" k3=""
    IFS= read -rsn1 k1 || true

    # กด Enter -> เลือกรายการที่ไฮไลต์อยู่ทันที
    if [ -z "$k1" ]; then
      MENU_RESULT="${items[$selected]%%|*}"
      break
    fi

    # กดปุ่ม Escape / ลูกศร ↑ ↓
    if [ "$k1" = $'\x1b' ]; then
      IFS= read -rsn1 -t 0.05 k2 || true
      if [ "$k2" = "[" ]; then
        IFS= read -rsn1 -t 0.05 k3 || true
        case "$k3" in
          A) # ลูกศรขึ้น
            selected=$(((selected - 1 + count) % count))
            continue
            ;;
          B) # ลูกศรลง
            selected=$(((selected + 1) % count))
            continue
            ;;
        esac
      else
        # กด Esc เดี่ยวๆ -> ยกเลิก/กลับ
        MENU_RESULT="b"
        break
      fi
      continue
    fi

    # กดปุ่ม / -> เปิดโหมดพิมพ์ Slash Command
    if [ "$k1" = "/" ]; then
      tput cnorm 2>/dev/null || true
      printf "\033[2A\033[2K\r${C_GRAY}│${C_RESET} ${C_PINK}❯ /${C_RESET}"
      local slash_cmd=""
      read -r slash_cmd || true
      printf "\n\n"
      MENU_RESULT="/${slash_cmd}"
      return 0
    fi

    # ตรวจสอบว่าตรงกับคีย์ลัดของรายการใดหรือไม่
    local lower_k1
    lower_k1="$(echo "$k1" | tr '[:upper:]' '[:lower:]')"
    local match_idx=0
    while [ "$match_idx" -lt "$count" ]; do
      local item_key="${items[$match_idx]%%|*}"
      local lower_item_key
      lower_item_key="$(echo "$item_key" | tr '[:upper:]' '[:lower:]')"
      if [ "$lower_k1" = "$lower_item_key" ]; then
        MENU_RESULT="$item_key"
        tput cnorm 2>/dev/null || true
        return 0
      fi
      match_idx=$((match_idx + 1))
    done
  done

  tput cnorm 2>/dev/null || true
}

# ─── 4. แสดงหัวกระดาษ 3D Pixel-Block Banner + กรอบ 2 คอลัมน์ (RELAY TUI) ─────
print_dashboard_header() {
  load_role_config
  get_active_task

  local git_branch="no-git"
  if [ -d "$PROJECT_DIR/.git" ]; then
    git_branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
  fi

  local state_badge="${C_RED}○ ยังไม่มี PROJECT_STATE.md (กด [i])${C_RESET}"
  [ -f "$RELAY_DIR/PROJECT_STATE.md" ] && state_badge="${C_GREEN}● PROJECT_STATE.md พร้อมใช้งาน${C_RESET}"

  local spec_m="${C_DIM}[ ] SPEC.md${C_RESET}"
  local plan_m="${C_DIM}[ ] ARCH & PLAN${C_RESET}"
  local qa_m="${C_DIM}[ ] QA_REPORT.md${C_RESET}"
  if [ -n "$ACTIVE_TASK" ]; then
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ] && spec_m="${C_GREEN}[✓] SPEC.md${C_RESET}"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/PLAN.md" ] && plan_m="${C_GREEN}[✓] ARCH & PLAN${C_RESET}"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_REPORT.md" ] && qa_m="${C_GREEN}[✓] QA_REPORT.md${C_RESET}"
  fi

  local claude_dot="${C_RED}○${C_RESET}" gemini_dot="${C_RED}○${C_RESET}" codex_dot="${C_RED}○${C_RESET}"
  is_provider_installed "claude" && claude_dot="${C_GREEN}●${C_RESET}"
  is_provider_installed "gemini" && gemini_dot="${C_GREEN}●${C_RESET}"
  is_provider_installed "codex"  && codex_dot="${C_GREEN}●${C_RESET}"

  local po_model arch_model dev_model qa_model
  po_model="$(get_effective_model_label "$ROLE_PO" "$MODEL_PO")"
  arch_model="$(get_effective_model_label "$ROLE_ARCH" "$MODEL_ARCH")"
  dev_model="$(get_effective_model_label "$ROLE_DEV" "$MODEL_DEV")"
  qa_model="$(get_effective_model_label "$ROLE_QA" "$MODEL_QA")"

  local po_dot="${C_RED}○ ยังไม่ติดตั้ง${C_RESET}" arch_dot="${C_RED}○ ยังไม่ติดตั้ง${C_RESET}" dev_dot="${C_RED}○ ยังไม่ติดตั้ง${C_RESET}" qa_dot="${C_RED}○ ยังไม่ติดตั้ง${C_RESET}"
  is_provider_installed "$ROLE_PO"   && po_dot="${C_GREEN}● พร้อมใช้งาน${C_RESET}"
  is_provider_installed "$ROLE_ARCH" && arch_dot="${C_GREEN}● พร้อมใช้งาน${C_RESET}"
  is_provider_installed "$ROLE_DEV"  && dev_dot="${C_GREEN}● พร้อมใช้งาน${C_RESET}"
  is_provider_installed "$ROLE_QA"   && qa_dot="${C_GREEN}● พร้อมใช้งาน${C_RESET}"

  echo ""
  echo -e "${C_CORAL}╭──────────────────────────────────────────────────────────────────────────────╮${C_RESET}"
  echo -e "${C_CORAL}│${C_RESET} ${C_GOLD}✻${C_RESET} Welcome to ${C_BOLD}${C_WHITE}RELAY v1.0${C_RESET} — Multi-Agent Specification & Handoff Orchestrator   ${C_CORAL}│${C_RESET}"
  echo -e "${C_CORAL}╰──────────────────────────────────────────────────────────────────────────────╯${C_RESET}"

  # 3D Pixel-Block Gradient Banner (> RELAY)
  echo -e " ${C_CYAN}██╗   ${C_RESET}   ${C_BLUE}██████╗ ${C_RESET} ${C_INDIGO}███████╗${C_RESET} ${C_VIOLET}██╗     ${C_RESET} ${C_PINK} █████╗ ${C_RESET} ${C_CORAL}██╗   ██╗${C_RESET}"
  echo -e " ${C_CYAN}╚██╗  ${C_RESET}   ${C_BLUE}██╔══██╗${C_RESET} ${C_INDIGO}██╔════╝${C_RESET} ${C_VIOLET}██║     ${C_RESET} ${C_PINK}██╔══██╗${C_RESET} ${C_CORAL}╚██╗ ██╔╝${C_RESET}"
  echo -e " ${C_CYAN} ╚██╗ ${C_RESET}   ${C_BLUE}██████╔╝${C_RESET} ${C_INDIGO}█████╗  ${C_RESET} ${C_VIOLET}██║     ${C_RESET} ${C_PINK}███████║${C_RESET} ${C_CORAL} ╚████╔╝ ${C_RESET}"
  echo -e " ${C_CYAN} ██╔╝ ${C_RESET}   ${C_BLUE}██╔══██╗${C_RESET} ${C_INDIGO}██╔══╝  ${C_RESET} ${C_VIOLET}██║     ${C_RESET} ${C_PINK}██╔══██║${C_RESET} ${C_CORAL}  ╚██╔╝  ${C_RESET}"
  echo -e " ${C_CYAN}██╔╝  ${C_RESET}   ${C_BLUE}██║  ██║${C_RESET} ${C_INDIGO}███████╗${C_RESET} ${C_VIOLET}███████╗${C_RESET} ${C_PINK}██║  ██║${C_RESET} ${C_CORAL}   ██║   ${C_RESET}"
  echo -e " ${C_CYAN}╚═╝   ${C_RESET}   ${C_BLUE}╚═╝  ╚═╝${C_RESET} ${C_INDIGO}╚══════╝${C_RESET} ${C_VIOLET}╚══════╝${C_RESET} ${C_PINK}╚═╝  ╚═╝${C_RESET} ${C_CORAL}   ╚═╝   ${C_RESET}"

  # กรอบข้อมูลควบคุมหลัก (2-Column Style Card)
  echo -e "${C_GOLD}╭─────────────────────── RELAY v1.0 • Control Center ──────────────────────────╮${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET}  ${C_CYAN}    ╭───╮    ${C_RESET}  ${C_BOLD}${C_GOLD}ตำแหน่งตัวแทน AI (Roles), ค่าย (Provider) & โมเดลปัจจุบัน${C_RESET}"
  printf "${C_GOLD}│${C_RESET}  ${C_CYAN}  ╭─┤ R ├─╮  ${C_RESET}  ${C_BOLD}1. @po (Product)${C_RESET}   ➔ ${C_CYAN}%-6s${C_RESET} │ โมเดล: ${C_WHITE}%-20s${C_RESET} │ %b\n" "$ROLE_PO" "$po_model" "$po_dot"
  printf "${C_GOLD}│${C_RESET}  ${C_CYAN}  │ ╰─┬─╯ │  ${C_RESET}  ${C_BOLD}2. @arch & @pm${C_RESET}     ➔ ${C_CYAN}%-6s${C_RESET} │ โมเดล: ${C_WHITE}%-20s${C_RESET} │ %b\n" "$ROLE_ARCH" "$arch_model" "$arch_dot"
  printf "${C_GOLD}│${C_RESET}  ${C_VIOLET}  ╰───┼───╯  ${C_RESET}  ${C_BOLD}3. @dev (Worktree)${C_RESET} ➔ ${C_CYAN}%-6s${C_RESET} │ โมเดล: ${C_WHITE}%-20s${C_RESET} │ %b\n" "$ROLE_DEV" "$dev_model" "$dev_dot"
  printf "${C_GOLD}│${C_RESET}  ${C_PINK}    ╭─┴─╮    ${C_RESET}  ${C_BOLD}4. @qa & @sec${C_RESET}      ➔ ${C_CYAN}%-6s${C_RESET} │ โมเดล: ${C_WHITE}%-20s${C_RESET} │ %b\n" "$ROLE_QA" "$qa_model" "$qa_dot"
  echo -e "${C_GOLD}│${C_RESET}  ${C_PINK}    ╰───╯    ${C_RESET}  ${C_DIM}─────────────────────────────────────────────────────────────${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET}  ${C_BOLD}CLIs ในเครื่อง:${C_RESET}  ${C_BOLD}${C_GOLD}ชุดทักษะมาตรฐานประจำตำแหน่ง (Modular Skill Packs)${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET}   ${claude_dot} claude      ${C_DIM}@po   :${C_RESET} brainstorming, founder-skill"
  echo -e "${C_GOLD}│${C_RESET}   ${gemini_dot} gemini      ${C_DIM}@arch :${C_RESET} writing-plans, supabase-postgres-best-practices"
  echo -e "${C_GOLD}│${C_RESET}   ${codex_dot} codex       ${C_DIM}@dev  :${C_RESET} impeccable, vercel-react, lucide/simple-icons, tdd"
  echo -e "${C_GOLD}│${C_RESET}                 ${C_DIM}@qa   :${C_RESET} verification, differential-review, semgrep, playwright"
  echo -e "${C_GOLD}├──────────────────────────────────────────────────────────────────────────────┤${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET} 📂 ${C_BOLD}${PROJECT_NAME}${C_RESET} ${C_CYAN}[⎇ ${git_branch}]${C_RESET}  •  ${state_badge}  •  ⚙️ ${C_DIM}${CONFIG_SOURCE}${C_RESET}"
  if [ -n "$ACTIVE_TASK" ]; then
    echo -e "${C_GOLD}│${C_RESET} 📋 ใบงาน: ${C_BOLD}${C_WHITE}${ACTIVE_TASK}${C_RESET}  ➔  ${spec_m}   ${plan_m}   ${qa_m}"
  else
    echo -e "${C_GOLD}│${C_RESET} 📋 ใบงาน: ${C_DIM}(ยังไม่มีใบงานที่กำลังดำเนินการ — เลือก [1] หรือ [n] เพื่อสร้างใบงานใหม่)${C_RESET}"
  fi
  echo -e "${C_GOLD}╰──────────────────────────────────────────────────────────────────────────────╯${C_RESET}"
}

# ─── 5. เมนูเลือกค่าย AI และเลือก Model แบบ Interactive (ลูกศร ↑/↓) ──────────
choose_provider_interactive() {
  local role_label="$1"
  local current_p="$2"
  local c_stat g_stat x_stat
  c_stat="$(is_provider_installed claude && echo "✅ ติดตั้งแล้ว ($(get_cli_default_model claude))" || echo "❌ ยังไม่ติดตั้ง CLI")"
  g_stat="$(is_provider_installed gemini && echo "✅ ติดตั้งแล้ว ($(get_cli_default_model gemini))" || echo "❌ ยังไม่ติดตั้ง CLI")"
  x_stat="$(is_provider_installed codex  && echo "✅ ติดตั้งแล้ว ($(get_cli_default_model codex))"  || echo "❌ ยังไม่ติดตั้ง CLI")"

  interactive_menu "🤖 เลือกค่าย AI สำหรับ ${role_label} (ปัจจุบัน: ${current_p})" \
    "1|claude  — Anthropic Claude Code CLI  [${c_stat}]" \
    "2|gemini  — Google Gemini CLI          [${g_stat}]" \
    "3|codex   — OpenAI Codex CLI           [${x_stat}]" \
    "b|คงค่าเดิม (${current_p})"

  local chosen_p="$current_p"
  case "$MENU_RESULT" in
    1) chosen_p="claude" ;;
    2) chosen_p="gemini" ;;
    3) chosen_p="codex" ;;
    *) chosen_p="$current_p" ;;
  esac

  # หากค่ายที่เลือกยังไม่ได้ติดตั้ง CLI ให้ถามว่าจะติดตั้งและ Login เลยหรือไม่
  if ! is_provider_installed "$chosen_p"; then
    local pkg="@google/gemini-cli"
    [ "$chosen_p" = "claude" ] && pkg="@anthropic-ai/claude-code"
    [ "$chosen_p" = "codex" ]  && pkg="@openai/codex"

    interactive_menu "⚡ ค่าย '${chosen_p}' ยังไม่ได้ติดตั้งในเครื่อง คุณต้องการติดตั้งและเชื่อมต่อเลยหรือไม่?" \
      "1|ติดตั้ง ${chosen_p} อัตโนมัติเดี๋ยวนี้ (npm install -g ${pkg}) และเปิดหน้า Login" \
      "2|บันทึกให้ใช้ค่าย ${chosen_p} ไว้ก่อน (ติดตั้งภายหลัง)"
    if [ "$MENU_RESULT" = "1" ]; then
      npm install -g "$pkg"
      if is_provider_installed "$chosen_p"; then
        echo -e "${C_GREEN}✅ ติดตั้ง ${chosen_p} สำเร็จ! กำลังเปิดหน้า Login (พิมพ์ /exit เมื่อ Login เสร็จ)...${C_RESET}"
        "$chosen_p" || true
      fi
    fi
  fi

  SELECTED_PROVIDER="$chosen_p"
}

choose_model_interactive() {
  local provider="$1"
  local role_label="$2"
  local current_m="${3:-default}"
  local cli_def
  cli_def="$(get_cli_default_model "$provider")"

  case "$provider" in
    claude)
      interactive_menu "🧠 เลือก Model ของค่าย [claude] สำหรับ ${role_label} (ปัจจุบัน: ${current_m})" \
        "1|default           — ใช้โมเดลเริ่มต้นของ Claude CLI (${cli_def})" \
        "2|sonnet            — Claude Sonnet 4.5 (รวดเร็ว สมดุล เหมาะกับงานเขียนโค้ด)" \
        "3|opus              — Claude Opus 4.5 (วิเคราะห์เชิงลึก เหมาะกับงานสถาปัตยกรรม/ตรวจโค้ด)" \
        "4|haiku             — Claude Haiku 4.5 (ประหยัดโควตาสูงสุด)" \
        "5|claude-sonnet-4-5 — ระบุรหัสเต็ม claude-sonnet-4-5" \
        "6|claude-opus-4-5   — ระบุรหัสเต็ม claude-opus-4-5" \
        "7|กำหนดชื่อโมเดลเอง   — พิมพ์รหัส Model ID ที่ต้องการด้วยตนเอง" \
        "b|คงค่าเดิม (${current_m})"
      case "$MENU_RESULT" in
        1) SELECTED_MODEL="default" ;;
        2) SELECTED_MODEL="sonnet" ;;
        3) SELECTED_MODEL="opus" ;;
        4) SELECTED_MODEL="haiku" ;;
        5) SELECTED_MODEL="claude-sonnet-4-5" ;;
        6) SELECTED_MODEL="claude-opus-4-5" ;;
        7) read -r -p "ระบุชื่อ Model ของ Claude: " cm; SELECTED_MODEL="${cm:-default}" ;;
        *) SELECTED_MODEL="$current_m" ;;
      esac
      ;;
    gemini)
      interactive_menu "🧠 เลือก Model ของค่าย [gemini] สำหรับ ${role_label} (ปัจจุบัน: ${current_m})" \
        "1|default          — ใช้โมเดลเริ่มต้นของ Gemini CLI (${cli_def})" \
        "2|gemini-2.5-pro   — Gemini 2.5 Pro (วิเคราะห์ความต้องการและวางแผนเชิงลึก)" \
        "3|gemini-2.5-flash — Gemini 2.5 Flash (รวดเร็วสูง ประหยัดโควตา)" \
        "4|กำหนดชื่อโมเดลเอง — พิมพ์รหัส Model ID ที่ต้องการด้วยตนเอง" \
        "b|คงค่าเดิม (${current_m})"
      case "$MENU_RESULT" in
        1) SELECTED_MODEL="default" ;;
        2) SELECTED_MODEL="gemini-2.5-pro" ;;
        3) SELECTED_MODEL="gemini-2.5-flash" ;;
        4) read -r -p "ระบุชื่อ Model ของ Gemini: " gm; SELECTED_MODEL="${gm:-default}" ;;
        *) SELECTED_MODEL="$current_m" ;;
      esac
      ;;
    codex)
      interactive_menu "🧠 เลือก Model ของค่าย [codex] สำหรับ ${role_label} (ปัจจุบัน: ${current_m})" \
        "1|default          — ใช้โมเดลเริ่มต้นของ Codex CLI (${cli_def})" \
        "2|o3               — OpenAI o3 (ตรวจสอบโค้ดและหาช่องโหว่แม่นยำสูง)" \
        "3|o4-mini          — OpenAI o4-mini (รวดเร็ว ประหยัดโควตา)" \
        "4|gpt-5            — OpenAI GPT-5 (โมเดลเรือธงรุ่นล่าสุด)" \
        "5|กำหนดชื่อโมเดลเอง — พิมพ์รหัส Model ID ที่ต้องการด้วยตนเอง" \
        "b|คงค่าเดิม (${current_m})"
      case "$MENU_RESULT" in
        1) SELECTED_MODEL="default" ;;
        2) SELECTED_MODEL="o3" ;;
        3) SELECTED_MODEL="o4-mini" ;;
        4) SELECTED_MODEL="gpt-5" ;;
        5) read -r -p "ระบุชื่อ Model ของ Codex: " xm; SELECTED_MODEL="${xm:-default}" ;;
        *) SELECTED_MODEL="$current_m" ;;
      esac
      ;;
  esac
}

# ─── 6. ศูนย์ตั้งค่าจับคู่ค่าย AI, เลือก Model และการเชื่อมต่อ CLI ในหน้าเดียว ([c] / /model) ───
configure_roles_menu() {
  load_role_config
  local target_conf="$GLOBAL_ROLES_CONF"
  local scope_label="ส่วนกลาง (~/.agents/relay-roles.conf)"
  if [ -f "$PROJECT_ROLES_CONF" ]; then
    target_conf="$PROJECT_ROLES_CONF"
    scope_label="เฉพาะโครงการนี้ (.relay/roles.conf)"
  fi

  while true; do
    local m_po m_arch m_dev m_qa
    m_po="$(get_effective_model_label "$ROLE_PO" "$MODEL_PO")"
    m_arch="$(get_effective_model_label "$ROLE_ARCH" "$MODEL_ARCH")"
    m_dev="$(get_effective_model_label "$ROLE_DEV" "$MODEL_DEV")"
    m_qa="$(get_effective_model_label "$ROLE_QA" "$MODEL_QA")"

    interactive_menu "⚙️  ตั้งค่าค่าย AI และเลือก Model ประจำตำแหน่ง [บันทึกที่: ${scope_label}]" \
      "1|ขั้นตอนที่ 1 (@po)        ➔ ค่าย: ${ROLE_PO} | โมเดล: ${m_po}" \
      "2|ขั้นตอนที่ 2 (@arch/@pm)  ➔ ค่าย: ${ROLE_ARCH} | โมเดล: ${m_arch}" \
      "3|ขั้นตอนที่ 3 (@dev)       ➔ ค่าย: ${ROLE_DEV} | โมเดล: ${m_dev}" \
      "4|ขั้นตอนที่ 4 (@qa/@sec)   ➔ ค่าย: ${ROLE_QA} | โมเดล: ${m_qa}" \
      "p|ตั้งค่าด่วนรวดเดียว 4 ตำแหน่ง (Quick Presets: All-Claude / All-Gemini / All-Codex)" \
      "m|ตั้งค่า Default Model ของแต่ละค่ายโดยตรง (Claude / Gemini / Codex Settings)" \
      "d|จัดการการเชื่อมต่อ CLI (ติดตั้ง CLI / เปิดหน้า Login ของแต่ละค่าย)" \
      "s|สลับระดับไฟล์ที่บันทึก (Global ~/.agents/ ↔ Project .relay/roles.conf)" \
      "t|🧪 บันทึกและทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่งทันที (Readiness Test)" \
      "b|💾 บันทึกการตั้งค่าและกลับสู่หน้าจอหลัก"

    case "$MENU_RESULT" in
      1)
        choose_provider_interactive "ขั้นตอนที่ 1 (@po)" "$ROLE_PO"
        ROLE_PO="$SELECTED_PROVIDER"
        choose_model_interactive "$ROLE_PO" "ขั้นตอนที่ 1 (@po)" "$MODEL_PO"
        MODEL_PO="$SELECTED_MODEL"
        save_role_config "$target_conf"
        ;;
      2)
        choose_provider_interactive "ขั้นตอนที่ 2 (@arch/@pm)" "$ROLE_ARCH"
        ROLE_ARCH="$SELECTED_PROVIDER"
        choose_model_interactive "$ROLE_ARCH" "ขั้นตอนที่ 2 (@arch/@pm)" "$MODEL_ARCH"
        MODEL_ARCH="$SELECTED_MODEL"
        save_role_config "$target_conf"
        ;;
      3)
        choose_provider_interactive "ขั้นตอนที่ 3 (@dev)" "$ROLE_DEV"
        ROLE_DEV="$SELECTED_PROVIDER"
        choose_model_interactive "$ROLE_DEV" "ขั้นตอนที่ 3 (@dev)" "$MODEL_DEV"
        MODEL_DEV="$SELECTED_MODEL"
        save_role_config "$target_conf"
        ;;
      4)
        choose_provider_interactive "ขั้นตอนที่ 4 (@qa/@sec)" "$ROLE_QA"
        ROLE_QA="$SELECTED_PROVIDER"
        choose_model_interactive "$ROLE_QA" "ขั้นตอนที่ 4 (@qa/@sec)" "$MODEL_QA"
        MODEL_QA="$SELECTED_MODEL"
        save_role_config "$target_conf"
        ;;
      p|P)
        interactive_menu "⚡ เลือกชุดการตั้งค่าด่วน (Quick Preset สำหรับทั้ง 4 ตำแหน่ง)" \
          "1|All-Claude Preset  — ใช้ Claude Code ทุกตำแหน่ง (@po=sonnet, @arch=opus, @dev=sonnet, @qa=opus)" \
          "2|All-Gemini Preset  — ใช้ Gemini CLI ทุกตำแหน่ง (gemini-2.5-pro ทั้ง 4 ตำแหน่ง)" \
          "3|All-Codex Preset   — ใช้ OpenAI Codex ทุกตำแหน่ง (o3 ทั้ง 4 ตำแหน่ง)" \
          "4|Multi-Vendor แนะนำ — @po=gemini, @arch=claude(opus), @dev=claude(sonnet), @qa=codex(o3)" \
          "b|ย้อนกลับ"
        case "$MENU_RESULT" in
          1)
            ROLE_PO="claude"; MODEL_PO="sonnet"
            ROLE_ARCH="claude"; MODEL_ARCH="opus"
            ROLE_DEV="claude"; MODEL_DEV="sonnet"
            ROLE_QA="claude"; MODEL_QA="opus"
            save_role_config "$target_conf"
            ;;
          2)
            ROLE_PO="gemini"; MODEL_PO="gemini-2.5-pro"
            ROLE_ARCH="gemini"; MODEL_ARCH="gemini-2.5-pro"
            ROLE_DEV="gemini"; MODEL_DEV="gemini-2.5-pro"
            ROLE_QA="gemini"; MODEL_QA="gemini-2.5-pro"
            save_role_config "$target_conf"
            ;;
          3)
            ROLE_PO="codex"; MODEL_PO="o3"
            ROLE_ARCH="codex"; MODEL_ARCH="o3"
            ROLE_DEV="codex"; MODEL_DEV="o3"
            ROLE_QA="codex"; MODEL_QA="o3"
            save_role_config "$target_conf"
            ;;
          4)
            ROLE_PO="gemini"; MODEL_PO="gemini-2.5-pro"
            ROLE_ARCH="claude"; MODEL_ARCH="opus"
            ROLE_DEV="claude"; MODEL_DEV="sonnet"
            ROLE_QA="codex"; MODEL_QA="o3"
            save_role_config "$target_conf"
            ;;
        esac
        ;;
      m|M)
        configure_provider_defaults_menu
        ;;
      d|D)
        run_doctor_menu
        ;;
      s|S)
        if [ "$target_conf" = "$GLOBAL_ROLES_CONF" ]; then
          target_conf="$PROJECT_ROLES_CONF"
          scope_label="เฉพาะโครงการนี้ (.relay/roles.conf)"
        else
          target_conf="$GLOBAL_ROLES_CONF"
          scope_label="ส่วนกลาง (~/.agents/relay-roles.conf)"
        fi
        save_role_config "$target_conf"
        ;;
      t|T)
        save_role_config "$target_conf"
        echo -e "${C_GREEN}✅ บันทึกการตั้งค่าลงใน ${target_conf} เรียบร้อยแล้ว!${C_RESET}"
        run_agent_readiness_test
        return 0
        ;;
      b|B|q|Q|*)
        save_role_config "$target_conf"
        echo -e "${C_GREEN}✅ บันทึกการตั้งค่าลงใน ${target_conf} เรียบร้อยแล้ว!${C_RESET}"
        return 0
        ;;
    esac
  done
}

# ─── 7. ตั้งค่า Default Model ของแต่ละค่ายโดยตรง (Claude / Gemini / Codex) ────
configure_provider_defaults_menu() {
  while true; do
    local cm gm xm
    cm="$(get_cli_default_model claude)"
    gm="$(get_cli_default_model gemini)"
    xm="$(get_cli_default_model codex)"

    interactive_menu "🧠 ตั้งค่า Default Model เริ่มต้นของแต่ละค่าย (มีผลกับไฟล์ตั้งค่าของ CLI โดยตรง)" \
      "1|Claude Code CLI (~/.claude/settings.json) — ค่าเริ่มต้นปัจจุบัน: ${cm}" \
      "2|Google Gemini CLI (~/.gemini/settings.json) — ค่าเริ่มต้นปัจจุบัน: ${gm}" \
      "3|OpenAI Codex CLI (~/.codex/config.toml)   — ค่าเริ่มต้นปัจจุบัน: ${xm}" \
      "b|ย้อนกลับ"

    case "$MENU_RESULT" in
      1)
        choose_model_interactive "claude" "ค่าเริ่มต้นของ Claude Code CLI" "$cm"
        if [ "$SELECTED_MODEL" != "default" ]; then
          set_cli_default_model "claude" "$SELECTED_MODEL"
          echo -e "${C_GREEN}✅ ตั้งค่า Default Model ของ Claude Code เป็น '${SELECTED_MODEL}' เรียบร้อยแล้ว!${C_RESET}"
        fi
        ;;
      2)
        choose_model_interactive "gemini" "ค่าเริ่มต้นของ Gemini CLI" "$gm"
        if [ "$SELECTED_MODEL" != "default" ]; then
          set_cli_default_model "gemini" "$SELECTED_MODEL"
          echo -e "${C_GREEN}✅ ตั้งค่า Default Model ของ Gemini CLI เป็น '${SELECTED_MODEL}' เรียบร้อยแล้ว!${C_RESET}"
        fi
        ;;
      3)
        choose_model_interactive "codex" "ค่าเริ่มต้นของ OpenAI Codex CLI" "$xm"
        if [ "$SELECTED_MODEL" != "default" ]; then
          set_cli_default_model "codex" "$SELECTED_MODEL"
          echo -e "${C_GREEN}✅ ตั้งค่า Default Model ของ Codex CLI เป็น '${SELECTED_MODEL}' เรียบร้อยแล้ว!${C_RESET}"
        fi
        ;;
      *)
        break
        ;;
    esac
  done
}

# ─── 8. ศูนย์จัดการการเชื่อมต่อ CLI, ติดตั้ง และ Login (RELAY Doctor / /connect) ─
run_doctor_menu() {
  while true; do
    echo ""
    echo -e "${C_GOLD}╭──────────────────── 🔌 RELAY CLI Connection & Login Hub ─────────────────────╮${C_RESET}"
    for p in claude gemini codex; do
      local pkg="@google/gemini-cli"
      [ "$p" = "claude" ] && pkg="@anthropic-ai/claude-code"
      [ "$p" = "codex" ]  && pkg="@openai/codex"
      local def_m
      def_m="$(get_cli_default_model "$p")"

      if is_provider_installed "$p"; then
        local bin_p ver_s
        bin_p="$(command -v "$p")"
        ver_s="$(get_provider_version "$p")"
        printf "${C_GOLD}│${C_RESET}  ${C_GREEN}●${C_RESET} ${C_BOLD}%-8s${C_RESET} : ติดตั้งแล้ว (${C_CYAN}%s${C_RESET}) • Default Model: ${C_WHITE}%s${C_RESET}\n" "$p" "$ver_s" "$def_m"
        printf "${C_GOLD}│${C_RESET}               ${C_DIM}Path: %s${C_RESET}\n" "$bin_p"
      else
        printf "${C_GOLD}│${C_RESET}  ${C_RED}○${C_RESET} ${C_BOLD}%-8s${C_RESET} : ${C_RED}ยังไม่ได้ติดตั้งในเครื่อง${C_RESET} ${C_DIM}(แพ็กเกจ: %s)${C_RESET}\n" "$p" "$pkg"
      fi
    done
    echo -e "${C_GOLD}╰──────────────────────────────────────────────────────────────────────────────╯${C_RESET}"

    interactive_menu "🔌 เลือกการจัดการเชื่อมต่อ CLI และบัญชีผู้ใช้งาน" \
      "1|ติดตั้ง / อัปเดต Google Gemini CLI  (npm install -g @google/gemini-cli)" \
      "2|ติดตั้ง / อัปเดต OpenAI Codex CLI   (npm install -g @openai/codex)" \
      "3|ติดตั้ง / อัปเดต Claude Code CLI    (npm install -g @anthropic-ai/claude-code)" \
      "4|ติดตั้งรวดเดียวครบทั้ง 3 ค่าย (claude + gemini + codex)" \
      "5|🔑 เปิด Claude Code เพื่อเข้าสู่ระบบ (Login / เช็กสถานะบัญชี)" \
      "6|🔑 เปิด Gemini CLI เพื่อเข้าสู่ระบบ (Login ด้วยบัญชี Google)" \
      "7|🔑 เปิด OpenAI Codex เพื่อเข้าสู่ระบบ (Login ด้วยบัญชี ChatGPT/OpenAI)" \
      "m|🧠 ตั้งค่า Default Model เริ่มต้นของแต่ละค่าย (Claude / Gemini / Codex)" \
      "b|กลับสู่หน้าจอหลัก"

    case "$MENU_RESULT" in
      1) npm install -g @google/gemini-cli ;;
      2) npm install -g @openai/codex ;;
      3) npm install -g @anthropic-ai/claude-code ;;
      4) npm install -g @anthropic-ai/claude-code @google/gemini-cli @openai/codex ;;
      5)
        if is_provider_installed claude; then
          echo -e "${C_CYAN}💡 กำลังเปิด claude เพื่อให้คุณ Login/เช็กสถานะ (พิมพ์ /exit เพื่อกลับมาหน้านี้)...${C_RESET}"
          claude || true
        else
          echo -e "${C_RED}❌ ยังไม่ได้ติดตั้ง claude (กรุณาเลือก [3] เพื่อติดตั้งก่อน)${C_RESET}"
        fi
        ;;
      6)
        if is_provider_installed gemini; then
          echo -e "${C_CYAN}💡 กำลังเปิด gemini เพื่อให้คุณ Login ด้วย Google (พิมพ์ /exit เพื่อกลับมาหน้านี้)...${C_RESET}"
          gemini || true
        else
          echo -e "${C_RED}❌ ยังไม่ได้ติดตั้ง gemini (กรุณาเลือก [1] เพื่อติดตั้งก่อน)${C_RESET}"
        fi
        ;;
      7)
        if is_provider_installed codex; then
          echo -e "${C_CYAN}💡 กำลังเปิด codex เพื่อให้คุณ Login ด้วย OpenAI (พิมพ์ /exit เพื่อกลับมาหน้านี้)...${C_RESET}"
          codex || true
        else
          echo -e "${C_RED}❌ ยังไม่ได้ติดตั้ง codex (กรุณาเลือก [2] เพื่อติดตั้งก่อน)${C_RESET}"
        fi
        ;;
      m|M) configure_provider_defaults_menu ;;
      *) break ;;
    esac
  done
}

# ─── 9. ทดสอบความพร้อมของ Agent แต่ละตำแหน่ง ([t] / /test) ─────────────────
check_role_skills_status() {
  local skills_list="$1"
  local output=""
  for sk in $skills_list; do
    if [ -d "$GLOBAL_DIR/skills/$sk" ]; then
      output="${output}${C_GREEN}[✓] ${sk}${C_RESET}  "
    else
      output="${output}${C_CYAN}[•] ${sk}${C_RESET}  "
    fi
  done
  echo -e "$output"
}

get_provider_rules_status() {
  local provider="$1"
  case "$provider" in
    claude) [ -e "$HOME/.claude/CLAUDE.md" ] && echo -e "${C_GREEN}✅ เชื่อมต่อ ~/.claude/CLAUDE.md แล้ว${C_RESET}" || echo -e "${C_RED}❌ ยังไม่พบ ~/.claude/CLAUDE.md${C_RESET}" ;;
    codex)  [ -e "$HOME/.codex/AGENTS.md" ]  && echo -e "${C_GREEN}✅ เชื่อมต่อ ~/.codex/AGENTS.md แล้ว${C_RESET}"  || echo -e "${C_RED}❌ ยังไม่พบ ~/.codex/AGENTS.md${C_RESET}" ;;
    gemini) [ -e "$HOME/.gemini/GEMINI.md" ] && echo -e "${C_GREEN}✅ เชื่อมต่อ ~/.gemini/GEMINI.md แล้ว${C_RESET}" || echo -e "${C_RED}❌ ยังไม่พบ ~/.gemini/GEMINI.md${C_RESET}" ;;
    *) echo "⚠️ ไม่ทราบค่าย" ;;
  esac
}

ping_single_role_agent() {
  local role_code="$1"
  local role_title="$2"
  local provider="$3"
  local configured_model="$4"
  local expected_skills="$5"
  local expected_duty="$6"
  local model_label
  model_label="$(get_effective_model_label "$provider" "$configured_model")"

  echo ""
  echo -e "${C_GOLD}╭──────────────────────────────────────────────────────────────────────────────╮${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET} 🧪 กำลังทดสอบรายงานตัวของ: ${C_BOLD}${C_WHITE}${role_title}${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET}    • ค่าย / โมเดล : ${C_CYAN}${provider}${C_RESET} (${C_WHITE}${model_label}${C_RESET})"
  echo -e "${C_GOLD}│${C_RESET}    • ทักษะประจำตัว: ${C_DIM}${expected_skills}${C_RESET}"
  echo -e "${C_GOLD}╰──────────────────────────────────────────────────────────────────────────────╯${C_RESET}"

  if ! is_provider_installed "$provider"; then
    echo -e "${C_RED}❌ ไม่สามารถยิงทดสอบ ${role_code} ได้ เนื่องจากยังไม่ได้ติดตั้ง CLI ค่าย '${provider}' ในเครื่อง${C_RESET}"
    echo -e "   👉 เลือกเมนู ${C_CYAN}[d]${C_RESET} เพื่อติดตั้ง '${provider}' หรือเลือก ${C_CYAN}[c]${C_RESET} เพื่อสลับไปใช้ค่ายที่มีในเครื่อง"
    return 1
  fi

  local self_check_prompt="นี่คือการทดสอบความพร้อมของระบบ RELAY v1.0 กรุณารายงานตัวสั้นๆ ไม่เกิน 4 บรรทัด (ห้ามรันคำสั่งแก้ไขไฟล์ใดๆ) โดยระบุข้อมูลดังนี้:
1. ยืนยันบทบาทของคุณคือ '$role_title' (ทำงานผ่านค่าย $provider โมเดล $model_label)
2. สรุปหน้าที่หลักของคุณในระบบ RELAY ($expected_duty)
3. ยืนยันชุดทักษะ (Skills) ประจำตำแหน่งของคุณ ได้แก่: $expected_skills
4. ปิดท้ายด้วยข้อความ 'สถานะ: พร้อมปฏิบัติงาน 100%'"

  echo -e "${C_DIM}⏳ กำลังส่งคำสั่งทดสอบไปยัง ${provider} (${model_label})...${C_RESET}"
  local exit_code=0
  case "$provider" in
    claude)
      if [ -n "$configured_model" ] && [ "$configured_model" != "default" ]; then
        claude --model "$configured_model" -p "$self_check_prompt" || exit_code=$?
      else
        claude -p "$self_check_prompt" || exit_code=$?
      fi
      ;;
    gemini)
      if [ -n "$configured_model" ] && [ "$configured_model" != "default" ]; then
        gemini -m "$configured_model" -p "$self_check_prompt" || exit_code=$?
      else
        gemini -p "$self_check_prompt" || exit_code=$?
      fi
      ;;
    codex)
      if [ -n "$configured_model" ] && [ "$configured_model" != "default" ]; then
        codex -m "$configured_model" exec "$self_check_prompt" 2>/dev/null || codex -m "$configured_model" -q "$self_check_prompt" || exit_code=$?
      else
        codex exec "$self_check_prompt" 2>/dev/null || codex -q "$self_check_prompt" || exit_code=$?
      fi
      ;;
  esac

  if [ "$exit_code" -eq 0 ]; then
    echo -e "${C_GREEN}✅ [ผ่านการทดสอบ] ${role_title} เชื่อมต่อกับ ${provider} (${model_label}) และพร้อมใช้งาน 100%!${C_RESET}"
  else
    echo -e "${C_RED}❌ [ไม่ผ่านการทดสอบ] ${role_title} ไม่สามารถรับคำสั่งผ่าน ${provider} (${model_label}) ได้ (กรุณาเช็กการ Login ในเมนู [d])${C_RESET}"
  fi
}

run_agent_readiness_test() {
  load_role_config
  local po_model arch_model dev_model qa_model
  po_model="$(get_effective_model_label "$ROLE_PO" "$MODEL_PO")"
  arch_model="$(get_effective_model_label "$ROLE_ARCH" "$MODEL_ARCH")"
  dev_model="$(get_effective_model_label "$ROLE_DEV" "$MODEL_DEV")"
  qa_model="$(get_effective_model_label "$ROLE_QA" "$MODEL_QA")"

  local po_skills="brainstorming founder-skill"
  local arch_skills="writing-plans supabase-postgres-best-practices"
  local dev_skills="impeccable vercel-react-best-practices lucide-icons simple-icons test-driven-development systematic-debugging"
  local qa_skills="verification-before-completion differential-review semgrep playwright-qa"

  echo ""
  echo -e "${C_GOLD}╭──────────── 🧪 RELAY Agent Readiness & Skill Verification ──────────────────╮${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET} ${C_BOLD}1️⃣  ขั้นตอนที่ 1: @po (Product Owner — วิเคราะห์ความต้องการและสร้าง SPEC.md)${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET}    • ค่าย / โมเดล : ${C_CYAN}${ROLE_PO}${C_RESET} │ โมเดล: ${C_WHITE}${po_model}${C_RESET} │ $(get_provider_status_badge "$ROLE_PO")"
  echo -e "${C_GOLD}│${C_RESET}    • กฎส่วนกลาง  : $(get_provider_rules_status "$ROLE_PO")"
  echo -e "${C_GOLD}│${C_RESET}    • ทักษะประจำตัว: $(check_role_skills_status "$po_skills")"
  echo -e "${C_GOLD}│${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET} ${C_BOLD}2️⃣  ขั้นตอนที่ 2: @arch & @pm (System Architect & Planner — สร้าง ARCH.md & PLAN.md)${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET}    • ค่าย / โมเดล : ${C_CYAN}${ROLE_ARCH}${C_RESET} │ โมเดล: ${C_WHITE}${arch_model}${C_RESET} │ $(get_provider_status_badge "$ROLE_ARCH")"
  echo -e "${C_GOLD}│${C_RESET}    • กฎส่วนกลาง  : $(get_provider_rules_status "$ROLE_ARCH")"
  echo -e "${C_GOLD}│${C_RESET}    • ทักษะประจำตัว: $(check_role_skills_status "$arch_skills")"
  echo -e "${C_GOLD}│${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET} ${C_BOLD}3️⃣  ขั้นตอนที่ 3: @dev (Full-Stack Developer — พัฒนาโค้ดและ Unit Tests ใน Git Worktree)${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET}    • ค่าย / โมเดล : ${C_CYAN}${ROLE_DEV}${C_RESET} │ โมเดล: ${C_WHITE}${dev_model}${C_RESET} │ $(get_provider_status_badge "$ROLE_DEV")"
  echo -e "${C_GOLD}│${C_RESET}    • กฎส่วนกลาง  : $(get_provider_rules_status "$ROLE_DEV")"
  echo -e "${C_GOLD}│${C_RESET}    • ทักษะประจำตัว: $(check_role_skills_status "$dev_skills")"
  echo -e "${C_GOLD}│${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET} ${C_BOLD}4️⃣  ขั้นตอนที่ 4: @qa & @sec (QA Verifier & Security Auditor — สร้าง QA_REPORT.md)${C_RESET}"
  echo -e "${C_GOLD}│${C_RESET}    • ค่าย / โมเดล : ${C_CYAN}${ROLE_QA}${C_RESET} │ โมเดล: ${C_WHITE}${qa_model}${C_RESET} │ $(get_provider_status_badge "$ROLE_QA")"
  echo -e "${C_GOLD}│${C_RESET}    • กฎส่วนกลาง  : $(get_provider_rules_status "$ROLE_QA")"
  echo -e "${C_GOLD}│${C_RESET}    • ทักษะประจำตัว: $(check_role_skills_status "$qa_skills")"
  echo -e "${C_GOLD}╰──────────────────────────────────────────────────────────────────────────────╯${C_RESET}"

  interactive_menu "🧪 เลือกตำแหน่งที่ต้องการยิงคำสั่งทดสอบให้ AI รายงานบทบาทและ Skills จริง (Live Handshake)" \
    "1|ทดสอบรวดเดียวครบทั้ง 4 ตำแหน่ง (@po, @arch/@pm, @dev, @qa/@sec)" \
    "2|ทดสอบเฉพาะ ขั้นตอนที่ 1 (@po        ➔ ${ROLE_PO} / ${po_model})" \
    "3|ทดสอบเฉพาะ ขั้นตอนที่ 2 (@arch/@pm  ➔ ${ROLE_ARCH} / ${arch_model})" \
    "4|ทดสอบเฉพาะ ขั้นตอนที่ 3 (@dev       ➔ ${ROLE_DEV} / ${dev_model})" \
    "5|ทดสอบเฉพาะ ขั้นตอนที่ 4 (@qa/@sec   ➔ ${ROLE_QA} / ${qa_model})" \
    "b|กลับสู่หน้าจอหลัก"

  case "$MENU_RESULT" in
    1)
      ping_single_role_agent "@po" "ขั้นตอนที่ 1: @po (Product Owner)" "$ROLE_PO" "$MODEL_PO" "$po_skills" "ซักถามความต้องการและสรุปเป็นเอกสาร SPEC.md" || true
      ping_single_role_agent "@arch/@pm" "ขั้นตอนที่ 2: @arch & @pm (System Architect & Planner)" "$ROLE_ARCH" "$MODEL_ARCH" "$arch_skills" "อ่าน PROJECT_STATE.md และ SPEC.md เพื่อออกแบบ ARCH.md และจัดทำ PLAN.md" || true
      ping_single_role_agent "@dev" "ขั้นตอนที่ 3: @dev (Full-Stack Developer)" "$ROLE_DEV" "$MODEL_DEV" "$dev_skills" "เขียนโค้ดและชุดทดสอบภายใน Git Worktree ตามแผนที่กำหนด" || true
      ping_single_role_agent "@qa/@sec" "ขั้นตอนที่ 4: @qa & @sec (Quality Assurance & Security Auditor)" "$ROLE_QA" "$MODEL_QA" "$qa_skills" "รันชุดทดสอบจริง ตรวจสอบความปลอดภัย และสรุปลงใน QA_REPORT.md" || true
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
      ;;
    2)
      ping_single_role_agent "@po" "ขั้นตอนที่ 1: @po (Product Owner)" "$ROLE_PO" "$MODEL_PO" "$po_skills" "ซักถามความต้องการและสรุปเป็นเอกสาร SPEC.md" || true
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
      ;;
    3)
      ping_single_role_agent "@arch/@pm" "ขั้นตอนที่ 2: @arch & @pm (System Architect & Planner)" "$ROLE_ARCH" "$MODEL_ARCH" "$arch_skills" "อ่าน PROJECT_STATE.md และ SPEC.md เพื่อออกแบบ ARCH.md และจัดทำ PLAN.md" || true
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
      ;;
    4)
      ping_single_role_agent "@dev" "ขั้นตอนที่ 3: @dev (Full-Stack Developer)" "$ROLE_DEV" "$MODEL_DEV" "$dev_skills" "เขียนโค้ดและชุดทดสอบภายใน Git Worktree ตามแผนที่กำหนด" || true
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
      ;;
    5)
      ping_single_role_agent "@qa/@sec" "ขั้นตอนที่ 4: @qa & @sec (Quality Assurance & Security Auditor)" "$ROLE_QA" "$MODEL_QA" "$qa_skills" "รันชุดทดสอบจริง ตรวจสอบความปลอดภัย และสรุปลงใน QA_REPORT.md" || true
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
      ;;
  esac
}

# ─── 10. เรียกใช้งาน CLI ของแต่ละขั้นตอน (Phase 1 - 5) ───────────────────────
launch_provider_cli() {
  local provider="$1"
  local configured_model="$2"
  local role_name="$3"
  local work_dir="$4"
  local initial_prompt="$5"
  local model_label
  model_label="$(get_effective_model_label "$provider" "$configured_model")"

  echo ""
  echo -e "${C_CYAN}╭──────────────────────────────────────────────────────────────────────────────╮${C_RESET}"
  echo -e "${C_CYAN}│${C_RESET} 🚀 กำลังเข้าสู่ ${C_BOLD}${C_WHITE}${role_name}${C_RESET}"
  echo -e "${C_CYAN}│${C_RESET}    • ค่ายผู้ให้บริการ : ${C_GOLD}${provider}${C_RESET}  │  โมเดลที่ใช้: ${C_WHITE}${model_label}${C_RESET}"
  echo -e "${C_CYAN}│${C_RESET}    • โฟลเดอร์ทำงาน  : ${C_DIM}${work_dir}${C_RESET}"
  echo -e "${C_CYAN}├──────────────────────────────────────────────────────────────────────────────┤${C_RESET}"
  echo -e "${C_CYAN}│${C_RESET} 📋 คำสั่งเริ่มต้น (คัดลอกลง Clipboard ให้แล้วอัตโนมัติ):"
  echo -e "${C_DIM}${initial_prompt}${C_RESET}"
  echo -e "${C_CYAN}├──────────────────────────────────────────────────────────────────────────────┤${C_RESET}"
  echo -e "${C_CYAN}│${C_RESET} 💡 เมื่อสนทนาและสร้างเอกสารของขั้นตอนนี้เสร็จแล้ว ให้พิมพ์ ${C_BOLD}/exit${C_RESET} เพื่อกลับมาหน้าจอ RELAY"
  echo -e "${C_CYAN}╰──────────────────────────────────────────────────────────────────────────────╯${C_RESET}"

  if command -v pbcopy >/dev/null 2>&1; then
    printf "%s" "$initial_prompt" | pbcopy
  fi

  if ! is_provider_installed "$provider"; then
    echo -e "${C_RED}⚠️ ยังไม่ได้ติดตั้งโปรแกรม '${provider}' ในเครื่องของคุณ!${C_RESET}"
    interactive_menu "ต้องการติดตั้ง '${provider}' ตอนนี้หรือสลับไปใช้ค่ายอื่น?" \
      "1|ติดตั้ง '${provider}' อัตโนมัติเดี๋ยวนี้ (ผ่านเมนูเชื่อมต่อ CLI)" \
      "2|สลับตำแหน่งนี้ไปใช้ค่ายอื่นที่มีในเครื่อง (ผ่านเมนูตั้งค่าค่าย/Model)" \
      "b|กลับสู่หน้าจอหลัก"
    case "$MENU_RESULT" in
      1) run_doctor_menu ;;
      2) configure_roles_menu ;;
    esac
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
    esac
  )
}

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
  echo -e "${C_GREEN}✅ สร้างใบงานใหม่เรียบร้อย: .relay/tasks/${ACTIVE_TASK}${C_RESET}"
}

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
      echo -e "${C_CYAN}🌿 กำลังสร้าง Git Worktree แยกอิสระที่ .relay/worktrees/${ACTIVE_TASK} (กิ่ง ${branch_name})...${C_RESET}"
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
  [ -d "$worktree_dir" ] && target_work_dir="$worktree_dir"

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
    echo -e "${C_RED}⚠️ ยังไม่มีใบงานที่กำลังดำเนินการใน .relay/tasks/${C_RESET}"
    return
  fi
  local branch_name="feat/$ACTIVE_TASK"
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"

  interactive_menu "🏁 ยืนยันการผสานโค้ดกิ่ง ${branch_name} เข้าสู่ main และจัดเก็บใบงาน ${ACTIVE_TASK}" \
    "y|ยืนยัน — ผสานโค้ดเข้ากิ่งหลัก ลบ Worktree และย้ายใบงานเข้า .relay/archive/" \
    "n|ยกเลิก — กลับสู่หน้าจอหลัก"

  if [ "$MENU_RESULT" = "y" ]; then
    if [ -d "$PROJECT_DIR/.git" ] && git show-ref --verify --quiet "refs/heads/$branch_name"; then
      git merge "$branch_name" || true
      [ -d "$worktree_dir" ] && { git worktree remove "$worktree_dir" --force 2>/dev/null || rm -rf "$worktree_dir"; }
      git branch -d "$branch_name" 2>/dev/null || true
    fi
    mkdir -p "$RELAY_DIR/archive"
    mv "$RELAY_DIR/tasks/$ACTIVE_TASK" "$RELAY_DIR/archive/$ACTIVE_TASK"
    CURRENT_TASK=""
    echo -e "${C_GREEN}✅ ผสานโค้ดและย้ายใบงานไปที่ .relay/archive/${ACTIVE_TASK} เรียบร้อยแล้ว!${C_RESET}"
  fi
}

run_init_project() {
  interactive_menu "📂 เลือกประเภทโครงการที่ต้องการเตรียมโครงสร้าง .relay/" \
    "1|โครงการใหม่ตั้งแต่ศูนย์ (Greenfield Project — สร้างโครงสร้าง .relay/ ทันที)" \
    "2|โครงการเดิมที่มีโค้ดอยู่แล้ว (Brownfield — สั่ง @arch สแกนโค้ดสรุปลง PROJECT_STATE.md)" \
    "b|ย้อนกลับ"
  case "$MENU_RESULT" in
    1) "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" new ;;
    2)
      "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" existing
      local prompt="@arch ช่วยสำรวจและวิเคราะห์โครงสร้างของโครงการเดิมนี้ทั้งหมด (ประกอบด้วย Tech Stack, โครงสร้างโฟลเดอร์สำคัญ, รูปแบบฐานข้อมูล/Schema, รายการ API หลัก และคำสั่งที่ใช้ในการ Build/Test) แล้วสรุปเขียนทับลงในไฟล์ .relay/PROJECT_STATE.md ให้มีความชัดเจนและกระชับ (ความยาวไม่เกิน 2 หน้า) โดยห้ามแก้ไขไฟล์โค้ดใดๆ ของระบบ"
      launch_provider_cli "$ROLE_ARCH" "$MODEL_ARCH" "การสแกนโครงสร้างโครงการเดิม (@arch)" "$PROJECT_DIR" "$prompt"
      ;;
  esac
}

run_skills_menu() {
  local skills_cmd="$GLOBAL_DIR/bin/relay-skills"
  [ ! -x "$skills_cmd" ] && skills_cmd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/relay-skills.sh"

  interactive_menu "🧰 จัดการและอัปเดตชุดทักษะ (RELAY Modular Skill Packs)" \
    "1|แสดงรายการทักษะทั้งหมดในคลังและที่ติดตั้งแล้วในเครื่อง (list)" \
    "2|ติดตั้งชุดทักษะมาตรฐานทั้งหมดลงเครื่อง (install)" \
    "3|อัปเดตทักษะทั้งหมดให้เป็นเวอร์ชันล่าสุดจาก GitHub (update)" \
    "4|เพิ่มทักษะใหม่จากลิงก์ GitHub Repository (add)" \
    "b|กลับสู่หน้าจอหลัก"

  case "$MENU_RESULT" in
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

# ─── 11. รองรับ Subcommands จากบรรทัดคำสั่งโดยตรง ──────────────────────────────
SUBCOMMAND="${1:-hub}"
case "$SUBCOMMAND" in
  status)
    print_dashboard_header
    exit 0
    ;;
  config|model)
    configure_roles_menu
    exit 0
    ;;
  test)
    run_agent_readiness_test
    exit 0
    ;;
  doctor|connect)
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

# ─── 12. Interactive Main Loop (ใช้ปุ่มลูกศร ↑/↓ + Enter หรือคีย์ลัด หรือ /command) ───
while true; do
  print_dashboard_header

  interactive_menu "🎛️  เลือกคำสั่งการทำงาน (ใช้ปุ่มลูกศร ↑/↓ เลื่อนแถบสีแล้วกด Enter)" \
    "1|เริ่มขั้นตอนที่ 1 (@po)        — วิเคราะห์ความต้องการและสร้าง SPEC.md" \
    "2|เริ่มขั้นตอนที่ 2 (@arch/@pm)  — อ่าน SPEC.md แล้วสร้าง ARCH.md & PLAN.md" \
    "3|เริ่มขั้นตอนที่ 3 (@dev)       — แยก Git Worktree อัตโนมัติและพัฒนาโค้ด" \
    "4|เริ่มขั้นตอนที่ 4 (@qa/@sec)   — รันชุดทดสอบ + ตรวจความปลอดภัย + สรุป QA_REPORT.md" \
    "5|ผสานโค้ดและจัดเก็บใบงาน      — Merge เข้ากิ่ง main และย้ายเข้า .relay/archive/" \
    "c|ตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่ง (/model)" \
    "d|จัดการการเชื่อมต่อ CLI, ติดตั้ง & Login ทั้ง 3 ค่าย (/connect)" \
    "t|ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่ง — เช็กบทบาท & Skills (/test)" \
    "s|จัดการและอัปเดตชุดทักษะ Skills (/skills)" \
    "n|สร้างใบงานใหม่ (New Task) (/new)" \
    "i|เตรียมโครงสร้าง .relay/ สำหรับโครงการใหม่หรือโครงการเดิม (/init)" \
    "q|ออกจากโปรแกรม (/quit)"

  case "$MENU_RESULT" in
    1|/po|/1)             run_phase_1_po ;;
    2|/arch|/pm|/2)       run_phase_2_arch ;;
    3|/dev|/3)            run_phase_3_dev ;;
    4|/qa|/sec|/4)        run_phase_4_qa ;;
    5|/merge|/5)          run_phase_5_merge ;;
    c|C|m|M|/model|/config) configure_roles_menu ;;
    d|D|/connect|/doctor|/login) run_doctor_menu ;;
    t|T|/test|/check)     run_agent_readiness_test ;;
    s|S|/skills)          run_skills_menu ;;
    n|N|/new)             create_new_task ;;
    i|I|/init)            run_init_project ;;
    q|Q|/quit|/exit|exit)
      echo -e "${C_CYAN}👋 ออกจากหน้าจอควบคุม RELAY เรียบร้อย${C_RESET}"
      exit 0
      ;;
  esac
done
