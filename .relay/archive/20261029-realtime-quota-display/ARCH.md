# เอกสารการออกแบบสถาปัตยกรรม (ARCH.md) — ระบบแสดงโควต้าคงเหลือแบบเรียลไทม์ (Real-Time Multi-Provider Quota Engine)

## 1. สถาปัตยกรรมการดึงและแคชข้อมูลโควต้า (Parallel Live Fetch + Smart Cache)
เพื่อให้หน้าจอ `relay` เปิดขึ้นได้รวดเร็วทันใจและแสดงข้อมูลที่เป็นปัจจุบันเสมอ ระบบใช้สถาปัตยกรรม **Hybrid Live + Smart Cache (`~/.agents/relay-quota.cache`)**:

1. **ตัวดึงข้อมูลโควต้าแบบขนาน (`refresh_quota_cache`):**
   - รันงานย่อย 3 ตัวแบบขนาน (Parallel Subshells) พร้อมกันเพื่อใช้เวลารวมไม่เกิน ~1.5 วินาที:
     - **Worker 1 (`agy` — Google AI Ultra):**
       - รัน `agy -p "/usage"`
       - แยกวิเคราะห์บรรทัด:
         - `Gemini Models          Weekly Limit Remaining     <pct>%   <reset_time>`
         - `Gemini Models          Five Hour Limit Remaining  <pct>%   <reset_time>`
         - `Claude and GPT models  Weekly Limit Remaining     <pct>%   <reset_time>`
         - `Claude and GPT models  Five Hour Limit Remaining  <pct>%   <reset_time>`
     - **Worker 2 (`codex` — OpenAI Codex CLI):**
       - ค้นหาไฟล์เซสชันล่าสุดใน `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` (และถ้าระบุโหมด `--deep` หรือยังไม่มีไฟล์เซสชัน ให้รัน `codex exec --skip-git-repo-check "ok"` เพื่อดึง `token_count` สด)
       - อ่าน JSON `payload.rate_limits`:
         - `CODEX_5H_REM = round(100 - primary.used_percent)`
         - `CODEX_7D_REM = round(100 - secondary.used_percent)`
         - แปลง `resets_at` (Unix epoch) เป็นเวลาท้องถิ่นที่อ่านง่าย
     - **Worker 3 (`claude` — Anthropic Claude Code CLI):**
       - ส่ง Control Request JSON `{"type":"control_request","request_id":"1","request":{"subtype":"get_usage","skip_behaviors":true}}` เข้า `claude -p --input-format stream-json --output-format stream-json --verbose`
       - อ่าน JSON `response.response`:
         - `CLAUDE_PLAN = subscription_type` (เช่น `pro`, `max`)
         - `CLAUDE_5H_REM = round(100 - rate_limits.five_hour.utilization)`
         - `CLAUDE_7D_REM = round(100 - rate_limits.seven_day.utilization)`
         - แปลง `resets_at` (ISO 8601) เป็นเวลาท้องถิ่นที่อ่านง่าย
   - บันทึกผลลัพธ์ลงไฟล์ `~/.agents/relay-quota.cache` พร้อม `QUOTA_UPDATED_EPOCH` และ `QUOTA_UPDATED_AT`

2. **กลไกการรีเฟรชอัตโนมัติ (Auto-Refresh Triggers):**
   - เมื่อเปิด `relay` หรือรัน `relay status`: หากยังไม่มีไฟล์ `~/.agents/relay-quota.cache` หรือข้อมูลเก่าเกิน `180 วินาที (3 นาที)` ระบบจะดึงข้อมูลสดให้โดยอัตโนมัติ (ส่วนค่าของ `codex` จะอ่านสดจากไฟล์เซสชันล่าสุดทุกครั้งที่วาดหน้าจอเพราะใช้เวลาเพียง `< 15ms`)
   - เมื่อจบการทำงานของ Agent ในทุกขั้นตอน (`run_agent_for_role`): สั่งรีเฟรชโควต้าทันทีเพื่อให้เห็นยอดคงเหลือล่าสุดหลังจบงาน
   - เมื่อผู้ใช้กด `[u]` หรือพิมพ์ `/quota`, `/usage` หรือรัน `relay quota`: บังคับดึงข้อมูลสดจากทุกค่ายทันทีและแสดงตารางหลอดโควต้าแบบละเอียด

## 2. การแสดงผลบนหน้าจอหลักและคอลัมน์ตำแหน่ง (Dashboard & Role Integration)
- ในตาราง **ตำแหน่ง (Roles)** แสดงโควต้าคงเหลือของโมเดลที่ตำแหน่งนั้นเลือกใช้ควบคู่กับสถานะความพร้อม เช่น:
  - `@po` (`agy / gemini-4-argon-high`) ➔ `● พร้อมใช้ (5h:75% • 7d:58%)`
  - `@arch & @pm` (`agy / claude-opus-5-5-high`) ➔ `● พร้อมใช้ (5h:100% • 7d:100%)`
  - `@dev` (`agy / claude-sonnet-5-5-high`) ➔ `● พร้อมใช้ (5h:100% • 7d:100%)`
  - `@qa & @sec` (`codex / gpt-6.1-terra`) ➔ `● พร้อมใช้ (5h:91% • 7d:80%)`
- ในส่วน **โควต้าคงเหลือแต่ละค่าย (Real-Time Provider Quotas)** แสดงครบทั้ง 4 กระเป๋าโควต้าในเครื่อง (`agy Gemini`, `agy Claude/GPT`, `codex`, `claude`) พร้อมเวลาที่รีเซ็ต เพื่อให้ผู้ใช้เปรียบเทียบโควต้าข้ามค่ายได้ในพริบตาเดียว
