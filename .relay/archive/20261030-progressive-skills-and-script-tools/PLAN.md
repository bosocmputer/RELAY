# แผนการดำเนินงาน (PLAN.md — 20261030-progressive-skills-and-script-tools)

## ลำดับขั้นตอนการพัฒนา (Implementation Steps)
1. **สร้าง Git Worktree แยกอิสระ:**
   - สร้าง `.relay/worktrees/20261030-progressive-skills-and-script-tools` บนกิ่ง `feat/20261030-progressive-skills-and-script-tools`
2. **สร้างสคริปต์ `templates/scripts/verify-relay-task.sh` และอัปเดต `relay-skills.sh`:**
   - พัฒนา `templates/scripts/verify-relay-task.sh` ให้ตรวจเพดานความยาวเอกสาร, ตรวจไฟล์ความลับต้องห้าม, และตรวจ `QA_VERDICT.json`
   - อัปเดต `relay-skills.sh` ให้รองรับคำสั่ง `create <skill-name> [description] [target_dir]` และติดตั้ง `verify-relay-task.sh`
3. **อัปเกรด `relay.sh` (Progressive Disclosure Index + Evidence-Based Distillation):**
   - เพิ่ม `build_skill_index_tsv` และ `get_role_progressive_skills_note` เชื่อมเข้ากับ `get_core_role_prompt_note`
   - อัปเกรด `distill_project_learned_skills` ให้สกัดบทเรียนจาก `QA_VERDICT.before-round-*.json` เมื่อแก้ผ่านในรอบถัดไป
   - เพิ่มตัวเลือกสร้าง Project Skill (`SKILL.md` + `scripts/`) ใน `run_skills_menu`
4. **สร้างและรันชุดทดสอบอัตโนมัติ (`tests/test_progressive_skills_and_tools.sh`):**
   - รัน `bash -n relay.sh && bash -n relay-init.sh && bash -n relay-skills.sh && bash -n templates/scripts/verify-relay-task.sh`
   - รัน `bash tests/test_progressive_skills_and_tools.sh` และชุดทดสอบเดิมทั้ง 8 ชุดให้ผ่านครบ 100%
