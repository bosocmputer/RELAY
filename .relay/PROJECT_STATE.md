# 📌 สถานะปัจจุบันของโปรเจกต์ (PROJECT_STATE.md)
*อัปเดตล่าสุด: 2026-10-28 • ความยาวไม่เกิน 2 หน้าเพื่อให้ `@arch/@pm` อ่านเข้าใจโครงสร้างทันทีโดยไม่ต้องย้อนอ่านใบงานเก่า*

## 1. ภาพรวมโปรเจกต์ (`RELAY v1.0 Public Community Edition`)
Repo สาธารณะ (`https://github.com/bosocmputer/RELAY.git` • โฟลเดอร์หลัก `/Users/nontawatwongnuk/dev_bos/RELAY`) สำหรับเผยแพร่มาตรฐานการทำงานร่วมกับ AI หลายค่ายแบบวิ่งผลัด 4 ไม้ผ่านเอกสารสัญญา (`.relay/`) รองรับทั้ง **Windows** และ **macOS** เริ่มต้นตั้งแต่ 0

## 2. โครงสร้างโมดูลและไฟล์สำคัญล่าสุด
- **ระบบติดตั้งและจัดการ Skills ข้ามแพลตฟอร์ม (Cross-Platform Setup & Skill Updater):**
  - `setup-mac.sh` & `setup-win.ps1`: ติดตั้ง `~/.agents/GLOBAL_AGENTS.md` (หรือ `%USERPROFILE%\.agents\`), เชื่อมกฎไปยัง Claude / Codex / Gemini และเปิดใช้ Global Git `pre-commit` Hook
  - `relay-skills.sh` & `relay-skills.ps1` + `skills-manifest.txt`: รองรับคำสั่ง `install`, `update` (ดึงอัปเดตล่าสุดจากผู้พัฒนาต้นทางบน GitHub), `add <repo>` (เพิ่มสกิลใหม่และบันทึกเข้า manifest อัตโนมัติ), และ `list`
- **คู่มือสาธารณะ (`README.md` & `docs/`):**
  - `docs/INSTALL_ZERO_TO_HERO.md`: คู่มือเริ่มจาก 0 สำหรับเครื่องเปล่าทั้ง Windows และ macOS
  - `docs/ARCHITECTURE_DEEP_DIVE.md`: เจาะลึกสถาปัตยกรรม 4 เสาหลักของ `RELAY`
  - `docs/SKILLS_AND_UPDATES.md`: วิธีอัปเดตสกิลเดิม เพิ่มสกิลใหม่ และเขียน `SKILL.md` เอง
  - `docs/CUSTOM_DOMAINS_GUIDE.md`: วิธีดัดแปลง `RELAY` ไปใช้กับสายอาชีพอื่น
- **แม่แบบดัดแปลงข้ามสายงาน (`domains/`):**
  - `domains/film-video-production/`: บทบาท 4 ไม้สำหรับสายสร้างหนัง/วิดีโอ (`@writer`, `@director`, `@creator`, `@editor`)
  - `domains/business-accounting/`: บทบาท 4 ไม้สำหรับสายบริษัท/บัญชี/ภาษี (`@analyst`, `@planner`, `@operator`, `@auditor`)
- **โปรเจกต์ตัวอย่าง (`dashboard/` & `examples/cafe-pos/`):**
  - `dashboard/index.html`: หน้ากระดานวิ่งผลัด 4 ไม้และเครื่องคำนวณการประหยัด Token
  - `examples/cafe-pos/`: ระบบคิดเงินร้านกาแฟ + VAT 7% + PromptPay QR พร้อม Unit Test 0 Token (`node --test examples/cafe-pos/pos-core.test.js`)
