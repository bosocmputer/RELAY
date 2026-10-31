# ใบงานแก้ไขปัญหาระดับ HIGH จากผลตรวจ Deep Audit (20261031-high-severity-fixes)
- **ที่มา:** รายงาน Deep Code, Security & UX Audit วันที่ 2026-10-31 (กลุ่ม CRITICAL / HIGH ข้อ H1–H9)
- **ขอบเขต:** แก้เฉพาะ `relay.sh`, `setup-mac.sh`, `relay-skills.sh`, `templates/pre-commit`, เพิ่ม `templates/hook-passthrough`, เพิ่มชุดทดสอบ และหมายเหตุในเอกสารติดตั้ง
- **นอกขอบเขต:** ไฟล์ Windows (`*.ps1`), ข้อ MEDIUM / PERFORMANCE / ANTI-OVERCLAIM (ทำในใบงานถัดไป)
- **ข้อจำกัด:** ห้ามเพิ่มขั้นตอนหรือเอกสารบังคับใหม่ให้ผู้ใช้, คงสถาปัตยกรรม Bash + Python 3 เดิม, ต้องรันได้บน `/bin/bash` 3.2

## เกณฑ์ตรวจรับ (Acceptance Criteria)
- [ ] H1: `interactive_menu` แบบไม่มี TTY เมื่อเจอ EOF ต้องคืนค่า `b` (ไม่เลือกข้อแรกเอง) และ `relay 5 </dev/null` ต้องไม่ merge
- [ ] H1: ลูปหลักของ hub ต้องออกเมื่อ stdin หมด (ไม่วนไม่รู้จบ)
- [ ] H8: กด Ctrl+C ขณะอยู่ในเมนูหรือช่องพิมพ์ของ relay ต้องออกโปรแกรม (exit 130) และคืนเคอร์เซอร์
- [ ] H8: กด Ctrl+C ขณะ CLI ของ agent ทำงานอยู่ ต้องไม่ปิด relay (Auto-Loop ยังบันทึก STOP ได้)
- [ ] H5: ตั้ง default model ของ codex ต้องเขียน `model` ระดับบนสุดของ TOML เสมอ (ไม่ตกไปอยู่ในตารางสุดท้าย) และอ่านเฉพาะระดับบนสุด
- [ ] H6: ถ้า `~/.claude/settings.json` อ่านไม่ผ่าน ต้องไม่เขียนทับไฟล์และแจ้ง error
- [ ] H7: ชื่อโปรเจกต์ที่กรองแล้วว่าง (เช่นภาษาไทย หรือ `..`) ต้องไม่ใช้โฟลเดอร์ workspace เป็นโปรเจกต์
- [ ] H2: `setup-mac.sh` ต้องสำรองไฟล์กฎเดิม (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `GLOBAL_AGENTS.md` ที่ถูกแก้) ก่อนแทนที่
- [ ] H3: hook ของ repo เดิม (`.git/hooks/*`) ต้องยังทำงานต่อหลังตั้ง global `core.hooksPath` และไม่ทับ `core.hooksPath` ที่ผู้ใช้ตั้งไว้เอง
- [ ] H4: pre-commit ต้องอนุญาตการลบไฟล์ความลับ, อนุญาต `.env.example/.sample/.template/.schema` และใช้กฎชุดเดียวกับ `relay.sh`
- [ ] H9: `npx` ใน `relay-skills.sh` ต้องล็อกเวอร์ชัน (ปรับได้ผ่านตัวแปรสภาพแวดล้อม)
- [ ] ชุดทดสอบเดิมทั้งหมดผ่าน + ชุดทดสอบใหม่ครอบคลุมทุกข้อข้างต้น และ `bash -n` ผ่านทุกสคริปต์
