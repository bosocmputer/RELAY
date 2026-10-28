---
name: playwright-qa
description: ตรวจสอบโค้ด รันเทสต์ด้วยสคริปต์จริง และใช้ Playwright MCP กดทดสอบหน้าเว็บพร้อมแคปภาพหน้าจอหลักฐาน
---

# ขั้นตอนการตรวจรับงานของ @qa (ไม้ที่ 4)
1. อ่านเกณฑ์ตรวจรับงาน (Acceptance Criteria) จาก `.relay/tasks/<task-id>/SPEC.md`
2. รันคำสั่ง build และ unit test ของโปรเจกต์ผ่าน Terminal (ขั้นตอนนี้ใช้สคริปต์ 0 Token)
3. หากเป็นงานที่มีหน้าเว็บ (UI):
   - เรียกใช้เครื่องมือ **Playwright MCP** (`browser_navigate`, `browser_snapshot`, `browser_click`, `browser_take_screenshot`)
   - ทดสอบกดใช้งานจริงตามเกณฑ์ AC ทุกข้อ และตรวจว่าไม่มี Console Error
   - บันทึกภาพหน้าจอหลักฐานไว้ที่ `.relay/tasks/<task-id>/screenshots/`
4. ตรวจสอบ `git diff` ว่าไม่มีไฟล์ `.env` หรือการแก้ไขนอกขอบเขต แล้วสรุปผลลง `.relay/tasks/<task-id>/QA_REPORT.md`
