# SPEC: อุดช่องโหว่ด้านความปลอดภัยและยกระดับความเสถียรของระบบหลัก (Core Security & Reliability Hardening)

## 1. เป้าหมาย (Objective)
ปิดช่องโหว่ด้านความปลอดภัย (`SEC-1`..`SEC-3`) และจุดเสี่ยงด้านความเสถียรของระบบ (`REL-1`..`REL-5`) ใน `relay.sh` และ `relay-init.sh` เพื่อให้ระบบ RELAY ทำงานได้อย่างปลอดภัย ไม่รันโค้ดแปลกปลอมจากไฟล์ตั้งค่า ไม่เกิดไฟล์พังเมื่อทำงานพร้อมกัน และป้องกันไฟล์ความลับหลุดเข้า Git

## 2. ขอบเขตงาน (Scope)
1. **Security Hardening (`SEC-1`..`SEC-3`):**
   - `SEC-1`: ยกเลิกการใช้ `source` กับไฟล์ `roles.conf` และ `relay-quota.cache` เปลี่ยนมาใช้ฟังก์ชันอ่านค่า `KEY="VALUE"` แบบ Safe Parser (`safe_load_roles_conf`, `safe_load_quota_cache`) ที่ไม่ตีความคำสั่ง Shell (`$(...)`, `` ` ``, `;`) พร้อม `sanitize_model_id`
   - `SEC-2`: เปลี่ยนการสร้าง `SPEC.md` ใน `run_fast_track_dev` และ `PROJECT_STATE.md` ใน `relay-init.sh` ให้ใช้ `printf` แทน `cat <<EOF` เพื่อป้องกัน Backtick / Command Expansion
   - `SEC-3`: ปรับปรุง `set_cli_default_model` ให้ตรวจรูปแบบชื่อโมเดลและอัปเดต JSON/TOML แบบ Atomic Write แทนการใช้ `sed`
2. **Reliability & Git Worktree Hardening (`REL-1`..`REL-5`):**
   - `REL-1`: เขียนไฟล์สถานะและแคชทั้งหมดแบบ Atomic (`tempfile` + `os.replace` / `mv -f`) พร้อม Lock ป้องกัน Background Quota Refresh ชนกัน
   - `REL-2`: สั่ง `git worktree prune` อัตโนมัติใน `prepare_task_worktree` ก่อนสร้าง Worktree ใหม่
   - `REL-3`: บล็อกและคัดกรองไฟล์ความลับ/ฐานข้อมูล (`.env*`, `*.key`, `*.pem`, `*.sqlite*`, `*.db`) ใน `run_phase_5_merge` ไม่ให้ถูก Auto-Commit หรือผสานเข้า `main`
   - `REL-4`: ส่งสัญญาณหยุดไปยัง Child Process Tree (`pkill -P "$pid"`) ใน `run_with_timeout`
   - `REL-5`: ป้องกันชื่อ Task ซ้ำในวันเดียวกันใน `create_new_task` (ต่อท้าย `-2`, `-3` อัตโนมัติเมื่อพบชื่อซ้ำใน `tasks/` หรือ `archive/`)

## 3. เกณฑ์ตรวจรับ (Acceptance Criteria)
- **AC-1:** ไฟล์ `roles.conf` และ `relay-quota.cache` ที่มีการฝัง `$(...)` หรือ `` `...` `` ต้องไม่ถูกรันเป็นคำสั่ง Shell และ Fast Track รองรับข้อความที่มี Backtick ได้โดยไม่รันคำสั่ง
- **AC-2:** การเขียนไฟล์แคช/ตั้งค่าเป็นแบบ Atomic, `prepare_task_worktree` กู้คืนจาก Worktree ที่ถูกลบด้วยมือได้, `create_new_task` ไม่ทับ Task เดิมในวันเดียวกัน และ `run_phase_5_merge` บล็อกไฟล์ความลับ (`.env*`, `*.key`, `*.pem`, `*.sqlite*`, `*.db`)
- **AC-3:** ผ่านชุดทดสอบใหม่ `tests/test_security_and_hardening.sh` และชุดทดสอบเดิมทั้ง 7 ชุดครบ 100%
