# PLAN — 20261029-safety-and-quota-countdown

- [x] **T1** เพิ่ม `ensure_relay_gitignore`, `prepare_task_worktree`, `worktree_dirty_files`; ใช้ใน `run_phase_3_dev` และ `run_auto_relay_loop`; เพิ่มคำสั่ง commit ใน Prompt ของ `@dev`
- [x] **T2** เขียน `run_phase_5_merge` ใหม่ตาม ARCH (commit อัตโนมัติ, `--no-ff`, `--abort`, ตรวจกิ่งปลายทาง, ลบเฉพาะหลังสำเร็จ)
- [x] **T3** Auto-Loop: `run_with_timeout`, `qa_verdict`, `loop_halt`, ตรวจ exit code และไฟล์ผลลัพธ์, ย้ายรายงานเก่า, โหมดสิทธิ์ต่อค่าย
- [x] **T4** แคชโควต้า: เพิ่ม `*_RESET_EPOCH` ทั้งใน Python writer และ `update_codex_quota_fast`
- [x] **T5** `format_countdown`, `effective_quota_pct`, `render_quota_table`; ปรับ `get_role_quota_pair`, `format_role_status_cell`, `print_dashboard_header`, `print_quota_report_box`
- [x] **T6** ทดสอบ: `bash -n`; ทดสอบ AC-1..AC-3 ด้วย git repo ชั่วคราว; ทดสอบ AC-4..AC-6 ด้วย CLI จำลอง (ไม่ใช้โควต้าจริง); ทดสอบ AC-7 ด้วยแคชจำลอง
- [x] **T7** อัปเดตเอกสาร, `QA_REPORT.md`, `PROJECT_STATE.md`, archive, merge, push, sync
