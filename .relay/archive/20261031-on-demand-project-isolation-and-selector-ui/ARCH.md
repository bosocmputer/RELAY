# สถาปัตยกรรมและการออกแบบเทคนิค (ARCH.md — 20261031-on-demand-project-isolation-and-selector-ui)

## 1. โครงสร้างโมดูลและไฟล์ที่แก้ไข/สร้างใหม่
- **`templates/GLOBAL_AGENTS.md`:**
  - เพิ่มหัวข้อ **"ขอบเขตการบังคับใช้แบบแยกโปรเจกต์ (On-Demand & Per-Project Activation Rule)"** ไว้บนสุดของไฟล์ เพื่อกำหนดให้ CLI (`agy`, `claude`, `codex`) ใช้ระบบทีม `.relay/` เฉพาะเมื่อตรวจพบโฟลเดอร์ `.relay/` ในโปรเจกต์ปัจจุบัน หรือเมื่อคำสั่งเริ่มต้นด้วย `@po`, `@arch`, `@pm`, `@dev`, `@qa`, `@sec` เท่านั้น หากเป็นโปรเจกต์ทั่วไปที่ไม่มี `.relay/` ให้ทำงานตามปกติทันที
- **`relay.sh`:**
  - `list_workspace_projects_tsv`: ฟังก์ชันช่วยสแกนโฟลเดอร์โปรเจกต์ใน `~/Projects`, `~/Projects`, `~/workspace`, `~/Developer` คัดแยกโปรเจกต์ที่มี `.relay/PROJECT_STATE.md` (หรือ `.relay/`) ขึ้นก่อนเสมอ พร้อมดึงชื่อ Task ปัจจุบันของแต่ละโปรเจกต์ คืนค่าเป็น TSV `has_relay \t name \t path \t task_info`
  - `select_or_create_project_dir`: แสดงรายการโปรเจกต์ด้วยป้ายสถานะด้านหน้าบรรทัด (`● [RELAY]` สีเขียว คู่กับ `○ [ทั่วไป]` สีเทา) จัดคอลัมน์ชื่อโปรเจกต์และ Path ให้ตรงกัน รองรับการเลือกได้สูงสุด 12 โปรเจกต์ และปรับถ้อยคำในเมนู Stage 2 / Footer ให้สั้นกระชับไม่เกิดสระลอยใน macOS Terminal.app
- **`README.md`, `docs/USE_CASES_NEW_AND_EXISTING.md`, `docs/ARCHITECTURE_DEEP_DIVE.md`:**
  - อัปเดตคำอธิบายเรื่อง On-Demand Per-Project Isolation (เปิดใช้เฉพาะโปรเจกต์ที่ต้องการ ไม่ปะปนและไม่บังคับใช้กับโปรเจกต์อื่นในเครื่อง) และตัวอย่างหน้าเลือกโปรเจกต์ใหม่
- **`tests/test_hermes_cli_redesign.sh`:**
  - เพิ่มเคสทดสอบ `list_workspace_projects_tsv`, การจัดลำดับโปรเจกต์ `● [RELAY]` ขึ้นก่อน `○ [ทั่วไป]`, และการตรวจสอบเงื่อนไข On-Demand ใน `templates/GLOBAL_AGENTS.md`
