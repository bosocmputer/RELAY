# ใบงานเก็บตก: กรองคำเตือน claude ใน Auto-Loop + ไฟล์ PowerShell อ่านภาษาไทยได้ (20261031-autoloop-filter-and-ps1-bom)
- **ที่มา:** งานค้างจากใบงานก่อน — (1) คำเตือน `Permission allow rule (...)` ของ claude ยังขึ้นตอนรัน Auto-Loop (2) ไฟล์ `.ps1` เป็น UTF-8 ไม่มี BOM ซึ่ง Windows PowerShell 5.1 อ่านข้อความภาษาไทยผิด
- **ข้อจำกัด:** ไม่มี PowerShell ในเครื่องทดสอบ — ตรวจได้เฉพาะไบต์ของไฟล์ ยังไม่ได้รันจริงบน Windows

## เกณฑ์ตรวจรับ (Acceptance Criteria)
- [ ] Auto-Loop ที่ใช้ claude ไม่แสดงคำเตือน `Permission allow rule (...)` แต่ข้อความ error อื่นยังแสดง และ exit code / timeout ทำงานเหมือนเดิม
- [ ] ไฟล์ `.ps1` ทุกไฟล์ขึ้นต้นด้วย UTF-8 BOM โดยเนื้อหาไม่เปลี่ยน
- [ ] ชุดทดสอบทั้งหมดผ่าน 0 ข้อผิดพลาด
