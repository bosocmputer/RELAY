# เอกสารกำหนดความต้องการ (SPEC.md)
- **รหัสใบงาน:** `20261030-token-telemetry-and-fast-track`
- **ชื่อใบงาน:** ระบบวัดผล Token จริง + เวลา + โควต้ารายขั้นตอน/รายโมเดล, โหมดด่วน Fast Track ลด Ceremony Overhead, และการปรับคำอธิบายให้ตรงข้อเท็จจริงทางเทคนิค
- **สถานะ:** ยืนยันแล้วโดยผู้ใช้ ("โอเคร ตกลง ทำทั้งหมดได้เลย")

## 1. เป้าหมายและขอบเขตงาน (Goals & Scope)
1. **ระบบดึงและแสดงผล Token จริงจาก Session Logs ของทั้ง 3 ค่าย (`agy`, `codex`, `claude`) รายขั้นตอนและรายโมเดล:**
   - ดึงตัวเลข Token จริง (`input_tokens`, `cached_tokens`, `output_tokens`, `total_tokens`, และจำนวน `turns`) จากไฟล์บันทึกของแต่ละ CLI ที่อัปเดตในช่วงเวลาทำงานของขั้นตอนนั้น (`start_epoch` ถึง `end_epoch`):
     - `agy`: `~/.gemini/antigravity-cli/brain/*/.system_generated/logs/transcript.jsonl`
     - `codex`: `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` (คำนวณส่วนต่างจาก `total_token_usage` เพื่อไม่ให้นับซ้ำ)
     - `claude`: `~/.claude/projects/*/*.jsonl` (กรองซ้ำด้วย `requestId` / `message.id`)
   - บันทึกข้อมูล Token ลงใน `.relay/tasks/<task-id>/RUN_LOG.jsonl` ทุกครั้งที่จบการรัน Agent (ทั้งแบบกดทีละขั้น `1`–`4`, โหมดด่วน `[x] Fast Track`, และ `[a] Auto-Relay Loop`)
   - **แสดงกล่องสรุปผลทันทีหลังจบทุกขั้นตอน (Live Step Scorecard):** แสดงเวลาที่ใช้, จำนวน Token จริง (`Total / In / Cache / Out`), และโควต้าก่อน➔หลัง
   - **แสดงยอดสะสมบน Dashboard หลัก + เมนู `[v]` (`relay stats` / `/stats`) และในหน้า `[5] Merge`:**
     - บรรทัด `ใบงาน` บน Dashboard แสดงยอดสะสมของใบงานปัจจุบัน (เวลารวม + Token รวม)
     - กด `[v]` (`relay stats`) หรือดูในหน้า `[5] Merge` จะแสดงตารางแยกตามขั้นตอน (`@po`, `@arch`, `@dev`, `@qa`, `Fast Track`) และสรุปแยกตามค่าย/โมเดล เพื่อให้ผู้ใช้ประเมินความคุ้มค่าด้วยตัวเองได้ทันที
2. **ลด Ceremony Overhead สำหรับงานเล็กและควบคุมความกระชับของเอกสาร:**
   - เพิ่มเมนู **`[x] ⚡ โหมดด่วน Fast Track (ข้าม @po/@arch ➔ ส่ง @dev ทำใน Worktree ทันที)`** (`relay fast` หรือ `/fast`) สำหรับงานเล็กหรือการแก้บั๊กที่ไม่ต้องการพิธีกรรมเอกสาร 4 ขั้นตอน
   - กำหนดเพดานความยาวเอกสารใน Prompt ของแต่ละบทบาท (`SPEC.md` ไม่เกิน 40 บรรทัด, `ARCH.md` & `PLAN.md` ไม่เกิน 60 บรรทัด, `QA_REPORT.md` ไม่เกิน 30 บรรทัด) เพื่อลด Output Tokens และเวลาทำงาน
   - ปรับ Prompt ของ `@qa` ให้เรียกใช้ Playwright MCP เฉพาะเมื่อใบงานมีการแก้ไขส่วนติดต่อผู้ใช้ (Web UI) จริงเท่านั้น
3. **ปรับคำอธิบายเรื่อง `"0 Token"` ในเอกสารและกฎส่วนกลางให้ตรงความจริง 100% (No Over-claiming):**
   - แก้ไข `README.md`, `docs/*`, และ `templates/GLOBAL_AGENTS.md` ให้แยกชัดเจนระหว่างสคริปต์ระบบที่ไม่เรียก AI (`pre-commit hook`, การตรวจ Git Merge = ไม่เสียโควตา AI) กับการสั่งให้ `@qa` รันเทสต์/Playwright MCP (ใช้โควต้าแพ็กเกจรายเดือนตามความยาว Output)

## 2. เกณฑ์การตรวจรับงาน (Acceptance Criteria)
- [x] **AC-1:** `extract_step_token_usage` ดึงตัวเลข Token (`input_tokens`, `cached_tokens`, `output_tokens`, `total_tokens`, `turns`) ได้ถูกต้องทั้ง 3 ค่าย (`agy`, `codex`, `claude`) โดยไม่นับซ้ำ และบันทึกลง `RUN_LOG.jsonl`
- [x] **AC-2:** หลังจบทุกขั้นตอน แสดงกล่องสรุปเวลา + Token + โควต้าทันที, บน Dashboard แสดงยอดสะสมของใบงาน, และคำสั่ง `relay stats` (ปุ่ม `[v]`) แสดงตารางวิเคราะห์รายขั้นตอนและรายโมเดล
- [x] **AC-3:** มีโหมดด่วน `[x] Fast Track` (`relay fast`) ที่สร้างใบงาน + Worktree และส่ง `@dev` ทำงานได้ทันทีโดยไม่ต้องผ่าน `@po` และ `@arch` พร้อมเพดานความยาวเอกสารใน Prompt ทุกบทบาท
- [x] **AC-4:** เอกสาร `README.md`, `docs/*`, `templates/GLOBAL_AGENTS.md` ไม่มีคำเคลม `"0 Token"` ที่คลาดเคลื่อน และชุดทดสอบอัตโนมัติทั้งหมดผ่าน 100%
