# เอกสารกำหนดความต้องการ (SPEC.md) — ระบบแสดงโควต้าคงเหลือแบบเรียลไทม์ของทุกค่าย AI (Real-Time Multi-Provider Quota Display)

## 1. เป้าหมายและปัญหาที่ต้องการแก้ไข
ผู้ใช้งาน `RELAY` ต้องการทราบปริมาณโควต้าที่เหลืออยู่ (Remaining Quota %) ของแต่ละค่าย AI (`agy` Google AI Ultra, `codex` OpenAI Codex CLI, `claude` Anthropic Claude Code CLI) แบบเรียลไทม์ขณะใช้งาน `relay` เพื่อวางแผนสลับค่าย/โมเดลในแต่ละตำแหน่ง (`@po`, `@arch`, `@dev`, `@qa`) ได้ทันทีหากค่ายใดค่ายหนึ่งใกล้หมดโควต้าราย 5 ชั่วโมง (5-Hour Window) หรือรายสัปดาห์ (Weekly 7-Day Window)

## 2. ขอบเขตฟีเจอร์ (Scope of Work)
1. **ดึงข้อมูลโควต้าจริงจากทั้ง 3 ค่ายหลักโดยตรง (100% Native CLI Quota Integration):**
   - **`agy` (Google AI Ultra / Antigravity CLI):**
     - ดึงผ่านคำสั่งเนทีฟ `agy -p "/usage"` ซึ่งคืนค่าโควต้าคงเหลือแยกตาม 2 กระเป๋าโควต้าอิสระ:
       1. **Gemini Models** (`Weekly Limit Remaining %` + เวลาที่รีเซ็ต และ `Five Hour Limit Remaining %` + เวลาที่รีเซ็ต)
       2. **Claude and GPT models** (`Weekly Limit Remaining %` + เวลาที่รีเซ็ต และ `Five Hour Limit Remaining %` + เวลาที่รีเซ็ต)
   - **`codex` (OpenAI Codex CLI):**
     - อ่านค่า `rate_limits` ล่าสุดจากบันทึกเซสชัน `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` (`primary.used_percent` สำหรับโควต้า 5 ชั่วโมง และ `secondary.used_percent` สำหรับโควต้ารายสัปดาห์ 7 วัน พร้อม `resets_at` และ `plan_type`) และรองรับการสั่ง Sync สดผ่าน `codex exec`
   - **`claude` (Anthropic Claude Code CLI):**
     - ดึงผ่าน Control Protocol เนทีฟของ Claude Code (`{"type":"control_request","request_id":"1","request":{"subtype":"get_usage","skip_behaviors":true}}` ส่งเข้า `claude -p --input-format stream-json --output-format stream-json --verbose`) เพื่ออ่านค่า `subscription_type`, `rate_limits.five_hour.utilization`, `rate_limits.seven_day.utilization` และ `resets_at` แล้วคำนวณเปอร์เซ็นต์คงเหลือ (`100 - utilization`)
2. **แสดงผลโควต้าคงเหลือบนหน้าแดชบอร์ดหลัก (`relay` & `relay status`):**
   - แสดงส่วน **`โควต้าคงเหลือ (Real-Time Quota)`** ในกรอบสถานะหลักของ `relay` พร้อมแถบสีสถานะตามเกณฑ์:
     - เหลือ `>= 50%`: สีเขียว (`C_OK`)
     - เหลือ `20% - 49%`: สีส้มแจ้งเตือน (`C_WARN` พร้อมสัญลักษณ์ `▲`)
     - เหลือ `< 20%`: สีแดงเตือนภัย (`C_ERR` พร้อมสัญลักษณ์ `▲ โควต้าใกล้หมด`)
   - แสดงโควต้าคงเหลือของค่ายที่แต่ละตำแหน่ง (`@po`, `@arch`, `@dev`, `@qa`) กำลังใช้งานอยู่ เพื่อให้เห็นทันทีว่าตำแหน่งใดพร้อมลุยงานหนัก
3. **คำสั่งและเมนูดึงโควต้าสดแบบเรียลไทม์ (`[u]` / `/quota` / `/usage` / `relay quota`):**
   - เพิ่มคีย์ลัด `[u]` (และคำสั่งทับ `/quota`, `/usage`) บนหน้าจอหลัก และคำสั่ง `relay quota` จาก Terminal
   - ดึงข้อมูลสดแบบขนาน (Parallel Live Fetch) จาก `agy`, `codex`, และ `claude` พร้อมกันใน ~1.5 วินาที
   - อัปเดตโควต้าอัตโนมัติทุกครั้งหลังจบการทำงานของ Agent ในแต่ละขั้นตอน (`@po`, `@arch`, `@dev`, `@qa`)

## 3. เกณฑ์การตรวจรับงาน (Acceptance Criteria)
- [x] `relay status` และหน้าแดชบอร์ด `relay` แสดงเปอร์เซ็นต์โควต้าคงเหลือทั้งแบบ **5 ชั่วโมง (5h)** และ **รายสัปดาห์ (7d)** ของ `agy (Gemini Models)`, `agy (Claude & GPT)`, `codex`, และ `claude` อย่างถูกต้องพร้อมเวลาที่รีเซ็ต
- [x] คำสั่ง `relay quota` (และปุ่ม `[u]` / `/quota` ในหน้าเมนู) ดึงข้อมูลโควต้าสดจาก CLI ทั้ง 3 ค่ายและแสดงหลอดโควต้า (Progress Bar) พร้อมคำแนะนำการสลับค่ายเมื่อโควต้าต่ำกว่า 20%
- [x] รองรับทั้ง `relay.sh` (macOS/Linux) และ `relay.ps1` (Windows PowerShell) รวมถึงอัปเดตเอกสาร `README.md` และ `docs/` ครบถ้วน
