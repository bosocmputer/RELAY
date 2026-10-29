# เอกสารกำหนดความต้องการ (SPEC.md) — ระบบ Auto-Relay Loop (Loop Engineering) และ Self-Learning Project Skills (AutoHarness)

## 1. เป้าหมายและแนวคิดหลัก
ยกระดับ `RELAY` ด้วยแนวคิด **Human-Anchored Outer Loop (Loop Engineering)** และ **Self-Learning Skill Distillation (`autoharness`)** โดยให้มนุษย์ยังคงเป็นผู้ควบคุมจุดเริ่มต้น (`@po` สร้าง `SPEC.md`) และจุดสิ้นสุด (`[5] Merge & Archive`) ขณะที่ขั้นตอนตรงกลาง (`@arch ➔ @dev ⇄ @qa`) สามารถรันเป็นวงรอบอัตโนมัติพร้อมระบบเบรกนิรภัย 3 ชั้น และเมื่อจบใบงานจะสกัดบทเรียนสะสมเข้าสู่โปรเจกต์โดยอัตโนมัติ

## 2. ขอบเขตฟีเจอร์ (Scope of Work)
1. **ฟีเจอร์ที่ 1: `Bounded Auto-Relay Loop` (`[a]` / `/loop` / `relay loop`)**
   - ทำงานเฉพาะเมื่อใบงานปัจจุบันมีไฟล์ `.relay/tasks/<task-id>/SPEC.md` ที่มนุษย์อนุมัติแล้ว
   - **ระบบเบรกนิรภัย 3 ชั้น (3-Tier Circuit Breaker):**
     1. **Real-Time Quota Guard:** ตรวจสอบโควต้าคงเหลือ (`5h` และ `7d`) ของค่ายที่รับผิดชอบในแต่ละก้าวก่อนรันเสมอ หากเหลือน้อยกว่า `20%` จะหยุดลูปอย่างปลอดภัยทันทีเพื่อป้องกันโควต้าหมด
     2. **Max Remediation Rounds (สูงสุด 3 รอบ):** จำกัดจำนวนรอบการวนแก้บั๊กระหว่าง `@dev ⇄ @qa` ไม่เกิน `3 รอบ`
     3. **Cross-Provider Independent Verification:** ใช้ `@qa` (เช่น `codex`) ตรวจงานของ `@dev` (เช่น `agy`) ใน `.relay/worktrees/<task-id>` และตัดสินผลด้วย `VERDICT: PASS` หรือ `VERDICT: FAIL` ใน `QA_REPORT.md` พร้อมบันทึกประวัติวงรอบไว้ใน `LOOP_LOG.md`
2. **ฟีเจอร์ที่ 2: `Self-Learning Project Skills & Guardrails` (`[l]` / `/learn` / `relay learn` + Auto-Distill on Merge)**
   - เมื่อกด `[5] Merge & Archive` (หรือสั่ง `[l]` / `/learn` / `relay learn`) ระบบจะสกัดความรู้จาก `SPEC.md`, `ARCH.md`, และ `QA_REPORT.md` ของใบงาน:
     - สร้าง/อัปเดตไฟล์ทักษะเฉพาะโครงการที่ `.relay/skills/project-learned/SKILL.md` (ยุบรวมกฎที่ซ้ำซ้อนอัตโนมัติ ไม่ให้เกิน 25 ข้อ)
     - บันทึกประวัติที่มาของกฎแต่ละข้อแบบ Append-Only ลงใน `.relay/skills/project-learned/LEDGER.md` (ระบุวันที่และรหัสใบงานที่ทำให้เกิดกฎนั้น ตามสถาปัตยกรรม `autoharness`)
     - อัปเดตสรุปข้อควรระวังสะสมลงใน `.relay/PROJECT_STATE.md` เพื่อให้ Agent ทุกค่าย (`agy`, `codex`, `claude`) นำไปใช้ในใบงานถัดไปอัตโนมัติ
     - **กฎความปลอดภัย (Self-Authored Only Guardrail):** ห้ามแก้ไขไฟล์กฎส่วนกลาง `~/.agents/GLOBAL_AGENTS.md` หรือทักษะที่ติดตั้งด้วยมือใน `~/.agents/skills/` โดยเด็ดขาด

## 3. เกณฑ์การตรวจรับงาน (Acceptance Criteria)
- [x] มีเมนู `[a] ⚡ รัน Auto-Relay Loop (ขั้นที่ 2 ➔ 3 ⇄ 4 อัตโนมัติพร้อมเบรกโควต้า)` และคำสั่ง `relay loop`
- [x] มีเมนู `[l] 🧠 สกัดบทเรียนสะสมเข้าโปรเจกต์ (Self-Learning Skills)` และคำสั่ง `relay learn` พร้อมทำงานอัตโนมัติในขั้นตอนที่ 5 (`Merge & Archive`)
- [x] รองรับการทำงานร่วมกับ `agy`, `codex`, และ `claude` ทั้งใน `relay.sh` และ `relay.ps1`
- [x] อัปเดตเอกสารทั้งหมด (`README.md`, `docs/ARCHITECTURE_DEEP_DIVE.md`, `docs/USE_CASES_NEW_AND_EXISTING.md`, `.relay/PROJECT_STATE.md`) และอัปโหลดขึ้น GitHub
