---
name: flutter-best-practices
description: แนวทางปฏิบัติและมาตรฐานวิศวกรรมสำหรับการพัฒนาแอปพลิเคชันด้วยภาษา Flutter และ Dart (Dart 3, State Management, Widget Performance และการทดสอบ)
---

# มาตรฐานการพัฒนาแอปพลิเคชันด้วย Flutter & Dart (`flutter-best-practices`)

เปิดอ่านและปฏิบัติตามข้อกำหนดนี้เมื่อโครงการมีไฟล์ `pubspec.yaml` หรือเป็นงานพัฒนาด้วยภาษา **Flutter / Dart**:

## 1. การตรวจสอบโครงสร้างเดิมก่อนลงมือทำ (Ground-Truth Discovery)
1. อ่านไฟล์ `pubspec.yaml` และ `analysis_options.yaml` ก่อนเสมอ เพื่อตรวจสอบเวอร์ชันของ Dart SDK, แพ็กเกจจัดการสถานะ (เช่น `flutter_riverpod`, `flutter_bloc`, `provider`, `get_it`), ระบบนำทาง (`go_router` หรือ `Navigator`), และโครงสร้างโฟลเดอร์ของโปรเจกต์
2. ห้ามติดตั้งแพ็กเกจใหม่ซ้ำซ้อนกับเครื่องมือที่มีอยู่แล้วใน `pubspec.yaml` โดยไม่จำเป็น

## 2. มาตรฐานภาษา Dart 3 และความปลอดภัยของชนิดข้อมูล (Type Safety)
1. **Strict Null Safety:** ห้ามใช้ตัวดำเนินการ `!` (Bang operator) โดยไม่มีการตรวจสอบค่า `null` ล่วงหน้า และหลีกเลี่ยงการใช้ `dynamic` หรือ `late` หากสามารถกำหนดค่าเริ่มต้นหรือใช้ Nullable Type ได้อย่างปลอดภัย
2. **Modern Dart 3:** ใช้ `final` หรือ `const` สำหรับตัวแปรที่ไม่เปลี่ยนแปลงค่า, ใช้ `sealed class` ร่วมกับ `switch` expression (Exhaustive Pattern Matching) สำหรับจัดการสถานะของหน้าจอ (`Loading`, `Data`, `Error`) และใช้ `records` หรือคลาสที่มีเมธอด `copyWith` สำหรับข้อมูลที่ไม่เปลี่ยนแปลง (Immutable Data)

## 3. ประสิทธิภาพการวาดหน้าจอและโครงสร้าง Widget (Widget & Rendering Performance)
1. **`const` Constructors:** ใส่ `const` หน้า Constructor และ Widget ทุกจุดที่ค่าพารามิเตอร์คงที่ เพื่อให้ Flutter ข้ามการสร้าง Widget ซ้ำขณะ Rebuild
2. **แยก Widget เป็นคลาสย่อย แทนการสร้างฟังก์ชันคืนค่า Widget:** ห้ามเขียนเมธอดประเภท `Widget _buildCard()` ยาวๆ ภายในคลาสเดียว ให้แยกออกเป็นคลาส `StatelessWidget` หรือ `StatefulWidget` ย่อยที่มี `Key` ชัดเจน เพื่อจำกัดขอบเขตการ Rebuild เฉพาะส่วนที่ข้อมูลเปลี่ยน
3. **การจัดการรายการข้อมูลและการคืนทรัพยากร:**
   - ใช้ `ListView.builder`, `GridView.builder` หรือ `SliverList` สำหรับรายการข้อมูลที่มีโอกาสยาวเกินหน้าจอ (ห้ามใช้ `Column` + `.map().toList()` กับรายการขนาดใหญ่)
   - ใน `StatefulWidget` ต้องยกเลิกและคืนทรัพยากร (`dispose()`) ของ `TextEditingController`, `ScrollController`, `FocusNode`, `AnimationController`, และ `StreamSubscription` ในเมธอด `dispose()` ทุกครั้ง
   - ตรวจสอบ `if (!context.mounted) return;` ก่อนเรียกใช้ `BuildContext` หลังคำสั่ง `await` ทุกครั้ง

## 4. สถาปัตยกรรม การแยกชั้นข้อมูล และส่วนติดต่อผู้ใช้ (Architecture & UI)
1. แยกโค้ดส่วนแสดงผล (`UI / Widgets`) ออกจากตรรกะทางธุรกิจ (`Controller / Notifier / Bloc`) และส่วนดึงข้อมูล (`Repository / Data Source`) อย่างชัดเจน ห้ามเขียนคำสั่งเรียก API หรือฐานข้อมูลโดยตรงภายในเมธอด `build()`
2. รองรับการแสดงผลหลายขนาดหน้าจอและพื้นที่ปลอดภัยด้วย `SafeArea`, `MediaQuery.sizeOf(context)`, หรือ `LayoutBuilder` และจัดการสถานะกำลังโหลด/ข้อผิดพลาดให้ผู้ใช้เห็นชัดเจนเสมอ
3. สำหรับไอคอนใน Flutter ให้ใช้แพ็กเกจไอคอนที่โปรเจกต์ติดตั้งไว้ (เช่น `lucide_icons` หรือ `Icons` มาตรฐานของ Material/Cupertino) ห้ามฮาร์ดโค้ดข้อมูล SVG ดิบขนาดใหญ่ในโค้ด Widget

## 5. การตรวจสอบคุณภาพและชุดทดสอบบังคับก่อนส่งงาน (Mandatory Verification)
ก่อนทำการ `git commit` หรือสรุปจบงาน ต้องรันคำสั่งต่อไปนี้ผ่าน Terminal ให้ผ่านจริง:
1. ตรวจสอบไวยากรณ์และกฎ Linter: `flutter analyze` (ต้องไม่พบข้อผิดพลาด `No issues found!`)
2. รันชุดทดสอบ Unit / Widget Tests: `flutter test`
