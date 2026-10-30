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
    - บันทึกสถานะการดึงต่อค่าย (`*_FETCH_OK`, `*_FETCHED_AT`) — ค่ายที่ดึงไม่ได้แสดง `? NN% ดึงไม่ได้ • ค่าเมื่อ HH:MM`
    - แสดงผลในตารางโควต้าบนแดชบอร์ดหลัก (`relay status`) และหน้าหลอดโควต้าละเอียด (`relay quota` หรือกด `[u]` / `/quota`) พร้อมแจ้งเตือนเมื่อค่ายใดเหลือโควต้าต่ำกว่า `20%`
    - แสดงผลเป็นตารางโควต้า 3 คอลัมน์ (ค่าย / 5 ชั่วโมง / รายสัปดาห์) พร้อม **นับถอยหลังเวลารีเซ็ต** (แคชเก็บ `*_RESET_EPOCH` และคำนวณตอนวาดหน้าจอ), แสดง `↻ รีเซ็ตแล้ว` และนับเป็น 100% เมื่อเลยเวลารีเซ็ต, บอกอายุข้อมูลและเตือนเมื่อเก่ากว่า 15 นาที; คอลัมน์สถานะตำแหน่งแสดงแค่ `● พร้อมใช้` / `▲ โควต้าต่ำ X%`
  - **ระบบรันลูปอัตโนมัติแบบมีเบรกนิรภัย (`Bounded Auto-Relay Loop` — `[a]` / `/loop` / `relay loop`):**
    - ให้มนุษย์ควบคุมขั้นตอนที่ 1 (`@po` สร้าง `SPEC.md`) และขั้นตอนที่ 5 (`Merge & Archive`) ขณะที่ขั้นตอน `2 (@arch) ➔ 3 (@dev ใน Worktree) ⇄ 4 (@qa ต่างค่าย)` รันอัตโนมัติภายใต้เบรก 4 ชั้น:
      1. **Quota Circuit Breaker (`check_role_quota_safe`):** หยุดหากโควต้า `5h` หรือ `7d` ของตำแหน่งถัดไปต่ำกว่า `20%`
      2. **Max Remediation Cap (`3 รอบ`):** บันทึก `LOOP_LOG.md` และเก็บรายงานเก่าเป็น `QA_REPORT.before-round-N.md`
      3. **Cross-Provider QA Verifier:** ตัดสินจาก `QA_VERDICT.json` ก่อน (`qa_verdict`; PASS ต้องไม่มี `failed_criteria`, JSON เสีย = ไม่ผ่าน) และใช้ `VERDICT:` ใน `QA_REPORT.md` เป็นทางสำรอง
      4. **Step Guard:** หยุดเมื่อ agent error / ไม่สร้างไฟล์ผลลัพธ์ / เกินเพดานเวลา (`run_with_timeout`, `RELAY_STEP_TIMEOUT` ค่าเริ่มต้น 1800 วินาที)
    - โหมดสิทธิ์: `agy --mode auto`, `claude --permission-mode acceptEdits`, `codex exec --full-auto`
  - **Git Worktree และขั้นตอนที่ 5 ที่ไม่ทำให้โค้ดหาย:**
    - `prepare_task_worktree` ใช้ร่วมกันในขั้นตอนที่ 3 และ Auto-Loop: หยุดพร้อม error จริงถ้าสร้างไม่ได้, เพิ่ม `.relay/worktrees/` ใน `.gitignore`; Prompt ของ `@dev` สั่งให้ commit ในกิ่ง `feat/<task>`
    - `run_phase_5_merge`: ตรวจ commit/ไฟล์ค้าง/ผล QA ➔ commit อัตโนมัติ (ไม่รวม `.relay/`) ➔ ยืนยันเพิ่มถ้า QA ยังไม่ผ่าน ➔ `merge --no-ff` ➔ `merge --abort` เมื่อล้มเหลว ➔ `record_task_in_project_state` ➔ ลบ Worktree/กิ่งและ archive เฉพาะหลังสำเร็จ
    - `PROJECT_STATE.md` ของกิ่งหลักถูกแก้เฉพาะหลังผสาน (`@qa` ห้ามแก้, ไม่คัดลอกกลับจาก Worktree); `sync_task_docs_from_worktree` ไม่ทับ `LOOP_LOG.md` / `RUN_LOG.jsonl`
    - ทุกการเรียก agent บันทึกลง `.relay/tasks/<task>/RUN_LOG.jsonl` (`append_run_log`) และสรุปท้าย Auto-Loop
  - **Windows (`relay.ps1`):** แดชบอร์ด/ตั้งค่า/โควต้าใช้ได้ แต่ `[a]` และ `[l]` ยังเป็นโครงเท่านั้น (งานค้าง C5)
  - **ระบบสกัดบทเรียนและสร้างทักษะเฉพาะโปรเจกต์อัตโนมัติ (`Self-Learning Project Skills` — `[l]` / `/learn` / `relay learn`):**
    - สกัดกฎที่เสนอแบบจับคำสำคัญ (ยังไม่ใช้ AI สรุป — งานค้าง M2) ลงคิว `PENDING.md` ➔ ผู้ใช้อนุมัติใน `[l]` (`apply_learned_approval`) ➔ ย้ายเข้า `SKILL.md` (ไม่เกิน 25 ข้อ) ➔ บันทึก `LEDGER.md`
    - Prompt ของ `@arch`, `@dev`, `@qa` แนบเฉพาะ `SKILL.md` (กฎที่อนุมัติแล้ว) โดยไม่แตะต้อง `~/.agents/GLOBAL_AGENTS.md`
  - **ตรวจสอบความพร้อมจริง 3 ชั้น (3-Layer CLI Readiness Verification):**
    1. ตรวจการติดตั้ง CLI (`agy`, `claude`, `codex`)
    2. ตรวจสถานะการเข้าสู่ระบบจริง (`~/.gemini/jetski-standalone-oauth-token` สำหรับ `agy`, `claude auth status`, และ `codex login status`)
    3. ดึงรายชื่อ Model จาก CLI ในเครื่องโดยตรง
  - **ระบบนำทางทีละขั้น (Guided 3-Stage Progressive Disclosure UX):**
    1. **ขั้นที่ 1 (`ตั้งค่า & Login AI ให้ครบ 4 ตำแหน่ง`)**
    2. **ขั้นที่ 2 (`เตรียมโฟลเดอร์โปรเจกต์`)**
    3. **ขั้นที่ 3 (`เริ่มสั่งงานตามใบงาน 1-5`)**
- **สคริปต์ติดตั้งส่วนกลางและสร้างโครงสร้างโครงการ (`setup-mac.sh`, `setup-win.ps1`, `relay-init.sh`, `relay-init.ps1`):**
  - ติดตั้ง `~/.agents/GLOBAL_AGENTS.md`, `~/.agents/bin/relay`, `~/.agents/bin/relay-init`, `~/.agents/bin/relay-skills`, เชื่อม Symlink `~/.agents/bin/agy -> ~/.gemini/bin/agy` อัตโนมัติ และเปิดใช้งาน Global Git `pre-commit` Hook
- **ระบบจัดการและอัปเดตทักษะ (`relay-skills.sh`, `relay-skills.ps1` และ `skills-manifest.txt`):**
  - รองรับคำสั่ง `install`, `update`, `add <repo>` และ `list`
- **ชุดทดสอบที่ไม่ใช้โควต้า (`tests/`):** `test_phase5_merge.sh`, `test_auto_loop.sh` (CLI จำลอง), `test_quota_display.sh`
- **เอกสารคู่มือมาตรฐาน (`README.md`, `docs/` และ `domains/`):**
  - ครอบคลุมการติดตั้งตั้งแต่ศูนย์ การใช้งานทั้งในโครงการใหม่ (Greenfield) และโครงการเดิม (Brownfield), ชี้แจงชัดเจนว่าโฟลเดอร์ `.relay/` คือกลไกหลักโดย **Obsidian เป็นเพียงทางเลือกเสริม (Optional Viewer)**, ทุกบทบาทสลับค่าย/โมเดล AI ได้อิสระผ่านปุ่ม `[c]`, รวมถึงแม่แบบสำหรับสายงานผลิตภาพยนตร์/วิดีโอ และสายงานบริหารธุรกิจ/บัญชี
