# สถาปัตยกรรมและการออกแบบ (ARCH.md)
- **รหัสใบงาน:** `20261031-final-audit-completion`

## 1. การเชื่อม `~/.agents/skills/*` เข้าสู่ `~/.claude/skills/*`
- เพิ่มฟังก์ชัน `sync_claude_skill_links` ใน `setup-mac.sh` และ `relay-skills.sh`:
  - วนลูปทุกโฟลเดอร์ย่อยใน `~/.agents/skills/*` ที่มี `SKILL.md`
  - หาก `~/.claude/skills/<name>` ยังไม่มีอยู่ หรือเป็น symlink อยู่แล้ว ให้สั่ง `ln -sfn "$skill_dir" ~/.claude/skills/<name>`
  - หาก `~/.claude/skills/<name>` เป็นโฟลเดอร์จริงที่ผู้ใช้สร้างเอง (`[ -d ... ] && [ ! -L ... ]`) จะข้ามโดยไม่แตะต้อง
- ใน `setup-win.ps1` และ `relay-skills.ps1`: คัดลอก `SKILL.md` ไปยัง `$HOME\.claude\skills\<name>\SKILL.md` ควบคู่กับ `$HOME\.agents\skills\<name>\SKILL.md`

## 2. การตรวจสแกนคำ Over-claiming ใน `.relay/PROJECT_STATE.md`
- เพิ่ม `.relay/PROJECT_STATE.md` (ถ้ามีไฟล์) เข้าในรายการ `files` ของ `tests/test_performance_and_accuracy.sh`
