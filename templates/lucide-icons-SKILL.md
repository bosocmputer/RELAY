---
name: lucide-icons
description: มาตรฐานการใช้ไอคอนส่วนติดต่อผู้ใช้ (UI Icons) ด้วยแพ็กเกจ lucide-react / lucide สำหรับตัวแทน @dev ในระบบ RELAY
---

# มาตรฐานการใช้ไอคอนส่วนติดต่อผู้ใช้ (`lucide-icons` / `lucide-react`)

เมื่อพัฒนาส่วนติดต่อผู้ใช้ (Web UI) ในบทบาท `@dev`:
1. **ห้ามเขียนโค้ด `<svg>` วาดไอคอนขึ้นเองโดยไม่มีมาตรฐาน** เพื่อป้องกันไอคอนเพี้ยนและลดการใช้ Token โดยไม่จำเป็น
2. **การติดตั้งและเรียกใช้งาน (React / Next.js / Vite):**
   - ติดตั้งแพ็กเกจ: `npm install lucide-react` (หรือ `pnpm add lucide-react`)
   - นำเข้าเฉพาะไอคอนที่ใช้งานแบบ Tree-shakable:
     ```tsx
     import { Plus, Trash2, Check, Search, ShoppingCart, Printer, AlertTriangle } from "lucide-react";
     ```
3. **แนวทางการกำหนดขนาดและเส้นขอบให้สม่ำเสมอ:**
   - ใช้ขนาดมาตรฐาน `className="w-4 h-4"` (ปุ่มย่อย/Badge) หรือ `className="w-5 h-5"` (ปุ่มหลัก/เมนู)
   - กำหนด `strokeWidth={2}` (หรือ `1.75` สำหรับ UI ที่เน้นความโปร่งสะอาดตา) ให้เหมือนกันทั้งหน้าจอ
   - ใส่ `aria-hidden="true"` สำหรับไอคอนประดับที่มีข้อความกำกับอยู่แล้ว
