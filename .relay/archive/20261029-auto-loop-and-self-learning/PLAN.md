# แผนการดำเนินงาน (Implementation Plan — 20261029-auto-loop-and-self-learning)

- [x] **Task 1:** เพิ่มฟังก์ชันตรวจสอบเพดานโควต้าก่อนรันแต่ละก้าว (`check_role_quota_safe`) และระบบ `run_auto_relay_loop` (`[a]` / `/loop` / `relay loop`) ใน `relay.sh`
- [x] **Task 2:** เพิ่มระบบสกัดบทเรียนและสร้างทักษะเฉพาะโปรเจกต์อัตโนมัติ (`distill_project_learned_skills` และ `run_learned_skills_menu` — `[l]` / `/learn` / `relay learn`) พร้อมผูกเข้ากับขั้นตอนที่ `[5] Merge & Archive` และการส่งต่อเข้า Prompt ของ `@arch`, `@dev`, `@qa`
- [x] **Task 3:** อัปเดต `relay.ps1` ให้รองรับคำสั่ง `loop` (`[a]`) และ `learn` (`[l]`) บน Windows PowerShell
- [x] **Task 4:** ติดตั้งลง `~/.agents/bin/relay` ทดสอบการทำงานจริง อัปเดตเอกสารทั้งหมด (`README.md`, `docs/ARCHITECTURE_DEEP_DIVE.md`, `docs/USE_CASES_NEW_AND_EXISTING.md`, `.relay/PROJECT_STATE.md`) และ Push ขึ้น GitHub `main`
