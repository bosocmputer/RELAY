# เอกสารการออกแบบสถาปัตยกรรม (ARCH.md)
**รหัสใบงาน:** `20261029-agy-google-ai-ultra`

## 1. การผสาน Antigravity CLI (`agy`) เข้ากับสถาปัตยกรรม Multi-Agent ของ RELAY
- **Path Resolution:** เพิ่ม `$HOME/.gemini/bin` เข้าใน `PATH` เริ่มต้นของ `relay.sh` และสร้าง Symlink ที่ `~/.agents/bin/agy -> ~/.gemini/bin/agy`
- **Authentication Check (`refresh_cli_auth_cache`):**
  - ตรวจไฟล์ `~/.gemini/jetski-standalone-oauth-token` หรือ `~/.gemini/config/config.json` เพื่อยืนยันว่าผู้ใช้ Login บัญชี Google AI Ultra ใน Antigravity แล้ว
- **Model Discovery (`get_cli_live_models "agy"`):**
  - อ่านจากแคช `~/.agents/agy-models.cache` (หากมี) ร่วมกับรายการโมเดลมาตรฐานของ Google AI Ultra 13 รุ่นที่ดึงจาก `agy models` (`gemini-4-argon-*`, `gemini-3.8-flash-*`, `claude-opus-5-5-*`, `claude-sonnet-5-5-*`, `gpt-oss-120b-medium`)
- **Execution Engine (`launch_provider_cli` & `ping_single_role_agent`):**
  - โหมดโต้ตอบ (Interactive Step 1–4): `agy --model "$configured_model" -i "$initial_prompt"`
  - โหมดทดสอบความพร้อม (Headless Test `[t]`): `agy --model "$configured_model" -p "$self_check_prompt"`
