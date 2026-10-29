# เอกสารการออกแบบสถาปัตยกรรม (ARCH.md) — ระบบ Auto-Relay Loop และ Self-Learning Project Skills

## 1. สถาปัตยกรรม `Bounded Auto-Relay Loop` (`run_auto_relay_loop`)
1. **การตรวจสอบเงื่อนไขเริ่มต้น (Pre-flight & Quota Guard):**
   - ต้องผ่าน `require_all_roles_ready` และมีไฟล์ `.relay/tasks/$ACTIVE_TASK/SPEC.md`
   - ฟังก์ชัน `check_role_quota_safe "$provider" "$model" "$min_pct"`:
     - อ่านค่าโควต้า `5h` และ `7d` จาก `get_role_quota_pair`
     - หากค่าใดเป็นตัวเลขและต่ำกว่า `$min_pct` (ค่าเริ่มต้น `20%`) จะคืนค่า `1` และหยุดลูปทันทีพร้อมแสดงคำเตือนให้สลับค่ายใน `[c]`
2. **ฟังก์ชันรัน Agent แบบอัตโนมัติในลูป (`exec_provider_autonomous`):**
   - รันในโฟลเดอร์เป้าหมาย (`$PROJECT_DIR` สำหรับ `@arch`, และ `.relay/worktrees/$ACTIVE_TASK` สำหรับ `@dev` / `@qa`):
     - `agy`: `agy --model "$model" -p "$prompt"`
     - `codex`: `codex exec --full-auto -m "$model" "$prompt"`
     - `claude`: `claude --model "$model" --dangerously-skip-permissions -p "$prompt"` (จำกัดเฉพาะใน Git Worktree / โฟลเดอร์งาน)
     - `gemini`: `gemini -m "$model" -y -p "$prompt"`
   - หลังจบแต่ละคำสั่งในลูป จะเรียก `refresh_quota_cache --quiet` เพื่ออัปเดตโควต้าคงเหลือตามจริง
3. **วงจรการเดินงานและตรวจซ้ำ (`@arch ➔ @dev ⇄ @qa`):**
   - **Step A (`@arch & @pm`):** หากยังไม่มี `PLAN.md` จะสั่ง `@arch` สร้าง `ARCH.md` และ `PLAN.md`
   - **Step B (`@dev` รอบที่ `1..MAX_ROUNDS`):**
     - สร้างและซิงก์ `.relay/worktrees/$ACTIVE_TASK` (กิ่ง `feat/$ACTIVE_TASK`)
     - รอบที่ 1: สั่ง `@dev` พัฒนาโค้ดและชุดทดสอบตาม `SPEC.md`, `ARCH.md`, `PLAN.md`
     - รอบที่ 2..3 (เมื่อ `@qa` แจ้ง `FAIL`): ส่งรายละเอียดข้อผิดพลาดจาก `QA_REPORT.md` กลับไปให้ `@dev` แก้ไขเฉพาะจุด
   - **Step C (`@qa & @sec` รอบที่ `1..MAX_ROUNDS`):**
     - สั่ง `@qa` รันชุดทดสอบจริง ตรวจสอบความปลอดภัยของ `git diff` และเขียน `QA_REPORT.md` โดยบังคับให้ระบุบรรทัดสรุป `VERDICT: PASS` หรือ `VERDICT: FAIL`
     - ซิงก์ `QA_REPORT.md` กลับมาที่ `.relay/tasks/$ACTIVE_TASK/QA_REPORT.md` และบันทึกประวัติลง `LOOP_LOG.md`
     - หากพบ `VERDICT: PASS` (หรือไม่พบ `FAIL` / `❌`) ลูปจะจบด้วยสถานะสำเร็จ (`LAST_COMPLETED_PHASE=4`) และชี้เป้าไปยังข้อ `[5] Merge & Archive`

## 2. สถาปัตยกรรม `Self-Learning Project Skills` (`distill_project_learned_skills`)
1. **โครงสร้างไฟล์ความรู้เฉพาะโปรเจกต์ (ตามแนวคิด `autoharness` แต่รองรับทุกค่าย):**
   - `.relay/skills/project-learned/SKILL.md`: เก็บกฎ สถาปัตยกรรม รูปแบบโค้ด และข้อควรระวังที่ได้เรียนรู้จริงจากใบงานในโปรเจกต์นี้ (จำกัดไม่เกิน 25 ข้อ มีการยุบรวมข้อซ้ำอัตโนมัติ)
   - `.relay/skills/project-learned/LEDGER.md`: บันทึก Audit Trail แบบ Append-Only ว่าใบงานใด (`<task-id>`) และวันที่เท่าไรที่สกัดความรู้นั้นออกมา
   - `.relay/PROJECT_STATE.md`: อัปเดตหมวด `## บทเรียนและข้อควรระวังสะสมของโครงการ (Learned Guardrails)` เพื่อให้ทุกตำแหน่งอ่านเจอทันทีโดยไม่ต้องโหลดไฟล์เพิ่ม
2. **การเรียกใช้โมเดลสกัดความรู้ (Reflector Engine):**
   - เลือกใช้โมเดลที่ประหยัดโควต้าและรวดเร็วที่สุดที่มีในเครื่อง (ลำดับแรก: `agy` โมเดล `gemini-3.8-flash-high` หากพร้อมใช้งาน มิฉะนั้นใช้ค่ายของ `@po`)
   - ส่งเนื้อหา `SPEC.md`, `ARCH.md`, `QA_REPORT.md` ของใบงาน ร่วมกับ `SKILL.md` เดิม เพื่อสังเคราะห์กฎที่ควรจดจำและตัดข้อมูลที่ซ้ำซ้อนออก
3. **การเชื่อมต่อเข้ากับ Prompt ของทุกตำแหน่ง:**
   - หากในโปรเจกต์มีไฟล์ `.relay/skills/project-learned/SKILL.md` ระบบ `relay` จะแนบคำสั่งให้อ่านไฟล์ดังกล่าวใน Prompt ของ `@arch`, `@dev`, และ `@qa` โดยอัตโนมัติ
