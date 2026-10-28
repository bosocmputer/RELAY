# สถานะปัจจุบันของโครงการ (PROJECT_STATE.md)
*อัปเดตล่าสุด: 2026-10-28 • ความยาวไม่เกิน 2 หน้าเพื่อให้ `@arch` และ `@pm` เข้าใจโครงสร้างล่าสุดของระบบได้ทันทีโดยไม่ต้องอ่านใบงานเก่าทั้งหมด*

## 1. ภาพรวมของโครงการ (`RELAY v1.0 Official Public Edition`)
คลังโค้ดมาตรฐานสาธารณะ (`https://github.com/bosocmputer/RELAY.git` • โฟลเดอร์หลัก `/Users/nontawatwongnuk/dev_bos/RELAY`) สำหรับเผยแพร่สถาปัตยกรรมการทำงานร่วมกับตัวแทน AI หลายค่ายแบบแบ่ง 4 ขั้นตอนผ่านเอกสารส่งมอบงานในโฟลเดอร์ `.relay/` รองรับทั้งระบบปฏิบัติการ **Windows** และ **macOS**

## 2. โครงสร้างโมดูลและไฟล์สำคัญล่าสุด
- **สคริปต์ติดตั้งส่วนกลางและสร้างโครงสร้างโครงการ (Cross-Platform Setup & Initialization):**
  - `setup-mac.sh` และ `setup-win.ps1`: ติดตั้งไฟล์กฎการทำงานส่วนกลาง `~/.agents/GLOBAL_AGENTS.md` (หรือ `%USERPROFILE%\.agents\`), เชื่อมต่อไปยัง Claude / Codex / Gemini, ติดตั้งคำสั่ง `relay-init` และเปิดใช้งาน Global Git `pre-commit` Hook
  - `relay-init.sh` และ `relay-init.ps1`: สร้างโครงสร้างโฟลเดอร์ `.relay/` และไฟล์ `PROJECT_STATE.md` ตั้งต้น รองรับทั้ง **โครงการใหม่ (Greenfield: `new`)** และ **โครงการเดิมที่มีโค้ดอยู่แล้ว (Brownfield: `existing`)**
- **ระบบจัดการและอัปเดตทักษะ (`relay-skills.sh`, `relay-skills.ps1` และ `skills-manifest.txt`):**
  - รองรับคำสั่ง `install` (ติดตั้งชุดทักษะมาตรฐานและผูก `Playwright MCP`), `update` (ดึงอัปเดตเวอร์ชันล่าสุดจากคลังโค้ดของผู้พัฒนาต้นทางบน GitHub), `add <repo>` (ติดตั้งทักษะใหม่พร้อมบันทึกเข้าสู่ `skills-manifest.txt` อัตโนมัติ) และ `list`
- **เอกสารคู่มือมาตรฐาน (`README.md` และ `docs/`):**
  - `docs/INSTALL_ZERO_TO_HERO.md`: คู่มือการติดตั้งตั้งแต่เริ่มต้นสำหรับ Windows และ macOS รวมถึงการติดตั้งและเชื่อมต่อโปรแกรม **Obsidian**
  - `docs/USE_CASES_NEW_AND_EXISTING.md`: คู่มือการนำ `RELAY` ไปใช้ใน 2 กรณีศึกษาหลัก ได้แก่ **โครงการใหม่ (Greenfield)** และ **โครงการเดิม (Brownfield)**
  - `docs/ARCHITECTURE_DEEP_DIVE.md`: รายละเอียดสถาปัตยกรรมและหลักการทำงานเชิงลึก
  - `docs/SKILLS_AND_UPDATES.md`: คู่มือการจัดการและอัปเดตชุดทักษะ
  - `docs/CUSTOM_DOMAINS_GUIDE.md`: คู่มือการประยุกต์ใช้ `RELAY` กับสายงานอื่น
- **แม่แบบกฎการทำงานสำหรับสายงานอื่น (`domains/`):**
  - `domains/film-video-production/`: แม่แบบสำหรับสายงานผลิตภาพยนตร์และวิดีโอ (`@writer`, `@director`, `@creator`, `@editor`)
  - `domains/business-accounting/`: แม่แบบสำหรับสายงานบริหารธุรกิจและบัญชี (`@analyst`, `@planner`, `@operator`, `@auditor`)
