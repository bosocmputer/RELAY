# แผนการดำเนินงาน (`PLAN.md`)

1. [ ] สร้าง Git Worktree `.relay/worktrees/20261030-smart-quota-failover-and-handoff`
2. [ ] เพิ่มฟังก์ชัน `get_worktree_handoff_context_note`, `list_quota_failover_candidates`, `apply_role_provider_model_switch`, และ `prompt_or_auto_switch_role_quota` ใน `relay.sh`
3. [ ] เชื่อมต่อระบบตรวจสอบโควต้าและรับไม้ต่อเข้ากับ `run_phase_1_po`..`run_phase_4_qa`, `run_fast_track_dev`, และ `run_auto_relay_loop`
4. [ ] สร้างชุดทดสอบ `tests/test_quota_failover_and_handoff.sh` และรันทดสอบร่วมกับชุดทดสอบเดิมทั้งหมด (`bash tests/test_*.sh`)
