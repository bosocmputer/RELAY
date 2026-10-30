# ใบกำหนดความต้องการ (SPEC.md — 20261030-progressive-skills-and-script-tools)

## 1. เป้าหมายและขอบเขตของงาน (Goal & Scope)
อัปเกรดระบบ Skills ของ RELAY ตามแนวคิด **Anthropic (Progressive Disclosure + Scripts as Tools)** ผสานกับ **Hermes (Evidence-Based Skill Distillation)** โดยไม่เพิ่มความซับซ้อน (ไม่ทำ Soul, Cron หรือ Chat Memory ข้ามวัน):
1. **Progressive Disclosure Skill Index (`build_skill_index_tsv`, `get_role_progressive_skills_note`):**
   - สแกนเฉพาะ Metadata (`name`, `description` ย่อจาก YAML Frontmatter, พาธไฟล์ `SKILL.md`, และรายชื่อสคริปต์ในโฟลเดอร์ `scripts/`) ของทักษะที่ติดตั้งใน `.relay/skills/` และ `~/.agents/skills/`
   - แนบเป็นสารบัญสั้นๆ ให้ Agent ทุกค่าย (`agy`, `claude`, `codex`) เห็นตรงกัน เพื่อให้เปิดอ่าน `SKILL.md` หรือรันสคริปต์ใน `scripts/` เฉพาะเมื่อตรงกับงานจริง
2. **Scripts as Tools (`templates/scripts/verify-relay-task.sh` & `relay-skills.sh create`):**
   - สร้างสคริปต์ตรวจสอบมาตรฐาน `verify-relay-task.sh` (`~/.agents/bin/relay-verify-task` และใน `verification-before-completion/scripts/`) ให้ `@dev`/`@qa` เรียกตรวจเพดานบรรทัดเอกสาร (`SPEC.md` ≤40, `ARCH.md`+`PLAN.md` ≤60, `QA_REPORT.md` ≤30), ตรวจไฟล์ความลับต้องห้าม และตรวจโครงสร้าง `QA_VERDICT.json` ได้ด้วยคำสั่งเดียว
   - เพิ่มคำสั่ง `relay-skills.sh create <skill-name> [description]` (และในเมนู `[s]`) สำหรับสร้างโครงสร้าง Skill มาตรฐาน (`.relay/skills/<name>/SKILL.md` + `scripts/`)
3. **Evidence-Based Skill Distillation (`distill_project_learned_skills`):**
   - สกัดบทเรียนจากหลักฐานการแก้บั๊กจริง (`QA_VERDICT.before-round-*.json` ที่ไม่ผ่านในรอบแรกแล้วแก้จนผ่านในรอบถัดไป) เข้าคิว `.relay/skills/project-learned/PENDING.md` เพื่อให้มนุษย์อนุมัติเข้า `SKILL.md`

## 2. เกณฑ์การตรวจรับงาน (Acceptance Criteria)
- [ ] **AC-1 (Progressive Skill Index):** `build_skill_index_tsv` และ `get_core_role_prompt_note` สกัด YAML Frontmatter (`name`, `description`), พาธ `SKILL.md`, และรายชื่อไฟล์ใน `scripts/` แนบเข้า Prompt แบบกระชับได้ถูกต้องทั้งจาก `.relay/skills/` และ `~/.agents/skills/`
- [ ] **AC-2 (Scripts as Tools & Skill Scaffolding):** `verify-relay-task.sh` ตรวจจับเอกสารเกินบรรทัด, ไฟล์ความลับ `.env*`/`*.key`, และ `QA_VERDICT.json` ได้แม่นยำ และ `relay-skills.sh create` สร้างโฟลเดอร์ `SKILL.md` + `scripts/` ได้สำเร็จ
- [ ] **AC-3 (Evidence-Based Distillation):** `distill_project_learned_skills` สกัดบทเรียนจาก `QA_VERDICT.before-round-*.json` เมื่อผ่านการแก้บั๊กรอบถัดไปเข้าสู่ `PENDING.md` ได้ถูกต้อง และชุดทดสอบอัตโนมัติทุกชุดผ่าน 100%
