# 📌 สถานะปัจจุบันของโปรเจกต์ (PROJECT_STATE.md)
*อัปเดตล่าสุด: 2026-10-28 • ความยาวไม่เกิน 2 หน้าเพื่อให้ `@arch/@pm` อ่านเข้าใจโครงสร้างทันทีโดยไม่ต้องย้อนอ่านใบงานเก่า*

## 1. ภาพรวมโปรเจกต์ (`RELAY Starter Kit & Demo Sandbox`)
Repo นี้ประกอบด้วย:
1. **ชุดติดตั้งส่วนกลาง (`setup-mac.sh` & `templates/`):** ติดตั้ง `~/.agents/GLOBAL_AGENTS.md`, `playwright-qa`, และ Global Git `pre-commit` hook
2. **โปรเจกต์ตัวอย่างที่ 1 (`dashboard/index.html`):** หน้า `RELAY Board & Token Saver` แสดงสถานะใบงานทั้ง 4 ไม้และคำนวณค่า Token ที่ประหยัดได้
3. **โปรเจกต์ตัวอย่างที่ 2 (`examples/cafe-pos/`):** ระบบ `Mini Cafe POS + PromptPay QR` คำนวณยอดสั่งซื้อ + VAT 7% + สร้าง QR พร้อมเพย์ พร้อมชุด Unit Test (`node --test`) ที่รันด้วย 0 Token

## 2. โครงสร้างโมดูลและไฟล์สำคัญล่าสุด
- `examples/cafe-pos/pos-core.js`:
  - `MENU_ITEMS`: รายการสินค้า (กาแฟและเบเกอรี่)
  - `calculateOrderSummary(cartItems)`: คำนวณ `subtotal`, `vatAmount` (7% ปัดเศษทศนิยม 2 ตำแหน่ง), และ `netTotal`
  - `buildPromptPayPayload(promptPayId, netTotal)`: สร้างข้อมูลสรุปสำหรับแสดง QR พร้อมเพย์แบบล็อกยอดเงิน
- `examples/cafe-pos/pos-core.test.js`:
  - ชุด Unit Test มาตรฐาน (`node:test` + `node:assert`) ตรวจสอบความถูกต้องของ VAT 7% และยอดสุทธิ
- `examples/cafe-pos/index.html`:
  - หน้า UI คิดเงินร้านกาแฟ มีปุ่มกดเพิ่ม/ลดสินค้า ตะกร้าคำนวณ VAT 7% อัตโนมัติ และปุ่มเปิด Modal สแกนจ่าย PromptPay QR

## 3. กฎเกณฑ์เฉพาะของโปรเจกต์นี้
- การรันเทสต์หลักใช้คำสั่ง: `node --test examples/cafe-pos/pos-core.test.js` (0 Token)
- หน้าเว็บทั้ง `dashboard/index.html` และ `examples/cafe-pos/index.html` ต้องเปิดผ่านเบราว์เซอร์หรือให้ `Playwright MCP` เข้าตรวจสอบได้ทันทีโดยไม่ต้องพึ่งพา `.env` ลับ
