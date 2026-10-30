# แผนการดำเนินงาน (PLAN.md)
- **รหัสใบงาน:** `20261030-token-telemetry-and-fast-track`

- [x] **Task 1:** สร้าง Git Worktree แยกอิสระสำหรับใบงาน `20261030-token-telemetry-and-fast-track`
- [x] **Task 2:** พัฒนา `extract_step_token_usage`, อัปเดต `append_run_log`, `print_step_telemetry_box`, `get_task_telemetry_summary_inline`, และ `run_task_stats_view` (`[v]` / `relay stats`) ใน `relay.sh`
- [x] **Task 3:** เพิ่มโหมดด่วน `run_fast_track_dev` (`[x]` / `relay fast`) และปรับ Prompt ของ `@po`, `@arch`, `@dev`, `@qa` ให้กระชับและลด Ceremony Overhead
- [x] **Task 4:** ปรับปรุง `templates/GLOBAL_AGENTS.md`, `README.md`, และ `docs/*` ให้ไม่มีคำเคลม `"0 Token"` ที่คลาดเคลื่อน พร้อมอธิบายระบบวัด Token จริงและโหมด Fast Track
- [x] **Task 5:** สร้างชุดทดสอบอัตโนมัติ `tests/test_token_telemetry.sh` และรันทดสอบร่วมกับชุดทดสอบเดิมทั้งหมด ➔ บันทึก `QA_REPORT.md` & `QA_VERDICT.json` ➔ Merge เข้า `main` และ Push ขึ้น GitHub
