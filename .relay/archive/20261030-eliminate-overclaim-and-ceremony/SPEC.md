# กำจัดข้อความ Over-Claiming ที่ตกค้างและคุมเพดาน Ceremony Overhead ทุกเส้นทาง (`20261030-eliminate-overclaim-and-ceremony`)

## 1. เป้าหมาย (Objective)
- ตัดข้อความ Over-claiming ที่ยังตกค้างในสคริปต์และเอกสาร (`ปลอดภัย 100%`, `พร้อมใช้ทันที 100%`, `แนะนำสูงสุด`, `Zero-Ceremony`, `100% agy`, `ฟรี 100%`)
- บังคับเพดานความกระชับ (Anti-Ceremony Overhead) ให้ครบทุกเส้นทางใน `relay.sh` รวมถึง `run_auto_relay_loop` (`ARCH.md`+`PLAN.md` ≤60 บรรทัด, `QA_REPORT.md` ≤30 บรรทัด) และ `run_custom_agent_task`

## 2. เกณฑ์การตรวจรับงาน (Acceptance Criteria)
- [ ] AC-1: `templates/pre-commit`, `relay.sh`, `relay.ps1`, `README.md`, และ `docs/*.md` ไม่มีคำกล่าวอ้างเกินจริง (`ปลอดภัย 100%`, `พร้อมใช้ทันที 100%`, `แนะนำสูงสุด`, `Zero-Ceremony`)
- [ ] AC-2: Prompt ใน `run_auto_relay_loop` และ `run_custom_agent_task` กำหนดเพดานความยาวเอกสารและห้ามเขียนเนื้อหาเยิ่นเย้อเกินจำเป็น
- [ ] AC-3: ชุดทดสอบอัตโนมัติทั้งหมดใน `tests/test_*.sh` ผ่านครบทุกข้อ
