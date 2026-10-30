# รายงานผลการตรวจสอบคุณภาพและความปลอดภัย (QA_REPORT)
- **รหัสใบงาน:** `20261031-on-demand-project-isolation-and-selector-ui`
- **วันที่ตรวจรับ:** 2026-10-31

## 1. ผลการตรวจสอบเกณฑ์ตรวจรับ (Acceptance Criteria)
- **AC-1 (On-Demand & Per-Project Isolation):** ผ่าน — `templates/GLOBAL_AGENTS.md` กำหนดชัดเจนว่าพิธีกรรม 4 ขั้นตอน (`SPEC.md` + `Git Worktree`) ใช้เฉพาะในโปรเจกต์ที่มี `.relay/` หรือเมื่อเรียก `@po`/`@arch`/`@dev`/`@qa` เท่านั้น โปรเจกต์ทั่วไปทำงานได้ปกติโดยไม่มี Ceremony Overhead
- **AC-2 (Categorized Project Selector UI):** ผ่าน — `list_workspace_projects_tsv` และ `select_or_create_project_dir` จัดเรียงโปรเจกต์ที่มี `.relay/` (`● [RELAY]` สีเขียว พร้อมสถานะใบงาน) ไว้ด้านบนสุดเสมอ แยกจากโฟลเดอร์ทั่วไป (`○ [ทั่วไป]` สีเทา) และปรับข้อความเมนู Stage 2 ลดคำสระอำเพื่อป้องกันสระแตกบน macOS Terminal.app
- **AC-3 (Documentation & Automated Tests):** ผ่าน — อัปเดต `README.md`, `docs/USE_CASES_NEW_AND_EXISTING.md`, `docs/ARCHITECTURE_DEEP_DIVE.md` และชุดทดสอบ `tests/test_hermes_cli_redesign.sh` ครบถ้วน

## 2. การตรวจสอบความปลอดภัย (Security Audit)
- ไม่พบการแก้ไขหรือบันทึกไฟล์ความลับ (`.env*`, `*.key`, `*.pem`, `*.sqlite`, `*.db`)

VERDICT: PASS
