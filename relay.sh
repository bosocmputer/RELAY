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
CLI_AUTH_GEMINI=0
CLI_AUTH_CODEX=0
CLI_AUTH_DETAIL_AGY="ยังไม่ได้ Login"
CLI_AUTH_DETAIL_CLAUDE="ยังไม่ได้ Login"
CLI_AUTH_DETAIL_GEMINI="ยังไม่ได้ Login"
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

  # 3. ตรวจสถานะ Login ของ Google Gemini CLI (Legacy API Key)
  CLI_AUTH_GEMINI=0
  CLI_AUTH_DETAIL_GEMINI="ยังไม่ได้ตั้งค่า API Key (แนะนำให้ใช้ค่าย agy สำหรับ Google AI Ultra)"
  if is_provider_installed "gemini"; then
    if [ -n "${GEMINI_API_KEY:-}" ] || [ -n "${GOOGLE_GENAI_USE_VERTEXAI:-}" ] || [ -n "${GOOGLE_GENAI_USE_GCA:-}" ]; then
      CLI_AUTH_GEMINI=1
      CLI_AUTH_DETAIL_GEMINI="Login แล้ว (Environment API Key)"
    elif [ -r "$HOME/.gemini/settings.json" ]; then
      local g_type
      g_type="$(grep -Eo '"selectedType"[[:space:]]*:[[:space:]]*"[^"]+"' "$HOME/.gemini/settings.json" 2>/dev/null | head -n 1 | sed -E 's/.*"([^"]+)"$/\1/' || true)"
      if [ -n "$g_type" ] && [ "$g_type" != "oauth-personal" ]; then
        CLI_AUTH_GEMINI=1
        CLI_AUTH_DETAIL_GEMINI="Login แล้ว (${g_type})"
      fi
    fi
  fi

  # 4. ตรวจสถานะ Login ของ OpenAI Codex CLI
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
    gemini) [ "$CLI_AUTH_GEMINI" -eq 1 ] ;;
    codex)  [ "$CLI_AUTH_CODEX" -eq 1 ] ;;
    *) return 1 ;;
  esac
}

get_provider_auth_detail() {
  local provider="$1"
  case "$provider" in
    agy)    echo "$CLI_AUTH_DETAIL_AGY" ;;
    claude) echo "$CLI_AUTH_DETAIL_CLAUDE" ;;
    gemini) echo "$CLI_AUTH_DETAIL_GEMINI" ;;
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

elif provider == "gemini":
    if cli_def and cli_def != "default":
        add_item(cli_def, "ค่าเริ่มต้นปัจจุบันจาก Gemini CLI (ต้องใช้ Gemini API Key)")
    preferred = [
        ("gemini-2.5-pro", "โมเดลวิเคราะห์เชิงลึก (ต้องใช้ Gemini API Key)"),
        ("gemini-2.5-flash", "โมเดลความเร็วสูง (ต้องใช้ Gemini API Key)"),
        ("gemini-2.5-flash-lite", "โมเดลขนาดเบา (ต้องใช้ Gemini API Key)"),
        ("gemini-3.1-pro", "Gemini 3.1 Pro (ต้องใช้ Gemini API Key)"),
        ("gemini-3.5-flash", "Gemini 3.5 Flash (ต้องใช้ Gemini API Key)"),
    ]
    for m, d in preferred:
        add_item(m, d)

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
      gemini)
        printf "gemini-2.5-pro|Gemini 2.5 Pro (ต้องใช้ Gemini API Key)\ngemini-2.5-flash|Gemini 2.5 Flash\n"
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
}

format_role_status_cell() {
  local provider="$1"
  local model="$2"
  if ! is_provider_installed "$provider"; then
    printf "%s✖ ยังไม่ติดตั้ง CLI (กด [3])%s" "$C_ERR" "$C_RESET"
  elif ! is_provider_logged_in "$provider"; then
    printf "%s▲ ยังไม่ Login บัญชี (กด [3])%s" "$C_WARN" "$C_RESET"
  elif ! is_model_explicitly_set "$model"; then
    printf "%s▲ รอเลือกโมเดล (กด [1]/[2])%s" "$C_WARN" "$C_RESET"
  elif [ "$provider" = "agy" ]; then
    printf "%s● พร้อมใช้งาน (Google AI Ultra)%s" "$C_OK" "$C_RESET"
  else
    printf "%s● พร้อมใช้งาน (Login แล้ว)%s" "$C_OK" "$C_RESET"
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
    STAGE3_FOCUS_TEXT="มี SPEC.md แล้ว — กด Enter ที่ข้อ [2] เพื่อให้ @arch/@pm สร้าง ARCH.md & PLAN.md"
  elif [ ! -d "$RELAY_DIR/worktrees/$ACTIVE_TASK" ] && [ "${LAST_COMPLETED_PHASE:-0}" -lt 3 ]; then
    RECOMMENDED_STEP=3
    STAGE3_FOCUS_TEXT="มี PLAN.md แล้ว — กด Enter ที่ข้อ [3] เพื่อให้ @dev แยก Worktree และเขียนโค้ด"
  elif [ ! -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_REPORT.md" ]; then
    RECOMMENDED_STEP=4
    STAGE3_FOCUS_TEXT="เขียนโค้ดใน Worktree แล้ว — กด Enter ที่ข้อ [4] เพื่อให้ @qa/@sec ตรวจรับงาน"
  else
    RECOMMENDED_STEP=5
    STAGE3_FOCUS_TEXT="ผ่าน QA_REPORT.md แล้ว — กด Enter ที่ข้อ [5] เพื่อผสานโค้ดเข้า main และเก็บเข้า Archive"
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

  determine_ux_stage

  local git_branch="no-git"
  if [ -d "$PROJECT_DIR/.git" ]; then
    git_branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
  fi

  local state_badge="${C_WARN}○ ยังไม่มี PROJECT_STATE.md${C_RESET}"
  [ -f "$RELAY_DIR/PROJECT_STATE.md" ] && state_badge="${C_OK}● PROJECT_STATE.md พร้อมใช้งาน${C_RESET}"

  local spec_m="${C_MUTED}[ ] SPEC.md${C_RESET}"
  local plan_m="${C_MUTED}[ ] ARCH & PLAN${C_RESET}"
  local qa_m="${C_MUTED}[ ] QA_REPORT.md${C_RESET}"
  if [ -n "$ACTIVE_TASK" ]; then
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ] && spec_m="${C_OK}[✓] SPEC.md${C_RESET}"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/PLAN.md" ] && plan_m="${C_OK}[✓] ARCH & PLAN${C_RESET}"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_REPORT.md" ] && qa_m="${C_OK}[✓] QA_REPORT.md${C_RESET}"
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

  # แสดงข้อมูลโฟลเดอร์โปรเจกต์เฉพาะเมื่อผ่านขั้นที่ 1 แล้ว
  if [ "$UX_STAGE" -ge 2 ]; then
    printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
    if [ "$IN_HOME_DIR" -eq 1 ]; then
      printf "%s│%s โฟลเดอร์ : %s~ (%s)%s  •  %s▲ เป็นโฟลเดอร์ Home ส่วนตัว (ไม่ใช่โฟลเดอร์โปรเจกต์)%s\n" \
        "$C_ACCENT" "$C_RESET" "$C_BOLD" "$PROJECT_DIR" "$C_RESET" "$C_WARN" "$C_RESET"
    else
      printf "%s│%s โครงการ : %s%s%s [%s]  •  %b\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$PROJECT_NAME" "$C_RESET" "$git_branch" "$state_badge"
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
        folder_items+=("${idx}|เปิดโปรเจกต์: ${d/#$HOME/\~} (${r_stat})")
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

  local a_stat x_stat c_stat g_stat
  a_stat="$(get_provider_auth_detail agy)"
  x_stat="$(get_provider_auth_detail codex)"
  c_stat="$(get_provider_auth_detail claude)"
  g_stat="$(get_provider_auth_detail gemini)"

  interactive_menu "เลือกค่าย AI สำหรับ ${role_label} (ปัจจุบัน: ${current_p})" 0 \
    "1|agy    — Google AI Ultra / Antigravity CLI [${a_stat}]" \
    "2|codex  — OpenAI Codex CLI                  [${x_stat}]" \
    "3|claude — Anthropic Claude Code CLI         [${c_stat}]" \
    "4|gemini — Google Gemini CLI (API Key)       [${g_stat}]" \
    "b|คงค่าเดิม (${current_p})"

  local chosen_p="$current_p"
  case "$MENU_RESULT" in
    1) chosen_p="agy" ;;
    2) chosen_p="codex" ;;
    3) chosen_p="claude" ;;
    4) chosen_p="gemini" ;;
    *) chosen_p="$current_p" ;;
  esac

  if ! is_provider_installed "$chosen_p"; then
    local pkg="@google/gemini-cli"
    [ "$chosen_p" = "claude" ] && pkg="@anthropic-ai/claude-code"
    [ "$chosen_p" = "codex" ]  && pkg="@openai/codex"

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
    gemini)
      if is_provider_installed gemini; then
        printf "\n%sกำลังเปิด Gemini CLI (เลือกข้อ 2. Use Gemini API Key แล้วพิมพ์ /quit เมื่อเสร็จ)...%s\n" "$C_ACCENT" "$C_RESET"
        gemini || true
      else
        printf "%s✖ ยังไม่ได้ติดตั้ง gemini%s\n" "$C_ERR" "$C_RESET"
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

# ─── 10. ตั้งค่า Default Model ของแต่ละค่ายโดยตรง (Claude / Gemini / Codex) ────
configure_provider_defaults_menu() {
  while true; do
    local cm gm xm
    cm="$(get_cli_default_model claude)"
    gm="$(get_cli_default_model gemini)"
    xm="$(get_cli_default_model codex)"

    interactive_menu "ตั้งค่า Default Model เริ่มต้นในไฟล์ระบบของแต่ละค่าย" 0 \
      "1|Claude Code CLI (~/.claude/settings.json) — ค่าเริ่มต้นปัจจุบัน: ${cm}" \
      "2|Google Gemini CLI (~/.gemini/settings.json) — ค่าเริ่มต้นปัจจุบัน: ${gm}" \
      "3|OpenAI Codex CLI (~/.codex/config.toml)   — ค่าเริ่มต้นปัจจุบัน: ${xm}" \
      "b|ย้อนกลับ"

    case "$MENU_RESULT" in
      1)
        choose_model_interactive "claude" "ค่าเริ่มต้นของ Claude Code CLI"
        set_cli_default_model "claude" "$SELECTED_MODEL"
        ;;
      2)
        choose_model_interactive "gemini" "ค่าเริ่มต้นของ Gemini CLI"
        set_cli_default_model "gemini" "$SELECTED_MODEL"
        ;;
      3)
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
    for p in agy codex claude gemini; do
      local pkg="Antigravity App (~/.gemini/bin/agy)"
      [ "$p" = "claude" ] && pkg="@anthropic-ai/claude-code"
      [ "$p" = "codex" ]  && pkg="@openai/codex"
      [ "$p" = "gemini" ] && pkg="@google/gemini-cli"
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
      "4|เปิด Gemini CLI เพื่อใส่ Gemini API Key (ข้อ 2. Use Gemini API Key)" \
      "5|ติดตั้ง / อัปเดต CLI (codex + claude + gemini)" \
      "m|ตั้งค่า Default Model เริ่มต้นของแต่ละค่ายในไฟล์ระบบ CLI" \
      "b|กลับสู่หน้าจอหลัก"

    case "$MENU_RESULT" in
      1) refresh_agy_models_live ;;
      2) login_single_provider "codex" ;;
      3) login_single_provider "claude" ;;
      4) login_single_provider "gemini" ;;
      5) npm install -g @anthropic-ai/claude-code @google/gemini-cli @openai/codex ;;
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
    if [ -d "$GLOBAL_DIR/skills/$sk" ]; then
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
    gemini) [ -e "$HOME/.gemini/GEMINI.md" ] && printf "%s● เชื่อม ~/.gemini/GEMINI.md แล้ว%s" "$C_OK" "$C_RESET" || printf "%s○ ไม่พบ ~/.gemini/GEMINI.md%s" "$C_ERR" "$C_RESET" ;;
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
1. ยืนยันบทบาทของคุณคือ '$role_title' (ทำงานผ่านค่าย $provider โมเดล $configured_model)
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
    gemini)
      gemini -m "$configured_model" -p "$self_check_prompt" || exit_code=$?
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

  (
    cd "$work_dir"
    case "$provider" in
      agy)    agy --model "$configured_model" -i "$initial_prompt" || agy --model "$configured_model" || true ;;
      claude) claude --model "$configured_model" "$initial_prompt" 2> >(grep -v '^Permission allow rule (\.claude/settings\.json):' >&2) || true ;;
      codex)  codex -m "$configured_model" "$initial_prompt" || true ;;
      gemini) gemini -m "$configured_model" -i "$initial_prompt" 2>/dev/null || gemini -m "$configured_model" || true ;;
    esac
  )
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
  echo ""
  read -r -p "ตั้งชื่อย่อของใบงานใหม่ (ภาษาอังกฤษ เช่น user-auth หรือ payment-api): " slug
  slug="$(echo "${slug:-feature}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')"
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
  ensure_or_create_task
  echo ""
  read -r -p "อธิบายฟีเจอร์หรือความต้องการคร่าวๆ ที่ต้องการให้ @po วิเคราะห์: " user_goal
  local prompt="@po ฉันต้องการพัฒนาฟีเจอร์สำหรับใบงาน .relay/tasks/$ACTIVE_TASK เกี่ยวกับ: ${user_goal:-ตามที่ฉันกำลังจะอธิบายต่อไปนี้} กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md (ถ้ามี) แล้วซักถามความต้องการจากฉันทีละประเด็นจนชัดเจน เมื่อฉันยืนยันแล้วให้สรุปเป็นเอกสารกำหนดความต้องการลงในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md"
  launch_provider_cli "$ROLE_PO" "$MODEL_PO" "ขั้นตอนที่ 1: @po (Product Owner)" "$PROJECT_DIR" "$prompt"
  LAST_COMPLETED_PHASE=1
}

run_phase_2_arch() {
  require_all_roles_ready || return 0
  ensure_or_create_task
  local prompt="@arch @pm กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md ร่วมกับไฟล์ความต้องการ .relay/tasks/$ACTIVE_TASK/SPEC.md แล้วออกแบบโครงสร้างทางเทคนิคลงในไฟล์ .relay/tasks/$ACTIVE_TASK/ARCH.md และจัดทำแผนการดำเนินงานย่อยเป็นข้อๆ ลงในไฟล์ .relay/tasks/$ACTIVE_TASK/PLAN.md"
  launch_provider_cli "$ROLE_ARCH" "$MODEL_ARCH" "ขั้นตอนที่ 2: @arch & @pm (Architect & Planner)" "$PROJECT_DIR" "$prompt"
  LAST_COMPLETED_PHASE=2
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
      printf "%sกำลังสร้าง Git Worktree แยกอิสระที่ .relay/worktrees/%s (กิ่ง %s)...%s\n" "$C_ACCENT" "$ACTIVE_TASK" "$branch_name" "$C_RESET"
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
  LAST_COMPLETED_PHASE=3
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
  LAST_COMPLETED_PHASE=4
}

run_phase_5_merge() {
  require_all_roles_ready || return 0
  get_active_task
  if [ -z "$ACTIVE_TASK" ]; then
    printf "%s▲ ยังไม่มีใบงานที่กำลังดำเนินการใน .relay/tasks/%s\n" "$C_ERR" "$C_RESET"
    return
  fi
  local branch_name="feat/$ACTIVE_TASK"
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"

  interactive_menu "ยืนยันการผสานโค้ดกิ่ง ${branch_name} เข้าสู่ main และจัดเก็บใบงาน ${ACTIVE_TASK}" 0 \
    "y|ยืนยัน — ผสานโค้ดเข้ากิ่งหลัก ลบ Worktree และย้ายเข้า .relay/archive/" \
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
    LAST_COMPLETED_PHASE=0
    printf "%s● ผสานโค้ดและย้ายใบงานไปที่ .relay/archive/%s เรียบร้อยแล้ว!%s\n" "$C_OK" "$ACTIVE_TASK" "$C_RESET"
  fi
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
      "t|ตรวจสอบสถานะความพร้อม Agent & Skills ประจำตำแหน่ง (/test)" \
      "q|ออกจากโปรแกรม (/quit)"

    case "$MENU_RESULT" in
      1) run_quick_preset_menu ;;
      2|c|C|/model|/config) configure_roles_menu ;;
      3|d|D|/connect|/doctor|/login) run_doctor_menu ;;
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
        "t|ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่งด้วยโควตา Google AI Ultra + Codex (/test)" \
        "c|ตั้งค่าค่าย AI & เปลี่ยน Model ประจำตำแหน่ง (/model)" \
        "d|จัดการการเชื่อมต่อ CLI & Login บัญชี (/connect)" \
        "q|ออกจากโปรแกรม (เพื่อพิมพ์ cd เข้าโฟลเดอร์โปรเจกต์เอง)"

      case "$MENU_RESULT" in
        1|f|F|i|I|/init) select_or_create_project_dir ;;
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
        "t|ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่ง (/test)" \
        "c|ตั้งค่าค่าย AI & เปลี่ยน Model ประจำตำแหน่ง (/model)" \
        "q|ออกจากโปรแกรม (/quit)"

      case "$MENU_RESULT" in
        1) run_init_greenfield ;;
        2) run_init_brownfield ;;
        f|F) select_or_create_project_dir ;;
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
    p5_label="ขั้นตอนที่ 5 (Merge)     — ผสานโค้ดเข้า main และเก็บเข้า .relay/archive/"

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
      "n|สร้างใบงานใหม่ (New Task) (/new)" \
      "f|สลับไปโฟลเดอร์โปรเจกต์อื่น (Switch Project Folder)" \
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
      n|N|/new)             create_new_task ;;
      f|F)                  select_or_create_project_dir ;;
      i|I|/init)            run_init_project ;;
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
