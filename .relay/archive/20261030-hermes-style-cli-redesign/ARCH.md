# ARCH: โครงสร้างทางเทคนิคสำหรับ Hermes-Style CLI Redesign & Modular Braille Logo

## 1. ไฟล์ที่ต้องแก้ไขและสร้างใหม่
1. `relay.sh` (แก้ไข):
   - **`RELAY_LOGO_STYLE` & `render_relay_logo_lines()`:** ฟังก์ชันแยกอิสระสำหรับคืนค่าบรรทัดโลโก้ Braille (ค่าเริ่มต้น `apple` 9 บรรทัด) เพื่อให้สลับหรือเปลี่ยนโลโก้ในอนาคตได้ที่จุดเดียว
   - **`render_hermes_split_header()` & `print_dashboard_header()`:** วาดกรอบ `╭─── RELAY v1.0.0 ───╮` ด้วย Python คำนวณความกว้าง Unicode/Braille/ภาษาไทย จัดวางคอลัมน์ซ้าย (Braille Apple + Provider + Path/Branch + Task) คู่กับคอลัมน์ขวา (`Agent Roles`, `Quota (5h / 7d)`, `Pipeline & Telemetry`)
   - **`MENU_SHORTCUTS_BAR` & `interactive_menu()`:** ปรับกรอบเมนูและตัวชี้ `❯` ให้ใช้โทนสี 4 ระดับ (เส้นกรอบ `C_MUTED`, บรรทัดที่เลือก `C_SEL`, คีย์ลัดใน `Shortcuts` ด้านล่างกดได้ทันทีผ่าน `EXTRA_MENU_KEYS`)
   - **Stage 3 Main Menu:** แสดงเฉพาะ 7 คำสั่ง `Workflow` (`1..5`, `a`, `x`) ในรายการเลื่อนลูกศร และแสดงคำสั่งจัดการระบบในแถบ `Shortcuts` ด้านล่าง
2. `tests/test_hermes_cli_redesign.sh` (สร้างใหม่):
   - ทดสอบ `render_relay_logo_lines`, โครงสร้าง Hermes-Style Split-Header Card, การกดคีย์ลัดจากแถบ `Shortcuts`, และการตรวจสอบคำศัพท์มาตรฐาน
