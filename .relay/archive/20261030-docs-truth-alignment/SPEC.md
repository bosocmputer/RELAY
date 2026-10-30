# เอกสารกำหนดความต้องการ (SPEC.md)
- **รหัสใบงาน:** `20261030-docs-truth-alignment`
- **ชื่อใบงาน:** ปรับปรุงเอกสาร `README.md`, `docs/*`, และ `relay-init.*` ให้ตรงกับความจริงของระบบ 100% (ชี้แจงว่า Obsidian เป็นเพียง Optional Viewer, ย้ำว่าทุกบทบาทสลับค่าย/โมเดล AI ได้อิสระ, และลบคำสั่ง `gemini-cli` ที่เลิกใช้แล้วในเอกสารย่อย)
- **สถานะ:** ยืนยันแล้วโดยผู้ใช้ ("ปรับได้เลย ให้ตรงกับความจริง")

## 1. เป้าหมายและขอบเขตงาน
1. **ชี้แจงบทบาทของโปรแกรม Obsidian ให้ตรงความจริง:**
   - ระบบ `RELAY` ทำงานกับไฟล์ Markdown (`.md`) และ JSON ในโฟลเดอร์ `.relay/` โดยตรง ไม่ได้พึ่งพาหรือบังคับติดตั้งโปรแกรม Obsidian
   - โปรแกรม **Obsidian** เป็นเพียง **ทางเลือกเสริมสำหรับเปิดอ่านเอกสาร (Optional Markdown Viewer)** (ใช้ VS Code, Cursor หรือโปรแกรมอ่าน Markdown ใดก็ได้)
   - ปรับตารางองค์ประกอบหลักข้อที่ 2 ใน `README.md`, ขั้นตอนการติดตั้ง 3.1, หัวข้อที่ 5, รวมถึง `docs/INSTALL_ZERO_TO_HERO.md`, `docs/ARCHITECTURE_DEEP_DIVE.md`, `docs/USE_CASES_NEW_AND_EXISTING.md`, `relay-init.sh`, และ `relay-init.ps1` ให้ระบุชัดเจนว่า Obsidian เป็นทางเลือกเสริม ไม่ใช่โปรแกรมบังคับ
2. **ชี้แจงให้ชัดเจนว่าทั้ง 4 บทบาท (`@po`, `@arch`, `@dev`, `@qa`) สามารถเปลี่ยนค่ายและโมเดล AI ได้อย่างอิสระ:**
   - เพิ่มคำอธิบายชัดเจนตั้งแต่ตารางองค์ประกอบหลักและหัวข้อที่ 4 ใน `README.md` ว่าผู้ใช้สามารถกด `[c]` (`relay config`) เพื่อสลับค่าย (`agy`, `claude`, `codex`) และเลือกโมเดลให้แต่ละบทบาทได้อย่างอิสระ ไม่ได้ล็อกตายตัวตามค่าเริ่มต้น
3. **ลบการอ้างอิง `@google/gemini-cli` (`gemini`) ที่เลิกใช้แล้วออกจากเอกสารย่อยและสคริปต์เริ่มต้น:**
   - ลบคำสั่ง `npm install -g @google/gemini-cli` ออกจาก `docs/INSTALL_ZERO_TO_HERO.md`
   - ปรับ `docs/CUSTOM_DOMAINS_GUIDE.md` จาก `Claude, Codex, Gemini` เป็น `agy (Google AI Ultra), claude, codex`
   - ปรับข้อความแนะนำใน `relay-init.sh` และ `relay-init.ps1` จากการสั่งรัน `claude หรือ gemini` เป็นการพิมพ์คำสั่ง `relay` เพื่อเปิดหน้าจอควบคุมกลาง

## 2. เกณฑ์การตรวจรับงาน (Acceptance Criteria)
- [x] **AC-1:** `README.md` ตารางองค์ประกอบหลักข้อ 2 และหัวข้อติดตั้ง 3.1 ระบุชัดเจนว่า `.relay/` คือกลไกหลัก และ Obsidian เป็นเพียงโปรแกรมเสริม (Optional Viewer — ไม่บังคับติดตั้ง)
- [x] **AC-2:** `README.md` ระบุชัดเจนว่าทุกบทบาท (`@po`, `@arch`, `@dev`, `@qa`) สลับค่าย AI (`agy`, `claude`, `codex`) และโมเดลได้อย่างอิสระผ่านปุ่ม `[c]`
- [x] **AC-3:** ไม่มีคำสั่งติดตั้ง `@google/gemini-cli` หรือการแนะนำให้รัน `gemini` CLI ค้างอยู่ใน `docs/INSTALL_ZERO_TO_HERO.md`, `docs/CUSTOM_DOMAINS_GUIDE.md`, `relay-init.sh`, และ `relay-init.ps1`
