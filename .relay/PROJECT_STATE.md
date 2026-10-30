# สถานะปัจจุบันของโครงการ (PROJECT_STATE.md)
*อัปเดตล่าสุด: 2026-10-30 • ความยาวไม่เกิน 2 หน้าเพื่อให้ `@arch` และ `@pm` เข้าใจโครงสร้างล่าสุดของระบบได้ทันทีโดยไม่ต้องอ่านใบงานเก่าทั้งหมด*

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
    - **ระบบวัดผล Token จริง + เวลา + โควต้ารายขั้นตอนและรายโมเดล (`extract_step_token_usage`, `print_step_telemetry_box`, `[v]` / `relay stats`):**
      - ดึงจำนวน Token จริง (`total`, `input`, `cached`, `output`, `turns`) จากไฟล์ Session Log ของทั้ง 3 ค่าย (`agy`, `codex`, `claude`) โดยไม่นับซ้ำ บันทึกลง `.relay/tasks/<task>/RUN_LOG.jsonl` และแสดงกล่องสรุปทันทีหลังจบทุกขั้นตอน พร้อมแถบยอดสะสมบน Dashboard หลักและตารางเปรียบเทียบรายขั้นตอน/รายโมเดลใน `relay stats` (`[v]`)
    - **โหมดด่วน `Fast Track` (`[x]` / `relay fast`) และเพดานความยาวเอกสาร:**
      - สำหรับงานเล็กหรือแก้บั๊ก กด `[x]` เพื่อสร้างใบงาน + Worktree และส่ง `@dev` ทำงานได้ทันทีโดยไม่ต้องผ่าน `@po` และ `@arch` พร้อมกำหนดเพดานความยาวเอกสาร (`SPEC.md` ≤40 บรรทัด, `ARCH.md`+`PLAN.md` ≤60 บรรทัด, `QA_REPORT.md` ≤30 บรรทัด)
- **ชุดทดสอบที่ไม่ใช้โควต้า (`tests/`):** `test_token_telemetry.sh`, `test_phase5_merge.sh`, `test_auto_loop.sh` (CLI จำลอง), `test_quota_display.sh` (รวม 60/60 ข้อ)
- **เอกสารคู่มือมาตรฐาน (`README.md`, `docs/` และ `domains/`):**
  - ครอบคลุมการติดตั้งตั้งแต่ศูนย์ การใช้งานทั้งในโครงการใหม่ (Greenfield) และโครงการเดิม (Brownfield), ชี้แจงชัดเจนว่าโฟลเดอร์ `.relay/` คือกลไกหลักโดย **Obsidian เป็นเพียงทางเลือกเสริม (Optional Viewer)**, ทุกบทบาทสลับค่าย/โมเดล AI ได้อิสระผ่านปุ่ม `[c]`, ตัดคำกล่าวอ้างเกินจริง (`100%`, `คุ้มค่าสูงสุด`, `0 Token` ในขั้นตอนที่รัน AI) ออกทั้งหมด, อธิบายข้อจำกัดเรื่อง **Ceremony Overhead** คู่กับโหมด `[x] Fast Track` และระบบวัด Token จริง (`[v]` / `relay stats`), รวมถึงแม่แบบสำหรับสายงานผลิตภาพยนตร์/วิดีโอ และสายงานบริหารธุรกิจ/บัญชี
