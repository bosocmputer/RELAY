# ARCH: โครงสร้างทางเทคนิคสำหรับ Core Security & Reliability Hardening

## 1. ไฟล์ที่ต้องแก้ไขและสร้างใหม่
1. `relay.sh` (แก้ไข):
   - **`sanitize_model_id()`, `safe_load_roles_conf()`, `safe_load_quota_cache()`:** แทนที่ `source` ทั้งหมดในการโหลด `roles.conf` และ `relay-quota.cache` ด้วยตัวอ่านค่าแบบ Whitelist ที่ไม่รันคำสั่ง Shell
   - **Atomic Writes & Quota Lock:** ใช้ `tempfile.NamedTemporaryFile` + `os.replace` ใน Python และ `mktemp` + `mv -f` ใน Bash สำหรับ `roles.conf`, `relay-quota.cache`, `custom-agents.json`, `PENDING.md`, `SKILL.md`, `PROJECT_STATE.md` พร้อมตรวจ PID lock ใน `load_quota_cache`
   - **`set_cli_default_model()` & `run_fast_track_dev()`:** ใช้ `sanitize_model_id` + Python Atomic Write แทน `sed` และใช้ `printf` เขียน `SPEC.md` แทน `cat <<EOF`
   - **`prepare_task_worktree()`, `create_new_task()`, `run_with_timeout()`, `run_phase_5_merge()`:** เพิ่ม `git worktree prune`, การรันเลขลำดับ `-2`, `-3` เมื่อชื่อ Task ซ้ำ, การส่ง `pkill -TERM/-KILL -P "$pid"`, และ `worktree_forbidden_files()` เพื่อบล็อกไฟล์ `.env*`, `*.key`, `*.pem`, `*.sqlite*`, `*.db` ก่อนผสานโค้ด
2. `relay-init.sh` (แก้ไข):
   - ใช้ `printf` เขียน `PROJECT_STATE.md` แบบปลอดภัยแทน unquoted `cat <<EOF`
3. `tests/test_security_and_hardening.sh` (สร้างใหม่):
   - ทดสอบครบทั้ง 8 กรณี (`SEC-1`..`SEC-3` และ `REL-1`..`REL-5`) โดยไม่ใช้โควต้า AI จริง
