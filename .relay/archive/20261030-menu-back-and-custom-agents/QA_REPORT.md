# QA Report — `20261030-menu-back-and-custom-agents`

## 1. ผลการทดสอบอัตโนมัติ (Automated Test Suite)
- `bash -n relay.sh` ➔ **PASS** (0 syntax errors)
- `bash tests/test_custom_agents_and_back_nav.sh` ➔ **PASS (9/9 ข้อ)**
- `bash tests/test_token_telemetry.sh` ➔ **PASS (8/8 ข้อ)**
- `bash tests/test_auto_loop.sh < /dev/null` ➔ **PASS (24/24 ข้อ)**
- `bash tests/test_merge_safety.sh` ➔ **PASS (22/22 ข้อ)**
- `bash tests/test_quota_display.sh` ➔ **PASS (6/6 ข้อ)**
- **รวมทั้งหมด:** ผ่าน **69 / 69 ข้อ** (0 ไม่ผ่าน)

## 2. การตรวจสอบตามเกณฑ์ (Acceptance Criteria & Security)
- **AC-1 (ปุ่ม `[b] ย้อนกลับ` และ `ESC` ทุกเมนูและช่องรับข้อความ):** ทดสอบแล้วว่า `choose_model_interactive`, `choose_provider_interactive`, `interactive_menu`, และช่องรับข้อความทั้งหมดรองรับ `b` / `ESC` เพื่อย้อนกลับโดยไม่เปลี่ยนค่าเดิม
- **AC-2 & AC-3 (การปรับแต่ง 4 ตำแหน่งหลัก + การเพิ่ม/แก้ไข/ลบ Agent ตำแหน่งใหม่):** ทดสอบแล้วว่า `[g]` (`/agents` / `relay agents`) รองรับการตั้งชื่อบทบาท, คำสั่ง Prompt, ทักษะ (`Skills`), และค่าย/Model ทั้งระดับ Global (`~/.agents/custom-agents.json`) และ Project (`.relay/custom-agents.json`)
- **AC-4 & AC-5 (การสั่งรัน + วัด Token + ภาษาทางการ):** ทดสอบการสั่งรัน Custom Agent ใน `Git Worktree`, บันทึก Token ลง `RUN_LOG.jsonl`, และตรวจสอบว่าไม่มีคำว่า `"ศูนย์จัดการ"` ในโค้ดและเอกสาร
- **Security Audit:** ส่งค่า JSON ผ่าน `sys.argv` ใน `python3` ไม่มีช่องโหว่ Command Injection และไม่มีไฟล์ความลับใน `git diff`

VERDICT: PASS
