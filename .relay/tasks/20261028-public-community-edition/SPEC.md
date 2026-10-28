# 📜 ใบสั่งงาน (SPEC.md) — ไม้ที่ 1 (`@po`)
- **รหัสใบงาน:** `20261028-public-community-edition`
- **ชื่อฟีเจอร์:** ยกระดับ `RELAY` เป็น Public Open-Source Community Edition (รองรับ Windows & macOS เริ่มจาก 0 + ระบบจัดการ/อัปเดต Skills + แม่แบบดัดแปลงข้ามสายงาน)
- **สถานะ:** ผู้ใช้ยืนยันความต้องการครบทั้ง 3 ข้อแล้ว

## 1. เป้าหมายหลัก (Objective)
ทำให้โปรเจกต์ `https://github.com/bosocmputer/RELAY.git` (และโฟลเดอร์หลัก `/Users/nontawatwongnuk/dev_bos/RELAY`) เป็นคู่มือและชุดเครื่องมือสาธารณะที่สมบูรณ์ที่สุดสำหรับชุมชนนักพัฒนาและผู้สนใจทั่วไป โดยอธิบายตั้งแต่ 0 แบบจับมือทำ รองรับทั้ง **Windows และ macOS** มีระบบจัดการและอัปเดต Skills อัตโนมัติ และมีแม่แบบสำหรับดัดแปลงไปใช้กับสายงานอื่น (เช่น สร้างหนัง/วิดีโอ และ บัญชี/ธุรกิจ)

## 2. ข้อตกลงจากการซักถามผู้ใช้ (Confirmed Decisions)
1. **รูปแบบภาษา:** ใช้ **ภาษาไทยเป็นหลัก** อธิบายละเอียด เข้าใจง่ายสำหรับคนทั่วไปและชุมชนนักพัฒนาไทย พร้อมวงเล็บคำศัพท์เทคนิคภาษาอังกฤษที่จำเป็น
2. **โครงสร้างคู่มือบน GitHub:**
   - **`README.md` หน้าแรก:** มีเนื้อหาครบจบในหน้าเดียว ตั้งแต่วิธีคิด สถาปัตยกรรม วิธีติดตั้งเริ่มจาก 0 ทั้งบน Windows และ macOS วิธีอัปเดต Skills และวิธีนำไปดัดแปลงใช้กับสายงานอื่น
   - **โฟลเดอร์ `docs/` เจาะลึกแยกหมวดหมู่:**
     - `docs/INSTALL_ZERO_TO_HERO.md`: คู่มือจับมือทำตั้งแต่เครื่องเปล่า (ไม่มี Git/Node.js) สำหรับทั้ง Windows (PowerShell) และ macOS (Terminal)
     - `docs/ARCHITECTURE_DEEP_DIVE.md`: อธิบายเบื้องหลังการทำงานของระบบส่งไม้ต่อ (`.relay/`), การแก้ปัญหา Context Rot, Git Worktree, 0-Token Test และ Playwright MCP
     - `docs/SKILLS_AND_UPDATES.md`: คู่มือการอัปเดตสกิลเดิมตามผู้พัฒนาต้นทาง การเพิ่มสกิลใหม่ และการสร้าง `SKILL.md` ของตัวเอง
     - `docs/CUSTOM_DOMAINS_GUIDE.md`: คู่มือการดัดแปลง `RELAY` ไปใช้กับแผนกอื่นหรือวงการอื่นนอกเหนือจากงานเขียนโค้ด
3. **ระบบจัดการและอัปเดต Skills (`relay-skills.sh` & `relay-skills.ps1` + `skills-manifest.txt`):**
   - รองรับคำสั่ง `install` (ติดตั้งชุดมาตรฐาน), `update` (ดึงเวอร์ชันล่าสุดจากผู้พัฒนาต้นทางบน GitHub), `add <repo>` (เพิ่มสกิลใหม่), และ `list` (ดูสกิลที่มีในเครื่อง)
4. **แม่แบบสายงานอื่นพร้อมใช้งาน (`domains/`):**
   - `domains/film-video-production/AGENTS.md`: แม่แบบ 4 ไม้สำหรับสายสร้างหนัง/วิดีโอ/ครีเอเตอร์ (`@writer` ➔ `@director` ➔ `@creator` ➔ `@editor`)
   - `domains/business-accounting/AGENTS.md`: แม่แบบ 4 ไม้สำหรับสายบริษัท/บัญชี/การเงิน (`@analyst` ➔ `@planner` ➔ `@operator` ➔ `@auditor`)
5. **มาตรฐาน Open-Source ชุมชน:** มีไฟล์ `LICENSE` (MIT) และ `CONTRIBUTING.md` พร้อมซิงก์ไฟล์ทั้งหมดไปที่ `/Users/nontawatwongnuk/dev_bos/RELAY` และ Push ขึ้น `https://github.com/bosocmputer/RELAY.git`

## 3. เกณฑ์ตรวจรับงาน (Acceptance Criteria สำหรับ `@qa`)
- [x] **AC-1:** มีสคริปต์ติดตั้งและจัดการสกิลครบทั้ง macOS (`setup-mac.sh`, `relay-skills.sh`) และ Windows (`setup-win.ps1`, `relay-skills.ps1`) พร้อมไฟล์ `skills-manifest.txt`
- [x] **AC-2:** `README.md` และโฟลเดอร์ `docs/` ทั้ง 4 ไฟล์อธิบายละเอียดตั้งแต่ 0 ครบทั้งหลักการทำงาน สถาปัตยกรรม การอัปเดต Skills และการขยายสายงาน
- [x] **AC-3:** มีแม่แบบสายงาน `domains/film-video-production/AGENTS.md` และ `domains/business-accounting/AGENTS.md` พร้อมตัวอย่างเอกสารสัญญา
- [x] **AC-4:** Unit Tests (`node --test examples/cafe-pos/pos-core.test.js`) ผ่าน 100% และซิงก์ไฟล์ทั้งหมดไปยัง `/Users/nontawatwongnuk/dev_bos/RELAY` พร้อม Push ขึ้น GitHub สำเร็จ
