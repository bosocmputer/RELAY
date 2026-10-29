# เอกสารกำหนดความต้องการ (SPEC.md)
**รหัสใบงาน:** `20261029-cli-auth-and-live-models`
**วันที่:** 2026-10-29
**สถานะ:** ยืนยันโดยผู้ใช้แล้ว (Confirmed)

## 1. ที่มาและปัญหาที่พบ (Problem Statement)
จากการทดสอบเมนู `[t] ทดสอบความพร้อม Agent ทั้ง 4 ตำแหน่ง` ของผู้ใช้ พบปัญหาสำคัญ 3 ประการ:
1. **แสดงสถานะ `● พร้อมใช้งาน` ทั้งที่ยังไม่ได้ Login บัญชี CLI:**
   - เดิมระบบตรวจเฉพาะว่ามีคำสั่ง CLI ในเครื่อง (`command -v`) และเลือกชื่อโมเดลแล้วหรือยัง แต่ไม่ได้ตรวจว่าเข้าสู่ระบบ (Login) หรือยัง ทำให้เมื่อกดทดสอบจริง `gemini` และ `claude` จึงฟ้องว่ายังไม่ได้ Login
2. **รายชื่อ Model เดิมเป็นค่าที่เขียนตายตัว (Hardcoded) ไม่ได้ดึงจาก CLI ในเครื่องโดยตรง:**
   - ตัวอย่างเช่น `codex` ของผู้ใช้มีการตั้งค่าและแคชโมเดลจริงไว้ที่ `~/.codex/config.toml` (`gpt-6.1-terra`) และ `~/.codex/models_cache.json` (`gpt-6.1-sol`, `gpt-6-astra`, `gpt-6.1-terra`, ฯลฯ) แต่ชุดตั้งค่าด่วนเดิมไปกำหนดเป็น `o3` ที่ไม่มีในแคชของผู้ใช้
3. **คำสั่งทดสอบ `codex` และข้อความเตือนของ `claude`:**
   - การรัน `codex exec` นอกโฟลเดอร์ Git (เช่นใน `~`) ต้องใช้ `--skip-git-repo-check` และไม่ควรมี fallback แฟล็ก `-q` ที่เลิกใช้แล้ว
   - การรัน `claude -p` แสดงข้อความเตือน `Permission allow rule (.claude/settings.json)` ยาว 26 บรรทัดจากกฎเก่าของโปรเจกต์อื่น ทำให้รกหน้าจอ

## 2. ขอบเขตการพัฒนา (Scope of Work)
1. **ระบบตรวจสอบสถานะการ Login จริงของทั้ง 3 ค่าย (`is_provider_logged_in`):**
   - `claude`: ตรวจจาก `claude auth status` (`"loggedIn": true`) หรือตัวแปร `ANTHROPIC_API_KEY`
   - `codex`: ตรวจจาก `codex login status` (`Logged in`) หรือไฟล์ `~/.codex/auth.json` หรือ `OPENAI_API_KEY`
   - `gemini`: ตรวจจากค่า `selectedType` ใน `~/.gemini/settings.json` หรือไฟล์ `~/.gemini/oauth_creds.json` หรือ `GEMINI_API_KEY`
   - เงื่อนไข `is_role_ready` ต้องครบทั้ง 3 ข้อ: **ติดตั้ง CLI แล้ว + Login บัญชีแล้ว + เลือก Model แล้ว** จึงจะแสดง `● พร้อมใช้งาน`
2. **ระบบดึงรายชื่อ Model จาก CLI ในเครื่องโดยตรง (`get_cli_live_models`):**
   - `codex`: ดึงรายการโมเดลจริงจาก `~/.codex/models_cache.json` (`visibility: "list"`) ร่วมกับค่าเริ่มต้นใน `~/.codex/config.toml`
   - `gemini`: ดึงรายการโมเดลจริงจากชุดติดตั้ง `@google/gemini-cli` ในเครื่อง ร่วมกับ `~/.gemini/settings.json`
   - `claude`: ดึงรายการโมเดลจริงจากไบนารี `claude` ที่ติดตั้งในเครื่อง ร่วมกับ `~/.claude/settings.json`
   - ปรับ `Quick Setup` ให้ใช้โมเดลเริ่มต้นจริงจาก CLI ของเครื่อง (เช่น `gpt-6.1-terra` สำหรับ `codex`) และชี้เป้าค่ายที่ Login พร้อมใช้งานแล้ว
3. **ปรับปรุงคำสั่งทดสอบ Live Handshake (`[t]`) และเมนู Login (`[d]` / `[3]`):**
   - บล็อกการยิงทดสอบทันทีหากค่ายนั้นยังไม่ได้ Login พร้อมพาไปหน้า Login ได้ในคลิกเดียว
   - ใช้ `codex exec --skip-git-repo-check -m "<model>" "<prompt>"` สำหรับ Codex CLI
   - กรองข้อความเตือน `Permission allow rule (.claude/settings.json)` ของ Claude CLI ไม่ให้รกหน้าจอ
   - ใช้คำสั่ง `claude auth login` และ `codex login` เพื่อเปิดหน้ายืนยันตัวตนโดยตรง

## 3. เกณฑ์การตรวจรับงาน (Acceptance Criteria)
- [x] AC1: หน้าตาราง Roles และแถว `CLIs ในเครื่อง` แสดงสถานะแยกชัดเจนระหว่าง `✖ ยังไม่ติดตั้ง CLI`, `▲ ยังไม่ Login (กด [3])`, `▲ รอเลือกโมเดล` และ `● พร้อมใช้งาน`
- [x] AC2: เมนูเลือก Model ของทั้ง 3 ค่ายดึงรายชื่อโมเดลจริงจาก CLI ในเครื่อง พร้อมป้ายระบุ `(ดึงจาก CLI โดยตรง)`
- [x] AC3: การทดสอบ `codex` ด้วยโมเดลจริง (`gpt-6.1-terra`) ทำงานผ่าน `codex exec --skip-git-repo-check` ได้โดยไม่ติดข้อผิดพลาด `-q` และไม่มีข้อความเตือนรกตาจาก `.claude/settings.json`
