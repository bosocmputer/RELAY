# สถาปัตยกรรมและการออกแบบทางเทคนิค (ARCH.md)
- **รหัสใบงาน:** `20261030-docs-truth-alignment`

## 1. ไฟล์ที่ต้องแก้ไขใน Git Worktree
1. `README.md`:
   - ตารางหัวข้อที่ 2 (องค์ประกอบหลักข้อ 2): เปลี่ยนจาก `Obsidian + โฟลเดอร์ .relay/` เป็น `โฟลเดอร์ .relay/ (Markdown & JSON State) • เปิดดูด้วย Editor ใดก็ได้ หรือใช้ Obsidian (ตัวเลือกเสริม)`
   - ตารางหัวข้อที่ 2 (องค์ประกอบหลักข้อ 3): ระบุชัดเจนว่าสลับค่าย (`agy`, `claude`, `codex`) และโมเดลประจำตำแหน่งได้อิสระทุกบทบาทผ่านปุ่ม `[c]`
   - หัวข้อที่ 3.1 (การติดตั้งพื้นฐาน): แยก `brew install --cask obsidian` / `winget install Obsidian` ออกเป็นคอมเมนต์ทางเลือกเสริม (Optional) เพื่อไม่ให้เข้าใจผิดว่าเป็นโปรแกรมบังคับก่อนรัน `RELAY`
   - หัวข้อที่ 4.1: เน้นย้ำว่า **ทั้ง 4 บทบาทไม่ได้ล็อกตายตัวกับค่ายใดค่ายหนึ่ง** สามารถกด `[c]` สลับค่ายและโมเดลได้ตลอดเวลา (เช่น เมื่อโควต้าค่ายใดใกล้หมด)
   - หัวข้อที่ 5: เปลี่ยนชื่อหัวข้อเป็น `5. การเปิดดูเอกสารใน .relay/ ด้วยโปรแกรม Obsidian (ทางเลือกเสริม — ไม่บังคับติดตั้ง)`
2. `docs/ARCHITECTURE_DEEP_DIVE.md`:
   - ปรับ Sequence Diagram บรรทัดที่ 30 จาก `โฟลเดอร์เอกสาร (.relay/ & Obsidian)` เป็น `โฟลเดอร์เอกสาร (.relay/ Markdown & JSON)` และระบุในบทที่ 2 ว่าแต่ละบทบาทสลับค่าย/โมเดลได้อิสระ
3. `docs/INSTALL_ZERO_TO_HERO.md`:
   - ปรับหัวข้อส่วนที่ 2 ให้ระบุชัดเจนว่า Obsidian เป็น **ทางเลือกเสริม (Optional Viewer — ไม่บังคับติดตั้ง)**
   - ลบ `@google/gemini-cli` (`gemini`) ออกจากส่วนที่ 3.2 ให้เหลือเฉพาะ `agy`, `claude`, และ `codex`
4. `docs/USE_CASES_NEW_AND_EXISTING.md` และ `docs/CUSTOM_DOMAINS_GUIDE.md`:
   - ปรับการกล่าวถึง Obsidian ใน `USE_CASES_NEW_AND_EXISTING.md` ให้ระบุว่าเป็นทางเลือกเสริม
   - ปรับรายชื่อค่ายใน `CUSTOM_DOMAINS_GUIDE.md` เป็น `agy (Google AI Ultra), claude, codex`
5. `relay-init.sh` และ `relay-init.ps1`:
   - ปรับข้อความแนะนำหลังสร้าง `.relay/` ให้แนะนำการพิมพ์คำสั่ง `relay` แทนการคัดลอกคำสั่งไปรันใน `claude หรือ gemini` แบบเก่า และระบุว่า Obsidian เป็นทางเลือกเสริม
