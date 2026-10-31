#!/usr/bin/env bash
# ชุดทดสอบเมนูบนจอแคบ + ตัวกรองคำเตือนของ claude (ใบงาน 20261031-menu-fit-and-claude-warning-filter)
# จำลองหน้าจอด้วย Terminal ที่ไม่ทำตาม ESC[?7l (ตัดบรรทัดเอง) — ไม่ใช้โควต้า AI
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELAY_SH="$REPO_ROOT/relay.sh"

TMP_ROOT="$(mktemp -d -t relay-terminal-menu.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT
export HOME="$TMP_ROOT/home"
mkdir -p "$HOME/.agents"

PASS_COUNT=0
FAIL_COUNT=0
ok()  { echo "  ✅ PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
bad() { echo "  ❌ FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
check() { if eval "$1"; then ok "$2"; else bad "$2"; fi; }

LONG_EN="Design Architecture and Plan (ARCH.md, PLAN.md) using claude/claude-opus-5-5-high with a long suffix"
LONG_TH="ตั้งค่าค่าย AI และเลือก Model ประจำตำแหน่งพร้อมคำอธิบายยาวมากเกินความกว้างของหน้าจอแคบ"

echo "=== ตัดข้อความให้พอดีจอ (นับตามตัวอักษร UTF-8 แม้ locale เป็น C) ==="
out="$(env -u LANG -u LC_ALL -u LC_CTYPE RELAY_SOURCE_ONLY=1 /bin/bash -c "source '$RELAY_SH'; relay_detect_utf8_locale; relay_fit_text '$LONG_TH' 20")"
check 'printf "%s" "$out" | python3 -c "import sys; t=sys.stdin.buffer.read().decode(\"utf-8\"); sys.exit(0 if t.endswith(\"…\") and len(t) <= 20 and \"\\ufffd\" not in t else 1)"' "ภาษาไทยถูกตัดเหลือไม่เกิน 20 ตัวอักษร ลงท้ายด้วย … และไม่มีตัวอักษรเสีย"
out="$(RELAY_SOURCE_ONLY=1 /bin/bash -c "source '$RELAY_SH'; relay_detect_utf8_locale; relay_fit_text 'short label' 20")"
check '[ "$out" = "short label" ]' "ข้อความที่สั้นกว่าจอไม่ถูกแก้"

echo "=== เมนูบนจอ 60 คอลัมน์ ใน Terminal ที่ไม่ทำตาม ESC[?7l ==="
res="$(python3 - "$RELAY_SH" "$HOME" "$LONG_EN" "$LONG_TH" <<'PYEOF'
import fcntl, os, pty, re, select, struct, sys, termios, time, unicodedata
relay, home, long_en, long_th = sys.argv[1:5]
COLS, ROWS = 60, 40
script = (f"export HOME='{home}' TERM=xterm RELAY_SOURCE_ONLY=1; unset LANG LC_ALL LC_CTYPE; source '{relay}'; "
          f"MENU_SHORTCUTS_BAR=1; interactive_menu t 0 '1|{long_en}' '2|{long_th}' '3|short item'; echo \"RESULT=$MENU_RESULT\"")
pid, fd = pty.fork()
if pid == 0:
    os.execv("/bin/bash", ["/bin/bash", "-c", script])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
out = b""
def drain(t):
    global out
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                d = os.read(fd, 65536)
            except OSError:
                return
            if not d:
                return
            out += d
drain(1.5)
for key in (b"\x1b[B", b"\x1b[B", b"\x1b[A"):
    os.write(fd, key)
    drain(1.3)
os.write(fd, b"\r")
drain(1.0)
try:
    os.waitpid(pid, 0)
except Exception:
    pass
# จอจำลองที่ตัดบรรทัดเสมอ (ไม่ทำตาม ESC[?7l)
scr = [[" "] * COLS for _ in range(ROWS)]
x = y = 0
def nl():
    global y
    if y == ROWS - 1:
        scr.pop(0); scr.append([" "] * COLS)
    else:
        y += 1
def width(c):
    if unicodedata.combining(c) or unicodedata.category(c) in ("Mn", "Me", "Cf"):
        return 0
    return 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1
s = out.decode("utf-8", "replace")
csi = re.compile(r"\x1b\[(\??)([0-9;]*)([A-Za-z])")
i = 0
while i < len(s):
    c = s[i]
    if c == "\x1b":
        m = csi.match(s, i)
        if m:
            q, a, cmd = m.groups()
            n = int(a.split(";")[0] or 1) if a else 1
            if cmd == "A" and not q:
                y = max(0, y - n)
            elif cmd == "K":
                scr[y] = [" "] * COLS
            i = m.end()
            continue
        i += 1
        continue
    if c == "\r":
        x = 0
    elif c == "\n":
        nl()
    elif c >= " ":
        w = width(c)
        if w:
            if x + w > COLS:
                x = 0; nl()
            scr[y][x] = c
            x += w
    i += 1
lines = ["".join(r).rstrip() for r in scr]
if os.environ.get("DEBUG_MENU"):
    sys.stderr.write("\n".join(l for l in lines if l.strip()) + "\n")
items = [l for l in lines if re.match(r"^\s+(❯ )?\[[123]\] ", l)]
print("ITEMS=%d" % len(items))
print("DUP1=%d" % len([l for l in items if "[1]" in l]))
print("ELLIPSIS=%d" % len([l for l in items if l.endswith("…")]))
print("BAD_CHARS=%d" % s.count("\ufffd"))
m = re.search(r"RESULT=(\S+)", s)
print("RESULT=%s" % (m.group(1) if m else "-"))
PYEOF
)"
check 'printf "%s" "$res" | grep -q "^ITEMS=3$" && printf "%s" "$res" | grep -q "^DUP1=1$"' "กด ↓ ↓ ↑ แล้วเมนูไม่ซ้อน (แถวเมนู 3 แถว และแถว [1] ไม่ซ้ำ)"
check 'printf "%s" "$res" | grep -q "^ELLIPSIS=2$" && printf "%s" "$res" | grep -q "^BAD_CHARS=0$"' "ข้อความยาวทั้ง 2 รายการถูกตัดพร้อม … และไม่มีตัวอักษรเสีย"
check 'printf "%s" "$res" | grep -q "^RESULT=2$"' "ตัดข้อความแล้วยังเลือกรายการได้ถูกต้อง (↓ ↓ ↑ ➔ [2])"

echo "=== ตัวกรองคำเตือน Permission allow rule ของ claude ==="
err="$(printf 'Permission allow rule (../../.claude/settings.json): Bash(x) has a wildcard\nPermission allow rule (.claude/settings.json): Bash(y)\nreal error from claude\n' | RELAY_SOURCE_ONLY=1 /bin/bash -c "source '$RELAY_SH'; filter_claude_permission_warnings" 2>&1)"
check '[ "$err" = "real error from claude" ]' "กรองคำเตือนทุกพาธ และข้อความ error อื่นยังแสดง"
check '[ "$(grep -c "2> >(filter_claude_permission_warnings)" "$RELAY_SH")" = "2" ] && ! grep -q "Permission allow rule (\\\\.claude" "$RELAY_SH"' "ทั้ง [t] และการเปิด CLI ของแต่ละขั้นตอนใช้ตัวกรองเดียวกัน"

echo ""
echo "=================================================================="
echo "สรุปผลชุดทดสอบ Terminal Menu: ผ่าน ${PASS_COUNT} รายการ, ล้มเหลว ${FAIL_COUNT} รายการ"
echo "=================================================================="
[ "$FAIL_COUNT" -eq 0 ]
