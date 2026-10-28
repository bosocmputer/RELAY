---
name: playwright-qa
description: ตรวจสอบคุณภาพโค้ด รันชุดทดสอบด้วยสคริปต์ระบบ และใช้ Playwright MCP ทดสอบการทำงานของส่วนติดต่อผู้ใช้พร้อมบันทึกภาพหน้าจอหลักฐาน
---

# ขั้นตอนการตรวจรับงานของ @qa (ขั้นตอนที่ 4)
1. อ่านเกณฑ์การตรวจรับงาน (Acceptance Criteria) จากไฟล์ `.relay/tasks/<task-id>/SPEC.md`
2. รันคำสั่ง build และ unit test ของโครงการผ่าน Terminal (ขั้นตอนนี้ประมวลผลด้วยสคริปต์ของระบบ 0 Token)
3. หากเป็นงานที่เกี่ยวข้องกับส่วนติดต่อผู้ใช้บนเว็บ (Web UI):
   - เรียกใช้เครื่องมือ **Playwright MCP** (`browser_navigate`, `browser_snapshot`, `browser_click`, `browser_take_screenshot`)
   - ทดสอบการใช้งานจริงตามเกณฑ์การตรวจรับงานทุกข้อ และตรวจสอบว่าไม่มีข้อผิดพลาดใน Console (Console Error)
   - บันทึกภาพหน้าจอเพื่อใช้เป็นหลักฐานการตรวจสอบไว้ที่ `.relay/tasks/<task-id>/screenshots/`
4. ตรวจสอบ `git diff` เพื่อให้มั่นใจว่าไม่มีไฟล์ความลับ (`.env`) หรือการแก้ไขโค้ดนอกเหนือขอบเขตที่กำหนด จากนั้นสรุปผลการตรวจสอบลงในไฟล์ `.relay/tasks/<task-id>/QA_REPORT.md`
