# ใบงานปรับความเร็ว ลด Token และแก้ข้อความอ้างเกินจริง (20261031-performance-and-accuracy-cleanup)
- **ที่มา:** รายงาน Deep Audit 2026-10-31 กลุ่ม PERFORMANCE / ANTI-CEREMONY / ANTI-OVERCLAIM + TEST GAP ของ `test_phase5_merge.sh`
- **ข้อจำกัด:** ห้ามเพิ่มขั้นตอนหรือเอกสารบังคับใหม่, คง Bash + Python 3, รันได้บน `/bin/bash` 3.2 และ Python 3.9
- **นอกขอบเขต:** `.relay/PROJECT_STATE.md` (กฎห้าม AI แก้ — แจ้งผู้ใช้แทน)

## เกณฑ์ตรวจรับ (Acceptance Criteria)
- [ ] P1: ผลตรวจ Login ของ claude / codex ถูกแคชในโปรเซสเดียวกัน 60 วินาที และรีเฟรชทันทีหลังสั่ง login
- [ ] P2: `update_codex_quota_fast` ไม่เรียก python ซ้ำเมื่อ session log ของ codex ไม่เปลี่ยน
- [ ] P3: `GLOBAL_AGENTS.md` เหลือเฉพาะกฎที่ใช้ทุก session • หน้าที่ของแต่ละบทบาทย้ายไป skill `relay-roles` ที่เปิดอ่านเมื่อจำเป็น และติดตั้งทั้ง macOS / Windows
- [ ] P4: นับ Token ของ claude / codex เฉพาะ session ในโฟลเดอร์ที่รันขั้นตอนนั้น • agy (ไม่มีข้อมูลโฟลเดอร์) แสดงว่าเป็นค่าประมาณ
- [ ] P5: ไม่พบข้อมูล Token แสดงว่า "ไม่พบข้อมูล" แทน "0 tokens" และ RUN_LOG ระบุว่าไม่พบ
- [ ] ข้อความ UI ใน `relay.sh` / `relay.ps1` / `relay-init.sh` / สคริปต์ ไม่มีคำว่า เรียลไทม์ / Real-Time / Live Sync / 0-Token ในจุดที่ไม่จริง และบอกผลข้างเคียงของ Deep Codex Sync
- [ ] สรุปโควต้าไม่บอกว่า "ทุกตำแหน่งพร้อม" เมื่อมีค่ายใดต่ำกว่า 20% • ตรวจ Login ของ agy ไม่ใช้แค่การมีโฟลเดอร์
- [ ] เอกสาร README / docs ตรงกับพฤติกรรมปัจจุบัน และไม่มีคำอ้างเกินจริงข้างต้น
- [ ] `test_phase5_merge.sh` แยก HOME + ใช้ CLI จำลอง + โฟลเดอร์ชั่วคราวที่ลบเองเมื่อจบ
- [ ] ชุดทดสอบเดิมทั้งหมดผ่าน + ชุดทดสอบใหม่ครอบคลุม P1–P5 และข้อความ
