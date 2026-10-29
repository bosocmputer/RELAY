# PLAN — 20261029-final-hardening

- [x] **T1 (F3)** `qa_verdict` แบบ JSON-first, `archive_old_qa_outputs`, `get_qa_prompt_contract`; ใช้ในขั้นตอนที่ 4, Auto-Loop, ขั้นตอนที่ 5, แดชบอร์ด
- [x] **T2 (F4)** ลบคำสั่งแก้ `PROJECT_STATE.md` ออกจาก `@qa`, เลิกคัดลอกกลับ, เพิ่ม `record_task_in_project_state` หลังผสาน
- [x] **T3 (F2)** `PENDING.md`, `apply_learned_approval`, เมนู `[l]` ใหม่, badge แดชบอร์ด
- [x] **T4 (F5)** `append_run_log` ใน `launch_provider_cli` และ `exec_provider_autonomous`, สรุปท้ายลูป
- [x] **T5 (F7)** สถานะการดึงโควต้าต่อค่าย + การแสดงผล `?`
- [x] **T6 (F1)** แก้เอกสาร README / ARCHITECTURE / PROJECT_STATE + หัวข้อข้อจำกัด
- [x] **T7** อัปเดตเทสต์ (JSON verdict, PENDING, PROJECT_STATE, RUN_LOG, quota `?`), รันทั้งหมด, QA_REPORT, archive, merge, push, sync
