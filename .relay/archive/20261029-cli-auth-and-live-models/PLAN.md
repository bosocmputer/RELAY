# แผนการดำเนินงาน (PLAN.md)
**รหัสใบงาน:** `20261029-cli-auth-and-live-models`

## รายการงานย่อย (Checklist)
- [x] 1. เพิ่มฟังก์ชัน `refresh_cli_auth_cache()` และ `is_provider_logged_in()` สำหรับตรวจสถานะ Login จริงของ `claude`, `gemini`, `codex`
- [x] 2. อัปเดต `is_role_ready()`, `format_role_status_cell()` และแถว `CLIs ในเครื่อง` บนหัวตารางให้แสดงสถานะ Login ของแต่ละค่ายอย่างชัดเจน
- [x] 3. สร้างฟังก์ชัน `get_cli_live_models()` เพื่อดึงรายชื่อโมเดลจาก CLI ในเครื่องโดยตรง (`~/.codex/models_cache.json`, `@google/gemini-cli`, และ `claude` binary) มาแสดงในเมนูเลือกโมเดล
- [x] 4. ปรับปรุง `run_quick_preset_menu()` ให้ดึงโมเดลเริ่มต้นจริงจาก CLI (เช่น `gpt-6.1-terra` ของ Codex) และบอกชัดเจนว่าค่ายใด Login พร้อมใช้งานแล้ว
- [x] 5. ปรับปรุง `ping_single_role_agent()` ให้ใช้ `codex exec --skip-git-repo-check`, บล็อกค่ายที่ยังไม่ Login ก่อนรัน และกรองข้อความเตือน `Permission allow rule (.claude/settings.json)` ออก
- [x] 6. ทดสอบการทำงานจริง อัปเดต `PROJECT_STATE.md`, บันทึก `QA_REPORT.md`, ติดตั้งลง `~/.agents/bin/relay` และซิงก์ขึ้น GitHub
