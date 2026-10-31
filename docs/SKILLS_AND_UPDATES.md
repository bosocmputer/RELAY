# คู่มือการจัดการ การอัปเดต และการเพิ่มชุดทักษะ (`SKILLS_AND_UPDATES.md`)

ระบบ `RELAY` จัดเก็บชุดทักษะเฉพาะทาง (Modular Skill Packs) ไว้ที่โฟลเดอร์ส่วนกลางของเครื่อง (`~/.agents/skills/` บน macOS/Linux หรือ `%USERPROFILE%\.agents\skills\` บน Windows) โดยผู้ใช้งานสามารถสั่ง **อัปเดตทักษะเดิมให้เป็นเวอร์ชันล่าสุดตามผู้พัฒนาต้นทางบน GitHub** หรือ **ติดตั้งทักษะใหม่เพิ่มเติม** ได้ตลอดเวลาผ่านสคริปต์ `relay-skills`

---

## 1. การอัปเดตชุดทักษะทั้งหมดให้เป็นเวอร์ชันล่าสุด (`update`)

เมื่อผู้พัฒนาทักษะต้นทาง (เช่น ทีมวิศวกรของ Vercel, Supabase, Trail of Bits, Semgrep หรือ Obra) มีการปรับปรุงเนื้อหาหรือแนวทางปฏิบัติใหม่บน GitHub คุณสามารถดึงข้อมูลเวอร์ชันล่าสุดทั้งหมดมาอัปเดตลงในเครื่องได้ด้วยคำสั่งเดียว:

### 🍎 บนระบบปฏิบัติการ macOS / Linux:
```bash
./relay-skills.sh update
```

### 🪟 บนระบบปฏิบัติการ Windows (PowerShell):
```powershell
.\relay-skills.ps1 update
```
*(สคริปต์จะอ่านรายการคลังโค้ดทั้งหมดจากไฟล์ [`skills-manifest.txt`](../skills-manifest.txt) และดำเนินการดึงเวอร์ชันล่าสุดจาก GitHub มาติดตั้งทับในคลังส่วนกลางของเครื่องโดยอัตโนมัติ)*

---

## 2. การเพิ่มทักษะใหม่จาก GitHub เข้าสู่ระบบ (`add`)

หากคุณต้องการเพิ่มทักษะใหม่จาก GitHub เข้าสู่ระบบ `RELAY` สามารถใช้คำสั่ง `add` เพื่อติดตั้งทักษะลงเครื่องพร้อมบันทึกเข้าสู่รายการอัปเดตอัตโนมัติได้ทันที:

### 🍎 บนระบบปฏิบัติการ macOS / Linux:
```bash
# กรณีระบุชื่อทักษะย่อยภายใน Repository
./relay-skills.sh add https://github.com/owner/repo-name ชื่อทักษะ "[ขั้นตอนที่ 3 @dev] คำอธิบายทักษะ"

# กรณีต้องการติดตั้งทั้ง Repository
./relay-skills.sh add https://github.com/owner/repo-name
```

### 🪟 บนระบบปฏิบัติการ Windows (PowerShell):
```powershell
.\relay-skills.ps1 add https://github.com/owner/repo-name ชื่อทักษะ "[ขั้นตอนที่ 3 @dev] คำอธิบายทักษะ"
```

**การทำงานของคำสั่ง `add`:**
1. ติดตั้งทักษะดังกล่าวเข้าสู่โฟลเดอร์ส่วนกลางของเครื่องผ่านคำสั่ง `npx skills add ... -g` (สคริปต์ล็อกเวอร์ชันไว้ที่ `skills@1.7.4` เปลี่ยนได้ด้วยตัวแปร `RELAY_SKILLS_CLI_PKG`)
2. บันทึกลิงก์ Repository และชื่อทักษะต่อท้ายลงในไฟล์ [`skills-manifest.txt`](../skills-manifest.txt) โดยอัตโนมัติ เพื่อให้การรันคำสั่ง `update` ในอนาคตทำการอัปเดตทักษะใหม่นี้ควบคู่ไปด้วยเสมอ

---

## 3. การตรวจสอบรายการทักษะทั้งหมดในคลัง (`list`)

```bash
# บน macOS / Linux
./relay-skills.sh list

# บน Windows PowerShell
.\relay-skills.ps1 list
```

---

## 4. การสร้างทักษะเฉพาะทางพร้อมสคริปต์เครื่องมือ (`Progressive Disclosure` & `Scripts as Tools`)

ตามแนวคิด **Anthropic Agent Skills** ระบบ `RELAY` รองรับการเปิดเผยข้อมูลทักษะแบบขั้นบันได (**Progressive Disclosure**) โดยสแกนเฉพาะหัว YAML Frontmatter (`name` และ `description`) พร้อมพาธไฟล์ `SKILL.md` และรายการสคริปต์ในโฟลเดอร์ `scripts/` เพื่อแนบเป็นสารบัญสั้นๆ ให้ Agent ทุกค่าย (`agy`, `claude`, `codex`) เห็นตรงกันโดยไม่เปลือง Context Window

คุณสามารถสร้างโครงสร้างทักษะมาตรฐาน (`SKILL.md` + โฟลเดอร์ `scripts/`) สำหรับโปรเจกต์ได้ด้วยคำสั่งเดียว:

```bash
# สร้างทักษะใหม่ใน .relay/skills/<skill-name>/ (หรือกด [s] -> เลือกข้อ 5 ในหน้าจอ relay)
./relay-skills.sh create company-api-standard "มาตรฐานการออกแบบ REST API และการจัดการข้อผิดพลาดขององค์กร"
```

คำสั่งดังกล่าวจะสร้างโฟลเดอร์ `.relay/skills/company-api-standard/` ประกอบด้วย:
1. **`SKILL.md`:** เอกสารขั้นตอนปฏิบัติงานพร้อม YAML Frontmatter (แนะนำความยาวไม่เกิน 150 บรรทัด):
```markdown
---
name: company-api-standard
description: มาตรฐานการออกแบบ REST API และการจัดการข้อผิดพลาดขององค์กร
---

# ข้อกำหนดการพัฒนา API ภายในองค์กร
1. กำหนดรูปแบบ Endpoint เป็น `/api/v1/<resource>` เสมอ
2. ข้อมูลตอบกลับ (Response) ต้องอยู่ในโครงสร้าง `{ success: boolean, data: any, error: string | null }`
3. รันสคริปต์ตรวจสอบในโฟลเดอร์ `scripts/run-check.sh` ก่อนส่งมอบงานทุกครั้ง
```
2. **`scripts/run-check.sh` (`Scripts as Tools`):** สคริปต์ตรวจสอบอัตโนมัติที่ Agent สามารถสั่งรันซ้ำผ่าน Bash ได้ทันทีโดยไม่ต้องเขียนคำสั่งตรวจใหม่ด้วยมือทุกครั้ง

---

## 5. รายการทักษะแม่แบบและสคริปต์เครื่องมือที่ติดตั้งมาพร้อมกับ `RELAY` (`templates/`)
นอกจากทักษะภายนอกใน `skills-manifest.txt` แล้ว สคริปต์ติดตั้ง (`setup-mac.sh` / `relay-skills.sh`) จะติดตั้งทักษะแม่แบบและสคริปต์เครื่องมือของ `RELAY` ลงใน `~/.agents/` ให้อัตโนมัติ ได้แก่:
- **`relay-verify-task`** (`templates/scripts/verify-relay-task.sh` ➔ `~/.agents/bin/relay-verify-task`): สคริปต์ตรวจสอบมาตรฐาน (ไม่เรียก AI) สำหรับตรวจเพดานบรรทัดเอกสาร (`SPEC.md` ≤40, `ARCH.md`+`PLAN.md` ≤60, `QA_REPORT.md` ≤30), ตรวจไฟล์ความลับต้องห้าม (`.env*`, `*.key`, `*.pem`, `*.sqlite*`, `*.db`) และตรวจ JSON Schema ของ `QA_VERDICT.json`
- **`relay-roles`** (`templates/relay-roles-SKILL.md`): หน้าที่และชุดทักษะของ `@po`, `@arch`/`@pm`, `@dev`, `@qa`/`@sec` — ย้ายออกจาก `GLOBAL_AGENTS.md` เพื่อไม่ให้ถูกโหลดทุก session • agent เปิดอ่านเมื่อผู้ใช้เรียกบทบาทเองใน CLI (หน้าจอ `relay` แนบหน้าที่ไว้ใน prompt แล้ว)
- **`flutter-best-practices`** (`templates/flutter-best-practices-SKILL.md`): มาตรฐานการพัฒนาแอปพลิเคชันด้วย Flutter & Dart (Dart 3 Null Safety, Widget Performance, State Management และการรัน `flutter analyze` + `flutter test`)
- **`playwright-qa`** (`templates/playwright-qa-SKILL.md`): ขั้นตอนการตรวจสอบคุณภาพ รันชุดทดสอบจริงของโปรเจกต์ การใช้ Playwright MCP เฉพาะเมื่อแก้ Web UI และการเขียน `QA_REPORT.md` คู่กับ `QA_VERDICT.json`
- **`lucide-icons` และ `simple-icons`**: มาตรฐานการใช้ไอคอนและสัญลักษณ์แบรนด์โดยไม่วาด `<svg>` ดิบเอง
