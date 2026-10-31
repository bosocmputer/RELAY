#!/usr/bin/env bash
# ชุดทดสอบอัตโนมัติสำหรับใบงาน 20261031-high-severity-fixes (H1–H9 จากผลตรวจ Deep Audit)
# ไม่ใช้โควต้า AI: แยก HOME ชั่วคราว และใช้ CLI จำลอง (stub) แทน agy / claude / codex
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELAY_SH="$REPO_ROOT/relay.sh"

TMP_ROOT="$(mktemp -d -t relay-high-fixes.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
ok()  { echo "  ✅ PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
bad() { echo "  ❌ FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
check() { if eval "$1"; then ok "$2"; else bad "$2"; fi; }

# PATH ที่มีเฉพาะ python3 + เครื่องมือระบบ + CLI จำลอง (ไม่เรียก CLI จริงของเครื่อง)
STUB_BIN="$TMP_ROOT/stub-bin"
mkdir -p "$STUB_BIN"
ln -s "$(command -v python3)" "$STUB_BIN/python3"
for c in agy claude codex; do
  printf '#!/bin/sh\nexit 1\n' > "$STUB_BIN/$c"
  chmod +x "$STUB_BIN/$c"
done
SAFE_PATH="$STUB_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
unset GIT_CONFIG_GLOBAL XDG_CONFIG_HOME
export GIT_CONFIG_NOSYSTEM=1

new_home() {
  local h="$TMP_ROOT/$1"
  mkdir -p "$h"
  printf '[user]\n\tname = relay-test\n\temail = relay-test@example.com\n' > "$h/.gitconfig"
  echo "$h"
}

# git ทุกคำสั่งในชุดทดสอบใช้ HOME ชั่วคราว (ไม่อ่าน ~/.gitconfig หรือ global hook ของเครื่องจริง)
export HOME="$(new_home base-home)"

# รัน bash ที่ source relay.sh แบบฟังก์ชันอย่างเดียว
relay_src() {
  local home="$1"
  shift
  HOME="$home" PATH="$SAFE_PATH" RELAY_SOURCE_ONLY=1 bash -c "source \"$RELAY_SH\"; $*"
}

echo "=== [H1] เมนูแบบไม่มี TTY เมื่อ stdin หมด (EOF) ต้องย้อนกลับ ไม่เลือกข้อแรกเอง ==="
H1_HOME="$(new_home h1)"
out="$(relay_src "$H1_HOME" 'interactive_menu "t" 0 "y|ยืนยัน" "b|ย้อนกลับ" >/dev/null; echo "$MENU_RESULT|$MENU_STDIN_EOF"' </dev/null)"
check '[ "$out" = "b|1" ]' "EOF ➔ MENU_RESULT=b และตั้ง MENU_STDIN_EOF=1 (ได้ '$out')"
out="$(printf '\n' | relay_src "$H1_HOME" 'interactive_menu "t" 0 "y|ยืนยัน" "b|ย้อนกลับ" >/dev/null; echo "$MENU_RESULT"')"
check '[ "$out" = "y" ]' "กด Enter (บรรทัดว่าง) ยังเลือกข้อที่ไฮไลต์ตามเดิม"
out="$(printf 'b' | relay_src "$H1_HOME" 'interactive_menu "t" 0 "y|ยืนยัน" "b|ย้อนกลับ" >/dev/null; echo "$MENU_RESULT"')"
check '[ "$out" = "b" ]' "พิมพ์ค่าโดยไม่มีขึ้นบรรทัดใหม่ก่อน EOF ยังอ่านค่านั้นได้"

H1_REPO="$TMP_ROOT/h1-repo"
T=20261031-demo
mkdir -p "$H1_REPO" && cd "$H1_REPO" || exit 1
git init -q -b main . && git commit -q --allow-empty -m init
git worktree add -q ".relay/worktrees/$T" -b "feat/$T"
mkdir -p ".relay/tasks/$T" && echo "# demo" > ".relay/tasks/$T/SPEC.md"
echo '{"verdict":"PASS","failed_criteria":[]}' > ".relay/tasks/$T/QA_VERDICT.json"
echo "feature" > ".relay/worktrees/$T/feature.txt"
relay_src "$H1_HOME" 'require_all_roles_ready() { return 0; }; PROJECT_DIR="$PWD"; refresh_project_paths; run_phase_5_merge' </dev/null >/dev/null 2>&1
check '[ "$(git -C "$H1_REPO" rev-list --count main)" = "1" ]' "ขั้นตอนที่ 5 ที่ stdin หมดต้องไม่ merge เข้า main"
check '[ -d "$H1_REPO/.relay/worktrees/$T" ] && [ -d "$H1_REPO/.relay/tasks/$T" ]' "Worktree และใบงานยังอยู่ครบ"
cd "$TMP_ROOT" || exit 1

H1_PROJ="$TMP_ROOT/h1-proj"
mkdir -p "$H1_PROJ"
( cd "$H1_PROJ" && HOME="$H1_HOME" PATH="$SAFE_PATH" python3 - "$RELAY_SH" <<'PYEOF'
import subprocess, sys
try:
    rc = subprocess.run(["bash", sys.argv[1]], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL, timeout=60).returncode
except subprocess.TimeoutExpired:
    rc = "timeout"
print(rc)
PYEOF
) > "$TMP_ROOT/h1-hub.rc"
check '[ "$(cat "$TMP_ROOT/h1-hub.rc")" = "0" ]' "หน้าจอหลัก (hub) ออกเองเมื่อ stdin หมด ไม่วนไม่รู้จบ (ได้ '$(cat "$TMP_ROOT/h1-hub.rc")')"

echo "=== [H8] Ctrl+C ในเมนูต้องออกโปรแกรม แต่ Ctrl+C ระหว่าง CLI ของ agent ทำงานต้องไม่ปิด relay ==="
H8_HOME="$(new_home h8)"
cat > "$TMP_ROOT/pty_drive.py" <<'PYEOF'
import os, pty, select, sys, time
script = sys.argv[1]
pid, fd = pty.fork()
if pid == 0:
    os.execv("/bin/bash", ["/bin/bash", "-c", script])
out = b""
def drain(t):
    global out
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try:
                d = os.read(fd, 4096)
            except OSError:
                return
            if not d:
                return
            out += d
drain(1.5)
os.write(fd, b"\x03")
drain(2.0)
try:
    os.kill(pid, 9)
except Exception:
    pass
_, status = os.waitpid(pid, 0)
rc = os.waitstatus_to_exitcode(status) if hasattr(os, "waitstatus_to_exitcode") else status
print(f"RC={rc}")
print(out.decode("utf-8", "replace"))
PYEOF
menu_script="export HOME='$H8_HOME' PATH='$SAFE_PATH' TERM=xterm RELAY_SOURCE_ONLY=1; source '$RELAY_SH'; install_interrupt_traps; interactive_menu t 0 'a|A' 'b|B'; echo AFTER_MENU"
res="$(python3 "$TMP_ROOT/pty_drive.py" "$menu_script")"
check 'printf "%s" "$res" | grep -q "^RC=130" && ! printf "%s" "$res" | grep -q AFTER_MENU' "Ctrl+C ในเมนู ➔ ออกด้วย exit 130 (bash $(/bin/bash -c 'echo $BASH_VERSION'))"
check 'printf "%s" "$res" | grep -q "?25h"' "Ctrl+C ในเมนู ➔ คืนเคอร์เซอร์ (tput cnorm)"
child_script="export HOME='$H8_HOME' PATH='$SAFE_PATH' TERM=xterm RELAY_SOURCE_ONLY=1; source '$RELAY_SH'; install_interrupt_traps; RELAY_CHILD_ACTIVE=1; python3 -c 'import signal,sys,time; signal.signal(signal.SIGINT, lambda *a: sys.exit(130)); time.sleep(10)' || echo CHILD_RC=\$?; RELAY_CHILD_ACTIVE=0; echo RELAY_ALIVE"
res="$(python3 "$TMP_ROOT/pty_drive.py" "$child_script")"
check 'printf "%s" "$res" | grep -q "CHILD_RC=130" && printf "%s" "$res" | grep -q RELAY_ALIVE && printf "%s" "$res" | grep -q "^RC=0"' "Ctrl+C ระหว่าง CLI ทำงาน ➔ CLI หยุดเอง แต่ relay ทำงานต่อ"

echo "=== [H5] ตั้ง default model ของ codex ต้องอยู่ระดับบนสุดของ TOML ==="
H5_HOME="$(new_home h5)"
mkdir -p "$H5_HOME/.codex"
printf '[profiles.fast]\nmodel = "profile-model"\n\n[mcp_servers.playwright]\ncommand = "npx"\n' > "$H5_HOME/.codex/config.toml"
relay_src "$H5_HOME" 'set_cli_default_model codex gpt-top' >/dev/null 2>&1
first_line="$(grep -v '^[[:space:]]*$' "$H5_HOME/.codex/config.toml" | head -n 1)"
check '[ "$first_line" = "model = \"gpt-top\"" ]' "แทรก model ก่อนหัวตารางตัวแรก (ได้ '$first_line')"
check 'grep -q "^model = \"profile-model\"" "$H5_HOME/.codex/config.toml"' "ไม่แตะ model ใน [profiles.fast]"
check '[ "$(awk "/^\\[mcp_servers.playwright\\]/{f=1;next} f" "$H5_HOME/.codex/config.toml" | grep -c "^model")" = "0" ]' "ไม่มี model หลุดเข้าไปใน [mcp_servers.playwright]"
relay_src "$H5_HOME" 'set_cli_default_model codex gpt-second' >/dev/null 2>&1
check '[ "$(grep -c "^model = \"gpt-" "$H5_HOME/.codex/config.toml")" = "1" ] && grep -q "^model = \"gpt-second\"" "$H5_HOME/.codex/config.toml"' "ตั้งซ้ำ ➔ แทนค่าบรรทัดเดิม ไม่เพิ่มบรรทัดซ้ำ"
got="$(relay_src "$H5_HOME" 'get_cli_default_model codex')"
check '[ "$got" = "gpt-second" ]' "get_cli_default_model อ่าน model ระดับบนสุด (ได้ '$got')"
printf '[profiles.fast]\nmodel = "profile-model"\n' > "$H5_HOME/.codex/config.toml"
got="$(relay_src "$H5_HOME" 'get_cli_default_model codex')"
check '[ "$got" != "profile-model" ]' "ไม่อ่าน model จาก [profiles.*] เป็นค่าเริ่มต้น"

echo "=== [H6] settings.json ของ claude ที่อ่านไม่ผ่านต้องไม่ถูกเขียนทับ ==="
H6_HOME="$(new_home h6)"
mkdir -p "$H6_HOME/.claude"
printf '{\n  "permissions": {"allow": ["Bash(ls)"]},\n  // comment\n  "theme": "dark"\n}\n' > "$H6_HOME/.claude/settings.json"
cp "$H6_HOME/.claude/settings.json" "$TMP_ROOT/h6-orig.json"
err="$(relay_src "$H6_HOME" 'set_cli_default_model claude opus' 2>&1 >/dev/null)"
check 'cmp -s "$H6_HOME/.claude/settings.json" "$TMP_ROOT/h6-orig.json"' "JSON เสีย ➔ ไฟล์เดิมไม่ถูกแก้"
check 'printf "%s" "$err" | grep -q "ไม่ได้แก้ไขไฟล์"' "แจ้ง error ให้ผู้ใช้ทราบ"
printf '{"permissions": {"allow": ["Bash(ls)"]}, "theme": "dark"}\n' > "$H6_HOME/.claude/settings.json"
chmod 600 "$H6_HOME/.claude/settings.json"
relay_src "$H6_HOME" 'set_cli_default_model claude opus' >/dev/null 2>&1
check 'python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d[\"model\"]==\"opus\" and d[\"theme\"]==\"dark\" and d[\"permissions\"] else 1)" "$H6_HOME/.claude/settings.json"' "JSON ถูกต้อง ➔ ตั้ง model และเก็บค่าเดิมครบ"
check '[ "$(stat -c %a "$H6_HOME/.claude/settings.json" 2>/dev/null || stat -f %Lp "$H6_HOME/.claude/settings.json")" = "600" ]' "คงสิทธิ์ไฟล์เดิม (600)"

echo "=== [H7] ชื่อโปรเจกต์ที่กรองแล้วว่างต้องไม่ใช้โฟลเดอร์ workspace เป็นโปรเจกต์ ==="
H7_HOME="$(new_home h7)"
mkdir -p "$H7_HOME/dev_bos" "$H7_HOME/.agents/bin"
cp "$REPO_ROOT/relay-init.sh" "$H7_HOME/.agents/bin/relay-init"
chmod +x "$H7_HOME/.agents/bin/relay-init"
( cd "$H7_HOME" && printf 'n\nแอปบัญชี\n' | relay_src "$H7_HOME" 'PROJECT_DIR="$HOME"; select_or_create_project_dir' >/dev/null 2>&1 )
check '[ ! -e "$H7_HOME/dev_bos/.relay" ]' "ไม่สร้าง .relay/ ที่ราก workspace (~/dev_bos)"
created="$(ls -1 "$H7_HOME/dev_bos" | grep '^relay-app-' | head -n 1)"
check '[ -n "$created" ] && [ -f "$H7_HOME/dev_bos/$created/.relay/PROJECT_STATE.md" ]' "สร้างโปรเจกต์ชื่อใหม่ให้อัตโนมัติ (ได้ '$created')"
( cd "$H7_HOME" && printf 'n\nระบบ-pos\n' | relay_src "$H7_HOME" 'PROJECT_DIR="$HOME"; select_or_create_project_dir' >/dev/null 2>&1 )
check '[ -d "$H7_HOME/dev_bos/pos" ]' "ตัดขีดนำหน้าทั้งหมด ('ระบบ-pos' ➔ 'pos')"

echo "=== [H2] setup-mac.sh ต้องสำรองไฟล์กฎเดิมก่อนแทนที่ ==="
H2_HOME="$(new_home h2)"
mkdir -p "$H2_HOME/.claude" "$H2_HOME/.codex"
echo "my own claude rules" > "$H2_HOME/.claude/CLAUDE.md"
echo "my own codex rules" > "$H2_HOME/.codex/AGENTS.md"
HOME="$H2_HOME" PATH="$SAFE_PATH" bash "$REPO_ROOT/setup-mac.sh" >/dev/null 2>&1
bak="$(ls -1 "$H2_HOME/.claude" | grep '^CLAUDE.md.bak.' | head -n 1)"
check '[ -n "$bak" ] && [ "$(cat "$H2_HOME/.claude/$bak")" = "my own claude rules" ]' "สำรอง ~/.claude/CLAUDE.md เดิมพร้อมเนื้อหาครบ"
check 'ls "$H2_HOME/.codex" | grep -q "^AGENTS.md.bak."' "สำรอง ~/.codex/AGENTS.md เดิม"
check '[ -L "$H2_HOME/.claude/CLAUDE.md" ] && [ -L "$H2_HOME/.gemini/GEMINI.md" ]' "เชื่อม symlink ไปยัง GLOBAL_AGENTS.md แล้ว"
echo "# ผู้ใช้แก้กฎเอง" >> "$H2_HOME/.agents/GLOBAL_AGENTS.md"
sleep 1
HOME="$H2_HOME" PATH="$SAFE_PATH" bash "$REPO_ROOT/setup-mac.sh" >/dev/null 2>&1
check '[ "$(ls -1 "$H2_HOME/.claude" | grep -c "^CLAUDE.md.bak.")" = "1" ]' "รันซ้ำ ➔ ไม่สำรอง symlink ซ้ำ"
check 'grep -q "ผู้ใช้แก้กฎเอง" "$H2_HOME"/.agents/GLOBAL_AGENTS.md.bak.*' "รันซ้ำ ➔ สำรอง GLOBAL_AGENTS.md ที่ผู้ใช้แก้ไว้ก่อนเขียนทับ"
check '[ "$(HOME="$H2_HOME" git config --global --get core.hooksPath)" = "$H2_HOME/.agents/hooks" ]' "ตั้ง core.hooksPath เมื่อยังไม่มีค่าเดิม"

H2B_HOME="$(new_home h2b)"
HOME="$H2B_HOME" git config --global core.hooksPath /custom/hooks
HOME="$H2B_HOME" PATH="$SAFE_PATH" bash "$REPO_ROOT/setup-mac.sh" >/dev/null 2>&1
check '[ "$(HOME="$H2B_HOME" git config --global --get core.hooksPath)" = "/custom/hooks" ]' "ไม่ทับ core.hooksPath ที่ผู้ใช้ตั้งไว้เอง"

echo "=== [H3] hook เดิมของ repo ต้องยังทำงานภายใต้ global core.hooksPath ==="
H3_REPO="$TMP_ROOT/h3-repo"
mkdir -p "$H3_REPO" && cd "$H3_REPO" || exit 1
HOME="$H2_HOME" git init -q -b main .
printf '#!/bin/sh\necho LOCAL_PRE_COMMIT_BLOCK; exit 1\n' > .git/hooks/pre-commit
printf '#!/bin/sh\necho ran > "%s"\n' "$TMP_ROOT/h3-commit-msg.ran" > .git/hooks/commit-msg
chmod +x .git/hooks/pre-commit .git/hooks/commit-msg
echo a > a.txt && HOME="$H2_HOME" git add a.txt
check '! HOME="$H2_HOME" git commit -q -m a >/dev/null 2>&1' "pre-commit เดิมของ repo (exit 1) ยังบล็อก commit ได้"
rm -f .git/hooks/pre-commit
HOME="$H2_HOME" git commit -q -m a >/dev/null 2>&1
check '[ -f "$TMP_ROOT/h3-commit-msg.ran" ]' "commit-msg เดิมของ repo ยังถูกเรียกผ่านตัวส่งต่อ"
cd "$TMP_ROOT" || exit 1

echo "=== [H4] pre-commit: อนุญาตการลบไฟล์ความลับ และใช้กฎเดียวกับ relay.sh ==="
H4_REPO="$TMP_ROOT/h4-repo"
mkdir -p "$H4_REPO" && cd "$H4_REPO" || exit 1
hk="$REPO_ROOT/templates"
g() { git -c core.hooksPath="$hk" "$@"; }
git init -q -b main .
echo "SECRET=1" > .env && git add -f .env && git commit -q --no-verify -m leaked
g rm -q --cached .env
check 'g commit -q -m "remove leaked secret" >/dev/null 2>&1' "commit การลบ .env ที่หลุดเข้าไปแล้วได้"
for f in .env.example .env.sample .env.template .env.schema; do
  echo "X=" > "$f" && g add -f "$f"
done
check 'g commit -q -m samples >/dev/null 2>&1' "อนุญาต .env.example / .sample / .template / .schema"
for f in .env.local app.db data.sqlite3 server.key; do
  echo x > "$f" && g add -f "$f"
  if g commit -q -m "$f" >/dev/null 2>&1; then bad "ต้องบล็อก $f"; else ok "บล็อก $f"; fi
  git reset -q HEAD "$f"
done
cd "$TMP_ROOT" || exit 1

echo "=== [H9] npx ต้องล็อกเวอร์ชันแพ็กเกจ ==="
check '! grep -nE "@latest|npx -y skills " "$REPO_ROOT/relay-skills.sh"' "relay-skills.sh ไม่มี @latest หรือ npx skills ที่ไม่ระบุเวอร์ชัน"
check 'grep -qE "^SKILLS_CLI_PKG=\"\\\$\{RELAY_SKILLS_CLI_PKG:-skills@[0-9]+\.[0-9]+\.[0-9]+\}\"" "$REPO_ROOT/relay-skills.sh"' "ค่าเริ่มต้นของ skills CLI เป็นเวอร์ชันที่ระบุชัดและปรับผ่านตัวแปรได้"

echo ""
echo "=================================================================="
echo "สรุปผลชุดทดสอบ HIGH Severity Fixes: ผ่าน ${PASS_COUNT} รายการ, ล้มเหลว ${FAIL_COUNT} รายการ"
echo "=================================================================="
[ "$FAIL_COUNT" -eq 0 ]
