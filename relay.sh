#!/usr/bin/env bash
set -e

# ==============================================================================
# 🎛️ RELAY Central Terminal Hub (v1.0) — Full-Color Interactive TUI (macOS/Linux)
# • 3D Two-Tone Pixel-Block Gradient Banner (> RELAY)
# • รองรับปุ่มลูกศร ↑/↓ + Enter, คีย์ลัด, Slash Commands (/model, /connect, /test)
# • ระบบ Readiness Gate: บังคับตั้งค่า Roles + Provider + Model ให้ครบทั้ง 4 ตำแหน่งก่อนเริ่มถามงาน
# ==============================================================================

GLOBAL_DIR="$HOME/.agents"
GLOBAL_ROLES_CONF="$GLOBAL_DIR/relay-roles.conf"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
RELAY_DIR="$PROJECT_DIR/.relay"
PROJECT_ROLES_CONF="$RELAY_DIR/roles.conf"

# ─── ระบบสี ANSI 256-Color เต็มรูปแบบ (บังคับแสดงสีเสมอใน Terminal) ─────────────
export CLICOLOR=1
export CLICOLOR_FORCE=1
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_DIM=$'\033[2m'

# สีหลักของธีมและเงา 3 มิติ
C_CYAN=$'\033[1;38;5;51m'
C_CYAN_SH=$'\033[38;5;31m'
C_BLUE=$'\033[1;38;5;75m'
C_BLUE_SH=$'\033[38;5;25m'
C_INDIGO=$'\033[1;38;5;111m'
C_INDIGO_SH=$'\033[38;5;61m'
C_VIOLET=$'\033[1;38;5;141m'
C_VIOLET_SH=$'\033[38;5;97m'
C_PINK=$'\033[1;38;5;213m'
C_PINK_SH=$'\033[38;5;162m'
C_CORAL=$'\033[1;38;5;209m'
C_CORAL_SH=$'\033[38;5;130m'

# สีประจำบทบาทและสถานะ
C_GOLD=$'\033[1;38;5;220m'
C_AMBER=$'\033[38;5;214m'
C_GREEN=$'\033[1;38;5;84m'
C_MINT=$'\033[1;38;5;48m'
C_RED=$'\033[1;38;5;203m'
C_GRAY=$'\033[38;5;242m'
C_LIGHT_GRAY=$'\033[38;5;250m'
C_WHITE=$'\033[1;38;5;255m'

# สีแถบไฮไลต์เมื่อเลื่อนปุ่มลูกศร ↑/↓
C_SEL_BG=$'\033[48;5;24m\033[1;38;5;255m'
C_LOCK_BG=$'\033[48;5;52m\033[1;38;5;210m'

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

# ─── 2. ตรวจสอบสถานะ CLI, สีประจำค่าย และระบบ 4-Role Readiness Gate ─────────
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

format_provider_colored() {
  local provider="$1"
  case "$provider" in
    claude) printf "%s%-6s%s" "$C_CORAL" "claude" "$C_RESET" ;;
    gemini) printf "%s%-6s%s" "$C_BLUE"  "gemini" "$C_RESET" ;;
    codex)  printf "%s%-6s%s" "$C_GREEN" "codex"  "$C_RESET" ;;
    *)      printf "%s%-6s%s" "$C_WHITE" "$provider" "$C_RESET" ;;
  esac
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

# ตรวจสอบว่าโมเดลของตำแหน่งนั้นถูกเลือกกำหนดไว้อย่างชัดเจนหรือยัง
is_model_explicitly_set() {
  local m="$1"
  [ -n "$m" ] && [ "$m" != "default" ] && [ "$m" != "unconfigured" ] && [ "$m" != "none" ]
}

# ตรวจสอบว่าตำแหน่งนั้นพร้อมใช้งานครบทั้ง CLI และ Model หรือยัง
is_role_ready() {
  local provider="$1"
  local model="$2"
  is_provider_installed "$provider" && is_model_explicitly_set "$model"
}

# นับจำนวนตำแหน่งที่ตั้งค่าพร้อมครบถ้วน (จากทั้งหมด 4 ตำแหน่ง)
READY_ROLE_COUNT=0
ALL_ROLES_READY=0
check_all_roles_ready() {
  load_role_config
  READY_ROLE_COUNT=0
  is_role_ready "$ROLE_PO"   "$MODEL_PO"   && READY_ROLE_COUNT=$((READY_ROLE_COUNT + 1))
  is_role_ready "$ROLE_ARCH" "$MODEL_ARCH" && READY_ROLE_COUNT=$((READY_ROLE_COUNT + 1))
  is_role_ready "$ROLE_DEV"  "$MODEL_DEV"  && READY_ROLE_COUNT=$((READY_ROLE_COUNT + 1))
  is_role_ready "$ROLE_QA"   "$MODEL_QA"   && READY_ROLE_COUNT=$((READY_ROLE_COUNT + 1))

  if [ "$READY_ROLE_COUNT" -eq 4 ]; then
    ALL_ROLES_READY=1
  else
    ALL_ROLES_READY=0
  fi
}

get_effective_model_label() {
  local provider="$1"
  local configured_model="${2:-default}"
  if is_model_explicitly_set "$configured_model"; then
    echo "$configured_model"
    return
  fi
  local cli_def
  cli_def="$(get_cli_default_model "$provider")"
  echo "ยังไม่ระบุ (ค่าเริ่มต้น: $cli_def)"
}

format_role_status_cell() {
  local provider="$1"
  local model="$2"
  if ! is_provider_installed "$provider"; then
    printf "%s✖ ยังไม่ติดตั้ง CLI (กด [c]/[d])%s" "$C_RED" "$C_RESET"
  elif ! is_model_explicitly_set "$model"; then
    printf "%s⚠️ รอเลือกโมเดล (กด [c])%s" "$C_GOLD" "$C_RESET"
  else
    printf "%s● พร้อมใช้งาน 100%%%s" "$C_GREEN" "$C_RESET"
  fi
}

format_role_model_cell() {
  local provider="$1"
  local model="$2"
  if is_model_explicitly_set "$model"; then
    printf "%s%-22s%s" "$C_WHITE" "$model" "$C_RESET"
  else
    local cli_def
    cli_def="$(get_cli_default_model "$provider")"
    printf "%s%-22s%s" "$C_GOLD" "ยังไม่เลือก ($cli_def)" "$C_RESET"
  fi
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

# ─── 3. Interactive Arrow-Key Selector Engine (รองรับสีสันเต็มรูปแบบ + ↑/↓ + Enter) ───
# รูปแบบรายการ: "คีย์|ข้อความแสดงผลปกติ (ใส่สีได้)|ข้อความตอนไฮไลต์ (ไม่มีรหัสสีซ้อน)"
MENU_RESULT=""
interactive_menu() {
  local title="$1"
  local default_sel="${2:-0}"
  shift 2
  local items=("$@")
  local count="${#items[@]}"
  local selected="$default_sel"
  [ "$selected" -ge "$count" ] && selected=0

  if [ ! -t 0 ]; then
    echo -e "\n${C_BOLD}${C_GOLD}${title}${C_RESET}"
    local idx=0
    while [ "$idx" -lt "$count" ]; do
      local entry="${items[$idx]}"
      local key="${entry%%|*}"
      local rest="${entry#*|}"
      local colored_lbl="${rest%%|*}"
      printf "  [%s] %b\n" "$key" "$colored_lbl"
      idx=$((idx + 1))
    done
    local input_val=""
    read -r input_val || true
    if [ -z "$input_val" ]; then
      MENU_RESULT="${items[$selected]%%|*}"
    else
      MENU_RESULT="$input_val"
    fi
    return 0
  fi

  printf "\n%s%s%s\n" "$C_BOLD" "$title" "$C_RESET"
  printf "%sใช้ปุ่มลูกศร ↑/↓ เลื่อนแถบสี • กด Enter เพื่อยืนยัน • หรือกดคีย์ลัดในวงเล็บ [...] ได้ทันที%s\n" "$C_LIGHT_GRAY" "$C_RESET"

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
      local rest="${entry#*|}"
      local colored_lbl="${rest%%|*}"
      local plain_lbl="${rest#*|}"
      [ "$plain_lbl" = "$colored_lbl" ] && plain_lbl="$(echo -e "$colored_lbl" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g')"

      printf "\033[2K\r"
      if [ "$i" -eq "$selected" ]; then
        printf "  %s ❯ [%s] %-68s %s\n" "$C_SEL_BG" "$key" "$plain_lbl" "$C_RESET"
      else
        printf "    %s[%s]%s %b\n" "$C_CYAN" "$key" "$C_RESET" "$colored_lbl"
      fi
      i=$((i + 1))
    done

    local cur_key="${items[$selected]%%|*}"
    printf "\033[2K\r%s╭──────────────────────────────────────────────────────────────────────────────╮%s\n" "$C_INDIGO" "$C_RESET"
    printf "\033[2K\r%s│%s %s❯%s คำสั่งที่เลือก: %s[%s]%s  %s(↑/↓ เลื่อน • Enter เลือก • กด / พิมพ์คำสั่ง /model, /connect, /test)%s\n" "$C_INDIGO" "$C_RESET" "$C_PINK" "$C_RESET" "$C_GOLD" "$cur_key" "$C_RESET" "$C_LIGHT_GRAY" "$C_RESET"
    printf "\033[2K\r%s╰──────────────────────────────────────────────────────────────────────────────╯%s\n" "$C_INDIGO" "$C_RESET"

    local k1="" k2="" k3=""
    IFS= read -rsn1 k1 || true

    if [ -z "$k1" ]; then
      MENU_RESULT="${items[$selected]%%|*}"
      break
    fi

    if [ "$k1" = $'\x1b' ]; then
      IFS= read -rsn1 -t 0.05 k2 || true
      if [ "$k2" = "[" ]; then
        IFS= read -rsn1 -t 0.05 k3 || true
        case "$k3" in
          A) selected=$(((selected - 1 + count) % count)); continue ;;
          B) selected=$(((selected + 1) % count)); continue ;;
        esac
      else
        MENU_RESULT="b"
        break
      fi
      continue
    fi

    if [ "$k1" = "/" ]; then
      tput cnorm 2>/dev/null || true
      printf "\033[2A\033[2K\r%s│%s %s❯ /%s" "$C_INDIGO" "$C_RESET" "$C_PINK" "$C_RESET"
      local slash_cmd=""
      read -r slash_cmd || true
      printf "\n\n"
      MENU_RESULT="/${slash_cmd}"
      return 0
    fi

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

# ─── 4. แสดงหัวกระดาษ 3D Dual-Tone Banner + กรอบ 2 คอลัมน์สีสันเต็มรูปแบบ ─────
print_dashboard_header() {
  check_all_roles_ready
  get_active_task

  local git_branch="no-git"
  if [ -d "$PROJECT_DIR/.git" ]; then
    git_branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
  fi

  local state_badge="${C_RED}○ ยังไม่มี PROJECT_STATE.md (กด [i])${C_RESET}"
  [ -f "$RELAY_DIR/PROJECT_STATE.md" ] && state_badge="${C_GREEN}● PROJECT_STATE.md พร้อมใช้งาน${C_RESET}"

  local spec_m="${C_GRAY}[ ] SPEC.md${C_RESET}"
  local plan_m="${C_GRAY}[ ] ARCH & PLAN${C_RESET}"
  local qa_m="${C_GRAY}[ ] QA_REPORT.md${C_RESET}"
  if [ -n "$ACTIVE_TASK" ]; then
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ] && spec_m="${C_GREEN}[✓] SPEC.md${C_RESET}"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/PLAN.md" ] && plan_m="${C_GREEN}[✓] ARCH & PLAN${C_RESET}"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_REPORT.md" ] && qa_m="${C_GREEN}[✓] QA_REPORT.md${C_RESET}"
  fi

  local claude_dot="${C_RED}○${C_RESET}" gemini_dot="${C_RED}○${C_RESET}" codex_dot="${C_RED}○${C_RESET}"
  is_provider_installed "claude" && claude_dot="${C_GREEN}●${C_RESET}"
  is_provider_installed "gemini" && gemini_dot="${C_GREEN}●${C_RESET}"
  is_provider_installed "codex"  && codex_dot="${C_GREEN}●${C_RESET}"

  local p_po p_arch p_dev p_qa
  p_po="$(format_provider_colored "$ROLE_PO")"
  p_arch="$(format_provider_colored "$ROLE_ARCH")"
  p_dev="$(format_provider_colored "$ROLE_DEV")"
  p_qa="$(format_provider_colored "$ROLE_QA")"

  local m_po m_arch m_dev m_qa
  m_po="$(format_role_model_cell "$ROLE_PO" "$MODEL_PO")"
  m_arch="$(format_role_model_cell "$ROLE_ARCH" "$MODEL_ARCH")"
  m_dev="$(format_role_model_cell "$ROLE_DEV" "$MODEL_DEV")"
  m_qa="$(format_role_model_cell "$ROLE_QA" "$MODEL_QA")"

  local s_po s_arch s_dev s_qa
  s_po="$(format_role_status_cell "$ROLE_PO" "$MODEL_PO")"
  s_arch="$(format_role_status_cell "$ROLE_ARCH" "$MODEL_ARCH")"
  s_dev="$(format_role_status_cell "$ROLE_DEV" "$MODEL_DEV")"
  s_qa="$(format_role_status_cell "$ROLE_QA" "$MODEL_QA")"

  echo ""
  printf "%s╭──────────────────────────────────────────────────────────────────────────────╮%s\n" "$C_CORAL" "$C_RESET"
  printf "%s│%s %s✻%s Welcome to %sRELAY v1.0%s — %sMulti-Agent Specification & Handoff Orchestrator%s   %s│%s\n" "$C_CORAL" "$C_RESET" "$C_GOLD" "$C_RESET" "$C_WHITE" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CORAL" "$C_RESET"
  printf "%s╰──────────────────────────────────────────────────────────────────────────────╯%s\n" "$C_CORAL" "$C_RESET"

  # 3D Dual-Tone Pixel-Block Gradient Banner (> RELAY) — แยกสีตัวอักษรหลัก (█) กับเงา 3 มิติ (╔═╗║╚╝)
  printf " %s██%s╗      %s██████%s╗  %s███████%s╗ %s██%s╗       %s█████%s╗  %s██%s╗   %s██%s╗\n" \
    "$C_CYAN" "$C_CYAN_SH" "$C_BLUE" "$C_BLUE_SH" "$C_INDIGO" "$C_INDIGO_SH" "$C_VIOLET" "$C_VIOLET_SH" "$C_PINK" "$C_PINK_SH" "$C_CORAL" "$C_CORAL_SH" "$C_CORAL" "$C_CORAL_SH"
  printf " %s╚%s██%s╗     %s██%s╔══%s██%s╗ %s██%s╔════╝ %s██%s║      %s██%s╔══%s██%s╗ %s╚%s██%s╗ %s██%s╔╝\n" \
    "$C_CYAN_SH" "$C_CYAN" "$C_CYAN_SH" "$C_BLUE" "$C_BLUE_SH" "$C_BLUE" "$C_BLUE_SH" "$C_INDIGO" "$C_INDIGO_SH" "$C_VIOLET" "$C_VIOLET_SH" "$C_PINK" "$C_PINK_SH" "$C_PINK" "$C_PINK_SH" "$C_CORAL_SH" "$C_CORAL" "$C_CORAL_SH" "$C_CORAL" "$C_CORAL_SH"
  printf "  %s╚%s██%s╗    %s██████%s╔╝ %s█████%s╗   %s██%s║      %s███████%s║  %s╚%s████%s╔╝ %s\n" \
    "$C_CYAN_SH" "$C_CYAN" "$C_CYAN_SH" "$C_BLUE" "$C_BLUE_SH" "$C_INDIGO" "$C_INDIGO_SH" "$C_VIOLET" "$C_VIOLET_SH" "$C_PINK" "$C_PINK_SH" "$C_CORAL_SH" "$C_CORAL" "$C_CORAL_SH" "$C_RESET"
  printf "  %s██%s╔╝    %s██%s╔══%s██%s╗ %s██%s╔══╝   %s██%s║      %s██%s╔══%s██%s║   %s╚%s██%s╔╝  %s\n" \
    "$C_CYAN" "$C_CYAN_SH" "$C_BLUE" "$C_BLUE_SH" "$C_BLUE" "$C_BLUE_SH" "$C_INDIGO" "$C_INDIGO_SH" "$C_VIOLET" "$C_VIOLET_SH" "$C_PINK" "$C_PINK_SH" "$C_PINK" "$C_PINK_SH" "$C_CORAL_SH" "$C_CORAL" "$C_CORAL_SH" "$C_RESET"
  printf " %s██%s╔╝     %s██%s║  %s██%s║ %s███████%s╗ %s███████%s╗ %s██%s║  %s██%s║    %s██%s║   %s\n" \
    "$C_CYAN" "$C_CYAN_SH" "$C_BLUE" "$C_BLUE_SH" "$C_BLUE" "$C_BLUE_SH" "$C_INDIGO" "$C_INDIGO_SH" "$C_VIOLET" "$C_VIOLET_SH" "$C_PINK" "$C_PINK_SH" "$C_PINK" "$C_PINK_SH" "$C_CORAL" "$C_CORAL_SH" "$C_RESET"
  printf " %s╚═╝      %s╚═╝  ╚═╝ %s╚══════╝ %s╚══════╝ %s╚═╝  ╚═╝    %s╚═╝   %s\n" \
    "$C_CYAN_SH" "$C_BLUE_SH" "$C_INDIGO_SH" "$C_VIOLET_SH" "$C_PINK_SH" "$C_CORAL_SH" "$C_RESET"

  # กรอบข้อมูลควบคุมหลัก (2-Column Color Card)
  printf "%s╭─────────────────────── %sRELAY v1.0 • Control Center%s ──────────────────────────╮%s\n" "$C_GOLD" "$C_WHITE" "$C_GOLD" "$C_RESET"
  printf "%s│%s  %s    ╭───╮    %s  %sตำแหน่งตัวแทน AI (Roles), ค่าย (Provider) & โมเดลปัจจุบัน%s\n" "$C_GOLD" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_GOLD" "$C_RESET"
  printf "%s│%s  %s  ╭─┤ %sR%s ├─╮  %s  %s1. @po (Product)%s   ➔ %b │ โมเดล: %b │ %b\n" "$C_GOLD" "$C_RESET" "$C_CYAN" "$C_WHITE" "$C_CYAN" "$C_RESET" "$C_PINK" "$C_RESET" "$p_po" "$m_po" "$s_po"
  printf "%s│%s  %s  │ ╰─┬─╯ │  %s  %s2. @arch & @pm%s     ➔ %b │ โมเดล: %b │ %b\n" "$C_GOLD" "$C_RESET" "$C_BLUE" "$C_RESET" "$C_GOLD" "$C_RESET" "$p_arch" "$m_arch" "$s_arch"
  printf "%s│%s  %s  ╰───┼───╯  %s  %s3. @dev (Worktree)%s ➔ %b │ โมเดล: %b │ %b\n" "$C_GOLD" "$C_RESET" "$C_VIOLET" "$C_RESET" "$C_CYAN" "$C_RESET" "$p_dev" "$m_dev" "$s_dev"
  printf "%s│%s  %s    ╭─┴─╮    %s  %s4. @qa & @sec%s      ➔ %b │ โมเดล: %b │ %b\n" "$C_GOLD" "$C_RESET" "$C_PINK" "$C_RESET" "$C_MINT" "$C_RESET" "$p_qa" "$m_qa" "$s_qa"
  printf "%s│%s  %s    ╰───╯    %s  %s─────────────────────────────────────────────────────────────%s\n" "$C_GOLD" "$C_RESET" "$C_CORAL" "$C_RESET" "$C_GRAY" "$C_RESET"
  printf "%s│%s  %sCLIs ในเครื่อง:%s  %sชุดทักษะมาตรฐานประจำตำแหน่ง (Modular Skill Packs)%s\n" "$C_GOLD" "$C_RESET" "$C_WHITE" "$C_RESET" "$C_GOLD" "$C_RESET"
  printf "%s│%s   %b %sclaude%s      %s@po   :%s %sbrainstorming, founder-skill%s\n" "$C_GOLD" "$C_RESET" "$claude_dot" "$C_CORAL" "$C_RESET" "$C_PINK" "$C_RESET" "$C_LIGHT_GRAY" "$C_RESET"
  printf "%s│%s   %b %sgemini%s      %s@arch :%s %swriting-plans, supabase-postgres-best-practices%s\n" "$C_GOLD" "$C_RESET" "$gemini_dot" "$C_BLUE" "$C_RESET" "$C_GOLD" "$C_RESET" "$C_LIGHT_GRAY" "$C_RESET"
  printf "%s│%s   %b %scodex%s       %s@dev  :%s %simpeccable, vercel-react, lucide/simple-icons, tdd%s\n" "$C_GOLD" "$C_RESET" "$codex_dot" "$C_GREEN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_LIGHT_GRAY" "$C_RESET"
  printf "%s│%s                 %s@qa   :%s %sverification, differential-review, semgrep, playwright%s\n" "$C_GOLD" "$C_RESET" "$C_MINT" "$C_RESET" "$C_LIGHT_GRAY" "$C_RESET"
  printf "%s├──────────────────────────────────────────────────────────────────────────────┤%s\n" "$C_GOLD" "$C_RESET"

  # แถบสถานะความพร้อมของทั้ง 4 ตำแหน่ง (4-Role Readiness Gate Banner)
  if [ "$ALL_ROLES_READY" -eq 1 ]; then
    printf "%s│%s 🔓 %sสถานะความพร้อม: ✅ ตั้งค่าครบทั้ง 4/4 ตำแหน่งแล้ว — พร้อมเริ่มถาม/สั่งงาน [1]-[5] ทันที!%s\n" "$C_GOLD" "$C_RESET" "$C_GREEN" "$C_RESET"
  else
    printf "%s│%s 🔒 %sสถานะความพร้อม: ตั้งค่าพร้อม %d/4 ตำแหน่ง — กรุณาตั้งค่าค่าย & โมเดลให้ครบทั้ง 4 ตำแหน่งใน [c] ก่อนเริ่มงาน!%s\n" "$C_GOLD" "$C_RESET" "$C_RED" "$READY_ROLE_COUNT" "$C_RESET"
  fi

  printf "%s├──────────────────────────────────────────────────────────────────────────────┤%s\n" "$C_GOLD" "$C_RESET"
  printf "%s│%s 📂 %s%s%s %s[⎇ %s]%s  •  %b  •  ⚙️ %s%s%s\n" "$C_GOLD" "$C_RESET" "$C_WHITE" "$PROJECT_NAME" "$C_RESET" "$C_CYAN" "$git_branch" "$C_RESET" "$state_badge" "$C_LIGHT_GRAY" "$CONFIG_SOURCE" "$C_RESET"
  if [ -n "$ACTIVE_TASK" ]; then
    printf "%s│%s 📋 ใบงาน: %s%s%s  ➔  %b   %b   %b\n" "$C_GOLD" "$C_RESET" "$C_GOLD" "$ACTIVE_TASK" "$C_RESET" "$spec_m" "$plan_m" "$qa_m"
  else
    printf "%s│%s 📋 ใบงาน: %s(ยังไม่มีใบงานที่กำลังดำเนินการ — เลือก [1] หรือ [n] เพื่อสร้างใบงานใหม่)%s\n" "$C_GOLD" "$C_RESET" "$C_LIGHT_GRAY" "$C_RESET"
  fi
  printf "%s╰──────────────────────────────────────────────────────────────────────────────╯%s\n" "$C_GOLD" "$C_RESET"
}

# ─── 5. ฟังก์ชันตรวจสอบและบล็อกการถามงานหากยังตั้งค่าไม่ครบ 4 ตำแหน่ง ──────────
require_all_roles_ready() {
  check_all_roles_ready
  if [ "$ALL_ROLES_READY" -eq 1 ]; then
    return 0
  fi

  echo ""
  printf "%s╭────────────────── 🔒 ยังไม่สามารถเริ่มถามหรือสั่งงาน Agent ได้ ───────────────────╮%s\n" "$C_RED" "$C_RESET"
  printf "%s│%s ระบบกำหนดให้ต้องตั้งค่า %sตำแหน่ง (Roles) + ค่าย (Provider) + โมเดล (Model)%s      %s│%s\n" "$C_RED" "$C_RESET" "$C_GOLD" "$C_RESET" "$C_RED" "$C_RESET"
  printf "%s│%s ให้พร้อมใช้งานครบทั้ง %s4/4 ตำแหน่ง%s ก่อนเริ่มสนทนากับตัวแทน AI (ปัจจุบันพร้อม %d/4): %s│%s\n" "$C_RED" "$C_RESET" "$C_WHITE" "$C_RESET" "$READY_ROLE_COUNT" "$C_RED" "$C_RESET"
  printf "%s├──────────────────────────────────────────────────────────────────────────────┤%s\n" "$C_RED" "$C_RESET"
  printf "%s│%s  • ขั้นตอนที่ 1 (@po)       : %b (%s) ➔ %b\n" "$C_RED" "$C_RESET" "$(format_provider_colored "$ROLE_PO")" "$MODEL_PO" "$(format_role_status_cell "$ROLE_PO" "$MODEL_PO")"
  printf "%s│%s  • ขั้นตอนที่ 2 (@arch/@pm) : %b (%s) ➔ %b\n" "$C_RED" "$C_RESET" "$(format_provider_colored "$ROLE_ARCH")" "$MODEL_ARCH" "$(format_role_status_cell "$ROLE_ARCH" "$MODEL_ARCH")"
  printf "%s│%s  • ขั้นตอนที่ 3 (@dev)      : %b (%s) ➔ %b\n" "$C_RED" "$C_RESET" "$(format_provider_colored "$ROLE_DEV")" "$MODEL_DEV" "$(format_role_status_cell "$ROLE_DEV" "$MODEL_DEV")"
  printf "%s│%s  • ขั้นตอนที่ 4 (@qa/@sec)  : %b (%s) ➔ %b\n" "$C_RED" "$C_RESET" "$(format_provider_colored "$ROLE_QA")" "$MODEL_QA" "$(format_role_status_cell "$ROLE_QA" "$MODEL_QA")"
  printf "%s╰──────────────────────────────────────────────────────────────────────────────╯%s\n" "$C_RED" "$C_RESET"

  interactive_menu "⚙️  กรุณาตั้งค่าค่าย AI และเลือก Model ให้ครบทั้ง 4 ตำแหน่งก่อนเริ่มงาน" 0 \
    "c|${C_GOLD}ไปที่หน้าตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่งเดี๋ยวนี้ ([c])${C_RESET}|ไปที่หน้าตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่งเดี๋ยวนี้ ([c])" \
    "d|${C_CYAN}ไปที่หน้าติดตั้ง CLI & เชื่อมต่อบัญชี Login ([d])${C_RESET}|ไปที่หน้าติดตั้ง CLI & เชื่อมต่อบัญชี Login ([d])" \
    "b|${C_LIGHT_GRAY}กลับสู่หน้าจอหลัก${C_RESET}|กลับสู่หน้าจอหลัก"

  case "$MENU_RESULT" in
    c|C) configure_roles_menu ;;
    d|D) run_doctor_menu ;;
  esac
  return 1
}

# ─── 6. เมนูเลือกค่าย AI และเลือก Model แบบ Interactive (ลูกศร ↑/↓) ──────────
choose_provider_interactive() {
  local role_label="$1"
  local current_p="$2"
  local c_stat g_stat x_stat
  c_stat="$(is_provider_installed claude && echo "${C_GREEN}✅ ติดตั้งแล้ว${C_RESET}" || echo "${C_RED}❌ ยังไม่ติดตั้ง CLI${C_RESET}")"
  g_stat="$(is_provider_installed gemini && echo "${C_GREEN}✅ ติดตั้งแล้ว${C_RESET}" || echo "${C_RED}❌ ยังไม่ติดตั้ง CLI${C_RESET}")"
  x_stat="$(is_provider_installed codex  && echo "${C_GREEN}✅ ติดตั้งแล้ว${C_RESET}" || echo "${C_RED}❌ ยังไม่ติดตั้ง CLI${C_RESET}")"

  interactive_menu "🤖 เลือกค่าย AI สำหรับ ${role_label} (ปัจจุบัน: ${current_p})" 0 \
    "1|${C_CORAL}claude${C_RESET}  — Anthropic Claude Code CLI  [${c_stat}]|claude  — Anthropic Claude Code CLI" \
    "2|${C_BLUE}gemini${C_RESET}  — Google Gemini CLI          [${g_stat}]|gemini  — Google Gemini CLI" \
    "3|${C_GREEN}codex${C_RESET}   — OpenAI Codex CLI           [${x_stat}]|codex   — OpenAI Codex CLI" \
    "b|${C_LIGHT_GRAY}คงค่าเดิม (${current_p})${C_RESET}|คงค่าเดิม (${current_p})"

  local chosen_p="$current_p"
  case "$MENU_RESULT" in
    1) chosen_p="claude" ;;
    2) chosen_p="gemini" ;;
    3) chosen_p="codex" ;;
    *) chosen_p="$current_p" ;;
  esac

  if ! is_provider_installed "$chosen_p"; then
    local pkg="@google/gemini-cli"
    [ "$chosen_p" = "claude" ] && pkg="@anthropic-ai/claude-code"
    [ "$chosen_p" = "codex" ]  && pkg="@openai/codex"

    interactive_menu "⚡ ค่าย '${chosen_p}' ยังไม่ได้ติดตั้งในเครื่อง คุณต้องการติดตั้งและเชื่อมต่อเลยหรือไม่?" 0 \
      "1|${C_GREEN}ติดตั้ง ${chosen_p} อัตโนมัติเดี๋ยวนี้ (npm install -g ${pkg}) และเปิดหน้า Login${C_RESET}|ติดตั้ง ${chosen_p} อัตโนมัติเดี๋ยวนี้ (npm install -g ${pkg}) และเปิดหน้า Login" \
      "2|${C_GOLD}บันทึกให้ใช้ค่าย ${chosen_p} ไว้ก่อน (แต่จะยังเริ่มถามงานไม่ได้จนกว่าจะติดตั้ง CLI)${C_RESET}|บันทึกให้ใช้ค่าย ${chosen_p} ไว้ก่อน"
    if [ "$MENU_RESULT" = "1" ]; then
      npm install -g "$pkg"
      if is_provider_installed "$chosen_p"; then
        printf "%s✅ ติดตั้ง %s สำเร็จ! กำลังเปิดหน้า Login (พิมพ์ /exit เมื่อ Login เสร็จ)...%s\n" "$C_GREEN" "$chosen_p" "$C_RESET"
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
      interactive_menu "🧠 เลือก Model ของค่าย [claude] สำหรับ ${role_label}" 0 \
        "1|${C_CORAL}sonnet${C_RESET}            — Claude Sonnet 4.5 (รวดเร็ว สมดุล เหมาะกับงานเขียนโค้ดและวิเคราะห์)|sonnet            — Claude Sonnet 4.5 (รวดเร็ว สมดุล)" \
        "2|${C_GOLD}opus${C_RESET}              — Claude Opus 4.5 (วิเคราะห์เชิงลึก เหมาะกับงานสถาปัตยกรรม/ตรวจโค้ด)|opus              — Claude Opus 4.5 (วิเคราะห์เชิงลึก)" \
        "3|${C_CYAN}haiku${C_RESET}             — Claude Haiku 4.5 (รวดเร็วและประหยัดโควตาสูงสุด)|haiku             — Claude Haiku 4.5 (ประหยัดโควตาสูงสุด)" \
        "4|${C_WHITE}claude-sonnet-4-5${C_RESET} — ระบุรหัสเต็ม claude-sonnet-4-5|claude-sonnet-4-5 — ระบุรหัสเต็ม claude-sonnet-4-5" \
        "5|${C_WHITE}claude-opus-4-5${C_RESET}   — ระบุรหัสเต็ม claude-opus-4-5|claude-opus-4-5   — ระบุรหัสเต็ม claude-opus-4-5" \
        "6|${C_PINK}กำหนดชื่อโมเดลเอง${C_RESET}   — พิมพ์รหัส Model ID ที่ต้องการด้วยตนเอง|กำหนดชื่อโมเดลเอง   — พิมพ์รหัส Model ID ที่ต้องการด้วยตนเอง"
      case "$MENU_RESULT" in
        1) SELECTED_MODEL="sonnet" ;;
        2) SELECTED_MODEL="opus" ;;
        3) SELECTED_MODEL="haiku" ;;
        4) SELECTED_MODEL="claude-sonnet-4-5" ;;
        5) SELECTED_MODEL="claude-opus-4-5" ;;
        6) read -r -p "ระบุชื่อ Model ของ Claude: " cm; SELECTED_MODEL="${cm:-$cli_def}" ;;
        *) SELECTED_MODEL="${cli_def:-sonnet}" ;;
      esac
      ;;
    gemini)
      interactive_menu "🧠 เลือก Model ของค่าย [gemini] สำหรับ ${role_label}" 0 \
        "1|${C_BLUE}gemini-2.5-pro${C_RESET}   — Gemini 2.5 Pro (วิเคราะห์ความต้องการและวางแผนเชิงลึก แนะนำ)|gemini-2.5-pro   — Gemini 2.5 Pro (แนะนำ)" \
        "2|${C_CYAN}gemini-2.5-flash${C_RESET} — Gemini 2.5 Flash (รวดเร็วสูง ประหยัดโควตา)|gemini-2.5-flash — Gemini 2.5 Flash (รวดเร็วสูง)" \
        "3|${C_PINK}กำหนดชื่อโมเดลเอง${C_RESET} — พิมพ์รหัส Model ID ที่ต้องการด้วยตนเอง|กำหนดชื่อโมเดลเอง — พิมพ์รหัส Model ID ที่ต้องการด้วยตนเอง"
      case "$MENU_RESULT" in
        1) SELECTED_MODEL="gemini-2.5-pro" ;;
        2) SELECTED_MODEL="gemini-2.5-flash" ;;
        3) read -r -p "ระบุชื่อ Model ของ Gemini: " gm; SELECTED_MODEL="${gm:-gemini-2.5-pro}" ;;
        *) SELECTED_MODEL="gemini-2.5-pro" ;;
      esac
      ;;
    codex)
      interactive_menu "🧠 เลือก Model ของค่าย [codex] สำหรับ ${role_label}" 0 \
        "1|${C_GREEN}o3${C_RESET}               — OpenAI o3 (ตรวจสอบโค้ดและหาช่องโหว่แม่นยำสูง แนะนำ)|o3               — OpenAI o3 (แนะนำ)" \
        "2|${C_CYAN}o4-mini${C_RESET}          — OpenAI o4-mini (รวดเร็ว ประหยัดโควตา)|o4-mini          — OpenAI o4-mini (รวดเร็ว ประหยัดโควตา)" \
        "3|${C_GOLD}gpt-5${C_RESET}            — OpenAI GPT-5 (โมเดลเรือธงรุ่นล่าสุด)|gpt-5            — OpenAI GPT-5 (โมเดลเรือธงรุ่นล่าสุด)" \
        "4|${C_PINK}กำหนดชื่อโมเดลเอง${C_RESET} — พิมพ์รหัส Model ID ที่ต้องการด้วยตนเอง|กำหนดชื่อโมเดลเอง — พิมพ์รหัส Model ID ที่ต้องการด้วยตนเอง"
      case "$MENU_RESULT" in
        1) SELECTED_MODEL="o3" ;;
        2) SELECTED_MODEL="o4-mini" ;;
        3) SELECTED_MODEL="gpt-5" ;;
        4) read -r -p "ระบุชื่อ Model ของ Codex: " xm; SELECTED_MODEL="${xm:-o3}" ;;
        *) SELECTED_MODEL="o3" ;;
      esac
      ;;
  esac
}

# ─── 7. ศูนย์ตั้งค่าจับคู่ค่าย AI, เลือก Model และการเชื่อมต่อ CLI ในหน้าเดียว ([c] / /model) ───
configure_roles_menu() {
  load_role_config
  local target_conf="$GLOBAL_ROLES_CONF"
  local scope_label="ส่วนกลาง (~/.agents/relay-roles.conf)"
  if [ -f "$PROJECT_ROLES_CONF" ]; then
    target_conf="$PROJECT_ROLES_CONF"
    scope_label="เฉพาะโครงการนี้ (.relay/roles.conf)"
  fi

  while true; do
    check_all_roles_ready
    local st_po st_arch st_dev st_qa
    st_po="$(format_role_status_cell "$ROLE_PO" "$MODEL_PO")"
    st_arch="$(format_role_status_cell "$ROLE_ARCH" "$MODEL_ARCH")"
    st_dev="$(format_role_status_cell "$ROLE_DEV" "$MODEL_DEV")"
    st_qa="$(format_role_status_cell "$ROLE_QA" "$MODEL_QA")"

    interactive_menu "⚙️  ตั้งค่าค่าย AI & เลือก Model ให้ครบทั้ง 4 ตำแหน่ง [พร้อมแล้ว ${READY_ROLE_COUNT}/4 • บันทึกที่: ${scope_label}]" 0 \
      "p|${C_GOLD}⚡ ตั้งค่าด่วนรวดเดียวครบ 4 ตำแหน่ง (Quick Presets: All-Claude / All-Gemini / All-Codex)${C_RESET}|⚡ ตั้งค่าด่วนรวดเดียวครบ 4 ตำแหน่ง (Quick Presets: All-Claude / All-Gemini / All-Codex)" \
      "1|${C_PINK}ขั้นตอนที่ 1 (@po)${C_RESET}       ➔ ค่าย: ${C_WHITE}${ROLE_PO}${C_RESET} | โมเดล: ${C_CYAN}${MODEL_PO}${C_RESET} | ${st_po}|ขั้นตอนที่ 1 (@po)       ➔ ค่าย: ${ROLE_PO} | โมเดล: ${MODEL_PO}" \
      "2|${C_GOLD}ขั้นตอนที่ 2 (@arch/@pm)${C_RESET} ➔ ค่าย: ${C_WHITE}${ROLE_ARCH}${C_RESET} | โมเดล: ${C_CYAN}${MODEL_ARCH}${C_RESET} | ${st_arch}|ขั้นตอนที่ 2 (@arch/@pm) ➔ ค่าย: ${ROLE_ARCH} | โมเดล: ${MODEL_ARCH}" \
      "3|${C_CYAN}ขั้นตอนที่ 3 (@dev)${C_RESET}      ➔ ค่าย: ${C_WHITE}${ROLE_DEV}${C_RESET} | โมเดล: ${C_CYAN}${MODEL_DEV}${C_RESET} | ${st_dev}|ขั้นตอนที่ 3 (@dev)      ➔ ค่าย: ${ROLE_DEV} | โมเดล: ${MODEL_DEV}" \
      "4|${C_MINT}ขั้นตอนที่ 4 (@qa/@sec)${C_RESET}  ➔ ค่าย: ${C_WHITE}${ROLE_QA}${C_RESET} | โมเดล: ${C_CYAN}${MODEL_QA}${C_RESET} | ${st_qa}|ขั้นตอนที่ 4 (@qa/@sec)  ➔ ค่าย: ${ROLE_QA} | โมเดล: ${MODEL_QA}" \
      "m|${C_VIOLET}🧠 ตั้งค่า Default Model ของแต่ละค่ายโดยตรง (Claude / Gemini / Codex Settings)${C_RESET}|🧠 ตั้งค่า Default Model ของแต่ละค่ายโดยตรง (Claude / Gemini / Codex Settings)" \
      "d|${C_BLUE}🔌 จัดการการเชื่อมต่อ CLI (ติดตั้ง CLI / เปิดหน้า Login ของแต่ละค่าย)${C_RESET}|🔌 จัดการการเชื่อมต่อ CLI (ติดตั้ง CLI / เปิดหน้า Login ของแต่ละค่าย)" \
      "s|${C_LIGHT_GRAY}📂 สลับระดับไฟล์ที่บันทึก (Global ~/.agents/ ↔ Project .relay/roles.conf)${C_RESET}|📂 สลับระดับไฟล์ที่บันทึก (Global ~/.agents/ ↔ Project .relay/roles.conf)" \
      "t|${C_GREEN}🧪 บันทึกและทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่งทันที (Readiness Test)${C_RESET}|🧪 บันทึกและทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่งทันที (Readiness Test)" \
      "b|${C_WHITE}💾 บันทึกการตั้งค่าและกลับสู่หน้าจอหลัก${C_RESET}|💾 บันทึกการตั้งค่าและกลับสู่หน้าจอหลัก"

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
        interactive_menu "⚡ เลือกชุดการตั้งค่าด่วน (ตั้งค่าทั้งค่ายและระบุ Model ให้ครบทั้ง 4 ตำแหน่งทันที)" 0 \
          "1|${C_CORAL}All-Claude Preset${C_RESET}  — ใช้ Claude Code ทั้ง 4 ตำแหน่ง (@po=sonnet, @arch=opus, @dev=sonnet, @qa=opus)|All-Claude Preset  — ใช้ Claude Code ทั้ง 4 ตำแหน่ง (@po=sonnet, @arch=opus, @dev=sonnet, @qa=opus)" \
          "2|${C_BLUE}All-Gemini Preset${C_RESET}  — ใช้ Gemini CLI ทั้ง 4 ตำแหน่ง (gemini-2.5-pro ทั้ง 4 ตำแหน่ง)|All-Gemini Preset  — ใช้ Gemini CLI ทั้ง 4 ตำแหน่ง (gemini-2.5-pro ทั้ง 4 ตำแหน่ง)" \
          "3|${C_GREEN}All-Codex Preset${C_RESET}   — ใช้ OpenAI Codex ทั้ง 4 ตำแหน่ง (o3 ทั้ง 4 ตำแหน่ง)|All-Codex Preset   — ใช้ OpenAI Codex ทั้ง 4 ตำแหน่ง (o3 ทั้ง 4 ตำแหน่ง)" \
          "4|${C_GOLD}Multi-Vendor แนะนำ${C_RESET} — @po=gemini(2.5-pro), @arch=claude(opus), @dev=claude(sonnet), @qa=codex(o3)|Multi-Vendor แนะนำ — @po=gemini(2.5-pro), @arch=claude(opus), @dev=claude(sonnet), @qa=codex(o3)" \
          "b|${C_LIGHT_GRAY}ย้อนกลับ${C_RESET}|ย้อนกลับ"
        case "$MENU_RESULT" in
          1)
            ROLE_PO="claude";   MODEL_PO="sonnet"
            ROLE_ARCH="claude"; MODEL_ARCH="opus"
            ROLE_DEV="claude";  MODEL_DEV="sonnet"
            ROLE_QA="claude";   MODEL_QA="opus"
            save_role_config "$target_conf"
            printf "%s✅ ตั้งค่า All-Claude Preset ครบทั้ง 4 ตำแหน่งเรียบร้อยแล้ว!%s\n" "$C_GREEN" "$C_RESET"
            ;;
          2)
            ROLE_PO="gemini";   MODEL_PO="gemini-2.5-pro"
            ROLE_ARCH="gemini"; MODEL_ARCH="gemini-2.5-pro"
            ROLE_DEV="gemini";  MODEL_DEV="gemini-2.5-pro"
            ROLE_QA="gemini";   MODEL_QA="gemini-2.5-pro"
            save_role_config "$target_conf"
            ;;
          3)
            ROLE_PO="codex";   MODEL_PO="o3"
            ROLE_ARCH="codex"; MODEL_ARCH="o3"
            ROLE_DEV="codex";  MODEL_DEV="o3"
            ROLE_QA="codex";   MODEL_QA="o3"
            save_role_config "$target_conf"
            ;;
          4)
            ROLE_PO="gemini";   MODEL_PO="gemini-2.5-pro"
            ROLE_ARCH="claude"; MODEL_ARCH="opus"
            ROLE_DEV="claude";  MODEL_DEV="sonnet"
            ROLE_QA="codex";    MODEL_QA="o3"
            save_role_config "$target_conf"
            ;;
        esac
        ;;
      m|M) configure_provider_defaults_menu ;;
      d|D) run_doctor_menu ;;
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
        run_agent_readiness_test
        return 0
        ;;
      b|B|q|Q|*)
        save_role_config "$target_conf"
        printf "%s✅ บันทึกการตั้งค่าลงใน %s เรียบร้อยแล้ว!%s\n" "$C_GREEN" "$target_conf" "$C_RESET"
        return 0
        ;;
    esac
  done
}

# ─── 8. ตั้งค่า Default Model ของแต่ละค่ายโดยตรง (Claude / Gemini / Codex) ────
configure_provider_defaults_menu() {
  while true; do
    local cm gm xm
    cm="$(get_cli_default_model claude)"
    gm="$(get_cli_default_model gemini)"
    xm="$(get_cli_default_model codex)"

    interactive_menu "🧠 ตั้งค่า Default Model เริ่มต้นของแต่ละค่าย (บันทึกลงไฟล์ตั้งค่าของ CLI โดยตรง)" 0 \
      "1|${C_CORAL}Claude Code CLI${C_RESET} (~/.claude/settings.json) — ค่าเริ่มต้นปัจจุบัน: ${C_WHITE}${cm}${C_RESET}|Claude Code CLI (~/.claude/settings.json) — ค่าเริ่มต้นปัจจุบัน: ${cm}" \
      "2|${C_BLUE}Google Gemini CLI${C_RESET} (~/.gemini/settings.json) — ค่าเริ่มต้นปัจจุบัน: ${C_WHITE}${gm}${C_RESET}|Google Gemini CLI (~/.gemini/settings.json) — ค่าเริ่มต้นปัจจุบัน: ${gm}" \
      "3|${C_GREEN}OpenAI Codex CLI${C_RESET} (~/.codex/config.toml)   — ค่าเริ่มต้นปัจจุบัน: ${C_WHITE}${xm}${C_RESET}|OpenAI Codex CLI (~/.codex/config.toml)   — ค่าเริ่มต้นปัจจุบัน: ${xm}" \
      "b|${C_LIGHT_GRAY}ย้อนกลับ${C_RESET}|ย้อนกลับ"

    case "$MENU_RESULT" in
      1)
        choose_model_interactive "claude" "ค่าเริ่มต้นของ Claude Code CLI" "$cm"
        set_cli_default_model "claude" "$SELECTED_MODEL"
        printf "%s✅ ตั้งค่า Default Model ของ Claude Code เป็น '%s' เรียบร้อยแล้ว!%s\n" "$C_GREEN" "$SELECTED_MODEL" "$C_RESET"
        ;;
      2)
        choose_model_interactive "gemini" "ค่าเริ่มต้นของ Gemini CLI" "$gm"
        set_cli_default_model "gemini" "$SELECTED_MODEL"
        printf "%s✅ ตั้งค่า Default Model ของ Gemini CLI เป็น '%s' เรียบร้อยแล้ว!%s\n" "$C_GREEN" "$SELECTED_MODEL" "$C_RESET"
        ;;
      3)
        choose_model_interactive "codex" "ค่าเริ่มต้นของ OpenAI Codex CLI" "$xm"
        set_cli_default_model "codex" "$SELECTED_MODEL"
        printf "%s✅ ตั้งค่า Default Model ของ Codex CLI เป็น '%s' เรียบร้อยแล้ว!%s\n" "$C_GREEN" "$SELECTED_MODEL" "$C_RESET"
        ;;
      *) break ;;
    esac
  done
}

# ─── 9. ศูนย์จัดการการเชื่อมต่อ CLI, ติดตั้ง และ Login (RELAY Doctor / /connect) ─
run_doctor_menu() {
  while true; do
    echo ""
    printf "%s╭──────────────────── 🔌 RELAY CLI Connection & Login Hub ─────────────────────╮%s\n" "$C_GOLD" "$C_RESET"
    for p in claude gemini codex; do
      local pkg="@google/gemini-cli"
      [ "$p" = "claude" ] && pkg="@anthropic-ai/claude-code"
      [ "$p" = "codex" ]  && pkg="@openai/codex"
      local def_m p_col
      def_m="$(get_cli_default_model "$p")"
      p_col="$(format_provider_colored "$p")"

      if is_provider_installed "$p"; then
        local bin_p ver_s
        bin_p="$(command -v "$p")"
        ver_s="$(get_provider_version "$p")"
        printf "%s│%s  %s●%s %b : %sติดตั้งแล้ว%s (%s%s%s) • Default Model: %s%s%s\n" "$C_GOLD" "$C_RESET" "$C_GREEN" "$C_RESET" "$p_col" "$C_GREEN" "$C_RESET" "$C_CYAN" "$ver_s" "$C_RESET" "$C_WHITE" "$def_m" "$C_RESET"
        printf "%s│%s             %sPath: %s%s\n" "$C_GOLD" "$C_RESET" "$C_GRAY" "$bin_p" "$C_RESET"
      else
        printf "%s│%s  %s○%s %b : %sยังไม่ได้ติดตั้งในเครื่อง%s %s(แพ็กเกจ: %s)%s\n" "$C_GOLD" "$C_RESET" "$C_RED" "$C_RESET" "$p_col" "$C_RED" "$C_RESET" "$C_LIGHT_GRAY" "$pkg" "$C_RESET"
      fi
    done
    printf "%s╰──────────────────────────────────────────────────────────────────────────────╯%s\n" "$C_GOLD" "$C_RESET"

    interactive_menu "🔌 เลือกการจัดการเชื่อมต่อ CLI และบัญชีผู้ใช้งาน" 0 \
      "1|${C_BLUE}ติดตั้ง / อัปเดต Google Gemini CLI${C_RESET}  (npm install -g @google/gemini-cli)|ติดตั้ง / อัปเดต Google Gemini CLI  (npm install -g @google/gemini-cli)" \
      "2|${C_GREEN}ติดตั้ง / อัปเดต OpenAI Codex CLI${C_RESET}   (npm install -g @openai/codex)|ติดตั้ง / อัปเดต OpenAI Codex CLI   (npm install -g @openai/codex)" \
      "3|${C_CORAL}ติดตั้ง / อัปเดต Claude Code CLI${C_RESET}    (npm install -g @anthropic-ai/claude-code)|ติดตั้ง / อัปเดต Claude Code CLI    (npm install -g @anthropic-ai/claude-code)" \
      "4|${C_GOLD}ติดตั้งรวดเดียวครบทั้ง 3 ค่าย${C_RESET} (claude + gemini + codex)|ติดตั้งรวดเดียวครบทั้ง 3 ค่าย (claude + gemini + codex)" \
      "5|${C_CORAL}🔑 เปิด Claude Code เพื่อเข้าสู่ระบบ (Login / เช็กสถานะบัญชี)${C_RESET}|🔑 เปิด Claude Code เพื่อเข้าสู่ระบบ (Login / เช็กสถานะบัญชี)" \
      "6|${C_BLUE}🔑 เปิด Gemini CLI เพื่อเข้าสู่ระบบ (Login ด้วยบัญชี Google)${C_RESET}|🔑 เปิด Gemini CLI เพื่อเข้าสู่ระบบ (Login ด้วยบัญชี Google)" \
      "7|${C_GREEN}🔑 เปิด OpenAI Codex เพื่อเข้าสู่ระบบ (Login ด้วยบัญชี ChatGPT/OpenAI)${C_RESET}|🔑 เปิด OpenAI Codex เพื่อเข้าสู่ระบบ (Login ด้วยบัญชี ChatGPT/OpenAI)" \
      "m|${C_VIOLET}🧠 ตั้งค่า Default Model เริ่มต้นของแต่ละค่าย (Claude / Gemini / Codex)${C_RESET}|🧠 ตั้งค่า Default Model เริ่มต้นของแต่ละค่าย (Claude / Gemini / Codex)" \
      "b|${C_LIGHT_GRAY}กลับสู่หน้าจอหลัก${C_RESET}|กลับสู่หน้าจอหลัก"

    case "$MENU_RESULT" in
      1) npm install -g @google/gemini-cli ;;
      2) npm install -g @openai/codex ;;
      3) npm install -g @anthropic-ai/claude-code ;;
      4) npm install -g @anthropic-ai/claude-code @google/gemini-cli @openai/codex ;;
      5)
        if is_provider_installed claude; then
          printf "%s💡 กำลังเปิด claude เพื่อให้คุณ Login/เช็กสถานะ (พิมพ์ /exit เพื่อกลับมาหน้านี้)...%s\n" "$C_CYAN" "$C_RESET"
          claude || true
        else
          printf "%s❌ ยังไม่ได้ติดตั้ง claude (กรุณาเลือก [3] เพื่อติดตั้งก่อน)%s\n" "$C_RED" "$C_RESET"
        fi
        ;;
      6)
        if is_provider_installed gemini; then
          printf "%s💡 กำลังเปิด gemini เพื่อให้คุณ Login ด้วย Google (พิมพ์ /exit เพื่อกลับมาหน้านี้)...%s\n" "$C_CYAN" "$C_RESET"
          gemini || true
        else
          printf "%s❌ ยังไม่ได้ติดตั้ง gemini (กรุณาเลือก [1] เพื่อติดตั้งก่อน)%s\n" "$C_RED" "$C_RESET"
        fi
        ;;
      7)
        if is_provider_installed codex; then
          printf "%s💡 กำลังเปิด codex เพื่อให้คุณ Login ด้วย OpenAI (พิมพ์ /exit เพื่อกลับมาหน้านี้)...%s\n" "$C_CYAN" "$C_RESET"
          codex || true
        else
          printf "%s❌ ยังไม่ได้ติดตั้ง codex (กรุณาเลือก [2] เพื่อติดตั้งก่อน)%s\n" "$C_RED" "$C_RESET"
        fi
        ;;
      m|M) configure_provider_defaults_menu ;;
      *) break ;;
    esac
  done
}

# ─── 10. ทดสอบความพร้อมของ Agent แต่ละตำแหน่ง ([t] / /test) ─────────────────
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
  printf "%b" "$output"
}

get_provider_rules_status() {
  local provider="$1"
  case "$provider" in
    claude) [ -e "$HOME/.claude/CLAUDE.md" ] && printf "%s✅ เชื่อมต่อ ~/.claude/CLAUDE.md แล้ว%s" "$C_GREEN" "$C_RESET" || printf "%s❌ ยังไม่พบ ~/.claude/CLAUDE.md%s" "$C_RED" "$C_RESET" ;;
    codex)  [ -e "$HOME/.codex/AGENTS.md" ]  && printf "%s✅ เชื่อมต่อ ~/.codex/AGENTS.md แล้ว%s" "$C_GREEN" "$C_RESET"  || printf "%s❌ ยังไม่พบ ~/.codex/AGENTS.md%s" "$C_RED" "$C_RESET" ;;
    gemini) [ -e "$HOME/.gemini/GEMINI.md" ] && printf "%s✅ เชื่อมต่อ ~/.gemini/GEMINI.md แล้ว%s" "$C_GREEN" "$C_RESET" || printf "%s❌ ยังไม่พบ ~/.gemini/GEMINI.md%s" "$C_RED" "$C_RESET" ;;
    *) printf "⚠️ ไม่ทราบค่าย" ;;
  esac
}

ping_single_role_agent() {
  local role_code="$1"
  local role_title="$2"
  local provider="$3"
  local configured_model="$4"
  local expected_skills="$5"
  local expected_duty="$6"

  echo ""
  printf "%s╭──────────────────────────────────────────────────────────────────────────────╮%s\n" "$C_GOLD" "$C_RESET"
  printf "%s│%s 🧪 กำลังทดสอบรายงานตัวของ: %s%s%s\n" "$C_GOLD" "$C_RESET" "$C_WHITE" "$role_title" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %b (%s%s%s)\n" "$C_GOLD" "$C_RESET" "$(format_provider_colored "$provider")" "$C_CYAN" "$configured_model" "$C_RESET"
  printf "%s│%s    • ทักษะประจำตัว: %s%s%s\n" "$C_GOLD" "$C_RESET" "$C_LIGHT_GRAY" "$expected_skills" "$C_RESET"
  printf "%s╰──────────────────────────────────────────────────────────────────────────────╯%s\n" "$C_GOLD" "$C_RESET"

  if ! is_role_ready "$provider" "$configured_model"; then
    printf "%s❌ ไม่สามารถยิงทดสอบ %s ได้ เนื่องจากยังตั้งค่าค่ายหรือโมเดลไม่สมบูรณ์ (%b)%s\n" "$C_RED" "$role_code" "$(format_role_status_cell "$provider" "$configured_model")" "$C_RESET"
    return 1
  fi

  local self_check_prompt="นี่คือการทดสอบความพร้อมของระบบ RELAY v1.0 กรุณารายงานตัวสั้นๆ ไม่เกิน 4 บรรทัด (ห้ามรันคำสั่งแก้ไขไฟล์ใดๆ) โดยระบุข้อมูลดังนี้:
1. ยืนยันบทบาทของคุณคือ '$role_title' (ทำงานผ่านค่าย $provider โมเดล $configured_model)
2. สรุปหน้าที่หลักของคุณในระบบ RELAY ($expected_duty)
3. ยืนยันชุดทักษะ (Skills) ประจำตำแหน่งของคุณ ได้แก่: $expected_skills
4. ปิดท้ายด้วยข้อความ 'สถานะ: พร้อมปฏิบัติงาน 100%'"

  printf "%s⏳ กำลังส่งคำสั่งทดสอบไปยัง %s (%s)...%s\n" "$C_CYAN" "$provider" "$configured_model" "$C_RESET"
  local exit_code=0
  case "$provider" in
    claude) claude --model "$configured_model" -p "$self_check_prompt" || exit_code=$? ;;
    gemini) gemini -m "$configured_model" -p "$self_check_prompt" || exit_code=$? ;;
    codex)  codex -m "$configured_model" exec "$self_check_prompt" 2>/dev/null || codex -m "$configured_model" -q "$self_check_prompt" || exit_code=$? ;;
  esac

  if [ "$exit_code" -eq 0 ]; then
    printf "%s✅ [ผ่านการทดสอบ] %s เชื่อมต่อกับ %s (%s) และพร้อมใช้งาน 100%%!%s\n" "$C_GREEN" "$role_title" "$provider" "$configured_model" "$C_RESET"
  else
    printf "%s❌ [ไม่ผ่านการทดสอบ] %s ไม่สามารถรับคำสั่งผ่าน %s (%s) ได้ (กรุณาเช็กการ Login ในเมนู [d])%s\n" "$C_RED" "$role_title" "$provider" "$configured_model" "$C_RESET"
  fi
}

run_agent_readiness_test() {
  check_all_roles_ready
  local po_skills="brainstorming founder-skill"
  local arch_skills="writing-plans supabase-postgres-best-practices"
  local dev_skills="impeccable vercel-react-best-practices lucide-icons simple-icons test-driven-development systematic-debugging"
  local qa_skills="verification-before-completion differential-review semgrep playwright-qa"

  echo ""
  printf "%s╭──────────── 🧪 RELAY Agent Readiness & Skill Verification ──────────────────╮%s\n" "$C_GOLD" "$C_RESET"
  printf "%s│%s %s1️⃣  ขั้นตอนที่ 1: @po (Product Owner — วิเคราะห์ความต้องการและสร้าง SPEC.md)%s\n" "$C_GOLD" "$C_RESET" "$C_PINK" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %b │ โมเดล: %b │ %b\n" "$C_GOLD" "$C_RESET" "$(format_provider_colored "$ROLE_PO")" "$(format_role_model_cell "$ROLE_PO" "$MODEL_PO")" "$(format_role_status_cell "$ROLE_PO" "$MODEL_PO")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_GOLD" "$C_RESET" "$(get_provider_rules_status "$ROLE_PO")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_GOLD" "$C_RESET" "$(check_role_skills_status "$po_skills")"
  printf "%s│%s\n" "$C_GOLD" "$C_RESET"
  printf "%s│%s %s2️⃣  ขั้นตอนที่ 2: @arch & @pm (System Architect & Planner — สร้าง ARCH.md & PLAN.md)%s\n" "$C_GOLD" "$C_RESET" "$C_GOLD" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %b │ โมเดล: %b │ %b\n" "$C_GOLD" "$C_RESET" "$(format_provider_colored "$ROLE_ARCH")" "$(format_role_model_cell "$ROLE_ARCH" "$MODEL_ARCH")" "$(format_role_status_cell "$ROLE_ARCH" "$MODEL_ARCH")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_GOLD" "$C_RESET" "$(get_provider_rules_status "$ROLE_ARCH")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_GOLD" "$C_RESET" "$(check_role_skills_status "$arch_skills")"
  printf "%s│%s\n" "$C_GOLD" "$C_RESET"
  printf "%s│%s %s3️⃣  ขั้นตอนที่ 3: @dev (Full-Stack Developer — พัฒนาโค้ดและ Unit Tests ใน Git Worktree)%s\n" "$C_GOLD" "$C_RESET" "$C_CYAN" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %b │ โมเดล: %b │ %b\n" "$C_GOLD" "$C_RESET" "$(format_provider_colored "$ROLE_DEV")" "$(format_role_model_cell "$ROLE_DEV" "$MODEL_DEV")" "$(format_role_status_cell "$ROLE_DEV" "$MODEL_DEV")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_GOLD" "$C_RESET" "$(get_provider_rules_status "$ROLE_DEV")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_GOLD" "$C_RESET" "$(check_role_skills_status "$dev_skills")"
  printf "%s│%s\n" "$C_GOLD" "$C_RESET"
  printf "%s│%s %s4️⃣  ขั้นตอนที่ 4: @qa & @sec (QA Verifier & Security Auditor — สร้าง QA_REPORT.md)%s\n" "$C_GOLD" "$C_RESET" "$C_MINT" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %b │ โมเดล: %b │ %b\n" "$C_GOLD" "$C_RESET" "$(format_provider_colored "$ROLE_QA")" "$(format_role_model_cell "$ROLE_QA" "$MODEL_QA")" "$(format_role_status_cell "$ROLE_QA" "$MODEL_QA")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_GOLD" "$C_RESET" "$(get_provider_rules_status "$ROLE_QA")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_GOLD" "$C_RESET" "$(check_role_skills_status "$qa_skills")"
  printf "%s╰──────────────────────────────────────────────────────────────────────────────╯%s\n" "$C_GOLD" "$C_RESET"

  if [ "$ALL_ROLES_READY" -eq 0 ]; then
    printf "\n%s🔒 ยังไม่สามารถยิงทดสอบ Live Handshake ได้ เนื่องจากยังตั้งค่าค่ายและโมเดลไม่ครบทั้ง 4 ตำแหน่ง (%d/4)%s\n" "$C_RED" "$READY_ROLE_COUNT" "$C_RESET"
    interactive_menu "ต้องการไปตั้งค่าให้ครบทั้ง 4 ตำแหน่งก่อนหรือไม่?" 0 \
      "c|${C_GOLD}ไปที่หน้าตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่ง ([c])${C_RESET}|ไปที่หน้าตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่ง ([c])" \
      "b|${C_LIGHT_GRAY}กลับสู่หน้าจอหลัก${C_RESET}|กลับสู่หน้าจอหลัก"
    [ "$MENU_RESULT" = "c" ] && configure_roles_menu
    return 0
  fi

  interactive_menu "🧪 เลือกตำแหน่งที่ต้องการยิงคำสั่งทดสอบให้ AI รายงานบทบาทและ Skills จริง (Live Handshake)" 0 \
    "1|${C_GREEN}ทดสอบรวดเดียวครบทั้ง 4 ตำแหน่ง (@po, @arch/@pm, @dev, @qa/@sec)${C_RESET}|ทดสอบรวดเดียวครบทั้ง 4 ตำแหน่ง (@po, @arch/@pm, @dev, @qa/@sec)" \
    "2|${C_PINK}ทดสอบเฉพาะ ขั้นตอนที่ 1 (@po        ➔ ${ROLE_PO} / ${MODEL_PO})${C_RESET}|ทดสอบเฉพาะ ขั้นตอนที่ 1 (@po        ➔ ${ROLE_PO} / ${MODEL_PO})" \
    "3|${C_GOLD}ทดสอบเฉพาะ ขั้นตอนที่ 2 (@arch/@pm  ➔ ${ROLE_ARCH} / ${MODEL_ARCH})${C_RESET}|ทดสอบเฉพาะ ขั้นตอนที่ 2 (@arch/@pm  ➔ ${ROLE_ARCH} / ${MODEL_ARCH})" \
    "4|${C_CYAN}ทดสอบเฉพาะ ขั้นตอนที่ 3 (@dev       ➔ ${ROLE_DEV} / ${MODEL_DEV})${C_RESET}|ทดสอบเฉพาะ ขั้นตอนที่ 3 (@dev       ➔ ${ROLE_DEV} / ${MODEL_DEV})" \
    "5|${C_MINT}ทดสอบเฉพาะ ขั้นตอนที่ 4 (@qa/@sec   ➔ ${ROLE_QA} / ${MODEL_QA})${C_RESET}|ทดสอบเฉพาะ ขั้นตอนที่ 4 (@qa/@sec   ➔ ${ROLE_QA} / ${MODEL_QA})" \
    "b|${C_LIGHT_GRAY}กลับสู่หน้าจอหลัก${C_RESET}|กลับสู่หน้าจอหลัก"

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

# ─── 11. เรียกใช้งาน CLI ของแต่ละขั้นตอน (บังคับผ่าน 4-Role Readiness Gate ก่อนเสมอ) ───
launch_provider_cli() {
  local provider="$1"
  local configured_model="$2"
  local role_name="$3"
  local work_dir="$4"
  local initial_prompt="$5"

  echo ""
  printf "%s╭──────────────────────────────────────────────────────────────────────────────╮%s\n" "$C_CYAN" "$C_RESET"
  printf "%s│%s 🚀 กำลังเข้าสู่ %s%s%s\n" "$C_CYAN" "$C_RESET" "$C_WHITE" "$role_name" "$C_RESET"
  printf "%s│%s    • ค่ายผู้ให้บริการ : %b  │  โมเดลที่ใช้: %s%s%s\n" "$C_CYAN" "$C_RESET" "$(format_provider_colored "$provider")" "$C_GOLD" "$configured_model" "$C_RESET"
  printf "%s│%s    • โฟลเดอร์ทำงาน  : %s%s%s\n" "$C_CYAN" "$C_RESET" "$C_LIGHT_GRAY" "$work_dir" "$C_RESET"
  printf "%s├──────────────────────────────────────────────────────────────────────────────┤%s\n" "$C_CYAN" "$C_RESET"
  printf "%s│%s 📋 คำสั่งเริ่มต้น (คัดลอกลง Clipboard ให้แล้วอัตโนมัติ):\n" "$C_CYAN" "$C_RESET"
  printf "%s%s%s\n" "$C_LIGHT_GRAY" "$initial_prompt" "$C_RESET"
  printf "%s├──────────────────────────────────────────────────────────────────────────────┤%s\n" "$C_CYAN" "$C_RESET"
  printf "%s│%s 💡 เมื่อสนทนาและสร้างเอกสารของขั้นตอนนี้เสร็จแล้ว ให้พิมพ์ %s/exit%s เพื่อกลับมาหน้าจอ RELAY\n" "$C_CYAN" "$C_RESET" "$C_GOLD" "$C_RESET"
  printf "%s╰──────────────────────────────────────────────────────────────────────────────╯%s\n" "$C_CYAN" "$C_RESET"

  if command -v pbcopy >/dev/null 2>&1; then
    printf "%s" "$initial_prompt" | pbcopy
  fi

  (
    cd "$work_dir"
    case "$provider" in
      claude) claude --model "$configured_model" "$initial_prompt" || true ;;
      codex)  codex -m "$configured_model" "$initial_prompt" || true ;;
      gemini) gemini -m "$configured_model" -i "$initial_prompt" 2>/dev/null || gemini -m "$configured_model" || true ;;
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
  printf "%s✅ สร้างใบงานใหม่เรียบร้อย: .relay/tasks/%s%s\n" "$C_GREEN" "$ACTIVE_TASK" "$C_RESET"
}

run_phase_1_po() {
  require_all_roles_ready || return 0
  ensure_or_create_task
  echo ""
  read -r -p "💡 อธิบายฟีเจอร์หรือความต้องการคร่าวๆ ที่ต้องการให้ @po วิเคราะห์: " user_goal
  local prompt="@po ฉันต้องการพัฒนาฟีเจอร์สำหรับใบงาน .relay/tasks/$ACTIVE_TASK เกี่ยวกับ: ${user_goal:-ตามที่ฉันกำลังจะอธิบายต่อไปนี้} กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md (ถ้ามี) แล้วซักถามความต้องการจากฉันทีละประเด็นจนชัดเจน เมื่อฉันยืนยันแล้วให้สรุปเป็นเอกสารกำหนดความต้องการลงในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md"
  launch_provider_cli "$ROLE_PO" "$MODEL_PO" "ขั้นตอนที่ 1: @po (Product Owner)" "$PROJECT_DIR" "$prompt"
}

run_phase_2_arch() {
  require_all_roles_ready || return 0
  ensure_or_create_task
  local prompt="@arch @pm กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md ร่วมกับไฟล์ความต้องการ .relay/tasks/$ACTIVE_TASK/SPEC.md แล้วออกแบบโครงสร้างทางเทคนิคลงในไฟล์ .relay/tasks/$ACTIVE_TASK/ARCH.md และจัดทำแผนการดำเนินงานย่อยเป็นข้อๆ ลงในไฟล์ .relay/tasks/$ACTIVE_TASK/PLAN.md"
  launch_provider_cli "$ROLE_ARCH" "$MODEL_ARCH" "ขั้นตอนที่ 2: @arch & @pm (Architect & Planner)" "$PROJECT_DIR" "$prompt"
}

run_phase_3_dev() {
  require_all_roles_ready || return 0
  ensure_or_create_task
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"
  local branch_name="feat/$ACTIVE_TASK"
  local target_work_dir="$PROJECT_DIR"

  if [ -d "$PROJECT_DIR/.git" ]; then
    mkdir -p "$RELAY_DIR/worktrees"
    if [ ! -d "$worktree_dir" ]; then
      printf "%s🌿 กำลังสร้าง Git Worktree แยกอิสระที่ .relay/worktrees/%s (กิ่ง %s)...%s\n" "$C_CYAN" "$ACTIVE_TASK" "$branch_name" "$C_RESET"
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
  require_all_roles_ready || return 0
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
  require_all_roles_ready || return 0
  get_active_task
  if [ -z "$ACTIVE_TASK" ]; then
    printf "%s⚠️ ยังไม่มีใบงานที่กำลังดำเนินการใน .relay/tasks/%s\n" "$C_RED" "$C_RESET"
    return
  fi
  local branch_name="feat/$ACTIVE_TASK"
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"

  interactive_menu "🏁 ยืนยันการผสานโค้ดกิ่ง ${branch_name} เข้าสู่ main และจัดเก็บใบงาน ${ACTIVE_TASK}" 0 \
    "y|${C_GREEN}ยืนยัน — ผสานโค้ดเข้ากิ่งหลัก ลบ Worktree และย้ายใบงานเข้า .relay/archive/${C_RESET}|ยืนยัน — ผสานโค้ดเข้ากิ่งหลัก ลบ Worktree และย้ายใบงานเข้า .relay/archive/" \
    "n|${C_LIGHT_GRAY}ยกเลิก — กลับสู่หน้าจอหลัก${C_RESET}|ยกเลิก — กลับสู่หน้าจอหลัก"

  if [ "$MENU_RESULT" = "y" ]; then
    if [ -d "$PROJECT_DIR/.git" ] && git show-ref --verify --quiet "refs/heads/$branch_name"; then
      git merge "$branch_name" || true
      [ -d "$worktree_dir" ] && { git worktree remove "$worktree_dir" --force 2>/dev/null || rm -rf "$worktree_dir"; }
      git branch -d "$branch_name" 2>/dev/null || true
    fi
    mkdir -p "$RELAY_DIR/archive"
    mv "$RELAY_DIR/tasks/$ACTIVE_TASK" "$RELAY_DIR/archive/$ACTIVE_TASK"
    CURRENT_TASK=""
    printf "%s✅ ผสานโค้ดและย้ายใบงานไปที่ .relay/archive/%s เรียบร้อยแล้ว!%s\n" "$C_GREEN" "$ACTIVE_TASK" "$C_RESET"
  fi
}

run_init_project() {
  interactive_menu "📂 เลือกประเภทโครงการที่ต้องการเตรียมโครงสร้าง .relay/" 0 \
    "1|${C_GREEN}โครงการใหม่ตั้งแต่ศูนย์ (Greenfield Project — สร้างโครงสร้าง .relay/ ทันที)${C_RESET}|โครงการใหม่ตั้งแต่ศูนย์ (Greenfield Project — สร้างโครงสร้าง .relay/ ทันที)" \
    "2|${C_GOLD}โครงการเดิมที่มีโค้ดอยู่แล้ว (Brownfield — สั่ง @arch สแกนโค้ดสรุปลง PROJECT_STATE.md)${C_RESET}|โครงการเดิมที่มีโค้ดอยู่แล้ว (Brownfield — สั่ง @arch สแกนโค้ดสรุปลง PROJECT_STATE.md)" \
    "b|${C_LIGHT_GRAY}ย้อนกลับ${C_RESET}|ย้อนกลับ"
  case "$MENU_RESULT" in
    1) "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" new ;;
    2)
      require_all_roles_ready || return 0
      "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" existing
      local prompt="@arch ช่วยสำรวจและวิเคราะห์โครงสร้างของโครงการเดิมนี้ทั้งหมด (ประกอบด้วย Tech Stack, โครงสร้างโฟลเดอร์สำคัญ, รูปแบบฐานข้อมูล/Schema, รายการ API หลัก และคำสั่งที่ใช้ในการ Build/Test) แล้วสรุปเขียนทับลงในไฟล์ .relay/PROJECT_STATE.md ให้มีความชัดเจนและกระชับ (ความยาวไม่เกิน 2 หน้า) โดยห้ามแก้ไขไฟล์โค้ดใดๆ ของระบบ"
      launch_provider_cli "$ROLE_ARCH" "$MODEL_ARCH" "การสแกนโครงสร้างโครงการเดิม (@arch)" "$PROJECT_DIR" "$prompt"
      ;;
  esac
}

run_skills_menu() {
  local skills_cmd="$GLOBAL_DIR/bin/relay-skills"
  [ ! -x "$skills_cmd" ] && skills_cmd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/relay-skills.sh"

  interactive_menu "🧰 จัดการและอัปเดตชุดทักษะ (RELAY Modular Skill Packs)" 0 \
    "1|${C_CYAN}แสดงรายการทักษะทั้งหมดในคลังและที่ติดตั้งแล้วในเครื่อง (list)${C_RESET}|แสดงรายการทักษะทั้งหมดในคลังและที่ติดตั้งแล้วในเครื่อง (list)" \
    "2|${C_GREEN}ติดตั้งชุดทักษะมาตรฐานทั้งหมดลงเครื่อง (install)${C_RESET}|ติดตั้งชุดทักษะมาตรฐานทั้งหมดลงเครื่อง (install)" \
    "3|${C_GOLD}อัปเดตทักษะทั้งหมดให้เป็นเวอร์ชันล่าสุดจาก GitHub (update)${C_RESET}|อัปเดตทักษะทั้งหมดให้เป็นเวอร์ชันล่าสุดจาก GitHub (update)" \
    "4|${C_PINK}เพิ่มทักษะใหม่จากลิงก์ GitHub Repository (add)${C_RESET}|เพิ่มทักษะใหม่จากลิงก์ GitHub Repository (add)" \
    "b|${C_LIGHT_GRAY}กลับสู่หน้าจอหลัก${C_RESET}|กลับสู่หน้าจอหลัก"

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

# ─── 12. รองรับ Subcommands จากบรรทัดคำสั่งโดยตรง ──────────────────────────────
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

# ─── 13. Interactive Main Loop ────────────────────────────────────────────────
while true; do
  print_dashboard_header

  if [ "$ALL_ROLES_READY" -eq 1 ]; then
    interactive_menu "🎛️  เลือกคำสั่งการทำงาน (✅ ตั้งค่าครบทั้ง 4 ตำแหน่งแล้ว — พร้อมเริ่มงานทันที)" 0 \
      "1|${C_PINK}เริ่มขั้นตอนที่ 1 (@po)${C_RESET}        — วิเคราะห์ความต้องการและสร้าง SPEC.md (${ROLE_PO}/${MODEL_PO})|เริ่มขั้นตอนที่ 1 (@po)        — วิเคราะห์ความต้องการและสร้าง SPEC.md (${ROLE_PO}/${MODEL_PO})" \
      "2|${C_GOLD}เริ่มขั้นตอนที่ 2 (@arch/@pm)${C_RESET}  — อ่าน SPEC.md แล้วสร้าง ARCH.md & PLAN.md (${ROLE_ARCH}/${MODEL_ARCH})|เริ่มขั้นตอนที่ 2 (@arch/@pm)  — อ่าน SPEC.md แล้วสร้าง ARCH.md & PLAN.md (${ROLE_ARCH}/${MODEL_ARCH})" \
      "3|${C_CYAN}เริ่มขั้นตอนที่ 3 (@dev)${C_RESET}       — แยก Git Worktree อัตโนมัติและพัฒนาโค้ด (${ROLE_DEV}/${MODEL_DEV})|เริ่มขั้นตอนที่ 3 (@dev)       — แยก Git Worktree อัตโนมัติและพัฒนาโค้ด (${ROLE_DEV}/${MODEL_DEV})" \
      "4|${C_MINT}เริ่มขั้นตอนที่ 4 (@qa/@sec)${C_RESET}   — รันชุดทดสอบ + ตรวจความปลอดภัย + สรุป QA_REPORT.md (${ROLE_QA}/${MODEL_QA})|เริ่มขั้นตอนที่ 4 (@qa/@sec)   — รันชุดทดสอบ + ตรวจความปลอดภัย + สรุป QA_REPORT.md (${ROLE_QA}/${MODEL_QA})" \
      "5|${C_GREEN}ผสานโค้ดและจัดเก็บใบงาน${C_RESET}      — Merge เข้ากิ่ง main และย้ายเข้า .relay/archive/|ผสานโค้ดและจัดเก็บใบงาน      — Merge เข้ากิ่ง main และย้ายเข้า .relay/archive/" \
      "c|${C_GOLD}ตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่ง (/model)${C_RESET}|ตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่ง (/model)" \
      "d|${C_BLUE}จัดการการเชื่อมต่อ CLI, ติดตั้ง & Login ทั้ง 3 ค่าย (/connect)${C_RESET}|จัดการการเชื่อมต่อ CLI, ติดตั้ง & Login ทั้ง 3 ค่าย (/connect)" \
      "t|${C_GREEN}ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่ง — เช็กบทบาท & Skills (/test)${C_RESET}|ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่ง — เช็กบทบาท & Skills (/test)" \
      "s|${C_VIOLET}จัดการและอัปเดตชุดทักษะ Skills (/skills)${C_RESET}|จัดการและอัปเดตชุดทักษะ Skills (/skills)" \
      "n|${C_CYAN}สร้างใบงานใหม่ (New Task) (/new)${C_RESET}|สร้างใบงานใหม่ (New Task) (/new)" \
      "i|${C_INDIGO}เตรียมโครงสร้าง .relay/ สำหรับโครงการใหม่หรือโครงการเดิม (/init)${C_RESET}|เตรียมโครงสร้าง .relay/ สำหรับโครงการใหม่หรือโครงการเดิม (/init)" \
      "q|${C_RED}ออกจากโปรแกรม (/quit)${C_RESET}|ออกจากโปรแกรม (/quit)"
  else
    # หากยังตั้งค่าไม่ครบ 4 ตำแหน่ง ให้ล็อก [1]-[5] และวางแถบเลือกเริ่มต้นที่ [c] (index 5) ทันที!
    interactive_menu "🔒 กรุณาตั้งค่าค่าย AI & Model ให้ครบทั้ง 4 ตำแหน่งก่อน (ปัจจุบันพร้อม ${READY_ROLE_COUNT}/4 ตำแหน่ง)" 5 \
      "1|${C_GRAY}🔒 [ล็อก] ขั้นตอนที่ 1 (@po)        — ต้องตั้งค่าค่าย & Model ให้ครบ 4 ตำแหน่งใน [c] ก่อน${C_RESET}|🔒 [ล็อก] ขั้นตอนที่ 1 (@po)        — ต้องตั้งค่าค่าย & Model ให้ครบ 4 ตำแหน่งใน [c] ก่อน" \
      "2|${C_GRAY}🔒 [ล็อก] ขั้นตอนที่ 2 (@arch/@pm)  — ต้องตั้งค่าค่าย & Model ให้ครบ 4 ตำแหน่งใน [c] ก่อน${C_RESET}|🔒 [ล็อก] ขั้นตอนที่ 2 (@arch/@pm)  — ต้องตั้งค่าค่าย & Model ให้ครบ 4 ตำแหน่งใน [c] ก่อน" \
      "3|${C_GRAY}🔒 [ล็อก] ขั้นตอนที่ 3 (@dev)       — ต้องตั้งค่าค่าย & Model ให้ครบ 4 ตำแหน่งใน [c] ก่อน${C_RESET}|🔒 [ล็อก] ขั้นตอนที่ 3 (@dev)       — ต้องตั้งค่าค่าย & Model ให้ครบ 4 ตำแหน่งใน [c] ก่อน" \
      "4|${C_GRAY}🔒 [ล็อก] ขั้นตอนที่ 4 (@qa/@sec)   — ต้องตั้งค่าค่าย & Model ให้ครบ 4 ตำแหน่งใน [c] ก่อน${C_RESET}|🔒 [ล็อก] ขั้นตอนที่ 4 (@qa/@sec)   — ต้องตั้งค่าค่าย & Model ให้ครบ 4 ตำแหน่งใน [c] ก่อน" \
      "5|${C_GRAY}🔒 [ล็อก] ผสานโค้ดและจัดเก็บใบงาน      — ต้องตั้งค่าค่าย & Model ให้ครบ 4 ตำแหน่งใน [c] ก่อน${C_RESET}|🔒 [ล็อก] ผสานโค้ดและจัดเก็บใบงาน      — ต้องตั้งค่าค่าย & Model ให้ครบ 4 ตำแหน่งใน [c] ก่อน" \
      "c|${C_GOLD}👉 ตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่งให้ครบทั้ง 4 ตำแหน่ง (/model)${C_RESET}|👉 ตั้งค่าค่าย AI & เลือก Model ประจำตำแหน่งให้ครบทั้ง 4 ตำแหน่ง (/model)" \
      "d|${C_BLUE}จัดการการเชื่อมต่อ CLI, ติดตั้ง & Login ทั้ง 3 ค่าย (/connect)${C_RESET}|จัดการการเชื่อมต่อ CLI, ติดตั้ง & Login ทั้ง 3 ค่าย (/connect)" \
      "t|${C_GREEN}ตรวจสอบสถานะความพร้อม Agent & Skills ประจำตำแหน่ง (/test)${C_RESET}|ตรวจสอบสถานะความพร้อม Agent & Skills ประจำตำแหน่ง (/test)" \
      "s|${C_VIOLET}จัดการและอัปเดตชุดทักษะ Skills (/skills)${C_RESET}|จัดการและอัปเดตชุดทักษะ Skills (/skills)" \
      "n|${C_CYAN}สร้างใบงานใหม่ (New Task) (/new)${C_RESET}|สร้างใบงานใหม่ (New Task) (/new)" \
      "i|${C_INDIGO}เตรียมโครงสร้าง .relay/ สำหรับโครงการใหม่หรือโครงการเดิม (/init)${C_RESET}|เตรียมโครงสร้าง .relay/ สำหรับโครงการใหม่หรือโครงการเดิม (/init)" \
      "q|${C_RED}ออกจากโปรแกรม (/quit)${C_RESET}|ออกจากโปรแกรม (/quit)"
  fi

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
      printf "%s👋 ออกจากหน้าจอควบคุม RELAY เรียบร้อย%s\n" "$C_CYAN" "$C_RESET"
      exit 0
      ;;
  esac
done
