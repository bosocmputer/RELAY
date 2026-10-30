# โครงสร้างทางเทคนิค (`ARCH.md`)

## 1. ไฟล์ที่แก้ไขและสร้างเพิ่ม
- `relay.sh`:
  - `get_worktree_handoff_context_note <work_dir>`: รัน `git status --short` และ `git diff --stat` (ไม่นับ `.relay/`) รวมถึง `git log --oneline main..HEAD` เพื่อสร้างข้อความสรุปงานที่ทำค้างไว้ใน Worktree แนบเข้า Prompt อัตโนมัติ
  - `list_quota_failover_candidates <cur_prov> <cur_model>`: คืนค่ารายการกระเป๋าโควต้าที่พร้อมใช้ในเครื่อง (`provider|model|min_pct|label`) เรียงจากโควต้าสูงสุดไปต่ำสุด
  - `apply_role_provider_model_switch <role_key> <prov> <model>`: อัปเดตตัวแปรประจำตำแหน่ง (`ROLE_*`, `MODEL_*`) และบันทึกลงไฟล์ตั้งค่า
  - `prompt_or_auto_switch_role_quota <role_key> <role_label>`: แสดงเมนูทางลัดเมื่อโควต้า `< 20%` (เลือกสลับไปกระเป๋าที่โควต้าสูงสุดใน 1 ปุ่ม, เลือกค่ายเอง, หรือฝืนใช้โมเดลเดิมต่อ) และรองรับ `RELAY_AUTO_FAILOVER=1`
  - `run_auto_relay_loop` / `loop_check_rc`: เพิ่มตัวเลือกเปิด Auto-Failover ก่อนเริ่มลูป และรองรับการสลับค่ายรับไม้ต่อเมื่อ CLI จบด้วย error กลางคัน
- `tests/test_quota_failover_and_handoff.sh`: ชุดทดสอบอัตโนมัติสำหรับ AC-1 ถึง AC-4
- `README.md`: อัปเดตคำอธิบายระบบ Smart Quota Failover & Worktree Handoff
