# PLAN: แผนการดำเนินงานและคำสั่งทดสอบ

## 1. ลำดับขั้นการพัฒนา (Implementation Steps)
1. สร้าง Git Worktree ที่ `.relay/worktrees/20261030-core-security-and-reliability-hardening` บนกิ่ง `feat/20261030-core-security-and-reliability-hardening`
2. พัฒนา `sanitize_model_id()`, `safe_load_roles_conf()`, `safe_load_quota_cache()`, Atomic Write helpers และปรับปรุง `set_cli_default_model()` ใน `relay.sh`
3. ปรับปรุง `run_fast_track_dev()`, `prepare_task_worktree()`, `create_new_task()`, `run_with_timeout()`, และ `run_phase_5_merge()` (เพิ่ม Secret/DB Guard `worktree_forbidden_files`) ใน `relay.sh` และปรับ `relay-init.sh`
4. สร้างชุดทดสอบ `tests/test_security_and_hardening.sh` ครอบคลุมทั้ง 8 จุด (`SEC-1`..`SEC-3`, `REL-1`..`REL-5`)
5. รันตรวจไวยากรณ์และชุดทดสอบทั้งหมด 8 ชุดใน Worktree จนผ่านครบ 100%

## 2. คำสั่งรันทดสอบ (Verification Commands)
- `bash -n relay.sh && bash -n relay-init.sh && bash -n relay-skills.sh`
- `bash tests/test_security_and_hardening.sh`
- `bash tests/test_hermes_cli_redesign.sh`
- `bash tests/test_quota_display.sh`
- `bash tests/test_custom_agents_and_back_nav.sh`
- `bash tests/test_token_telemetry.sh`
- `bash tests/test_phase5_merge.sh`
- `bash tests/test_auto_loop.sh`
- `bash tests/test_quota_failover_and_handoff.sh`
