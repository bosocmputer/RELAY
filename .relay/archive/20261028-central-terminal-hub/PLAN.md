# แผนการดำเนินงาน (PLAN.md) — ขั้นตอนที่ 2 (`@pm`)
- **รหัสใบงาน:** `20261028-central-terminal-hub`

## รายการดำเนินงานสำหรับ `@dev` (ขั้นตอนที่ 3) และ `@qa` (ขั้นตอนที่ 4)
- [x] **Task 1:** สร้างไฟล์แม่แบบ `templates/relay-roles.conf` กำหนดค่าเริ่มต้นของการจับคู่ตำแหน่งกับค่าย AI (`ROLE_PO`, `ROLE_ARCH`, `ROLE_DEV`, `ROLE_QA`)
- [x] **Task 2:** พัฒนาสคริปต์ `relay.sh` (สำหรับ macOS/Linux) และ `relay.ps1` (สำหรับ Windows PowerShell) ให้เป็นหน้าจอควบคุมกลาง (Interactive Terminal Hub) ที่รองรับครบทุกฟังก์ชัน (`[1]` ถึง `[5]`, `[n]`, `[i]`, `[c]`, `[t]`, `[d]`, `[s]`) พร้อมระบบทดสอบความพร้อมของ Agent แต่ละตำแหน่ง (`relay test`)
- [x] **Task 3:** อัปเดต `setup-mac.sh` และ `setup-win.ps1` ให้ติดตั้งคำสั่ง `relay` ลงใน `~/.agents/bin/relay` และผูก `PATH` อัตโนมัติ พร้อมให้ตั้งค่าจับคู่ค่าย AI ได้ตั้งแต่ตอนติดตั้ง
- [x] **Task 4:** อัปเดต `.gitignore` (เพิกเฉยต่อ `.relay/worktrees/`) และอัปเดตเอกสารคู่มือทั้งหมด (`README.md`, `docs/INSTALL_ZERO_TO_HERO.md`, `docs/USE_CASES_NEW_AND_EXISTING.md`, `docs/ARCHITECTURE_DEEP_DIVE.md`, `.relay/PROJECT_STATE.md`)
- [x] **Task 5:** ทดสอบการทำงานของ `relay.sh`, อัปเดตการตั้งค่าในเครื่อง Mac ของผู้ใช้, บันทึก `QA_REPORT.md`, ผสานเข้ากิ่ง `main`, ซิงก์ไปยัง `<โฟลเดอร์ RELAY>` และอัปโหลดขึ้น GitHub
