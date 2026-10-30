# แผนการดำเนินงาน (PLAN.md — 20261031-on-demand-project-isolation-and-selector-ui)

## ลำดับขั้นตอนการพัฒนา (Implementation Steps)
1. **สร้าง Git Worktree แยกอิสระ:**
   - สร้าง `.relay/worktrees/20261031-on-demand-project-isolation-and-selector-ui` บนกิ่ง `feat/20261031-on-demand-project-isolation-and-selector-ui`
2. **อัปเดต `templates/GLOBAL_AGENTS.md`:**
   - กำหนดขอบเขต On-Demand & Per-Project Activation Rule ให้ชัดเจนว่าโปรเจกต์ทั่วไปที่ไม่มี `.relay/` จะไม่ถูกบังคับให้สร้าง `SPEC.md` หรือ `Git Worktree`
3. **อัปเกรด `select_or_create_project_dir` และ `list_workspace_projects_tsv` ใน `relay.sh`:**
   - แยกกลุ่มและเรียงโปรเจกต์ `● [RELAY]` ขึ้นก่อนเสมอ แสดงป้ายสถานะสีด้านหน้าชื่อโปรเจกต์ พร้อมแสดงชื่อ Task ล่าสุดของแต่ละโปรเจกต์ และปรับข้อความเมนู Stage 2/Footer ให้สะอาดตา
4. **อัปเดตเอกสาร (`README.md`, `docs/USE_CASES_NEW_AND_EXISTING.md`, `docs/ARCHITECTURE_DEEP_DIVE.md`) และชุดทดสอบ:**
   - เพิ่มการทดสอบใน `tests/test_hermes_cli_redesign.sh`
   - รัน `relay-verify-task` และชุดทดสอบอัตโนมัติทั้ง 9 ชุดให้ผ่านครบ 100%
