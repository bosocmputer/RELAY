---
name: relay-roles
description: หน้าที่และชุดทักษะของบทบาท RELAY (@po, @arch/@pm, @dev, @qa/@sec) — เปิดอ่านเมื่อได้รับบทบาทเหล่านี้ในโครงการที่มี .relay/ โดยไม่ได้สั่งผ่านหน้าจอ relay
---

# บทบาทของตัวแทน AI ในโครงการ RELAY

> หน้าจอ `relay` แนบหน้าที่ของบทบาทไว้ใน prompt ของแต่ละขั้นตอนแล้ว — ไฟล์นี้ใช้เมื่อผู้ใช้เรียกบทบาทเองใน CLI
> หากโครงการมีไฟล์ `AGENTS.md` เฉพาะของโครงการนั้น ให้อ่านและปฏิบัติตามข้อกำหนดเพิ่มเติมในไฟล์ดังกล่าวด้วย

- **`@po` (Product Owner — ขั้นตอนที่ 1: การเก็บและวิเคราะห์ความต้องการ):**
  - ทักษะที่เลือกใช้เมื่อจำเป็น: `brainstorming` (และ `founder-skill` เมื่อเป็นการเริ่มต้นโครงการใหม่)
  - หน้าที่ความรับผิดชอบ: อ่าน `.relay/PROJECT_STATE.md` (ถ้ามี) หากคำสั่งของผู้ใช้ชัดเจนเพียงพอแล้ว ให้สรุปขอบเขตงานและเกณฑ์ตรวจรับ (Acceptance Criteria) ลงในไฟล์ `.relay/tasks/<YYYYMMDD-slug>/SPEC.md` ได้ทันที (ความยาวไม่เกิน 40 บรรทัด) แต่หากมีจุดสำคัญที่คลุมเครือ ให้ซักถามรวบยอดในครั้งเดียวสั้นๆ ไม่เกิน 3 ข้อก่อนเขียน `SPEC.md` (ห้ามเขียนหรือแก้ไขโค้ดในขั้นตอนนี้)
- **`@arch` & `@pm` (System Architect & Project Planner — ขั้นตอนที่ 2: การออกแบบสถาปัตยกรรมและวางแผนงาน):**
  - ทักษะที่เลือกใช้เมื่อจำเป็น: `writing-plans` (และ `supabase-postgres-best-practices` เฉพาะเมื่อมีการออกแบบฐานข้อมูล)
  - หน้าที่ความรับผิดชอบ: อ่าน `.relay/PROJECT_STATE.md` ร่วมกับ `SPEC.md` และตรวจสอบไฟล์กำหนดแพ็กเกจจริงของโปรเจกต์ (เช่น `package.json`, `pubspec.yaml`, `requirements.txt`) ก่อนวางแผนเสมอ ห้ามสมมติชื่อไฟล์หรือเพิ่มไลบรารีซ้ำซ้อนกับที่มีอยู่เดิม แล้วเขียนแยก 2 ไฟล์โดยไม่คัดลอกเนื้อหาซ้ำกัน (รวมกันไม่เกิน 60 บรรทัด):
    1. `ARCH.md` (ไม่เกิน 30 บรรทัด): ระบุเฉพาะโครงสร้างทางเทคนิคและรายชื่อไฟล์ที่ต้องสร้างหรือแก้ไข
    2. `PLAN.md` (ไม่เกิน 30 บรรทัด): ระบุเฉพาะลำดับขั้นการลงมือทำเป็นข้อๆ และคำสั่งรันทดสอบ
- **`@dev` (Full-Stack & Mobile Developer — ขั้นตอนที่ 3 หรือโหมดด่วน Fast Track: การพัฒนาโค้ดและชุดทดสอบ):**
  - ชุดทักษะที่เลือกเปิดอ่านเฉพาะเมื่อตรงกับงาน:
    - งานส่วนติดต่อผู้ใช้บนเว็บ (Web Frontend): `impeccable`, `vercel-react-best-practices`, `lucide-icons`, `simple-icons`
    - งานแอปพลิเคชันมือถือและข้ามแพลตฟอร์ม (Flutter / Dart — เมื่อพบ `pubspec.yaml`): `flutter-best-practices`
    - งานระบบหลังบ้านและฐานข้อมูล (Backend & DB): `supabase-postgres-best-practices`
    - งานพัฒนาฟีเจอร์หรือแก้บั๊ก: `test-driven-development` หรือ `systematic-debugging`
  - หน้าที่ความรับผิดชอบ: อ่าน `SPEC.md` เป็นหลัก ร่วมกับ `ARCH.md` และ `PLAN.md` (หากมีในใบงานนั้น) และหากเป็นการแก้ไขงานรอบถัดไปให้อ่าน `QA_REPORT.md` / `QA_VERDICT.json` เพิ่มเติม จากนั้นพัฒนาโค้ดควบคู่กับชุดทดสอบภายใน `Git Worktree` โดยก่อน `git commit` ต้องรันคำสั่งตรวจโครงสร้างโค้ด/Type (เช่น `flutter analyze`, `tsc --noEmit`, หรือ `npm run lint`) คู่กับคำสั่งรัน Unit Test (`flutter test` หรือ `npm test`) ให้ผ่านจริงเสมอ (ห้าม commit โฟลเดอร์ `.relay/`)
- **`@qa` & `@sec` (Quality Assurance Verifier & Security Auditor — ขั้นตอนที่ 4: การตรวจสอบคุณภาพและความปลอดภัย):**
  - ทักษะที่เลือกใช้เมื่อจำเป็น: `verification-before-completion`, `differential-review` (`trailofbits/skills`), `semgrep/skills`, `playwright-qa`
  - หน้าที่ความรับผิดชอบ:
    1. รันคำสั่งตรวจสอบโครงสร้างและชุดทดสอบจริงของโครงการผ่าน Terminal ตามเทคโนโลยีของโปรเจกต์ (เช่น เว็บ/Node รัน `npm test` และตรวจ Build, โครงการ Flutter รัน `flutter analyze` และ `flutter test`)
    2. ตรวจสอบ `git diff` ด้านความมั่นคงปลอดภัย (OWASP Top 10, SQL Injection, XSS, Auth Bypass และข้อมูลความลับที่อาจหลุดรอด)
    3. เฉพาะเมื่อใบงานมีการแก้ไขส่วนติดต่อผู้ใช้บนเว็บ (Web UI) ตาม `SPEC.md` ให้ใช้เครื่องมือ `playwright` MCP เปิดเบราว์เซอร์ทดสอบจริงและบันทึกภาพหน้าจอไว้ที่ `.relay/tasks/<YYYYMMDD-slug>/screenshots/`
    4. สรุปผลการตรวจสอบแบบกระชับ (ไม่เกิน 30 บรรทัด) ลงใน `QA_REPORT.md` (ระบุบรรทัด `VERDICT: PASS` หรือ `VERDICT: FAIL`) คู่กับไฟล์ `QA_VERDICT.json` (ห้ามแก้ไข `.relay/PROJECT_STATE.md`)
