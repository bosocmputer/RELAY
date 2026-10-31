# ใบงานแก้จุดที่ตกหล่นจากใบงาน 20261031-final-audit-completion (20261031-fix-claude-skill-links-and-records)
- **ที่มา:** ตรวจงานของ Gemini 4 Argon — PROJECT_STATE.md ไม่ได้ถูกแก้, ชุดทดสอบได้ 215/216 แต่บันทึกว่า 216/216, การลิงก์ skill 29 ตัวเข้า `~/.claude/skills` เพิ่มคำอธิบาย ~12K ตัวอักษรเข้าทุก session ของ Claude Code
- **ผู้ใช้อนุญาต:** แก้ `.relay/PROJECT_STATE.md` และบันทึก QA ของใบงานที่ archive แล้วในครั้งนี้ (ยกเว้นกฎปกติ)
- **ข้อจำกัด:** ห้ามเพิ่มขั้นตอนบังคับ, คง Bash + Python 3, `/bin/bash` 3.2

## เกณฑ์ตรวจรับ (Acceptance Criteria)
- [ ] การลิงก์ skill เข้า `~/.claude/skills` เป็นแบบเลือกเปิดเอง (`RELAY_LINK_CLAUDE_SKILLS=all` หรือรายชื่อ) • ค่าเริ่มต้นไม่ลิงก์ และลบเฉพาะลิงก์ที่ชี้เข้า `~/.agents/skills`
- [ ] ไม่ลิงก์ skill ที่เป็น alias (symlink ใน `~/.agents/skills`) • ไม่แตะโฟลเดอร์จริงหรือ symlink ของผู้ใช้ที่ชี้ไปที่อื่น
- [ ] Windows: เลือกเปิดเองเหมือนกัน • คัดลอกทั้งโฟลเดอร์ • ข้ามโฟลเดอร์ที่ RELAY ไม่ได้สร้าง
- [ ] `install_interrupt_traps` เรียกซ้ำแล้วไม่ห่อ trap ซ้อน
- [ ] `.relay/PROJECT_STATE.md` ไม่มีคำอ้างเกินจริง และจำนวนชุดทดสอบตรงผลรันจริง
- [ ] บันทึก QA ของใบงาน `20261031-final-audit-completion` ระบุผลจริง • README / docs ตรงผลรันจริง
- [ ] ชุดทดสอบทั้งหมดผ่าน 0 ข้อผิดพลาด (นับจากผลรันจริง)
