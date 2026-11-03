# ใบงาน: QA ลู่เข้า — ตัดสินตามระดับความร้ายแรง • รอบแก้ตรวจเฉพาะ diff • ใช้ EVIDENCE ก่อน • หยุดเมื่อไม่ลู่เข้า (20261103-qa-convergence)
- **ปัญหา (KepTohPOS):** QA FAIL 8 รอบติด แต่ละรอบเจอจุดใหม่ 1–2 ข้อ เพราะตรวจทั้งแอป (110 ไฟล์) ทุกรอบ ข้อเล็กก็ FAIL ทั้งรอบ และ 2 รอบหลัง FAIL เพราะ sandbox ทั้งที่ EVIDENCE.log ผ่าน
- **อ้างอิงแนวทางชุมชน:** severity gate (CRITICAL/HIGH บล็อก, ที่เหลือ follow-up), "no failing test, no bug", re-review เฉพาะ diff + carry-over, ตรวจการลู่เข้าด้วยสคริปต์

## เกณฑ์ตรวจรับ (Acceptance Criteria)
- [ ] QA_VERDICT.json รูปแบบใหม่มี `findings` (severity, criterion, where, issue, repro, carry_over) และ `follow_ups` • สคริปต์ตัดสินเอง: FAIL เฉพาะเมื่อมี critical/high ที่มี repro • ไม่มี finding ที่บล็อก ➔ PASS แม้ AI เขียน FAIL (แสดงเหตุผล) • ยังรองรับรูปแบบเดิม (failed_criteria)
- [ ] PASS ต้องมีหลักฐานเทสต์: tests_run ไม่ว่าง หรือ EVIDENCE.log ผ่าน • EVIDENCE ไม่ผ่าน ➔ FAIL เหมือนเดิม
- [ ] prompt ของ QA: ข้อจำกัดของ sandbox/สภาพแวดล้อมไม่ใช่ข้อบกพร่อง ใช้ EVIDENCE.log แทน • รอบแรกรายงานทุกข้อในรอบเดียว
- [ ] รอบแก้ (QA รอบก่อน FAIL): prompt ให้ตรวจเฉพาะ `git diff <commit ที่ QA ตรวจล่าสุด>..HEAD` + ยืนยันข้อเดิม • ข้อใหม่นอก diff เป็น follow_ups เว้นแต่ critical • QA_HISTORY บันทึก commit ที่ตรวจ และจำนวนข้อที่บล็อก
- [ ] FAIL ≥3 รอบติดและจำนวนข้อที่บล็อกไม่ลดลง ➔ interactive ไม่แนะนำส่ง @dev ซ้ำเป็นค่าเริ่มต้น • loop หยุดพร้อมเหตุผล
- [ ] relay-verify-task รับรูปแบบใหม่ • สกัดบทเรียนอ่าน findings ได้ • ขั้น 5 แสดงจำนวน follow_ups • ชุดทดสอบทั้งหมดผ่าน
