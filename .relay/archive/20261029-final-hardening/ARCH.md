# ARCH — 20261029-final-hardening

| ส่วน | การเปลี่ยนแปลง |
| :-- | :-- |
| `distill_project_learned_skills` | เขียนกฎที่เสนอลง `PENDING.md` (dedupe กับ `SKILL.md` + `PENDING.md`, เพดาน 30) และบันทึก LEDGER "เสนอ" |
| `apply_learned_approval <selection>` (ใหม่) | Python: อนุมัติ/ปฏิเสธจาก `PENDING.md` ➔ `SKILL.md` (เพดาน 25) ➔ LEDGER ➔ ล้าง `PENDING.md` |
| `get_learned_pending_count` (ใหม่) | นับกฎใน `PENDING.md` |
| `qa_verdict <task_dir>` | คืน `PASS\|json`, `FAIL\|json`, `NONE\|invalid-json`, `PASS\|md`, `FAIL\|md`, `NONE\|md`, `MISSING\|-` |
| `archive_old_qa_outputs` (ใหม่) | ย้าย `QA_REPORT.md` + `QA_VERDICT.json` เป็น `*.before-round-N.*` |
| `get_qa_prompt_contract` (ใหม่) | ข้อความกำหนดรูปแบบ `QA_VERDICT.json` ใช้ร่วมในขั้นตอนที่ 4 และ Auto-Loop |
| `record_task_in_project_state` (ใหม่) | Python: แทรกรายการลงหัวข้อ "ประวัติใบงานที่ผสานแล้ว (RELAY อัปเดตอัตโนมัติ)" เก็บ 15 รายการ |
| `append_run_log` (ใหม่) | เขียน JSONL ผ่าน Python (escape ถูกต้อง) |
| `print_loop_run_summary` (ใหม่) | สรุปเวลาและโควต้าต่อขั้นจาก `RUN_LOG.jsonl` |
| แคชโควต้า | เพิ่ม `{AGY,CODEX,CLAUDE}_FETCH_OK` (`1`/`0`/`-`) และ `{AGY,CODEX,CLAUDE}_FETCHED_AT` (เวลาที่ดึงสำเร็จล่าสุด) |
| `render_quota_table` | แถวละ 9 ค่า (+fetch_ok, fetched_at); ค่ายที่ดึงไม่ได้แสดง `? NN%` สีจาง |
| `compute_stage3_next_step` | ใช้ `qa_verdict` แทนการดูแค่ว่ามีไฟล์ `QA_REPORT.md` |
