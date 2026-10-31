# แผนการดำเนินงาน (PLAN.md) — ขั้นตอนที่ 2 (`@pm`)
- **รหัสใบงาน:** `20261028-public-community-edition`

## รายการดำเนินงานสำหรับ `@dev` (ขั้นตอนที่ 3) และ `@qa` (ขั้นตอนที่ 4)
- [x] **Task 1:** ลบโฟลเดอร์ `dashboard/` และ `examples/` ออกจากโครงการ
- [x] **Task 2:** สร้างสคริปต์ `relay-init.sh` (macOS/Linux) และ `relay-init.ps1` (Windows) สำหรับเตรียมโครงสร้าง `.relay/` ในโครงการใหม่และโครงการเดิม พร้อมรองรับการเปิดดูใน Obsidian
- [x] **Task 3:** ปรับปรุงไฟล์แม่แบบและสคริปต์ทั้งหมด (`templates/GLOBAL_AGENTS.md`, `templates/playwright-qa-SKILL.md`, `templates/pre-commit`, `skills-manifest.txt`, `setup-mac.sh`, `setup-win.ps1`, `relay-skills.sh`, `relay-skills.ps1`) ให้ใช้ภาษาทางการระดับวิศวกรรมซอฟต์แวร์
- [x] **Task 4:** จัดทำเอกสารคู่มือหลัก `README.md` และเอกสารเชิงลึกใน `docs/` (รวมถึง `docs/USE_CASES_NEW_AND_EXISTING.md` และคู่มือการเชื่อมต่อ Obsidian) พร้อมปรับปรุงแม่แบบใน `domains/` ให้เป็นภาษาทางการทั้งหมด
- [x] **Task 5:** ตรวจสอบด้วยสคริปต์ว่าไม่มีคำศัพท์ไม่เป็นทางการหลงเหลือ อัปเดต `~/.agents/GLOBAL_AGENTS.md` ซิงก์ไปยัง `<โฟลเดอร์ RELAY>` และบันทึกขึ้น GitHub
