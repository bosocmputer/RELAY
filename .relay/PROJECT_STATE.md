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
  - **ระบบแสดงโควต้าคงเหลือแบบเรียลไทม์ของทุกค่าย (Real-Time Multi-Provider Quota Engine):**
    - ดึงเปอร์เซ็นต์โควต้าคงเหลือจริงทั้งรอบ **5 ชั่วโมง (5-Hour)** และ **รายสัปดาห์ (Weekly 7-Day)** พร้อมเวลาที่รีเซ็ตของทั้ง 4 กระเป๋าโควต้าหลัก:
      1. **`agy` (Gemini Models):** ดึงผ่าน `agy -p "/usage"`
      2. **`agy` (Claude & GPT Models):** ดึงผ่าน `agy -p "/usage"`
      3. **`codex` (OpenAI Codex CLI):** อ่านสดจาก `rate_limits` ใน `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`
      4. **`claude` (Anthropic Claude Code CLI):** ดึงผ่าน Control Protocol `get_usage` ของ `claude -p --input-format stream-json`
    - แสดงผลโควต้าคงเหลือทั้งในคอลัมน์สถานะของแต่ละตำแหน่ง (`@po`, `@arch`, `@dev`, `@qa`), ในส่วนสรุปบนหน้าแดชบอร์ดหลัก (`relay status`), และในหน้าจอหลอดโควต้าละเอียด (`relay quota` หรือกด `[u]` / `/quota`) พร้อมแจ้งเตือนอัตโนมัติหากค่ายใดเหลือโควต้าต่ำกว่า `20%`
  - **ตรวจสอบความพร้อมจริง 3 ชั้น (3-Layer CLI Readiness Verification):**
    1. ตรวจการติดตั้ง CLI (`agy`, `claude`, `codex`, `gemini`)
    2. ตรวจสถานะการเข้าสู่ระบบจริง (`~/.gemini/jetski-standalone-oauth-token` สำหรับ `agy`, `claude auth status`, `codex login status`, และ `GEMINI_API_KEY` สำหรับ `gemini`)
    3. ดึงรายชื่อ Model จาก CLI ในเครื่องโดยตรง
  - **ระบบนำทางทีละขั้น (Guided 3-Stage Progressive Disclosure UX):**
    1. **ขั้นที่ 1 (`ตั้งค่า & Login AI ให้ครบ 4 ตำแหน่ง`)**
    2. **ขั้นที่ 2 (`เตรียมโฟลเดอร์โปรเจกต์`)**
    3. **ขั้นที่ 3 (`เริ่มสั่งงานตามใบงาน 1-5`)**
- **สคริปต์ติดตั้งส่วนกลางและสร้างโครงสร้างโครงการ (`setup-mac.sh`, `setup-win.ps1`, `relay-init.sh`, `relay-init.ps1`):**
  - ติดตั้ง `~/.agents/GLOBAL_AGENTS.md`, `~/.agents/bin/relay`, `~/.agents/bin/relay-init`, `~/.agents/bin/relay-skills`, เชื่อม Symlink `~/.agents/bin/agy -> ~/.gemini/bin/agy` อัตโนมัติ และเปิดใช้งาน Global Git `pre-commit` Hook
- **ระบบจัดการและอัปเดตทักษะ (`relay-skills.sh`, `relay-skills.ps1` และ `skills-manifest.txt`):**
  - รองรับคำสั่ง `install`, `update`, `add <repo>` และ `list`
- **เอกสารคู่มือมาตรฐาน (`README.md`, `docs/` และ `domains/`):**
  - ครอบคลุมการติดตั้งตั้งแต่ศูนย์ การเชื่อมต่อโปรแกรม **Obsidian** การใช้งานทั้งในโครงการใหม่ (Greenfield) และโครงการเดิม (Brownfield) รวมถึงแม่แบบสำหรับสายงานผลิตภาพยนตร์/วิดีโอ และสายงานบริหารธุรกิจ/บัญชี
