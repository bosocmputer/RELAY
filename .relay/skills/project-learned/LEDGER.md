# สมุดบัญชีประวัติการสกัดบทเรียนของโปรเจกต์ (RELAY Self-Learning Ledger — RELAY)

## [2026-10-29 12:32] ใบงาน `20261029-auto-loop-and-self-learning`
- จำนวนกฎสะสมทั้งหมดหลังควบรวม: **5/25 ข้อ** (เพิ่มใหม่ 5 ข้อ)
  - `+` ตรวจสอบ Pre-flight Guard: บังคับว่าต้องมีไฟล์ `.relay/tasks/<task-id>/SPEC.md` ที่มนุษย์อนุมัติแล้วก่อนเสมอ จึงจะเริ่มลูป `2 (@arch) ➔ 3 (@dev) ⇄ 4 (@qa)` ได้
  - `+` ตรวจสอบ **Circuit Breaker 1 (Quota Guard):** `check_role_quota_safe` ตรวจสอบโควต้าคงเหลือทั้งราย 5 ชั่วโมง (`5h`) และรายสัปดาห์ (`7d`) ของตำแหน่งถัดไป และหยุดลูปทันทีหากต่ำกว่าเกณฑ์ปลอดภัย `20%`
  - `+` ตรวจสอบ **Circuit Breaker 2 (Max Remediation Cap):** จำกัดรอบการส่งกลับไปแก้บั๊กระหว่าง `@dev ⇄ @qa` สูงสุดไม่เกิน `3 รอบ` พร้อมบันทึกประวัติทุกรอบลงใน `.relay/tasks/<task-id>/LOOP_LOG.md`
  - `+` ตรวจสอบ **Circuit Breaker 3 (Cross-Provider QA Verifier):** แยกผู้ตรวจรับ (`@qa` เช่น `codex`) ออกจากผู้เขียนโค้ด (`@dev` เช่น `agy`) และตัดสินผลจาก `VERDICT: PASS` / `VERDICT: FAIL` ใน `QA_REPORT.md`
  - `+` สกัดบทเรียนและกฎป้องกันข้อผิดพลาดซ้ำจาก `SPEC.md`, `ARCH.md`, และ `QA_REPORT.md` ลงใน `.relay/skills/project-learned/SKILL.md` (ควบรวมกฎไม่ให้ซ้ำและจำกัดเพดานไม่เกิน 25 ข้อเพื่อรักษา Context Window)

