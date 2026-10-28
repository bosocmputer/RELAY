# 📋 แผนงานเช็กลิสต์ (PLAN.md) — ไม้ที่ 2 (`@pm`)
- **รหัสใบงาน:** `20261028-cafe-pos-promptpay`

## ลำดับงานสำหรับ `@dev` (ไม้ที่ 3) และ `@qa` (ไม้ที่ 4)
- [x] **Task 1 (TDD Core):** สร้างไฟล์ `examples/cafe-pos/pos-core.js` และเขียน Unit Test ใน `examples/cafe-pos/pos-core.test.js` ทดสอบการคำนวณ Subtotal, VAT 7%, Net Total และการป้องกันค่าติดลบ
- [x] **Task 2 (Frontend UI):** สร้างหน้าเว็บ `examples/cafe-pos/index.html` ตามหลัก UI สะอาดตา (`impeccable`) ใช้ไอคอนจาก `lucide` แสดงรายการเมนู ตะกร้าสินค้า และหน้าต่าง PromptPay QR
- [x] **Task 3 (Dashboard Integration):** สร้างหน้า `dashboard/index.html` (`RELAY Board & Token Saver`) เพื่อแสดงสถานะใบงานนี้ครบทั้ง 4 ไม้และเชื่อมลิงก์เปิดหน้า POS
- [x] **Task 4 (QA & Security Verification):** รัน `node --test examples/cafe-pos/pos-core.test.js` (0 Token) + ตรวจความปลอดภัยว่าไม่มี `.env` หรือ XSS + บันทึกผลลง `QA_REPORT.md`
