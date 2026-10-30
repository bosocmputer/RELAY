---
name: playwright-qa
description: ตรวจสอบคุณภาพโค้ด รันชุดทดสอบจริงของโครงการ และใช้ Playwright MCP ทดสอบส่วนติดต่อผู้ใช้บนเว็บพร้อมสรุป QA_REPORT.md และ QA_VERDICT.json
---

# ขั้นตอนการตรวจรับงานของ `@qa & @sec` (ขั้นตอนที่ 4)
1. อ่านเกณฑ์การตรวจรับงาน (Acceptance Criteria) จากไฟล์ `.relay/tasks/<task-id>/SPEC.md`
2. รันคำสั่งตรวจสอบโครงสร้างโค้ดและชุดทดสอบจริงของโครงการผ่าน Terminal ตามประเภทเทคโนโลยีของโปรเจกต์:
   - โครงการ Web / Node.js / TypeScript: รัน `npm test` (หรือ `pnpm test`) และคำสั่งตรวจสอบ Build / Type-check
   - โครงการ Flutter / Dart (`pubspec.yaml`): รัน `flutter analyze` และ `flutter test`
   - โครงการภาษาอื่น: รันคำสั่งทดสอบมาตรฐานที่ระบุไว้ใน `.relay/PROJECT_STATE.md`
3. เฉพาะกรณีที่ใบงานมีการแก้ไขส่วนติดต่อผู้ใช้บนเว็บ (Web UI) ตาม `SPEC.md`:
   - เรียกใช้เครื่องมือ **Playwright MCP** (`browser_navigate`, `browser_snapshot`, `browser_click`, `browser_take_screenshot`)
   - ทดสอบการใช้งานจริงตามเกณฑ์การตรวจรับงาน ตรวจสอบว่าไม่มีข้อผิดพลาดใน Console และบันทึกภาพหน้าจอไว้ที่ `.relay/tasks/<task-id>/screenshots/`
4. ตรวจสอบ `git diff` เพื่อให้มั่นใจว่าไม่มีช่องโหว่ความปลอดภัยหรือไฟล์ความลับ (`.env*`, `*.key`, `*.pem`) หลุดรอด จากนั้นเขียนผลลัพธ์ 2 ไฟล์ (ห้ามแก้ไข `.relay/PROJECT_STATE.md`):
   - `.relay/tasks/<task-id>/QA_REPORT.md` (ความยาวไม่เกิน 30 บรรทัด พร้อมระบุบรรทัด `VERDICT: PASS` หรือ `VERDICT: FAIL` เพียงบรรทัดเดียว)
   - `.relay/tasks/<task-id>/QA_VERDICT.json` ในรูปแบบ `{"verdict": "PASS" หรือ "FAIL", "failed_criteria": [], "tests_run": ["คำสั่งที่รันจริง"], "summary": "สรุปสั้น"}`
