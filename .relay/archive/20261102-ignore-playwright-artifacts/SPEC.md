# ใบงาน: ไม่ให้ไฟล์ snapshot ของ Playwright MCP ถูก commit (20261102-ignore-playwright-artifacts)
- **ปัญหา (จากการทดสอบจริง):** @qa ใช้ Playwright MCP ใน Worktree ➔ ได้ `.playwright-mcp/*.yml` 31 ไฟล์ ➔ ขั้นที่ 5 commit ไฟล์ค้างให้อัตโนมัติ ➔ ไฟล์ขยะขึ้น GitHub
- **ข้อจำกัด:** ไม่แก้ไฟล์ที่ track ของโปรเจกต์ผู้ใช้ (`.gitignore`) • ไม่แก้ config ของ Playwright MCP

## เกณฑ์ตรวจรับ (Acceptance Criteria)
- [ ] สร้าง Worktree ➔ เพิ่ม `.playwright-mcp/` ใน `.git/info/exclude` (ใช้ร่วมทุก Worktree ไม่ต้อง commit) ครั้งเดียว ไม่ซ้ำ ➔ `git add -A` ของ @dev ไม่หยิบไฟล์นี้
- [ ] commit อัตโนมัติของ RELAY (ขั้นที่ 5 และ commit แรก) ไม่รวม `.playwright-mcp/` แม้ไม่มี exclude
- [ ] ไฟล์ `.playwright-mcp/` ที่ค้างอยู่ไม่นับเป็นไฟล์ค้างใน Worktree (ผสานแล้วลบ Worktree ได้ตามปกติ)
- [ ] มีชุดทดสอบ และชุดทดสอบเดิมผ่านทั้งหมด
