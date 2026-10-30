# เพิ่มทักษะ Flutter/Dart (`flutter-best-practices`) และปรับปรุงความสอดคล้องทั้งโครงการ (`20261030-flutter-skill-and-project-sync`)

## 1. เป้าหมาย (Objective)
- สร้างชุดทักษะ `templates/flutter-best-practices-SKILL.md` สำหรับการพัฒนาแอปพลิเคชันด้วยภาษา Flutter / Dart และเชื่อมเข้ากับ `@dev` และ `@qa`
- เพิ่มกฎ Ground-Truth Check ของ `@arch` และการรัน Static Analysis (`flutter analyze` / `tsc` / `lint`) ก่อน commit ของ `@dev` ตามหลัก `dair-ai/prompt-engineering-guide`
- ปรับปรุงไฟล์ที่ยังคลาดเคลื่อนจากการสแกนทั้งโปรเจกต์ (`templates/playwright-qa-SKILL.md`, `setup-mac.sh`, `setup-win.ps1`, `relay-skills.sh`, `relay-skills.ps1`, `relay-init.sh`, และเอกสารใน `docs/`) ให้ตรงกันทั้งหมด

## 2. เกณฑ์การตรวจรับงาน (Acceptance Criteria)
- [ ] AC-1: มีไฟล์ `templates/flutter-best-practices-SKILL.md` และติดตั้งเข้าสู่ `~/.agents/skills/flutter-best-practices/SKILL.md` พร้อมแสดงในทักษะของ `@dev`
- [ ] AC-2: `GLOBAL_AGENTS.md`, `playwright-qa-SKILL.md`, และ `relay.sh` มีคำสั่งสอดคล้องกันครบทุกตำแหน่ง (รวมถึงการรองรับ `flutter analyze` + `flutter test` และการเขียน `QA_VERDICT.json`)
- [ ] AC-3: สคริปต์ติดตั้ง (`setup-mac.sh`, `setup-win.ps1`, `relay-skills.sh`, `relay-skills.ps1`, `relay-init.sh`) และเอกสาร `docs/*.md` อัปเดตตรงกับความสามารถปัจจุบัน และผ่านชุดทดสอบ `tests/test_*.sh` ครบทุกข้อ
