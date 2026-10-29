# SPEC.md — ปรับปรุงเอกสารทั้งหมดในโครงการ RELAY ให้ตรงกับเวอร์ชันล่าสุด (Guided 3-Stage UX + Google AI Ultra `agy`)
*วันที่: 2026-10-29 • รหัสใบงาน: `20261029-docs-latest-sync`*

## 1. ขอบเขตการปรับปรุงเอกสาร
1. **`README.md`:**
   - อัปเดตหน้าจอตัวอย่าง `relay` ให้เป็นหน้าจอ **Guided 3-Stage Progressive UX (Monochrome Blue)** เวอร์ชันล่าสุด
   - อัปเดตรายชื่อค่าย AI ที่รองรับให้ครอบคลุมทั้ง **`agy` (Google AI Ultra / Antigravity CLI)**, **`claude` (Claude Code)**, **`codex` (OpenAI Codex CLI)** และ **`gemini` (ผ่าน API Key)**
   - อธิบายระบบตรวจสอบความพร้อมจริง 3 ชั้น (ติดตั้ง CLI + Login บัญชี + ดึงรายชื่อโมเดลสดจาก CLI) และระบบนำทาง 3 ขั้นตอนอัตโนมัติ
2. **`docs/INSTALL_ZERO_TO_HERO.md`:**
   - เพิ่มคำแนะนำการเชื่อมต่อโควต้า **Google AI Ultra** ผ่าน `agy` (`~/.gemini/bin/agy`) ควบคู่กับ `claude` และ `codex`
3. **`docs/USE_CASES_NEW_AND_EXISTING.md`:**
   - อัปเดตขั้นตอนการใช้งานตามระบบนำทาง **3 ขั้นตอนอัตโนมัติ (Stage 1 ➔ Stage 2 ➔ Stage 3)**
4. **`docs/ARCHITECTURE_DEEP_DIVE.md`:**
   - เพิ่มหัวข้อสถาปัตยกรรม **Guided 3-Stage Progressive Disclosure & 3-Layer CLI Readiness Verification**
