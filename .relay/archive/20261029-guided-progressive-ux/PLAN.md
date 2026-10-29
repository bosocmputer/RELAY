# แผนการดำเนินงาน (PLAN.md)
**รหัสใบงาน:** `20261029-guided-progressive-ux`

## รายการงานย่อย (Checklist)
- [x] 1. เพิ่มฟังก์ชัน `determine_ux_stage()` และ `compute_stage3_next_step()` ใน `relay.sh`
- [x] 2. ปรับปรุง `print_dashboard_header()` ให้แสดงแถบ **3-Stage Progress Stepper** (`ขั้นที่ 1` ➔ `ขั้นที่ 2` ➔ `ขั้นที่ 3`) และกล่อง **`👉 สิ่งที่ต้องทำตอนนี้`** ที่ปรับเปลี่ยนข้อความตามขั้นปัจจุบัน
- [x] 3. เพิ่มฟังก์ชัน `run_quick_preset_menu()` และ `select_or_create_project_dir()` เพื่อรองรับการตั้งค่าด่วนในคลิกเดียวและการสลับโฟลเดอร์ออกจาก `$HOME`
- [x] 4. ปรับปรุง Main Loop ของ `relay.sh` และ `relay.ps1` ให้แยกแสดงเมนูตาม `UX_STAGE` (1, 2, 3) โดยซ่อนเมนูที่ยังไม่ถึงคิว และเลื่อน `❯` ไปยังขั้นตอนที่แนะนำโดยอัตโนมัติ
- [x] 5. ทดสอบการทำงานครบทั้ง 3 ขั้นตอน อัปเดต `PROJECT_STATE.md`, บันทึก `QA_REPORT.md`, ติดตั้งลง `~/.agents/bin/relay` และซิงก์ขึ้น GitHub
