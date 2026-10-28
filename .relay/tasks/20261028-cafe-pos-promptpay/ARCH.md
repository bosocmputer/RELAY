# 🏗️ แผนสถาปัตยกรรม (ARCH.md) — ไม้ที่ 2 (`@arch`)
- **รหัสใบงาน:** `20261028-cafe-pos-promptpay`
- **อ้างอิง:** `.relay/PROJECT_STATE.md` และ `SPEC.md`

## 1. การแยกส่วนประกอบ (Component Design)
1. **`examples/cafe-pos/pos-core.js` (Pure Logic Module — ES Module / UMD):**
   - แยกสูตรคำนวณออกจาก DOM 100% เพื่อให้ทั้งหน้าเว็บ `index.html` และตัวรันเทสต์ `pos-core.test.js` เรียกใช้ชุดโค้ดเดียวกัน
   - ฟังก์ชัน `calculateOrderSummary(items)`: รับอาร์เรย์ `{ id, name, price, qty }` คืนค่า `{ subtotal, vatRate: 0.07, vatAmount, netTotal, totalItems }`
   - ฟังก์ชัน `buildPromptPayPayload(promptPayId, netTotal)`: สร้าง Payload จำลองมาตรฐาน EMVCo / PromptPay พร้อมรหัสอ้างอิงบิล
2. **`examples/cafe-pos/pos-core.test.js` (0-Token Unit Tests):**
   - ใช้ `node:test` และ `node:assert/strict` ของ Node.js 20 ไม่ต้องลงไลบรารีหนักเครื่อง
3. **`examples/cafe-pos/index.html` (Frontend UI — `impeccable` + `lucide-icons`):**
   - มี `data-testid` และ `id` ชัดเจนทุกปุ่ม (`#menu-grid`, `#subtotal-val`, `#vat-val`, `#net-total-val`, `#btn-generate-qr`, `#qr-modal`) เพื่อให้ `@qa` ใช้ **Playwright MCP** กดทดสอบได้แม่นยำ 100%
