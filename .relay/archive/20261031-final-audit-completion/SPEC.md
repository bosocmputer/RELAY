# เอกสารกำหนดความต้องการ (SPEC.md)
- **รหัสใบงาน:** `20261031-final-audit-completion`
- **วันที่:** 2026-10-31

## 1. เป้าหมายและขอบเขตงาน (Objective & Scope)
เก็บงานส่วนที่เหลือจากรายงาน Deep Audit ให้ครบสมบูรณ์ 100% โดยไม่เพิ่ม Ceremony Overhead และไม่มีคำกล่าวอ้างเกินจริง:
1. **เชื่อม Skills เข้ากับ `~/.claude/skills/` (`setup-mac.sh`, `relay-skills.sh`, `setup-win.ps1`, `relay-skills.ps1`):** สร้างลิงก์รายโฟลเดอร์จาก `~/.agents/skills/<name>` ไปยัง `~/.claude/skills/<name>` เพื่อให้ Claude Code มองเห็นทักษะเป็น Native Skill โดยไม่เขียนทับโฟลเดอร์จริงที่ผู้ใช้สร้างไว้เอง
2. **ล้างคำ Over-claiming และอัปเดตสถานะใน `.relay/PROJECT_STATE.md`:** แก้ไขถ้อยคำ 12 จุดที่ยังมีคำว่า `เรียลไทม์`, `Real-Time`, `อ่านสด`, `0 Token`, `0-Token`, `Token จริง`, `100%`, `คุ้มค่าสูงสุด` และอัปเดตจำนวนชุดทดสอบ (`12 ชุดทดสอบ`) พร้อมเพิ่ม `.relay/PROJECT_STATE.md` เข้าสแกนใน `tests/test_performance_and_accuracy.sh`
3. **อัปเดตตัวเลขชุดทดสอบใน `README.md` และตรวจรับด้วย `QA_REPORT.md` + `QA_VERDICT.json`:** รันครบทุกชุดทดสอบและตรวจด้วย `verify-relay-task.sh`

## 2. เกณฑ์ตรวจรับ (Acceptance Criteria)
- **AC-1:** `setup-mac.sh` และ `relay-skills.sh` เชื่อม `~/.claude/skills/<name>` ไปยัง `~/.agents/skills/<name>` โดยไม่ทับโฟลเดอร์จริงของผู้ใช้
- **AC-2:** `tests/test_performance_and_accuracy.sh` สแกนรวม `.relay/PROJECT_STATE.md` และไม่พบคำอ้างเกินจริงแม้แต่จุดเดียว
- **AC-3:** ชุดทดสอบทั้งหมด 12 ชุดผ่านครบทุกข้อ พร้อม `QA_REPORT.md` และ `QA_VERDICT.json` สถานะ `PASS`
