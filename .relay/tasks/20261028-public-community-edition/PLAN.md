# 📋 แผนงานเช็กลิสต์ (PLAN.md) — ไม้ที่ 2 (`@pm`)
- **รหัสใบงาน:** `20261028-public-community-edition`

## รายการงานสำหรับ `@dev` (ไม้ที่ 3) และ `@qa` (ไม้ที่ 4)
- [x] **Task 1 (Cross-Platform Installers & Skill Updater):**
  - สร้างไฟล์ `skills-manifest.txt` เก็บรายการสกิลมาตรฐานสาย Dev ทั้ง 4 ไม้
  - สร้าง `relay-skills.sh` (macOS/Linux) และ `relay-skills.ps1` (Windows PowerShell) รองรับคำสั่ง `install`, `update`, `add`, `list`
  - สร้าง `setup-win.ps1` สำหรับตั้งค่าส่วนกลางบน Windows (`%USERPROFILE%\.agents\`, กฎกลางของทั้ง 3 ค่าย และ Global Git Hook) และอัปเดต `setup-mac.sh`
- [x] **Task 2 (Extensible Domain Packs):**
  - สร้างแม่แบบสายงานสร้างหนังและวิดีโอ `domains/film-video-production/AGENTS.md` และ `EXAMPLE_STORY_SPEC.md`
  - สร้างแม่แบบสายงานธุรกิจและบัญชี `domains/business-accounting/AGENTS.md` และ `EXAMPLE_POLICY_SPEC.md`
- [x] **Task 3 (Deep-Dive Documentation & Public Open-Source Files):**
  - เขียนคู่มือเจาะลึก 4 ไฟล์ใน `docs/` (`INSTALL_ZERO_TO_HERO.md`, `ARCHITECTURE_DEEP_DIVE.md`, `SKILLS_AND_UPDATES.md`, `CUSTOM_DOMAINS_GUIDE.md`)
  - เขียน `README.md` ฉบับสมบูรณ์สำหรับสาธารณะ พร้อม `LICENSE` (MIT) และ `CONTRIBUTING.md`
- [x] **Task 4 (QA Verification, Merge & Sync to `/Users/nontawatwongnuk/dev_bos/RELAY`):**
  - รันเทสต์ตรวจความถูกต้องของสคริปต์และ `pos-core.test.js` (0 Token)
  - บันทึก `QA_REPORT.md`, อัปเดต `PROJECT_STATE.md`, ย้ายใบงานที่เสร็จเข้า `.relay/archive/`, Merge เข้ากิ่ง `main`, ซิงก์ไปยัง `/Users/nontawatwongnuk/dev_bos/RELAY` และ Push ขึ้น `https://github.com/bosocmputer/RELAY.git`
