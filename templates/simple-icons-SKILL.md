---
name: simple-icons
description: มาตรฐานการใช้สัญลักษณ์แบรนด์และโลโก้บริการต่างๆ (Brand Logos) ด้วยแพ็กเกจ simple-icons สำหรับตัวแทน @dev ในระบบ RELAY
---

# มาตรฐานการใช้สัญลักษณ์แบรนด์ (`simple-icons`)

เมื่อต้องการแสดงโลโก้ของแบรนด์หรือบริการภายนอก (เช่น GitHub, Google, LINE, Facebook, Visa, PromptPay/ธนาคาร หรือค่ายเทคโนโลยี) ในบทบาท `@dev`:
1. **ห้ามวาด `<svg>` ของโลโก้แบรนด์ด้วยมือ** ให้ใช้แพ็กเกจมาตรฐาน `simple-icons` หรือ `@icons-pack/react-simple-icons` เสมอ
2. **การติดตั้งและใช้งาน:**
   - ติดตั้งแพ็กเกจ: `npm install simple-icons`
   - ดึง Path มาตรฐานจาก `simple-icons` เพื่อแสดงผลอย่างแม่นยำตาม Brand Guidelines ของเจ้าของเครื่องหมายการค้า
3. **การแยกบทบาทกับ `lucide-icons`:**
   - ไอคอนคำสั่งทั่วไปบนหน้าจอ (ปุ่มค้นหา, ตะกร้า, ถังขยะ, ปริ้นเตอร์) ➔ ใช้ **`lucide-react` (`lucide-icons`)**
   - สัญลักษณ์แบรนด์และโลโก้บริษัท ➔ ใช้ **`simple-icons`**
