#!/usr/bin/env bash

# ==============================================================================
# 🎛️ RELAY Central Terminal Hub (v1.0) — Guided 3-Stage Progressive UX
# • โทนสี Minimalist 3-Tier (รองรับทั้ง Terminal พื้นหลังสีขาว Light Mode และพื้นดำ Dark Mode)
# • ไฮไลต์บรรทัดที่เลือกด้วย ❯ + สีน้ำเงินครามตัวหนาทั้งบรรทัด (คลุมครบทั้งบรรทัด ไม่แหว่งสระไทย)
# • รองรับโควตา Google AI Ultra เต็มรูปแบบผ่าน Antigravity CLI (~/.gemini/bin/agy):
#   ใช้ได้ทั้ง Gemini 4 Argon, Gemini 3.8 Flash, Claude Opus 5.5, Claude Sonnet 5.5
# • ตรวจสอบความพร้อมจริง 3 ชั้น: ติดตั้ง CLI แล้ว + Login บัญชีแล้ว + เลือก Model แล้ว
# ==============================================================================

export PATH="$HOME/.gemini/bin:$HOME/.local/bin:$HOME/.agents/bin:$PATH"

GLOBAL_DIR="$HOME/.agents"
GLOBAL_ROLES_CONF="$GLOBAL_DIR/relay-roles.conf"
GLOBAL_AGENTS_CONF="$GLOBAL_DIR/custom-agents.json"
AGY_MODELS_CACHE="$GLOBAL_DIR/agy-models.cache"
QUOTA_CACHE_FILE="$GLOBAL_DIR/relay-quota.cache"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
RELAY_DIR="$PROJECT_DIR/.relay"
PROJECT_ROLES_CONF="$RELAY_DIR/roles.conf"
PROJECT_AGENTS_CONF="$RELAY_DIR/custom-agents.json"
LAST_COMPLETED_PHASE=0

refresh_project_paths() {
  PROJECT_NAME="$(basename "$PROJECT_DIR")"
  RELAY_DIR="$PROJECT_DIR/.relay"
  PROJECT_ROLES_CONF="$RELAY_DIR/roles.conf"
  PROJECT_AGENTS_CONF="$RELAY_DIR/custom-agents.json"
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

# ─── 2. โหลดและบันทึกการตั้งค่า Role & Model (Safe Parser & Atomic Write) ────────
sanitize_model_id() {
  local raw="${1:-}"
  printf "%s" "$raw" | tr -cd 'a-zA-Z0-9._:/-'
}

safe_load_roles_conf() {
  local conf_file="$1"
  [ -r "$conf_file" ] || return 0
  local line k v
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [ -z "$line" ] || [[ "$line" == \#* ]] && continue
    [[ "$line" == *=* ]] || continue
    k="${line%%=*}"
    v="${line#*=}"
    k="$(printf "%s" "$k" | tr -d '[:space:]')"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    if [[ "$v" == \"*\" ]] && [[ "$v" == *\" ]]; then
      v="${v:1:${#v}-2}"
    elif [[ "$v" == \'*\' ]] && [[ "$v" == *\' ]]; then
      v="${v:1:${#v}-2}"
    fi
    # บล็อกค่าที่มีอักขระสั่งรันคำสั่ง Shell ($(), `, ;, |, &, >, <)
    if [[ "$v" == *'$('* ]] || [[ "$v" == *'`'* ]] || [[ "$v" == *';'* ]] || [[ "$v" == *'|'* ]] || [[ "$v" == *'&'* ]] || [[ "$v" == *'>'* ]] || [[ "$v" == *'<'* ]]; then
      continue
    fi
    case "$k" in
      ROLE_PO|ROLE_ARCH|ROLE_DEV|ROLE_QA)
        case "$v" in
          agy|codex|claude|gemini) printf -v "$k" '%s' "$v" ;;
        esac
        ;;
      MODEL_PO|MODEL_ARCH|MODEL_DEV|MODEL_QA)
        local clean_m
        clean_m="$(sanitize_model_id "$v")"
        [ -n "$clean_m" ] && printf -v "$k" '%s' "$clean_m"
        ;;
    esac
  done < "$conf_file"
}

load_role_config() {
  refresh_project_paths
  ROLE_PO="agy";     MODEL_PO="gemini-4-argon-high"
  ROLE_ARCH="agy";   MODEL_ARCH="claude-opus-5-5-high"
  ROLE_DEV="agy";    MODEL_DEV="claude-sonnet-5-5-high"
  ROLE_QA="codex";   MODEL_QA="gpt-6.1-terra"
  CONFIG_SOURCE="Global (~/.agents/relay-roles.conf)"

  if [ -r "$GLOBAL_ROLES_CONF" ]; then
    safe_load_roles_conf "$GLOBAL_ROLES_CONF"
  fi
  if [ -r "$PROJECT_ROLES_CONF" ]; then
    safe_load_roles_conf "$PROJECT_ROLES_CONF"
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
  local tmp_file="${target_file}.tmp.$$"
  local m_po m_arch m_dev m_qa
  m_po="$(sanitize_model_id "${MODEL_PO:-default}")"
  m_arch="$(sanitize_model_id "${MODEL_ARCH:-default}")"
  m_dev="$(sanitize_model_id "${MODEL_DEV:-default}")"
  m_qa="$(sanitize_model_id "${MODEL_QA:-default}")"
  {
    printf "# RELAY Role-to-Provider & Model Configuration\n"
    printf 'ROLE_PO="%s"\n' "${ROLE_PO:-agy}"
    printf 'MODEL_PO="%s"\n' "${m_po:-default}"
    printf 'ROLE_ARCH="%s"\n' "${ROLE_ARCH:-agy}"
    printf 'MODEL_ARCH="%s"\n' "${m_arch:-default}"
    printf 'ROLE_DEV="%s"\n' "${ROLE_DEV:-agy}"
    printf 'MODEL_DEV="%s"\n' "${m_dev:-default}"
    printf 'ROLE_QA="%s"\n' "${ROLE_QA:-codex}"
    printf 'MODEL_QA="%s"\n' "${m_qa:-default}"
  } > "$tmp_file" && mv -f "$tmp_file" "$target_file"
}

set_cli_default_model() {
  local provider="$1"
  local new_model
  new_model="$(sanitize_model_id "${2:-}")"
  [ -z "$new_model" ] || [ "$new_model" = "default" ] && return 0

  case "$provider" in
    claude)
      mkdir -p "$HOME/.claude"
      if command -v python3 >/dev/null 2>&1; then
        python3 - "$HOME/.claude/settings.json" "$new_model" <<'PYEOF'
import json, os, sys
path, model = sys.argv[1:3]
data = {}
if os.path.isfile(path):
    try:
        loaded = json.load(open(path, encoding="utf-8"))
        if isinstance(loaded, dict):
            data = loaded
    except Exception:
        pass
data["model"] = model
tmp = f"{path}.tmp.{os.getpid()}"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
os.replace(tmp, path)
PYEOF
      fi
      ;;
    codex)
      mkdir -p "$HOME/.codex"
      if command -v python3 >/dev/null 2>&1; then
        python3 - "$HOME/.codex/config.toml" "$new_model" <<'PYEOF'
import os, re, sys
path, model = sys.argv[1:3]
lines = []
found = False
if os.path.isfile(path):
    try:
        for line in open(path, encoding="utf-8", errors="ignore"):
            if not found and re.match(r"^\s*model\s*=", line):
                lines.append(f'model = "{model}"\n')
                found = True
            else:
                lines.append(line)
    except Exception:
        pass
if not found:
    lines.append(f'model = "{model}"\n')
tmp = f"{path}.tmp.{os.getpid()}"
with open(tmp, "w", encoding="utf-8") as f:
    f.writelines(lines)
os.replace(tmp, path)
PYEOF
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

tmp_cache = f"{cache_file}.tmp.{os.getpid()}"
with open(tmp_cache, "w", encoding="utf-8") as f:
    for k, v in vals.items():
        clean_v = str(v).replace("\n", " ").replace("\r", " ").replace('"', "").replace("$", "").replace("`", "")
        f.write(f'{k}="{clean_v}"\n')
os.replace(tmp_cache, cache_file)
PYEOF
  fi

  if [ -f "$QUOTA_CACHE_FILE" ]; then
    safe_load_quota_cache "$QUOTA_CACHE_FILE"
  fi
}

safe_load_quota_cache() {
  local cache_file="$1"
  [ -r "$cache_file" ] || return 0
  local line k v
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [ -z "$line" ] || [[ "$line" == \#* ]] && continue
    [[ "$line" == *=* ]] || continue
    k="${line%%=*}"
    v="${line#*=}"
    k="$(printf "%s" "$k" | tr -d '[:space:]')"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    if [[ "$v" == \"*\" ]] && [[ "$v" == *\" ]]; then
      v="${v:1:${#v}-2}"
    elif [[ "$v" == \'*\' ]] && [[ "$v" == *\' ]]; then
      v="${v:1:${#v}-2}"
    fi
    if [[ "$v" == *'$('* ]] || [[ "$v" == *'`'* ]] || [[ "$v" == *';'* ]] || [[ "$v" == *'|'* ]] || [[ "$v" == *'&'* ]] || [[ "$v" == *'>'* ]] || [[ "$v" == *'<'* ]]; then
      continue
    fi
    case "$k" in
      QUOTA_UPDATED_EPOCH|QUOTA_UPDATED_AT|\
      AGY_GEMINI_5H_REM|AGY_GEMINI_5H_RESET|AGY_GEMINI_5H_RESET_EPOCH|\
      AGY_GEMINI_7D_REM|AGY_GEMINI_7D_RESET|AGY_GEMINI_7D_RESET_EPOCH|\
      AGY_CLAUDE_5H_REM|AGY_CLAUDE_5H_RESET|AGY_CLAUDE_5H_RESET_EPOCH|\
      AGY_CLAUDE_7D_REM|AGY_CLAUDE_7D_RESET|AGY_CLAUDE_7D_RESET_EPOCH|\
      AGY_FETCH_OK|AGY_FETCHED_AT|\
      CODEX_PLAN|CODEX_5H_REM|CODEX_5H_RESET|CODEX_5H_RESET_EPOCH|\
      CODEX_7D_REM|CODEX_7D_RESET|CODEX_7D_RESET_EPOCH|\
      CODEX_FETCH_OK|CODEX_FETCHED_AT|\
      CLAUDE_PLAN|CLAUDE_5H_REM|CLAUDE_5H_RESET|CLAUDE_5H_RESET_EPOCH|\
      CLAUDE_7D_REM|CLAUDE_7D_RESET|CLAUDE_7D_RESET_EPOCH|\
      CLAUDE_FETCH_OK|CLAUDE_FETCHED_AT)
        printf -v "$k" '%s' "$v"
        ;;
    esac
  done < "$cache_file"
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
    safe_load_quota_cache "$QUOTA_CACHE_FILE"
  fi
  update_codex_quota_fast
  local age=$((now_ts - ${QUOTA_UPDATED_EPOCH:-0}))
  if [ "${SUBCOMMAND:-hub}" != "quota" ] && [ "${SUBCOMMAND:-hub}" != "usage" ]; then
    if [ ! -f "$QUOTA_CACHE_FILE" ] || [ "$age" -gt 180 ] || [ "${AGY_GEMINI_5H_REM:--}" = "-" ]; then
      local q_lock="$GLOBAL_DIR/relay-quota.lock"
      local lock_pid=""
      [ -f "$q_lock" ] && lock_pid="$(cat "$q_lock" 2>/dev/null || true)"
      if [ -z "$lock_pid" ] || ! kill -0 "$lock_pid" 2>/dev/null; then
        (
          mkdir -p "$GLOBAL_DIR" 2>/dev/null || true
          echo "$$" > "$q_lock" 2>/dev/null || true
          refresh_quota_cache --quiet </dev/null >/dev/null 2>&1 || true
          rm -f "$q_lock" 2>/dev/null || true
        ) >/dev/null 2>&1 &
      fi
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
print(f"{MUTED}│{RST} {BOLD}{ACC}Quota (5h / 7d){RST}  {note}")

cells = [(r[0], cell(r[1], r[2], r[3], r[7] == "0", r[8], True), cell(r[4], r[5], r[6], r[7] == "0", r[8], False)) for r in rows]
h_name, h5, h7 = "Provider / Pool", "5h Window", "7d Window"
nw = max([width(h_name)] + [width(n) for n, _, _ in cells])
w5 = max([width(h5)] + [width(c5[1]) for _, c5, _ in cells])
print(f"{MUTED}│{RST}  {MUTED}{pad(h_name, nw)}  {pad(h5, w5)}  {h7}{RST}")
for name, c5, c7 in cells:
    print(f"{MUTED}│{RST}  {pad(name, nw)}  {c5[0]}{' ' * max(0, w5 - width(c5[1]))}  {c7[0]}")
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

get_quota_pool_id() {
  local p="$1"
  local m="$2"
  case "$p" in
    agy)
      if [[ "$m" == claude-* ]] || [[ "$m" == gpt-* ]]; then
        echo "agy_claude"
      else
        echo "agy_gemini"
      fi
      ;;
    codex)  echo "codex" ;;
    claude) echo "claude" ;;
    *)      echo "$p" ;;
  esac
}

get_role_min_quota_pct() {
  local qpair q5 q7 min_q="-"
  qpair="$(get_role_quota_pair "$1" "$2")"
  q5="${qpair%%|*}"
  q7="${qpair#*|}"
  if [[ "$q5" =~ ^[0-9]+$ ]] && [[ "$q7" =~ ^[0-9]+$ ]]; then
    min_q="$q5"
    [ "$q7" -lt "$min_q" ] && min_q="$q7"
  elif [[ "$q5" =~ ^[0-9]+$ ]]; then
    min_q="$q5"
  elif [[ "$q7" =~ ^[0-9]+$ ]]; then
    min_q="$q7"
  fi
  echo "$min_q"
}

# คืนค่ารายการกระเป๋าโควต้าทางเลือกที่พร้อมใช้ในเครื่อง เรียงตามเปอร์เซ็นต์คงเหลือสูงสุด -> ต่ำสุด
# รูปแบบต่อบรรทัด: provider|model|min_pct|pool_label
list_quota_failover_candidates() {
  local cur_prov="$1"
  local cur_model="$2"
  local role_key="${3:-dev}"
  local cur_pool
  cur_pool="$(get_quota_pool_id "$cur_prov" "$cur_model")"

  local agy_gem_m="gemini-4-argon-high"
  [ "$role_key" = "qa" ] && agy_gem_m="gemini-3.8-flash-high"
  local agy_cl_m="claude-sonnet-5-5-high"
  [ "$role_key" = "arch" ] && agy_cl_m="claude-opus-5-5-high"
  local codex_m
  codex_m="$(get_cli_default_model codex)"
  local claude_m="sonnet"
  [ "$role_key" = "arch" ] && claude_m="opus"

  local raw_lines=""
  local pool_id c_prov c_mod c_label c_min sort_key
  for entry in \
    "agy_gemini|agy|${agy_gem_m}|กระเป๋า Gemini (Google AI Ultra)" \
    "agy_claude|agy|${agy_cl_m}|กระเป๋า Claude/GPT (Google AI Ultra)" \
    "codex|codex|${codex_m}|กระเป๋า OpenAI Codex (${CODEX_PLAN:-Plus})" \
    "claude|claude|${claude_m}|กระเป๋า Anthropic Claude (${CLAUDE_PLAN:-Pro})"
  do
    IFS='|' read -r pool_id c_prov c_mod c_label <<<"$entry"
    [ "$pool_id" = "$cur_pool" ] && continue
    if is_provider_installed "$c_prov" && is_provider_logged_in "$c_prov"; then
      c_min="$(get_role_min_quota_pct "$c_prov" "$c_mod")"
      if [[ "$c_min" =~ ^[0-9]+$ ]]; then
        sort_key="$c_min"
      else
        sort_key="50"
      fi
      raw_lines="${raw_lines}${sort_key}|${c_prov}|${c_mod}|${c_min}|${c_label}"$'\n'
    fi
  done

  [ -z "$raw_lines" ] && return 0
  printf "%s" "$raw_lines" | grep -v '^$' | sort -t'|' -k1,1nr | cut -d'|' -f2-
}

apply_role_provider_model_switch() {
  local role_key="$1"
  local new_prov="$2"
  local new_model="$3"
  case "$role_key" in
    po)   ROLE_PO="$new_prov";   MODEL_PO="$new_model" ;;
    arch) ROLE_ARCH="$new_prov"; MODEL_ARCH="$new_model" ;;
    dev)  ROLE_DEV="$new_prov";  MODEL_DEV="$new_model" ;;
    qa)   ROLE_QA="$new_prov";   MODEL_QA="$new_model" ;;
    *)    return 1 ;;
  esac
  local target_conf="$GLOBAL_ROLES_CONF"
  [ -f "$PROJECT_ROLES_CONF" ] && target_conf="$PROJECT_ROLES_CONF"
  save_role_config "$target_conf"
  return 0
}

prompt_or_auto_switch_role_quota() {
  local role_key="$1"
  local role_label="$2"
  local cur_prov="$3"
  local cur_model="$4"
  local min_pct="${5:-20}"
  local trigger_reason="${6:-low_quota}"

  [ -z "$role_key" ] && return 1

  local cand_list=()
  local c_line
  while IFS= read -r c_line; do
    [ -n "$c_line" ] && cand_list+=("$c_line")
  done < <(list_quota_failover_candidates "$cur_prov" "$cur_model" "$role_key")

  # 1. กรณีเปิดโหมด Auto-Failover (RELAY_AUTO_FAILOVER=1): สลับไปยังกระเป๋าที่โควต้าสูงสุด (>= 50%) อัตโนมัติทันที
  if [ "${RELAY_AUTO_FAILOVER:-0}" = "1" ] && [ "${#cand_list[@]}" -gt 0 ]; then
    local top_cand="${cand_list[0]}"
    local top_prov top_mod top_pct top_label
    IFS='|' read -r top_prov top_mod top_pct top_label <<<"$top_cand"
    local auto_min="${RELAY_AUTO_FAILOVER_MIN_PCT:-50}"
    if { [[ "$top_pct" =~ ^[0-9]+$ ]] && [ "$top_pct" -ge "$auto_min" ]; } || [ "$top_pct" = "-" ]; then
      apply_role_provider_model_switch "$role_key" "$top_prov" "$top_mod"
      local pct_txt="${top_pct}%"
      [ "$top_pct" = "-" ] && pct_txt="พร้อมใช้"
      printf "\n%s⚡ [Smart Auto-Failover] สลับตำแหน่ง %s จาก %s/%s ➔ ไปใช้ %s/%s (%s • โควต้าเหลือ %s) อัตโนมัติแล้วทำงานต่อทันที!%s\n" \
        "$C_OK" "$role_label" "$cur_prov" "$cur_model" "$top_prov" "$top_mod" "$top_label" "$pct_txt" "$C_RESET"
      if [ -n "${LOOP_LOG_FILE:-}" ]; then
        echo "- [FAILOVER] สลับ ${role_label} จาก ${cur_prov}/${cur_model} ➔ ${top_prov}/${top_mod} (โควต้าเหลือ ${pct_txt} • สาเหตุ: ${trigger_reason}) (\`$(date '+%H:%M:%S')\`)" >> "$LOOP_LOG_FILE"
      fi
      return 0
    fi
  fi

  # 2. กรณีรันแบบ Non-Interactive (เช่น ชุดทดสอบอัตโนมัติที่ไม่ได้เปิด Auto-Failover หรือบังคับถาม): หยุดทันที
  if [ ! -t 0 ] && [ "${RELAY_FORCE_QUOTA_PROMPT:-0}" != "1" ]; then
    return 1
  fi

  # 3. กรณี Interactive: แสดงทางลัดสลับกระเป๋าโควต้าในคลิกเดียว (หรือฝืนรันต่อด้วยโมเดลเดิม)
  local menu_items=()
  local cand_provs=()
  local cand_mods=()
  local cand_pcts=()
  local idx=1
  for c_line in "${cand_list[@]}"; do
    local cp cm cq cl
    IFS='|' read -r cp cm cq cl <<<"$c_line"
    if [[ "$cq" =~ ^[0-9]+$ ]] && [ "$cq" -lt "$min_pct" ]; then
      continue
    fi
    local q_disp="โควต้าเหลือ ${cq}%"
    [ "$cq" = "-" ] && q_disp="พร้อมใช้งาน"
    local star_prefix=""
    [ "$idx" -eq 1 ] && star_prefix="★ "
    menu_items+=("${idx}|${star_prefix}สลับไปใช้ ${cp} / ${cm} [${q_disp} — ${cl}] แล้วทำต่อทันที")
    cand_provs[$idx]="$cp"
    cand_mods[$idx]="$cm"
    cand_pcts[$idx]="$q_disp"
    idx=$((idx + 1))
  done

  menu_items+=("m|เลือกค่าย AI และโมเดลอื่นด้วยตนเอง แล้วทำต่อทันที")
  if [ "$trigger_reason" = "mid_step_error" ]; then
    menu_items+=("r|ลองรันซ้ำด้วยค่ายและโมเดลเดิม (${cur_prov} / ${cur_model})")
  else
    menu_items+=("f|ฝืนรันต่อด้วยค่ายและโมเดลเดิม (${cur_prov} / ${cur_model}) ในรอบนี้")
  fi
  menu_items+=("b|ย้อนกลับ / หยุดพักงานไว้ก่อน (งานที่ทำไปแล้วใน Worktree ยังอยู่ครบ)")

  interactive_menu "เลือกวิธีดำเนินการต่อสำหรับ ${role_label} (สลับกระเป๋าโควต้าแล้วรับไม้ต่อทันที)" 0 "${menu_items[@]}"

  case "$MENU_RESULT" in
    [1-9])
      if [ -n "${cand_provs[$MENU_RESULT]:-}" ]; then
        local np="${cand_provs[$MENU_RESULT]}"
        local nm="${cand_mods[$MENU_RESULT]}"
        local nq="${cand_pcts[$MENU_RESULT]}"
        apply_role_provider_model_switch "$role_key" "$np" "$nm"
        printf "\n%s● สลับ %s ไปใช้ %s / %s (%s) เรียบร้อย — กำลังทำงานต่อทันที!%s\n" "$C_OK" "$role_label" "$np" "$nm" "$nq" "$C_RESET"
        if [ -n "${LOOP_LOG_FILE:-}" ]; then
          echo "- [FAILOVER] ผู้ใช้สลับ ${role_label} จาก ${cur_prov}/${cur_model} ➔ ${np}/${nm} (${nq}) (\`$(date '+%H:%M:%S')\`)" >> "$LOOP_LOG_FILE"
        fi
        return 0
      fi
      ;;
    m|M)
      if choose_provider_interactive "$role_label" "$cur_prov"; then
        local next_p="$SELECTED_PROVIDER"
        if choose_model_interactive "$next_p" "$role_label" "$cur_model"; then
          apply_role_provider_model_switch "$role_key" "$next_p" "$SELECTED_MODEL"
          printf "\n%s● สลับ %s ไปใช้ %s / %s เรียบร้อย — กำลังทำงานต่อทันที!%s\n" "$C_OK" "$role_label" "$next_p" "$SELECTED_MODEL" "$C_RESET"
          if [ -n "${LOOP_LOG_FILE:-}" ]; then
            echo "- [FAILOVER] ผู้ใช้กำหนด ${role_label} เป็น ${next_p}/${SELECTED_MODEL} (\`$(date '+%H:%M:%S')\`)" >> "$LOOP_LOG_FILE"
          fi
          return 0
        fi
      fi
      ;;
    f|F|r|R)
      printf "\n%s▲ ดำเนินการต่อด้วยค่ายและโมเดลเดิม (%s / %s) ในรอบนี้ตามคำสั่งผู้ใช้%s\n" "$C_WARN" "$cur_prov" "$cur_model" "$C_RESET"
      if [ -n "${LOOP_LOG_FILE:-}" ]; then
        echo "- [OVERRIDE] ผู้ใช้เลือกใช้ ${cur_prov}/${cur_model} ต่อในรอบนี้ (\`$(date '+%H:%M:%S')\`)" >> "$LOOP_LOG_FILE"
      fi
      return 0
      ;;
  esac
  return 1
}

check_role_quota_safe() {
  local provider="$1"
  local model="$2"
  local role_label="$3"
  local min_pct="${4:-20}"
  local role_key="${5:-}"

  if [ -z "$role_key" ]; then
    case "$role_label" in
      *"@po"*)   role_key="po" ;;
      *"@arch"*) role_key="arch" ;;
      *"@dev"*)  role_key="dev" ;;
      *"@qa"*)   role_key="qa" ;;
    esac
  fi

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
    printf "%s│%s %s🛑 [Quota Circuit Breaker] โควต้าของตำแหน่งนี้ต่ำกว่าเกณฑ์ปลอดภัย (%s%%)!%s\n" "$C_ERR" "$C_RESET" "$C_BOLD" "$min_pct" "$C_RESET"
    printf "%s│%s  • ตำแหน่ง : %s (%s / %s)\n" "$C_ERR" "$C_RESET" "$role_label" "$provider" "$model"
    printf "%s│%s  • โควต้าคงเหลือปัจจุบัน : 5 ชม. เหลือ %s%% │ รายสัปดาห์ เหลือ %s%% (เกณฑ์ขั้นต่ำ %s%%)\n" "$C_ERR" "$C_RESET" "$q5" "$q7" "$min_pct"
    printf "%s│%s  • คำแนะนำ : สลับไปใช้กระเป๋าโควต้า/ค่ายอื่นที่ยังมีโควต้าเหลือเยอะ แล้วรับไม้ต่อใน Worktree เดิมได้ทันที\n" "$C_ERR" "$C_RESET"
    printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ERR" "$C_RESET"

    if prompt_or_auto_switch_role_quota "$role_key" "$role_label" "$provider" "$model" "$min_pct" "low_quota"; then
      return 0
    fi
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
  if [ -n "${CURRENT_TASK:-}" ] && [ -d "$RELAY_DIR/tasks/$CURRENT_TASK" ]; then
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
    STAGE3_FOCUS_TEXT="[1] @po Define Spec (SPEC.md) หรือ [x] Fast Track"
  elif [ ! -f "$RELAY_DIR/tasks/$ACTIVE_TASK/PLAN.md" ]; then
    RECOMMENDED_STEP=2
    STAGE3_FOCUS_TEXT="[2] @arch & @pm Design Architecture & Plan หรือ [a] Auto Loop (2→3⇄4)"
  elif [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_REPORT.md" ] || [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_VERDICT.json" ]; then
    local s3v
    s3v="$(qa_verdict "$RELAY_DIR/tasks/$ACTIVE_TASK")"
    if [ "${s3v%%|*}" = "PASS" ]; then
      RECOMMENDED_STEP=5
      STAGE3_FOCUS_TEXT="[5] Merge Branch to main & Archive Task (QA PASS)"
    else
      RECOMMENDED_STEP=3
      STAGE3_FOCUS_TEXT="[3] @dev แก้ไขตาม QA_REPORT.md (${s3v%%|*}) หรือ [a] Auto Loop"
    fi
  elif [ ! -d "$RELAY_DIR/worktrees/$ACTIVE_TASK" ] && [ "${LAST_COMPLETED_PHASE:-0}" -lt 3 ]; then
    RECOMMENDED_STEP=3
    STAGE3_FOCUS_TEXT="[3] @dev Implement in Git Worktree หรือ [a] Auto Loop (3⇄4)"
  else
    RECOMMENDED_STEP=4
    STAGE3_FOCUS_TEXT="[4] @qa & @sec Verify Tests, Security & QA_REPORT.md"
  fi
}

# ─── 3. Interactive Arrow-Key Menu (4-Level Quiet Color Hierarchy + Shortcuts Bar) ───
MENU_RESULT=""
MENU_SHORTCUTS_BAR=""
EXTRA_MENU_KEYS=""

print_shortcuts_bar_lines() {
  printf "\033[2K\r\n"
  printf "\033[2K\r  %s%sShortcuts%s\n" "$C_ACCENT" "$C_BOLD" "$C_RESET"
  printf "\033[2K\r  %s[c]%s Models   %s[g]%s Agents   %s[u]%s Quota   %s[v]%s Telemetry   %s[l]%s Rules\n" \
    "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET"
  printf "\033[2K\r  %s[n]%s New Task %s[f]%s Project  %s[t]%s Test    %s[d]%s Auth        %s[s]%s Skills  %s[q]%s Quit\n" \
    "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET"
}

interactive_menu() {
  local title="$1"
  local default_sel="${2:-0}"
  shift 2
  local items=("$@")
  local count="${#items[@]}"
  local selected="$default_sel"
  local has_shortcuts="${MENU_SHORTCUTS_BAR:-}"
  local extra_keys="${EXTRA_MENU_KEYS:-}"
  MENU_SHORTCUTS_BAR=""
  EXTRA_MENU_KEYS=""
  if [ "$selected" -ge "$count" ] || [ "$selected" -lt 0 ]; then
    selected=0
  fi

  if [ ! -t 0 ]; then
    printf "\n  %s%s%s\n" "$C_BOLD" "$title" "$C_RESET"
    local idx=0
    while [ "$idx" -lt "$count" ]; do
      local entry="${items[$idx]}"
      local key="${entry%%|*}"
      local label="${entry#*|}"
      if [ "$idx" -eq "$selected" ]; then
        printf "  %s❯ [%s] %s%s\n" "$C_SEL" "$key" "$label" "$C_RESET"
      elif [[ "$label" == "● [RELAY]"* ]]; then
        printf "    %s[%s]%s %s● [RELAY]%s%s\n" "$C_MUTED" "$key" "$C_RESET" "$C_OK" "$C_RESET" "${label#● \[RELAY\]}"
      elif [[ "$label" == "○ [ทั่วไป]"* ]]; then
        printf "    %s[%s]%s %s○ [ทั่วไป]%s%s\n" "$C_MUTED" "$key" "$C_RESET" "$C_MUTED" "$C_RESET" "${label#○ \[ทั่วไป\]}"
      else
        printf "    %s[%s]%s %s\n" "$C_MUTED" "$key" "$C_RESET" "$label"
      fi
      idx=$((idx + 1))
    done
    if [ -n "$has_shortcuts" ]; then
      print_shortcuts_bar_lines
    fi
    local input_val=""
    read -r input_val || true
    if [ -z "$input_val" ]; then
      MENU_RESULT="${items[$selected]%%|*}"
    else
      MENU_RESULT="$input_val"
    fi
    return 0
  fi

  printf "\n  %s%s%s\n" "$C_BOLD" "$title" "$C_RESET"

  tput civis 2>/dev/null || true
  trap 'tput cnorm 2>/dev/null || true' EXIT INT TERM

  local footer_lines=1
  [ -n "$has_shortcuts" ] && footer_lines=4

  local first_draw=1
  while true; do
    if [ "$first_draw" -eq 0 ]; then
      printf "\033[%dA\r" "$((count + footer_lines))"
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
      elif [[ "$label" == "● [RELAY]"* ]]; then
        printf "    %s[%s]%s %s● [RELAY]%s%s\n" "$C_MUTED" "$key" "$C_RESET" "$C_OK" "$C_RESET" "${label#● \[RELAY\]}"
      elif [[ "$label" == "○ [ทั่วไป]"* ]]; then
        printf "    %s[%s]%s %s○ [ทั่วไป]%s%s\n" "$C_MUTED" "$key" "$C_RESET" "$C_MUTED" "$C_RESET" "${label#○ \[ทั่วไป\]}"
      else
        printf "    %s[%s]%s %s\n" "$C_MUTED" "$key" "$C_RESET" "$label"
      fi
      i=$((i + 1))
    done

    local cur_key="${items[$selected]%%|*}"
    if [ -n "$has_shortcuts" ]; then
      print_shortcuts_bar_lines
    else
      printf "\033[2K\r  %s↑/↓ เลื่อน • Enter เลือก [%s] • b/ESC ย้อนกลับ • / พิมพ์เมนู%s\n" "$C_MUTED" "$cur_key" "$C_RESET"
    fi

    local k1=""
    IFS= read -rsn1 k1 || true

    if [ -z "$k1" ]; then
      MENU_RESULT="${items[$selected]%%|*}"
      break
    fi

    if [ "$k1" = $'\x1b' ]; then
      local k23=""
      IFS= read -rsn2 -t 0.1 k23 2>/dev/null || IFS= read -rsn2 -t 1 k23 2>/dev/null || true
      case "$k23" in
        "[A"|"OA")
          selected=$(((selected - 1 + count) % count))
          continue
          ;;
        "[B"|"OB")
          selected=$(((selected + 1) % count))
          continue
          ;;
        "")
          MENU_RESULT="b"
          tput cnorm 2>/dev/null || true
          return 0
          ;;
        *)
          continue
          ;;
      esac
    fi

    if [ "$k1" = "/" ]; then
      tput cnorm 2>/dev/null || true
      printf "\033[1A\033[2K\r  %s❯ /%s" "$C_SEL" "$C_RESET"
      local slash_cmd=""
      read -r slash_cmd || true
      printf "\n"
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
    if [ -n "$extra_keys" ]; then
      local ek
      for ek in $extra_keys; do
        if [ "$lower_k1" = "$ek" ]; then
          MENU_RESULT="$lower_k1"
          tput cnorm 2>/dev/null || true
          return 0
        fi
      done
    fi
    if [ "$lower_k1" = "b" ]; then
      MENU_RESULT="b"
      tput cnorm 2>/dev/null || true
      return 0
    fi
  done

  tput cnorm 2>/dev/null || true
}

# ตรวจสอบว่าคำที่ผู้ใช้พิมพ์คือคำสั่งขอย้อนกลับหรือไม่ (b, B, back, /back)
is_back_input() {
  local val="${1:-}"
  case "$val" in
    b|B|back|BACK|/back|/b) return 0 ;;
    *) return 1 ;;
  esac
}

# ─── 3.5 การจัดการข้อมูลบทบาท Agent, คำสั่ง Prompt และทักษะ (Custom Agents & Overrides) ───
get_active_agents_conf() {
  refresh_project_paths
  if [ -f "$PROJECT_AGENTS_CONF" ]; then
    echo "$PROJECT_AGENTS_CONF"
  else
    echo "$GLOBAL_AGENTS_CONF"
  fi
}

get_agents_conf_scope_label() {
  refresh_project_paths
  if [ -f "$PROJECT_AGENTS_CONF" ]; then
    echo "Project (.relay/custom-agents.json)"
  else
    echo "Global (~/.agents/custom-agents.json)"
  fi
}

get_core_role_default_title() {
  case "$1" in
    po)   echo "Product Owner" ;;
    arch) echo "System Architect & Planner" ;;
    dev)  echo "Full-Stack Developer" ;;
    qa)   echo "QA & Security Auditor" ;;
    *)    echo "$1" ;;
  esac
}

get_core_role_default_skills() {
  case "$1" in
    po)   echo "brainstorming founder-skill" ;;
    arch) echo "writing-plans supabase-postgres-best-practices" ;;
    dev)  echo "impeccable vercel-react-best-practices flutter-best-practices supabase-postgres-best-practices lucide-icons simple-icons test-driven-development systematic-debugging" ;;
    qa)   echo "verification-before-completion differential-review semgrep playwright-qa" ;;
    *)    echo "" ;;
  esac
}

get_core_role_override_field() {
  local role_key="$1"
  local field="$2"
  local conf_file="${3:-$(get_active_agents_conf)}"
  [ -f "$conf_file" ] && command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$conf_file" "$role_key" "$field" <<'PYEOF' 2>/dev/null || true
import json, sys
path, role_key, field = sys.argv[1:4]
try:
    data = json.load(open(path, encoding="utf-8"))
    val = ((data.get("overrides") or {}).get(role_key) or {}).get(field, "")
    if isinstance(val, str) and val.strip():
        print(val.strip())
except Exception:
    pass
PYEOF
}

get_core_role_title() {
  local role_key="$1"
  local custom_t
  custom_t="$(get_core_role_override_field "$role_key" "title")"
  if [ -n "$custom_t" ]; then
    echo "$custom_t"
  else
    get_core_role_default_title "$role_key"
  fi
}

get_core_role_skills() {
  local role_key="$1"
  local custom_s
  custom_s="$(get_core_role_override_field "$role_key" "skills")"
  if [ -n "$custom_s" ]; then
    echo "$custom_s"
  else
    get_core_role_default_skills "$role_key"
  fi
}

get_core_role_extra_prompt() {
  local role_key="$1"
  get_core_role_override_field "$role_key" "prompt"
}

# สร้างสารบัญ Progressive Disclosure ของทักษะ (YAML Frontmatter name/description + พาธ SKILL.md + รายการสคริปต์ใน scripts/)
# คืนค่าบรรทัดละ: slug \t skill_md_path \t short_description \t script_files
build_skill_index_tsv() {
  local requested_skills="${1:-}"
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "${RELAY_DIR:-}/skills" "${GLOBAL_DIR:-$HOME/.agents}/skills" "$requested_skills" <<'PYEOF' 2>/dev/null || true
import os, re, sys

proj_skills_dir, global_skills_dir, req_raw = sys.argv[1:4]
req = [s.strip() for s in re.split(r"[\s,]+", req_raw) if s.strip()]

# รวมทักษะเฉพาะของโปรเจกต์ใน .relay/skills/* (ยกเว้น project-learned ที่มีช่องทางแนบแยกอยู่แล้ว)
if os.path.isdir(proj_skills_dir):
    for entry in sorted(os.listdir(proj_skills_dir)):
        if entry == "project-learned" or entry.startswith("."):
            continue
        if os.path.isfile(os.path.join(proj_skills_dir, entry, "SKILL.md")) and entry not in req:
            req.append(entry)

if not req:
    for d in (proj_skills_dir, global_skills_dir):
        if os.path.isdir(d):
            for entry in sorted(os.listdir(d)):
                if entry == "project-learned" or entry.startswith("."):
                    continue
                if os.path.isfile(os.path.join(d, entry, "SKILL.md")) and entry not in req:
                    req.append(entry)

seen = set()
for slug in req:
    if slug in seen:
        continue
    seen.add(slug)
    md_path = ""
    for base in (proj_skills_dir, global_skills_dir):
        cand = os.path.join(base, slug, "SKILL.md")
        if base and os.path.isfile(cand):
            md_path = cand
            break
    if not md_path:
        continue
    desc = ""
    try:
        txt = open(md_path, encoding="utf-8", errors="ignore").read(4096)
        m = re.match(r"^---\s*\n(.*?)\n---\s*\n", txt, re.S)
        if m:
            for line in m.group(1).splitlines():
                if line.strip().lower().startswith("description:"):
                    desc = line.split(":", 1)[1].strip().strip("\"'")
                    break
        if not desc:
            for line in txt.splitlines():
                s = line.strip()
                if s and not s.startswith("#") and not s.startswith("---"):
                    desc = s
                    break
    except Exception:
        pass
    desc = re.sub(r"\s+", " ", desc).replace("\t", " ").strip()
    if len(desc) > 80:
        desc = desc[:77].rstrip() + "..."
    scripts_dir = os.path.join(os.path.dirname(md_path), "scripts")
    scripts = []
    if os.path.isdir(scripts_dir):
        for sf in sorted(os.listdir(scripts_dir)):
            if not sf.startswith(".") and os.path.isfile(os.path.join(scripts_dir, sf)):
                scripts.append(os.path.join(scripts_dir, sf))
    print(f"{slug}\t{md_path}\t{desc or slug}\t{','.join(scripts)}")
PYEOF
}

get_role_progressive_skills_note() {
  local role_key="$1"
  local sk_cur="${2:-}"
  [ -z "$sk_cur" ] && sk_cur="$(get_core_role_skills "$role_key")"
  local tsv
  tsv="$(build_skill_index_tsv "$sk_cur")"
  [ -z "$tsv" ] && return 0
  local entries=()
  local slug md_path desc scripts entry
  while IFS=$'\t' read -r slug md_path desc scripts; do
    [ -z "$slug" ] && continue
    entry="${slug} (${md_path}: ${desc}"
    if [ -n "$scripts" ]; then
      entry="${entry}; scripts=${scripts}"
    fi
    entry="${entry})"
    entries+=("$entry")
  done <<< "$tsv"
  [ "${#entries[@]}" -eq 0 ] && return 0
  local joined=""
  local idx=0
  for entry in "${entries[@]}"; do
    if [ "$idx" -gt 0 ]; then
      joined="${joined} | "
    fi
    joined="${joined}${entry}"
    idx=$((idx + 1))
  done
  printf " [Progressive Skills Index — เปิดอ่านไฟล์ SKILL.md หรือรันสคริปต์ใน scripts/ เฉพาะเมื่อตรงกับงานนี้เท่านั้น: %s]" "$joined"
}

get_core_role_prompt_note() {
  local role_key="$1"
  local ep sk_def sk_cur prog_idx extra=""
  ep="$(get_core_role_extra_prompt "$role_key")"
  sk_def="$(get_core_role_default_skills "$role_key")"
  sk_cur="$(get_core_role_skills "$role_key")"
  if [ -n "$sk_cur" ] && [ "$sk_cur" != "$sk_def" ]; then
    extra="${extra} (ใช้ชุดทักษะประจำบทบาท: ${sk_cur})"
  fi
  prog_idx="$(get_role_progressive_skills_note "$role_key" "$sk_cur")"
  if [ -n "$prog_idx" ]; then
    extra="${extra}${prog_idx}"
  fi
  if [ -n "$ep" ]; then
    extra="${extra} (คำสั่งเพิ่มเติมประจำบทบาท: ${ep})"
  fi
  printf "%s" "$extra"
}

set_core_role_override() {
  local conf_file="$1"
  local role_key="$2"
  local field="$3"
  local val="${4:-}"
  command -v python3 >/dev/null 2>&1 || return 1
  mkdir -p "$(dirname "$conf_file")"
  python3 - "$conf_file" "$role_key" "$field" "$val" <<'PYEOF'
import json, os, sys
path, role_key, field, val = sys.argv[1:5]
data = {"overrides": {}, "agents": []}
if os.path.isfile(path):
    try:
        loaded = json.load(open(path, encoding="utf-8"))
        if isinstance(loaded, dict):
            data.update(loaded)
    except Exception:
        pass
ov = data.setdefault("overrides", {})
if field == "reset":
    ov.pop(role_key, None)
else:
    r = ov.setdefault(role_key, {})
    if val.strip():
        r[field] = val.strip()
    else:
        r.pop(field, None)
    if not r:
        ov.pop(role_key, None)
tmp = f"{path}.tmp.{os.getpid()}"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
PYEOF
}

# คืนค่ารายการ Custom Agents เป็นบรรทัดละ: slug \t title \t provider \t model \t work_mode \t skills \t prompt
list_custom_agents_tsv() {
  local conf_file="${1:-$(get_active_agents_conf)}"
  [ -f "$conf_file" ] && command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$conf_file" <<'PYEOF' 2>/dev/null || true
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path, encoding="utf-8"))
    for a in data.get("agents") or []:
        if not isinstance(a, dict) or not a.get("slug"):
            continue
        vals = [
            str(a.get("slug", "")).replace("\t", " ").replace("\n", " ").strip(),
            str(a.get("title", "")).replace("\t", " ").replace("\n", " ").strip() or a.get("slug", ""),
            str(a.get("provider", "agy")).replace("\t", " ").strip(),
            str(a.get("model", "")).replace("\t", " ").strip(),
            str(a.get("work_mode", "project")).replace("\t", " ").strip(),
            str(a.get("skills", "")).replace("\t", " ").replace("\n", " ").strip(),
            str(a.get("prompt", "")).replace("\t", " ").replace("\n", " ").strip(),
        ]
        print("\t".join(vals))
except Exception:
    pass
PYEOF
}

get_custom_agent_field() {
  local slug="$1"
  local field="$2"
  local conf_file="${3:-$(get_active_agents_conf)}"
  [ -f "$conf_file" ] && command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$conf_file" "$slug" "$field" <<'PYEOF' 2>/dev/null || true
import json, sys
path, slug, field = sys.argv[1:4]
slug = slug.lstrip("@").strip().lower()
try:
    data = json.load(open(path, encoding="utf-8"))
    for a in data.get("agents") or []:
        if isinstance(a, dict) and str(a.get("slug", "")).strip().lower() == slug:
            print(str(a.get(field, "")).strip())
            break
except Exception:
    pass
PYEOF
}

upsert_custom_agent() {
  local conf_file="$1"
  local slug="$2"
  local title="$3"
  local provider="$4"
  local model="$5"
  local work_mode="$6"
  local skills="$7"
  local prompt="$8"
  command -v python3 >/dev/null 2>&1 || return 1
  mkdir -p "$(dirname "$conf_file")"
  python3 - "$conf_file" "$slug" "$title" "$provider" "$model" "$work_mode" "$skills" "$prompt" <<'PYEOF'
import json, os, re, sys
path, slug, title, provider, model, work_mode, skills, prompt = sys.argv[1:9]
slug = re.sub(r"[^a-z0-9_-]+", "-", slug.lstrip("@").strip().lower()).strip("-")
if not slug:
    sys.exit(1)
data = {"overrides": {}, "agents": []}
if os.path.isfile(path):
    try:
        loaded = json.load(open(path, encoding="utf-8"))
        if isinstance(loaded, dict):
            data.update(loaded)
    except Exception:
        pass
agents = data.setdefault("agents", [])
entry = {
    "slug": slug,
    "title": title.strip() or slug,
    "provider": provider.strip() or "agy",
    "model": model.strip(),
    "work_mode": "worktree" if work_mode.strip() == "worktree" else "project",
    "skills": skills.strip(),
    "prompt": prompt.strip(),
}
replaced = False
for idx, a in enumerate(agents):
    if isinstance(a, dict) and str(a.get("slug", "")).lower() == slug:
        agents[idx] = entry
        replaced = True
        break
if not replaced:
    agents.append(entry)
tmp = f"{path}.tmp.{os.getpid()}"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
PYEOF
}

delete_custom_agent() {
  local conf_file="$1"
  local slug="$2"
  [ -f "$conf_file" ] && command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$conf_file" "$slug" <<'PYEOF'
import json, os, sys
path, slug = sys.argv[1:3]
slug = slug.lstrip("@").strip().lower()
try:
    data = json.load(open(path, encoding="utf-8"))
    agents = [a for a in (data.get("agents") or []) if not (isinstance(a, dict) and str(a.get("slug", "")).lower() == slug)]
    data["agents"] = agents
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)
except Exception:
    pass
PYEOF
}

list_available_skill_names() {
  {
    if [ -d "$GLOBAL_DIR/skills" ]; then
      for d in "$GLOBAL_DIR/skills"/*; do
        [ -d "$d" ] && basename "$d"
      done
    fi
    if [ -d "$RELAY_DIR/skills" ]; then
      for d in "$RELAY_DIR/skills"/*; do
        [ -d "$d" ] && basename "$d"
      done
    fi
  } 2>/dev/null | sort -u
}

# ─── 4. แสดงหัวกระดาษสไตล์ Hermes (Split-Header Card + Modular Braille Apple Logo) ───
RELAY_LOGO_STYLE="${RELAY_LOGO_STYLE:-apple}"

render_relay_logo_lines() {
  local style="${1:-${RELAY_LOGO_STYLE:-apple}}"
  case "$style" in
    apple|*)
      printf "%s             ⣠⣤⡀             %s\n" "$C_OK" "$C_RESET"
      printf "%s           ⢀⣾⣿⣿⠏             %s\n" "$C_OK" "$C_RESET"
      printf "%s       ⢀⣠⣴⣾⡿⠋⣠⣴⣾⣦⣄⡀          %s\n" "$C_ACCENT" "$C_RESET"
      printf "%s     ⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦         %s\n" "$C_ACCENT" "$C_RESET"
      printf "%s     ⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠋         %s\n" "$C_ACCENT" "$C_RESET"
      printf "%s     ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁          %s\n" "$C_ACCENT" "$C_RESET"
      printf "%s     ⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀         %s\n" "$C_ACCENT" "$C_RESET"
      printf "%s      ⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿         %s\n" "$C_ACCENT" "$C_RESET"
      printf "%s       ⠈⠻⢿⣿⣿⡿⠛⠻⢿⣿⣿⡿⠋          %s\n" "$C_ACCENT_SH" "$C_RESET"
      ;;
  esac
}

print_dashboard_header() {
  if [ -t 1 ] && [ "${SUBCOMMAND:-hub}" = "hub" ]; then
    printf "\033[H\033[2J"
  fi
  RENDER_NOW="$(date +%s)"

  determine_ux_stage

  local git_branch="no-git"
  if [ -e "$PROJECT_DIR/.git" ]; then
    git_branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
  fi

  local state_badge="${C_WARN}○ no PROJECT_STATE.md${C_RESET}"
  [ -f "$RELAY_DIR/PROJECT_STATE.md" ] && state_badge="${C_OK}● PROJECT_STATE.md${C_RESET}"

  local learned_cnt
  learned_cnt="$(get_learned_skills_count)"
  local learned_pending
  learned_pending="$(get_learned_pending_count)"
  local rules_badge="${C_MUTED}○ 0 rules${C_RESET}"
  if [ "${learned_cnt:-0}" -gt 0 ]; then
    rules_badge="${C_OK}● ${learned_cnt} rules${C_RESET}"
  fi
  if [ "${learned_pending:-0}" -gt 0 ]; then
    rules_badge="${rules_badge} ${C_WARN}▲ ${learned_pending} pending [l]${C_RESET}"
  fi

  local spec_m="${C_MUTED}○ SPEC${C_RESET}"
  local arch_m="${C_MUTED}○ ARCH${C_RESET}"
  local plan_m="${C_MUTED}○ PLAN${C_RESET}"
  local qa_m="${C_MUTED}○ QA${C_RESET}"
  if [ -n "$ACTIVE_TASK" ]; then
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ] && spec_m="${C_OK}● SPEC${C_RESET}"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/ARCH.md" ] && arch_m="${C_OK}● ARCH${C_RESET}"
    [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/PLAN.md" ] && plan_m="${C_OK}● PLAN${C_RESET}"
    if [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_REPORT.md" ] || [ -f "$RELAY_DIR/tasks/$ACTIVE_TASK/QA_VERDICT.json" ]; then
      local hv
      hv="$(qa_verdict "$RELAY_DIR/tasks/$ACTIVE_TASK")"
      if [ "${hv%%|*}" = "PASS" ]; then
        qa_m="${C_OK}● QA PASS${C_RESET}"
      else
        qa_m="${C_WARN}▲ QA ${hv%%|*}${C_RESET}"
      fi
    fi
  fi

  local m_po m_arch m_dev m_qa
  m_po="$(format_role_model_text "$ROLE_PO" "$MODEL_PO" | sed -E 's/[[:space:]]+$//')"
  m_arch="$(format_role_model_text "$ROLE_ARCH" "$MODEL_ARCH" | sed -E 's/[[:space:]]+$//')"
  m_dev="$(format_role_model_text "$ROLE_DEV" "$MODEL_DEV" | sed -E 's/[[:space:]]+$//')"
  m_qa="$(format_role_model_text "$ROLE_QA" "$MODEL_QA" | sed -E 's/[[:space:]]+$//')"

  local s_po s_arch s_dev s_qa
  s_po="$(format_role_status_cell "$ROLE_PO" "$MODEL_PO")"
  s_arch="$(format_role_status_cell "$ROLE_ARCH" "$MODEL_ARCH")"
  s_dev="$(format_role_status_cell "$ROLE_DEV" "$MODEL_DEV")"
  s_qa="$(format_role_status_cell "$ROLE_QA" "$MODEL_QA")"

  local short_proj="~${PROJECT_DIR#$HOME}"
  [ "$short_proj" = "$PROJECT_DIR" ] && short_proj="$PROJECT_NAME"
  if [ "${#short_proj}" -gt 18 ]; then
    short_proj="…/${PROJECT_NAME}"
  fi
  local short_branch="$git_branch"
  if [ "${#short_branch}" -gt 12 ]; then
    short_branch="${short_branch:0:11}…"
  fi
  local left_proj_line="${short_proj} (${short_branch})"
  [ "$IN_HOME_DIR" -eq 1 ] && left_proj_line="~ (Home Directory)"

  local left_task_line="Task: none (ready)"
  [ -n "$ACTIVE_TASK" ] && left_task_line="Task: ${ACTIVE_TASK}"

  local prov_summary="Google AI Ultra · Codex"
  if ! is_provider_logged_in agy && is_provider_logged_in codex; then
    prov_summary="OpenAI Codex CLI"
  elif is_provider_logged_in agy && ! is_provider_logged_in codex; then
    prov_summary="Google AI Ultra (agy)"
  fi

  local right_lines=()
  right_lines+=("${C_ACCENT}${C_BOLD}Agent Roles${C_RESET}")
  right_lines+=("${C_MUTED}@po:${C_RESET}       ${ROLE_PO} (${m_po})  ${s_po}")
  right_lines+=("${C_MUTED}@arch/pm:${C_RESET}  ${ROLE_ARCH} (${m_arch})  ${s_arch}")
  right_lines+=("${C_MUTED}@dev:${C_RESET}      ${ROLE_DEV} (${m_dev})  ${s_dev}")
  right_lines+=("${C_MUTED}@qa/sec:${C_RESET}   ${ROLE_QA} (${m_qa})  ${s_qa}")

  local ca_slug ca_title ca_prov ca_mod ca_wmode ca_skills ca_prompt
  while IFS=$'\t' read -r ca_slug ca_title ca_prov ca_mod ca_wmode ca_skills ca_prompt; do
    [ -z "$ca_slug" ] && continue
    local ca_m ca_s
    ca_m="$(format_role_model_text "$ca_prov" "$ca_mod" | sed -E 's/[[:space:]]+$//')"
    ca_s="$(format_role_status_cell "$ca_prov" "$ca_mod")"
    right_lines+=("${C_MUTED}@${ca_slug}:${C_RESET}   ${ca_prov} (${ca_m})  ${ca_s}")
  done < <(list_custom_agents_tsv)

  right_lines+=("")
  local q_line
  while IFS= read -r q_line; do
    [ -z "$q_line" ] && continue
    q_line="$(printf "%s" "$q_line" | sed -E "s/^(\x1b\[[0-9;]*m)*│(\x1b\[[0-9;]*m)*[[:space:]]+//")"
    right_lines+=("$q_line")
  done < <(render_quota_table 2>/dev/null || true)

  right_lines+=("")
  right_lines+=("${C_ACCENT}${C_BOLD}Pipeline & Telemetry${C_RESET}")
  if [ "$UX_STAGE" -eq 1 ]; then
    right_lines+=("${C_MUTED}stage:${C_RESET}    Step 1/3 Setup & Auth AI Roles (${READY_ROLE_COUNT}/4 ready)")
    right_lines+=("${C_MUTED}next:${C_RESET}     กด [1] ตั้งค่าด่วน Google AI Ultra + Codex หรือ [3] Login CLI")
  elif [ "$UX_STAGE" -eq 2 ]; then
    right_lines+=("${C_MUTED}stage:${C_RESET}    Step 2/3 Initialize Project (.relay/PROJECT_STATE.md)")
    if [ "$IN_HOME_DIR" -eq 1 ]; then
      right_lines+=("${C_MUTED}next:${C_RESET}     กด [1] เลือกหรือสร้างโฟลเดอร์โปรเจกต์")
    else
      right_lines+=("${C_MUTED}next:${C_RESET}     กด [1] Greenfield หรือ [2] Brownfield สำหรับ '${PROJECT_NAME}'")
    fi
  else
    right_lines+=("${C_MUTED}status:${C_RESET}   ${spec_m}  ${arch_m}  ${plan_m}  ${qa_m}  ·  ${state_badge}  ·  ${rules_badge}")
    local task_telem=""
    [ -n "$ACTIVE_TASK" ] && task_telem="$(get_task_telemetry_summary_inline "$ACTIVE_TASK")"
    if [ -n "$task_telem" ]; then
      right_lines+=("${C_MUTED}session:${C_RESET}  ${task_telem}")
    else
      right_lines+=("${C_MUTED}session:${C_RESET}  ${C_MUTED}0 runs in current task · press [v] for telemetry${C_RESET}")
    fi
    right_lines+=("${C_MUTED}next:${C_RESET}     ${STAGE3_FOCUS_TEXT}")
  fi

  local left_lines=()
  local l_line
  while IFS= read -r l_line; do
    left_lines+=("$l_line")
  done < <(render_relay_logo_lines "$RELAY_LOGO_STYLE")
  left_lines+=("")
  left_lines+=("${C_ACCENT}${prov_summary}${C_RESET}")
  left_lines+=("${C_MUTED}${left_proj_line}${C_RESET}")
  left_lines+=("${C_MUTED}${left_task_line}${C_RESET}")

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$C_MUTED" "$C_ACCENT" "$C_BOLD" "$C_RESET" "${#left_lines[@]}" "${left_lines[@]}" "${right_lines[@]}" <<'PYEOF'
import re, sys, unicodedata

MUTED, ACC, BOLD, RST = sys.argv[1:5]
n_left = int(sys.argv[5])
left_lines = sys.argv[6:6 + n_left]
right_lines = sys.argv[6 + n_left:]

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")

def vis_width(s):
    clean = ANSI_RE.sub("", s)
    w = 0
    for c in clean:
        if unicodedata.combining(c) or unicodedata.category(c) in ("Mn", "Me", "Cf"):
            continue
        w += 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1
    return w

def pad_right(s, target_w):
    return s + (" " * max(0, target_w - vis_width(s)))

def center_line(s, target_w):
    vw = vis_width(s)
    if vw > target_w:
        clean = ANSI_RE.sub("", s)
        prefix_m = ANSI_RE.match(s)
        pre = prefix_m.group(0) if prefix_m else ""
        cut = clean[:max(1, target_w - 1)] + "…"
        s = pre + cut + RST
        vw = vis_width(s)
    left_pad = (target_w - vw) // 2
    right_pad = target_w - vw - left_pad
    return (" " * left_pad) + s + (" " * right_pad)

LEFT_W = 30
formatted_left = []
for idx, line in enumerate(left_lines):
    if idx >= 10 and line.strip():
        formatted_left.append(center_line(line, LEFT_W))
    else:
        formatted_left.append(pad_right(line, LEFT_W))

RIGHT_W = max([48] + [vis_width(r) for r in right_lines])
total_rows = max(len(formatted_left), len(right_lines))
title_plain = " RELAY v1.0.0 "
left_bar_len = LEFT_W + 2
right_bar_len = max(4, (LEFT_W + 2 + RIGHT_W + 2) - left_bar_len - len(title_plain))

print(f"{MUTED}╭{'─' * left_bar_len}{RST}{BOLD}{ACC}{title_plain}{RST}{MUTED}{'─' * right_bar_len}╮{RST}")
for i in range(total_rows):
    l_cell = formatted_left[i] if i < len(formatted_left) else (" " * LEFT_W)
    r_cell = pad_right(right_lines[i], RIGHT_W) if i < len(right_lines) else (" " * RIGHT_W)
    print(f"{MUTED}│{RST} {l_cell}  {r_cell} {MUTED}│{RST}")
print(f"{MUTED}╰{'─' * (LEFT_W + 2 + RIGHT_W + 2)}╯{RST}")
PYEOF
  else
    printf "%s╭────────────────────────────── RELAY v1.0.0 ──────────────────────────────╮%s\n" "$C_MUTED" "$C_RESET"
    local r_item
    for r_item in "${right_lines[@]}"; do
      printf "%s│%s  %b\n" "$C_MUTED" "$C_RESET" "$r_item"
    done
    printf "%s╰──────────────────────────────────────────────────────────────────────────╯%s\n" "$C_MUTED" "$C_RESET"
  fi
  RENDER_NOW=""
}

# ─── 4.5 การตรวจสอบโควต้าคงเหลือรายค่าย ([u] / /quota / relay quota) ─────
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
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_MUTED" "$C_RESET"
  printf "%s│%s %s%sQuota Monitor (5h / 7d) — สถานะโควต้าแยกตามค่ายและโมเดล%s\n" "$C_MUTED" "$C_RESET" "$C_ACCENT" "$C_BOLD" "$C_RESET"
  printf "%s│%s %sอัปเดตล่าสุดเมื่อเวลา: %s  (ดึงข้อมูลจาก CLI ทั้ง 3 ค่ายโดยตรง)%s\n" "$C_MUTED" "$C_RESET" "$C_MUTED" "${QUOTA_UPDATED_AT:--}" "$C_RESET"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_MUTED" "$C_RESET"
  printf "%s│%s %s1. Google AI Ultra — Gemini Models (agy)%s\n" "$C_MUTED" "$C_RESET" "$C_BOLD" "$C_RESET"
  [ "$AGY_FETCH_OK" = "0" ] && printf "%s│%s    %s▲ ดึงข้อมูลสดไม่สำเร็จ — แสดงค่าล่าสุดเมื่อ %s%s\n" "$C_MUTED" "$C_RESET" "$C_WARN" "$AGY_FETCHED_AT" "$C_RESET"
  printf "%s│%s    • 5-Hour Window : %b   %s(%s)%s\n" "$C_MUTED" "$C_RESET" "$(format_quota_bar "$g5")" "$C_MUTED" "$(format_reset_detail "$AGY_GEMINI_5H_RESET_EPOCH" "$AGY_GEMINI_5H_RESET")" "$C_RESET"
  printf "%s│%s    • Weekly 7-Day  : %b   %s(%s)%s\n" "$C_MUTED" "$C_RESET" "$(format_quota_bar "$g7")" "$C_MUTED" "$(format_reset_detail "$AGY_GEMINI_7D_RESET_EPOCH" "$AGY_GEMINI_7D_RESET")" "$C_RESET"
  printf "%s│%s\n" "$C_MUTED" "$C_RESET"
  printf "%s│%s %s2. Google AI Ultra — Claude & GPT Models (agy)%s\n" "$C_MUTED" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s    • 5-Hour Window : %b   %s(%s)%s\n" "$C_MUTED" "$C_RESET" "$(format_quota_bar "$a5")" "$C_MUTED" "$(format_reset_detail "$AGY_CLAUDE_5H_RESET_EPOCH" "$AGY_CLAUDE_5H_RESET")" "$C_RESET"
  printf "%s│%s    • Weekly 7-Day  : %b   %s(%s)%s\n" "$C_MUTED" "$C_RESET" "$(format_quota_bar "$a7")" "$C_MUTED" "$(format_reset_detail "$AGY_CLAUDE_7D_RESET_EPOCH" "$AGY_CLAUDE_7D_RESET")" "$C_RESET"
  printf "%s│%s\n" "$C_MUTED" "$C_RESET"
  printf "%s│%s %s3. OpenAI Codex CLI — %s (codex)%s\n" "$C_MUTED" "$C_RESET" "$C_BOLD" "$CODEX_PLAN" "$C_RESET"
  [ "$CODEX_FETCH_OK" = "0" ] && printf "%s│%s    %s▲ ดึงข้อมูลสดไม่สำเร็จ — แสดงค่าล่าสุดเมื่อ %s%s\n" "$C_MUTED" "$C_RESET" "$C_WARN" "$CODEX_FETCHED_AT" "$C_RESET"
  printf "%s│%s    • 5-Hour Window : %b   %s(%s)%s\n" "$C_MUTED" "$C_RESET" "$(format_quota_bar "$x5")" "$C_MUTED" "$(format_reset_detail "$CODEX_5H_RESET_EPOCH" "$CODEX_5H_RESET")" "$C_RESET"
  printf "%s│%s    • Weekly 7-Day  : %b   %s(%s)%s\n" "$C_MUTED" "$C_RESET" "$(format_quota_bar "$x7")" "$C_MUTED" "$(format_reset_detail "$CODEX_7D_RESET_EPOCH" "$CODEX_7D_RESET")" "$C_RESET"
  printf "%s│%s\n" "$C_MUTED" "$C_RESET"
  printf "%s│%s %s4. Anthropic Claude Code CLI — %s (claude)%s\n" "$C_MUTED" "$C_RESET" "$C_BOLD" "$CLAUDE_PLAN" "$C_RESET"
  [ "$CLAUDE_FETCH_OK" = "0" ] && printf "%s│%s    %s▲ ดึงข้อมูลสดไม่สำเร็จ — แสดงค่าล่าสุดเมื่อ %s%s\n" "$C_MUTED" "$C_RESET" "$C_WARN" "$CLAUDE_FETCHED_AT" "$C_RESET"
  printf "%s│%s    • 5-Hour Window : %b   %s(%s)%s\n" "$C_MUTED" "$C_RESET" "$(format_quota_bar "$c5")" "$C_MUTED" "$(format_reset_detail "$CLAUDE_5H_RESET_EPOCH" "$CLAUDE_5H_RESET")" "$C_RESET"
  printf "%s│%s    • Weekly 7-Day  : %b   %s(%s)%s\n" "$C_MUTED" "$C_RESET" "$(format_quota_bar "$c7")" "$C_MUTED" "$(format_reset_detail "$CLAUDE_7D_RESET_EPOCH" "$CLAUDE_7D_RESET")" "$C_RESET"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_MUTED" "$C_RESET"
  printf "%s│%s %sStatus Summary:%s\n" "$C_MUTED" "$C_RESET" "$C_BOLD" "$C_RESET"
  if [[ "$c7" =~ ^[0-9]+$ ]] && [ "$c7" -lt 20 ]; then
    printf "%s│%s  %s▲ โควต้ารายสัปดาห์ของ claude เหลือ %s%% (%s) — แนะนำให้สลับไปใช้ agy (เหลือ %s%%)%s\n" \
      "$C_MUTED" "$C_RESET" "$C_WARN" "$c7" "$(format_reset_detail "$CLAUDE_7D_RESET_EPOCH" "$CLAUDE_7D_RESET")" "$a7" "$C_RESET"
  else
    printf "%s│%s  %s● โควต้าทุกตำแหน่งพร้อมทำงานต่อเนื่อง%s\n" "$C_MUTED" "$C_RESET" "$C_OK" "$C_RESET"
  fi
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_MUTED" "$C_RESET"
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
    u_tag="● พร้อมใช้ทันที"
  fi
  is_provider_logged_in agy    && a_tag="● พร้อมใช้ทันที"
  is_provider_logged_in codex  && x_tag="● พร้อมใช้ทันที"
  is_provider_logged_in claude && c_tag="● พร้อมใช้ทันที"

  interactive_menu "เลือกชุดการตั้งค่าด่วน (รองรับโควตา Google AI Ultra ผ่าน agy + Codex)" 0 \
    "1|★ ชุดผสมแนะนำ (Google AI Ultra + Codex) — @po=agy(gemini-4-argon-high), @arch=agy(claude-opus-5-5-high), @dev=agy(claude-sonnet-5-5-high), @qa=codex(${codex_def}) [${u_tag}]" \
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
# คืนค่ารายการโปรเจกต์ในเครื่องเป็น TSV: has_relay(1|0) \t dir_name \t full_path \t status_note
# เรียงโปรเจกต์ที่ติดตั้ง .relay/ แล้ว (has_relay=1) ไว้ด้านบนสุดเสมอ เพื่อไม่ให้ถูกตัดตกขอบ
list_workspace_projects_tsv() {
  local roots=("$@")
  if [ "${#roots[@]}" -eq 0 ]; then
    roots=("$HOME/dev_bos" "$HOME/Projects" "$HOME/workspace" "$HOME/Developer")
  fi
  local relay_rows=()
  local std_rows=()
  local search_root d dname active_t
  for search_root in "${roots[@]}"; do
    [ -d "$search_root" ] || continue
    for d in "$search_root"/*; do
      [ -d "$d" ] || continue
      dname="$(basename "$d")"
      [[ "$dname" == .* ]] && continue
      if [ -f "$d/.relay/PROJECT_STATE.md" ] || [ -d "$d/.relay/tasks" ]; then
        active_t="$(ls -1 "$d/.relay/tasks" 2>/dev/null | grep -v '^\.' | sort | tail -n 1 || true)"
        if [ -n "$active_t" ]; then
          relay_rows+=("1"$'\t'"$dname"$'\t'"$d"$'\t'"Task: $active_t")
        else
          relay_rows+=("1"$'\t'"$dname"$'\t'"$d"$'\t'"พร้อมเริ่มงานใหม่")
        fi
      else
        std_rows+=("0"$'\t'"$dname"$'\t'"$d"$'\t'"โปรเจกต์ทั่วไป")
      fi
    done
  done
  local r
  for r in "${relay_rows[@]}"; do
    printf "%s\n" "$r"
  done
  for r in "${std_rows[@]}"; do
    printf "%s\n" "$r"
  done
}

select_or_create_project_dir() {
  local base_workspace="$HOME/dev_bos"
  [ ! -d "$base_workspace" ] && base_workspace="$HOME/Projects"

  local folder_items=()
  local folder_paths=()
  folder_items+=("n|★ สร้างโปรเจกต์ใหม่ตั้งแต่ศูนย์ (สร้างโฟลเดอร์ + git init + .relay/ อัตโนมัติ)")

  local idx=1
  local has_relay dname d status_note short_name disp_path
  while IFS=$'\t' read -r has_relay dname d status_note; do
    [ -z "$d" ] && continue
    short_name="$dname"
    if [ "${#short_name}" -gt 26 ]; then
      short_name="${short_name:0:23}..."
    fi
    disp_path="~${d#$HOME}"
    if [ "$has_relay" = "1" ]; then
      folder_items+=("${idx}|$(printf "● [RELAY]   %-26s  %s (%s)" "$short_name" "$disp_path" "$status_note")")
    else
      folder_items+=("${idx}|$(printf "○ [ทั่วไป]   %-26s  %s" "$short_name" "$disp_path")")
    fi
    folder_paths[$idx]="$d"
    idx=$((idx + 1))
    [ "$idx" -gt 9 ] && break
  done < <(list_workspace_projects_tsv)

  folder_items+=("p|พิมพ์ระบุ Path ของโฟลเดอร์โปรเจกต์ด้วยตนเอง")
  folder_items+=("b|ย้อนกลับ")

  interactive_menu "เลือกโปรเจกต์ที่ต้องการเปิดใช้ RELAY (● ติดตั้ง .relay/ แล้ว • ○ โปรเจกต์ทั่วไปในเครื่อง)" 0 "${folder_items[@]}"

  case "$MENU_RESULT" in
    n|N)
      echo ""
      read -r -p "ตั้งชื่อโฟลเดอร์โปรเจกต์ใหม่ (ภาษาอังกฤษ เช่น my-saas-app หรือพิมพ์ b เพื่อย้อนกลับ): " new_proj_name || true
      if is_back_input "$new_proj_name"; then
        return 0
      fi
      new_proj_name="$(echo "${new_proj_name:-my-relay-app}" | tr ' ' '-' | sed -E 's/[^a-zA-Z0-9_-]+/-/g; s/^-|-$//g')"
      mkdir -p "$base_workspace/$new_proj_name"
      PROJECT_DIR="$base_workspace/$new_proj_name"
      cd "$PROJECT_DIR" || true
      refresh_project_paths
      "$GLOBAL_DIR/bin/relay-init" "$PROJECT_DIR" new
      CURRENT_TASK=""
      printf "\n%s● สร้างและเข้าสู่โปรเจกต์ใหม่เรียบร้อย: %s%s\n" "$C_OK" "$PROJECT_DIR" "$C_RESET"
      ;;
    [1-9])
      local chosen_dir="${folder_paths[$MENU_RESULT]:-}"
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
      read -r -p "ระบุ Path ของโฟลเดอร์โปรเจกต์ (เช่น ~/dev_bos/my-app หรือพิมพ์ b เพื่อย้อนกลับ): " custom_path || true
      if is_back_input "$custom_path" || [ -z "$custom_path" ]; then
        return 0
      fi
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
PROVIDER_CHOICE_CANCELLED=0
MODEL_CHOICE_CANCELLED=0

choose_provider_interactive() {
  local role_label="$1"
  local current_p="$2"
  PROVIDER_CHOICE_CANCELLED=0
  refresh_cli_auth_cache

  local a_stat x_stat c_stat
  a_stat="$(get_provider_auth_detail agy)"
  x_stat="$(get_provider_auth_detail codex)"
  c_stat="$(get_provider_auth_detail claude)"

  interactive_menu "เลือกค่าย AI สำหรับ ${role_label} (ปัจจุบัน: ${current_p})" 0 \
    "1|agy    — Google AI Ultra / Antigravity CLI [${a_stat}]" \
    "2|codex  — OpenAI Codex CLI                  [${x_stat}]" \
    "3|claude — Anthropic Claude Code CLI         [${c_stat}]" \
    "m|คงค่ายเดิม (${current_p}) และเลือกเฉพาะ Model" \
    "b|ย้อนกลับ (ไม่เปลี่ยนแปลงค่า)"

  local chosen_p="$current_p"
  case "$MENU_RESULT" in
    1) chosen_p="agy" ;;
    2) chosen_p="codex" ;;
    3) chosen_p="claude" ;;
    m|M) chosen_p="$current_p" ;;
    *)
      PROVIDER_CHOICE_CANCELLED=1
      SELECTED_PROVIDER="$current_p"
      return 1
      ;;
  esac

  if ! is_provider_installed "$chosen_p"; then
    local pkg="@openai/codex"
    [ "$chosen_p" = "claude" ] && pkg="@anthropic-ai/claude-code"

    interactive_menu "ค่าย '${chosen_p}' ยังไม่ได้ติดตั้งในเครื่อง ต้องการติดตั้งเลยหรือไม่?" 0 \
      "1|ติดตั้ง ${chosen_p} อัตโนมัติเดี๋ยวนี้ (npm install -g ${pkg}) และเปิดหน้าเข้าสู่ระบบ" \
      "2|บันทึกชื่อค่ายไว้ก่อน (ติดตั้งภายหลัง)" \
      "b|ย้อนกลับ"
    case "$MENU_RESULT" in
      1)
        npm install -g "$pkg"
        if is_provider_installed "$chosen_p"; then
          login_single_provider "$chosen_p"
        fi
        ;;
      2) ;;
      *)
        PROVIDER_CHOICE_CANCELLED=1
        SELECTED_PROVIDER="$current_p"
        return 1
        ;;
    esac
  elif ! is_provider_logged_in "$chosen_p"; then
    interactive_menu "ค่าย '${chosen_p}' ติดตั้งแล้วแต่ยังไม่ได้เข้าสู่ระบบ ต้องการดำเนินการเลยหรือไม่?" 0 \
      "1|★ เปิดหน้าเข้าสู่ระบบของ ${chosen_p} เดี๋ยวนี้" \
      "2|เลือกโมเดลไว้ก่อน (เข้าสู่ระบบภายหลัง)" \
      "b|ย้อนกลับ"
    case "$MENU_RESULT" in
      1) login_single_provider "$chosen_p" ;;
      2) ;;
      *)
        PROVIDER_CHOICE_CANCELLED=1
        SELECTED_PROVIDER="$current_p"
        return 1
        ;;
    esac
  fi

  SELECTED_PROVIDER="$chosen_p"
  return 0
}

choose_model_interactive() {
  local provider="$1"
  local role_label="$2"
  local current_m="${3:-}"
  MODEL_CHOICE_CANCELLED=0
  local cli_def
  cli_def="$(get_cli_default_model "$provider")"
  local fallback_m="${current_m:-$cli_def}"

  local menu_items=()
  local model_ids=()
  local idx=1
  while IFS='|' read -r mid mdesc; do
    [ -z "$mid" ] && continue
    menu_items+=("${idx}|$(printf "%-24s — %s" "$mid" "$mdesc")")
    model_ids[$idx]="$mid"
    idx=$((idx + 1))
  done < <(get_cli_live_models "$provider")

  menu_items+=("c|กำหนดรหัสโมเดลด้วยตนเอง    — พิมพ์ชื่อ Model ID ที่ต้องการ")
  menu_items+=("b|ย้อนกลับ                    — คงค่าโมเดลเดิม (${fallback_m})")

  interactive_menu "เลือก Model ของค่าย [${provider}] สำหรับ ${role_label} (ดึงจาก CLI ในเครื่องโดยตรง)" 0 "${menu_items[@]}"

  if [ "$MENU_RESULT" = "b" ] || [ "$MENU_RESULT" = "B" ]; then
    MODEL_CHOICE_CANCELLED=1
    SELECTED_MODEL="$fallback_m"
    return 1
  elif [ "$MENU_RESULT" = "c" ] || [ "$MENU_RESULT" = "C" ]; then
    local custom_m=""
    read -r -p "ระบุชื่อ Model ของ ${provider} (หรือพิมพ์ b เพื่อย้อนกลับ): " custom_m || true
    custom_m="$(sanitize_model_id "$custom_m")"
    if is_back_input "$custom_m" || [ -z "$custom_m" ]; then
      MODEL_CHOICE_CANCELLED=1
      SELECTED_MODEL="$fallback_m"
      return 1
    fi
    SELECTED_MODEL="$custom_m"
  elif [ -n "${model_ids[$MENU_RESULT]:-}" ]; then
    SELECTED_MODEL="${model_ids[$MENU_RESULT]}"
  else
    MODEL_CHOICE_CANCELLED=1
    SELECTED_MODEL="$fallback_m"
    return 1
  fi
  return 0
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
        printf "\n%sกำลังเปิดหน้าเข้าสู่ระบบของ Claude Code (claude auth login)...%s\n" "$C_ACCENT" "$C_RESET"
        claude auth login || claude || true
      else
        printf "%s✖ ยังไม่ได้ติดตั้ง claude%s\n" "$C_ERR" "$C_RESET"
      fi
      ;;
    codex)
      if is_provider_installed codex; then
        printf "\n%sกำลังเปิดหน้าเข้าสู่ระบบของ OpenAI Codex (codex login)...%s\n" "$C_ACCENT" "$C_RESET"
        codex login || true
      else
        printf "%s✖ ยังไม่ได้ติดตั้ง codex%s\n" "$C_ERR" "$C_RESET"
      fi
      ;;
  esac
  refresh_cli_auth_cache
}

# ─── 9. การตั้งค่าค่าย AI และเลือก Model ประจำตำแหน่ง ([c] / /model) ───────────
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

    interactive_menu "ตั้งค่าค่าย AI และเลือก Model ประจำตำแหน่ง [พร้อม ${READY_ROLE_COUNT}/4 • ${scope_label}]" 0 \
      "p|★ ตั้งค่าด่วนครบ 4 ตำแหน่ง (Google AI Ultra agy + Codex)" \
      "1|ขั้นตอนที่ 1 (@po)       ➔ ค่าย: ${ROLE_PO} | โมเดล: ${MODEL_PO} (${r1_stat})" \
      "2|ขั้นตอนที่ 2 (@arch/@pm) ➔ ค่าย: ${ROLE_ARCH} | โมเดล: ${MODEL_ARCH} (${r2_stat})" \
      "3|ขั้นตอนที่ 3 (@dev)      ➔ ค่าย: ${ROLE_DEV} | โมเดล: ${MODEL_DEV} (${r3_stat})" \
      "4|ขั้นตอนที่ 4 (@qa/@sec)  ➔ ค่าย: ${ROLE_QA} | โมเดล: ${MODEL_QA} (${r4_stat})" \
      "g|จัดการบทบาท Agent, คำสั่ง Prompt และทักษะประจำตำแหน่ง (/agents)" \
      "r|อัปเดตรายชื่อโมเดล Google AI Ultra ล่าสุดจาก 'agy models'" \
      "d|จัดการการเชื่อมต่อ CLI และการเข้าสู่ระบบ (agy / codex / claude)" \
      "m|ตั้งค่า Default Model เริ่มต้นของแต่ละค่ายในไฟล์ระบบ CLI" \
      "s|สลับไฟล์บันทึกการตั้งค่า (Global ~/.agents/ ↔ Project .relay/roles.conf)" \
      "t|บันทึกและทดสอบความพร้อม Agent ทุกตำแหน่ง (/test)" \
      "b|ย้อนกลับสู่หน้าจอหลัก"

    case "$MENU_RESULT" in
      1)
        if choose_provider_interactive "ขั้นตอนที่ 1 (@po)" "$ROLE_PO"; then
          local next_p="$SELECTED_PROVIDER"
          if choose_model_interactive "$next_p" "ขั้นตอนที่ 1 (@po)" "$MODEL_PO"; then
            ROLE_PO="$next_p"
            MODEL_PO="$SELECTED_MODEL"
            save_role_config "$target_conf"
          fi
        fi
        ;;
      2)
        if choose_provider_interactive "ขั้นตอนที่ 2 (@arch/@pm)" "$ROLE_ARCH"; then
          local next_p="$SELECTED_PROVIDER"
          if choose_model_interactive "$next_p" "ขั้นตอนที่ 2 (@arch/@pm)" "$MODEL_ARCH"; then
            ROLE_ARCH="$next_p"
            MODEL_ARCH="$SELECTED_MODEL"
            save_role_config "$target_conf"
          fi
        fi
        ;;
      3)
        if choose_provider_interactive "ขั้นตอนที่ 3 (@dev)" "$ROLE_DEV"; then
          local next_p="$SELECTED_PROVIDER"
          if choose_model_interactive "$next_p" "ขั้นตอนที่ 3 (@dev)" "$MODEL_DEV"; then
            ROLE_DEV="$next_p"
            MODEL_DEV="$SELECTED_MODEL"
            save_role_config "$target_conf"
          fi
        fi
        ;;
      4)
        if choose_provider_interactive "ขั้นตอนที่ 4 (@qa/@sec)" "$ROLE_QA"; then
          local next_p="$SELECTED_PROVIDER"
          if choose_model_interactive "$next_p" "ขั้นตอนที่ 4 (@qa/@sec)" "$MODEL_QA"; then
            ROLE_QA="$next_p"
            MODEL_QA="$SELECTED_MODEL"
            save_role_config "$target_conf"
          fi
        fi
        ;;
      g|G)
        save_role_config "$target_conf"
        run_agents_manager_menu
        load_role_config
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
        if choose_model_interactive "claude" "ค่าเริ่มต้นของ Claude Code CLI" "$cm"; then
          set_cli_default_model "claude" "$SELECTED_MODEL"
        fi
        ;;
      2)
        if choose_model_interactive "codex" "ค่าเริ่มต้นของ OpenAI Codex CLI" "$xm"; then
          set_cli_default_model "codex" "$SELECTED_MODEL"
        fi
        ;;
      *) break ;;
    esac
  done
}

# ─── 11. การจัดการเชื่อมต่อ CLI และการเข้าสู่ระบบ (RELAY Doctor / /connect) ────
run_doctor_menu() {
  while true; do
    refresh_cli_auth_cache
    echo ""
    printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
    printf "%s│%s %sสถานะการติดตั้ง CLI, การเข้าสู่ระบบ และโมเดลเริ่มต้นของแต่ละค่าย%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
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

    interactive_menu "เลือกการจัดการเข้าสู่ระบบ หรืออัปเดตโมเดลและ CLI" 0 \
      "1|อัปเดตรายชื่อโมเดล Google AI Ultra ล่าสุดจาก 'agy models'" \
      "2|เข้าสู่ระบบ OpenAI Codex (รัน codex login)" \
      "3|เข้าสู่ระบบ Claude Code แยกต่างหาก (รัน claude auth login)" \
      "4|ติดตั้งหรืออัปเดต CLI (codex + claude)" \
      "m|ตั้งค่า Default Model เริ่มต้นของแต่ละค่ายในไฟล์ระบบ CLI" \
      "b|ย้อนกลับสู่หน้าจอหลัก"

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
    if [ -d "$GLOBAL_DIR/skills/$sk" ] || [ -d "$RELAY_DIR/skills/$sk" ] || { [ "$sk" = "founder-skill" ] && [ -d "$GLOBAL_DIR/skills/founder-plan" ]; }; then
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
  printf "%s│%s กำลังทดสอบการรายงานตัวของ: %s%s%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$role_title" "$C_RESET"
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
4. ปิดท้ายด้วยข้อความ 'สถานะ: พร้อมปฏิบัติงาน'"

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
    printf "%s● [ผ่านการทดสอบ] %s เชื่อมต่อกับ %s (%s) และพร้อมใช้งานเรียบร้อย%s\n" "$C_OK" "$role_title" "$provider" "$configured_model" "$C_RESET"
  else
    printf "%s✖ [ไม่ผ่านการทดสอบ] %s ไม่สามารถรับคำสั่งผ่าน %s (%s) ได้%s\n" "$C_ERR" "$role_title" "$provider" "$configured_model" "$C_RESET"
  fi
}

run_agent_readiness_test() {
  check_all_roles_ready
  local po_title arch_title dev_title qa_title
  po_title="$(get_core_role_title po)"
  arch_title="$(get_core_role_title arch)"
  dev_title="$(get_core_role_title dev)"
  qa_title="$(get_core_role_title qa)"

  local po_skills arch_skills dev_skills qa_skills
  po_skills="$(get_core_role_skills po)"
  arch_skills="$(get_core_role_skills arch)"
  dev_skills="$(get_core_role_skills dev)"
  qa_skills="$(get_core_role_skills qa)"

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %sตรวจสอบบทบาท โมเดล การเข้าสู่ระบบ และทักษะประจำตำแหน่ง (RELAY Agent Readiness)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s1. ขั้นตอนที่ 1: @po (%s — สร้าง SPEC.md)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$po_title" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_PO" "$(format_role_model_text "$ROLE_PO" "$MODEL_PO")" "$(format_role_status_cell "$ROLE_PO" "$MODEL_PO")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_ACCENT" "$C_RESET" "$(get_provider_rules_status "$ROLE_PO")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_ACCENT" "$C_RESET" "$(check_role_skills_status "$po_skills")"
  printf "%s│%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s2. ขั้นตอนที่ 2: @arch & @pm (%s — สร้าง ARCH & PLAN)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$arch_title" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_ARCH" "$(format_role_model_text "$ROLE_ARCH" "$MODEL_ARCH")" "$(format_role_status_cell "$ROLE_ARCH" "$MODEL_ARCH")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_ACCENT" "$C_RESET" "$(get_provider_rules_status "$ROLE_ARCH")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_ACCENT" "$C_RESET" "$(check_role_skills_status "$arch_skills")"
  printf "%s│%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s3. ขั้นตอนที่ 3: @dev (%s — พัฒนาโค้ดใน Git Worktree)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$dev_title" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_DEV" "$(format_role_model_text "$ROLE_DEV" "$MODEL_DEV")" "$(format_role_status_cell "$ROLE_DEV" "$MODEL_DEV")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_ACCENT" "$C_RESET" "$(get_provider_rules_status "$ROLE_DEV")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_ACCENT" "$C_RESET" "$(check_role_skills_status "$dev_skills")"
  printf "%s│%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %s4. ขั้นตอนที่ 4: @qa & @sec (%s — สร้าง QA_REPORT.md)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$qa_title" "$C_RESET"
  printf "%s│%s    • ค่าย / โมเดล : %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ROLE_QA" "$(format_role_model_text "$ROLE_QA" "$MODEL_QA")" "$(format_role_status_cell "$ROLE_QA" "$MODEL_QA")"
  printf "%s│%s    • กฎส่วนกลาง  : %b\n" "$C_ACCENT" "$C_RESET" "$(get_provider_rules_status "$ROLE_QA")"
  printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_ACCENT" "$C_RESET" "$(check_role_skills_status "$qa_skills")"

  local ca_slug ca_title ca_prov ca_mod ca_wmode ca_skills ca_prompt
  local ca_idx=5
  while IFS=$'\t' read -r ca_slug ca_title ca_prov ca_mod ca_wmode ca_skills ca_prompt; do
    [ -z "$ca_slug" ] && continue
    printf "%s│%s\n" "$C_ACCENT" "$C_RESET"
    printf "%s│%s %s%d. ตำแหน่งเพิ่มเติม: @%s (%s — โหมด: %s)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$ca_idx" "$ca_slug" "$ca_title" "$ca_wmode" "$C_RESET"
    printf "%s│%s    • ค่าย / โมเดล : %-6s │ %s │ %b\n" "$C_ACCENT" "$C_RESET" "$ca_prov" "$(format_role_model_text "$ca_prov" "$ca_mod")" "$(format_role_status_cell "$ca_prov" "$ca_mod")"
    printf "%s│%s    • ทักษะประจำตัว: %b\n" "$C_ACCENT" "$C_RESET" "$(check_role_skills_status "${ca_skills:--}")"
    ca_idx=$((ca_idx + 1))
  done < <(list_custom_agents_tsv)
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  interactive_menu "เลือกตำแหน่งที่ต้องการทดสอบให้ AI รายงานบทบาทและทักษะจริง" 0 \
    "1|★ ทดสอบครบทุกตำแหน่ง (@po, @arch/@pm, @dev, @qa/@sec และตำแหน่งเพิ่มเติม)" \
    "2|ทดสอบเฉพาะ ขั้นตอนที่ 1 (@po        ➔ ${ROLE_PO} / ${MODEL_PO})" \
    "3|ทดสอบเฉพาะ ขั้นตอนที่ 2 (@arch/@pm  ➔ ${ROLE_ARCH} / ${MODEL_ARCH})" \
    "4|ทดสอบเฉพาะ ขั้นตอนที่ 3 (@dev       ➔ ${ROLE_DEV} / ${MODEL_DEV})" \
    "5|ทดสอบเฉพาะ ขั้นตอนที่ 4 (@qa/@sec   ➔ ${ROLE_QA} / ${MODEL_QA})" \
    "g|จัดการบทบาท Agent, คำสั่ง Prompt และทักษะประจำตำแหน่ง (/agents)" \
    "c|ตั้งค่าค่าย AI และเลือก Model ประจำตำแหน่ง (/model)" \
    "b|ย้อนกลับสู่หน้าจอหลัก"

  case "$MENU_RESULT" in
    1)
      ping_single_role_agent "@po" "ขั้นตอนที่ 1: @po ($po_title)" "$ROLE_PO" "$MODEL_PO" "$po_skills" "ซักถามความต้องการและสรุปเป็นเอกสาร SPEC.md $(get_core_role_extra_prompt po)" || true
      ping_single_role_agent "@arch/@pm" "ขั้นตอนที่ 2: @arch & @pm ($arch_title)" "$ROLE_ARCH" "$MODEL_ARCH" "$arch_skills" "อ่าน PROJECT_STATE.md และ SPEC.md เพื่อออกแบบ ARCH.md และจัดทำ PLAN.md $(get_core_role_extra_prompt arch)" || true
      ping_single_role_agent "@dev" "ขั้นตอนที่ 3: @dev ($dev_title)" "$ROLE_DEV" "$MODEL_DEV" "$dev_skills" "เขียนโค้ดและชุดทดสอบภายใน Git Worktree ตามแผนที่กำหนด $(get_core_role_extra_prompt dev)" || true
      ping_single_role_agent "@qa/@sec" "ขั้นตอนที่ 4: @qa & @sec ($qa_title)" "$ROLE_QA" "$MODEL_QA" "$qa_skills" "รันชุดทดสอบจริง ตรวจสอบความปลอดภัย และสรุปลงใน QA_REPORT.md $(get_core_role_extra_prompt qa)" || true
      while IFS=$'\t' read -r ca_slug ca_title ca_prov ca_mod ca_wmode ca_skills ca_prompt; do
        [ -z "$ca_slug" ] && continue
        ping_single_role_agent "@${ca_slug}" "ตำแหน่ง @${ca_slug} (${ca_title})" "$ca_prov" "$ca_mod" "${ca_skills:-ไม่ระบุ}" "${ca_prompt:-ปฏิบัติงานตามบทบาทที่กำหนด}" || true
      done < <(list_custom_agents_tsv)
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
      ;;
    2)
      ping_single_role_agent "@po" "ขั้นตอนที่ 1: @po ($po_title)" "$ROLE_PO" "$MODEL_PO" "$po_skills" "ซักถามความต้องการและสรุปเป็นเอกสาร SPEC.md $(get_core_role_extra_prompt po)" || true
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
      ;;
    3)
      ping_single_role_agent "@arch/@pm" "ขั้นตอนที่ 2: @arch & @pm ($arch_title)" "$ROLE_ARCH" "$MODEL_ARCH" "$arch_skills" "อ่าน PROJECT_STATE.md และ SPEC.md เพื่อออกแบบ ARCH.md และจัดทำ PLAN.md $(get_core_role_extra_prompt arch)" || true
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
      ;;
    4)
      ping_single_role_agent "@dev" "ขั้นตอนที่ 3: @dev ($dev_title)" "$ROLE_DEV" "$MODEL_DEV" "$dev_skills" "เขียนโค้ดและชุดทดสอบภายใน Git Worktree ตามแผนที่กำหนด $(get_core_role_extra_prompt dev)" || true
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
      ;;
    5)
      ping_single_role_agent "@qa/@sec" "ขั้นตอนที่ 4: @qa & @sec ($qa_title)" "$ROLE_QA" "$MODEL_QA" "$qa_skills" "รันชุดทดสอบจริง ตรวจสอบความปลอดภัย และสรุปลงใน QA_REPORT.md $(get_core_role_extra_prompt qa)" || true
      read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
      ;;
    g|G) run_agents_manager_menu ;;
    c|C) configure_roles_menu ;;
  esac
}

# ─── 13. เรียกใช้งาน CLI ของแต่ละขั้นตอน & ระบบวัด Token จริงจาก Session Logs ───
# ดึงตัวเลข Token จริง (total|input|cached|output|turns) จากไฟล์ .jsonl ของแต่ละ CLI ที่อัปเดตในช่วง [start_epoch, end_epoch]
extract_step_token_usage() {
  local provider="$1"
  local start_ep="${2:-0}"
  local end_ep="${3:-0}"
  if [ -n "${RELAY_MOCK_TOKENS:-}" ]; then
    echo "$RELAY_MOCK_TOKENS"
    return 0
  fi
  command -v python3 >/dev/null 2>&1 || { echo "0|0|0|0|0"; return 0; }
  python3 - "$provider" "$start_ep" "$end_ep" <<'PYEOF' 2>/dev/null || echo "0|0|0|0|0"
import os, sys, glob, json, datetime

prov = sys.argv[1]
s_ep = float(sys.argv[2]) if sys.argv[2].isdigit() else 0.0
e_ep = float(sys.argv[3]) if sys.argv[3].isdigit() else s_ep

def parse_ep(ts):
    if not ts or not isinstance(ts, str):
        return None
    try:
        if ts.endswith("Z"):
            ts = ts[:-1] + "+00:00"
        return datetime.datetime.fromisoformat(ts).timestamp()
    except Exception:
        return None

tot_in = tot_ca = tot_out = tot_all = turns = 0

if prov == "agy":
    roots = []
    if os.environ.get("RELAY_AGY_BRAIN_DIR"):
        roots.append(os.environ["RELAY_AGY_BRAIN_DIR"])
    else:
        roots.append(os.path.expanduser("~/.gemini/antigravity-cli/brain"))
        roots.append(os.path.expanduser("~/.gemini/antigravity/brain"))
    seen = {}
    for root in roots:
        if not os.path.isdir(root):
            continue
        agy_files = set(
            glob.glob(os.path.join(root, "*", ".system_generated", "logs", "transcript.jsonl"))
            + glob.glob(os.path.join(root, "**", "transcript.jsonl"), recursive=True)
        )
        for f in agy_files:
            try:
                if os.path.getmtime(f) < s_ep - 5:
                    continue
                for line in open(f, encoding="utf-8", errors="ignore"):
                    if "PLANNER_RESPONSE" not in line:
                        continue
                    d = json.loads(line)
                    if d.get("type") != "PLANNER_RESPONSE":
                        continue
                    ep = parse_ep(d.get("created_at"))
                    if ep is not None and (s_ep - 2 <= ep <= e_ep + 5):
                        inp = int(d.get("input_tokens") or 0)
                        ca = int(d.get("cache_read_tokens") or 0)
                        out = int(d.get("output_tokens") or 0)
                        if inp or ca or out:
                            seen[(f, d.get("step_index"))] = (inp, ca, out)
            except Exception:
                continue
    tot_in = sum(x[0] + x[1] for x in seen.values())
    tot_ca = sum(x[1] for x in seen.values())
    tot_out = sum(x[2] for x in seen.values())
    tot_all = tot_in + tot_out
    turns = len(seen)

elif prov == "codex":
    c_root = os.environ.get("RELAY_CODEX_SESSIONS_DIR") or os.path.expanduser("~/.codex/sessions")
    if os.path.isdir(c_root):
        for f in glob.glob(os.path.join(c_root, "**", "*.jsonl"), recursive=True):
            try:
                if os.path.getmtime(f) < s_ep - 5:
                    continue
                base = None
                win = []
                for line in open(f, encoding="utf-8", errors="ignore"):
                    if "total_token_usage" not in line:
                        continue
                    d = json.loads(line)
                    p = d.get("payload") or {}
                    if p.get("type") != "token_count":
                        continue
                    tu = (p.get("info") or {}).get("total_token_usage")
                    if not isinstance(tu, dict):
                        continue
                    ep = parse_ep(d.get("timestamp"))
                    if ep is None:
                        continue
                    if ep < s_ep - 2:
                        base = tu
                    elif ep <= e_ep + 5:
                        win.append(tu)
                if win:
                    last = win[-1]
                    b = base or {}
                    di = max(0, int(last.get("input_tokens") or 0) - int(b.get("input_tokens") or 0))
                    dc = max(0, int(last.get("cached_input_tokens") or 0) - int(b.get("cached_input_tokens") or 0))
                    do = max(0, int(last.get("output_tokens") or 0) - int(b.get("output_tokens") or 0))
                    dt = max(0, int(last.get("total_tokens") or 0) - int(b.get("total_tokens") or 0))
                    tot_in += di
                    tot_ca += dc
                    tot_out += do
                    tot_all += dt if dt > 0 else (di + do)
                    b_tot = int(b.get("total_tokens") or 0)
                    turns += len({int(x.get("total_tokens") or 0) for x in win if int(x.get("total_tokens") or 0) > b_tot})
            except Exception:
                continue

elif prov == "claude":
    cl_root = os.environ.get("RELAY_CLAUDE_PROJECTS_DIR") or os.path.expanduser("~/.claude/projects")
    seen = {}
    if os.path.isdir(cl_root):
        for f in glob.glob(os.path.join(cl_root, "**", "*.jsonl"), recursive=True):
            try:
                if os.path.getmtime(f) < s_ep - 5:
                    continue
                for line in open(f, encoding="utf-8", errors="ignore"):
                    if "\"usage\"" not in line:
                        continue
                    d = json.loads(line)
                    m = d.get("message") or {}
                    u = m.get("usage")
                    if not isinstance(u, dict):
                        continue
                    ep = parse_ep(d.get("timestamp"))
                    if ep is not None and (s_ep - 2 <= ep <= e_ep + 5):
                        k = d.get("requestId") or m.get("id") or d.get("uuid")
                        if k:
                            seen[k] = u
            except Exception:
                continue
    for u in seen.values():
        fi = int(u.get("input_tokens") or 0) + int(u.get("cache_creation_input_tokens") or 0)
        ca = int(u.get("cache_read_input_tokens") or 0)
        out = int(u.get("output_tokens") or 0)
        tot_in += fi + ca
        tot_ca += ca
        tot_out += out
    tot_all = tot_in + tot_out
    turns = len(seen)

print(f"{tot_all}|{tot_in}|{tot_ca}|{tot_out}|{turns}")
PYEOF
}

# บันทึก 1 บรรทัดต่อการเรียก agent ลง .relay/tasks/<task>/RUN_LOG.jsonl (พร้อมข้อมูล Token จริง)
append_run_log() {
  local log_dir="$RELAY_DIR/tasks/$ACTIVE_TASK"
  [ -n "$ACTIVE_TASK" ] && [ -d "$log_dir" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$log_dir/RUN_LOG.jsonl" "$@" <<'PYEOF' 2>/dev/null || true
import json, sys, datetime
f = sys.argv[1]
mode, step, prov, model, rc, s, e, qb, qa = sys.argv[2:11]
tok_raw = sys.argv[11] if len(sys.argv) > 11 else "0|0|0|0|0"
def q(x):
    p = x.split("|")
    return {"5h": p[0] if p and p[0] else "-", "7d": p[1] if len(p) > 1 else "-"}
def t(x):
    p = (x.split("|") + ["0", "0", "0", "0", "0"])[:5]
    return {
        "total": int(p[0]) if p[0].isdigit() else 0,
        "input": int(p[1]) if p[1].isdigit() else 0,
        "cached": int(p[2]) if p[2].isdigit() else 0,
        "output": int(p[3]) if p[3].isdigit() else 0,
        "turns": int(p[4]) if p[4].isdigit() else 0,
    }
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
    "tokens": t(tok_raw),
}
with open(f, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
PYEOF
}

# แสดงกล่องสรุปเวลา + Token จริง + โควต้าหลังจบแต่ละขั้นตอนทันที
print_step_telemetry_box() {
  local step_label="$1"
  local prov="$2"
  local model="$3"
  local rc="$4"
  local s_ep="$5"
  local e_ep="$6"
  local qb="$7"
  local qa="$8"
  local tok_raw="${9:-0|0|0|0|0}"
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$step_label" "$prov" "$model" "$rc" "$s_ep" "$e_ep" "$qb" "$qa" "$tok_raw" \
    "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_MUTED" "$C_OK" "$C_WARN" <<'PYEOF' 2>/dev/null || true
import sys

step, prov, model, rc, s, e, qb, qa, tok_raw, ACC, RST, BOLD, MUTED, OK, WARN = sys.argv[1:16]
dur_s = max(0, int(e) - int(s))
m, sec = divmod(dur_s, 60)
h, m = divmod(m, 60)
dur_txt = f"{h}ชม.{m:02d}น.{sec:02d}วิ" if h else (f"{m}น.{sec:02d}วิ" if m else f"{sec}วิ")

tp = (tok_raw.split("|") + ["0", "0", "0", "0", "0"])[:5]
tot, inp, ca, out, turns = [int(x) if x.isdigit() else 0 for x in tp]

def q_diff(b_str, a_str):
    if b_str.isdigit() and a_str.isdigit():
        d = int(a_str) - int(b_str)
        return f"{b_str}% ➔ {a_str}% ({d:+d}%)"
    return f"{b_str}% ➔ {a_str}%"

qb5, qb7 = (qb.split("|") + ["-", "-"])[:2]
qa5, qa7 = (qa.split("|") + ["-", "-"])[:2]

if tot > 0:
    tok_txt = f"{OK}รวม {tot:,} tokens{RST} (Input: {inp:,} [Cache: {ca:,}] • Output: {out:,} • {turns} รอบ)"
else:
    tok_txt = f"{MUTED}ไม่พบการบันทึก Token ในรอบนี้ (0 tokens){RST}"

print("")
print(f"{ACC}╭────────────────────────────────────────────────────────────────────────{RST}")
print(f"{ACC}│{RST} 📊 {BOLD}ตัวชี้วัดการทำงานของขั้นตอนนี้ (Step Telemetry — วัดจากระบบจริง){RST}")
print(f"{ACC}│{RST}  • ขั้นตอน / โมเดล : {BOLD}{step}{RST} ({prov} / {model})")
print(f"{ACC}│{RST}  • เวลาที่ใช้จริง   : ⏱ {BOLD}{dur_txt}{RST} {MUTED}(exit {rc}){RST}")
print(f"{ACC}│{RST}  • Token ที่ใช้จริง  : 🪙 {tok_txt}")
print(f"{ACC}│{RST}  • โควต้าก่อน ➔ หลัง : 📉 5h: {q_diff(qb5, qa5)}  │  7d: {q_diff(qb7, qa7)}")
print(f"{ACC}╰────────────────────────────────────────────────────────────────────────{RST}")
PYEOF
}

# สรุปยอดรวมของใบงานปัจจุบันแบบ 1 บรรทัดสำหรับแสดงบนหน้า Dashboard หลัก
get_task_telemetry_summary_inline() {
  local task="${1:-$ACTIVE_TASK}"
  [ -n "$task" ] || return 0
  local f="$RELAY_DIR/tasks/$task/RUN_LOG.jsonl"
  [ -f "$f" ] && command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$f" "$C_BOLD" "$C_MUTED" "$C_OK" "$C_RESET" <<'PYEOF' 2>/dev/null || true
import json, sys

f, BOLD, MUTED, OK, RST = sys.argv[1:6]
dur = tot = inp = ca = out = steps = 0
for line in open(f, encoding="utf-8", errors="ignore"):
    try:
        r = json.loads(line)
    except Exception:
        continue
    steps += 1
    dur += int(r.get("duration_sec") or 0)
    t = r.get("tokens") or {}
    tot += int(t.get("total") or 0)
    inp += int(t.get("input") or 0)
    ca += int(t.get("cached") or 0)
    out += int(t.get("output") or 0)

if steps == 0:
    sys.exit(0)
m, s = divmod(dur, 60)
h, m = divmod(m, 60)
dur_s = f"{h}ชม.{m:02d}น." if h else (f"{m}น.{s:02d}วิ" if m else f"{s}วิ")
print(f"⏱ {BOLD}{dur_s}{RST} ({steps} ขั้น) • 🪙 {OK}{tot:,} tokens{RST} {MUTED}(In:{inp:,} [Cache:{ca:,}] • Out:{out:,}) • กด [v] ดูรายขั้น/โมเดล{RST}")
PYEOF
}

# รายงานตารางเปรียบเทียบรายขั้นตอนและรายโมเดล (ใช้ใน [v] relay stats และหน้า [5] Merge)
print_task_telemetry_report() {
  local target_task="${1:-$ACTIVE_TASK}"
  refresh_project_paths
  if [ -z "$target_task" ]; then
    get_active_task
    target_task="$ACTIVE_TASK"
  fi
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$RELAY_DIR" "$target_task" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_MUTED" "$C_OK" "$C_WARN" <<'PYEOF' 2>/dev/null || true
import os, sys, glob, json

relay_dir, active_task, ACC, RST, BOLD, MUTED, OK, WARN = sys.argv[1:9]

def fmt_dur(s):
    s = max(0, int(s))
    m, sec = divmod(s, 60)
    h, m = divmod(m, 60)
    return f"{h}ชม.{m:02d}น." if h else (f"{m}น.{sec:02d}วิ" if m else f"{sec}วิ")

def load_rows(path):
    rows = []
    if not os.path.isfile(path):
        return rows
    for line in open(path, encoding="utf-8", errors="ignore"):
        try:
            rows.append(json.loads(line))
        except Exception:
            continue
    return rows

task_log = os.path.join(relay_dir, "tasks", active_task, "RUN_LOG.jsonl") if active_task else ""
if not os.path.isfile(task_log) and active_task:
    task_log = os.path.join(relay_dir, "archive", active_task, "RUN_LOG.jsonl")

task_rows = load_rows(task_log) if task_log else []

all_logs = sorted(
    glob.glob(os.path.join(relay_dir, "tasks", "*", "RUN_LOG.jsonl"))
    + glob.glob(os.path.join(relay_dir, "archive", "*", "RUN_LOG.jsonl"))
)
all_rows = []
for lf in all_logs:
    tname = os.path.basename(os.path.dirname(lf))
    for r in load_rows(lf):
        r["_task"] = tname
        all_rows.append(r)

print("")
print(f"{ACC}╭────────────────────────────────────────────────────────────────────────{RST}")
print(f"{ACC}│{RST} 📊 {BOLD}รายงานตัวชี้วัดความเร็ว + Token + โควต้า (RELAY Telemetry & Cost Report){RST}")

if task_rows:
    print(f"{ACC}├────────────────────────────────────────────────────────────────────────{RST}")
    print(f"{ACC}│{RST} {BOLD}1. แยกตามขั้นตอนของใบงานปัจจุบัน: {active_task}{RST}")
    tot_dur = tot_tok = tot_in = tot_ca = tot_out = 0
    for idx, r in enumerate(task_rows, 1):
        d = int(r.get("duration_sec") or 0)
        t = r.get("tokens") or {}
        tk = int(t.get("total") or 0)
        ti = int(t.get("input") or 0)
        tc = int(t.get("cached") or 0)
        to = int(t.get("output") or 0)
        tot_dur += d
        tot_tok += tk
        tot_in += ti
        tot_ca += tc
        tot_out += to
        qb = (r.get("quota_before") or {}).get("5h", "-")
        qa = (r.get("quota_after") or {}).get("5h", "-")
        print(f"{ACC}│{RST}  {idx}. {BOLD}{r.get('step','-')}{RST} [{r.get('provider','-')}/{r.get('model','-')}]")
        print(f"{ACC}│{RST}     ⏱ {fmt_dur(d)} • 🪙 {OK}{tk:,} tokens{RST} {MUTED}(In:{ti:,} [Cache:{tc:,}] • Out:{to:,}) • 5h: {qb}%➔{qa}%{RST}")
    print(f"{ACC}│{RST}  {BOLD}Σ รวมใบงานนี้:{RST} ⏱ {BOLD}{fmt_dur(tot_dur)}{RST} ({len(task_rows)} ขั้น) • 🪙 {OK}{tot_tok:,} tokens{RST} (In:{tot_in:,} [Cache:{tot_ca:,}] • Out:{tot_out:,})")
else:
    print(f"{ACC}├────────────────────────────────────────────────────────────────────────{RST}")
    print(f"{ACC}│{RST} {MUTED}ยังไม่มีประวัติการรัน Agent ในใบงานปัจจุบัน ({active_task or 'ไม่มีใบงาน'}){RST}")

if all_rows:
    by_model = {}
    for r in all_rows:
        key = f"{r.get('provider','-')}/{r.get('model','-')}"
        bm = by_model.setdefault(key, {"runs": 0, "dur": 0, "tot": 0, "inp": 0, "ca": 0, "out": 0})
        bm["runs"] += 1
        bm["dur"] += int(r.get("duration_sec") or 0)
        t = r.get("tokens") or {}
        bm["tot"] += int(t.get("total") or 0)
        bm["inp"] += int(t.get("input") or 0)
        bm["ca"] += int(t.get("cached") or 0)
        bm["out"] += int(t.get("output") or 0)
    print(f"{ACC}├────────────────────────────────────────────────────────────────────────{RST}")
    print(f"{ACC}│{RST} {BOLD}2. สรุปเปรียบเทียบแยกตามค่ายและโมเดล (สะสมทุกใบงานในโปรเจกต์นี้){RST}")
    for mk, st in sorted(by_model.items(), key=lambda x: (-x[1]["tot"], -x[1]["dur"])):
        print(f"{ACC}│{RST}  • {BOLD}{mk}{RST} ({st['runs']} ครั้ง • ⏱ {fmt_dur(st['dur'])})")
        print(f"{ACC}│{RST}    🪙 รวม {OK}{st['tot']:,} tokens{RST} {MUTED}(In:{st['inp']:,} [Cache:{st['ca']:,}] • Out:{st['out']:,}){RST}")

print(f"{ACC}╰────────────────────────────────────────────────────────────────────────{RST}")
PYEOF
}

run_task_stats_view() {
  local mode="${1:-interactive}"
  refresh_project_paths
  get_active_task
  print_task_telemetry_report "$ACTIVE_TASK"
  if [ "$mode" != "--once" ] && [ -t 0 ]; then
    read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true
  fi
}

# สรุปเวลา Token และโควต้าที่ใช้ต่อขั้นของ Auto-Loop จาก RUN_LOG.jsonl
print_loop_run_summary() {
  local since="$1"
  local f="$RELAY_DIR/tasks/$ACTIVE_TASK/RUN_LOG.jsonl"
  [ -f "$f" ] && command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$f" "$since" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_MUTED" "$C_OK" <<'PYEOF' 2>/dev/null || true
import json, sys, datetime
f, since, ACC, RST, BOLD, MUTED, OK = sys.argv[1:8]
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
total_s = 0
total_tok = 0
for r in rows:
    total_s += r.get("duration_sec", 0)
    tk = int((r.get("tokens") or {}).get("total") or 0)
    total_tok += tk
    qb, qa = r.get("quota_before", {}), r.get("quota_after", {})
    print(f"{ACC}│{RST}  • {r['step']} — {r['provider']}/{r['model']} • ⏱ {dur(r.get('duration_sec', 0))} • 🪙 {tk:,} tok {MUTED}• 5h {qb.get('5h')}%→{qa.get('5h')}%{RST}")
print(f"{ACC}│{RST}  {MUTED}รวม {len(rows)} ขั้น • ใช้เวลาทั้งหมด {dur(total_s)} • รวม {OK}{total_tok:,} tokens{RST}")
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

  local run_start run_end q_before q_after tok_usage
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
  run_end="$(date +%s)"
  refresh_quota_cache --quiet
  q_after="$(get_role_quota_pair "$provider" "$configured_model")"
  tok_usage="$(extract_step_token_usage "$provider" "$run_start" "$run_end")"
  append_run_log "interactive" "$role_name" "$provider" "$configured_model" "0" "$run_start" "$run_end" "$q_before" "$q_after" "$tok_usage"
  print_step_telemetry_box "$role_name" "$provider" "$configured_model" "0" "$run_start" "$run_end" "$q_before" "$q_after" "$tok_usage"
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

# ตรวจหาไฟล์ความลับหรือฐานข้อมูลที่ห้ามบันทึกตามกฎความปลอดภัยข้อที่ 1 (.env*, *.key, *.pem, *.sqlite*, *.db)
# ครอบคลุมทั้งไฟล์ที่ยังไม่ commit ใน Worktree และไฟล์ที่ถูก commit ไปแล้วในกิ่งของงานนี้เทียบกับกิ่งหลัก
worktree_forbidden_files() {
  local wt="$1"
  local base_ref="${2:-}"
  local branch_ref="${3:-}"
  local candidates=""
  if [ -d "$wt" ]; then
    candidates="$(git -C "$wt" status --porcelain -- . ':(exclude).relay' 2>/dev/null | sed -E 's/^.. //' | sed -E 's/.* -> //' || true)"
  fi
  if [ -n "$base_ref" ] && [ -n "$branch_ref" ]; then
    local committed=""
    committed="$(git -C "$PROJECT_DIR" diff --name-only --diff-filter=ACMR "${base_ref}..${branch_ref}" -- . ':(exclude).relay' 2>/dev/null || true)"
    if [ -n "$committed" ]; then
      candidates="${candidates}"$'\n'"${committed}"
    fi
  fi
  [ -n "$candidates" ] || return 0
  local path base_name
  while IFS= read -r path; do
    path="${path#\"}"
    path="${path%\"}"
    [ -z "$path" ] && continue
    base_name="$(basename "$path")"
    case "$base_name" in
      .env.example|.env.sample|.env.template|.env.schema)
        continue
        ;;
      .env|.env.*|*.key|*.pem|*.sqlite|*.sqlite3|*.db)
        printf "%s\n" "$path"
        ;;
    esac
  done <<< "$candidates" | sort -u
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
    # ล้างทะเบียน Worktree ค้างที่โฟลเดอร์ถูกลบไปแล้ว เพื่อไม่ให้ติด error 'already checked out'
    git -C "$PROJECT_DIR" worktree prune >/dev/null 2>&1 || true
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

# สรุปสถานะไฟล์ที่ทำค้างไว้ใน Git Worktree ด้วยสคริปต์ระบบ (0 Token) เพื่อให้ Agent ตัวใหม่รับไม้ต่อได้ทันทีเมื่อสลับค่ายหรือทำต่อ
get_worktree_handoff_context_note() {
  local wt="${1:-}"
  [ -n "$wt" ] && [ -d "$wt" ] || return 0
  git -C "$wt" rev-parse --git-dir >/dev/null 2>&1 || return 0

  local dirty_files commits_ahead diff_summary
  dirty_files="$(git -C "$wt" status --short -- . ':(exclude).relay' 2>/dev/null | head -n 10 | awk '{printf "%s(%s) ", $2, $1}' | sed -E 's/[[:space:]]+$//' || true)"
  commits_ahead="$(git -C "$wt" log --oneline main..HEAD -- . ':(exclude).relay' 2>/dev/null | head -n 5 | tr '\n' ';' | sed -E 's/;+$//; s/;/, /g' || true)"
  diff_summary="$(git -C "$wt" diff --shortstat HEAD -- . ':(exclude).relay' 2>/dev/null | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' || true)"

  if [ -n "$dirty_files" ] || [ -n "$commits_ahead" ]; then
    printf " [บริบทรับไม้ต่อใน Worktree (0-Token Handoff): "
    if [ -n "$commits_ahead" ]; then
      printf "มี commit ก่อนหน้าในกิ่งนี้แล้ว (%s) " "$commits_ahead"
    fi
    if [ -n "$dirty_files" ]; then
      printf "มีไฟล์ที่แก้ไขค้างไว้ยังไม่ commit ได้แก่: %s%s " "$dirty_files" "${diff_summary:+ ($diff_summary)}"
    fi
    printf "กรุณาตรวจสอบไฟล์ดังกล่าวด้วย git status / git diff และทำต่อจากจุดที่ค้างไว้ทันทีโดยไม่ต้องเริ่มเขียนใหม่ตั้งแต่ต้น]"
  fi
}

ensure_or_create_task() {
  refresh_project_paths
  mkdir -p "$RELAY_DIR/tasks" "$RELAY_DIR/archive"
  get_active_task
  if [ -z "$ACTIVE_TASK" ]; then
    create_new_task || return 1
  fi
  return 0
}

create_new_task() {
  refresh_project_paths
  mkdir -p "$RELAY_DIR/tasks" "$RELAY_DIR/archive"
  local raw_input="${1:-}"
  if [ -z "$raw_input" ]; then
    echo ""
    read -r -p "ตั้งชื่อย่อของใบงานใหม่ (ภาษาอังกฤษ เช่น user-auth หรือพิมพ์ b เพื่อย้อนกลับ): " raw_input || true
    if is_back_input "$raw_input"; then
      return 1
    fi
  fi
  local slug
  slug="$(printf "%s" "${raw_input:-feature}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -E 's/^-+|-+$//g' | cut -c1-24 | sed -E 's/-+$//')"
  [ -z "$slug" ] && slug="task-$(( $(ls -1 "$RELAY_DIR/tasks" 2>/dev/null | wc -l) + 1 ))"
  local today
  today="$(date +%Y%m%d)"
  local candidate="${today}-${slug}"
  local suffix=2
  while [ -e "$RELAY_DIR/tasks/$candidate" ] || [ -e "$RELAY_DIR/archive/$candidate" ]; do
    candidate="${today}-${slug}-${suffix}"
    suffix=$((suffix + 1))
  done
  CURRENT_TASK="$candidate"
  mkdir -p "$RELAY_DIR/tasks/$CURRENT_TASK/screenshots"
  ACTIVE_TASK="$CURRENT_TASK"
  LAST_COMPLETED_PHASE=0
  printf "%s● สร้างใบงานใหม่เรียบร้อย: .relay/tasks/%s%s\n" "$C_OK" "$ACTIVE_TASK" "$C_RESET"
  return 0
}

run_phase_1_po() {
  require_all_roles_ready || return 0
  refresh_project_paths
  mkdir -p "$RELAY_DIR/tasks" "$RELAY_DIR/archive"
  get_active_task
  echo ""
  local user_goal=""
  read -r -p "อธิบายฟีเจอร์หรือความต้องการที่ต้องการให้ @po วิเคราะห์ (หรือพิมพ์ b เพื่อย้อนกลับ): " user_goal || true
  if is_back_input "$user_goal"; then
    return 0
  fi
  if [ -z "$ACTIVE_TASK" ]; then
    create_new_task "${user_goal:-feature}" || return 0
  fi
  check_role_quota_safe "$ROLE_PO" "$MODEL_PO" "ขั้นตอนที่ 1: @po" 20 "po" || return 0
  local role_note
  role_note="$(get_core_role_prompt_note po)"
  local prompt="@po ฉันต้องการพัฒนาฟีเจอร์สำหรับใบงาน .relay/tasks/$ACTIVE_TASK เกี่ยวกับ: ${user_goal:-ตามที่ฉันกำลังจะอธิบายต่อไปนี้}${role_note} กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md (ถ้ามี) หากข้อมูลชัดเจนเพียงพอแล้ว ให้สรุปขอบเขตงานและเกณฑ์ตรวจรับ (Acceptance Criteria) ลงในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md ได้ทันที (เน้น Bullet Point ความยาวไม่เกิน 40 บรรทัด) แต่หากมีประเด็นสำคัญที่ยังไม่ชัดเจน ให้ถามรวบยอดในครั้งเดียวสั้นๆ ไม่เกิน 3 ข้อก่อนเขียน SPEC.md (ห้ามแก้ไขโค้ดในขั้นตอนนี้)"
  launch_provider_cli "$ROLE_PO" "$MODEL_PO" "ขั้นตอนที่ 1: @po ($(get_core_role_title po))" "$PROJECT_DIR" "$prompt"
  LAST_COMPLETED_PHASE=1
}

run_phase_2_arch() {
  require_all_roles_ready || return 0
  ensure_or_create_task || return 0
  check_role_quota_safe "$ROLE_ARCH" "$MODEL_ARCH" "ขั้นตอนที่ 2: @arch & @pm" 20 "arch" || return 0
  local learned_note role_note
  learned_note="$(get_learned_skills_prompt_note)"
  role_note="$(get_core_role_prompt_note arch)"
  local prompt="@arch @pm กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md ร่วมกับไฟล์ความต้องการ .relay/tasks/$ACTIVE_TASK/SPEC.md${learned_note}${role_note} และตรวจสอบไฟล์กำหนดแพ็กเกจ/โครงสร้างจริงของโปรเจกต์ (เช่น package.json, pubspec.yaml) ก่อนวางแผน ห้ามสมมติชื่อไฟล์หรือเพิ่มไลบรารีซ้ำซ้อน แล้วเขียนแยก 2 ไฟล์โดยไม่คัดลอกเนื้อหาซ้ำกัน (รวมกันไม่เกิน 60 บรรทัด ห้ามเขียนเกริ่นนำเยิ่นเย้อ): 1. .relay/tasks/$ACTIVE_TASK/ARCH.md (ไม่เกิน 30 บรรทัด: ระบุเฉพาะโครงสร้างทางเทคนิคและรายชื่อไฟล์ที่ต้องสร้างหรือแก้ไข) 2. .relay/tasks/$ACTIVE_TASK/PLAN.md (ไม่เกิน 30 บรรทัด: ระบุเฉพาะลำดับขั้นการลงมือทำเป็นข้อๆ และคำสั่งรันทดสอบ)"
  launch_provider_cli "$ROLE_ARCH" "$MODEL_ARCH" "ขั้นตอนที่ 2: @arch & @pm ($(get_core_role_title arch))" "$PROJECT_DIR" "$prompt"
  LAST_COMPLETED_PHASE=2
}

run_phase_3_dev() {
  require_all_roles_ready || return 0
  ensure_or_create_task || return 0
  check_role_quota_safe "$ROLE_DEV" "$MODEL_DEV" "ขั้นตอนที่ 3: @dev" 20 "dev" || return 0
  if ! prepare_task_worktree; then
    [ -t 0 ] && { read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true; }
    return 0
  fi

  local learned_note commit_note role_note handoff_note
  learned_note="$(get_learned_skills_prompt_note)"
  commit_note="$(get_dev_commit_note)"
  role_note="$(get_core_role_prompt_note dev)"
  handoff_note="$(get_worktree_handoff_context_note "$TASK_WORK_DIR")"
  local prompt="@dev กรุณาอ่านเอกสาร .relay/tasks/$ACTIVE_TASK/SPEC.md ร่วมกับ ARCH.md และ PLAN.md (ถ้ามี) รวมถึง QA_REPORT.md หากเป็นการแก้ไขงาน${learned_note}${role_note}${handoff_note} แล้วดำเนินการพัฒนาโค้ดควบคู่กับชุดทดสอบ (เปิดอ่านเฉพาะไฟล์ทักษะ SKILL.md ที่จำเป็นต่องานนี้ เช่น flutter-best-practices สำหรับงาน Flutter หรือ vercel-react-best-practices สำหรับงานเว็บ) โดยก่อน git commit ต้องรันคำสั่งตรวจโครงสร้างโค้ด/Type (เช่น flutter analyze, tsc --noEmit, หรือ npm run lint) คู่กับคำสั่งรัน Unit Test ให้ผ่านจริงเสมอ${commit_note}"
  launch_provider_cli "$ROLE_DEV" "$MODEL_DEV" "ขั้นตอนที่ 3: @dev ($(get_core_role_title dev) ใน Git Worktree)" "$TASK_WORK_DIR" "$prompt"
  LAST_COMPLETED_PHASE=3
}

# โหมดด่วน Fast Track ([x] / /fast / relay fast): สำหรับงานเล็กหรือแก้บั๊ก ข้าม @po และ @arch ส่งตรงให้ @dev ใน Worktree ทันที
run_fast_track_dev() {
  require_all_roles_ready || return 0
  refresh_project_paths
  mkdir -p "$RELAY_DIR/tasks" "$RELAY_DIR/archive"
  get_active_task

  local fast_goal="${1:-}"
  if [ -z "$ACTIVE_TASK" ] || [ ! -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ]; then
    if [ -z "$fast_goal" ]; then
      echo ""
      read -r -p "⚡ [Fast Track] ระบุงานย่อยหรือบั๊กที่ต้องการให้ @dev แก้ไขทันที (หรือพิมพ์ b เพื่อย้อนกลับ): " fast_goal || true
      if is_back_input "$fast_goal"; then
        return 0
      fi
    fi
    if [ -z "$ACTIVE_TASK" ]; then
      create_new_task "${fast_goal:-fast-fix}" || return 0
    fi
    if [ ! -f "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md" ]; then
      local safe_goal="${fast_goal:-แก้ไขโค้ดและชุดทดสอบตามคำสั่งของผู้ใช้}"
      {
        printf "# ใบงานด่วน (Fast Track SPEC — %s)\n" "$ACTIVE_TASK"
        printf -- "- **โหมด:** Fast Track (ข้าม @po และ @arch เพื่อลด Ceremony Overhead สำหรับงานขนาดเล็ก)\n"
        printf -- "- **เป้าหมาย:** %s\n\n" "$safe_goal"
        printf "## เกณฑ์การตรวจรับงาน (Acceptance Criteria)\n"
        printf -- "- [ ] แก้ไขโค้ดตรงตามเป้าหมายและรันชุดทดสอบที่เกี่ยวข้องผ่าน\n"
        printf -- "- [ ] บันทึก git commit ลงในกิ่ง feat/%s เรียบร้อย\n" "$ACTIVE_TASK"
      } > "$RELAY_DIR/tasks/$ACTIVE_TASK/SPEC.md"
    fi
  fi

  check_role_quota_safe "$ROLE_DEV" "$MODEL_DEV" "โหมดด่วน Fast Track: @dev" 20 "dev" || return 0
  if ! prepare_task_worktree; then
    [ -t 0 ] && { read -r -p "กด Enter เพื่อกลับสู่หน้าจอหลัก..." _ || true; }
    return 0
  fi

  local learned_note commit_note role_note handoff_note
  learned_note="$(get_learned_skills_prompt_note)"
  commit_note="$(get_dev_commit_note)"
  role_note="$(get_core_role_prompt_note dev)"
  handoff_note="$(get_worktree_handoff_context_note "$TASK_WORK_DIR")"
  local prompt="@dev [โหมดด่วน Fast Track — ข้ามพิธีกรรมเอกสาร ARCH/PLAN] กรุณาอ่านโจทย์ในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md${learned_note}${role_note}${handoff_note} แล้วลงมือแก้ไขโค้ด รันชุดทดสอบที่เกี่ยวข้องให้ผ่าน และเขียนไฟล์ .relay/tasks/$ACTIVE_TASK/QA_VERDICT.json เป็น {\"verdict\":\"PASS\",\"failed_criteria\":[],\"tests_run\":[\"fast-track\"],\"summary\":\"Fast track completed\"} เมื่อทดสอบผ่านแล้ว${commit_note}"
  launch_provider_cli "$ROLE_DEV" "$MODEL_DEV" "โหมดด่วน Fast Track: @dev (ใน Git Worktree)" "$TASK_WORK_DIR" "$prompt"
  if [ -d "$TASK_WORK_DIR/.relay/tasks/$ACTIVE_TASK" ]; then
    sync_task_docs_from_worktree "$TASK_WORK_DIR/.relay/tasks/$ACTIVE_TASK" "$RELAY_DIR/tasks/$ACTIVE_TASK"
  fi
  LAST_COMPLETED_PHASE=4
}

run_phase_4_qa() {
  require_all_roles_ready || return 0
  ensure_or_create_task || return 0
  check_role_quota_safe "$ROLE_QA" "$MODEL_QA" "ขั้นตอนที่ 4: @qa & @sec" 20 "qa" || return 0
  local worktree_dir="$RELAY_DIR/worktrees/$ACTIVE_TASK"
  local target_work_dir="$PROJECT_DIR"
  [ -d "$worktree_dir" ] && target_work_dir="$worktree_dir"

  local learned_note role_note
  learned_note="$(get_learned_skills_prompt_note)"
  role_note="$(get_core_role_prompt_note qa)"
  local prompt="@qa @sec กรุณาตรวจสอบผลงานตามเกณฑ์ Acceptance Criteria ในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md${learned_note}${role_note} โดย: 1. รันชุดทดสอบจริงของโครงการผ่าน Terminal 2. ตรวจสอบ git diff ด้านความมั่นคงปลอดภัยและตรวจว่าไม่มีไฟล์ความลับหลุดรอด (เปิดอ่านทักษะเฉพาะทางเมื่อจำเป็นเท่านั้น) 3. เฉพาะกรณีที่ใบงานมีการแก้ไขหน้าเว็บ UI ตาม SPEC.md จึงใช้ Playwright MCP ทดสอบและบันทึกภาพหน้าจอไว้ที่ .relay/tasks/$ACTIVE_TASK/screenshots/ 4. สรุปผลการตรวจสอบแบบกระชับ (ไม่เกิน 30 บรรทัด) ลงในไฟล์ .relay/tasks/$ACTIVE_TASK/QA_REPORT.md โดยต้องมีบรรทัด 'VERDICT: PASS' หรือ 'VERDICT: FAIL' เพียงบรรทัดเดียว$(get_qa_prompt_contract)"
  launch_provider_cli "$ROLE_QA" "$MODEL_QA" "ขั้นตอนที่ 4: @qa & @sec ($(get_core_role_title qa))" "$target_work_dir" "$prompt"

  if [ -d "$worktree_dir/.relay/tasks/$ACTIVE_TASK" ]; then
    sync_task_docs_from_worktree "$worktree_dir/.relay/tasks/$ACTIVE_TASK" "$RELAY_DIR/tasks/$ACTIVE_TASK"
  fi
  LAST_COMPLETED_PHASE=4
}

# ─── 13.4 การจัดการบทบาท Agent, คำสั่ง Prompt และทักษะ ([g] / /agents / relay agents) ───
SELECTED_SKILLS=""
choose_skills_interactive() {
  local role_label="$1"
  local current_skills="$2"
  SELECTED_SKILLS="$current_skills"

  local avail=()
  local sname
  while IFS= read -r sname; do
    [ -n "$sname" ] && avail+=("$sname")
  done < <(list_available_skill_names)

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %sเลือกชุดทักษะ (Skills) สำหรับ %s%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$role_label" "$C_RESET"
  printf "%s│%s  • ทักษะที่ใช้อยู่ปัจจุบัน: %s%s%s\n" "$C_ACCENT" "$C_RESET" "$C_OK" "${current_skills:-ไม่มี}" "$C_RESET"
  if [ "${#avail[@]}" -gt 0 ]; then
    printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
    printf "%s│%s  %sรายการทักษะที่ติดตั้งในเครื่อง (%d รายการ):%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "${#avail[@]}" "$C_RESET"
    local i=0
    while [ "$i" -lt "${#avail[@]}" ]; do
      local sk="${avail[$i]}"
      local mark="[ ]"
      case " $current_skills " in
        *" $sk "*) mark="${C_OK}[✓]${C_RESET}" ;;
      esac
      printf "%s│%s   %2d. %b %s\n" "$C_ACCENT" "$C_RESET" "$((i + 1))" "$mark" "$sk"
      i=$((i + 1))
    done
  fi
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  interactive_menu "เลือกวิธีระบุทักษะ (Skills) สำหรับ ${role_label}" 0 \
    "1|เลือกจากหมายเลขทักษะด้านบน (เช่น 1,3,5) หรือพิมพ์ชื่อทักษะคั่นด้วยเว้นวรรค" \
    "2|เพิ่มทักษะต่อท้ายจากรายการเดิม (${current_skills:-ไม่มี})" \
    "b|ย้อนกลับ (คงทักษะเดิม)"

  case "$MENU_RESULT" in
    1)
      local raw_sel=""
      read -r -p "ระบุหมายเลขทักษะ (เช่น 1,3) หรือชื่อทักษะ (หรือพิมพ์ b เพื่อย้อนกลับ): " raw_sel || true
      if is_back_input "$raw_sel" || [ -z "$raw_sel" ]; then
        return 1
      fi
      SELECTED_SKILLS="$(python3 - "$raw_sel" "${avail[@]}" <<'PYEOF'
import re, sys
raw = sys.argv[1].strip()
avail = sys.argv[2:]
tokens = [t for t in re.split(r"[\s,]+", raw) if t]
out = []
for t in tokens:
    if t.isdigit() and 1 <= int(t) <= len(avail):
        sk = avail[int(t) - 1]
    else:
        sk = t
    if sk and sk not in out:
        out.append(sk)
print(" ".join(out))
PYEOF
)"
      return 0
      ;;
    2)
      local raw_add=""
      read -r -p "ระบุหมายเลขหรือชื่อทักษะที่ต้องการเพิ่ม (หรือพิมพ์ b เพื่อย้อนกลับ): " raw_add || true
      if is_back_input "$raw_add" || [ -z "$raw_add" ]; then
        return 1
      fi
      SELECTED_SKILLS="$(python3 - "$current_skills" "$raw_add" "${avail[@]}" <<'PYEOF'
import re, sys
cur = sys.argv[1].split()
raw = sys.argv[2].strip()
avail = sys.argv[3:]
out = list(cur)
for t in [x for x in re.split(r"[\s,]+", raw) if x]:
    sk = avail[int(t) - 1] if (t.isdigit() and 1 <= int(t) <= len(avail)) else t
    if sk and sk not in out:
        out.append(sk)
print(" ".join(out))
PYEOF
)"
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

edit_core_role_menu() {
  local role_key="$1"
  local target_agents_conf="$2"
  local target_roles_conf="$3"
  local role_code="@${role_key}"
  [ "$role_key" = "arch" ] && role_code="@arch/@pm"
  [ "$role_key" = "qa" ] && role_code="@qa/@sec"

  while true; do
    load_role_config
    local cur_prov cur_mod cur_title cur_skills cur_prompt
    case "$role_key" in
      po)   cur_prov="$ROLE_PO";   cur_mod="$MODEL_PO" ;;
      arch) cur_prov="$ROLE_ARCH"; cur_mod="$MODEL_ARCH" ;;
      dev)  cur_prov="$ROLE_DEV";  cur_mod="$MODEL_DEV" ;;
      qa)   cur_prov="$ROLE_QA";   cur_mod="$MODEL_QA" ;;
    esac
    cur_title="$(get_core_role_title "$role_key")"
    cur_skills="$(get_core_role_skills "$role_key")"
    cur_prompt="$(get_core_role_extra_prompt "$role_key")"

    echo ""
    printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
    printf "%s│%s %sตั้งค่าบทบาทหลัก: %s (%s)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$role_code" "$cur_title" "$C_RESET"
    printf "%s│%s  • ค่าย AI / โมเดล : %s (%s)\n" "$C_ACCENT" "$C_RESET" "$cur_prov" "$cur_mod"
    printf "%s│%s  • ทักษะ (Skills)  : %s\n" "$C_ACCENT" "$C_RESET" "${cur_skills:-ไม่มี}"
    printf "%s│%s  • คำสั่ง Prompt เพิ่ม: %s\n" "$C_ACCENT" "$C_RESET" "${cur_prompt:-(ใช้ค่ามาตรฐานของระบบ)}"
    printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

    interactive_menu "เลือกรายการที่ต้องการแก้ไขสำหรับ ${role_code}" 0 \
      "1|เปลี่ยนค่าย AI และเลือก Model (${cur_prov} / ${cur_mod})" \
      "2|กำหนดคำสั่ง Prompt บทบาทหน้าที่เพิ่มเติม (Custom Role Prompt)" \
      "3|เลือกหรือแก้ไขชุดทักษะ (Skills) ประจำตำแหน่ง" \
      "4|แก้ไขชื่อแสดงผลของตำแหน่ง (${cur_title})" \
      "r|รีเซ็ตชื่อ Prompt และทักษะกลับเป็นค่ามาตรฐาน" \
      "b|ย้อนกลับ"

    case "$MENU_RESULT" in
      1)
        if choose_provider_interactive "${role_code} (${cur_title})" "$cur_prov"; then
          local next_p="$SELECTED_PROVIDER"
          if choose_model_interactive "$next_p" "${role_code} (${cur_title})" "$cur_mod"; then
            case "$role_key" in
              po)   ROLE_PO="$next_p";   MODEL_PO="$SELECTED_MODEL" ;;
              arch) ROLE_ARCH="$next_p"; MODEL_ARCH="$SELECTED_MODEL" ;;
              dev)  ROLE_DEV="$next_p";  MODEL_DEV="$SELECTED_MODEL" ;;
              qa)   ROLE_QA="$next_p";   MODEL_QA="$SELECTED_MODEL" ;;
            esac
            save_role_config "$target_roles_conf"
          fi
        fi
        ;;
      2)
        echo ""
        local new_p=""
        read -r -p "ระบุคำสั่ง Prompt เพิ่มเติมสำหรับ ${role_code} (หรือพิมพ์ b เพื่อย้อนกลับ): " new_p || true
        if ! is_back_input "$new_p"; then
          set_core_role_override "$target_agents_conf" "$role_key" "prompt" "$new_p"
          printf "%s● บันทึกคำสั่ง Prompt ของ %s เรียบร้อยแล้ว%s\n" "$C_OK" "$role_code" "$C_RESET"
        fi
        ;;
      3)
        if choose_skills_interactive "${role_code} (${cur_title})" "$cur_skills"; then
          set_core_role_override "$target_agents_conf" "$role_key" "skills" "$SELECTED_SKILLS"
          printf "%s● บันทึกชุดทักษะของ %s เรียบร้อยแล้ว%s\n" "$C_OK" "$role_code" "$C_RESET"
        fi
        ;;
      4)
        echo ""
        local new_t=""
        read -r -p "ระบุชื่อแสดงผลของตำแหน่ง ${role_code} (หรือพิมพ์ b เพื่อย้อนกลับ): " new_t || true
        if ! is_back_input "$new_t" && [ -n "$new_t" ]; then
          set_core_role_override "$target_agents_conf" "$role_key" "title" "$new_t"
          printf "%s● บันทึกชื่อตำแหน่ง %s เรียบร้อยแล้ว%s\n" "$C_OK" "$role_code" "$C_RESET"
        fi
        ;;
      r|R)
        set_core_role_override "$target_agents_conf" "$role_key" "reset" ""
        printf "%s● รีเซ็ต %s กลับเป็นค่ามาตรฐานเรียบร้อยแล้ว%s\n" "$C_OK" "$role_code" "$C_RESET"
        ;;
      *)
        return 0
        ;;
    esac
  done
}

run_custom_agent_task() {
  local slug="${1:-}"
  local user_instruction="${2:-}"
  slug="${slug#@}"
  [ -z "$slug" ] && return 1

  local title prov model wmode skills role_prompt
  title="$(get_custom_agent_field "$slug" "title")"
  prov="$(get_custom_agent_field "$slug" "provider")"
  model="$(get_custom_agent_field "$slug" "model")"
  wmode="$(get_custom_agent_field "$slug" "work_mode")"
  skills="$(get_custom_agent_field "$slug" "skills")"
  role_prompt="$(get_custom_agent_field "$slug" "prompt")"

  if [ -z "$prov" ] || [ -z "$model" ]; then
    printf "%s✖ ไม่พบการตั้งค่าของตำแหน่ง @%s%s\n" "$C_ERR" "$slug" "$C_RESET"
    return 1
  fi

  refresh_project_paths
  mkdir -p "$RELAY_DIR/tasks" "$RELAY_DIR/archive"
  get_active_task

  if [ -z "$user_instruction" ]; then
    echo ""
    read -r -p "ระบุงานที่ต้องการสั่งให้ @${slug} (${title}) ดำเนินการ (หรือพิมพ์ b เพื่อย้อนกลับ): " user_instruction || true
    if is_back_input "$user_instruction"; then
      return 0
    fi
  fi

  if [ -z "$ACTIVE_TASK" ]; then
    create_new_task "${user_instruction:-$slug}" || return 0
  fi

  local target_dir="$PROJECT_DIR"
  local commit_note=""
  local handoff_note=""
  if [ "$wmode" = "worktree" ]; then
    if ! prepare_task_worktree; then
      return 1
    fi
    target_dir="$TASK_WORK_DIR"
    commit_note="$(get_dev_commit_note)"
    handoff_note="$(get_worktree_handoff_context_note "$target_dir")"
  fi

  local learned_note skills_note=""
  learned_note="$(get_learned_skills_prompt_note)"
  [ -n "$skills" ] && skills_note=" โดยใช้ชุดทักษะ (Skills): ${skills}"

  local full_prompt="@${slug} (${title}) บทบาทหน้าที่ของคุณคือ: ${role_prompt:-ปฏิบัติงานตามความเชี่ยวชาญของตำแหน่ง}${skills_note}${learned_note}${handoff_note} กรุณาอ่านบริบทใน .relay/PROJECT_STATE.md (ถ้ามี) และใบงาน .relay/tasks/$ACTIVE_TASK แล้วดำเนินการตามคำสั่งนี้ให้กระชับตรงประเด็น (ห้ามเขียนเอกสารเยิ่นเย้อเกินจำเป็น): ${user_instruction:-ตามที่กำหนดในบทบาท}${commit_note}"
  launch_provider_cli "$prov" "$model" "ตำแหน่ง @${slug} (${title})" "$target_dir" "$full_prompt"

  if [ "$wmode" = "worktree" ] && [ -d "$target_dir/.relay/tasks/$ACTIVE_TASK" ]; then
    sync_task_docs_from_worktree "$target_dir/.relay/tasks/$ACTIVE_TASK" "$RELAY_DIR/tasks/$ACTIVE_TASK"
  fi
  return 0
}

add_custom_agent_wizard() {
  local target_conf="$1"
  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s %sเพิ่มตำแหน่ง Agent ใหม่ (พิมพ์ b ในขั้นตอนใดก็ได้เพื่อย้อนกลับ)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  local raw_slug=""
  read -r -p "1. รหัสตำแหน่งภาษาอังกฤษ (เช่น ux, devops, data, sec-audit หรือพิมพ์ b เพื่อย้อนกลับ): " raw_slug || true
  if is_back_input "$raw_slug" || [ -z "$raw_slug" ]; then
    return 0
  fi
  local slug
  slug="$(printf "%s" "${raw_slug#@}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_-' '-' | sed -E 's/^-+|-+$//g')"
  if [ -z "$slug" ]; then
    return 0
  fi

  local title=""
  read -r -p "2. ชื่อบทบาท (เช่น UX/UI Designer หรือ DevOps Engineer • พิมพ์ b เพื่อย้อนกลับ): " title || true
  if is_back_input "$title"; then
    return 0
  fi
  [ -z "$title" ] && title="$slug"

  local role_prompt=""
  read -r -p "3. คำสั่ง Prompt บทบาทหน้าที่หลักของ @${slug} (พิมพ์ b เพื่อย้อนกลับ): " role_prompt || true
  if is_back_input "$role_prompt"; then
    return 0
  fi
  [ -z "$role_prompt" ] && role_prompt="วิเคราะห์และปฏิบัติงานในฐานะ ${title} อย่างรอบคอบ"

  local skills=""
  if choose_skills_interactive "@${slug} (${title})" ""; then
    skills="$SELECTED_SKILLS"
  fi

  interactive_menu "5. เลือกโหมดโฟลเดอร์ทำงานสำหรับ @${slug} (${title})" 0 \
    "1|Project Root — ทำงานในโฟลเดอร์หลักของโปรเจกต์ (เหมาะสำหรับงานวิเคราะห์ / ออกแบบ / เอกสาร)" \
    "2|Git Worktree — แยกกิ่งโค้ดอิสระอัตโนมัติ (เหมาะสำหรับงานแก้ไขโค้ด)" \
    "b|ย้อนกลับ (ยกเลิกการสร้าง)"
  local wmode="project"
  case "$MENU_RESULT" in
    1) wmode="project" ;;
    2) wmode="worktree" ;;
    *) return 0 ;;
  esac

  if ! choose_provider_interactive "@${slug} (${title})" "agy"; then
    return 0
  fi
  local prov="$SELECTED_PROVIDER"

  if ! choose_model_interactive "$prov" "@${slug} (${title})" "$(get_cli_default_model "$prov")"; then
    return 0
  fi
  local mod="$SELECTED_MODEL"

  upsert_custom_agent "$target_conf" "$slug" "$title" "$prov" "$mod" "$wmode" "$skills" "$role_prompt"
  printf "\n%s● เพิ่มตำแหน่ง @%s (%s ➔ %s / %s) เรียบร้อยแล้ว%s\n" "$C_OK" "$slug" "$title" "$prov" "$mod" "$C_RESET"
}

manage_single_custom_agent_menu() {
  local slug="$1"
  local target_conf="$2"

  while true; do
    local title prov mod wmode skills role_prompt
    title="$(get_custom_agent_field "$slug" "title" "$target_conf")"
    prov="$(get_custom_agent_field "$slug" "provider" "$target_conf")"
    mod="$(get_custom_agent_field "$slug" "model" "$target_conf")"
    wmode="$(get_custom_agent_field "$slug" "work_mode" "$target_conf")"
    skills="$(get_custom_agent_field "$slug" "skills" "$target_conf")"
    role_prompt="$(get_custom_agent_field "$slug" "prompt" "$target_conf")"
    [ -z "$prov" ] && return 0

    echo ""
    printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
    printf "%s│%s %sข้อมูลตำแหน่ง: @%s (%s)%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$slug" "$title" "$C_RESET"
    printf "%s│%s  • ค่าย AI / โมเดล : %s (%s) • โหมดทำงาน: %s\n" "$C_ACCENT" "$C_RESET" "$prov" "$mod" "$wmode"
    printf "%s│%s  • ทักษะ (Skills)  : %s\n" "$C_ACCENT" "$C_RESET" "${skills:-ไม่ระบุ}"
    printf "%s│%s  • คำสั่ง Prompt   : %s\n" "$C_ACCENT" "$C_RESET" "${role_prompt:-ไม่ระบุ}"
    printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

    interactive_menu "เลือกการดำเนินการสำหรับตำแหน่ง @${slug} (${title})" 0 \
      "1|★ สั่งงาน Agent ตำแหน่ง @${slug} ทันที" \
      "2|ทดสอบความพร้อมและให้ @${slug} รายงานตัว (/test)" \
      "3|เปลี่ยนค่าย AI และเลือก Model (${prov} / ${mod})" \
      "4|แก้ไขคำสั่ง Prompt บทบาทหน้าที่" \
      "5|เลือกหรือแก้ไขชุดทักษะ (Skills)" \
      "6|สลับโหมดโฟลเดอร์ทำงาน (ปัจจุบัน: ${wmode})" \
      "7|แก้ไขชื่อบทบาท (${title})" \
      "d|ลบตำแหน่ง @${slug}" \
      "b|ย้อนกลับ"

    case "$MENU_RESULT" in
      1)
        run_custom_agent_task "$slug"
        ;;
      2)
        ping_single_role_agent "@${slug}" "ตำแหน่ง @${slug} (${title})" "$prov" "$mod" "${skills:-ไม่ระบุ}" "${role_prompt:-ปฏิบัติงานตามบทบาท}" || true
        [ -t 0 ] && { read -r -p "กด Enter เพื่อย้อนกลับ..." _ || true; }
        ;;
      3)
        if choose_provider_interactive "@${slug} (${title})" "$prov"; then
          local next_p="$SELECTED_PROVIDER"
          if choose_model_interactive "$next_p" "@${slug} (${title})" "$mod"; then
            upsert_custom_agent "$target_conf" "$slug" "$title" "$next_p" "$SELECTED_MODEL" "$wmode" "$skills" "$role_prompt"
          fi
        fi
        ;;
      4)
        local new_p=""
        read -r -p "ระบุคำสั่ง Prompt บทบาทหน้าที่ของ @${slug} (หรือพิมพ์ b เพื่อย้อนกลับ): " new_p || true
        if ! is_back_input "$new_p" && [ -n "$new_p" ]; then
          upsert_custom_agent "$target_conf" "$slug" "$title" "$prov" "$mod" "$wmode" "$skills" "$new_p"
        fi
        ;;
      5)
        if choose_skills_interactive "@${slug} (${title})" "$skills"; then
          upsert_custom_agent "$target_conf" "$slug" "$title" "$prov" "$mod" "$wmode" "$SELECTED_SKILLS" "$role_prompt"
        fi
        ;;
      6)
        local next_w="worktree"
        [ "$wmode" = "worktree" ] && next_w="project"
        upsert_custom_agent "$target_conf" "$slug" "$title" "$prov" "$mod" "$next_w" "$skills" "$role_prompt"
        ;;
      7)
        local new_t=""
        read -r -p "ระบุชื่อบทบาทใหม่ของ @${slug} (หรือพิมพ์ b เพื่อย้อนกลับ): " new_t || true
        if ! is_back_input "$new_t" && [ -n "$new_t" ]; then
          upsert_custom_agent "$target_conf" "$slug" "$new_t" "$prov" "$mod" "$wmode" "$skills" "$role_prompt"
        fi
        ;;
      d|D)
        delete_custom_agent "$target_conf" "$slug"
        printf "%s● ลบตำแหน่ง @%s เรียบร้อยแล้ว%s\n" "$C_OK" "$slug" "$C_RESET"
        return 0
        ;;
      *)
        return 0
        ;;
    esac
  done
}

run_agents_manager_menu() {
  local sub="${1:-interactive}"
  refresh_project_paths
  load_role_config

  local target_conf="$GLOBAL_AGENTS_CONF"
  local scope_label="Global (~/.agents/custom-agents.json)"
  if [ -f "$PROJECT_AGENTS_CONF" ]; then
    target_conf="$PROJECT_AGENTS_CONF"
    scope_label="Project (.relay/custom-agents.json)"
  fi

  local target_roles_conf="$GLOBAL_ROLES_CONF"
  [ -f "$PROJECT_ROLES_CONF" ] && target_roles_conf="$PROJECT_ROLES_CONF"

  # รองรับการเรียกใช้งานผ่าน CLI Subcommand โดยตรง
  case "$sub" in
    list)
      list_custom_agents_tsv "$target_conf"
      return 0
      ;;
    add)
      shift
      upsert_custom_agent "$target_conf" "${1:-}" "${2:-}" "${3:-agy}" "${4:-$(get_cli_default_model "${3:-agy}")}" "${5:-project}" "${6:-}" "${7:-}"
      return 0
      ;;
    remove|delete|rm)
      shift
      delete_custom_agent "$target_conf" "${1:-}"
      return 0
      ;;
    run)
      shift
      run_custom_agent_task "${1:-}" "${2:-}"
      return 0
      ;;
  esac

  while true; do
    load_role_config
    echo ""
    printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
    printf "%s│%s %sการจัดการบทบาท Agent, คำสั่ง Prompt และทักษะประจำตำแหน่ง%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
    printf "%s│%s  • ขอบเขตการบันทึกปัจจุบัน : %s%s%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$scope_label" "$C_RESET"
    printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
    printf "%s│%s  %sตำแหน่งมาตรฐาน 4 ขั้นตอน:%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
    printf "%s│%s   • @po       (%s) ➔ %s/%s │ ทักษะ: %s\n" "$C_ACCENT" "$C_RESET" "$(get_core_role_title po)" "$ROLE_PO" "$MODEL_PO" "$(get_core_role_skills po)"
    printf "%s│%s   • @arch/@pm (%s) ➔ %s/%s │ ทักษะ: %s\n" "$C_ACCENT" "$C_RESET" "$(get_core_role_title arch)" "$ROLE_ARCH" "$MODEL_ARCH" "$(get_core_role_skills arch)"
    printf "%s│%s   • @dev      (%s) ➔ %s/%s │ ทักษะ: %s\n" "$C_ACCENT" "$C_RESET" "$(get_core_role_title dev)" "$ROLE_DEV" "$MODEL_DEV" "$(get_core_role_skills dev)"
    printf "%s│%s   • @qa/@sec  (%s) ➔ %s/%s │ ทักษะ: %s\n" "$C_ACCENT" "$C_RESET" "$(get_core_role_title qa)" "$ROLE_QA" "$MODEL_QA" "$(get_core_role_skills qa)"

    local menu_items=()
    local custom_slugs=()
    local c_idx=1
    local ca_slug ca_title ca_prov ca_mod ca_wmode ca_skills ca_prompt
    while IFS=$'\t' read -r ca_slug ca_title ca_prov ca_mod ca_wmode ca_skills ca_prompt; do
      [ -z "$ca_slug" ] && continue
      if [ "$c_idx" -eq 1 ]; then
        printf "%s├────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"
        printf "%s│%s  %sตำแหน่ง Agent ที่เพิ่มใหม่:%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
      fi
      printf "%s│%s   • @%-10s (%s) ➔ %s/%s [%s] │ ทักษะ: %s\n" "$C_ACCENT" "$C_RESET" "$ca_slug" "$ca_title" "$ca_prov" "$ca_mod" "$ca_wmode" "${ca_skills:-ไม่ระบุ}"
      menu_items+=("${c_idx}|สั่งงานหรือแก้ไขตำแหน่ง @${ca_slug} (${ca_title} ➔ ${ca_prov}/${ca_mod})")
      custom_slugs[$c_idx]="$ca_slug"
      c_idx=$((c_idx + 1))
    done < <(list_custom_agents_tsv "$target_conf")
    printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

    menu_items+=("a|★ เพิ่มตำแหน่ง Agent ใหม่ (กำหนดรหัส @slug, Prompt บทบาท, ทักษะ Skills และเลือก Model)")
    menu_items+=("p|ปรับแต่งตำแหน่งที่ 1: @po (Prompt / ทักษะ Skills / ค่าย & Model)")
    menu_items+=("h|ปรับแต่งตำแหน่งที่ 2: @arch & @pm (Prompt / ทักษะ Skills / ค่าย & Model)")
    menu_items+=("v|ปรับแต่งตำแหน่งที่ 3: @dev (Prompt / ทักษะ Skills / ค่าย & Model)")
    menu_items+=("q|ปรับแต่งตำแหน่งที่ 4: @qa & @sec (Prompt / ทักษะ Skills / ค่าย & Model)")
    menu_items+=("s|สลับขอบเขตไฟล์บันทึก (Global ~/.agents/ ↔ Project .relay/custom-agents.json)")
    menu_items+=("b|ย้อนกลับสู่หน้าจอหลัก")

    interactive_menu "เลือกตำแหน่ง Agent ที่ต้องการสั่งงาน ปรับแต่ง หรือเพิ่มตำแหน่งใหม่" 0 "${menu_items[@]}"

    case "$MENU_RESULT" in
      [1-9])
        if [ -n "${custom_slugs[$MENU_RESULT]:-}" ]; then
          manage_single_custom_agent_menu "${custom_slugs[$MENU_RESULT]}" "$target_conf"
        fi
        ;;
      a|A)
        add_custom_agent_wizard "$target_conf"
        ;;
      p|P)
        edit_core_role_menu "po" "$target_conf" "$target_roles_conf"
        ;;
      h|H)
        edit_core_role_menu "arch" "$target_conf" "$target_roles_conf"
        ;;
      v|V)
        edit_core_role_menu "dev" "$target_conf" "$target_roles_conf"
        ;;
      q|Q)
        edit_core_role_menu "qa" "$target_conf" "$target_roles_conf"
        ;;
      s|S)
        if [ "$target_conf" = "$GLOBAL_AGENTS_CONF" ]; then
          mkdir -p "$RELAY_DIR"
          [ -f "$GLOBAL_AGENTS_CONF" ] && [ ! -f "$PROJECT_AGENTS_CONF" ] && cp "$GLOBAL_AGENTS_CONF" "$PROJECT_AGENTS_CONF" 2>/dev/null || true
          [ ! -f "$PROJECT_AGENTS_CONF" ] && echo '{"overrides":{},"agents":[]}' > "$PROJECT_AGENTS_CONF"
          target_conf="$PROJECT_AGENTS_CONF"
          scope_label="Project (.relay/custom-agents.json)"
        else
          target_conf="$GLOBAL_AGENTS_CONF"
          scope_label="Global (~/.agents/custom-agents.json)"
        fi
        printf "%s● สลับขอบเขตการบันทึกเป็น %s เรียบร้อยแล้ว%s\n" "$C_OK" "$scope_label" "$C_RESET"
        ;;
      *)
        return 0
        ;;
    esac
  done
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

# 1. สกัดบทเรียนจากหลักฐานการแก้บั๊กจริง (Evidence-Based Remediation: รอบก่อนหน้า FAIL แล้วแก้จน PASS)
import glob, json
before_verdicts = sorted(glob.glob(os.path.join(task_dir, "QA_VERDICT.before-round-*.json")))
final_verdict_path = os.path.join(task_dir, "QA_VERDICT.json")
if before_verdicts and os.path.isfile(final_verdict_path):
    try:
        final_v = json.load(open(final_verdict_path, encoding="utf-8"))
        if str(final_v.get("verdict", "")).strip().upper() == "PASS":
            fix_summary = re.sub(r"\s+", " ", str(final_v.get("summary", "")).strip())
            for bv_path in before_verdicts:
                bv = json.load(open(bv_path, encoding="utf-8"))
                failed_list = bv.get("failed_criteria") or []
                for fc in failed_list[:2]:
                    fc_clean = re.sub(r"\s+", " ", str(fc).strip())
                    if fc_clean:
                        remed_rule = f"[บทเรียนแก้บั๊กจาก {task_id}] ต้องป้องกันปัญหา '{fc_clean}' (วิธีแก้ไขที่ผ่าน QA: {fix_summary or 'ตรวจและรันชุดทดสอบให้ครบก่อนส่งมอบ'})"
                        candidates.append(remed_rule[:220])
    except Exception:
        pass

# 2. สกัดกฎเชิงสถาปัตยกรรมและข้อควรระวังจาก QA_REPORT.md, ARCH.md, SPEC.md
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
tmp_pending = f"{pending_file}.tmp.{os.getpid()}"
with open(tmp_pending, "w", encoding="utf-8") as f:
    f.write("# กฎที่รออนุมัติ (RELAY Self-Learning — ยังไม่ถูกส่งให้ AI)\n\n")
    f.write("> กด [l] ในหน้าจอ relay เพื่ออนุมัติหรือปฏิเสธ — เฉพาะกฎที่อนุมัติแล้วจะย้ายไปที่ SKILL.md\n\n")
    for p in pending:
        f.write(f"- {p}\n")
os.replace(tmp_pending, pending_file)

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
    tmp_skill = f"{skill_file}.tmp.{os.getpid()}"
    with open(tmp_skill, "w", encoding="utf-8") as f:
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
    os.replace(tmp_skill, skill_file)

tmp_pending = f"{pending_file}.tmp.{os.getpid()}"
with open(tmp_pending, "w", encoding="utf-8") as f:
    f.write("# กฎที่รออนุมัติ (RELAY Self-Learning — ยังไม่ถูกส่งให้ AI)\n\n")
    f.write("> กด [l] ในหน้าจอ relay เพื่ออนุมัติหรือปฏิเสธ — เฉพาะกฎที่อนุมัติแล้วจะย้ายไปที่ SKILL.md\n\n")
os.replace(tmp_pending, pending_file)

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
  read -r -p "พิมพ์หมายเลขที่อนุมัติ (เช่น 1,3) • a = อนุมัติทั้งหมด • x = ปฏิเสธทั้งหมด • b หรือ Enter = ย้อนกลับ: " sel || true
  if [ -z "$sel" ] || is_back_input "$sel"; then
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
  if command -v python3 >/dev/null 2>&1 && ! declare -F "${1:-}" >/dev/null 2>&1; then
    local py_rc=0
    python3 - "$secs" "$@" <<'PYEOF' || py_rc=$?
import os, signal, subprocess, sys, time

secs = float(sys.argv[1])
cmd = sys.argv[2:]
interrupted = False

p = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, start_new_session=True)

def _on_sig(signum, frame):
    global interrupted
    interrupted = True
    try:
        os.kill(p.pid, signal.SIGTERM)
    except Exception:
        pass
    try:
        os.killpg(p.pid, signal.SIGTERM)
    except Exception:
        pass

signal.signal(signal.SIGINT, _on_sig)
signal.signal(signal.SIGTERM, _on_sig)

try:
    rc = p.wait(timeout=secs)
    try:
        os.killpg(p.pid, signal.SIGTERM)
    except Exception:
        pass
    sys.exit(130 if interrupted else rc)
except subprocess.TimeoutExpired:
    try:
        os.kill(p.pid, signal.SIGTERM)
    except Exception:
        pass
    time.sleep(0.2)
    try:
        os.killpg(p.pid, signal.SIGTERM)
    except Exception:
        pass
    try:
        p.wait(timeout=4.8)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except Exception:
            pass
        try:
            p.wait(timeout=1.0)
        except Exception:
            pass
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except Exception:
        pass
    sys.exit(130 if interrupted else 124)
PYEOF
    return "$py_rc"
  fi

  local marker
  marker="$(mktemp -t relay-timeout.XXXXXX 2>/dev/null || echo "/tmp/relay-timeout.$$")"
  rm -f "$marker" "$marker.int"

  "$@" </dev/null &
  local pid=$!
  (
    sleep "$secs"
    touch "$marker"
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
    sleep 5
    pkill -KILL -P "$pid" 2>/dev/null || true
    kill -KILL "$pid" 2>/dev/null || true
  ) >/dev/null 2>&1 &
  local wd=$!

  trap 'touch "$marker.int"; pkill -TERM -P "$pid" 2>/dev/null || true; kill -TERM "$pid" 2>/dev/null || true' INT TERM
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

  local rc=0 run_start run_end q_before q_after tok_usage
  run_start="$(date +%s)"
  q_before="$(get_role_quota_pair "$provider" "$configured_model")"
  ( cd "$work_dir" && run_with_timeout "$step_timeout" "${cmd[@]}" ) || rc=$?
  run_end="$(date +%s)"

  refresh_quota_cache --quiet
  q_after="$(get_role_quota_pair "$provider" "$configured_model")"
  tok_usage="$(extract_step_token_usage "$provider" "$run_start" "$run_end")"
  append_run_log "auto" "$role_name" "$provider" "$configured_model" "$rc" "$run_start" "$run_end" "$q_before" "$q_after" "$tok_usage"
  print_step_telemetry_box "$role_name" "$provider" "$configured_model" "$rc" "$run_start" "$run_end" "$q_before" "$q_after" "$tok_usage"
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
  local verify_tool_note=""
  if [ -x "$GLOBAL_DIR/bin/relay-verify-task" ]; then
    verify_tool_note=" (สามารถรันสคริปต์ '$GLOBAL_DIR/bin/relay-verify-task .relay/tasks/$ACTIVE_TASK' เพื่อตรวจเพดานบรรทัดเอกสาร, ไฟล์ความลับ และโครงสร้าง JSON อัตโนมัติ)"
  fi
  printf ' จากนั้นต้องเขียนไฟล์ .relay/tasks/%s/QA_VERDICT.json เป็น JSON รูปแบบ {"verdict": "PASS" หรือ "FAIL", "failed_criteria": ["เกณฑ์ที่ไม่ผ่าน"], "tests_run": ["คำสั่งทดสอบที่รันจริง"], "summary": "สรุปสั้น"} โดยให้ PASS ได้เฉพาะเมื่อ failed_criteria ว่าง และห้ามแก้ไขไฟล์ .relay/PROJECT_STATE.md%s' "$ACTIVE_TASK" "$verify_tool_note"
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

# กู้คืนงานกลางคันเมื่อ CLI จบด้วย error (เช่น โควต้าหมดระหว่างกำลังรันขั้นตอนนั้น)
try_mid_step_failover() {
  local rc="$1"
  local role_key="$2"
  local role_label="$3"
  local min_pct="${4:-20}"

  case "$rc" in
    0|124|130) return 1 ;;
  esac

  local cur_prov="" cur_mod=""
  case "$role_key" in
    po)   cur_prov="$ROLE_PO";   cur_mod="$MODEL_PO" ;;
    arch) cur_prov="$ROLE_ARCH"; cur_mod="$MODEL_ARCH" ;;
    dev)  cur_prov="$ROLE_DEV";  cur_mod="$MODEL_DEV" ;;
    qa)   cur_prov="$ROLE_QA";   cur_mod="$MODEL_QA" ;;
    *)    return 1 ;;
  esac

  if [ "${RELAY_AUTO_FAILOVER:-0}" != "1" ] && [ ! -t 0 ] && [ "${RELAY_FORCE_QUOTA_PROMPT:-0}" != "1" ]; then
    return 1
  fi

  echo ""
  printf "%s╭────────────────────────────────────────────────────────────────────────%s\n" "$C_WARN" "$C_RESET"
  printf "%s│%s %s▲ [Mid-Step Failover Guard] %s จบด้วยข้อผิดพลาด (exit %s)%s\n" "$C_WARN" "$C_RESET" "$C_BOLD" "$role_label" "$rc" "$C_RESET"
  printf "%s│%s  • ค่าย/โมเดลที่ใช้ล่าสุด : %s (%s)\n" "$C_WARN" "$C_RESET" "$cur_prov" "$cur_mod"
  printf "%s│%s  • สาเหตุที่เป็นไปได้     : โควต้าของกระเป๋านี้หมดระหว่างทำงาน หรือการเชื่อมต่อขัดข้อง\n" "$C_WARN" "$C_RESET"
  printf "%s│%s  • การกู้คืนงาน          : สลับไปใช้กระเป๋าโควต้าอื่นเพื่อรับไม้ต่อใน Worktree เดิมได้ทันที\n" "$C_WARN" "$C_RESET"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_WARN" "$C_RESET"

  if prompt_or_auto_switch_role_quota "$role_key" "$role_label" "$cur_prov" "$cur_mod" "$min_pct" "mid_step_error"; then
    return 0
  fi
  return 1
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
  local auto_confirm="interactive"
  local arg
  for arg in "$@"; do
    case "$arg" in
      --yes|-y) auto_confirm="--yes" ;;
      --auto-failover) RELAY_AUTO_FAILOVER=1 ;;
    esac
  done

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
  printf "%s│%s  %sระบบเบรกนิรภัยและการสลับโควต้า (Circuit Breakers & Smart Failover):%s\n" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf "%s│%s   1. Quota Guard & Failover : เตือนหรือสลับกระเป๋าโควต้าอัตโนมัติเมื่อโควต้าต่ำกว่า %s%%\n" "$C_ACCENT" "$C_RESET" "$min_quota_pct"
  printf "%s│%s   2. 0-Token Worktree Handoff: ส่งต่อรายชื่อไฟล์ที่ทำค้างใน Worktree ให้ AI ตัวใหม่ทันที\n" "$C_ACCENT" "$C_RESET"
  printf "%s│%s   3. Max Loop Cap           : วนแก้บั๊ก (@dev ⇄ @qa) สูงสุด %s รอบ\n" "$C_ACCENT" "$C_RESET" "$max_rounds"
  printf "%s│%s   4. Step Guard             : หยุดเมื่อ agent ค้างเกิน %s นาทีต่อขั้น หรือไม่สร้างไฟล์ผลลัพธ์\n" "$C_ACCENT" "$C_RESET" "$((step_timeout / 60))"
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  if [ "$auto_confirm" != "--yes" ]; then
    interactive_menu "ต้องการเริ่มรัน Bounded Auto-Relay Loop สำหรับใบงาน '${ACTIVE_TASK}' เลยหรือไม่?" 0 \
      "y|★ เริ่มรันลูปอัตโนมัติ + เปิดระบบสลับกระเป๋าโควต้าอัตโนมัติเมื่อโควต้า < 20% (Smart Auto-Failover)" \
      "s|เริ่มรันลูปอัตโนมัติแบบถามยืนยันก่อนสลับค่ายเมื่อโควต้า < 20%" \
      "b|ย้อนกลับสู่หน้าจอหลัก"
    case "$MENU_RESULT" in
      y|Y) RELAY_AUTO_FAILOVER=1 ;;
      s|S) RELAY_AUTO_FAILOVER=0 ;;
      *)   return 0 ;;
    esac
  fi

  printf "%sกำลังดึงข้อมูลโควต้าสดล่าสุดก่อนเริ่มลูป...%s\n" "$C_MUTED" "$C_RESET"
  refresh_quota_cache

  {
    echo "# บันทึกการทำงานอัตโนมัติ (Bounded Auto-Relay Loop Log — $ACTIVE_TASK)"
    echo ""
    echo "- เริ่มต้นลูปเมื่อ: \`$(date '+%Y-%m-%d %H:%M:%S')\`"
    echo "- เกณฑ์เบรกโควต้าขั้นต่ำ: \`${min_quota_pct}%\` │ จำนวนรอบสูงสุด: \`${max_rounds} รอบ\` │ เพดานเวลาต่อขั้น: \`${step_timeout} วินาที\` │ Auto-Failover: \`${RELAY_AUTO_FAILOVER:-0}\`"
    echo ""
  } > "$LOOP_LOG_FILE"

  local rc=0
  local loop_started_at
  loop_started_at="$(date +%s)"

  local arch_role_note dev_role_note qa_role_note
  arch_role_note="$(get_core_role_prompt_note arch)"
  dev_role_note="$(get_core_role_prompt_note dev)"
  qa_role_note="$(get_core_role_prompt_note qa)"

  # 1. ขั้นตอนที่ 2 (@arch & @pm) หากยังไม่มี PLAN.md
  if [ ! -f "$task_dir/PLAN.md" ]; then
    if ! check_role_quota_safe "$ROLE_ARCH" "$MODEL_ARCH" "@arch & @pm" "$min_quota_pct" "arch"; then
      loop_halt "โควต้าของ @arch ต่ำกว่า ${min_quota_pct}%"
      return 1
    fi
    local arch_prompt="@arch @pm กรุณาอ่านไฟล์ .relay/PROJECT_STATE.md ร่วมกับ .relay/tasks/$ACTIVE_TASK/SPEC.md${learned_note}${arch_role_note} และตรวจสอบไฟล์กำหนดแพ็กเกจ/โครงสร้างจริงของโปรเจกต์ (เช่น package.json, pubspec.yaml) ก่อนวางแผน ห้ามสมมติชื่อไฟล์หรือเพิ่มไลบรารีซ้ำซ้อน แล้วเขียนแยก 2 ไฟล์โดยไม่คัดลอกเนื้อหาซ้ำกัน (รวมกันไม่เกิน 60 บรรทัด ห้ามเขียนเกริ่นนำเยิ่นเย้อ) โดยไม่ต้องรอถามโต้ตอบ: 1. .relay/tasks/$ACTIVE_TASK/ARCH.md (ไม่เกิน 30 บรรทัด: ระบุเฉพาะโครงสร้างทางเทคนิคและรายชื่อไฟล์ที่ต้องสร้างหรือแก้ไข) 2. .relay/tasks/$ACTIVE_TASK/PLAN.md (ไม่เกิน 30 บรรทัด: ระบุเฉพาะลำดับขั้นการลงมือทำเป็นข้อๆ และคำสั่งรันทดสอบ)"
    rc=0
    exec_provider_autonomous "$ROLE_ARCH" "$MODEL_ARCH" "ขั้นตอนที่ 2: @arch & @pm" "$PROJECT_DIR" "$arch_prompt" || rc=$?
    if [ "$rc" -ne 0 ] && try_mid_step_failover "$rc" "arch" "ขั้นตอนที่ 2 (@arch)" "$min_quota_pct"; then
      rc=0
      exec_provider_autonomous "$ROLE_ARCH" "$MODEL_ARCH" "ขั้นตอนที่ 2: @arch & @pm (รับไม้ต่อหลังสลับค่าย)" "$PROJECT_DIR" "$arch_prompt" || rc=$?
    fi
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

    if ! check_role_quota_safe "$ROLE_DEV" "$MODEL_DEV" "@dev (รอบที่ $round/$max_rounds)" "$min_quota_pct" "dev"; then
      loop_halt "โควต้าของ @dev ต่ำกว่า ${min_quota_pct}% (รอบที่ $round)"
      return 1
    fi

    local handoff_note=""
    handoff_note="$(get_worktree_handoff_context_note "$worktree_dir")"
    local dev_prompt=""
    if [ "$round" -eq 1 ]; then
      dev_prompt="@dev กรุณาอ่านเอกสาร .relay/tasks/$ACTIVE_TASK/SPEC.md ร่วมกับ ARCH.md และ PLAN.md (ถ้ามี)${learned_note}${dev_role_note}${handoff_note} แล้วลงมือพัฒนาโค้ดและรันชุดทดสอบให้ครบทุกข้อโดยไม่ต้องรอถามโต้ตอบ (เปิดอ่านเฉพาะไฟล์ทักษะ SKILL.md ที่จำเป็นต่องานนี้ เช่น flutter-best-practices สำหรับงาน Flutter และก่อน commit ต้องรันทั้งคำสั่งตรวจโครงสร้างโค้ด/Type และ Unit Test ให้ผ่านจริง)${commit_note}"
    else
      dev_prompt="@dev การตรวจรับรอบก่อนหน้าไม่ผ่าน กรุณาอ่านข้อบกพร่องในไฟล์ .relay/tasks/$ACTIVE_TASK/QA_REPORT.md และ QA_VERDICT.json ร่วมกับ SPEC.md และ PLAN.md${learned_note}${dev_role_note}${handoff_note} แล้วแก้ไขโค้ดและรันทั้งคำสั่งตรวจโครงสร้างโค้ด/Type และชุดทดสอบให้ผ่านครบทุกจุดโดยไม่ต้องรอถามโต้ตอบ${commit_note}"
    fi

    rc=0
    exec_provider_autonomous "$ROLE_DEV" "$MODEL_DEV" "ขั้นตอนที่ 3: @dev (รอบที่ $round/$max_rounds)" "$worktree_dir" "$dev_prompt" || rc=$?
    if [ "$rc" -ne 0 ] && try_mid_step_failover "$rc" "dev" "ขั้นตอนที่ 3 (@dev รอบที่ $round)" "$min_quota_pct"; then
      handoff_note="$(get_worktree_handoff_context_note "$worktree_dir")"
      dev_prompt="@dev กรุณารับไม้ต่อใน Git Worktree นี้ โดยอ่านเอกสาร .relay/tasks/$ACTIVE_TASK/SPEC.md ร่วมกับ ARCH.md และ PLAN.md (ถ้ามี)${learned_note}${dev_role_note}${handoff_note} แล้วดำเนินการพัฒนาโค้ดที่ค้างอยู่ต่อทันทีและรันทั้งคำสั่งตรวจโครงสร้างโค้ด/Type และชุดทดสอบให้ครบทุกข้อโดยไม่ต้องรอถามโต้ตอบ${commit_note}"
      rc=0
      exec_provider_autonomous "$ROLE_DEV" "$MODEL_DEV" "ขั้นตอนที่ 3: @dev (รอบที่ $round/$max_rounds — รับไม้ต่อหลังสลับค่าย)" "$worktree_dir" "$dev_prompt" || rc=$?
    fi
    loop_check_rc "$rc" "ขั้นตอนที่ 3 (@dev รอบที่ $round)" || return 1
    LAST_COMPLETED_PHASE=3

    if ! check_role_quota_safe "$ROLE_QA" "$MODEL_QA" "@qa & @sec (รอบที่ $round/$max_rounds)" "$min_quota_pct" "qa"; then
      loop_halt "โควต้าของ @qa ต่ำกว่า ${min_quota_pct}% (รอบที่ $round)"
      return 1
    fi

    # ย้ายผลตรวจรับเก่าออก เพื่อไม่ให้ผลรอบก่อนถูกนับเป็นผลของรอบนี้
    archive_old_qa_outputs "$round" "$wt_task_dir" "$task_dir"

    local qa_prompt="@qa @sec กรุณาตรวจสอบผลงานในโฟลเดอร์นี้เทียบกับเกณฑ์ Acceptance Criteria ในไฟล์ .relay/tasks/$ACTIVE_TASK/SPEC.md${learned_note}${qa_role_note} โดย: 1. รันคำสั่งทดสอบจริงผ่าน Terminal 2. ตรวจสอบ git diff ด้านความมั่นคงปลอดภัยและตรวจว่าไม่มีไฟล์ความลับหลุดรอด (เปิดอ่านทักษะเฉพาะทางเมื่อจำเป็นเท่านั้น) 3. เฉพาะกรณีที่ใบงานมีการแก้ไขหน้าเว็บ UI ตาม SPEC.md จึงใช้ Playwright MCP ทดสอบและบันทึกภาพหน้าจอไว้ที่ .relay/tasks/$ACTIVE_TASK/screenshots/ 4. เขียนรายงานสรุปแบบกระชับ (ความยาวไม่เกิน 30 บรรทัด) ลงในไฟล์ .relay/tasks/$ACTIVE_TASK/QA_REPORT.md โดยต้องมีบรรทัด 'VERDICT: PASS' หากผ่านครบทุกข้อ หรือ 'VERDICT: FAIL' พร้อมรายการจุดที่ต้องแก้ไขหากยังไม่ผ่าน (ใส่เพียงบรรทัดเดียว)$(get_qa_prompt_contract)"
    rc=0
    exec_provider_autonomous "$ROLE_QA" "$MODEL_QA" "ขั้นตอนที่ 4: @qa & @sec (รอบที่ $round/$max_rounds)" "$worktree_dir" "$qa_prompt" || rc=$?
    if [ "$rc" -ne 0 ] && try_mid_step_failover "$rc" "qa" "ขั้นตอนที่ 4 (@qa รอบที่ $round)" "$min_quota_pct"; then
      rc=0
      exec_provider_autonomous "$ROLE_QA" "$MODEL_QA" "ขั้นตอนที่ 4: @qa & @sec (รอบที่ $round/$max_rounds — รับไม้ต่อหลังสลับค่าย)" "$worktree_dir" "$qa_prompt" || rc=$?
    fi
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
tmp_ps = f"{ps}.tmp.{os.getpid()}"
with open(tmp_ps, "w", encoding="utf-8") as f:
    f.write(txt)
os.replace(tmp_ps, ps)
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
      "b|ย้อนกลับสู่หน้าจอหลัก"
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

  local dirty dirty_count ahead forbidden_files forbidden_count
  dirty="$(worktree_dirty_files "$worktree_dir")"
  dirty_count="$(printf "%s" "$dirty" | grep -c . || true)"
  ahead="$(git -C "$PROJECT_DIR" rev-list --count "${base}..${branch_name}" 2>/dev/null || echo 0)"
  forbidden_files="$(worktree_forbidden_files "$worktree_dir" "$base" "$branch_name")"
  forbidden_count="$(printf "%s" "$forbidden_files" | grep -c . || true)"

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
  if [ "$forbidden_count" -gt 0 ]; then
    printf "%s│%s  • %s[Security Block] พบไฟล์ความลับ/ฐานข้อมูลต้องห้าม (%s ไฟล์):%s\n" "$C_ACCENT" "$C_RESET" "$C_ERR" "$forbidden_count" "$C_RESET"
    printf "%s\n" "$forbidden_files" | head -n 8 | sed "s/^/${C_ACCENT}│${C_RESET}      • /"
  fi
  local merge_telem
  merge_telem="$(get_task_telemetry_summary_inline "$task")"
  if [ -n "$merge_telem" ]; then
    printf "%s│%s  • ต้นทุนใบงาน  : %b\n" "$C_ACCENT" "$C_RESET" "$merge_telem"
  fi
  if [ "$base" != "main" ] && [ "$base" != "master" ]; then
    printf "%s│%s  %s▲ กิ่งปลายทางไม่ใช่ main/master — ระบบจะถามยืนยันอีกครั้ง%s\n" "$C_ACCENT" "$C_RESET" "$C_WARN" "$C_RESET"
  fi
  printf "%s╰────────────────────────────────────────────────────────────────────────%s\n" "$C_ACCENT" "$C_RESET"

  if [ "$forbidden_count" -gt 0 ]; then
    printf "\n%s✖ ไม่อนุญาตให้ commit หรือผสานกิ่ง %s เนื่องจากพบไฟล์ความลับหรือฐานข้อมูลต้องห้าม (.env*, *.key, *.pem, *.sqlite*, *.db)%s\n" "$C_ERR" "$branch_name" "$C_RESET"
    printf "%s  กรุณาลบไฟล์ดังกล่าวออกจาก Worktree / กิ่ง หรือเพิ่มเข้า .gitignore ก่อนดำเนินการขั้นตอนที่ 5%s\n" "$C_MUTED" "$C_RESET"
    return 1
  fi

  local items=()
  if [ "$dirty_count" -gt 0 ]; then
    items+=("c|★ commit ไฟล์ที่ค้าง ${dirty_count} ไฟล์ใน Worktree (ไม่รวม .relay/) แล้วผสานเข้า ${base}")
  elif [ "$ahead" -gt 0 ]; then
    items+=("y|★ ผสาน ${ahead} commit เข้า ${base} ➔ สกัดบทเรียน ➔ ปิดใบงาน")
  else
    printf "%s▲ กิ่ง %s ไม่มีโค้ดใหม่ให้ผสาน — ระบบจะไม่ลบ Worktree หรือกิ่งใดๆ%s\n" "$C_WARN" "$branch_name" "$C_RESET"
    items+=("a|ปิดใบงานโดยไม่ผสาน (เก็บกิ่งและ Worktree ไว้ตรวจสอบภายหลัง)")
  fi
  items+=("b|ย้อนกลับสู่หน้าจอหลัก (ไม่มีการเปลี่ยนแปลงใดๆ)")

  interactive_menu "เลือกการดำเนินการสำหรับใบงาน ${task}" 0 "${items[@]}"

  case "$MENU_RESULT" in
    c|C)
      local commit_out=""
      if ! commit_out="$( { git -C "$worktree_dir" add -A -- . ':(exclude).relay' ':(exclude).env' ':(exclude).env.*' ':(exclude)**/.env' ':(exclude)**/.env.*' ':(exclude)*.key' ':(exclude)*.pem' ':(exclude)*.sqlite' ':(exclude)*.sqlite3' ':(exclude)*.db' && git -C "$worktree_dir" commit -m "feat(${task}): งานจาก @dev (RELAY auto-commit ก่อนผสาน)"; } 2>&1 )"; then
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
      "b|ย้อนกลับ — กลับไปแก้ไขก่อน"
    [ "$MENU_RESULT" != "y" ] && return 0
  fi

  if [ "$base" != "main" ] && [ "$base" != "master" ]; then
    interactive_menu "ยืนยันผสานเข้ากิ่ง '${base}' (ไม่ใช่ main/master)?" 1 \
      "y|ยืนยันผสานเข้า ${base}" \
      "b|ย้อนกลับ"
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
    "5|สร้างทักษะเฉพาะทางสำหรับโปรเจกต์นี้ (.relay/skills/<name>/SKILL.md + scripts/)" \
    "b|ย้อนกลับสู่หน้าจอหลัก"

  case "$MENU_RESULT" in
    1) "$skills_cmd" list ;;
    2) "$skills_cmd" install ;;
    3) "$skills_cmd" update ;;
    4)
      read -r -p "ระบุ GitHub Repo URL (หรือพิมพ์ b เพื่อย้อนกลับ): " repo_url || true
      if is_back_input "$repo_url" || [ -z "$repo_url" ]; then
        return 0
      fi
      read -r -p "ระบุชื่อ Skill ย่อย (หรือกด Enter หากติดตั้งทั้ง Repo • พิมพ์ b เพื่อย้อนกลับ): " skill_sub || true
      if is_back_input "$skill_sub"; then
        return 0
      fi
      "$skills_cmd" add "$repo_url" "$skill_sub"
      ;;
    5)
      local new_sk_name="" new_sk_desc=""
      read -r -p "ตั้งชื่อ Skill ใหม่ภาษาอังกฤษ (เช่น api-contract-check หรือพิมพ์ b เพื่อย้อนกลับ): " new_sk_name || true
      if is_back_input "$new_sk_name" || [ -z "$new_sk_name" ]; then
        return 0
      fi
      read -r -p "ระบุคำอธิบายสั้นๆ ว่าเมื่อไหร่ควรเปิดใช้ Skill นี้ (หรือพิมพ์ b เพื่อย้อนกลับ): " new_sk_desc || true
      if is_back_input "$new_sk_desc"; then
        return 0
      fi
      "$skills_cmd" create "$new_sk_name" "$new_sk_desc" "$RELAY_DIR/skills"
      ;;
  esac
}

# รองรับการ source เฉพาะฟังก์ชันสำหรับชุดทดสอบอัตโนมัติโดยไม่เข้า Interactive Loop
if [ "${RELAY_SOURCE_ONLY:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

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
    shift
    run_auto_relay_loop "$@"
    exit 0
    ;;
  learn|distill)
    run_learned_skills_menu "${2:-interactive}"
    exit 0
    ;;
  stats|telemetry|tokens)
    run_task_stats_view "${2:-interactive}"
    exit 0
    ;;
  fast|quick|x)
    run_fast_track_dev "${2:-}"
    exit 0
    ;;
  agents|agent|roles)
    shift
    run_agents_manager_menu "${@}"
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
    interactive_menu "ขั้นที่ 1/3: ตั้งค่าค่าย AI, เลือก Model และเข้าสู่ระบบให้ครบ 4 ตำแหน่ง (พร้อมใช้งานจริง ${READY_ROLE_COUNT}/4)" 0 \
      "1|★ [แนะนำ] ตั้งค่าด่วนด้วยโควตา Google AI Ultra (agy) + Codex พร้อมใช้ทันที" \
      "2|เลือกค่าย AI และ Model แยกทีละตำแหน่ง (@po, @arch, @dev, @qa)" \
      "g|จัดการบทบาท Agent, คำสั่ง Prompt และทักษะประจำตำแหน่ง (/agents)" \
      "3|จัดการการเชื่อมต่อ CLI และการเข้าสู่ระบบ (agy / codex / claude)" \
      "u|ตรวจสอบและอัปเดตโควต้าคงเหลือแบบเรียลไทม์ของทุกค่าย (/quota)" \
      "t|ตรวจสอบสถานะความพร้อม Agent และทักษะประจำตำแหน่ง (/test)" \
      "q|ออกจากโปรแกรม (/quit)"

    case "$MENU_RESULT" in
      1) run_quick_preset_menu ;;
      2|c|C|/model|/config) configure_roles_menu ;;
      g|G|/agents|/agent|/roles) run_agents_manager_menu ;;
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
      interactive_menu "ขั้นที่ 2/3: เลือกหรือสร้างโฟลเดอร์โปรเจกต์ (ปัจจุบันอยู่ใน Home ~)" 0 \
        "1|★ เลือกโฟลเดอร์โปรเจกต์ในเครื่อง หรือสร้างโปรเจกต์ใหม่ทันที" \
        "u|ตรวจสอบและอัปเดตโควต้าคงเหลือแบบเรียลไทม์ของทุกค่าย (/quota)" \
        "t|ทดสอบความพร้อมของ Agent ทุกบทบาท (/test)" \
        "g|จัดการบทบาท Agent, Prompt และชุดทักษะ Skills (/agents)" \
        "c|ตั้งค่าค่าย AI และเลือก Model ของแต่ละบทบาท (/model)" \
        "d|จัดการการเชื่อมต่อ CLI และการเข้าสู่ระบบ (/connect)" \
        "q|ออกจากโปรแกรม (เพื่อพิมพ์ cd เข้าโฟลเดอร์โปรเจกต์เอง)"

      case "$MENU_RESULT" in
        1|f|F|i|I|/init) select_or_create_project_dir ;;
        u|U|/quota|/usage) run_quota_dashboard ;;
        g|G|/agents|/agent|/roles) run_agents_manager_menu ;;
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
        "u|ตรวจสอบและอัปเดตโควต้าคงเหลือแบบเรียลไทม์ของทุกค่าย (/quota)" \
        "t|ทดสอบความพร้อม Agent ทุกตำแหน่ง (/test)" \
        "g|จัดการบทบาท Agent, คำสั่ง Prompt และทักษะประจำตำแหน่ง (/agents)" \
        "c|ตั้งค่าค่าย AI และเลือก Model ประจำตำแหน่ง (/model)" \
        "q|ออกจากโปรแกรม (/quit)"

      case "$MENU_RESULT" in
        1) run_init_greenfield ;;
        2) run_init_brownfield ;;
        f|F) select_or_create_project_dir ;;
        u|U|/quota|/usage) run_quota_dashboard ;;
        g|G|/agents|/agent|/roles) run_agents_manager_menu ;;
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
    # ขั้นที่ 3/3: Workflow Menu (7 คำสั่งหลัก + แถบ Shortcuts ด้านล่าง)
    # ═══════════════════════════════════════════════════════════════════════════
    p1_label="@po            Define Spec (SPEC.md) · ${ROLE_PO}/${MODEL_PO}"
    p2_label="@arch & @pm    Design Architecture & Plan (ARCH.md, PLAN.md) · ${ROLE_ARCH}/${MODEL_ARCH}"
    p3_label="@dev           Implement in Git Worktree + Tests · ${ROLE_DEV}/${MODEL_DEV}"
    p4_label="@qa & @sec     Verify Tests, Security & QA_REPORT.md · ${ROLE_QA}/${MODEL_QA}"
    p5_label="Merge          Merge Branch to main & Archive Task"
    pa_label="Auto Loop      Run Steps 2 → 3 ⇄ 4 Automatically (/loop)"
    px_label="Fast Track     Quick Spec + Step 3 → 4 in Git Worktree (/fast)"

    default_menu_idx=$((RECOMMENDED_STEP - 1))
    MENU_SHORTCUTS_BAR="1"
    EXTRA_MENU_KEYS="c g u v l n f i t d s q m"

    interactive_menu "Workflow (↑/↓ select, Enter run, or press key)" "$default_menu_idx" \
      "1|${p1_label}" \
      "2|${p2_label}" \
      "3|${p3_label}" \
      "4|${p4_label}" \
      "5|${p5_label}" \
      "a|${pa_label}" \
      "x|${px_label}"

    case "$MENU_RESULT" in
      1|/po|/1)             run_phase_1_po ;;
      2|/arch|/pm|/2)       run_phase_2_arch ;;
      3|/dev|/3)            run_phase_3_dev ;;
      4|/qa|/sec|/4)        run_phase_4_qa ;;
      5|/merge|/5)          run_phase_5_merge ;;
      a|A|/loop|/auto)      run_auto_relay_loop ;;
      x|X|/fast|/quick)     run_fast_track_dev ;;
      v|V|/stats|/tokens)   run_task_stats_view ;;
      g|G|/agents|/agent|/roles) run_agents_manager_menu ;;
      /@*)                  run_custom_agent_task "${MENU_RESULT#/@}" ;;
      l|L|/learn|/distill)  run_learned_skills_menu ;;
      n|N|/new)             create_new_task || true ;;
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
