# ใบงาน: RELAY เลือก skill ที่ต้องอ่านจากไฟล์โปรเจกต์ (20261102-required-skills-by-stack)
- **ปัญหา (จาก session log จริงของ WEB_WHAT_RELAY):** @po (agy), @arch และ @dev (claude 8 session) ไม่ได้เปิด SKILL.md เลย เช่น impeccable ในงานหน้าเว็บ • มีแค่ @qa (codex) ที่เปิด
- **สาเหตุ:** prompt ให้ skill เป็นสารบัญ พร้อมคำว่า "เปิดอ่านเฉพาะเมื่อตรงกับงานนี้" ➔ AI ข้ามไป
- **ข้อจำกัด:** เลือกด้วยสคริปต์ ไม่เรียก AI • เลือกเฉพาะ skill ที่อยู่ในชุดทักษะของตำแหน่งนั้นและติดตั้งแล้ว (เคารพที่ผู้ใช้ปรับใน [g])

## เกณฑ์ตรวจรับ (Acceptance Criteria)
- [ ] เลือก skill จากไฟล์ในโปรเจกต์และเอกสารใบงาน (SPEC/ARCH/PLAN):
  - @dev: test-driven-development เสมอ • งานหน้าเว็บ ➔ impeccable + lucide-icons • React/Next ➔ vercel-react-best-practices • Flutter ➔ flutter-best-practices • Supabase/Postgres/SQL ➔ supabase-postgres-best-practices • มี QA_REPORT ที่ไม่ผ่าน ➔ systematic-debugging
  - @po: brainstorming เสมอ • โปรเจกต์ยังไม่มีโค้ด ➔ founder-skill
  - @arch: writing-plans เสมอ • ฐานข้อมูล ➔ supabase-postgres-best-practices
  - @qa: verification-before-completion + differential-review เสมอ • งานหน้าเว็บ ➔ playwright-qa
- [ ] prompt บอกว่า "ก่อนเริ่มงานต้องเปิดอ่าน" พร้อมพาธ SKILL.md ของ skill ที่เลือก • skill อื่นในชุดยังเป็นสารบัญแบบเดิม
- [ ] มีชุดทดสอบครอบคลุมการเลือกแต่ละแบบ และชุดทดสอบเดิมผ่านทั้งหมด
