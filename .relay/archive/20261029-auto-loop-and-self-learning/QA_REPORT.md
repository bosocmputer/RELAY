# รายงานผลการตรวจสอบคุณภาพและความปลอดภัย (QA & Security Report — 20261029-auto-loop-and-self-learning)

- **VERDICT: PASS**
- **สถานะ:** ผ่านการตรวจรับครบทุกเกณฑ์ (Acceptance Criteria 100%)

## 1. ผลการตรวจสอบโครงสร้างและการทำงานจริง (Functional & Loop Verification)
- ทดสอบ `bash -n relay.sh` ผ่านสมบูรณ์ (`Exit Code 0`)
- ทดสอบระบบ **Bounded Auto-Relay Loop (`[a]` / `/loop` / `relay loop`)**:
  - ตรวจสอบ Pre-flight Guard: บังคับว่าต้องมีไฟล์ `.relay/tasks/<task-id>/SPEC.md` ที่มนุษย์อนุมัติแล้วก่อนเสมอ จึงจะเริ่มลูป `2 (@arch) ➔ 3 (@dev) ⇄ 4 (@qa)` ได้
  - ตรวจสอบ **Circuit Breaker 1 (Quota Guard):** `check_role_quota_safe` ตรวจสอบโควต้าคงเหลือทั้งราย 5 ชั่วโมง (`5h`) และรายสัปดาห์ (`7d`) ของตำแหน่งถัดไป และหยุดลูปทันทีหากต่ำกว่าเกณฑ์ปลอดภัย `20%`
  - ตรวจสอบ **Circuit Breaker 2 (Max Remediation Cap):** จำกัดรอบการส่งกลับไปแก้บั๊กระหว่าง `@dev ⇄ @qa` สูงสุดไม่เกิน `3 รอบ` พร้อมบันทึกประวัติทุกรอบลงใน `.relay/tasks/<task-id>/LOOP_LOG.md`
  - ตรวจสอบ **Circuit Breaker 3 (Cross-Provider QA Verifier):** แยกผู้ตรวจรับ (`@qa` เช่น `codex`) ออกจากผู้เขียนโค้ด (`@dev` เช่น `agy`) และตัดสินผลจาก `VERDICT: PASS` / `VERDICT: FAIL` ใน `QA_REPORT.md`
- ทดสอบระบบ **Self-Learning Project Skills (`[l]` / `/learn` / `relay learn`)**:
  - สกัดบทเรียนและกฎป้องกันข้อผิดพลาดซ้ำจาก `SPEC.md`, `ARCH.md`, และ `QA_REPORT.md` ลงใน `.relay/skills/project-learned/SKILL.md` (ควบรวมกฎไม่ให้ซ้ำและจำกัดเพดานไม่เกิน 25 ข้อเพื่อรักษา Context Window)
  - บันทึกสมุดบัญชีประวัติการเรียนรู้แบบ Append-Only ลงใน `.relay/skills/project-learned/LEDGER.md`
  - ผูกเข้ากับขั้นตอนที่ `[5] Merge & Archive` ให้สกัดบทเรียนอัตโนมัติก่อนเก็บใบงานเข้า `.relay/archive/` และแนบไฟล์ `.relay/skills/project-learned/SKILL.md` เข้าสู่ Prompt ของ `@arch`, `@dev`, และ `@qa` ในใบงานถัดไปอัตโนมัติ

## 2. บทเรียนและกฎสถาปัตยกรรมที่สกัดได้จากใบงานนี้ (Distilled Engineering Guardrails)
- การรัน `Bounded Auto-Relay Loop` (`[a]` / `/loop`) ต้องบังคับให้มีเอกสาร `SPEC.md` จากขั้นตอนที่ 1 (`@po`) ก่อนเสมอ เพื่อให้มนุษย์เป็นผู้กำหนดทิศทางและขอบเขตงาน (Human-Anchored Outer Loop)
- ก่อนรันแต่ละขั้นตอนในลูปอัตโนมัติ ต้องเรียก `check_role_quota_safe` เพื่อตรวจสอบว่าโควต้าคงเหลือทั้ง 5 ชั่วโมง (`5h`) และรายสัปดาห์ (`7d`) ไม่ต่ำกว่า `20%` เพื่อป้องกันการเผาผลาญโควต้าจนหมดเกลี้ยง
- การวนลูปแก้บั๊กระหว่าง `@dev ⇄ @qa` ต้องจำกัดเพดานสูงสุดไม่เกิน 3 รอบ (`max_rounds=3`) และใช้ผู้ตรวจรับคนละค่าย/เซสชัน (`Cross-Provider Verification`) ที่ตัดสินผลผ่าน `VERDICT: PASS` หรือ `VERDICT: FAIL` ใน `QA_REPORT.md`
- ระบบ `Self-Learning Project Skills` (`[l]` / `/learn`) ต้องเขียนเฉพาะลงใน `.relay/skills/project-learned/SKILL.md` (จำกัดเพดานไม่เกิน 25 ข้อ) และ `.relay/skills/project-learned/LEDGER.md` โดยห้ามแก้ไขไฟล์กฎส่วนกลาง `~/.agents/GLOBAL_AGENTS.md` โดยเด็ดขาด
- เมื่อรันคำสั่ง `agy -p "/usage"` ผ่าน Subprocess Pipe (Non-TTY) ระบบจะส่งออกเป็นรูปแบบ TSV พร้อมเวลา ISO-8601 UTC จึงต้องรองรับการแปลงเวลา UTC เป็นเวลาท้องถิ่นและตั้งค่า `timeout=15` วินาทีเสมอ

## 3. การตรวจสอบความปลอดภัย (Security Audit — Differential Review)
- ตรวจสอบ `git diff` แล้ว ไม่พบการเข้าถึงหรือบันทึกไฟล์ความลับ (`.env*`, `*.key`, `*.pem`, `*.sqlite`, `*.db`)
- ระบบ Self-Learning มีขอบเขตป้องกันตัวเอง (`Self-Authored Only Boundary`) ไม่แตะต้องไฟล์กฎส่วนกลางของผู้ใช้
