# แผนการดำเนินงาน (PLAN.md) — ระบบแสดงโควต้าคงเหลือแบบเรียลไทม์ (Real-Time Multi-Provider Quota Display)

- [x] **Task 1:** สร้างเอกสาร `SPEC.md`, `ARCH.md`, และ `PLAN.md` บนกิ่งแยก `feat/realtime-quota-display`
- [x] **Task 2:** พัฒนาโมดูลดึงและแคชข้อมูลโควต้าแบบขนาน (`refresh_quota_cache`, `load_quota_cache`, `get_role_quota_pair`, `run_quota_dashboard`) ใน `relay.sh`
  - รองรับ `agy -p "/usage"` (แยกทั้งกระเป๋า `Gemini Models` และ `Claude and GPT models`)
  - รองรับ `codex` (อ่านสดจาก `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` และสั่ง Sync สดได้)
  - รองรับ `claude` (ดึงผ่าน Control Request `get_usage` ของ `claude -p --input-format stream-json`)
- [x] **Task 3:** ผสานการแสดงผลโควต้าคงเหลือเข้ากับหน้าแดชบอร์ดหลัก (`print_dashboard_header`), ตารางตำแหน่งทั้ง 4 (`format_role_status_cell`), เมนู `[u]` (`/quota` / `/usage`), และคำสั่ง `relay quota` ใน `relay.sh` และ `relay.ps1`
- [x] **Task 4:** ติดตั้ง `relay.sh` ไปยัง `~/.agents/bin/relay` และทดสอบรันจริง (`relay status`, `relay quota`) เพื่อตรวจความแม่นยำของตัวเลขโควต้าทั้ง 3 ค่าย
- [x] **Task 5:** บันทึกผลลง `QA_REPORT.md`, อัปเดต `README.md`, `docs/`, และ `.relay/PROJECT_STATE.md`, ย้ายใบงานเข้า `.relay/archive/`, ผสานเข้า `main`, Push ขึ้น GitHub และ Sync ไปยัง `/Users/nontawatwongnuk/dev_bos/RELAY`
