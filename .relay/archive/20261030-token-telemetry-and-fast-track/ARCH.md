# สถาปัตยกรรมและการออกแบบทางเทคนิค (ARCH.md)
- **รหัสใบงาน:** `20261030-token-telemetry-and-fast-track`

## 1. การดึงข้อมูล Token จริงจาก Session Logs (`extract_step_token_usage`)
สร้างฟังก์ชัน `extract_step_token_usage <provider> <start_epoch> <end_epoch>` ใน `relay.sh` (รองรับตัวแปรแวดล้อม `RELAY_AGY_BRAIN_DIR`, `RELAY_CODEX_SESSIONS_DIR`, `RELAY_CLAUDE_PROJECTS_DIR` สำหรับการรันชุดทดสอบจำลอง):
- **`agy`:** สแกนไฟล์ `transcript.jsonl` ใน `~/.gemini/antigravity-cli/brain/*/.system_generated/logs/` ที่แก้ไขตั้งแต่ `start_epoch - 5` และรวมบรรทัด `type == "PLANNER_RESPONSE"` ที่มี `created_at` อยู่ในช่วง `[start_epoch - 2, end_epoch + 5]`:
  - `in_total = sum(input_tokens + cache_read_tokens)`, `cached = sum(cache_read_tokens)`, `out = sum(output_tokens)`, `total = in_total + out`
- **`codex`:** สแกนไฟล์ `rollout-*.jsonl` ใน `~/.codex/sessions/` ที่แก้ไขตั้งแต่ `start_epoch - 5`:
  - คำนวณส่วนต่างของ `payload.info.total_token_usage` ระหว่างค่าสุดท้ายในช่วง `[start_epoch - 2, end_epoch + 5]` กับค่าสุดท้ายก่อน `start_epoch - 2` ในไฟล์เดียวกัน (ป้องกันการนับซ้ำ 100%)
- **`claude`:** สแกนไฟล์ `*.jsonl` ใน `~/.claude/projects/*/` ที่แก้ไขตั้งแต่ `start_epoch - 5`:
  - เก็บเฉพาะบรรทัดล่าสุดของแต่ละ `requestId` (หรือ `message.id`) ที่มี `timestamp` อยู่ในช่วง `[start_epoch - 2, end_epoch + 5]` แล้วรวม `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` เป็น `in_total`, `cache_read_input_tokens` เป็น `cached`, และ `output_tokens` เป็น `out`
- คืนค่ารูปแบบมาตรฐาน: `total|in_total|cached|out|turns`

## 2. การบันทึกและแสดงผล (`RUN_LOG.jsonl`, `print_step_telemetry_box`, `run_task_stats_view`)
- อัปเดต `append_run_log` ให้บันทึกอ็อบเจกต์ `"tokens": {"total": ..., "input": ..., "cached": ..., "output": ..., "turns": ...}` ลงใน `.relay/tasks/<task>/RUN_LOG.jsonl`
- สร้าง `print_step_telemetry_box` แสดงผลทันทีหลังจบ `launch_provider_cli` และ `exec_provider_autonomous`
- สร้าง `get_task_telemetry_summary_inline` แสดงยอดรวมเวลาและ Token ของใบงานปัจจุบันบนหน้าจอ Dashboard หลัก
- สร้าง `run_task_stats_view` (`relay stats` หรือปุ่ม `[v]` / `/stats`) และแสดงตารางสรุปรายขั้นตอน + รายโมเดลในหน้า `[5] Merge`

## 3. โหมดด่วน `Fast Track` (`[x]` / `relay fast`) และเพดานความยาวเอกสาร
- สร้างฟังก์ชัน `run_fast_track_dev`:
  - รับโจทย์สั้นๆ จากผู้ใช้ ➔ สร้างใบงานและไฟล์ `SPEC.md` กระชับอัตโนมัติ (หากยังไม่มี) ➔ เตรียม Git Worktree (`prepare_task_worktree`) ➔ เปิด CLI ของ `@dev` ทันทีโดยข้าม `@po` และ `@arch`
- เพิ่มข้อกำหนดเพดานความยาวใน Prompt ของ `@po` (≤40 บรรทัด), `@arch` (≤60 บรรทัด), และ `@qa` (≤30 บรรทัด + ใช้ Playwright เฉพาะเมื่อมี Web UI)
