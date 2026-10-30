# PLAN: แผนการดำเนินงานและชุดคำสั่งทดสอบ

## 1. ลำดับขั้นการพัฒนา (Implementation Steps)
1. เตรียม Git Worktree แยกอิสระที่ `.relay/worktrees/20261030-hermes-style-cli-redesign` บนกิ่ง `feat/20261030-hermes-style-cli-redesign`
2. เพิ่มฟังก์ชัน `render_relay_logo_lines()` (`RELAY_LOGO_STYLE="${RELAY_LOGO_STYLE:-apple}"`) และ `render_hermes_split_header()` ใน `relay.sh`
3. ปรับปรุง `print_dashboard_header()` ให้ใช้ Hermes-Style Split-Header Card โดยคงความเข้ากันได้กับข้อมูล Quota, Custom Agents (`@ux`, `@devops`), และ Telemetry
4. ปรับปรุง `interactive_menu()` และ Main Loop ขั้นที่ 3 ให้แยกหมวด `Workflow` (7 ข้อหลัก) คู่กับแถบ `Shortcuts` ด้านล่างที่รับคีย์ลัดได้ครบทุกปุ่ม
5. สร้างชุดทดสอบ `tests/test_hermes_cli_redesign.sh` และรันทดสอบร่วมกับชุดทดสอบเดิมทั้ง 6 ชุด

## 2. คำสั่งตรวจสอบและรันชุดทดสอบ (Verification Commands)
- `bash -n relay.sh`
- `bash tests/test_hermes_cli_redesign.sh`
- `bash tests/test_quota_display.sh`
- `bash tests/test_custom_agents_and_back_nav.sh`
- `bash tests/test_token_telemetry.sh`
- `bash tests/test_phase5_merge.sh`
- `bash tests/test_auto_loop.sh`
- `bash tests/test_quota_failover_and_handoff.sh`
