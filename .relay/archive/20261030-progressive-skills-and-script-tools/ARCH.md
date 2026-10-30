# สถาปัตยกรรมและการออกแบบเทคนิค (ARCH.md — 20261030-progressive-skills-and-script-tools)

## 1. โครงสร้างโมดูลและไฟล์ที่แก้ไข/สร้างใหม่
- **`relay.sh`:**
  - `build_skill_index_tsv [skill_names...]`: สแกน `.relay/skills/<name>/SKILL.md` (ลำดับแรก) และ `$GLOBAL_DIR/skills/<name>/SKILL.md` ดึง `description` จาก YAML Frontmatter (ย่อ ≤80 ตัวอักษร) และรายชื่อไฟล์ใน `scripts/` คืนค่าเป็น TSV `slug \t path \t desc \t scripts`
  - `get_role_progressive_skills_note <role_key>`: สร้างข้อความสารบัญ Progressive Disclosure สั้นๆ สำหรับแนบใน `get_core_role_prompt_note` (รวม Skill ประจำบทบาท + Project-local Skills ใน `.relay/skills/`)
  - `get_qa_prompt_contract`: อ้างอิงสคริปต์ `relay-verify-task` (ถ้ามี) ให้ `@qa` ใช้ตรวจโครงสร้างเอกสารและไฟล์ความลับแบบ Deterministic
  - `distill_project_learned_skills`: เพิ่มการอ่าน `QA_VERDICT.before-round-*.json` คู่กับ `QA_VERDICT.json` ที่ผ่านแล้ว เพื่อสกัดบทเรียนจากความล้มเหลวที่แก้สำเร็จจริง (`[บทเรียนจากการแก้บั๊กจริง] ...`) เข้าสู่ `PENDING.md`
  - `run_skills_menu`: เพิ่มตัวเลือกสร้าง Project Skill ใหม่ (`.relay/skills/<slug>/SKILL.md` + `scripts/`)
- **`templates/scripts/verify-relay-task.sh` (สร้างใหม่):**
  - สคริปต์ Bash มาตรฐานสำหรับตรวจเพดานบรรทัด (`SPEC.md` ≤40, `ARCH.md` ≤30, `PLAN.md` ≤30, `QA_REPORT.md` ≤30), ตรวจไฟล์ความลับต้องห้ามใน Git, และตรวจ JSON Schema ของ `QA_VERDICT.json`
- **`relay-skills.sh`:**
  - เพิ่มคำสั่ง `create <skill-name> [description] [target_dir]` สร้างโครงสร้าง `.relay/skills/<name>/SKILL.md` + `scripts/` และคัดลอก `verify-relay-task.sh` ไปยัง `~/.agents/bin/relay-verify-task` และ `~/.agents/skills/verification-before-completion/scripts/verify-relay-task.sh` ตอน `install`/`update`
- **`tests/test_progressive_skills_and_tools.sh` (สร้างใหม่):**
  - ชุดทดสอบอัตโนมัติครอบคลุม AC-1, AC-2, และ AC-3 โดยไม่ใช้โควต้า AI จริง
