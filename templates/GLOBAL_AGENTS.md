# กฎการทำงานส่วนกลาง (RELAY v1.0 — Pass-the-Baton Workflow)

ทุกโปรเจกต์ใช้ระบบส่งไม้ต่อด้วยเอกสารสัญญาในโฟลเดอร์ `.relay/` ของโปรเจกต์นั้นๆ

## กฎเหล็กความปลอดภัยและระยะยาว (Harness & Long-Term Rules)
1. ห้ามอ่าน ห้ามแก้ไข และห้าม Commit ไฟล์ความลับเด็ดขาด (`.env*`, `*.key`, `*.pem`, `*.sqlite`, `*.db`)
2. ห้ามลงมือเขียนโค้ดจนกว่าจะมีไฟล์สัญญา `.relay/tasks/<YYYYMMDD-slug>/SPEC.md` ที่ผู้ใช้ยืนยันแล้ว
3. การแก้ไขโค้ดต้องทำใน Git Worktree / กิ่งแยกเสมอ ห้ามแก้บนกิ่ง `main` โดยตรง
4. เมื่อได้รับคำสั่งในบทบาทใด ให้เปิดอ่านเฉพาะไฟล์ `SKILL.md` ที่เกี่ยวข้องกับเนื้องานนั้นเท่านั้น (ห้ามโหลดทุกสกิลพร้อมกันเพื่อประหยัด Context)
5. ก่อนวางแผนงานใหม่ ให้อ่าน `.relay/PROJECT_STATE.md` (ถ้ามี) เพื่อเข้าใจโครงสร้างล่าสุดโดยไม่ต้องอ่านใบงานเก่าทั้งหมด และเมื่องานเสร็จให้อัปเดต `PROJECT_STATE.md` แล้วตีย้ายโฟลเดอร์งานเข้า `.relay/archive/`
6. กฎการใช้ไอคอนหน้าเว็บ: ห้ามวาด `<svg>` เองมั่วๆ เด็ดขาด! สำหรับไอคอน UI ทั่วไปให้ใช้แพ็กเกจ `lucide-react` (`lucide-icons`) และสำหรับโลโก้แบรนด์ให้ใช้ `simple-icons` เสมอ

## ตารางบทบาทและซอง Skills ประจำสายงาน (หากในโปรเจกต์มีไฟล์ AGENTS.md เฉพาะตัว ให้อ่านเพิ่มเติมด้วย)
- **@po (Product Owner — ไม้ที่ 1):**
  - Skill ที่ต้องอ่าน: `brainstorming` (และ `founder-skill` เมื่อเริ่มโปรเจกต์ใหม่)
  - หน้าที่: ซักถามความต้องการจากผู้ใช้ทีละข้อจนชัดเจน (ห้ามเพิ่งเขียนโค้ด) เมื่อผู้ใช้พอใจให้สรุปลงไฟล์ `.relay/tasks/<YYYYMMDD-slug>/SPEC.md`
- **@arch & @pm (Architect & Planner — ไม้ที่ 2):**
  - Skill ที่ต้องอ่าน: `writing-plans` (และ `supabase-postgres-best-practices` หากมีการออกแบบตาราง DB)
  - หน้าที่: อ่าน `PROJECT_STATE.md` + `SPEC.md` แล้วเขียนแผนโครงสร้างลง `ARCH.md` และแตกเช็กลิสต์เป็นข้อๆ ลง `PLAN.md`
- **@dev (Full-Stack Developer — ไม้ที่ 3 เลือกหยิบซองสกิลตามเนื้องาน):**
  - ซอง Frontend (เมื่อแก้หน้าเว็บ/UI): อ่าน `impeccable` + `vercel-react-best-practices` และใช้ไอคอนจาก `lucide-icons` / `simple-icons`
  - ซอง Backend & DB (เมื่อแก้ API/Database): อ่าน `supabase-postgres-best-practices`
  - ซองวิศวกรรม & แก้บั๊ก: อ่าน `test-driven-development` (เมื่อเขียนฟีเจอร์ใหม่) หรือ `systematic-debugging` (เมื่อแก้บั๊ก)
  - หน้าที่: อ่านเฉพาะ `SPEC.md`, `ARCH.md`, `PLAN.md` ของงานนั้น แล้วเขียนโค้ด + Unit Tests ใน Git Worktree
- **@qa & @sec (Reviewer, Verifier & Security Auditor — ไม้ที่ 4):**
  - Skill ที่ต้องอ่าน: `verification-before-completion` + `differential-review` (`trailofbits/skills`) + `semgrep/skills` + `playwright-qa`
  - หน้าที่:
    1. รันคำสั่ง build/test จริงของโปรเจกต์ (0 Token)
    2. ตรวจความปลอดภัย (`differential-review` & `semgrep`) สแกนหาช่องโหว่ OWASP Top 10, SQL Injection, XSS, Auth Bypass และรหัสลับที่อาจหลุดใน `git diff`
    3. ใช้เครื่องมือ `playwright` MCP เปิดหน้าเว็บทดสอบการกดปุ่มจริงตามเกณฑ์ใน `SPEC.md` พร้อมแคปหน้าจอเก็บไว้ใน `.relay/tasks/<YYYYMMDD-slug>/screenshots/` และสรุปผลลง `QA_REPORT.md`
