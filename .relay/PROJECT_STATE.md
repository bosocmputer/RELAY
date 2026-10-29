# สถานะปัจจุบันของโครงการ (PROJECT_STATE.md)
*อัปเดตล่าสุด: 2026-10-29 • ความยาวไม่เกิน 2 หน้าเพื่อให้ `@arch` และ `@pm` เข้าใจโครงสร้างล่าสุดของระบบได้ทันทีโดยไม่ต้องอ่านใบงานเก่าทั้งหมด*

## 1. ภาพรวมของโครงการ (`RELAY v1.0 Official Public Edition`)
คลังโค้ดมาตรฐานสาธารณะ (`https://github.com/bosocmputer/RELAY.git` • โฟลเดอร์หลัก `/Users/nontawatwongnuk/dev_bos/RELAY`) สำหรับเผยแพร่สถาปัตยกรรมการทำงานร่วมกับตัวแทน AI หลายค่ายแบบแบ่ง 4 ขั้นตอนผ่านหน้าจอควบคุมกลางใน Terminal (`relay`) และเอกสารส่งมอบงานในโฟลเดอร์ `.relay/` รองรับทั้งระบบปฏิบัติการ **Windows** และ **macOS**

## 2. โครงสร้างโมดูลและไฟล์สำคัญล่าสุด
- **หน้าจอควบคุมกลางแบบนำทาง 3 ขั้นตอนอัตโนมัติ (`relay.sh`, `relay.ps1`, `templates/relay-roles.conf`):**
  - ใช้โทนสี **Minimalist High-Contrast (3-Tier Monochrome Blue)** ที่อ่านคมชัดทั้งบน Terminal พื้นขาว (Light Mode) และพื้นดำ (Dark Mode) พร้อมตัวชี้ `❯` สีน้ำเงินครามตัวหนาทั้งบรรทัดที่ไม่ตัดสระภาษาไทย
  - **รองรับโควต้า Google AI Ultra ผ่าน Antigravity CLI (`agy` / `~/.gemini/bin/agy`) เป็นค่ายหลัก (First-Class Provider):**
    - แก้ข้อจำกัดที่ Google ยกเลิกการ Login ด้วยบัญชี Google ส่วนบุคคลบน `@google/gemini-cli` รุ่นเก่า โดยเชื่อมกับ `agy` (Antigravity CLI) ที่ใช้โควต้า **Google AI Ultra** ได้โดยตรง
    - ดึงรายชื่อโมเดลสดจาก `agy models` ครบทั้งโควต้า **Gemini Models** (`gemini-4-argon-high/medium/low`, `gemini-3.8-flash-high/medium/low`) และโควต้า **Claude & GPT Models** (`claude-opus-5-5-high/medium/low`, `claude-sonnet-5-5-high/medium/low`, `gpt-oss-120b-medium`)
  - **ตรวจสอบความพร้อมจริง 3 ชั้น (3-Layer CLI Readiness Verification):**
    1. ตรวจการติดตั้ง CLI (`agy`, `claude`, `codex`, `gemini`)
    2. ตรวจสถานะการเข้าสู่ระบบจริง (`~/.gemini/jetski-standalone-oauth-token` สำหรับ `agy`, `claude auth status`, `codex login status`, และ `GEMINI_API_KEY` สำหรับ `gemini`) ก่อนแสดงสถานะ `● พร้อมใช้งาน (Google AI Ultra)` หรือ `● พร้อมใช้งาน (Login แล้ว)`
    3. ดึงรายชื่อ Model จาก CLI ในเครื่องโดยตรง (`agy models`, `~/.codex/models_cache.json`, `@google/gemini-cli`, และไบนารี `claude`)
  - **ระบบนำทางทีละขั้น (Guided 3-Stage Progressive Disclosure UX):**
    1. **ขั้นที่ 1 (`ตั้งค่า & Login AI ให้ครบ 4 ตำแหน่ง`):** ซ่อนเมนูใบงานที่ยังไม่ถึงคิวทั้งหมด ชี้เป้าปุ่ม Quick Setup หรือปุ่ม Login บัญชีค่ายที่ยังไม่ได้ยืนยันตัวตนอัตโนมัติ
    2. **ขั้นที่ 2 (`เตรียมโฟลเดอร์โปรเจกต์`):** ตรวจจับหากผู้ใช้เผลอรัน `relay` ในโฟลเดอร์ `$HOME` (`~`) พร้อมตัวช่วยเลือก/สร้างโฟลเดอร์โปรเจกต์ใหม่ในคลิกเดียว และเมนูสร้าง `.relay/PROJECT_STATE.md` (Greenfield / Brownfield)
    3. **ขั้นที่ 3 (`เริ่มสั่งงานตามใบงาน 1-5`):** ตรวจจับไฟล์ในใบงานปัจจุบัน (`SPEC.md`, `PLAN.md`, `Worktree`, `QA_REPORT.md`) เพื่อเลื่อนตัวชี้ `❯` และป้าย `★ [ขั้นตอนถัดไป]` ไปยังขั้นตอนที่ต้องทำต่อให้อัตโนมัติ
  - มีเมนู `[t]` (`relay test`) สำหรับตรวจสอบทักษะประจำตำแหน่งและยิงทดสอบ Live Handshake (`agy --model <m> -p`, `codex exec --skip-git-repo-check`, `claude -p`) รวมถึงเมนู `[d]` (`relay doctor`) สำหรับ Login และติดตั้ง CLI
- **สคริปต์ติดตั้งส่วนกลางและสร้างโครงสร้างโครงการ (`setup-mac.sh`, `setup-win.ps1`, `relay-init.sh`, `relay-init.ps1`):**
  - ติดตั้ง `~/.agents/GLOBAL_AGENTS.md`, `~/.agents/bin/relay`, `~/.agents/bin/relay-init`, `~/.agents/bin/relay-skills`, เชื่อม Symlink `~/.agents/bin/agy -> ~/.gemini/bin/agy` อัตโนมัติ และเปิดใช้งาน Global Git `pre-commit` Hook
- **ระบบจัดการและอัปเดตทักษะ (`relay-skills.sh`, `relay-skills.ps1` และ `skills-manifest.txt`):**
  - รองรับคำสั่ง `install`, `update`, `add <repo>` และ `list`
- **เอกสารคู่มือมาตรฐาน (`README.md`, `docs/` และ `domains/`):**
  - ครอบคลุมการติดตั้งตั้งแต่ศูนย์ การเชื่อมต่อโปรแกรม **Obsidian** การใช้งานทั้งในโครงการใหม่ (Greenfield) และโครงการเดิม (Brownfield) รวมถึงแม่แบบสำหรับสายงานผลิตภาพยนตร์/วิดีโอ และสายงานบริหารธุรกิจ/บัญชี
