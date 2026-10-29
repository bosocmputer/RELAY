#!/usr/bin/env bash

# ==============================================================================
# 🎛️ RELAY Central Terminal Hub (v1.0) — Guided 3-Stage Progressive UX
# • โทนสี Minimalist 3-Tier (รองรับทั้ง Terminal พื้นหลังสีขาว Light Mode และพื้นดำ Dark Mode)
# • ไฮไลต์บรรทัดที่เลือกด้วย ❯ + สีน้ำเงินครามตัวหนาทั้งบรรทัด (คลุมครบ 100% ไม่แหว่งสระไทย)
# • รองรับโควตา Google AI Ultra เต็มรูปแบบผ่าน Antigravity CLI (~/.gemini/bin/agy):
#   ใช้ได้ทั้ง Gemini 4 Argon, Gemini 3.8 Flash, Claude Opus 5.5, Claude Sonnet 5.5
# • ตรวจสอบความพร้อมจริง 3 ชั้น: ติดตั้ง CLI แล้ว + Login บัญชีแล้ว + เลือก Model แล้ว
# ==============================================================================

export PATH="$HOME/.gemini/bin:$HOME/.local/bin:$HOME/.agents/bin:$PATH"

GLOBAL_DIR="$HOME/.agents"
GLOBAL_ROLES_CONF="$GLOBAL_DIR/relay-roles.conf"
AGY_MODELS_CACHE="$GLOBAL_DIR/agy-models.cache"
QUOTA_CACHE_FILE="$GLOBAL_DIR/relay-quota.cache"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
RELAY_DIR="$PROJECT_DIR/.relay"
PROJECT_ROLES_CONF="$RELAY_DIR/roles.conf"
LAST_COMPLETED_PHASE=0

refresh_project_paths() {
  PROJECT_NAME="$(basename "$PROJECT_DIR")"
  RELAY_DIR="$PROJECT_DIR/.relay"
  PROJECT_ROLES_CONF="$RELAY_DIR/roles.conf"
}

# ─── ระบบสี Minimalist High-Contrast (อ่านคมชัดทั้งบนพื้นขาวและพื้นดำ) ─────────
export CLICOLOR=1
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'

# สีเทาเข้มปานกลาง (ไม่จางหายบนพื้นขาว และไม่มืดจมบนพื้นดำ)
C_MUTED=$'\033[38;5;242m'

# สีหลักของระบบ (Primary Accent — น้ำเงินคราม Cerulean / Royal Blue)
C_ACCENT=$'\033[38;5;32m'
C_ACCENT_SH=$'\033[38;5;24m'
C_SEL=$'\033[1;38;5;26m'

# สีบอกสถานะ (ใช้เฉพาะจุดบอกสถานะเท่านั้น ไม่ระบายพร่ำเพรื่อ)
C_OK=$'\033[38;5;28m'
C_WARN=$'\033[38;5;166m'
C_ERR=$'\033[38;5;160m'

# ─── 1. ตรวจสอบการติดตั้ง CLI, สถานะ Login จริง และดึง Model จาก CLI โดยตรง ───
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

# แคชสถานะการ Login ของทุกค่ายต่อรอบการแสดงผล เพื่อความรวดเร็วสูงสุด
CLI_AUTH_AGY=0
CLI_AUTH_CLAUDE=0
CLI_AUTH_CODEX=0
CLI_AUTH_DETAIL_AGY="ยังไม่ได้ Login"
CLI_AUTH_DETAIL_CLAUDE="ยังไม่ได้ Login"
CLI_AUTH_DETAIL_CODEX="ยังไม่ได้ Login"

refresh_cli_auth_cache() {
  # 1. ตรวจสถานะ Login ของ agy (Google AI Ultra / Antigravity CLI)
  CLI_AUTH_AGY=0
  CLI_AUTH_DETAIL_AGY="ยังไม่ได้ Login (รัน agy เพื่อเข้าสู่ระบบ Google AI Ultra)"
  if is_provider_installed "agy"; then
    if [ -s "$HOME/.gemini/jetski-standalone-oauth-token" ] || [ -s "$HOME/.gemini/config/config.json" ] || [ -d "$HOME/.gemini/antigravity-cli" ]; then
      CLI_AUTH_AGY=1
      CLI_AUTH_DETAIL_AGY="Login แล้ว (Google AI Ultra • Gemini 4 + Claude 5.5)"
    fi
  fi

  # 2. ตรวจสถานะ Login ของ Claude Code CLI
  CLI_AUTH_CLAUDE=0
  CLI_AUTH_DETAIL_CLAUDE="ยังไม่ได้ Login (รัน claude auth login หรือใช้ค่าย agy แทน)"
  if is_provider_installed "claude"; then
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
      CLI_AUTH_CLAUDE=1
      CLI_AUTH_DETAIL_CLAUDE="Login แล้ว (ANTHROPIC_API_KEY)"
    else
      local c_auth
      c_auth="$(claude auth status 2>/dev/null || true)"
      if printf "%s" "$c_auth" | grep -Eq '"loggedIn"[[:space:]]*:[[:space:]]*true'; then
        CLI_AUTH_CLAUDE=1
        local c_method
        c_method="$(printf "%s" "$c_auth" | grep -Eo '"authMethod"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n 1 | sed -E 's/.*"([^"]+)"$/\1/' || true)"
        CLI_AUTH_DETAIL_CLAUDE="Login แล้ว (${c_method:-OAuth})"
      fi
    fi
  fi

  # 3. ตรวจสถานะ Login ของ OpenAI Codex CLI
  CLI_AUTH_CODEX=0
  CLI_AUTH_DETAIL_CODEX="ยังไม่ได้ Login (รัน codex login)"
  if is_provider_installed "codex"; then
    if [ -n "${OPENAI_API_KEY:-}" ]; then
      CLI_AUTH_CODEX=1
      CLI_AUTH_DETAIL_CODEX="Login แล้ว (OPENAI_API_KEY)"
    else
      local x_auth
      x_auth="$(codex login status 2>&1 | tr -d '\r' | head -n 1 || true)"
      if printf "%s" "$x_auth" | grep -qi "Logged in"; then
        CLI_AUTH_CODEX=1
        CLI_AUTH_DETAIL_CODEX="Login แล้ว (${x_auth})"
      elif [ -s "$HOME/.codex/auth.json" ]; then
        CLI_AUTH_CODEX=1
        CLI_AUTH_DETAIL_CODEX="Login แล้ว (auth.json)"
      fi
    fi
  fi
}

is_provider_logged_in() {
  local provider="$1"
  case "$provider" in
    agy)    [ "$CLI_AUTH_AGY" -eq 1 ] ;;
    claude) [ "$CLI_AUTH_CLAUDE" -eq 1 ] ;;
    codex)  [ "$CLI_AUTH_CODEX" -eq 1 ] ;;
    *) return 1 ;;
  esac
}

get_provider_auth_detail() {
  local provider="$1"
  case "$provider" in
    agy)    echo "$CLI_AUTH_DETAIL_AGY" ;;
    claude) echo "$CLI_AUTH_DETAIL_CLAUDE" ;;
    codex)  echo "$CLI_AUTH_DETAIL_CODEX" ;;
    *) echo "ไม่ทราบสถานะ" ;;
  esac
}

get_cli_default_model() {
  local provider="$1"
  case "$provider" in
    agy)
      echo "gemini-4-argon-high"
      ;;
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
      if [ -r "$HOME/.codex/models_cache.json" ] && command -v python3 >/dev/null 2>&1; then
        local first_codex
        first_codex="$(python3 -c '
import json, os
try:
    data = json.load(open(os.path.expanduser("~/.codex/models_cache.json")))
    models = data.get("models", data) if isinstance(data, dict) else data
    for m in models:
        if isinstance(m, dict) and m.get("visibility") == "list" and m.get("slug"):
            print(m["slug"]); break
except Exception:
    pass
' 2>/dev/null || true)"
        [ -n "$first_codex" ] && { echo "$first_codex"; return; }
      fi
      echo "gpt-6.1-terra"
      ;;
    *)
      echo "default"
      ;;
  esac
}

# ดึงรายชื่อ Model จาก CLI ในเครื่องโดยตรง (คืนค่าบรรทัดละ "model_id|คำอธิบาย")
get_cli_live_models() {
  local provider="$1"
  local cli_def
  cli_def="$(get_cli_default_model "$provider")"

  if [ "$provider" = "agy" ]; then
    if [ -s "$AGY_MODELS_CACHE" ]; then
      cat "$AGY_MODELS_CACHE"
      return
    fi
    cat << 'EOF'
gemini-4-argon-high|Gemini 4 Argon (High) — โควตา Google AI Ultra (แนะนำสำหรับ @po / วิเคราะห์ลึก)
gemini-4-argon-medium|Gemini 4 Argon (Medium) — โควตา Google AI Ultra (สมดุลความเร็วและคุณภาพ)
gemini-4-argon-low|Gemini 4 Argon (Low) — โควตา Google AI Ultra (ประหยัดโควตาสูงสุด)
gemini-3.8-flash-high|Gemini 3.8 Flash (High) — โควตา Google AI Ultra (ความเร็วสูง คุณภาพสูง)
gemini-3.8-flash-medium|Gemini 3.8 Flash (Medium) — โควตา Google AI Ultra (รวดเร็วสำหรับงานทั่วไป)
gemini-3.8-flash-low|Gemini 3.8 Flash (Low) — โควตา Google AI Ultra (เบาและเร็วที่สุด)
claude-opus-5-5-high|Claude Opus 5.5 (High) — โควตา Google AI Ultra (แนะนำสำหรับ @arch/@pm)
claude-opus-5-5-medium|Claude Opus 5.5 (Medium) — โควตา Google AI Ultra (สถาปัตยกรรมและวางแผน)
claude-opus-5-5-low|Claude Opus 5.5 (Low) — โควตา Google AI Ultra (ประหยัดโควตา Claude Opus)
claude-sonnet-5-5-high|Claude Sonnet 5.5 (High) — โควตา Google AI Ultra (แนะนำสำหรับ @dev เขียนโค้ด)
claude-sonnet-5-5-medium|Claude Sonnet 5.5 (Medium) — โควตา Google AI Ultra (เขียนโค้ดรวดเร็ว)
claude-sonnet-5-5-low|Claude Sonnet 5.5 (Low) — โควตา Google AI Ultra (ประหยัดโควตา Claude Sonnet)
gpt-oss-120b-medium|GPT-OSS 120B (Medium) — โควตา Google AI Ultra (โมเดล GPT บน Antigravity)
EOF
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$provider" "$cli_def" << 'PYEOF'
import sys, os, re, json, shutil

provider = sys.argv[1]
cli_def = sys.argv[2]
results = []
seen = set()

def add_item(mid, desc):
    if not mid or mid in seen:
        return
    seen.add(mid)
    results.append((mid, desc))

if provider == "codex":
    if cli_def and cli_def != "default":
        add_item(cli_def, "ค่าเริ่มต้นปัจจุบันจาก ~/.codex/config.toml")
    cache_path = os.path.expanduser("~/.codex/models_cache.json")
    if os.path.exists(cache_path):
        try:
            data = json.load(open(cache_path, errors="ignore"))
            models = data.get("models", data) if isinstance(data, dict) else data
            if isinstance(models, list):
                for m in models:
                    if isinstance(m, dict) and m.get("visibility") == "list":
                        slug = m.get("slug") or m.get("id")
                        desc = (m.get("description") or "โมเดลจาก ~/.codex/models_cache.json").strip()
                        add_item(slug, f"{desc} (ดึงจาก Codex CLI)")
        except Exception:
            pass
    if not results:
        add_item("gpt-6.1-terra", "GPT-6.1 Terra Codex Model")
        add_item("gpt-6.1-sol", "GPT-6.1 Sol Workhorse Model")

elif provider == "claude":
    if cli_def and cli_def != "default":
        add_item(cli_def, "ค่าเริ่มต้นปัจจุบันจาก Claude Code CLI")
    add_item("sonnet", "Alias มาตรฐานของ Claude Code ชี้ไปยัง Sonnet รุ่นล่าสุด")
    add_item("opus", "Alias มาตรฐานของ Claude Code ชี้ไปยัง Opus รุ่นล่าสุด (วิเคราะห์ลึก)")
    add_item("haiku", "Alias มาตรฐานของ Claude Code ชี้ไปยัง Haiku รุ่นล่าสุด (รวดเร็ว)")
    claude_bin = shutil.which("claude")
    if claude_bin:
        try:
            real_c = os.path.realpath(claude_bin)
            raw = open(real_c, "rb").read().decode("latin1", errors="ignore")
            c_models = sorted(set(re.findall(r"claude-(?:sonnet|opus|haiku)-[45]-[0-9](?:-[0-9]{8})?", raw)), reverse=True)
            for cm in c_models[:8]:
                add_item(cm, "รหัสโมเดลจริงที่ตรวจพบในไบนารี Claude Code CLI")
        except Exception:
            pass

for mid, desc in results[:12]:
    print(f"{mid}|{desc}")
PYEOF
  else
    case "$provider" in
      claude)
        printf "sonnet|Claude Sonnet (Alias มาตรฐานจาก CLI)\nopus|Claude Opus (Alias มาตรฐานจาก CLI)\nhaiku|Claude Haiku (Alias มาตรฐานจาก CLI)\n"
        ;;
      codex)
        printf "%s|ค่าเริ่มต้นจาก ~/.codex/config.toml\n" "$cli_def"
        ;;
    esac
  fi
}

refresh_agy_models_live() {
  if ! is_provider_installed "agy"; then
    printf "%s✖ ไม่พบคำสั่ง agy ในเครื่อง%s\n" "$C_ERR" "$C_RESET"
    return 1
  fi
  printf "\n%sกำลังดึงรายชื่อโมเดลล่าสุดของแพ็กเกจ Google AI Ultra จาก 'agy models'...%s\n" "$C_ACCENT" "$C_RESET"
  local raw_out
  raw_out="$(agy models 2>/dev/null | tr -d '\r' | grep -E '^[a-z0-9][a-z0-9._-]+[[:space:]]+' || true)"
  if [ -n "$raw_out" ]; then
    mkdir -p "$GLOBAL_DIR"
    : > "$AGY_MODELS_CACHE"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local mid mdesc
      mid="$(printf "%s" "$line" | awk '{print $1}')"
      mdesc="$(printf "%s" "$line" | sed -E 's/^[^[:space:]]+[[:space:]]+//')"
      printf "%s|%s — โควตา Google AI Ultra (ดึงสดจาก agy models)\n" "$mid" "$mdesc" >> "$AGY_MODELS_CACHE"
    done <<< "$raw_out"
    printf "%s● อัปเดตรายชื่อโมเดลจาก agy models สำเร็จแล้ว!%s\n" "$C_OK" "$C_RESET"
  else
    printf "%s▲ ไม่สามารถดึงรายการใหม่ได้ ใช้รายการมาตรฐานของ Google AI Ultra ต่อไป%s\n" "$C_WARN" "$C_RESET"
  fi
}

# ─── 2. โหลดและบันทึกการตั้งค่า Role & Model ─────────────────────────────────
load_role_config() {
  refresh_project_paths
  ROLE_PO="agy";     MODEL_PO="gemini-4-argon-high"
  ROLE_ARCH="agy";   MODEL_ARCH="claude-opus-5-5-high"
  ROLE_DEV="agy";    MODEL_DEV="claude-sonnet-5-5-high"
  ROLE_QA="codex";   MODEL_QA="gpt-6.1-terra"
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

  # หากไฟล์ตั้งค่าเดิมเคยมีค่าย gemini ที่ยกเลิกการรองรับแล้ว ให้เปลี่ยนเป็น agy (Google AI Ultra) อัตโนมัติ
  [ "$ROLE_PO" = "gemini" ]   && { ROLE_PO="agy";   MODEL_PO="gemini-4-argon-high"; }
  [ "$ROLE_ARCH" = "gemini" ] && { ROLE_ARCH="agy"; MODEL_ARCH="claude-opus-5-5-high"; }
  [ "$ROLE_DEV" = "gemini" ]  && { ROLE_DEV="agy";  MODEL_DEV="claude-sonnet-5-5-high"; }
  [ "$ROLE_QA" = "gemini" ]   && { ROLE_QA="agy";   MODEL_QA="gemini-3.8-flash-high"; }

  # หากค่าเดิมของ Codex เคยถูกตั้งเป็น o3 แต่ในเครื่องมีโมเดลจริงใน config.toml ให้สลับมาใช้โมเดลจริงทันที
  if [ "$ROLE_QA" = "codex" ] && [ "$MODEL_QA" = "o3" ] && [ -r "$HOME/.codex/config.toml" ]; then
    local real_codex_def
    real_codex_def="$(get_cli_default_model codex)"
    if [ -n "$real_codex_def" ] && [ "$real_codex_def" != "o3" ]; then
      MODEL_QA="$real_codex_def"
    fi
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

is_model_explicitly_set() {
  local m="$1"
  [ -n "$m" ] && [ "$m" != "default" ] && [ "$m" != "unconfigured" ] && [ "$m" != "none" ]
}

# เงื่อนไขความพร้อมจริง 3 ชั้น: ติดตั้ง CLI แล้ว + Login บัญชีแล้ว + เลือก Model แล้ว
is_role_ready() {
  local provider="$1"
  local model="$2"
  is_provider_installed "$provider" && is_provider_logged_in "$provider" && is_model_explicitly_set "$model"
}

READY_ROLE_COUNT=0
ALL_ROLES_READY=0
MODELS_SET_COUNT=0
UNLOGGED_ACTIVE_PROVIDERS=""

check_all_roles_ready() {
  load_role_config
  refresh_cli_auth_cache

  READY_ROLE_COUNT=0
  MODELS_SET_COUNT=0
  UNLOGGED_ACTIVE_PROVIDERS=""

  if is_model_explicitly_set "$MODEL_PO"; then MODELS_SET_COUNT=$((MODELS_SET_COUNT + 1)); fi
  if is_model_explicitly_set "$MODEL_ARCH"; then MODELS_SET_COUNT=$((MODELS_SET_COUNT + 1)); fi
  if is_model_explicitly_set "$MODEL_DEV"; then MODELS_SET_COUNT=$((MODELS_SET_COUNT + 1)); fi
  if is_model_explicitly_set "$MODEL_QA"; then MODELS_SET_COUNT=$((MODELS_SET_COUNT + 1)); fi

  if is_role_ready "$ROLE_PO" "$MODEL_PO"; then READY_ROLE_COUNT=$((READY_ROLE_COUNT + 1)); fi
  if is_role_ready "$ROLE_ARCH" "$MODEL_ARCH"; then READY_ROLE_COUNT=$((READY_ROLE_COUNT + 1)); fi
  if is_role_ready "$ROLE_DEV" "$MODEL_DEV"; then READY_ROLE_COUNT=$((READY_ROLE_COUNT + 1)); fi
  if is_role_ready "$ROLE_QA" "$MODEL_QA"; then READY_ROLE_COUNT=$((READY_ROLE_COUNT + 1)); fi

  for rp in "$ROLE_PO" "$ROLE_ARCH" "$ROLE_DEV" "$ROLE_QA"; do
    if is_provider_installed "$rp" && ! is_provider_logged_in "$rp"; then
      case " $UNLOGGED_ACTIVE_PROVIDERS " in
        *" $rp "*) ;;
        *) UNLOGGED_ACTIVE_PROVIDERS="${UNLOGGED_ACTIVE_PROVIDERS:+$UNLOGGED_ACTIVE_PROVIDERS, }$rp" ;;
      esac
    fi
  done

  if [ "$READY_ROLE_COUNT" -eq 4 ]; then
    ALL_ROLES_READY=1
  else
    ALL_ROLES_READY=0
  fi

  load_quota_cache
}

# ─── 2.5 ระบบดึงและแสดงโควต้าคงเหลือแบบเรียลไทม์ (Real-Time Multi-Provider Quota Engine) ───
QUOTA_UPDATED_EPOCH=0
QUOTA_UPDATED_AT="-"
AGY_GEMINI_5H_REM="-"
AGY_GEMINI_5H_RESET="-"
AGY_GEMINI_7D_REM="-"
AGY_GEMINI_7D_RESET="-"
AGY_CLAUDE_5H_REM="-"
AGY_CLAUDE_5H_RESET="-"
AGY_CLAUDE_7D_REM="-"
AGY_CLAUDE_7D_RESET="-"
CODEX_PLAN="Plus"
CODEX_5H_REM="-"
CODEX_5H_RESET="-"
CODEX_7D_REM="-"
CODEX_7D_RESET="-"
CLAUDE_PLAN="Pro"
CLAUDE_5H_REM="-"
CLAUDE_5H_RESET="-"
CLAUDE_7D_REM="-"
CLAUDE_7D_RESET="-"
AGY_GEMINI_5H_RESET_EPOCH="-"
AGY_GEMINI_7D_RESET_EPOCH="-"
AGY_CLAUDE_5H_RESET_EPOCH="-"
AGY_CLAUDE_7D_RESET_EPOCH="-"
CODEX_5H_RESET_EPOCH="-"
CODEX_7D_RESET_EPOCH="-"
CLAUDE_5H_RESET_EPOCH="-"
CLAUDE_7D_RESET_EPOCH="-"
AGY_FETCH_OK="-"
AGY_FETCHED_AT="-"
CODEX_FETCH_OK="-"
CODEX_FETCHED_AT="-"
CLAUDE_FETCH_OK="-"
CLAUDE_FETCHED_AT="-"

refresh_quota_cache() {
  local mode="${1:-auto}"
  mkdir -p "$GLOBAL_DIR"

  if [ "$mode" != "--quiet" ]; then
    printf "%sกำลังดึงข้อมูลโควต้าคงเหลือแบบเรียลไทม์จาก CLI ทุกค่าย (agy / codex / claude)...%s\n" "$C_ACCENT" "$C_RESET"
  fi

  if [ "$mode" = "--deep" ] && is_provider_installed "codex" && is_provider_logged_in "codex"; then
    codex exec --skip-git-repo-check "ok" </dev/null >/dev/null 2>&1 || true
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$QUOTA_CACHE_FILE" "$CLI_AUTH_AGY" "$CLI_AUTH_CLAUDE" "$CLI_AUTH_CODEX" <<'PYEOF' 2>/dev/null || true
import sys, os, re, json, glob, time, pty, subprocess
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor

cache_file = sys.argv[1]
has_agy = (sys.argv[2] == "1")
has_claude = (sys.argv[3] == "1")
has_codex = (len(sys.argv) > 4 and sys.argv[4] == "1")
NOW_HM = datetime.now().strftime("%H:%M")
TH_MONTHS = ["", "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]

def fmt_dt_short(dt, is_weekly=False):
    if not dt:
        return "-"
    if is_weekly:
        return f"{dt.day:02d} {TH_MONTHS[dt.month]} {dt.strftime('%H:%M')}"
    return dt.strftime("%H:%M")

vals = {
    "QUOTA_UPDATED_EPOCH": str(int(time.time())),
    "QUOTA_UPDATED_AT": datetime.now().strftime("%H:%M:%S"),
    "AGY_GEMINI_5H_REM": "-",
    "AGY_GEMINI_5H_RESET": "-",
    "AGY_GEMINI_7D_REM": "-",
    "AGY_GEMINI_7D_RESET": "-",
    "AGY_CLAUDE_5H_REM": "-",
    "AGY_CLAUDE_5H_RESET": "-",
    "AGY_CLAUDE_7D_REM": "-",
    "AGY_CLAUDE_7D_RESET": "-",
    "CODEX_PLAN": "Plus",
    "CODEX_5H_REM": "-",
    "CODEX_5H_RESET": "-",
    "CODEX_7D_REM": "-",
    "CODEX_7D_RESET": "-",
    "CLAUDE_PLAN": "Pro",
    "CLAUDE_5H_REM": "-",
    "CLAUDE_5H_RESET": "-",
    "CLAUDE_7D_REM": "-",
    "CLAUDE_7D_RESET": "-",
    "AGY_GEMINI_5H_RESET_EPOCH": "-",
    "AGY_GEMINI_7D_RESET_EPOCH": "-",
    "AGY_CLAUDE_5H_RESET_EPOCH": "-",
    "AGY_CLAUDE_7D_RESET_EPOCH": "-",
    "CODEX_5H_RESET_EPOCH": "-",
    "CODEX_7D_RESET_EPOCH": "-",
    "CLAUDE_5H_RESET_EPOCH": "-",
    "CLAUDE_7D_RESET_EPOCH": "-",
    "AGY_FETCH_OK": "-", "AGY_FETCHED_AT": "-",
    "CODEX_FETCH_OK": "-", "CODEX_FETCHED_AT": "-",
    "CLAUDE_FETCH_OK": "-", "CLAUDE_FETCHED_AT": "-",
}

def to_epoch(dt):
    try:
        return str(int(dt.timestamp())) if dt else "-"
    except Exception:
        return "-"

if os.path.exists(cache_file):
    try:
        for line in open(cache_file, encoding="utf-8"):
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                v = v.strip().strip('"').strip("'")
                if k in vals and k not in ("QUOTA_UPDATED_EPOCH", "QUOTA_UPDATED_AT") and v and v != "-":
                    vals[k] = v
    except Exception:
        pass

def fetch_agy():
    if not has_agy:
        return ""
    try:
        proc = subprocess.Popen(
            ["agy", "-p", "/usage"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            close_fds=True,
        )
        out, _ = proc.communicate(timeout=15)
        return out.decode("utf-8", errors="ignore")
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass
        return ""

def fetch_claude():
    if not has_claude:
        return ""
    try:
        req = b'{"type":"control_request","request_id":"1","request":{"subtype":"get_usage","skip_behaviors":true}}\n'
        proc = subprocess.Popen(
            ["claude", "-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            close_fds=True,
        )
        out, _ = proc.communicate(input=req, timeout=15)
        return out.decode("utf-8", errors="ignore")
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass
        return ""

with ThreadPoolExecutor(max_workers=2) as ex:
    fut_agy = ex.submit(fetch_agy)
    fut_claude = ex.submit(fetch_claude)
    raw_agy = fut_agy.result()
    raw_claude = fut_claude.result()

# 1. แยกวิเคราะห์ผลลัพธ์จาก agy -p "/usage" (รองรับทั้งโหมด TSV ISO-8601 UTC เมื่อต่อ Pipe และโหมด TTY)
agy_ok = False
if raw_agy:
    try:
        for line in raw_agy.splitlines():
            m = re.search(
                r"^(Gemini Models|Claude and GPT models)\s+(Weekly Limit Remaining|Five Hour Limit Remaining)\s+(\d+)%\s+(\S+(?:\s+\S+)?)",
                line.strip(),
            )
            if m:
                group, win, pct, dt_str = m.group(1), m.group(2), m.group(3), m.group(4).strip()
                dt_obj = None
                try:
                    if "T" in dt_str:
                        dt_obj = datetime.fromisoformat(dt_str.replace("Z", "+00:00")).astimezone()
                    else:
                        dt_clean = re.sub(r"\s+[+-]\d+$", "", dt_str)
                        dt_obj = datetime.strptime(dt_clean, "%Y-%m-%d %H:%M")
                except Exception:
                    dt_obj = None
                is_wk = "Weekly" in win
                prefix = "AGY_GEMINI" if "Gemini" in group else "AGY_CLAUDE"
                win_key = "7D" if is_wk else "5H"
                vals[f"{prefix}_{win_key}_REM"] = pct
                vals[f"{prefix}_{win_key}_RESET"] = fmt_dt_short(dt_obj, is_weekly=is_wk)
                vals[f"{prefix}_{win_key}_RESET_EPOCH"] = to_epoch(dt_obj)
                agy_ok = True
    except Exception:
        pass

if has_agy:
    vals["AGY_FETCH_OK"] = "1" if agy_ok else "0"
    if agy_ok:
        vals["AGY_FETCHED_AT"] = NOW_HM
else:
    vals["AGY_FETCH_OK"] = "-"

# 2. แยกวิเคราะห์ผลลัพธ์จาก ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl
codex_ok = False
try:
    codex_files = sorted(glob.glob(os.path.expanduser("~/.codex/sessions/*/*/*/rollout-*.jsonl")))
    for cf in reversed(codex_files[-8:]):
        found_rl = False
        for line in reversed(open(cf, encoding="utf-8", errors="ignore").readlines()):
            if '"rate_limits"' in line and '"token_count"' in line:
                obj = json.loads(line)
                rl = (obj.get("payload") or {}).get("rate_limits") or {}
                prim = rl.get("primary") or {}
                sec = rl.get("secondary") or {}
                if prim.get("used_percent") is not None:
                    rem5 = max(0, min(100, int(round(100.0 - float(prim["used_percent"])))))
                    vals["CODEX_5H_REM"] = str(rem5)
                    if prim.get("resets_at"):
                        vals["CODEX_5H_RESET"] = fmt_dt_short(datetime.fromtimestamp(int(prim["resets_at"])), is_weekly=False)
                        vals["CODEX_5H_RESET_EPOCH"] = str(int(prim["resets_at"]))
                if sec.get("used_percent") is not None:
                    rem7 = max(0, min(100, int(round(100.0 - float(sec["used_percent"])))))
                    vals["CODEX_7D_REM"] = str(rem7)
                    if sec.get("resets_at"):
                        vals["CODEX_7D_RESET"] = fmt_dt_short(datetime.fromtimestamp(int(sec["resets_at"])), is_weekly=True)
                        vals["CODEX_7D_RESET_EPOCH"] = str(int(sec["resets_at"]))
                pt = rl.get("plan_type")
                if pt:
                    vals["CODEX_PLAN"] = str(pt).capitalize()
                found_rl = True
                codex_ok = True
                break
        if found_rl:
            break
except Exception:
    pass
if has_codex:
    vals["CODEX_FETCH_OK"] = "1" if codex_ok else "0"
    if codex_ok:
        vals["CODEX_FETCHED_AT"] = NOW_HM
else:
    vals["CODEX_FETCH_OK"] = "-"

# 3. แยกวิเคราะห์ผลลัพธ์จาก claude get_usage
claude_ok = False
if raw_claude:
    try:
        for line in raw_claude.splitlines():
            if '"control_response"' in line and '"rate_limits"' in line:
                obj = json.loads(line)
                resp = ((obj.get("response") or {}).get("response")) or {}
                st = resp.get("subscription_type")
                if st:
                    vals["CLAUDE_PLAN"] = str(st).capitalize()
                rl = resp.get("rate_limits")
                if isinstance(rl, dict):
                    fh = rl.get("five_hour") or {}
                    sd = rl.get("seven_day") or {}
                    if fh.get("utilization") is not None:
                        rem5 = max(0, min(100, int(round(100.0 - float(fh["utilization"])))))
                        vals["CLAUDE_5H_REM"] = str(rem5)
                        if fh.get("resets_at"):
                            dt5 = datetime.fromisoformat(str(fh["resets_at"]).replace("Z", "+00:00")).astimezone()
                            vals["CLAUDE_5H_RESET"] = fmt_dt_short(dt5, is_weekly=False)
                            vals["CLAUDE_5H_RESET_EPOCH"] = to_epoch(dt5)
                        else:
                            vals["CLAUDE_5H_RESET"] = "พร้อมใช้"
                            vals["CLAUDE_5H_RESET_EPOCH"] = "-"
                    if sd.get("utilization") is not None:
                        rem7 = max(0, min(100, int(round(100.0 - float(sd["utilization"])))))
                        vals["CLAUDE_7D_REM"] = str(rem7)
                        if sd.get("resets_at"):
                            dt7 = datetime.fromisoformat(str(sd["resets_at"]).replace("Z", "+00:00")).astimezone()
                            vals["CLAUDE_7D_RESET"] = fmt_dt_short(dt7, is_weekly=True)
                            vals["CLAUDE_7D_RESET_EPOCH"] = to_epoch(dt7)
                claude_ok = True
                break
    except Exception:
        pass

if has_claude:
    vals["CLAUDE_FETCH_OK"] = "1" if claude_ok else "0"
    if claude_ok:
        vals["CLAUDE_FETCHED_AT"] = NOW_HM
else:
    vals["CLAUDE_FETCH_OK"] = "-"

with open(cache_file, "w", encoding="utf-8") as f:
    for k, v in vals.items():
        f.write(f'{k}="{v}"\n')
PYEOF
  fi

  if [ -f "$QUOTA_CACHE_FILE" ]; then
    # shellcheck disable=SC1090
    source "$QUOTA_CACHE_FILE"
  fi
}

update_codex_quota_fast() {
  if ! command -v python3 >/dev/null 2>&1; then
    return 0
  fi
  local cx_out
  cx_out="$(python3 -c '
import os, glob, json
from datetime import datetime
TH_MONTHS = ["", "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
files = sorted(glob.glob(os.path.expanduser("~/.codex/sessions/*/*/*/rollout-*.jsonl")))
for cf in reversed(files[-5:]):
    for line in reversed(open(cf, encoding="utf-8", errors="ignore").readlines()):
        if "\"rate_limits\"" in line and "\"token_count\"" in line:
            rl = (json.loads(line).get("payload") or {}).get("rate_limits") or {}
            p, s = rl.get("primary") or {}, rl.get("secondary") or {}
            r5 = max(0, min(100, int(round(100.0 - float(p.get("used_percent", 0))))))
            r7 = max(0, min(100, int(round(100.0 - float(s.get("used_percent", 0))))))
            dt5 = datetime.fromtimestamp(int(p["resets_at"])).strftime("%H:%M") if p.get("resets_at") else "-"
            dt7_o = datetime.fromtimestamp(int(s["resets_at"])) if s.get("resets_at") else None
            dt7 = f"{dt7_o.day:02d} {TH_MONTHS[dt7_o.month]} {dt7_o.strftime(\"%H:%M\")}" if dt7_o else "-"
            pt = str(rl.get("plan_type") or "plus").capitalize()
            e5 = str(int(p["resets_at"])) if p.get("resets_at") else "-"
            e7 = str(int(s["resets_at"])) if s.get("resets_at") else "-"
            print(f"{pt}|{r5}|{dt5}|{r7}|{dt7}|{e5}|{e7}")
            raise SystemExit(0)
' 2>/dev/null || true)"
  if [ -n "$cx_out" ]; then
    IFS='|' read -r CODEX_PLAN CODEX_5H_REM CODEX_5H_RESET CODEX_7D_REM CODEX_7D_RESET CODEX_5H_RESET_EPOCH CODEX_7D_RESET_EPOCH <<<"$cx_out"
    CODEX_FETCH_OK="1"
  fi
}

load_quota_cache() {
  local now_ts
  now_ts="$(date +%s)"
  if [ -f "$QUOTA_CACHE_FILE" ]; then
    # shellcheck disable=SC1090
    source "$QUOTA_CACHE_FILE"
  fi
  update_codex_quota_fast
  local age=$((now_ts - ${QUOTA_UPDATED_EPOCH:-0}))
  if [ "${SUBCOMMAND:-hub}" != "quota" ] && [ "${SUBCOMMAND:-hub}" != "usage" ]; then
    if [ ! -f "$QUOTA_CACHE_FILE" ] || [ "$age" -gt 180 ] || [ "${AGY_GEMINI_5H_REM:--}" = "-" ]; then
      ( refresh_quota_cache --quiet </dev/null >/dev/null 2>&1 & )
    fi
  fi
}

format_quota_pct_color() {
  local pct="$1"
  if [[ ! "$pct" =~ ^[0-9]+$ ]]; then
    printf "%s—%s" "$C_MUTED" "$C_RESET"
  elif [ "$pct" -ge 50 ]; then
    printf "%s● %s%%%s" "$C_OK" "$pct" "$C_RESET"
  elif [ "$pct" -ge 20 ]; then
    printf "%s▲ %s%%%s" "$C_WARN" "$pct" "$C_RESET"
  else
    printf "%s▲ %s%% (ใกล้หมด)%s" "$C_ERR" "$pct" "$C_RESET"
  fi
}

format_quota_bar() {
  local pct="$1"
  if [[ ! "$pct" =~ ^[0-9]+$ ]]; then
    printf "%s[░░░░░░░░░░]   —%s" "$C_MUTED" "$C_RESET"
    return
  fi
  local filled=$(( (pct + 5) / 10 ))
  [ "$filled" -gt 10 ] && filled=10
  [ "$filled" -lt 0 ] && filled=0
  local empty=$((10 - filled))
  local bar=""
  local i=0
  while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$((i + 1)); done
  i=0
  while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$((i + 1)); done

  local col="$C_OK"
  if [ "$pct" -lt 20 ]; then
    col="$C_ERR"
  elif [ "$pct" -lt 50 ]; then
    col="$C_WARN"
  fi
  printf "%s[%s] %3d%%%s" "$col" "$bar" "$pct" "$C_RESET"
}

# ─── นับถอยหลังเวลารีเซ็ตโควต้า (คำนวณตอนวาดหน้าจอทุกครั้ง จึงเดินถูกเสมอแม้แคชจะเก่า) ───
RENDER_NOW=""
now_epoch() {
  if [ -n "$RENDER_NOW" ]; then
    echo "$RENDER_NOW"
  else
    date +%s
  fi
}

format_countdown() {
  local ep="$1"
  [[ "$ep" =~ ^[0-9]+$ ]] || return 0
  local diff=$(( ep - $(now_epoch) ))
  if [ "$diff" -le 0 ]; then
    printf "↻ รีเซ็ตแล้ว"
    return 0
  fi
  local d=$(( diff / 86400 ))
  local h=$(( (diff % 86400) / 3600 ))
  local m=$(( (diff % 3600) / 60 ))
  if [ "$d" -gt 0 ]; then
    printf "อีก %dวัน %dชม." "$d" "$h"
  elif [ "$h" -gt 0 ]; then
    printf "อีก %dชม.%02dน." "$h" "$m"
  else
    [ "$m" -lt 1 ] && m=1
    printf "อีก %dน." "$m"
  fi
}

# เมื่อเลยเวลารีเซ็ตแล้ว โควต้ารอบนั้นกลับมาเต็ม 100% (ใช้ทั้งการแสดงผลและ Quota Circuit Breaker)
effective_quota_pct() {
  local pct="$1"
  local ep="$2"
  if [[ "$ep" =~ ^[0-9]+$ ]] && [ "$ep" -le "$(now_epoch)" ]; then
    echo "100"
  else
    echo "$pct"
  fi
}

format_reset_detail() {
  local ep="$1"
  local txt="$2"
  local cd
  cd="$(format_countdown "$ep")"
  if [ -z "$cd" ]; then
    case "$txt" in
      ""|"-") printf "-" ;;
      "พร้อมใช้") printf "ยังไม่เริ่มนับรอบ" ;;
      *) printf "รีเซ็ต %s" "$txt" ;;
    esac
  elif [ "$cd" = "↻ รีเซ็ตแล้ว" ]; then
    printf "↻ รีเซ็ตแล้ว — กด [u] เพื่อดึงค่าล่าสุด"
  else
    printf "รีเซ็ตใน%s • %s" "${cd#อีก}" "$txt"
  fi
}

# ตารางโควต้า 3 คอลัมน์ (ค่าย / 5 ชั่วโมง / รายสัปดาห์) — ใช้ Python คำนวณความกว้างตัวอักษรไทย
# (สระบน/ล่างและวรรณยุกต์ไม่กินพื้นที่) เพื่อให้คอลัมน์ตรงแนว
render_quota_table() {
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$(now_epoch)" "${QUOTA_UPDATED_EPOCH:-0}" "${QUOTA_UPDATED_AT:--}" \
    "$C_OK" "$C_WARN" "$C_ERR" "$C_MUTED" "$C_ACCENT" "$C_RESET" "$C_BOLD" \
    "agy (Gemini)" "$AGY_GEMINI_5H_REM" "$AGY_GEMINI_5H_RESET_EPOCH" "$AGY_GEMINI_5H_RESET" "$AGY_GEMINI_7D_REM" "$AGY_GEMINI_7D_RESET_EPOCH" "$AGY_GEMINI_7D_RESET" "$AGY_FETCH_OK" "$AGY_FETCHED_AT" \
    "agy (Claude/GPT)" "$AGY_CLAUDE_5H_REM" "$AGY_CLAUDE_5H_RESET_EPOCH" "$AGY_CLAUDE_5H_RESET" "$AGY_CLAUDE_7D_REM" "$AGY_CLAUDE_7D_RESET_EPOCH" "$AGY_CLAUDE_7D_RESET" "$AGY_FETCH_OK" "$AGY_FETCHED_AT" \
    "codex (${CODEX_PLAN:-Plus})" "$CODEX_5H_REM" "$CODEX_5H_RESET_EPOCH" "$CODEX_5H_RESET" "$CODEX_7D_REM" "$CODEX_7D_RESET_EPOCH" "$CODEX_7D_RESET" "$CODEX_FETCH_OK" "$CODEX_FETCHED_AT" \
    "claude (${CLAUDE_PLAN:-Pro})" "$CLAUDE_5H_REM" "$CLAUDE_5H_RESET_EPOCH" "$CLAUDE_5H_RESET" "$CLAUDE_7D_REM" "$CLAUDE_7D_RESET_EPOCH" "$CLAUDE_7D_RESET" "$CLAUDE_FETCH_OK" "$CLAUDE_FETCHED_AT" \
    <<'PYEOF'
import sys, unicodedata

a = sys.argv[1:]
now = int(a[0])
upd, upd_at = a[1], a[2]
OK, WARN, ERR, MUTED, ACC, RST, BOLD = a[3:10]
rest = a[10:]
rows = [rest[i:i + 9] for i in range(0, len(rest), 9)]

def width(s):
    n = 0
    for c in s:
        if unicodedata.combining(c) or unicodedata.category(c) in ("Mn", "Me", "Cf"):
            continue
        n += 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1
    return n

def pad(s, w):
    return s + " " * max(0, w - width(s))

def countdown(diff):
    d, r = divmod(diff, 86400)
    h, r = divmod(r, 3600)
    m = r // 60
    if d > 0:
        return f"อีก {d}วัน {h}ชม."
    if h > 0:
        return f"อีก {h}ชม.{m:02d}น."
    return f"อีก {max(1, m)}น."

def cell(p, e, t, stale=False, at="-", first=False):
    has_ep = e.isdigit()
    passed = has_ep and int(e) <= now
    if passed:
        pv = 100
    elif p.isdigit():
        pv = int(p)
    else:
        return MUTED + "—" + RST, "—"
    if stale:
        head = pad(f"? {pv}%", 6)
        tail = ("ดึงไม่ได้ • ค่าเมื่อ " + at) if (first and at not in ("", "-")) else ("ดึงไม่ได้" if first else "")
        if not first and has_ep and not passed:
            tail = countdown(int(e) - now)
        return MUTED + head + " " + tail + RST, head + " " + tail
    col = OK if pv >= 50 else (WARN if pv >= 20 else ERR)
    head = pad(("●" if pv >= 50 else "▲") + f" {pv}%", 6)
    if passed:
        tail = "↻ รีเซ็ตแล้ว"
    elif has_ep:
        tail = countdown(int(e) - now) + (f" ({t})" if t not in ("", "-") else "")
    elif t == "พร้อมใช้":
        tail = "ยังไม่เริ่มนับรอบ"
    else:
        tail = f"รีเซ็ต {t}" if t not in ("", "-") else ""
    return col + head + RST + " " + MUTED + tail + RST, head + " " + tail

# หัวกล่อง: อายุข้อมูล
age = None
if upd.isdigit() and int(upd) > 0:
    age = max(0, now - int(upd))
if age is None:
    age_s = "ยังไม่มีข้อมูล"
elif age < 60:
    age_s = "เมื่อสักครู่"
elif age < 3600:
    age_s = f"{age // 60} นาทีที่แล้ว"
elif age < 86400:
    age_s = f"{age // 3600} ชม. ที่แล้ว"
else:
    age_s = f"{age // 86400} วันที่แล้ว"
stale = age is None or age > 900
note = (WARN + f"▲ อัปเดต {upd_at} ({age_s}) — ข้อมูลอาจไม่ตรง กด [u] ดึงข้อมูลสด" + RST) if stale \
    else (MUTED + f"อัปเดต {upd_at} ({age_s}) • กด [u] ดึงข้อมูลสด" + RST)
print(f"{ACC}│{RST} {BOLD}โควต้าคงเหลือ (Real-Time Quota){RST}  {note}")

cells = [(r[0], cell(r[1], r[2], r[3], r[7] == "0", r[8], True), cell(r[4], r[5], r[6], r[7] == "0", r[8], False)) for r in rows]
h_name, h5, h7 = "ค่าย / กระเป๋า", "5 ชั่วโมง", "รายสัปดาห์"
nw = max([width(h_name)] + [width(n) for n, _, _ in cells])
w5 = max([width(h5)] + [width(c5[1]) for _, c5, _ in cells])
print(f"{ACC}│{RST}  {MUTED}{pad(h_name, nw)}  {pad(h5, w5)}  {h7}{RST}")
for name, c5, c7 in cells:
    print(f"{ACC}│{RST}  {pad(name, nw)}  {c5[0]}{' ' * max(0, w5 - width(c5[1]))}  {c7[0]}")
PYEOF
}

get_role_quota_pair() {
  local provider="$1"
  local model="$2"
  local q5="-" q7="-"
  case "$provider" in
    agy)
      if [[ "$model" == claude-* ]] || [[ "$model" == gpt-* ]]; then
        q5="$(effective_quota_pct "$AGY_CLAUDE_5H_REM" "$AGY_CLAUDE_5H_RESET_EPOCH")"
        q7="$(effective_quota_pct "$AGY_CLAUDE_7D_REM" "$AGY_CLAUDE_7D_RESET_EPOCH")"
      else
        q5="$(effective_quota_pct "$AGY_GEMINI_5H_REM" "$AGY_GEMINI_5H_RESET_EPOCH")"
        q7="$(effective_quota_pct "$AGY_GEMINI_7D_REM" "$AGY_GEMINI_7D_RESET_EPOCH")"
      fi
      ;;
    codex)
      q5="$(effective_quota_pct "$CODEX_5H_REM" "$CODEX_5H_RESET_EPOCH")"
      q7="$(effective_quota_pct "$CODEX_7D_REM" "$CODEX_7D_RESET_EPOCH")"
      ;;
    claude)
      q5="$(effective_quota_pct "$CLAUDE_5H_REM" "$CLAUDE_5H_RESET_EPOCH")"
      q7="$(effective_quota_pct "$CLAUDE_7D_REM" "$CLAUDE_7D_RESET_EPOCH")"
      ;;
  esac
  printf "%s|%s" "$q5" "$q7"
}

format_role_status_cell() {
  local provider="$1"
  local model="$2"
  if ! is_provider_installed "$provider"; then
    printf "%s✖ ยังไม่ติดตั้ง CLI (กด [3])%s" "$C_ERR" "$C_RESET"
    return
  elif ! is_provider_logged_in "$provider"; then
    printf "%s▲ ยังไม่ Login บัญชี (กด [3])%s" "$C_WARN" "$C_RESET"
    return
  elif ! is_model_explicitly_set "$model"; then
    printf "%s▲ รอเลือกโมเดล (กด [1]/[2])%s" "$C_WARN" "$C_RESET"
    return
  fi

  local qpair q5 q7
  qpair="$(get_role_quota_pair "$provider" "$model")"
  q5="${qpair%%|*}"
  q7="${qpair#*|}"

  if [[ "$q5" =~ ^[0-9]+$ ]] && [[ "$q7" =~ ^[0-9]+$ ]]; then
    local min_q="$q5"
    [ "$q7" -lt "$min_q" ] && min_q="$q7"
    if [ "$min_q" -lt 20 ]; then
      printf "%s▲ พร้อมใช้ • โควต้าต่ำ (เหลือ %s%%)%s" "$C_WARN" "$min_q" "$C_RESET"
    else
      printf "%s● พร้อมใช้%s" "$C_OK" "$C_RESET"
    fi
  elif [ "$provider" = "agy" ]; then
    printf "%s● พร้อมใช้งาน (Google AI Ultra)%s" "$C_OK" "$C_RESET"
  else
    printf "%s● พร้อมใช้งาน (Login แล้ว)%s" "$C_OK" "$C_RESET"
  fi
}

check_role_quota_safe() {
  local provider="$1"
  local model="$2"
  local role_label="$3"
  local min_pct="${4:-20}"

  update_codex_quota_fast
  local qpair q5 q7
  qpair="$(get_role_quota_pair "$provider" "$model")"
  q5="${qpair%%|*}"
  q7="${qpair#*|}"

  local fetch_ok="-" fetched_at="-"
  case "$provider" in
    agy)    fetch_ok="$AGY_FETCH_OK";    fetched_at="$AGY_FETCHED_AT" ;;
    codex)  fetch_ok="$CODEX_FETCH_OK";  fetched_at="$CODEX_FETCHED_AT" ;;
    claude) fetch_ok="$CLAUDE_FETCH_OK"; fetched_at="$CLAUDE_FETCHED_AT" ;;
  esac
  if [ "$fetch_ok" = "0" ]; then
    printf "%s▲ ดึงโควต้าสดของ %s ไม่สำเร็จ — ใช้ค่าล่าสุดเมื่อ %s ในการตัดสิน%s\n" "$C_WARN" "$provider" "$fetched_at" "$C_RESET"
  fi

  local low_flag=0
  if [[ "$q5" =~ ^[0-9]+$ ]] && [ "$q5" -lt "$min_pct" ]; then low_flag=1; fi
  if [[ "$q7" =~ ^[0-9]+$ ]] && [ "$q7" -lt "$min_pct" ]; then low_flag=1; fi

  if [ "$low_flag" -eq 1 ]; then
    echo ""
    printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ERR" "$C_RESET"
    printf "%s│%s %s🛑 [Quota Circuit Breaker] หยุดลูปอัตโนมัติเพื่อปกป้องโควต้าของคุณ!%s\n" "$C_ERR" "$C_RESET" "$C_BOLD" "$C_RESET"
    printf "%s│%s  • ตำแหน่ง : %s (%s / %s)\n" "$C_ERR" "$C_RESET" "$role_label" "$provider" "$model"
    printf "%s│%s  • โควต้าคงเหลือปัจจุบัน : 5 ชม. เหลือ %s%% │ รายสัปดาห์ เหลือ %s%% (ต่ำกว่าเกณฑ์ปลอดภัย %s%%)\n" "$C_ERR" "$C_RESET" "$q5" "$q7" "$min_pct"
    printf "%s│%s  • คำแนะนำ : กด [c] เพื่อสลับตำแหน่งนี้ไปใช้ค่ายอื่นที่ยังมีโควต้าเหลือเยอะ แล้วสั่งรันลูปต่อได้ทันที\n" "$C_ERR" "$C_RESET"
    printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ERR" "$C_RESET"
    return 1
  fi
  return 0
}

get_learned_skills_count() {
  local skill_file="$RELAY_DIR/skills/project-learned/SKILL.md"
  if [ ! -f "$skill_file" ]; then
    echo "0"
    return
  fi
  local cnt
  cnt="$(grep -cE '^[[:space:]]*-[[:space:]]+' "$skill_file" 2>/dev/null || echo "0")"
  echo "${cnt:-0}"
}

get_learned_skills_prompt_note() {
  local skill_file="$RELAY_DIR/skills/project-learned/SKILL.md"
  if [ -f "$skill_file" ]; then
    printf " และกรุณาอ่านไฟล์บทเรียนสะสมเฉพาะโครงการที่ .relay/skills/project-learned/SKILL.md เพื่อปฏิบัติตามกฎและข้อควรระวังที่ได้เรียนรู้จากใบงานก่อนหน้าอย่างเคร่งครัด"
  fi
}

format_cli_summary_badge() {
  local provider="$1"
  local label="$provider"
  [ "$provider" = "agy" ] && label="agy (Google AI Ultra)"
  if ! is_provider_installed "$provider"; then
    printf "%s○ %s (ยังไม่ติดตั้ง)%s" "$C_ERR" "$label" "$C_RESET"
  elif ! is_provider_logged_in "$provider"; then
    printf "%s▲ %s (ยังไม่ Login)%s" "$C_WARN" "$label" "$C_RESET"
  else
    printf "%s● %s (Login แล้ว)%s" "$C_OK" "$label" "$C_RESET"
  fi
}

format_role_model_text() {
  local provider="$1"
  local model="$2"
  if is_model_explicitly_set "$model"; then
    printf "%-22s" "$model"
  else
    local cli_def
    cli_def="$(get_cli_default_model "$provider")"
    printf "%-22s" "ยังไม่เลือก ($cli_def)"
  fi
}

get_active_task() {
  refresh_project_paths
  if [ ! -d "$RELAY_DIR/tasks" ]; then
    ACTIVE_TASK=""
    return
  fi
  if [ -n "$CURRENT_TASK" ] && [ -d "$RELAY_DIR/tasks/$CURRENT_TASK" ]; then
    ACTIVE_TASK="$CURRENT_TASK"
    return
  fi
  ACTIVE_TASK="$(ls -1 "$RELAY_DIR/tasks" 2>/dev/null | grep -v '^\.' | tail -n 1 || true)"
}

# คำนวณว่าตอนนี้อยู่ในขั้นที่เท่าไรจาก 3 ขั้นตอนหลัก (Stage 1 / Stage 2 / Stage 3)
UX_STAGE=1
IN_HOME_DIR=0
HAS_PROJECT_STATE=0
RECOMMENDED_STEP=1
STAGE3_FOCUS_TEXT=""

determine_ux_stage() {
  check_all_roles_ready
  get_active_task

  if [ "$PROJECT_DIR" = "$HOME" ]; then
    IN_HOME_DIR=1
  else
    IN_HOME_DIR=0
  fi

  if [ "$IN_HOME_DIR" -eq 0 ] && [ -f "$RELAY_DIR/PROJECT_STATE.md" ]; then
    HAS_PROJECT_STATE=1
  else
    HAS_PROJECT_STATE=0
  fi

  if [ "$ALL_ROLES_READY" -eq 0 ]; then
    UX_STAGE=1
  elif [ "$IN_HOME_DIR" -eq 1 ] || [ "$HAS_PROJECT_STATE" -eq 0 ]; then
    UX_STAGE=2
  else
    UX_STAGE=3
    compute_stage3_next_step
  fi
}

compute_stage3_next_step() {
  if [ -z "$ACTIVE_TASK" ] || [ ! -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ]; then
    RECOMMENDED_STEP=1
    STAGE3_FOCUS_TEXT="กด Enter ที่ข้อ [1] เพื่อให้ @po ซักถามความต้องการและสร้างเอกสาร SPEC.md"
  elif [ ! -f "$RELAY_DIR/tasks/$ACTIVE_TASK/PLAN.md" ]; then
    RECOMMENDED_STEP=2
    STAGE3_FOCUS_TEXT="มี SPEC.md แล้ว — กด [2] ให้ @arch วางแผน หรือกด [a] ⚡ รัน Auto-Relay Loop (2➔3⇄4) อัตโนมัติ"
  elif [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_REPORT.md" ] || [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_VERDICT.json" ]; then
    local s3v
    s3v="$(qa_verdict "$RELAY_DIR/tasks/$ACTIVE_TASK")"
    if [ "${s3v%%|*}" = "PASS" ]; then
      RECOMMENDED_STEP=5
      STAGE3_FOCUS_TEXT="@qa ตรวจรับผ่านแล้ว (PASS) — กด Enter ที่ข้อ [5] เพื่อผสานโค้ดเข้า main สกัดบทเรียน และปิดใบงาน"
    else
      RECOMMENDED_STEP=3
      STAGE3_FOCUS_TEXT="ผลตรวจรับล่าสุดยังไม่ผ่าน (${s3v%%|*}) — ดู QA_REPORT.md แล้วกด [3] ให้ @dev แก้ไข หรือกด [a] รันลูปแก้ไขอัตโนมัติ"
    fi
  elif [ ! -d "$RELAY_DIR/worktrees/$ACTIVE_TASK" ] && [ "${LAST_COMPLETED_PHASE:-0}" -lt 3 ]; then
    RECOMMENDED_STEP=3
    STAGE3_FOCUS_TEXT="มี PLAN.md แล้ว — กด [3] ให้ @dev เขียนโค้ด หรือกด [a] ⚡ รัน Auto-Relay Loop (3⇄4) อัตโนมัติ"
  else
    RECOMMENDED_STEP=4
    STAGE3_FOCUS_TEXT="เขียนโค้ดใน Worktree แล้ว — กด [4] ให้ @qa/@sec ตรวจรับงาน หรือกด [a] ⚡ รันลูปตรวจและแก้ไขอัตโนมัติ"
  fi
}

# ─── 3. Interactive Arrow-Key Menu (สไตล์ Claude Code: ❯ + สีน้ำเงินครามตัวหนาทั้งบรรทัด) ───
MENU_RESULT=""
interactive_menu() {
  local title="$1"
  local default_sel="${2:-0}"
  shift 2
  local items=("$@")
  local count="${#items[@]}"
  local selected="$default_sel"
  if [ "$selected" -ge "$count" ] || [ "$selected" -lt 0 ]; then
    selected=0
  fi

  if [ ! -t 0 ]; then
    printf "\n%s%s%s\n" "$C_BOLD" "$title" "$C_RESET"
    local idx=0
    while [ "$idx" -lt "$count" ]; do
      local entry="${items[$idx]}"
      local key="${entry%%|*}"
      local label="${entry#*|}"
      printf "  [%s] %s\n" "$key" "$label"
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
  printf "%sใช้ปุ่มลูกศร ↑/↓ เลื่อนเลือก • กด Enter ยืนยัน • หรือกดคีย์ลัด [...] ได้ทันที%s\n" "$C_MUTED" "$C_RESET"

  tput civis 2>/dev/null || true
  trap 'tput cnorm 2>/dev/null || true' EXIT INT TERM

  local first_draw=1
  while true; do
    if [ "$first_draw" -eq 0 ]; then
      printf "\033[%dA\r" "$((count + 3))"
    fi
    first_draw=0

    local i=0
    while [ "$i" -lt "$count" ]; do
      local entry="${items[$i]}"
      local key="${entry%%|*}"
      local label="${entry#*|}"

      printf "\033[2K\r"
      if [ "$i" -eq "$selected" ]; then
        printf "  %s❯ [%s] %s%s\n" "$C_SEL" "$key" "$label" "$C_RESET"
      else
        printf "    %s[%s]%s %s\n" "$C_ACCENT" "$key" "$C_RESET" "$label"
      fi
      i=$((i + 1))
    done

    local cur_key="${items[$selected]%%|*}"
    printf "\033[2K\r%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
    printf "\033[2K\r%s│%s %s❯%s คำสั่งที่เลือก: %s[%s]%s  %s(↑/↓ เลื่อน • Enter ยืนยัน • กด / พิมพ์ /model, /connect, /test)%s\n" "$C_ACCENT" "$C_RESET" "$C_SEL" "$C_RESET" "$C_SEL" "$cur_key" "$C_RESET" "$C_MUTED" "$C_RESET"
    printf "\033[2K\r%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

    local k1=""
    IFS= read -rsn1 k1 || true

    if [ -z "$k1" ]; then
      MENU_RESULT="${items[$selected]%%|*}"
      break
    fi

    if [ "$k1" = $'\x1b' ]; then
      local k23=""
      IFS= read -rsn2 -t 1 k23 2>/dev/null || true
      case "$k23" in
        "[A"|"OA")
          selected=$(((selected - 1 + count) % count))
          continue
          ;;
        "[B"|"OB")
          selected=$(((selected + 1) % count))
          continue
          ;;
        *)
          continue
          ;;
      esac
    fi

    if [ "$k1" = "/" ]; then
      tput cnorm 2>/dev/null || true
      printf "\033[2A\033[2K\r%s│%s %s❯ /%s" "$C_ACCENT" "$C_RESET" "$C_SEL" "$C_RESET"
      local slash_cmd=""
      read -r slash_cmd || true
      printf "\n\n"
      MENU_RESULT="/${slash_cmd}"
      return 0
    fi

    local lower_k1
    lower_k1="$(printf "%s" "$k1" | tr '[:upper:]' '[:lower:]')"
    local match_idx=0
    while [ "$match_idx" -lt "$count" ]; do
      local item_key="${items[$match_idx]%%|*}"
      local lower_item_key
      lower_item_key="$(printf "%s" "$item_key" | tr '[:upper:]' '[:lower:]')"
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

# ─── 4. แสดงหัวกระดาษพร้อมแถบนำทาง 3 ขั้นตอน (3-Stage Progress Stepper) ──────
print_dashboard_header() {
  if [ -t 1 ] && [ "${SUBCOMMAND:-hub}" = "hub" ]; then
    printf "\033[H\033[2J"
  fi
  RENDER_NOW="$(date +%s)"

  determine_ux_stage

  local git_branch="no-git"
  if [ -d "$PROJECT_DIR/.git" ]; then
    git_branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
  fi

  local state_badge="${C_WARN}○ ยังไม่มี PROJECT_STATE.md${C_RESET}"
  [ -f "$RELAY_DIR/PROJECT_STATE.md" ] && state_badge="${C_OK}● PROJECT_STATE.md พร้อมใช้งาน${C_RESET}"

  local learned_cnt
  learned_cnt="$(get_learned_skills_count)"
  local learned_pending
  learned_pending="$(get_learned_pending_count)"
  local learned_badge="${C_MUTED}○ Learned Skills (รอสกัดเมื่อปิดใบงาน [5]/[l])${C_RESET}"
  if [ "${learned_cnt:-0}" -gt 0 ]; then
    learned_badge="${C_OK}● Learned Skills (${learned_cnt} กฎ)${C_RESET}"
  fi
  if [ "${learned_pending:-0}" -gt 0 ]; then
    learned_badge="${learned_badge} ${C_WARN}▲ ${learned_pending} รออนุมัติ [l]${C_RESET}"
  fi

  local spec_m="${C_MUTED}[ ] SPEC.md${C_RESET}"
  local plan_m="${C_MUTED}[ ] ARCH & PLAN${C_RESET}"
  local qa_m="${C_MUTED}[ ] QA_REPORT.md${C_RESET}"
  if [ -n "$ACTIVE_TASK" ]; then
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ] && spec_m="${C_OK}[✓] SPEC.md${C_RESET}"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/PLAN.md" ] && plan_m="${C_OK}[✓] ARCH & PLAN${C_RESET}"
    if [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_REPORT.md" ] || [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_VERDICT.json" ]; then
      local hv
      hv="$(qa_verdict "$RELAY_DIR/tasks/$ACTIVE_TASK")"
      if [ "${hv%%|*}" = "PASS" ]; then
        qa_m="${C_OK}[✓] QA PASS${C_RESET}"
      else
        qa_m="${C_WARN}[✗] QA ยังไม่ผ่าน (${hv%%|*})${C_RESET}"
      fi
    fi
  fi

  local agy_b codex_b claude_b
  agy_b="$(format_cli_summary_badge "agy")"
  codex_b="$(format_cli_summary_badge "codex")"
  claude_b="$(format_cli_summary_badge "claude")"

  local m_po m_arch m_dev m_qa
  m_po="$(format_role_model_text "$ROLE_PO" "$MODEL_PO")"
  m_arch="$(format_role_model_text "$ROLE_ARCH" "$MODEL_ARCH")"
  m_dev="$(format_role_model_text "$ROLE_DEV" "$MODEL_DEV")"
  m_qa="$(format_role_model_text "$ROLE_QA" "$MODEL_QA")"

  local s_po s_arch s_dev s_qa
  s_po="$(format_role_status_cell "$ROLE_PO" "$MODEL_PO")"
  s_arch="$(format_role_status_cell "$ROLE_ARCH" "$MODEL_ARCH")"
  s_dev="$(format_role_status_cell "$ROLE_DEV" "$MODEL_DEV")"
  s_qa="$(format_role_status_cell "$ROLE_QA" "$MODEL_QA")"

  # แถบ 3-Stage Stepper บอกตำแหน่งปัจจุบัน
  local step1_badge step2_badge step3_badge
  if [ "$UX_STAGE" -eq 1 ]; then
    step1_badge="${C_SEL}● [ขั้นที่ 1: ตั้งค่า & Login AI (${READY_ROLE_COUNT}/4)]${C_RESET}"
    step2_badge="${C_MUTED}○ ขั้นที่ 2: เตรียมโปรเจกต์${C_RESET}"
    step3_badge="${C_MUTED}○ ขั้นที่ 3: เริ่มสั่งงาน${C_RESET}"
  elif [ "$UX_STAGE" -eq 2 ]; then
    step1_badge="${C_OK}✓ ขั้นที่ 1: ตั้งค่า & Login AI (4/4)${C_RESET}"
    step2_badge="${C_SEL}● [ขั้นที่ 2: เตรียมโปรเจกต์]${C_RESET}"
    step3_badge="${C_MUTED}○ ขั้นที่ 3: เริ่มสั่งงาน${C_RESET}"
  else
    step1_badge="${C_OK}✓ ขั้นที่ 1: ตั้งค่า & Login AI (4/4)${C_RESET}"
    step2_badge="${C_OK}✓ ขั้นที่ 2: เตรียมโปรเจกต์${C_RESET}"
    step3_badge="${C_SEL}● [ขั้นที่ 3: เริ่มสั่งงาน]${C_RESET}"
  fi

  # โลโก้ 3D โทนสีเดียวสะอาดตา (Monochrome Cerulean Blue + Slate Shadow)
  printf " %s██%s╗      %s██████%s╗  %s███████%s╗ %s██%s╗       %s█████%s╗  %s██%s╗   %s██%s╗\n" \
    "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH"
  printf " %s╚%s██%s╗     %s██%s╔══%s██%s╗ %s██%s╔════╝ %s██%s║      %s██%s╔══%s██%s╗ %s╚%s██%s╗ %s██%s╔╝\n" \
    "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH"
  printf "  %s╚%s██%s╗    %s██████%s╔╝ %s█████%s╗   %s██%s║      %s███████%s║  %s╚%s████%s╔╝ %s\n" \
    "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_RESET"
  printf "  %s██%s╔╝    %s██%s╔══%s██%s╗ %s██%s╔══╝   %s██%s║      %s██%s╔══%s██%s║   %s╚%s██%s╔╝  %s\n" \
    "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_RESET"
  printf " %s██%s╔╝     %s██%s║  %s██%s║ %s███████%s╗ %s███████%s╗ %s██%s║  %s██%s║    %s██%s║   %s\n" \
    "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_ACCENT" "$C_ACCENT_SH" "$C_RESET"
  printf " %s╚═╝      ╚═╝  ╚═╝ ╚══════╝ ╚══════╝ ╚═╝  ╚═╝    ╚═╝%s   %sRELAY v1.0 • Multi-Agent Handoff Hub%s\n" \
    "$C_ACCENT_SH" "$C_RESET" "$C_MUTED" "$C_RESET"

  # กรอบข้อมูลแบบ Open-Right พร้อมแถบนำทาง 3 ขั้นตอนด้านบนสุด
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %sลำดับงาน :%s %b %s──➔%s %b %s──➔%s %b\n" \
    "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET" "$step1_badge" "$C_MUTED" "$C_RESET" "$step2_badge" "$C_MUTED" "$C_RESET" "$step3_badge"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %sตำแหน่ง (Roles)       ค่าย      โมเดลปัจจุบัน (จาก CLI)     สถานะความพร้อมจริง%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s 1. @po (Product)    ➔ %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_PO" "$m_po" "$s_po"
  printf "%s│%s 2. @arch & @pm      ➔ %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_ARCH" "$m_arch" "$s_arch"
  printf "%s│%s 3. @dev (Worktree)  ➔ %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_DEV" "$m_dev" "$s_dev"
  printf "%s│%s 4. @qa & @sec       ➔ %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_QA" "$m_qa" "$s_qa"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %sสถานะ CLI:%s %b   %b   %b\n" \
    "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET" "$agy_b" "$codex_b" "$claude_b"

  # ─── ตารางโควต้าคงเหลือแบบเรียลไทม์ + นับถอยหลังเวลารีเซ็ต (Real-Time Multi-Provider Quota) ───
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  if ! render_quota_table 2>/dev/null; then
    printf "%s│%s %sโควต้าคงเหลือ (Real-Time Quota)%s  %s[อัปเดต %s • กด [u]]%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_MUTED" "${QUOTA_UPDATED_AT:--}" "$C_RESET"
    printf "%s│%s  agy (Gemini)     5ชม. %b %s%s%s │ สัปดาห์ %b %s%s%s\n" "$C_ACCENT" "$C_RESET" \
      "$(format_quota_pct_color "$(effective_quota_pct "$AGY_GEMINI_5H_REM" "$AGY_GEMINI_5H_RESET_EPOCH")")" "$C_MUTED" "$(format_reset_detail "$AGY_GEMINI_5H_RESET_EPOCH" "$AGY_GEMINI_5H_RESET")" "$C_RESET" \
      "$(format_quota_pct_color "$(effective_quota_pct "$AGY_GEMINI_7D_REM" "$AGY_GEMINI_7D_RESET_EPOCH")")" "$C_MUTED" "$(format_reset_detail "$AGY_GEMINI_7D_RESET_EPOCH" "$AGY_GEMINI_7D_RESET")" "$C_RESET"
  fi

  # แสดงข้อมูลโฟลเดอร์โปรเจกต์เฉพาะเมื่อผ่านขั้นที่ 1 แล้ว
  if [ "$UX_STAGE" -ge 2 ]; then
    printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
    if [ "$IN_HOME_DIR" -eq 1 ]; then
      printf "%s│%s โฟลเดอร์ : %s~ (%s)%s  •  %s▲ เป็นโฟลเดอร์ Home ส่วนตัว (ไม่ใช่โฟลเดอร์โปรเจกต์)%s\n" \
        "$C_ACCENT" "$C_RESET" "$C_BOLD" "$PROJECT_DIR" "$C_RESET" "$C_WARN" "$C_RESET"
    else
      printf "%s│%s โครงการ : %s%s%s [%s]  •  %b  •  %b\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$PROJECT_NAME" "$C_RESET" "$git_branch" "$state_badge" "$learned_badge"
    fi

    if [ "$UX_STAGE" -eq 3 ]; then
      if [ -n "$ACTIVE_TASK" ]; then
        printf "%s│%s ใบงาน   : %s%s%s  ➔  %b   %b   %b\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$ACTIVE_TASK" "$C_RESET" "$spec_m" "$plan_m" "$qa_m"
      else
        printf "%s│%s ใบงาน   : %s(ยังไม่มีใบงานที่กำลังดำเนินการ — กด Enter ที่ข้อ [1] เพื่อเริ่มใบงานแรก)%s\n" "$C_ACCENT" "$C_RESET" "$C_MUTED" "$C_RESET"
      fi
    fi
  fi

  # แถบชี้เป้า "สิ่งที่ต้องทำตอนนี้" (Focus Callout)
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  if [ "$UX_STAGE" -eq 1 ]; then
    if [ -n "$UNLOGGED_ACTIVE_PROVIDERS" ] && [ "$MODELS_SET_COUNT" -eq 4 ]; then
      printf "%s│%s %s👉 สิ่งที่ต้องทำตอนนี้ (ขั้นที่ 1/3):%s กดข้อ %s[1]%s เพื่อใช้โควตา Google AI Ultra (agy) ที่ Login แล้ว หรือกด %s[3]%s เพื่อ Login [%s]\n" \
        "$C_ACCENT" "$C_RESET" "$C_SEL" "$C_RESET" "$C_SEL" "$C_RESET" "$C_SEL" "$C_RESET" "$UNLOGGED_ACTIVE_PROVIDERS"
    else
      printf "%s│%s %s👉 สิ่งที่ต้องทำตอนนี้ (ขั้นที่ 1/3):%s ตั้งค่าและ Login AI ให้ครบ 4 ตำแหน่ง (กด Enter ที่ข้อ %s[1]%s เพื่อตั้งค่าด่วน)\n" \
        "$C_ACCENT" "$C_RESET" "$C_SEL" "$C_RESET" "$C_SEL" "$C_RESET"
    fi
  elif [ "$UX_STAGE" -eq 2 ]; then
    if [ "$IN_HOME_DIR" -eq 1 ]; then
      printf "%s│%s %s👉 สิ่งที่ต้องทำตอนนี้ (ขั้นที่ 2/3):%s คุณอยู่ในโฟลเดอร์ Home (~) — กด Enter ที่ข้อ %s[1]%s เพื่อเลือก/สร้างโฟลเดอร์โปรเจกต์\n" \
        "$C_ACCENT" "$C_RESET" "$C_SEL" "$C_RESET" "$C_SEL" "$C_RESET"
    else
      printf "%s│%s %s👉 สิ่งที่ต้องทำตอนนี้ (ขั้นที่ 2/3):%s เตรียมโครงสร้าง .relay/ สำหรับโปรเจกต์ '%s' (กด Enter ที่ข้อ %s[1]%s หรือ %s[2]%s)\n" \
        "$C_ACCENT" "$C_RESET" "$C_SEL" "$C_RESET" "$PROJECT_NAME" "$C_SEL" "$C_RESET" "$C_SEL" "$C_RESET"
    fi
  else
    printf "%s│%s %s👉 ขั้นตอนถัดไปที่แนะนำ (ขั้นที่ 3/3):%s %s\n" \
      "$C_ACCENT" "$C_RESET" "$C_SEL" "$C_RESET" "$STAGE3_FOCUS_TEXT"
  fi
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  RENDER_NOW=""
}

# ─── 4.5 ศูนย์ตรวจสอบโควต้าคงเหลือแบบเรียลไทม์ ([u] / /quota / relay quota) ─────
print_quota_report_box() {
  RENDER_NOW="$(date +%s)"
  local g5 g7 a5 a7 x5 x7 c5 c7
  g5="$(effective_quota_pct "$AGY_GEMINI_5H_REM" "$AGY_GEMINI_5H_RESET_EPOCH")"
  g7="$(effective_quota_pct "$AGY_GEMINI_7D_REM" "$AGY_GEMINI_7D_RESET_EPOCH")"
  a5="$(effective_quota_pct "$AGY_CLAUDE_5H_REM" "$AGY_CLAUDE_5H_RESET_EPOCH")"
  a7="$(effective_quota_pct "$AGY_CLAUDE_7D_REM" "$AGY_CLAUDE_7D_RESET_EPOCH")"
  x5="$(effective_quota_pct "$CODEX_5H_REM" "$CODEX_5H_RESET_EPOCH")"
  x7="$(effective_quota_pct "$CODEX_7D_REM" "$CODEX_7D_RESET_EPOCH")"
  c5="$(effective_quota_pct "$CLAUDE_5H_REM" "$CLAUDE_5H_RESET_EPOCH")"
  c7="$(effective_quota_pct "$CLAUDE_7D_REM" "$CLAUDE_7D_RESET_EPOCH")"

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %sรายงานโควต้าคงเหลือแบบเรียลไทม์ (RELAY Live Multi-Provider Quota Monitor)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s %sอัปเดตล่าสุดเมื่อเวลา: %s  (ดึงข้อมูลสดจาก CLI ทั้ง 3 ค่ายโดยตรง)%s\n" "$C_ACCENT" "$C_RESET" "$C_MUTED" "${QUOTA_UPDATED_AT:--}" "$C_RESET"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s1. Google AI Ultra — กระเป๋า Gemini Models (agy)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  [ "$AGY_FETCH_OK" = "0" ] && printf "%s│%s    %s▲ ดึงข้อมูลสดไม่สำเร็จ — แสดงค่าล่าสุดเมื่อ %s%s\n" "$C_ACCENT" "$C_RESET" "$C_WARN" "$AGY_FETCHED_AT" "$C_RESET"
  printf "%s│%s    • โควต้า 5 ชั่วโมง (5-Hour) : %b   %s(%s)%s\n" "$C_ACCENT" "$C_RESET" "$(format_quota_bar "$g5")" "$C_MUTED" "$(format_reset_detail "$AGY_GEMINI_5H_RESET_EPOCH" "$AGY_GEMINI_5H_RESET")" "$C_RESET"
  printf "%s│%s    • โควต้ารายสัปดาห์ (Weekly) : %b   %s(%s)%s\n" "$C_ACCENT" "$C_RESET" "$(format_quota_bar "$g7")" "$C_MUTED" "$(format_reset_detail "$AGY_GEMINI_7D_RESET_EPOCH" "$AGY_GEMINI_7D_RESET")" "$C_RESET"
  printf "%s│%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s2. Google AI Ultra — กระเป๋า Claude & GPT Models (agy)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s    • โควต้า 5 ชั่วโมง (5-Hour) : %b   %s(%s)%s\n" "$C_ACCENT" "$C_RESET" "$(format_quota_bar "$a5")" "$C_MUTED" "$(format_reset_detail "$AGY_CLAUDE_5H_RESET_EPOCH" "$AGY_CLAUDE_5H_RESET")" "$C_RESET"
  printf "%s│%s    • โควต้ารายสัปดาห์ (Weekly) : %b   %s(%s)%s\n" "$C_ACCENT" "$C_RESET" "$(format_quota_bar "$a7")" "$C_MUTED" "$(format_reset_detail "$AGY_CLAUDE_7D_RESET_EPOCH" "$AGY_CLAUDE_7D_RESET")" "$C_RESET"
  printf "%s│%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s3. OpenAI Codex CLI — แพ็กเกจ %s (codex)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$CODEX_PLAN" "$C_RESET"
  [ "$CODEX_FETCH_OK" = "0" ] && printf "%s│%s    %s▲ ดึงข้อมูลสดไม่สำเร็จ — แสดงค่าล่าสุดเมื่อ %s%s\n" "$C_ACCENT" "$C_RESET" "$C_WARN" "$CODEX_FETCHED_AT" "$C_RESET"
  printf "%s│%s    • โควต้า 5 ชั่วโมง (5-Hour) : %b   %s(%s)%s\n" "$C_ACCENT" "$C_RESET" "$(format_quota_bar "$x5")" "$C_MUTED" "$(format_reset_detail "$CODEX_5H_RESET_EPOCH" "$CODEX_5H_RESET")" "$C_RESET"
  printf "%s│%s    • โควต้ารายสัปดาห์ (Weekly) : %b   %s(%s)%s\n" "$C_ACCENT" "$C_RESET" "$(format_quota_bar "$x7")" "$C_MUTED" "$(format_reset_detail "$CODEX_7D_RESET_EPOCH" "$CODEX_7D_RESET")" "$C_RESET"
  printf "%s│%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s4. Anthropic Claude Code CLI — แพ็กเกจ %s (claude)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$CLAUDE_PLAN" "$C_RESET"
  [ "$CLAUDE_FETCH_OK" = "0" ] && printf "%s│%s    %s▲ ดึงข้อมูลสดไม่สำเร็จ — แสดงค่าล่าสุดเมื่อ %s%s\n" "$C_ACCENT" "$C_RESET" "$C_WARN" "$CLAUDE_FETCHED_AT" "$C_RESET"
  printf "%s│%s    • โควต้า 5 ชั่วโมง (5-Hour) : %b   %s(%s)%s\n" "$C_ACCENT" "$C_RESET" "$(format_quota_bar "$c5")" "$C_MUTED" "$(format_reset_detail "$CLAUDE_5H_RESET_EPOCH" "$CLAUDE_5H_RESET")" "$C_RESET"
  printf "%s│%s    • โควต้ารายสัปดาห์ (Weekly) : %b   %s(%s)%s\n" "$C_ACCENT" "$C_RESET" "$(format_quota_bar "$c7")" "$C_MUTED" "$(format_reset_detail "$CLAUDE_7D_RESET_EPOCH" "$CLAUDE_7D_RESET")" "$C_RESET"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %sคำแนะนำการจัดสรรโควต้าปัจจุบัน:%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  if [[ "$c7" =~ ^[0-9]+$ ]] && [ "$c7" -lt 20 ]; then
    printf "%s│%s  %s▲ โควต้ารายสัปดาห์ของค่าย claude เหลือ %s%% (%s) — แนะนำให้ใช้ Claude ผ่านค่าย agy (เหลือ %s%%) แทน%s\n" \
      "$C_ACCENT" "$C_RESET" "$C_WARN" "$c7" "$(format_reset_detail "$CLAUDE_7D_RESET_EPOCH" "$CLAUDE_7D_RESET")" "$a7" "$C_RESET"
  else
    printf "%s│%s  %s● โควต้าทุกตำแหน่งที่ตั้งค่าไว้พร้อมลุยงานต่อเนื่องได้อย่างเต็มประสิทธิภาพ%s\n" "$C_ACCENT" "$C_RESET" "$C_OK" "$C_RESET"
  fi
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  RENDER_NOW=""
}

run_quota_dashboard() {
  local mode="${1:-interactive}"
  refresh_cli_auth_cache
  refresh_quota_cache --live
  print_quota_report_box

  if [ "$mode" = "--once" ] || [ ! -t 0 ]; then
    return 0
  fi

  while true; do
    interactive_menu "จัดการและรีเฟรชโควต้าคงเหลือแบบเรียลไทม์" 0 \
      "1|★ รีเฟรชข้อมูลโควต้าสดจากทุกค่ายเดี๋ยวนี้ (Live Sync: agy + codex + claude)" \
      "2|ยิงอัปเดตโควต้า Codex สดจากเซิร์ฟเวอร์ OpenAI (Deep Codex Sync)" \
      "c|สลับค่าย AI / เปลี่ยน Model ประจำตำแหน่งเพื่อกระจายโควต้า (/model)" \
      "b|กลับสู่หน้าจอหลัก"

    case "$MENU_RESULT" in
      1)
        refresh_quota_cache --live
        print_quota_report_box
        ;;
      2)
        refresh_quota_cache --deep
        print_quota_report_box
        ;;
      c|C)
        configure_roles_menu
        return 0
        ;;
      *)
        return 0
        ;;
    esac
  done
}

# ─── 5. ฟังก์ชันตรวจสอบและบล็อกการถามงานหากยังตั้งค่า/Login ไม่ครบ 4 ตำแหน่ง ──
require_all_roles_ready() {
  check_all_roles_ready
  if [ "$ALL_ROLES_READY" -eq 1 ]; then
    return 0
  fi

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ERR" "$C_RESET"
  printf "%s│%s %sยังไม่สามารถเริ่มถามหรือสั่งงาน Agent ได้ (พร้อมใช้งานจริง %d/4 ตำแหน่ง)%s\n" "$C_ERR" "$C_RESET" "$C_BOLD" "$READY_ROLE_COUNT" "$C_RESET"
  printf "%s│%s ทุกตำแหน่งต้อง (1) ติดตั้ง CLI แล้ว (2) Login บัญชีแล้ว และ (3) เลือก Model แล้ว:\n" "$C_ERR" "$C_RESET"
  printf "%s│%s  • 1. @po       : %-6s (%s) ➔ %b\n" "$C_ERR" "$C_RESET" "$ROLE_PO" "$MODEL_PO" "$(format_role_status_cell "$ROLE_PO" "$MODEL_PO")"
  printf "%s│%s  • 2. @arch/@pm : %-6s (%s) ➔ %b\n" "$C_ERR" "$C_RESET" "$ROLE_ARCH" "$MODEL_ARCH" "$(format_role_status_cell "$ROLE_ARCH" "$MODEL_ARCH")"
  printf "%s│%s  • 3. @dev      : %-6s (%s) ➔ %b\n" "$C_ERR" "$C_RESET" "$ROLE_DEV" "$MODEL_DEV" "$(format_role_status_cell "$ROLE_DEV" "$MODEL_DEV")"
  printf "%s│%s  • 4. @qa/@sec  : %-6s (%s) ➔ %b\n" "$C_ERR" "$C_RESET" "$ROLE_QA" "$MODEL_QA" "$(format_role_status_cell "$ROLE_QA" "$MODEL_QA")"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ERR" "$C_RESET"

  interactive_menu "เลือกขั้นตอนเพื่อตั้งค่าและ Login ให้พร้อมใช้งาน" 0 \
    "1|★ ตั้งค่าด่วนด้วยโควตา Google AI Ultra (agy) + Codex พร้อมใช้ทันที" \
    "d|ไปที่หน้า Login บัญชี CLI (agy / codex / claude)" \
    "c|ตั้งค่าค่าย AI & เลือก Model แยกทีละตำแหน่ง" \
    "b|กลับสู่หน้าจอหลัก"

  case "$MENU_RESULT" in
    1) run_quick_preset_menu ;;
    c|C) configure_roles_menu ;;
    d|D) run_doctor_menu ;;
  esac
  return 1
}

# ─── 6. เมนูตั้งค่าด่วนคลิกเดียวครบ 4 ตำแหน่ง (รองรับ Google AI Ultra เต็มรูปแบบ) ───
run_quick_preset_menu() {
  load_role_config
  refresh_cli_auth_cache
  local target_conf="$GLOBAL_ROLES_CONF"
  [ -f "$PROJECT_ROLES_CONF" ] && target_conf="$PROJECT_ROLES_CONF"

  local codex_def
  codex_def="$(get_cli_default_model codex)"

  local u_tag="ต้องมี agy + codex" a_tag="ต้องมี agy" x_tag="ยังไม่ Login" c_tag="ยังไม่ Login"
  if is_provider_logged_in agy && is_provider_logged_in codex; then
    u_tag="● พร้อมใช้ทันที 100%"
  fi
  is_provider_logged_in agy    && a_tag="● พร้อมใช้ทันที 100%"
  is_provider_logged_in codex  && x_tag="● พร้อมใช้ทันที"
  is_provider_logged_in claude && c_tag="● พร้อมใช้ทันที"

  interactive_menu "เลือกชุดการตั้งค่าด่วน (รองรับโควตา Google AI Ultra ผ่าน agy + Codex)" 0 \
    "1|★ แนะนำสูงสุด (Google AI Ultra + Codex) — @po=agy(gemini-4-argon-high), @arch=agy(claude-opus-5-5-high), @dev=agy(claude-sonnet-5-5-high), @qa=codex(${codex_def}) [${u_tag}]" \
    "2|All-Google-AI-Ultra (agy ล้วนทั้ง 4 ตำแหน่ง) — @po=gemini-4-argon-high, @arch=claude-opus-5-5-high, @dev=claude-sonnet-5-5-high, @qa=gemini-3.8-flash-high [${a_tag}]" \
    "3|All-Codex Preset  — ใช้ codex (${codex_def}) ทั้ง 4 ตำแหน่ง [${x_tag}]" \
    "4|All-Claude Preset — ใช้ claude CLI แยกต่างหากทั้ง 4 ตำแหน่ง (@po=sonnet, @arch=opus, @dev=sonnet, @qa=opus) [${c_tag}]" \
    "b|ย้อนกลับ"

  case "$MENU_RESULT" in
    1)
      ROLE_PO="agy";     MODEL_PO="gemini-4-argon-high"
      ROLE_ARCH="agy";   MODEL_ARCH="claude-opus-5-5-high"
      ROLE_DEV="agy";    MODEL_DEV="claude-sonnet-5-5-high"
      ROLE_QA="codex";   MODEL_QA="$codex_def"
      save_role_config "$target_conf"
      printf "\n%s● บันทึกชุด Google AI Ultra (agy) + Codex (%s) ครบทั้ง 4 ตำแหน่งเรียบร้อยแล้ว!%s\n" "$C_OK" "$codex_def" "$C_RESET"
      ;;
    2)
      ROLE_PO="agy";     MODEL_PO="gemini-4-argon-high"
      ROLE_ARCH="agy";   MODEL_ARCH="claude-opus-5-5-high"
      ROLE_DEV="agy";    MODEL_DEV="claude-sonnet-5-5-high"
      ROLE_QA="agy";     MODEL_QA="gemini-3.8-flash-high"
      save_role_config "$target_conf"
      printf "\n%s● บันทึกชุด All-Google-AI-Ultra (agy) ครบทั้ง 4 ตำแหน่งเรียบร้อยแล้ว!%s\n" "$C_OK" "$C_RESET"
      ;;
    3)
      ROLE_PO="codex";   MODEL_PO="$codex_def"
      ROLE_ARCH="codex"; MODEL_ARCH="$codex_def"
      ROLE_DEV="codex";  MODEL_DEV="$codex_def"
      ROLE_QA="codex";   MODEL_QA="$codex_def"
      save_role_config "$target_conf"
      printf "\n%s● บันทึกชุด All-Codex (%s) ครบทั้ง 4 ตำแหน่งเรียบร้อยแล้ว!%s\n" "$C_OK" "$codex_def" "$C_RESET"
      ;;
    4)
      ROLE_PO="claude";   MODEL_PO="sonnet"
      ROLE_ARCH="claude"; MODEL_ARCH="opus"
      ROLE_DEV="claude";  MODEL_DEV="sonnet"
      ROLE_QA="claude";   MODEL_QA="opus"
      save_role_config "$target_conf"
      printf "\n%s● บันทึกชุด All-Claude ครบทั้ง 4 ตำแหน่งเรียบร้อยแล้ว!%s\n" "$C_OK" "$C_RESET"
      ;;
  esac
}

# ─── 7. ตัวช่วยเลือกหรือสร้างโฟลเดอร์โปรเจกต์ (เมื่อรันใน Home ~ หรือกด [f]) ───
select_or_create_project_dir() {
  local base_workspace="$HOME/dev_bos"
  [ ! -d "$base_workspace" ] && base_workspace="$HOME/Projects"

  local folder_items=()
  local folder_paths=()
  folder_items+=("n|★ สร้างโฟลเดอร์โปรเจกต์ใหม่ตั้งแต่ศูนย์ (สร้างโฟลเดอร์ + git init + .relay/ อัตโนมัติ)")

  local idx=1
  for search_root in "$HOME/dev_bos" "$HOME/Projects" "$HOME/workspace" "$HOME/Developer"; do
    if [ -d "$search_root" ]; then
      for d in "$search_root"/*; do
        [ -d "$d" ] || continue
        local dname
        dname="$(basename "$d")"
        [[ "$dname" == .* ]] && continue
        local r_stat="ยังไม่มี .relay/"
        [ -f "$d/.relay/PROJECT_STATE.md" ] && r_stat="● มี .relay/ พร้อมทำงาน"
        folder_items+=("${idx}|เปิดโปรเจกต์: ~${d#$HOME} (${r_stat})")
        folder_paths[$idx]="$d"
        idx=$((idx + 1))
        [ "$idx" -gt 7 ] && break 2
      done
    fi
  done

  folder_items+=("p|พิมพ์ระบุตำแหน่งโฟลเดอร์ (Path) ด้วยตนเอง")
  folder_items+=("b|ย้อนกลับ")

  interactive_menu "เลือกโฟลเดอร์โปรเจกต์ที่ต้องการทำงาน หรือสร้างโปรเจกต์ใหม่" 0 "${folder_items[@]}"

  case "$MENU_RESULT" in
    n|N)
      echo ""
      read -r -p "ตั้งชื่อโฟลเดอร์โปรเจกต์ใหม่ (ภาษาอังกฤษ เช่น my-saas-app หรือ booking-web): " new_proj_name
      new_proj_name="$(echo "${new_proj_name:-my-relay-app}" | tr ' ' '-' | sed -E 's/[^a-zA-Z0-9_-]+/-/g; s/^-|-$//g')"
      mkdir -p "$base_workspace/$new_proj_name"
      PROJECT_DIR="$base_workspace/$new_proj_name"
      cd "$PROJECT_DIR" || true
      refresh_project_paths
      "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" new
      CURRENT_TASK=""
      printf "\n%s● สร้างและเข้าสู่โปรเจกต์ใหม่เรียบร้อย: %s%s\n" "$C_OK" "$PROJECT_DIR" "$C_RESET"
      ;;
    [1-7])
      local chosen_dir="${folder_paths[$MENU_RESULT]}"
      if [ -n "$chosen_dir" ] && [ -d "$chosen_dir" ]; then
        PROJECT_DIR="$chosen_dir"
        cd "$PROJECT_DIR" || true
        refresh_project_paths
        CURRENT_TASK=""
        printf "\n%s● สลับเข้าสู่โฟลเดอร์โปรเจกต์: %s%s\n" "$C_OK" "$PROJECT_DIR" "$C_RESET"
      fi
      ;;
    p|P)
      echo ""
      read -r -p "ระบุ Path ของโฟลเดอร์โปรเจกต์ (เช่น ~/dev_bos/my-app): " custom_path
      custom_path="${custom_path/#\~/$HOME}"
      if [ -n "$custom_path" ]; then
        mkdir -p "$custom_path" 2>/dev/null || true
        if [ -d "$custom_path" ]; then
          PROJECT_DIR="$(cd "$custom_path" && pwd)"
          cd "$PROJECT_DIR" || true
          refresh_project_paths
          CURRENT_TASK=""
          printf "\n%s● สลับเข้าสู่โฟลเดอร์โปรเจกต์: %s%s\n" "$C_OK" "$PROJECT_DIR" "$C_RESET"
        else
          printf "\n%s✖ ไม่พบโฟลเดอร์ที่ระบุ: %s%s\n" "$C_ERR" "$custom_path" "$C_RESET"
        fi
      fi
      ;;
  esac
}

# ─── 8. เมนูเลือกค่าย AI และดึงรายชื่อ Model จาก CLI โดยตรง (ลูกศร ↑/↓) ────────
choose_provider_interactive() {
  local role_label="$1"
  local current_p="$2"
  refresh_cli_auth_cache

  local a_stat x_stat c_stat
  a_stat="$(get_provider_auth_detail agy)"
  x_stat="$(get_provider_auth_detail codex)"
  c_stat="$(get_provider_auth_detail claude)"

  interactive_menu "เลือกค่าย AI สำหรับ ${role_label} (ปัจจุบัน: ${current_p})" 0 \
    "1|agy    — Google AI Ultra / Antigravity CLI [${a_stat}]" \
    "2|codex  — OpenAI Codex CLI                  [${x_stat}]" \
    "3|claude — Anthropic Claude Code CLI         [${c_stat}]" \
    "b|คงค่าเดิม (${current_p})"

  local chosen_p="$current_p"
  case "$MENU_RESULT" in
    1) chosen_p="agy" ;;
    2) chosen_p="codex" ;;
    3) chosen_p="claude" ;;
    *) chosen_p="$current_p" ;;
  esac

  if ! is_provider_installed "$chosen_p"; then
    local pkg="@openai/codex"
    [ "$chosen_p" = "claude" ] && pkg="@anthropic-ai/claude-code"

    interactive_menu "ค่าย '${chosen_p}' ยังไม่ได้ติดตั้งในเครื่อง ต้องการติดตั้งเลยหรือไม่?" 0 \
      "1|ติดตั้ง ${chosen_p} อัตโนมัติเดี๋ยวนี้ (npm install -g ${pkg}) และเปิดหน้า Login" \
      "2|บันทึกชื่อค่ายไว้ก่อน (ติดตั้งภายหลัง)"
    if [ "$MENU_RESULT" = "1" ]; then
      npm install -g "$pkg"
      if is_provider_installed "$chosen_p"; then
        login_single_provider "$chosen_p"
      fi
    fi
  elif ! is_provider_logged_in "$chosen_p"; then
    interactive_menu "ค่าย '${chosen_p}' ติดตั้งแล้วแต่ยังไม่ได้ Login ต้องการเข้าสู่ระบบเลยหรือไม่?" 0 \
      "1|★ เปิดหน้า Login ของ ${chosen_p} เดี๋ยวนี้" \
      "2|เลือกโมเดลไว้ก่อน (ค่อย Login ภายหลัง)"
    if [ "$MENU_RESULT" = "1" ]; then
      login_single_provider "$chosen_p"
    fi
  fi

  SELECTED_PROVIDER="$chosen_p"
}

choose_model_interactive() {
  local provider="$1"
  local role_label="$2"
  local cli_def
  cli_def="$(get_cli_default_model "$provider")"

  local menu_items=()
  local model_ids=()
  local idx=1
  while IFS='|' read -r mid mdesc; do
    [ -z "$mid" ] && continue
    menu_items+=("${idx}|$(printf "%-24s — %s" "$mid" "$mdesc")")
    model_ids[$idx]="$mid"
    idx=$((idx + 1))
  done < <(get_cli_live_models "$provider")

  menu_items+=("c|กำหนดชื่อโมเดลเอง            — พิมพ์รหัส Model ID ที่ต้องการด้วยตนเอง")

  interactive_menu "เลือก Model ของค่าย [${provider}] สำหรับ ${role_label} (ดึงจาก CLI ในเครื่องโดยตรง)" 0 "${menu_items[@]}"

  if [ "$MENU_RESULT" = "c" ] || [ "$MENU_RESULT" = "C" ]; then
    read -r -p "ระบุชื่อ Model ของ ${provider}: " custom_m
    SELECTED_MODEL="${custom_m:-$cli_def}"
  elif [ -n "${model_ids[$MENU_RESULT]:-}" ]; then
    SELECTED_MODEL="${model_ids[$MENU_RESULT]}"
  else
    SELECTED_MODEL="$cli_def"
  fi
}

login_single_provider() {
  local provider="$1"
  case "$provider" in
    agy)
      if is_provider_installed agy; then
        printf "\n%sกำลังเปิด Antigravity CLI (agy) เพื่อเชื่อมบัญชี Google AI Ultra (พิมพ์ /exit เมื่อเสร็จ)...%s\n" "$C_ACCENT" "$C_RESET"
        agy || true
      else
        printf "%s✖ ไม่พบ ~/.gemini/bin/agy%s\n" "$C_ERR" "$C_RESET"
      fi
      ;;
    claude)
      if is_provider_installed claude; then
        printf "\n%sกำลังเปิดหน้า Login ของ Claude Code (claude auth login)...%s\n" "$C_ACCENT" "$C_RESET"
        claude auth login || claude || true
      else
        printf "%s✖ ยังไม่ได้ติดตั้ง claude%s\n" "$C_ERR" "$C_RESET"
      fi
      ;;
    codex)
      if is_provider_installed codex; then
        printf "\n%sกำลังเปิดหน้า Login ของ OpenAI Codex (codex login)...%s\n" "$C_ACCENT" "$C_RESET"
        codex login || true
      else
        printf "%s✖ ยังไม่ได้ติดตั้ง codex%s\n" "$C_ERR" "$C_RESET"
      fi
      ;;
  esac
  refresh_cli_auth_cache
}

# ─── 9. ศูนย์ตั้งค่าจับคู่ค่าย AI, เลือก Model และการเชื่อมต่อ CLI ([c] / /model) ───
configure_roles_menu() {
  load_role_config
  local target_conf="$GLOBAL_ROLES_CONF"
  local scope_label="Global (~/.agents/relay-roles.conf)"
  if [ -f "$PROJECT_ROLES_CONF" ]; then
    target_conf="$PROJECT_ROLES_CONF"
    scope_label="Project (.relay/roles.conf)"
  fi

  while true; do
    check_all_roles_ready
    local r1_stat="ยังไม่ครบ" r2_stat="ยังไม่ครบ" r3_stat="ยังไม่ครบ" r4_stat="ยังไม่ครบ"
    if is_role_ready "$ROLE_PO" "$MODEL_PO"; then r1_stat="● พร้อมแล้ว"; elif ! is_provider_logged_in "$ROLE_PO"; then r1_stat="▲ ยังไม่ Login"; fi
    if is_role_ready "$ROLE_ARCH" "$MODEL_ARCH"; then r2_stat="● พร้อมแล้ว"; elif ! is_provider_logged_in "$ROLE_ARCH"; then r2_stat="▲ ยังไม่ Login"; fi
    if is_role_ready "$ROLE_DEV" "$MODEL_DEV"; then r3_stat="● พร้อมแล้ว"; elif ! is_provider_logged_in "$ROLE_DEV"; then r3_stat="▲ ยังไม่ Login"; fi
    if is_role_ready "$ROLE_QA" "$MODEL_QA"; then r4_stat="● พร้อมแล้ว"; elif ! is_provider_logged_in "$ROLE_QA"; then r4_stat="▲ ยังไม่ Login"; fi

    interactive_menu "ตั้งค่าค่าย AI & เลือก Model ให้ครบ 4 ตำแหน่ง [พร้อม ${READY_ROLE_COUNT}/4 • ${scope_label}]" 0 \
      "p|★ ตั้งค่าด่วนรวดเดียวครบ 4 ตำแหน่ง (Google AI Ultra agy + Codex)" \
      "1|ขั้นตอนที่ 1 (@po)       ➔ ค่าย: ${ROLE_PO} | โมเดล: ${MODEL_PO} (${r1_stat})" \
      "2|ขั้นตอนที่ 2 (@arch/@pm) ➔ ค่าย: ${ROLE_ARCH} | โมเดล: ${MODEL_ARCH} (${r2_stat})" \
      "3|ขั้นตอนที่ 3 (@dev)      ➔ ค่าย: ${ROLE_DEV} | โมเดล: ${MODEL_DEV} (${r3_stat})" \
      "4|ขั้นตอนที่ 4 (@qa/@sec)  ➔ ค่าย: ${ROLE_QA} | โมเดล: ${MODEL_QA} (${r4_stat})" \
      "r|อัปเดตรายชื่อโมเดล Google AI Ultra ล่าสุดจาก 'agy models'" \
      "d|จัดการการเชื่อมต่อ CLI & Login บัญชี (agy / codex / claude)" \
      "m|ตั้งค่า Default Model เริ่มต้นของแต่ละค่ายในไฟล์ระบบ CLI" \
      "s|สลับไฟล์บันทึกการตั้งค่า (Global ~/.agents/ ↔ Project .relay/roles.conf)" \
      "t|บันทึกและทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่งทันที (/test)" \
      "b|บันทึกการตั้งค่าและกลับสู่หน้าจอหลัก"

    case "$MENU_RESULT" in
      1)
        choose_provider_interactive "ขั้นตอนที่ 1 (@po)" "$ROLE_PO"
        ROLE_PO="$SELECTED_PROVIDER"
        choose_model_interactive "$ROLE_PO" "ขั้นตอนที่ 1 (@po)"
        MODEL_PO="$SELECTED_MODEL"
        save_role_config "$target_conf"
        ;;
      2)
        choose_provider_interactive "ขั้นตอนที่ 2 (@arch/@pm)" "$ROLE_ARCH"
        ROLE_ARCH="$SELECTED_PROVIDER"
        choose_model_interactive "$ROLE_ARCH" "ขั้นตอนที่ 2 (@arch/@pm)"
        MODEL_ARCH="$SELECTED_MODEL"
        save_role_config "$target_conf"
        ;;
      3)
        choose_provider_interactive "ขั้นตอนที่ 3 (@dev)" "$ROLE_DEV"
        ROLE_DEV="$SELECTED_PROVIDER"
        choose_model_interactive "$ROLE_DEV" "ขั้นตอนที่ 3 (@dev)"
        MODEL_DEV="$SELECTED_MODEL"
        save_role_config "$target_conf"
        ;;
      4)
        choose_provider_interactive "ขั้นตอนที่ 4 (@qa/@sec)" "$ROLE_QA"
        ROLE_QA="$SELECTED_PROVIDER"
        choose_model_interactive "$ROLE_QA" "ขั้นตอนที่ 4 (@qa/@sec)"
        MODEL_QA="$SELECTED_MODEL"
        save_role_config "$target_conf"
        ;;
      p|P)
        run_quick_preset_menu
        load_role_config
        ;;
      r|R) refresh_agy_models_live ;;
      m|M) configure_provider_defaults_menu ;;
      d|D) run_doctor_menu ;;
      s|S)
        if [ "$target_conf" = "$GLOBAL_ROLES_CONF" ]; then
          target_conf="$PROJECT_ROLES_CONF"
          scope_label="Project (.relay/roles.conf)"
        else
          target_conf="$GLOBAL_ROLES_CONF"
          scope_label="Global (~/.agents/relay-roles.conf)"
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
        return 0
        ;;
    esac
  done
}

# ─── 10. ตั้งค่า Default Model ของแต่ละค่ายโดยตรง (Claude / Codex) ────────────
configure_provider_defaults_menu() {
  while true; do
    local cm xm
    cm="$(get_cli_default_model claude)"
    xm="$(get_cli_default_model codex)"

    interactive_menu "ตั้งค่า Default Model เริ่มต้นในไฟล์ระบบของแต่ละค่าย" 0 \
      "1|Claude Code CLI (~/.claude/settings.json) — ค่าเริ่มต้นปัจจุบัน: ${cm}" \
      "2|OpenAI Codex CLI (~/.codex/config.toml)   — ค่าเริ่มต้นปัจจุบัน: ${xm}" \
      "b|ย้อนกลับ"

    case "$MENU_RESULT" in
      1)
        choose_model_interactive "claude" "ค่าเริ่มต้นของ Claude Code CLI"
        set_cli_default_model "claude" "$SELECTED_MODEL"
        ;;
      2)
        choose_model_interactive "codex" "ค่าเริ่มต้นของ OpenAI Codex CLI"
        set_cli_default_model "codex" "$SELECTED_MODEL"
        ;;
      *) break ;;
    esac
  done
}

# ─── 11. ศูนย์จัดการการเชื่อมต่อ CLI, ติดตั้ง และ Login (RELAY Doctor / /connect) ─
run_doctor_menu() {
  while true; do
    refresh_cli_auth_cache
    echo ""
    printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
    printf "%s│%s %sสถานะการติดตั้ง CLI, การ Login บัญชี และโมเดลเริ่มต้นของแต่ละค่าย%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
    for p in agy codex claude; do
      local pkg="Antigravity App (~/.gemini/bin/agy)"
      [ "$p" = "claude" ] && pkg="@anthropic-ai/claude-code"
      [ "$p" = "codex" ]  && pkg="@openai/codex"
      local def_m auth_d
      def_m="$(get_cli_default_model "$p")"
      auth_d="$(get_provider_auth_detail "$p")"

      if ! is_provider_installed "$p"; then
        printf "%s│%s  %s○%s %-8s : %sยังไม่ได้ติดตั้ง CLI%s %s(%s)%s\n" "$C_ACCENT" "$C_RESET" "$C_ERR" "$C_RESET" "$p" "$C_ERR" "$C_RESET" "$C_MUTED" "$pkg" "$C_RESET"
      elif ! is_provider_logged_in "$p"; then
        local ver_s
        ver_s="$(get_provider_version "$p")"
        printf "%s│%s  %s▲%s %-8s : ติดตั้งแล้ว (%s) • %s%s%s\n" "$C_ACCENT" "$C_RESET" "$C_WARN" "$C_RESET" "$p" "$ver_s" "$C_WARN" "$auth_d" "$C_RESET"
      else
        local ver_s
        ver_s="$(get_provider_version "$p")"
        printf "%s│%s  %s●%s %-8s : ติดตั้งแล้ว (%s) • %s%s%s • Model: %s%s%s\n" "$C_ACCENT" "$C_RESET" "$C_OK" "$C_RESET" "$p" "$ver_s" "$C_OK" "$auth_d" "$C_RESET" "$C_BOLD" "$def_m" "$C_RESET"
      fi
    done
    printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

    interactive_menu "เลือกการจัดการ Login บัญชีผู้ใช้งาน หรืออัปเดตโมเดล/CLI" 0 \
      "1|อัปเดตรายชื่อโมเดล Google AI Ultra ล่าสุดจาก 'agy models'" \
      "2|เข้าสู่ระบบ OpenAI Codex (รัน codex login)" \
      "3|เข้าสู่ระบบ Claude Code แยกต่างหาก (รัน claude auth login)" \
      "4|ติดตั้ง / อัปเดต CLI (codex + claude)" \
      "m|ตั้งค่า Default Model เริ่มต้นของแต่ละค่ายในไฟล์ระบบ CLI" \
      "b|กลับสู่หน้าจอหลัก"

    case "$MENU_RESULT" in
      1) refresh_agy_models_live ;;
      2) login_single_provider "codex" ;;
      3) login_single_provider "claude" ;;
      4) npm install -g @anthropic-ai/claude-code @openai/codex ;;
      m|M) configure_provider_defaults_menu ;;
      *) break ;;
    esac
  done
}

# ─── 12. ทดสอบความพร้อมของ Agent แต่ละตำแหน่ง ([t] / /test) ─────────────────
check_role_skills_status() {
  local skills_list="$1"
  local output=""
  for sk in $skills_list; do
    if [ -d "$GLOBAL_DIR/skills/$sk" ] || { [ "$sk" = "founder-skill" ] && [ -d "$GLOBAL_DIR/skills/founder-plan" ]; }; then
      output="${output}${C_OK}[✓] ${sk}${C_RESET}  "
    else
      output="${output}${C_MUTED}[•] ${sk}${C_RESET}  "
    fi
  done
  printf "%b" "$output"
}

get_provider_rules_status() {
  local provider="$1"
  case "$provider" in
    agy)    [ -e "$HOME/.gemini/GEMINI.md" ] && printf "%s● เชื่อม ~/.gemini/GEMINI.md (Google AI Ultra) แล้ว%s" "$C_OK" "$C_RESET" || printf "%s○ ไม่พบ ~/.gemini/GEMINI.md%s" "$C_ERR" "$C_RESET" ;;
    claude) [ -e "$HOME/.claude/CLAUDE.md" ] && printf "%s● เชื่อม ~/.claude/CLAUDE.md แล้ว%s" "$C_OK" "$C_RESET" || printf "%s○ ไม่พบ ~/.claude/CLAUDE.md%s" "$C_ERR" "$C_RESET" ;;
    codex)  [ -e "$HOME/.codex/AGENTS.md" ]  && printf "%s● เชื่อม ~/.codex/AGENTS.md แล้ว%s" "$C_OK" "$C_RESET"  || printf "%s○ ไม่พบ ~/.codex/AGENTS.md%s" "$C_ERR" "$C_RESET" ;;
    *) printf "ไม่ทราบค่าย" ;;
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
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s กำลังทดสอบรายงานตัวของ: %s%s%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$role_title" "$C_RESET"
  printf "%s│%s  • ค่าย / โมเดล : %s (%s) • สถานะ: %s\n" "$C_ACCENT" "$C_RESET" "$provider" "$configured_model" "$(get_provider_auth_detail "$provider")"
  printf "%s│%s  • ทักษะประจำตัว: %s%s%s\n" "$C_ACCENT" "$C_RESET" "$C_MUTED" "$expected_skills" "$C_RESET"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  if ! is_provider_installed "$provider"; then
    printf "%s✖ ข้ามการยิงทดสอบ %s เนื่องจากยังไม่ได้ติดตั้ง CLI ของค่าย '%s'%s\n" "$C_ERR" "$role_code" "$provider" "$C_RESET"
    return 1
  fi

  if ! is_provider_logged_in "$provider"; then
    printf "%s✖ ข้ามการยิงทดสอบ %s เนื่องจากค่าย '%s' ยังไม่ได้เข้าสู่ระบบ (Not logged in)%s\n" "$C_WARN" "$role_code" "$provider" "$C_RESET"
    return 1
  fi

  if ! is_model_explicitly_set "$configured_model"; then
    printf "%s✖ ข้ามการยิงทดสอบ %s เนื่องจากยังไม่ได้เลือก Model%s\n" "$C_WARN" "$role_code" "$C_RESET"
    return 1
  fi

  local self_check_prompt="นี่คือการทดสอบความพร้อมของระบบ RELAY v1.0 กรุณารายงานตัวสั้นๆ ไม่เกิน 4 บรรทัด (ห้ามรันคำสั่งแก้ไขไฟล์ใดๆ) โดยระบุข้อมูลดังนี้:
1. รายงานบทบาทของคุณคือ '$role_title' (เรียกใช้งานผ่าน CLI ค่าย $provider)
2. สรุปหน้าที่หลักของคุณในระบบ RELAY ($expected_duty)
3. ยืนยันชุดทักษะ (Skills) ประจำตำแหน่งของคุณ ได้แก่: $expected_skills
4. ปิดท้ายด้วยข้อความ 'สถานะ: พร้อมปฏิบัติงาน 100%'"

  printf "%sกำลังส่งคำสั่งทดสอบไปยัง %s (%s)...%s\n" "$C_MUTED" "$provider" "$configured_model" "$C_RESET"
  local exit_code=0
  case "$provider" in
    agy)
      agy --model "$configured_model" -p "$self_check_prompt" || exit_code=$?
      ;;
    claude)
      claude --model "$configured_model" -p "$self_check_prompt" 2> >(grep -v '^Permission allow rule (\.claude/settings\.json):' >&2) || exit_code=$?
      ;;
    codex)
      codex exec --skip-git-repo-check -m "$configured_model" "$self_check_prompt" || exit_code=$?
      ;;
  esac

  if [ "$exit_code" -eq 0 ]; then
    printf "%s● [ผ่านการทดสอบ] %s เชื่อมต่อกับ %s (%s) และพร้อมใช้งาน 100%%!%s\n" "$C_OK" "$role_title" "$provider" "$configured_model" "$C_RESET"
  else
    printf "%s✖ [ไม่ผ่านการทดสอบ] %s ไม่สามารถรับคำสั่งผ่าน %s (%s) ได้%s\n" "$C_ERR" "$role_title" "$provider" "$configured_model" "$C_RESET"
  fi
}

run_agent_readiness_test() {
  check_all_roles_ready
  local po_skills="brainstorming founder-skill"
  local arch_skills="writing-plans supabase-postgres-best-practices"
  local dev_skills="impeccable vercel-react-best-practices lucide-icons simple-icons test-driven-development systematic-debugging"
  local qa_skills="verification-before-completion differential-review semgrep playwright-qa"

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %sตรวจสอบบทบาท โมเดล การ Login และทักษะประจำตำแหน่ง (RELAY Agent Readiness)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s1. ขั้นตอนที่ 1: @po (Product Owner — สร้าง SPEC.md)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_PO" "$(format_role_model_text "$ROLE_PO" "$MODEL_PO")" "$(format_role_status_cell "$ROLE_PO" "$MODEL_PO")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_ACCENT" "$C_RESET" "$(get_provider_rules_status "$ROLE_PO")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_ACCENT" "$C_RESET" "$(check_role_skills_status "$po_skills")"
  printf "%s│%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s2. ขั้นตอนที่ 2: @arch & @pm (Architect & Planner — สร้าง ARCH & PLAN)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_ARCH" "$(format_role_model_text "$ROLE_ARCH" "$MODEL_ARCH")" "$(format_role_status_cell "$ROLE_ARCH" "$MODEL_ARCH")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_ACCENT" "$C_RESET" "$(get_provider_rules_status "$ROLE_ARCH")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_ACCENT" "$C_RESET" "$(check_role_skills_status "$arch_skills")"
  printf "%s│%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s3. ขั้นตอนที่ 3: @dev (Full-Stack Developer — พัฒนาโค้ดใน Git Worktree)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_DEV" "$(format_role_model_text "$ROLE_DEV" "$MODEL_DEV")" "$(format_role_status_cell "$ROLE_DEV" "$MODEL_DEV")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_ACCENT" "$C_RESET" "$(get_provider_rules_status "$ROLE_DEV")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_ACCENT" "$C_RESET" "$(check_role_skills_status "$dev_skills")"
  printf "%s│%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s4. ขั้นตอนที่ 4: @qa & @sec (QA & Security Auditor — สร้าง QA_REPORT.md)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_QA" "$(format_role_model_text "$ROLE_QA" "$MODEL_QA")" "$(format_role_status_cell "$ROLE_QA" "$MODEL_QA")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_ACCENT" "$C_RESET" "$(get_provider_rules_status "$ROLE_QA")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_ACCENT" "$C_RESET" "$(check_role_skills_status "$qa_skills")"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  interactive_menu "เลือกตำแหน่งที่ต้องการยิงทดสอบให้ AI รายงานบทบาทและ Skills จริง" 0 \
    "1|★ ทดสอบรวดเดียวครบทั้ง 4 ตำแหน่ง (@po, @arch/@pm, @dev, @qa/@sec)" \
    "2|ทดสอบเฉพาะ ขั้นตอนที่ 1 (@po        ➔ ${ROLE_PO} / ${MODEL_PO})" \
    "3|ทดสอบเฉพาะ ขั้นตอนที่ 2 (@arch/@pm  ➔ ${ROLE_ARCH} / ${MODEL_ARCH})" \
    "4|ทดสอบเฉพาะ ขั้นตอนที่ 3 (@dev       ➔ ${ROLE_DEV} / ${MODEL_DEV})" \
    "5|ทดสอบเฉพาะ ขั้นตอนที่ 4 (@qa/@sec   ➔ ${ROLE_QA} / ${MODEL_QA})" \
    "c|ไปที่หน้าตั้งค่าค่าย AI & เปลี่ยน Model" \
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
    c|C) configure_roles_menu ;;
  esac
}

# ─── 13. เรียกใช้งาน CLI ของแต่ละขั้นตอน ──────────────────────────────────────
# บันทึก 1 บรรทัดต่อการเรียก agent ลง .relay/tasks/<task>/RUN_LOG.jsonl
append_run_log() {
  local log_dir="$RELAY_DIR/tasks/$ACTIVE_TASK"
  [ -n "$ACTIVE_TASK" ] && [ -d "$log_dir" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$log_dir/RUN_LOG.jsonl" "$@" <<'PYEOF' 2>/dev/null || true
import json, sys, datetime
f = sys.argv[1]
mode, step, prov, model, rc, s, e, qb, qa = sys.argv[2:11]
def q(x):
    p = x.split("|")
    return {"5h": p[0] if p and p[0] else "-", "7d": p[1] if len(p) > 1 else "-"}
rec = {
    "started_at": datetime.datetime.fromtimestamp(int(s)).isoformat(timespec="seconds"),
    "duration_sec": int(e) - int(s),
    "mode": mode,
    "step": step,
    "provider": prov,
    "model": model,
    "exit_code": int(rc) if rc.lstrip("-").isdigit() else rc,
    "quota_before": q(qb),
    "quota_after": q(qa),
}
with open(f, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
PYEOF
}

# สรุปเวลาและโควต้าที่ใช้ต่อขั้นของ Auto-Loop จาก RUN_LOG.jsonl
print_loop_run_summary() {
  local since="$1"
  local f="$RELAY_DIR/tasks/$ACTIVE_TASK/RUN_LOG.jsonl"
  [ -f "$f" ] && command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$f" "$since" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_MUTED" <<'PYEOF' 2>/dev/null || true
import json, sys, datetime
f, since, ACC, RST, BOLD, MUTED = sys.argv[1:7]
since = int(since)
rows = []
for line in open(f, encoding="utf-8"):
    try:
        r = json.loads(line)
    except Exception:
        continue
    if r.get("mode") != "auto":
        continue
    if datetime.datetime.fromisoformat(r["started_at"]).timestamp() < since - 1:
        continue
    rows.append(r)
if not rows:
    sys.exit(0)
def dur(s):
    m, s = divmod(int(s), 60)
    h, m = divmod(m, 60)
    return f"{h}ชม.{m:02d}น." if h else f"{m}น.{s:02d}วิ"
print(f"{ACC}│{RST} {BOLD}สรุปการทำงานของลูป (จาก RUN_LOG.jsonl){RST}")
total = 0
for r in rows:
    total += r.get("duration_sec", 0)
    qb, qa = r.get("quota_before", {}), r.get("quota_after", {})
    print(f"{ACC}│{RST}  • {r['step']} — {r['provider']}/{r['model']} • {dur(r.get('duration_sec', 0))} • exit {r.get('exit_code')} {MUTED}• 5h {qb.get('5h')}%→{qa.get('5h')}%{RST}")
print(f"{ACC}│{RST}  {MUTED}รวม {len(rows)} ขั้น • ใช้เวลาทั้งหมด {dur(total)}{RST}")
PYEOF
}

launch_provider_cli() {
  local provider="$1"
  local configured_model="$2"
  local role_name="$3"
  local work_dir="$4"
  local initial_prompt="$5"

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s กำลังเข้าสู่ %s%s%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$role_name" "$C_RESET"
  printf "%s│%s  • ค่ายผู้ให้บริการ : %s  │  โมเดลที่ใช้: %s%s%s\n" "$C_ACCENT" "$C_RESET" "$provider" "$C_BOLD" "$configured_model" "$C_RESET"
  printf "%s│%s  • โฟลเดอร์ทำงาน  : %s%s%s\n" "$C_ACCENT" "$C_RESET" "$C_MUTED" "$work_dir" "$C_RESET"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s คำสั่งเริ่มต้น (คัดลอกลง Clipboard ให้แล้วอัตโนมัติ):\n" "$C_ACCENT" "$C_RESET"
  printf "%s%s%s\n" "$C_MUTED" "$initial_prompt" "$C_RESET"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s เมื่อสร้างเอกสารของขั้นตอนนี้เสร็จแล้ว ให้พิมพ์ %s/exit%s เพื่อกลับมาหน้าจอ RELAY\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  if command -v pbcopy >/dev/null 2>&1; then
    printf "%s" "$initial_prompt" | pbcopy
  fi

  local run_start q_before
  run_start="$(date +%s)"
  q_before="$(get_role_quota_pair "$provider" "$configured_model")"
  (
    cd "$work_dir"
    case "$provider" in
      agy)    agy --model "$configured_model" -i "$initial_prompt" || agy --model "$configured_model" || true ;;
      claude) claude --model "$configured_model" "$initial_prompt" 2> >(grep -v '^Permission allow rule (\.claude/settings\.json):' >&2) || true ;;
      codex)  codex -m "$configured_model" "$initial_prompt" || true ;;
    esac
  )
  refresh_quota_cache --quiet
  append_run_log "interactive" "$role_name" "$provider" "$configured_model" "0" "$run_start" "$(date +%s)" "$q_before" "$(get_role_quota_pair "$provider" "$configured_model")"
}

ensure_git_repo_ready_for_worktree() {
  if [ ! -d "$PROJECT_DIR/.git" ]; then
    printf "%sกำลังเตรียม Git Repository (git init -b main) สำหรับโครงการ %s...%s\n" "$C_ACCENT" "$PROJECT_NAME" "$C_RESET"
    git -C "$PROJECT_DIR" init -b main >/dev/null 2>&1 || git -C "$PROJECT_DIR" init >/dev/null 2>&1 || true
  fi
  if [ -d "$PROJECT_DIR/.git" ] && ! git -C "$PROJECT_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "$PROJECT_DIR" commit --allow-empty -m "chore: initial commit for RELAY" >/dev/null 2>&1 || true
  fi
}

# เพิ่ม .relay/worktrees/ ลงใน .gitignore ของโปรเจกต์ เพื่อไม่ให้ Worktree ของใบงานปะปนกับโค้ดในกิ่งหลัก
ensure_relay_gitignore() {
  local gi="$PROJECT_DIR/.gitignore"
  if ! grep -qxF '.relay/worktrees/' "$gi" 2>/dev/null; then
    printf '\n# RELAY: Git Worktree แยกอิสระของแต่ละใบงาน (ห้าม commit)\n.relay/worktrees/\n' >> "$gi"
  fi
}

# รายการไฟล์โค้ดที่ยังไม่ commit ใน Worktree (ไม่นับเอกสารใน .relay/ ที่ RELAY คัดลอกเข้าไปเอง)
worktree_dirty_files() {
  local wt="$1"
  [ -d "$wt" ] || return 0
  git -C "$wt" status --porcelain -- . ':(exclude).relay' 2>/dev/null || true
}

# สร้างหรือใช้ Worktree ของใบงานปัจจุบัน แล้วตั้งค่า TASK_WORK_DIR
# คืนค่า 1 พร้อมแสดงข้อความ error จริงเมื่อสร้างไม่ได้ (ห้ามทำงานต่อบนกิ่งหลักแบบเงียบๆ)
TASK_WORK_DIR=""
prepare_task_worktree() {
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"
  local branch_name="feat/$ACTIVE_TASK"
  TASK_WORK_DIR=""

  ensure_git_repo_ready_for_worktree
  if ! git -C "$PROJECT_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
    echo ""
    printf "%s✖ ไม่สามารถเตรียม Git Repository ได้ (ยังไม่มี commit แรก — ตรวจสอบ git config user.name / user.email)%s\n" "$C_ERR" "$C_RESET"
    return 1
  fi
  ensure_relay_gitignore
  mkdir -p "$RELAY_DIR/worktrees"

  if [ ! -d "$worktree_dir" ]; then
    printf "%sกำลังสร้าง Git Worktree แยกอิสระที่ .relay/worktrees/%s (กิ่ง %s)...%s\n" "$C_ACCENT" "$ACTIVE_TASK" "$branch_name" "$C_RESET"
    local wt_err=""
    if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$branch_name"; then
      wt_err="$(git -C "$PROJECT_DIR" worktree add "$worktree_dir" "$branch_name" 2>&1)" || {
        printf "%s✖ สร้าง Worktree ไม่สำเร็จ (หยุดเพื่อไม่ให้แก้โค้ดบนกิ่งหลัก):%s\n%s\n" "$C_ERR" "$C_RESET" "$wt_err"
        return 1
      }
    else
      wt_err="$(git -C "$PROJECT_DIR" worktree add "$worktree_dir" -b "$branch_name" 2>&1)" || {
        printf "%s✖ สร้าง Worktree ไม่สำเร็จ (หยุดเพื่อไม่ให้แก้โค้ดบนกิ่งหลัก):%s\n%s\n" "$C_ERR" "$C_RESET" "$wt_err"
        return 1
      }
    fi
  fi

  mkdir -p "$worktree_dir/.relay/tasks"
  cp -R "$RELAY_DIR/tasks/$ACTIVE_TASK" "$worktree_dir/.relay/tasks/" 2>/dev/null || true
  [ -f "$RELAY_DIR/PROJECT_STATE.md" ] && cp "$RELAY_DIR/PROJECT_STATE.md" "$worktree_dir/.relay/PROJECT_STATE.md" 2>/dev/null || true
  if [ -d "$RELAY_DIR/skills" ]; then
    mkdir -p "$worktree_dir/.relay/skills"
    cp -R "$RELAY_DIR/skills/"* "$worktree_dir/.relay/skills/" 2>/dev/null || true
  fi
  TASK_WORK_DIR="$worktree_dir"
  return 0
}

# ดึงเอกสารที่ agent เขียนใน Worktree กลับมาที่ใบงานหลัก
# (ไม่ทับ LOOP_LOG.md / RUN_LOG.jsonl ที่ RELAY เขียนในใบงานหลักโดยตรง เพื่อไม่ให้บันทึกหาย)
sync_task_docs_from_worktree() {
  local src="$1"
  local dst="$2"
  [ -d "$src" ] && [ -d "$dst" ] || return 0
  local f
  for f in "$src"/* ; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      LOOP_LOG.md|RUN_LOG.jsonl) continue ;;
    esac
    cp -R "$f" "$dst/" 2>/dev/null || true
  done
  return 0
}

# ข้อความกำชับ @dev ให้ commit งานในกิ่งของใบงาน (ป้องกันโค้ดหายตอนผสานในขั้นตอนที่ 5)
get_dev_commit_note() {
  printf " เมื่อเขียนโค้ดและรันชุดทดสอบผ่านแล้ว ให้ git add และ git commit งานทั้งหมดในกิ่ง feat/%s ของ Worktree นี้ (ห้าม commit โฟลเดอร์ .relay/)" "$ACTIVE_TASK"
}

ensure_or_create_task() {
  refresh_project_paths
  mkdir -p "$RELAY_DIR/tasks" "$RELAY_DIR/archive"
  get_active_task
  if [ -z "$ACTIVE_TASK" ]; then
    create_new_task
  fi
}

create_new_task() {
  refresh_project_paths
  mkdir -p "$RELAY_DIR/tasks" "$RELAY_DIR/archive"
  local raw_input="${1:-}"
  if [ -z "$raw_input" ]; then
    echo ""
    read -r -p "ตั้งชื่อย่อของใบงานใหม่ (ภาษาอังกฤษ เช่น user-auth หรือ pos-cafe): " raw_input
  fi
  local slug
  slug="$(printf "%s" "${raw_input:-feature}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -E 's/^-+|-+$//g' | cut -c1-24 | sed -E 's/-+$//')"
  [ -z "$slug" ] && slug="task-$(( $(ls -1 "$RELAY_DIR/tasks" 2>/dev/null | wc -l) + 1 ))"
  local today
  today="$(date +%Y%m%d)"
  CURRENT_TASK="${today}-${slug}"
  mkdir -p "$RELAY_DIR/tasks/$CURRENT_TASK/screenshots"
  ACTIVE_TASK="$CURRENT_TASK"
  LAST_COMPLETED_PHASE=0
  printf "%s● สร้างใบงานใหม่เรียบร้อย: .relay/tasks/%s%s\n" "$C_OK" "$ACTIVE_TASK" "$C_RESET"
}

run_phase_1_po() {
  require_all_roles_ready || return 0
  refresh_project_paths
  mkdir -p "$RELAY_DIR/tasks" "$RELAY_DIR/archive"
  get_active_task
  echo ""
  read -r -p "อธิบายฟีเจอร์หรือความต้องการคร่าวๆ ที่ต้องการให้ @po วิเคราะห์: " user_goal
  if [ -z "$ACTIVE_TASK" ]; then
    create_new_task "${user_goal:-feature}"
  fi
  local prompt="@po ฉันต้องการพัฒนาฟีเจอร์สำหรับใบงาน .relay/tasks/$ACTIVE_TASK เกี่ยวกับ: ${user_goal:-ตามที่ฉันกำลังจะอธิบายต่อไปนี้} กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md (ถ้ามี) แล้วซักถามความต้องการจากฉันทีละประเด็นจนชัดเจน เมื่อฉันยืนยันแล้วให้สรุปเป็นเอกสารกำหนดความต้องการลงในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md"
  launch_provider_cli "$ROLE_PO" "$MODEL_PO" "ขั้นตอนที่ 1: @po (Product Owner)" "$PROJECT_DIR" "$prompt"
  LAST_COMPLETED_PHASE=1
}

run_phase_2_arch() {
  require_all_roles_ready || return 0
  ensure_or_create_task
  local learned_note
  learned_note="$(get_learned_skills_prompt_note)"
  local prompt="@arch @pm กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md ร่วมกับไฟล์ความต้องการ .relay/tasks/$ACTIVE_TASK/SPEC.md${learned_note} แล้วออกแบบโครงสร้างทางเทคนิคลงในไฟล์ .relay/tasks/$ACTIVE_TASK/ARCH.md และจัดทำแผนการดำเนินงานย่อยเป็นข้อๆ ลงในไฟล์ .relay/tasks/$ACTIVE_TASK/PLAN.md"
  launch_provider_cli "$ROLE_ARCH" "$MODEL_ARCH" "ขั้นตอนที่ 2: @arch & @pm (Architect & Planner)" "$PROJECT_DIR" "$prompt"
  LAST_COMPLETED_PHASE=2
}

run_phase_3_dev() {
  require_all_roles_ready || return 0
  ensure_or_create_task
  if ! prepare_task_worktree; then
    [ -t 0 ] && { read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true; }
    return 0
  fi

  local learned_note commit_note
  learned_note="$(get_learned_skills_prompt_note)"
  commit_note="$(get_dev_commit_note)"
  local prompt="@dev กรุณาอ่านเอกสาร .relay/tasks/$ACTIVE_TASK/SPEC.md, ARCH.md และ PLAN.md${learned_note} แล้วดำเนินการพัฒนาโค้ดควบคู่กับชุดทดสอบ (Unit Tests) ตามแผนที่กำหนดไว้${commit_note}"
  launch_provider_cli "$ROLE_DEV" "$MODEL_DEV" "ขั้นตอนที่ 3: @dev (Full-Stack Developer ใน Git Worktree)" "$TASK_WORK_DIR" "$prompt"
  LAST_COMPLETED_PHASE=3
}

run_phase_4_qa() {
  require_all_roles_ready || return 0
  ensure_or_create_task
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"
  local target_work_dir="$PROJECT_DIR"
  [ -d "$worktree_dir" ] && target_work_dir="$worktree_dir"

  local learned_note
  learned_note="$(get_learned_skills_prompt_note)"
  local prompt="@qa @sec กรุณาตรวจสอบผลงานตามเกณฑ์ Acceptance Criteria ในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md${learned_note} โดย: 1. รันชุดทดสอบจริงของโครงการผ่าน Terminal (0 Token) 2. ตรวจสอบความปลอดภัยของ git diff ตามทักษะ differential-review และ semgrep 3. หากมีส่วนติดต่อผู้ใช้บนเว็บ ให้ใช้ Playwright MCP ทดสอบและบันทึกภาพหน้าจอไว้ที่ .relay/tasks/$ACTIVE_TASK/screenshots/ 4. สรุปผลการตรวจสอบลงในไฟล์ .relay/tasks/$ACTIVE_TASK/QA_REPORT.md (ระบุ VERDICT: PASS หรือ VERDICT: FAIL ให้ชัดเจน)$(get_qa_prompt_contract)"
  launch_provider_cli "$ROLE_QA" "$MODEL_QA" "ขั้นตอนที่ 4: @qa & @sec (Quality Assurance & Security Auditor)" "$target_work_dir" "$prompt"

  if [ -d "$worktree_dir/.relay/tasks/$ACTIVE_TASK" ]; then
    sync_task_docs_from_worktree "$worktree_dir/.relay/tasks/$ACTIVE_TASK" "$RELAY_DIR/tasks/$ACTIVE_TASK"
  fi
  LAST_COMPLETED_PHASE=4
}

# ─── 13.5 ระบบสกัดบทเรียนสะสมเฉพาะโปรเจกต์อัตโนมัติ (Self-Learning Project Skills) ─
distill_project_learned_skills() {
  local target_task="${1:-$ACTIVE_TASK}"
  local mode="${2:-interactive}"
  refresh_project_paths

  if [ -z "$target_task" ]; then
    get_active_task
    target_task="$ACTIVE_TASK"
  fi

  local task_dir=""
  if [ -n "$target_task" ] && [ -d "$RELAY_DIR/tasks/$target_task" ]; then
    task_dir="$RELAY_DIR/tasks/$target_task"
  elif [ -n "$target_task" ] && [ -d "$RELAY_DIR/archive/$target_task" ]; then
    task_dir="$RELAY_DIR/archive/$target_task"
  else
    local latest_arch
    latest_arch="$(ls -1 "$RELAY_DIR/archive" 2>/dev/null | grep -v '^\.' | tail -n 1 || true)"
    if [ -n "$latest_arch" ] && [ -d "$RELAY_DIR/archive/$latest_arch" ]; then
      target_task="$latest_arch"
      task_dir="$RELAY_DIR/archive/$latest_arch"
    fi
  fi

  if [ -z "$task_dir" ] || [ ! -d "$task_dir" ]; then
    [ "$mode" != "auto" ] && printf "%s▲ ยังไม่มีใบงานที่พร้อมสกัดบทเรียนใน .relay/tasks/ หรือ .relay/archive/%s\n" "$C_WARN" "$C_RESET"
    return 1
  fi
  command -v python3 >/dev/null 2>&1 || return 1

  local learn_dir="$RELAY_DIR/skills/project-learned"
  mkdir -p "$learn_dir"

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s🧠 [Self-Learning] กำลังสกัดกฎที่เสนอจากใบงาน %s...%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$target_task" "$C_RESET"
  printf "%s│%s  • กฎที่สกัดได้จะเข้าคิว PENDING.md ก่อน — ยังไม่ถูกส่งให้ AI จนกว่าคุณจะอนุมัติใน [l]\n" "$C_ACCENT" "$C_RESET"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  python3 - "$target_task" "$task_dir" "$learn_dir" <<'PYEOF'
import os, re, sys, datetime

task_id, task_dir, learn_dir = sys.argv[1:4]
skill_file = os.path.join(learn_dir, "SKILL.md")
pending_file = os.path.join(learn_dir, "PENDING.md")
ledger_file = os.path.join(learn_dir, "LEDGER.md")

def read_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()
    except Exception:
        return ""

def bullets(text):
    return [l.strip()[2:].strip() for l in text.splitlines() if l.strip().startswith("- ")]

def norm(s):
    return re.sub(r"\W+", "", s.lower())[:60]

spec_txt = read_text(os.path.join(task_dir, "SPEC.md"))
arch_txt = read_text(os.path.join(task_dir, "ARCH.md"))
qa_txt = read_text(os.path.join(task_dir, "QA_REPORT.md"))

known = {norm(r) for r in bullets(read_text(skill_file))}
pending = bullets(read_text(pending_file))
known |= {norm(r) for r in pending}

candidates = []
for content in (qa_txt, arch_txt, spec_txt):
    for line in content.splitlines():
        s = line.strip()
        if not s.startswith("- "):
            continue
        item = s[2:].strip()
        if len(item) < 30 or len(item) > 220 or item.endswith(":") or item.startswith("[ ]") or item.startswith("[x]"):
            continue
        if any(k in item.lower() for k in [
            "circuit breaker", "quota", "worktree", "skill", "security", "timeout", "guard",
            "fallback", "verdict", "โควต้า", "ความปลอดภัย", "ห้าม", "ต้อง", "มาตรฐาน", "ป้องกัน", "แยกอิสระ",
        ]):
            candidates.append(re.sub(r"\s+", " ", item))

added = []
for c in candidates:
    k = norm(c)
    if k and k not in known:
        known.add(k)
        added.append(c)
        if len(added) >= 5:
            break

pending = (pending + added)[-30:]
with open(pending_file, "w", encoding="utf-8") as f:
    f.write("# กฎที่รออนุมัติ (RELAY Self-Learning — ยังไม่ถูกส่งให้ AI)\n\n")
    f.write("> กด [l] ในหน้าจอ relay เพื่ออนุมัติหรือปฏิเสธ — เฉพาะกฎที่อนุมัติแล้วจะย้ายไปที่ SKILL.md\n\n")
    for p in pending:
        f.write(f"- {p}\n")

now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
if not os.path.exists(ledger_file):
    with open(ledger_file, "w", encoding="utf-8") as f:
        f.write("# สมุดบัญชีประวัติบทเรียนของโปรเจกต์ (RELAY Self-Learning Ledger)\n\n")
with open(ledger_file, "a", encoding="utf-8") as f:
    f.write(f"## [{now_str}] เสนอจากใบงาน `{task_id}` ({len(added)} ข้อ — รออนุมัติ)\n")
    for a in added:
        f.write(f"  - `?` {a}\n")
    f.write("\n")

print(f"● เสนอกฎใหม่ {len(added)} ข้อ (รออนุมัติทั้งหมด {len(pending)} ข้อ ใน .relay/skills/project-learned/PENDING.md)")
PYEOF
}

get_learned_pending_count() {
  local f="$RELAY_DIR/skills/project-learned/PENDING.md"
  [ -f "$f" ] || { echo "0"; return; }
  local cnt
  cnt="$(grep -cE '^[[:space:]]*-[[:space:]]+' "$f" 2>/dev/null || true)"
  echo "${cnt:-0}"
}

# อนุมัติ/ปฏิเสธกฎจาก PENDING.md — selection: "a" ทั้งหมด, "x" ปฏิเสธทั้งหมด, หรือหมายเลขคั่นด้วยจุลภาค เช่น "1,3"
apply_learned_approval() {
  local selection="$1"
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$RELAY_DIR/skills/project-learned" "$PROJECT_NAME" "$selection" <<'PYEOF'
import os, re, sys, datetime

learn_dir, project_name, selection = sys.argv[1:4]
skill_file = os.path.join(learn_dir, "SKILL.md")
pending_file = os.path.join(learn_dir, "PENDING.md")
ledger_file = os.path.join(learn_dir, "LEDGER.md")

def read_text(path):
    try:
        return open(path, encoding="utf-8", errors="ignore").read()
    except Exception:
        return ""

def bullets(text):
    return [l.strip()[2:].strip() for l in text.splitlines() if l.strip().startswith("- ")]

pending = bullets(read_text(pending_file))
sel = selection.strip().lower()
if sel == "a":
    chosen = set(range(len(pending)))
elif sel == "x":
    chosen = set()
else:
    chosen = {int(n) - 1 for n in re.findall(r"\d+", sel) if 0 < int(n) <= len(pending)}

approved = [p for i, p in enumerate(pending) if i in chosen]
rejected = [p for i, p in enumerate(pending) if i not in chosen]

rules = bullets(read_text(skill_file))
seen = {re.sub(r"\W+", "", r.lower())[:60] for r in rules}
for a in approved:
    k = re.sub(r"\W+", "", a.lower())[:60]
    if k not in seen:
        rules.append(a)
        seen.add(k)
rules = rules[-25:]
now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

if rules:
    with open(skill_file, "w", encoding="utf-8") as f:
        f.write(f"""---
name: project-learned-{project_name.lower()}
description: กฎและข้อควรระวังเฉพาะโครงการ {project_name} ที่ผ่านการอนุมัติจากผู้ใช้แล้ว (RELAY Self-Learning)
---

# บทเรียนสะสมที่อนุมัติแล้ว ({project_name})

> ทุกข้อผ่านการอนุมัติจากผู้ใช้ผ่านเมนู [l] (อัปเดตล่าสุด `{now_str}`) • แก้ไขหรือลบข้อที่ไม่ต้องการในไฟล์นี้ได้โดยตรง
> ตัวแทน AI (`@arch`, `@dev`, `@qa`) ต้องปฏิบัติตามกฎด้านล่างควบคู่กับ `.relay/PROJECT_STATE.md`

## กฎสถาปัตยกรรมและการป้องกันข้อผิดพลาดซ้ำ
""")
        for r in rules:
            f.write(f"- {r}\n")

with open(pending_file, "w", encoding="utf-8") as f:
    f.write("# กฎที่รออนุมัติ (RELAY Self-Learning — ยังไม่ถูกส่งให้ AI)\n\n")
    f.write("> กด [l] ในหน้าจอ relay เพื่ออนุมัติหรือปฏิเสธ — เฉพาะกฎที่อนุมัติแล้วจะย้ายไปที่ SKILL.md\n\n")

with open(ledger_file, "a", encoding="utf-8") as f:
    f.write(f"## [{now_str}] ผลการทบทวนโดยผู้ใช้ (อนุมัติ {len(approved)} • ปฏิเสธ {len(rejected)})\n")
    for a in approved:
        f.write(f"  - `+ อนุมัติ` {a}\n")
    for r in rejected:
        f.write(f"  - `- ปฏิเสธ` {r}\n")
    f.write("\n")

print(f"● อนุมัติ {len(approved)} ข้อ • ปฏิเสธ {len(rejected)} ข้อ • กฎที่ใช้งานอยู่ทั้งหมด {len(rules)}/25 ข้อ")
PYEOF
}

review_pending_learned_rules() {
  local pending_file="$RELAY_DIR/skills/project-learned/PENDING.md"
  local pcnt
  pcnt="$(get_learned_pending_count)"
  if [ "$pcnt" -eq 0 ]; then
    printf "%sไม่มีกฎที่รออนุมัติ%s\n" "$C_MUTED" "$C_RESET"
    return 0
  fi
  echo ""
  printf "%sกฎที่รออนุมัติ (%s ข้อ):%s\n" "$C_BOLD" "$pcnt" "$C_RESET"
  grep -E '^[[:space:]]*-[[:space:]]+' "$pending_file" | sed -E 's/^[[:space:]]*-[[:space:]]+//' | awk '{ printf "  [%d] %s\n", NR, $0 }'
  echo ""
  local sel=""
  read -r -p "พิมพ์หมายเลขที่อนุมัติ (เช่น 1,3) • a = อนุมัติทั้งหมด • x = ปฏิเสธทั้งหมด • Enter = ข้ามไว้ก่อน: " sel || true
  if [ -z "$sel" ]; then
    printf "%sเก็บกฎไว้ในคิวรออนุมัติตามเดิม%s\n" "$C_MUTED" "$C_RESET"
    return 0
  fi
  apply_learned_approval "$sel"
}

run_learned_skills_menu() {
  local mode="${1:-interactive}"
  refresh_project_paths
  get_active_task
  if [ "$mode" = "--auto" ] || [ "$mode" = "auto" ]; then
    distill_project_learned_skills "$ACTIVE_TASK" "auto"
    return 0
  fi

  local skill_file="$RELAY_DIR/skills/project-learned/SKILL.md"
  local ledger_file="$RELAY_DIR/skills/project-learned/LEDGER.md"
  local cnt pcnt
  cnt="$(get_learned_skills_count)"
  pcnt="$(get_learned_pending_count)"

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s🧠 บทเรียนสะสมเฉพาะโปรเจกต์ (RELAY Self-Learning)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s  • ใช้งานอยู่ (ส่งให้ AI) : %s ข้อ ใน .relay/skills/project-learned/SKILL.md\n" "$C_ACCENT" "$C_RESET" "$cnt"
  if [ "$pcnt" -gt 0 ]; then
    printf "%s│%s  • %sรออนุมัติ            : %s ข้อ ใน PENDING.md (ยังไม่ถูกส่งให้ AI)%s\n" "$C_ACCENT" "$C_RESET" "$C_WARN" "$pcnt" "$C_RESET"
  else
    printf "%s│%s  • รออนุมัติ            : 0 ข้อ\n" "$C_ACCENT" "$C_RESET"
  fi
  printf "%s│%s  • ขอบเขตปลอดภัย : แก้ไขเฉพาะไฟล์ในโปรเจกต์นี้ ไม่แตะต้อง GLOBAL_AGENTS.md\n" "$C_ACCENT" "$C_RESET"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  local default_idx=0
  [ "$pcnt" -eq 0 ] && default_idx=1
  interactive_menu "เลือกคำสั่งจัดการบทเรียนสะสม (/learn)" "$default_idx" \
    "1|★ ทบทวนและอนุมัติกฎที่รออนุมัติ (${pcnt} ข้อ)" \
    "2|สกัดกฎที่เสนอจากใบงานปัจจุบัน/ล่าสุดเข้าคิวรออนุมัติ" \
    "3|ดูกฎที่ใช้งานอยู่ (SKILL.md)" \
    "4|ดูประวัติการเสนอ/อนุมัติทั้งหมด (LEDGER.md)" \
    "b|กลับสู่หน้าจอหลัก"

  case "$MENU_RESULT" in
    1) review_pending_learned_rules ;;
    2) distill_project_learned_skills "$ACTIVE_TASK" "interactive" || true ;;
    3)
      echo ""
      if [ -f "$skill_file" ]; then cat "$skill_file"; else printf "%sยังไม่มีกฎที่อนุมัติแล้ว%s\n" "$C_MUTED" "$C_RESET"; fi
      ;;
    4)
      echo ""
      if [ -f "$ledger_file" ]; then cat "$ledger_file"; else printf "%sยังไม่มีประวัติ%s\n" "$C_MUTED" "$C_RESET"; fi
      ;;
    *) return 0 ;;
  esac
  if [ -t 0 ]; then
    read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
  fi
}

# ─── 13.6 ระบบรันลูปอัตโนมัติแบบมีเบรกนิรภัย 3 ชั้น (Bounded Auto-Relay Loop) ──
# รันคำสั่งพร้อมเพดานเวลา (macOS ไม่มีคำสั่ง timeout มาให้) — คืนค่า 124 เมื่อหมดเวลา, 130 เมื่อผู้ใช้กด Ctrl+C
run_with_timeout() {
  local secs="$1"
  shift
  local marker
  marker="$(mktemp -t relay-timeout.XXXXXX 2>/dev/null || echo "/tmp/relay-timeout.$$")"
  rm -f "$marker" "$marker.int"

  "$@" </dev/null &
  local pid=$!
  ( sleep "$secs"; touch "$marker"; kill -TERM "$pid" 2>/dev/null; sleep 5; kill -KILL "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local wd=$!

  trap 'touch "$marker.int"; kill -TERM "$pid" 2>/dev/null' INT TERM
  local rc=0
  wait "$pid" || rc=$?
  if kill -0 "$pid" 2>/dev/null; then
    wait "$pid" 2>/dev/null || true
  fi
  trap - INT TERM

  pkill -P "$wd" 2>/dev/null || true
  kill "$wd" 2>/dev/null || true
  wait "$wd" 2>/dev/null || true

  if [ -e "$marker.int" ]; then
    rc=130
  elif [ -e "$marker" ]; then
    rc=124
  fi
  rm -f "$marker" "$marker.int"
  return "$rc"
}

exec_provider_autonomous() {
  local provider="$1"
  local configured_model="$2"
  local role_name="$3"
  local work_dir="$4"
  local prompt="$5"
  local step_timeout="${RELAY_STEP_TIMEOUT:-1800}"
  [[ "$step_timeout" =~ ^[0-9]+$ ]] || step_timeout=1800

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s ⚡ [Auto-Relay Loop] กำลังรัน %s%s%s แบบอัตโนมัติ\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$role_name" "$C_RESET"
  printf "%s│%s  • ค่ายผู้ให้บริการ : %s (%s) │ เพดานเวลา: %s นาที\n" "$C_ACCENT" "$C_RESET" "$provider" "$configured_model" "$((step_timeout / 60))"
  printf "%s│%s  • โฟลเดอร์ทำงาน  : %s\n" "$C_ACCENT" "$C_RESET" "$work_dir"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  # โหมดสิทธิ์แบบไม่ต้องถามโต้ตอบ แต่ไม่ข้ามระบบสิทธิ์ทั้งหมด
  local cmd=()
  case "$provider" in
    agy)    cmd=(agy --model "$configured_model" --mode auto -p "$prompt") ;;
    claude) cmd=(claude --model "$configured_model" --permission-mode acceptEdits -p "$prompt") ;;
    codex)  cmd=(codex exec --full-auto --skip-git-repo-check -m "$configured_model" "$prompt") ;;
    *)
      printf "%s✖ ไม่รู้จักค่าย '%s'%s\n" "$C_ERR" "$provider" "$C_RESET"
      return 2
      ;;
  esac

  local rc=0 run_start q_before
  run_start="$(date +%s)"
  q_before="$(get_role_quota_pair "$provider" "$configured_model")"
  ( cd "$work_dir" && run_with_timeout "$step_timeout" "${cmd[@]}" ) || rc=$?

  refresh_quota_cache --quiet
  append_run_log "auto" "$role_name" "$provider" "$configured_model" "$rc" "$run_start" "$(date +%s)" "$q_before" "$(get_role_quota_pair "$provider" "$configured_model")"
  return "$rc"
}

# ตัดสินผลตรวจรับ: อ่าน QA_VERDICT.json ก่อน (PASS ต้องไม่มี failed_criteria) ถ้าไม่มีจึงใช้ VERDICT ใน QA_REPORT.md เป็นทางสำรอง
# คืนค่า "<PASS|FAIL|NONE|MISSING>|<json|invalid-json|md|->"
qa_verdict() {
  local d="$1"
  local json="$d/QA_VERDICT.json"
  local md="$d/QA_REPORT.md"
  if [ -f "$json" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "$json" <<'PYEOF'
import json, sys
try:
    o = json.load(open(sys.argv[1], encoding="utf-8"))
    v = str(o.get("verdict", "")).strip().upper()
    fc = o.get("failed_criteria") or []
    if v == "PASS" and not fc:
        print("PASS|json")
    elif v in ("PASS", "FAIL"):
        print("FAIL|json")
    else:
        print("NONE|invalid-json")
except Exception:
    print("NONE|invalid-json")
PYEOF
    return
  fi
  if [ ! -f "$md" ]; then
    echo "MISSING|-"
  elif grep -qiE 'VERDICT[^A-Za-z0-9]{0,6}FAIL' "$md"; then
    echo "FAIL|md"
  elif grep -qiE 'VERDICT[^A-Za-z0-9]{0,6}PASS' "$md"; then
    echo "PASS|md"
  else
    echo "NONE|md"
  fi
}

# ย้ายผลตรวจรับเดิมออกก่อน @qa รอบใหม่ เพื่อไม่ให้ผลเก่าถูกนับซ้ำ
archive_old_qa_outputs() {
  local round="$1"
  shift
  local d
  for d in "$@"; do
    [ -f "$d/QA_REPORT.md" ] && mv "$d/QA_REPORT.md" "$d/QA_REPORT.before-round-${round}.md"
    [ -f "$d/QA_VERDICT.json" ] && mv "$d/QA_VERDICT.json" "$d/QA_VERDICT.before-round-${round}.json"
  done
  return 0
}

# ข้อกำหนดผลลัพธ์ของ @qa (ใช้ร่วมกันในขั้นตอนที่ 4 และ Auto-Loop)
get_qa_prompt_contract() {
  printf ' จากนั้นต้องเขียนไฟล์ .relay/tasks/%s/QA_VERDICT.json เป็น JSON รูปแบบ {"verdict": "PASS" หรือ "FAIL", "failed_criteria": ["เกณฑ์ที่ไม่ผ่าน"], "tests_run": ["คำสั่งทดสอบที่รันจริง"], "summary": "สรุปสั้น"} โดยให้ PASS ได้เฉพาะเมื่อ failed_criteria ว่าง และห้ามแก้ไขไฟล์ .relay/PROJECT_STATE.md' "$ACTIVE_TASK"
}

verdict_source_note() {
  case "$1" in
    md) printf " (ไม่มี QA_VERDICT.json — ใช้ VERDICT ใน QA_REPORT.md เป็นทางสำรอง)" ;;
    invalid-json) printf " (QA_VERDICT.json รูปแบบไม่ถูกต้อง)" ;;
  esac
}

LOOP_LOG_FILE=""
loop_halt() {
  local reason="$1"
  [ -n "$LOOP_LOG_FILE" ] && echo "- [STOP] ${reason} (\`$(date '+%H:%M:%S')\`)" >> "$LOOP_LOG_FILE"
  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ERR" "$C_RESET"
  printf "%s│%s %s🛑 หยุด Auto-Relay Loop:%s %s\n" "$C_ERR" "$C_RESET" "$C_BOLD" "$C_RESET" "$reason"
  printf "%s│%s  • บันทึกลูป : .relay/tasks/%s/LOOP_LOG.md\n" "$C_ERR" "$C_RESET" "$ACTIVE_TASK"
  printf "%s│%s  • งานที่ทำไปแล้วยังอยู่ครบใน Worktree — แก้ไขสาเหตุแล้วกด [a] เพื่อรันต่อ หรือทำทีละขั้นด้วย [2]/[3]/[4]\n" "$C_ERR" "$C_RESET"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ERR" "$C_RESET"
  if [ -t 0 ]; then
    read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
  fi
}

# แปลง exit code ของ agent เป็นเหตุผลการหยุดลูป (คืนค่า 1 เมื่อต้องหยุด)
loop_check_rc() {
  local rc="$1"
  local label="$2"
  case "$rc" in
    0) return 0 ;;
    124) loop_halt "${label} ทำงานเกินเพดานเวลา (${RELAY_STEP_TIMEOUT:-1800} วินาที)" ;;
    130) loop_halt "ผู้ใช้ยกเลิกระหว่าง ${label}" ;;
    *) loop_halt "${label} จบการทำงานด้วยข้อผิดพลาด (exit ${rc}) — อาจเกิดจากโควต้าหมด เครือข่าย หรือสิทธิ์ไม่พอ" ;;
  esac
  return 1
}

run_auto_relay_loop() {
  require_all_roles_ready || return 0
  refresh_project_paths
  get_active_task

  if [ -z "$ACTIVE_TASK" ] || [ ! -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ]; then
    echo ""
    printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_WARN" "$C_RESET"
    printf "%s│%s %s▲ ต้องมีเอกสาร SPEC.md จากขั้นตอนที่ 1 (@po) ก่อนเริ่มรัน Auto-Relay Loop!%s\n" "$C_WARN" "$C_RESET" "$C_BOLD" "$C_RESET"
    printf "%s│%s  • เหตุผล : เพื่อให้มนุษย์เป็นผู้กำหนดทิศทางและขอบเขตงาน (Human-Anchored SPEC.md)\n" "$C_WARN" "$C_RESET"
    printf "%s│%s  • คำแนะนำ: กรุณากด [1] เพื่อสร้าง SPEC.md ร่วมกับ @po ก่อน แล้วจึงกด [a] รันลูปอัตโนมัติ\n" "$C_WARN" "$C_RESET"
    printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_WARN" "$C_RESET"
    if [ -t 0 ]; then
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
    fi
    return 1
  fi

  local max_rounds=3
  local min_quota_pct=20
  local step_timeout="${RELAY_STEP_TIMEOUT:-1800}"
  local task_dir="$RELAY_DIR/tasks/$ACTIVE_TASK"
  LOOP_LOG_FILE="$task_dir/LOOP_LOG.md"
  local learned_note commit_note
  learned_note="$(get_learned_skills_prompt_note)"
  commit_note="$(get_dev_commit_note)"

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s⚡ ยืนยันการเริ่มทำงานโหมด Bounded Auto-Relay Loop (ขั้นตอนที่ 2 ➔ 3 ⇄ 4)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s  • ใบงานเป้าหมาย          : %s%s%s (มี SPEC.md พร้อมแล้ว)\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$ACTIVE_TASK" "$C_RESET"
  printf "%s│%s  • ขั้นที่ 2 (@arch/@pm)    : %s (%s)\n" "$C_ACCENT" "$C_RESET" "$ROLE_ARCH" "$MODEL_ARCH"
  printf "%s│%s  • ขั้นที่ 3 (@dev Worktree): %s (%s)\n" "$C_ACCENT" "$C_RESET" "$ROLE_DEV" "$MODEL_DEV"
  printf "%s│%s  • ขั้นที่ 4 (@qa Verifier) : %s (%s)\n" "$C_ACCENT" "$C_RESET" "$ROLE_QA" "$MODEL_QA"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s  %sระบบเบรกนิรภัย (Circuit Breakers):%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s   1. Quota Guard        : หยุดทันทีหากโควต้า 5h หรือ 7d ของตำแหน่งถัดไปต่ำกว่า %s%%\n" "$C_ACCENT" "$C_RESET" "$min_quota_pct"
  printf "%s│%s   2. Max Loop Cap       : วนแก้บั๊ก (@dev ⇄ @qa) สูงสุด %s รอบ\n" "$C_ACCENT" "$C_RESET" "$max_rounds"
  printf "%s│%s   3. Cross-Provider QA  : ผ่านเฉพาะเมื่อ QA_REPORT.md มี VERDICT: PASS ชัดเจน\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s   4. Step Guard         : หยุดเมื่อ agent error / ไม่สร้างไฟล์ผลลัพธ์ / เกิน %s นาทีต่อขั้น\n" "$C_ACCENT" "$C_RESET" "$((step_timeout / 60))"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  if [ "${1:-interactive}" != "--yes" ]; then
    interactive_menu "ต้องการเริ่มรัน Bounded Auto-Relay Loop สำหรับใบงาน '${ACTIVE_TASK}' เลยหรือไม่?" 0 \
      "y|★ เริ่มรันลูปอัตโนมัติทันที (2 ➔ 3 ⇄ 4 พร้อมเบรกนิรภัยครบทุกชั้น)" \
      "n|ยกเลิก — กลับสู่หน้าจอหลัก"
    [ "$MENU_RESULT" != "y" ] && return 0
  fi

  printf "%sกำลังดึงข้อมูลโควต้าสดล่าสุดก่อนเริ่มลูป...%s\n" "$C_MUTED" "$C_RESET"
  refresh_quota_cache

  {
    echo "# บันทึกการทำงานอัตโนมัติ (Bounded Auto-Relay Loop Log — $ACTIVE_TASK)"
    echo ""
    echo "- เริ่มต้นลูปเมื่อ: \`$(date '+%Y-%m-%d %H:%M:%S')\`"
    echo "- เกณฑ์เบรกโควต้าขั้นต่ำ: \`${min_quota_pct}%\` │ จำนวนรอบสูงสุด: \`${max_rounds} รอบ\` │ เพดานเวลาต่อขั้น: \`${step_timeout} วินาที\`"
    echo ""
  } > "$LOOP_LOG_FILE"

  local rc=0
  local loop_started_at
  loop_started_at="$(date +%s)"

  # 1. ขั้นตอนที่ 2 (@arch & @pm) หากยังไม่มี PLAN.md
  if [ ! -f "$task_dir/PLAN.md" ]; then
    if ! check_role_quota_safe "$ROLE_ARCH" "$MODEL_ARCH" "@arch & @pm" "$min_quota_pct"; then
      loop_halt "โควต้าของ @arch ต่ำกว่า ${min_quota_pct}%"
      return 1
    fi
    local arch_prompt="@arch @pm กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md ร่วมกับ .relay/tasks/$ACTIVE_TASK/SPEC.md${learned_note} แล้วสร้างไฟล์ .relay/tasks/$ACTIVE_TASK/ARCH.md และ .relay/tasks/$ACTIVE_TASK/PLAN.md ให้เสร็จสมบูรณ์โดยไม่ต้องรอถามโต้ตอบ"
    rc=0
    exec_provider_autonomous "$ROLE_ARCH" "$MODEL_ARCH" "ขั้นตอนที่ 2: @arch & @pm" "$PROJECT_DIR" "$arch_prompt" || rc=$?
    loop_check_rc "$rc" "ขั้นตอนที่ 2 (@arch)" || return 1
    if [ ! -f "$task_dir/PLAN.md" ]; then
      loop_halt "@arch ทำงานจบแต่ไม่ได้สร้าง .relay/tasks/$ACTIVE_TASK/PLAN.md"
      return 1
    fi
    echo "- [x] ขั้นตอนที่ 2 (@arch/@pm): สร้าง ARCH.md & PLAN.md เรียบร้อย (\`$(date '+%H:%M:%S')\`)" >> "$LOOP_LOG_FILE"
    LAST_COMPLETED_PHASE=2
  else
    echo "- [x] ขั้นตอนที่ 2 (@arch/@pm): พบไฟล์ PLAN.md อยู่แล้ว ข้ามไปยังขั้นตอนที่ 3" >> "$LOOP_LOG_FILE"
  fi

  # เตรียม Git Worktree (หยุดทันทีถ้าสร้างไม่ได้ — ห้ามแก้โค้ดบนกิ่งหลัก)
  if ! prepare_task_worktree; then
    loop_halt "สร้าง Git Worktree ไม่สำเร็จ"
    return 1
  fi
  local worktree_dir="$TASK_WORK_DIR"
  local wt_task_dir="$worktree_dir/.relay/tasks/$ACTIVE_TASK"

  # 2. วนลูป @dev ⇄ @qa สูงสุดไม่เกิน max_rounds รอบ
  local round=1
  local loop_passed=0
  while [ "$round" -le "$max_rounds" ]; do
    echo ""
    printf "%s═══ ⚡ [Auto-Relay Loop] รอบที่ %d/%d : ขั้นตอนที่ 3 (@dev) ⇄ ขั้นตอนที่ 4 (@qa) ═══%s\n" "$C_SEL" "$round" "$max_rounds" "$C_RESET"

    if ! check_role_quota_safe "$ROLE_DEV" "$MODEL_DEV" "@dev (รอบที่ $round/$max_rounds)" "$min_quota_pct"; then
      loop_halt "โควต้าของ @dev ต่ำกว่า ${min_quota_pct}% (รอบที่ $round)"
      return 1
    fi

    local dev_prompt=""
    if [ "$round" -eq 1 ]; then
      dev_prompt="@dev กรุณาอ่านเอกสาร .relay/tasks/$ACTIVE_TASK/SPEC.md, ARCH.md และ PLAN.md${learned_note} แล้วลงมือพัฒนาโค้ดและรันชุดทดสอบให้ครบทุกข้อโดยไม่ต้องรอถามโต้ตอบ${commit_note}"
    else
      dev_prompt="@dev การตรวจรับรอบก่อนหน้าไม่ผ่าน กรุณาอ่านข้อบกพร่องในไฟล์ .relay/tasks/$ACTIVE_TASK/QA_REPORT.md ร่วมกับ SPEC.md และ PLAN.md${learned_note} แล้วแก้ไขโค้ดและชุดทดสอบให้ผ่านครบทุกจุดโดยไม่ต้องรอถามโต้ตอบ${commit_note}"
    fi

    rc=0
    exec_provider_autonomous "$ROLE_DEV" "$MODEL_DEV" "ขั้นตอนที่ 3: @dev (รอบที่ $round/$max_rounds)" "$worktree_dir" "$dev_prompt" || rc=$?
    loop_check_rc "$rc" "ขั้นตอนที่ 3 (@dev รอบที่ $round)" || return 1
    LAST_COMPLETED_PHASE=3

    if ! check_role_quota_safe "$ROLE_QA" "$MODEL_QA" "@qa & @sec (รอบที่ $round/$max_rounds)" "$min_quota_pct"; then
      loop_halt "โควต้าของ @qa ต่ำกว่า ${min_quota_pct}% (รอบที่ $round)"
      return 1
    fi

    # ย้ายผลตรวจรับเก่าออก เพื่อไม่ให้ผลรอบก่อนถูกนับเป็นผลของรอบนี้
    archive_old_qa_outputs "$round" "$wt_task_dir" "$task_dir"

    local qa_prompt="@qa @sec กรุณาตรวจสอบผลงานในโฟลเดอร์นี้เทียบกับเกณฑ์ Acceptance Criteria ในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md${learned_note} โดยรันคำสั่งทดสอบจริงผ่าน Terminal ตรวจสอบ git diff และเขียนรายงานสรุปลงในไฟล์ .relay/tasks/$ACTIVE_TASK/QA_REPORT.md โดยต้องมีบรรทัด 'VERDICT: PASS' หากผ่านครบทุกข้อ หรือ 'VERDICT: FAIL' พร้อมรายการจุดที่ต้องแก้ไขหากยังไม่ผ่าน (ใส่เพียงบรรทัดเดียว)$(get_qa_prompt_contract)"
    rc=0
    exec_provider_autonomous "$ROLE_QA" "$MODEL_QA" "ขั้นตอนที่ 4: @qa & @sec (รอบที่ $round/$max_rounds)" "$worktree_dir" "$qa_prompt" || rc=$?
    loop_check_rc "$rc" "ขั้นตอนที่ 4 (@qa รอบที่ $round)" || return 1

    if [ -d "$wt_task_dir" ]; then
      sync_task_docs_from_worktree "$wt_task_dir" "$task_dir"
    fi
    LAST_COMPLETED_PHASE=4

    local vres verdict vnote
    vres="$(qa_verdict "$task_dir")"
    verdict="${vres%%|*}"
    vnote="$(verdict_source_note "${vres#*|}")"
    case "$verdict" in
      PASS)
        echo "- [PASS] รอบที่ $round/$max_rounds: @qa ระบุ VERDICT: PASS${vnote} (\`$(date '+%H:%M:%S')\`)" >> "$LOOP_LOG_FILE"
        loop_passed=1
        break
        ;;
      FAIL)
        echo "- [RETRY] รอบที่ $round/$max_rounds: @qa ระบุ VERDICT: FAIL${vnote} (\`$(date '+%H:%M:%S')\`)" >> "$LOOP_LOG_FILE"
        ;;
      NONE)
        echo "- [RETRY] รอบที่ $round/$max_rounds: ไม่มี VERDICT ที่ชัดเจน${vnote} — ไม่นับว่าผ่าน (\`$(date '+%H:%M:%S')\`)" >> "$LOOP_LOG_FILE"
        ;;
      *)
        loop_halt "@qa ทำงานจบแต่ไม่ได้เขียน QA_REPORT.md หรือ QA_VERDICT.json (รอบที่ $round)"
        return 1
        ;;
    esac

    round=$((round + 1))
  done

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  print_loop_run_summary "$loop_started_at"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  if [ "$loop_passed" -eq 1 ]; then
    printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_OK" "$C_RESET"
    printf "%s│%s %s● [Auto-Relay Loop สำเร็จ!] @qa ระบุ VERDICT: PASS ในรอบที่ %d/%d%s\n" "$C_OK" "$C_RESET" "$C_BOLD" "$round" "$max_rounds" "$C_RESET"
    printf "%s│%s  • บันทึกลูปการทำงาน : .relay/tasks/%s/LOOP_LOG.md\n" "$C_OK" "$C_RESET" "$ACTIVE_TASK"
    printf "%s│%s  • ขั้นตอนถัดไป     : กด [5] เพื่อตรวจ commit, ผสานโค้ดเข้า main, สกัดบทเรียน และปิดใบงาน\n" "$C_OK" "$C_RESET"
    printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_OK" "$C_RESET"
  else
    echo "- [STOP] ครบเพดาน ${max_rounds} รอบโดยยังไม่ผ่าน (\`$(date '+%H:%M:%S')\`)" >> "$LOOP_LOG_FILE"
    printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_WARN" "$C_RESET"
    printf "%s│%s %s▲ [Circuit Breaker: ครบเพดาน %d รอบ] หยุดลูปอัตโนมัติเพื่อให้คุณตรวจสอบร่วมตัดสินใจ%s\n" "$C_WARN" "$C_RESET" "$C_BOLD" "$max_rounds" "$C_RESET"
    printf "%s│%s  • กรุณาตรวจสอบรายละเอียดใน .relay/tasks/%s/QA_REPORT.md และ LOOP_LOG.md\n" "$C_WARN" "$C_RESET" "$ACTIVE_TASK"
    printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_WARN" "$C_RESET"
  fi

  if [ -t 0 ]; then
    read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
  fi
}

# ─── 13.7 ขั้นตอนที่ 5: ผสานโค้ดอย่างปลอดภัย (ไม่ลบอะไรจนกว่าจะผสานสำเร็จ) ────────
# บันทึกใบงานที่ผสานแล้วลง PROJECT_STATE.md (เก็บล่าสุด 15 รายการ) — เรียกหลังผสานสำเร็จเท่านั้น
record_task_in_project_state() {
  local task="$1"
  local commit="$2"
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$RELAY_DIR/PROJECT_STATE.md" "$RELAY_DIR/tasks/$task/SPEC.md" "$task" "$commit" <<'PYEOF' || true
import os, re, sys, datetime
ps, spec, task, commit = sys.argv[1:5]
title = task
if os.path.exists(spec):
    for line in open(spec, encoding="utf-8", errors="ignore"):
        if line.startswith("# "):
            title = line[2:].strip()
            break
title = re.sub(r"\s+", " ", title)[:120]
entry = f"- `{datetime.date.today().isoformat()}` `{task}` — {title} (merge `{commit}`)"
H = "## ประวัติใบงานที่ผสานแล้ว (RELAY อัปเดตอัตโนมัติ)"
txt = open(ps, encoding="utf-8").read() if os.path.exists(ps) else "# สถานะปัจจุบันของโครงการ (PROJECT_STATE.md)\n"
if H in txt:
    before, after = txt.split(H, 1)
    m = re.search(r"\n## ", after)
    section = after[:m.start()] if m else after
    rest = after[m.start():] if m else ""
    items = [l for l in section.splitlines() if l.startswith("- ") and f"`{task}`" not in l]
    items = ([entry] + items)[:15]
    txt = before + H + "\n" + "\n".join(items) + "\n" + rest
else:
    txt = txt.rstrip("\n") + "\n\n" + H + "\n" + entry + "\n"
open(ps, "w", encoding="utf-8").write(txt)
PYEOF
}

archive_active_task() {
  mkdir -p "$RELAY_DIR/archive"
  local dest="$RELAY_DIR/archive/$ACTIVE_TASK"
  [ -e "$dest" ] && dest="${dest}-$(date +%H%M%S)"
  mv "$RELAY_DIR/tasks/$ACTIVE_TASK" "$dest"
  CURRENT_TASK=""
  LAST_COMPLETED_PHASE=0
}

run_phase_5_merge() {
  require_all_roles_ready || return 0
  refresh_project_paths
  get_active_task
  if [ -z "$ACTIVE_TASK" ]; then
    printf "%s▲ ยังไม่มีใบงานที่กำลังดำเนินการใน .relay/tasks/%s\n" "$C_ERR" "$C_RESET"
    return
  fi
  local task="$ACTIVE_TASK"
  local branch_name="feat/$task"
  local worktree_dir="$RELAY_DIR/worktrees/$task"
  local task_dir="$RELAY_DIR/tasks/$task"

  # กรณีไม่มีกิ่งโค้ดของใบงาน (เช่น ใบงานเอกสารล้วน หรือยังไม่ผ่านขั้นตอนที่ 3)
  if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1 || ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$branch_name"; then
    interactive_menu "ใบงาน ${task} ไม่มีกิ่งโค้ด ${branch_name} — ต้องการปิดใบงานโดยไม่ผสานโค้ดหรือไม่?" 1 \
      "y|ปิดใบงาน: สกัดบทเรียน + ย้ายเข้า .relay/archive/ (ไม่มีโค้ดให้ผสาน)" \
      "n|ยกเลิก — กลับสู่หน้าจอหลัก"
    if [ "$MENU_RESULT" = "y" ]; then
      distill_project_learned_skills "$task" "auto" || true
      archive_active_task
      printf "%s● ปิดใบงานและย้ายไปที่ .relay/archive/%s เรียบร้อยแล้ว%s\n" "$C_OK" "$task" "$C_RESET"
    fi
    return 0
  fi

  local base
  base="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  if [ -z "$base" ] || [ "$base" = "HEAD" ] || [ "$base" = "$branch_name" ]; then
    printf "\n%s✖ โฟลเดอร์โปรเจกต์ไม่ได้อยู่บนกิ่งหลัก (ปัจจุบัน: %s) — กรุณา git checkout main ก่อนกด [5]%s\n" "$C_ERR" "${base:-ไม่ทราบ}" "$C_RESET"
    return 1
  fi

  # ดึงเอกสารล่าสุดจาก Worktree กลับมาที่ใบงานหลักก่อน
  if [ -d "$worktree_dir/.relay/tasks/$task" ]; then
    sync_task_docs_from_worktree "$worktree_dir/.relay/tasks/$task" "$task_dir"
  fi

  local qa_res qa_v
  qa_res="$(qa_verdict "$task_dir")"
  qa_v="${qa_res%%|*}"

  local dirty dirty_count ahead
  dirty="$(worktree_dirty_files "$worktree_dir")"
  dirty_count="$(printf "%s" "$dirty" | grep -c . || true)"
  ahead="$(git -C "$PROJECT_DIR" rev-list --count "${base}..${branch_name}" 2>/dev/null || echo 0)"

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %sตรวจสอบก่อนผสานโค้ด (ขั้นตอนที่ 5)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s  • ผสานจากกิ่ง  : %s ➔ เข้ากิ่ง %s%s%s\n" "$C_ACCENT" "$C_RESET" "$branch_name" "$C_BOLD" "$base" "$C_RESET"
  printf "%s│%s  • commit ใหม่   : %s commit\n" "$C_ACCENT" "$C_RESET" "$ahead"
  if [ "$qa_v" = "PASS" ]; then
    printf "%s│%s  • ผลตรวจรับ    : %sPASS%s%s\n" "$C_ACCENT" "$C_RESET" "$C_OK" "$C_RESET" "$(verdict_source_note "${qa_res#*|}")"
  else
    printf "%s│%s  • ผลตรวจรับ    : %s%s — ยังไม่ผ่านการตรวจรับจาก @qa%s\n" "$C_ACCENT" "$C_RESET" "$C_WARN" "$qa_v" "$C_RESET"
  fi
  if [ "$dirty_count" -gt 0 ]; then
    printf "%s│%s  • %sไฟล์ที่ยังไม่ commit ใน Worktree : %s ไฟล์ (ไม่นับ .relay/)%s\n" "$C_ACCENT" "$C_RESET" "$C_WARN" "$dirty_count" "$C_RESET"
    printf "%s\n" "$dirty" | head -n 8 | sed "s/^/${C_ACCENT}│${C_RESET}      /"
  else
    printf "%s│%s  • ไฟล์ค้างใน Worktree : ไม่มี\n" "$C_ACCENT" "$C_RESET"
  fi
  if [ "$base" != "main" ] && [ "$base" != "master" ]; then
    printf "%s│%s  %s▲ กิ่งปลายทางไม่ใช่ main/master — ระบบจะถามยืนยันอีกครั้ง%s\n" "$C_ACCENT" "$C_RESET" "$C_WARN" "$C_RESET"
  fi
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  local items=()
  if [ "$dirty_count" -gt 0 ]; then
    items+=("c|★ commit ไฟล์ที่ค้าง ${dirty_count} ไฟล์ใน Worktree (ไม่รวม .relay/) แล้วผสานเข้า ${base}")
  elif [ "$ahead" -gt 0 ]; then
    items+=("y|★ ผสาน ${ahead} commit เข้า ${base} ➔ สกัดบทเรียน ➔ ปิดใบงาน")
  else
    printf "%s▲ กิ่ง %s ไม่มีโค้ดใหม่ให้ผสาน — ระบบจะไม่ลบ Worktree หรือกิ่งใดๆ%s\n" "$C_WARN" "$branch_name" "$C_RESET"
    items+=("a|ปิดใบงานโดยไม่ผสาน (เก็บกิ่งและ Worktree ไว้ตรวจสอบภายหลัง)")
  fi
  items+=("n|ยกเลิก — กลับสู่หน้าจอหลัก (ไม่มีการเปลี่ยนแปลงใดๆ)")

  interactive_menu "เลือกการดำเนินการสำหรับใบงาน ${task}" 0 "${items[@]}"

  case "$MENU_RESULT" in
    c|C)
      local commit_out=""
      if ! commit_out="$( { git -C "$worktree_dir" add -A -- . ':(exclude).relay' && git -C "$worktree_dir" commit -m "feat(${task}): งานจาก @dev (RELAY auto-commit ก่อนผสาน)"; } 2>&1 )"; then
        printf "\n%s✖ commit ใน Worktree ไม่สำเร็จ — ยังไม่มีการผสานหรือลบใดๆ:%s\n%s\n" "$C_ERR" "$C_RESET" "$(printf "%s" "$commit_out" | tail -n 8)"
        return 1
      fi
      printf "%s● commit ไฟล์ใน Worktree เรียบร้อย%s\n" "$C_OK" "$C_RESET"
      ;;
    y|Y) ;;
    a|A)
      distill_project_learned_skills "$task" "auto" || true
      archive_active_task
      printf "%s● ปิดใบงานแล้ว (กิ่ง %s และ Worktree ยังเก็บไว้)%s\n" "$C_OK" "$branch_name" "$C_RESET"
      return 0
      ;;
    *) return 0 ;;
  esac

  if [ "$qa_v" != "PASS" ]; then
    interactive_menu "ใบงานนี้ยังไม่ผ่านการตรวจรับ (${qa_v}) — ยืนยันจะผสานเข้า ${base} หรือไม่?" 1 \
      "y|ยืนยันผสานแม้ยังไม่ผ่าน QA (รับผิดชอบเอง)" \
      "n|ยกเลิก — กลับไปแก้ไขก่อน"
    [ "$MENU_RESULT" != "y" ] && return 0
  fi

  if [ "$base" != "main" ] && [ "$base" != "master" ]; then
    interactive_menu "ยืนยันผสานเข้ากิ่ง '${base}' (ไม่ใช่ main/master)?" 1 \
      "y|ยืนยันผสานเข้า ${base}" \
      "n|ยกเลิก"
    [ "$MENU_RESULT" != "y" ] && return 0
  fi

  local merge_out=""
  if ! merge_out="$(git -C "$PROJECT_DIR" merge --no-ff "$branch_name" -m "merge: ${branch_name} (RELAY ${task})" 2>&1)"; then
    git -C "$PROJECT_DIR" merge --abort >/dev/null 2>&1 || true
    echo ""
    printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ERR" "$C_RESET"
    printf "%s│%s %s✖ ผสานโค้ดไม่สำเร็จ — ยกเลิกการผสานแล้ว (ไม่มีไฟล์ใดถูกลบ)%s\n" "$C_ERR" "$C_RESET" "$C_BOLD" "$C_RESET"
    printf "%s\n" "$merge_out" | head -n 10 | sed "s/^/${C_ERR}│${C_RESET}   /"
    printf "%s│%s  • Worktree (.relay/worktrees/%s) และใบงานยังอยู่ครบ\n" "$C_ERR" "$C_RESET" "$task"
    printf "%s│%s  • วิธีแก้: เข้า Worktree แล้ว git merge %s เพื่อแก้ conflict และ commit จากนั้นกด [5] อีกครั้ง\n" "$C_ERR" "$C_RESET" "$base"
    printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ERR" "$C_RESET"
    return 1
  fi
  printf "%s● ผสาน %s เข้า %s สำเร็จ%s\n" "$C_OK" "$branch_name" "$base" "$C_RESET"

  record_task_in_project_state "$task" "$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "-")"
  distill_project_learned_skills "$task" "auto" || true

  # ลบ Worktree เฉพาะเมื่อไม่มีไฟล์โค้ดค้าง (ไฟล์ใน .relay/ เป็นสำเนาที่ดึงกลับมาแล้ว)
  if [ -d "$worktree_dir" ]; then
    if [ -n "$(worktree_dirty_files "$worktree_dir")" ]; then
      printf "%s▲ ยังมีไฟล์ค้างใน Worktree — เก็บ .relay/worktrees/%s ไว้ให้ตรวจสอบ%s\n" "$C_WARN" "$task" "$C_RESET"
    else
      git -C "$PROJECT_DIR" worktree remove --force "$worktree_dir" >/dev/null 2>&1 || \
        printf "%s▲ ลบ Worktree ไม่สำเร็จ กรุณาลบเองด้วย git worktree remove%s\n" "$C_WARN" "$C_RESET"
    fi
  fi
  if [ ! -d "$worktree_dir" ]; then
    git -C "$PROJECT_DIR" branch -d "$branch_name" >/dev/null 2>&1 || \
      printf "%s▲ ลบกิ่ง %s ไม่สำเร็จ (ยังเก็บไว้)%s\n" "$C_WARN" "$branch_name" "$C_RESET"
  fi

  archive_active_task
  printf "%s● ผสานโค้ด บันทึกลง PROJECT_STATE.md และย้ายใบงานไปที่ .relay/archive/%s เรียบร้อยแล้ว!%s\n" "$C_OK" "$task" "$C_RESET"
  local pend
  pend="$(get_learned_pending_count)"
  [ "$pend" -gt 0 ] && printf "%s▲ มีกฎที่เสนอจากใบงานนี้ %s ข้อรออนุมัติ — กด [l] เพื่อทบทวนก่อนนำไปใช้%s\n" "$C_WARN" "$pend" "$C_RESET"
  printf "%s• หากโครงสร้างระบบเปลี่ยนมาก ให้ @arch ทบทวนส่วนบนของ .relay/PROJECT_STATE.md ในใบงานถัดไป%s\n" "$C_MUTED" "$C_RESET"
}

run_init_greenfield() {
  refresh_project_paths
  "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" new
}

run_init_brownfield() {
  require_all_roles_ready || return 0
  refresh_project_paths
  "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" existing
  local prompt="@arch ช่วยสำรวจและวิเคราะห์โครงสร้างของโครงการเดิมนี้ทั้งหมด (ประกอบด้วย Tech Stack, โครงสร้างโฟลเดอร์สำคัญ, รูปแบบฐานข้อมูล/Schema, รายการ API หลัก และคำสั่งที่ใช้ในการ Build/Test) แล้วสรุปเขียนทับลงในไฟล์ .relay/PROJECT_STATE.md ให้มีความชัดเจนและกระชับ (ความยาวไม่เกิน 2 หน้า) โดยห้ามแก้ไขไฟล์โค้ดใดๆ ของระบบ"
  launch_provider_cli "$ROLE_ARCH" "$MODEL_ARCH" "การสแกนโครงสร้างโครงการเดิม (@arch)" "$PROJECT_DIR" "$prompt"
}

run_init_project() {
  if [ "$PROJECT_DIR" = "$HOME" ]; then
    select_or_create_project_dir
    return 0
  fi
  interactive_menu "เลือกประเภทโครงการที่ต้องการเตรียมโครงสร้าง .relay/ สำหรับ '${PROJECT_NAME}'" 0 \
    "1|★ โครงการใหม่ตั้งแต่ศูนย์ (Greenfield — สร้างโครงสร้าง .relay/ ทันที)" \
    "2|โครงการเดิมที่มีโค้ดอยู่แล้ว (Brownfield — ให้ @arch สแกนโค้ดสรุปลง PROJECT_STATE.md)" \
    "f|สลับไปโฟลเดอร์โปรเจกต์อื่นในเครื่อง (Switch Project Folder)" \
    "b|ย้อนกลับ"
  case "$MENU_RESULT" in
    1) run_init_greenfield ;;
    2) run_init_brownfield ;;
    f|F) select_or_create_project_dir ;;
  esac
}

run_skills_menu() {
  local skills_cmd="$GLOBAL_DIR/bin/relay-skills"
  [ ! -x "$skills_cmd" ] && skills_cmd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/relay-skills.sh"

  interactive_menu "จัดการและอัปเดตชุดทักษะ (RELAY Modular Skill Packs)" 0 \
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

# ─── 14. รองรับ Subcommands จากบรรทัดคำสั่งโดยตรง ──────────────────────────────
SUBCOMMAND="${1:-hub}"
case "$SUBCOMMAND" in
  status)
    print_dashboard_header
    exit 0
    ;;
  quota|usage)
    run_quota_dashboard "${2:-interactive}"
    exit 0
    ;;
  loop|auto)
    run_auto_relay_loop "${2:-interactive}"
    exit 0
    ;;
  learn|distill)
    run_learned_skills_menu "${2:-interactive}"
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

# ─── 15. Interactive Main Loop (Guided 3-Stage Progressive UX) ────────────────
while true; do
  print_dashboard_header

  if [ "$UX_STAGE" -eq 1 ]; then
    # ═══════════════════════════════════════════════════════════════════════════
    # ขั้นที่ 1/3: ตั้งค่า AI & Login บัญชีให้ครบ 4 ตำแหน่ง
    # ═══════════════════════════════════════════════════════════════════════════
    interactive_menu "ขั้นที่ 1/3: ตั้งค่าค่าย AI, เลือก Model และ Login ให้ครบ 4 ตำแหน่ง (พร้อมใช้งานจริง ${READY_ROLE_COUNT}/4)" 0 \
      "1|★ [แนะนำ] ตั้งค่าด่วนด้วยโควตา Google AI Ultra (agy) + Codex พร้อมใช้ทันที" \
      "2|เลือกค่าย AI และ Model แยกทีละตำแหน่ง (@po, @arch, @dev, @qa)" \
      "3|จัดการการเชื่อมต่อ CLI & Login บัญชี (agy / codex / claude)" \
      "u|เช็กและอัปเดตโควต้าคงเหลือแบบเรียลไทม์ของทุกค่าย (/quota)" \
      "t|ตรวจสอบสถานะความพร้อม Agent & Skills ประจำตำแหน่ง (/test)" \
      "q|ออกจากโปรแกรม (/quit)"

    case "$MENU_RESULT" in
      1) run_quick_preset_menu ;;
      2|c|C|/model|/config) configure_roles_menu ;;
      3|d|D|/connect|/doctor|/login) run_doctor_menu ;;
      u|U|/quota|/usage) run_quota_dashboard ;;
      t|T|/test) run_agent_readiness_test ;;
      s|S|/skills) run_skills_menu ;;
      q|Q|/quit|/exit|exit)
        printf "%sออกจากหน้าจอควบคุม RELAY เรียบร้อย%s\n" "$C_MUTED" "$C_RESET"
        exit 0
        ;;
    esac

  elif [ "$UX_STAGE" -eq 2 ]; then
    # ═══════════════════════════════════════════════════════════════════════════
    # ขั้นที่ 2/3: เตรียมโฟลเดอร์โปรเจกต์ (.relay/PROJECT_STATE.md)
    # ═══════════════════════════════════════════════════════════════════════════
    if [ "$IN_HOME_DIR" -eq 1 ]; then
      interactive_menu "ขั้นที่ 2/3: เลือกหรือสร้างโฟลเดอร์โปรเจกต์ที่จะทำงาน (ปัจจุบันคุณอยู่ใน Home ~)" 0 \
        "1|★ เลือกโฟลเดอร์โปรเจกต์ในเครื่อง หรือสร้างโปรเจกต์ใหม่ทันที (แนะนำ)" \
        "u|เช็กและอัปเดตโควต้าคงเหลือแบบเรียลไทม์ของทุกค่าย (/quota)" \
        "t|ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่งด้วยโควตา Google AI Ultra + Codex (/test)" \
        "c|ตั้งค่าค่าย AI & เปลี่ยน Model ประจำตำแหน่ง (/model)" \
        "d|จัดการการเชื่อมต่อ CLI & Login บัญชี (/connect)" \
        "q|ออกจากโปรแกรม (เพื่อพิมพ์ cd เข้าโฟลเดอร์โปรเจกต์เอง)"

      case "$MENU_RESULT" in
        1|f|F|i|I|/init) select_or_create_project_dir ;;
        u|U|/quota|/usage) run_quota_dashboard ;;
        c|C|m|M|/model|/config) configure_roles_menu ;;
        d|D|/connect|/doctor) run_doctor_menu ;;
        t|T|/test) run_agent_readiness_test ;;
        s|S|/skills) run_skills_menu ;;
        q|Q|/quit|/exit|exit)
          printf "%sออกจากหน้าจอควบคุม RELAY เรียบร้อย%s\n" "$C_MUTED" "$C_RESET"
          exit 0
          ;;
      esac
    else
      interactive_menu "ขั้นที่ 2/3: เตรียมโครงสร้าง .relay/ สำหรับโปรเจกต์ '${PROJECT_NAME}'" 0 \
        "1|★ เริ่มโปรเจกต์ใหม่ตั้งแต่ศูนย์ในโฟลเดอร์นี้ (Greenfield — สร้าง .relay/ ทันที)" \
        "2|นำ RELAY มาใช้กับโปรเจกต์เดิมที่มีโค้ดอยู่แล้ว (Brownfield — ให้ @arch สแกนสร้าง PROJECT_STATE.md)" \
        "f|สลับไปโฟลเดอร์โปรเจกต์อื่นในเครื่อง (Switch Project Folder)" \
        "u|เช็กและอัปเดตโควต้าคงเหลือแบบเรียลไทม์ของทุกค่าย (/quota)" \
        "t|ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่ง (/test)" \
        "c|ตั้งค่าค่าย AI & เปลี่ยน Model ประจำตำแหน่ง (/model)" \
        "q|ออกจากโปรแกรม (/quit)"

      case "$MENU_RESULT" in
        1) run_init_greenfield ;;
        2) run_init_brownfield ;;
        f|F) select_or_create_project_dir ;;
        u|U|/quota|/usage) run_quota_dashboard ;;
        c|C|m|M|/model|/config) configure_roles_menu ;;
        d|D|/connect|/doctor) run_doctor_menu ;;
        t|T|/test) run_agent_readiness_test ;;
        s|S|/skills) run_skills_menu ;;
        q|Q|/quit|/exit|exit)
          printf "%sออกจากหน้าจอควบคุม RELAY เรียบร้อย%s\n" "$C_MUTED" "$C_RESET"
          exit 0
          ;;
      esac
    fi

  else
    # ═══════════════════════════════════════════════════════════════════════════
    # ขั้นที่ 3/3: เริ่มสั่งงานตามใบงาน 1-5 (เลื่อน ❯ ไปยังขั้นตอนถัดไปอัตโนมัติ!)
    # ═══════════════════════════════════════════════════════════════════════════
    p1_label="ขั้นตอนที่ 1 (@po)       — วิเคราะห์ความต้องการและสร้าง SPEC.md (${ROLE_PO}/${MODEL_PO})"
    p2_label="ขั้นตอนที่ 2 (@arch/@pm) — สร้าง ARCH.md & PLAN.md (${ROLE_ARCH}/${MODEL_ARCH})"
    p3_label="ขั้นตอนที่ 3 (@dev)      — แยก Git Worktree และเขียนโค้ด (${ROLE_DEV}/${MODEL_DEV})"
    p4_label="ขั้นตอนที่ 4 (@qa/@sec)  — รันเทสต์ + ตรวจความปลอดภัย + QA_REPORT.md (${ROLE_QA}/${MODEL_QA})"
    p5_label="ขั้นตอนที่ 5 (Merge)     — ตรวจ commit + ผสานโค้ดเข้า main + สกัดบทเรียน + เก็บเข้า .relay/archive/"
    pa_label="⚡ รัน Auto-Relay Loop: ขั้นที่ 2 ➔ 3 ⇄ 4 อัตโนมัติพร้อมเบรกโควต้า 20% (/loop)"
    pl_label="🧠 จัดการและสกัดบทเรียนสะสมเฉพาะโปรเจกต์ (Self-Learning Skills) (/learn)"

    case "$RECOMMENDED_STEP" in
      1) p1_label="★ [แนะนำให้เริ่มที่นี่] ${p1_label}" ;;
      2) p2_label="★ [ขั้นตอนถัดไป] ${p2_label}" ;;
      3) p3_label="★ [ขั้นตอนถัดไป] ${p3_label}" ;;
      4) p4_label="★ [ขั้นตอนถัดไป] ${p4_label}" ;;
      5) p5_label="★ [ขั้นตอนถัดไป] ${p5_label}" ;;
    esac

    default_menu_idx=$((RECOMMENDED_STEP - 1))

    interactive_menu "ขั้นที่ 3/3: เลือกขั้นตอนการทำงานสำหรับโปรเจกต์ '${PROJECT_NAME}'" "$default_menu_idx" \
      "1|${p1_label}" \
      "2|${p2_label}" \
      "3|${p3_label}" \
      "4|${p4_label}" \
      "5|${p5_label}" \
      "a|${pa_label}" \
      "l|${pl_label}" \
      "n|สร้างใบงานใหม่ (New Task) (/new)" \
      "f|สลับไปโฟลเดอร์โปรเจกต์อื่น (Switch Project Folder)" \
      "u|เช็กและอัปเดตโควต้าคงเหลือแบบเรียลไทม์ของทุกค่าย (/quota)" \
      "c|ตั้งค่าค่าย AI & เปลี่ยน Model ประจำตำแหน่ง (/model)" \
      "t|ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่ง (/test)" \
      "d|จัดการการเชื่อมต่อ CLI & Login บัญชี (/connect)" \
      "s|จัดการและอัปเดตชุดทักษะ Skills (/skills)" \
      "q|ออกจากโปรแกรม (/quit)"

    case "$MENU_RESULT" in
      1|/po|/1)             run_phase_1_po ;;
      2|/arch|/pm|/2)       run_phase_2_arch ;;
      3|/dev|/3)            run_phase_3_dev ;;
      4|/qa|/sec|/4)        run_phase_4_qa ;;
      5|/merge|/5)          run_phase_5_merge ;;
      a|A|/loop|/auto)      run_auto_relay_loop ;;
      l|L|/learn|/distill)  run_learned_skills_menu ;;
      n|N|/new)             create_new_task ;;
      f|F)                  select_or_create_project_dir ;;
      i|I|/init)            run_init_project ;;
      u|U|/quota|/usage)    run_quota_dashboard ;;
      c|C|m|M|/model|/config) configure_roles_menu ;;
      d|D|/connect|/doctor|/login) run_doctor_menu ;;
      t|T|/test|/check)     run_agent_readiness_test ;;
      s|S|/skills)          run_skills_menu ;;
      q|Q|/quit|/exit|exit)
        printf "%sออกจากหน้าจอควบคุม RELAY เรียบร้อย%s\n" "$C_MUTED" "$C_RESET"
        exit 0
        ;;
    esac
  fi
done
