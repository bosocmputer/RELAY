# แผนการดำเนินงาน (PLAN.md)
- **รหัสใบงาน:** `20261031-final-audit-completion`

## ลำดับงาน
1. แยก Git Worktree `.relay/worktrees/20261031-final-audit-completion` บนกิ่ง `feat/20261031-final-audit-completion`
2. แก้ไข `setup-mac.sh`, `relay-skills.sh`, `setup-win.ps1`, `relay-skills.ps1` เพื่อเชื่อมทักษะเข้ากับ `~/.claude/skills/`
3. เพิ่มการทดสอบการเชื่อม `~/.claude/skills/` และการสแกน `.relay/PROJECT_STATE.md` ใน `tests/test_performance_and_accuracy.sh` พร้อมอัปเดต `README.md` และ `docs/SKILLS_AND_UPDATES.md`
4. อัปเดต `.relay/PROJECT_STATE.md` ให้ไม่มีคำ Over-claim และตรงกับสถานะปัจจุบัน
5. รัน `verify-relay-task.sh` + ชุดทดสอบทั้ง 12 ชุด เขียน `QA_REPORT.md` & `QA_VERDICT.json` ผสานเข้า `main` รัน `./setup-mac.sh` และ Push ขึ้น `origin/main`
