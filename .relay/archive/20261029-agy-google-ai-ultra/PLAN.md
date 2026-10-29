# แผนการดำเนินงาน (PLAN.md)
**รหัสใบงาน:** `20261029-agy-google-ai-ultra`

## รายการงานย่อย (Checklist)
- [x] 1. เพิ่มการรองรับค่าย `agy` (Google AI Ultra / Antigravity CLI) ใน `relay.sh`, `relay.ps1`, และ `templates/relay-roles.conf`
- [x] 2. เพิ่มรายการโมเดลจาก `agy models` (ทั้ง Gemini 4 Argon / 3.8 Flash และ Claude Opus 5.5 / Sonnet 5.5) เข้าใน `get_cli_live_models`
- [x] 3. เพิ่ม Preset แนะนำ `Google AI Ultra + Codex` และ `All-Google-AI-Ultra` ใน `run_quick_preset_menu()`
- [x] 4. อัปเดตการตั้งค่าเริ่มต้นใน `~/.agents/relay-roles.conf` ให้พร้อมใช้งานครบ 4/4 ตำแหน่งทันที
- [x] 5. ทดสอบการทำงานจริง บันทึก `QA_REPORT.md` อัปเดต `PROJECT_STATE.md` และซิงก์ขึ้น GitHub
