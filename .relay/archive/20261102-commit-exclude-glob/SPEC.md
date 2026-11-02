# ใบงาน: commit อัตโนมัติล้มเมื่อไฟล์ที่ exclude ถูก ignore อยู่แล้ว (20261102-commit-exclude-glob)
- **ปัญหา:** `git add -A -- . ':(exclude).env' ':(exclude).playwright-mcp' ...` จบด้วย exit 1 ("paths are ignored") เมื่อไฟล์/โฟลเดอร์นั้นมีอยู่จริงและถูก ignore (เช่น `.env` ใน .gitignore หรือ `.playwright-mcp/` ที่ RELAY ใส่ใน info/exclude เอง) ➔ ขั้นที่ 5 เลือก [c] แล้วไม่ผสาน และข้อความ error ถูกล้างจากจอทันทีเพราะหน้าหลักวาดใหม่โดยไม่หยุดรอ
- **พบจริง:** WEB_WHAT_RELAY ใบงาน 20261102-impeccable-token-cache-o

## เกณฑ์ตรวจรับ (Acceptance Criteria)
- [ ] RELAY_COMMIT_EXCLUDES ใช้ pathspec แบบ `:(exclude,glob)**/...` ที่ไม่ทำให้ git add ล้มเมื่อไฟล์ที่ exclude ถูก ignore อยู่ และยังกันไฟล์ต้องห้ามได้ทุกระดับโฟลเดอร์ (.relay, .env*, *.key, *.pem, *.sqlite*, *.db, .playwright-mcp)
- [ ] ขั้นที่ 5 ที่ล้มเหลว (commit/merge ไม่สำเร็จ) หยุดรอ Enter ก่อนกลับหน้าหลัก เพื่อให้เห็นข้อความ error
- [ ] เทสต์: ขั้นที่ 5 [c] ใน worktree ที่มี `.env` และ `.playwright-mcp/` ถูก ignore อยู่ ➔ ผสานสำเร็จและไฟล์ต้องห้ามไม่ถูก commit
- [ ] ชุดทดสอบทั้งหมดผ่าน
