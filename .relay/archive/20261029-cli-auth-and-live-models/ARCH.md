# เอกสารการออกแบบสถาปัตยกรรม (ARCH.md)
**รหัสใบงาน:** `20261029-cli-auth-and-live-models`

## 1. สถาปัตยกรรมการตรวจสถานะ CLI แบบ 3 ชั้น (3-Layer CLI Readiness Check)
สำหรับแต่ละตำแหน่ง (`@po`, `@arch/@pm`, `@dev`, `@qa/@sec`):
1. **Layer 1 — Installation (`is_provider_installed`):** `command -v <provider>`
2. **Layer 2 — Authentication (`is_provider_logged_in`):**
   - แคชผลลัพธ์ไว้ในตัวแปร `CLI_AUTH_CLAUDE`, `CLI_AUTH_GEMINI`, `CLI_AUTH_CODEX` ต่อรอบการวาดหน้าจอ (`refresh_cli_auth_cache`) เพื่อความรวดเร็วสูงสุด:
     - `claude`: `claude auth status 2>/dev/null | grep -q '"loggedIn"[[:space:]]*:[[:space:]]*true'` (หรือมี `ANTHROPIC_API_KEY`)
     - `codex`: `codex login status 2>/dev/null | grep -qi 'Logged in'` (หรือมี `OPENAI_API_KEY`)
     - `gemini`: ตรวจค่า `"selectedType"` ใน `~/.gemini/settings.json` หรือมีไฟล์ `~/.gemini/oauth_creds.json` หรือมี `GEMINI_API_KEY`
3. **Layer 3 — Model Configuration (`is_model_explicitly_set`):** โมเดลต้องไม่ใช่ `default`/`none` และหากโมเดลเดิมที่เคยบันทึกไว้ไม่มีอยู่ในรายการโมเดลของค่าย (เช่น `o3` เดิม) ให้สลับไปใช้โมเดลเริ่มต้นของ CLI ในเครื่องให้อัตโนมัติเมื่อกด Quick Setup

## 2. สถาปัตยกรรมการดึงรายชื่อ Model จาก CLI โดยตรง (`get_cli_models_from_system`)
ใช้สคริปต์ Python3 ขนาดเล็กในตัว (พร้อม Fallback กรณีไม่มี Python3) เพื่ออ่านข้อมูลโมเดลจากไฟล์ระบบของ CLI ที่ติดตั้งอยู่ในเครื่อง:
- **Codex (`~/.codex/models_cache.json` + `~/.codex/config.toml`):**
  ดึง `slug` และ `description` ของทุกโมเดลที่มี `visibility == "list"` โดยนำโมเดลที่ตั้งไว้ใน `config.toml` ขึ้นเป็นอันดับแรก
- **Gemini (`@google/gemini-cli` bundle + `~/.gemini/settings.json`):**
  สแกนรหัสโมเดลจากไฟล์ bundle ของ `gemini` ที่ติดตั้งในเครื่อง (`gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`, `auto-gemini-2.5`, `gemini-3.1-pro`, `gemini-3.5-flash`, `gemini-2.0-flash`)
- **Claude (`claude` binary + `~/.claude/settings.json`):**
  ดึง alias มาตรฐาน (`sonnet`, `opus`, `haiku`) คู่กับรหัสโมเดลจริงล่าสุดที่สแกนพบในไบนารีของ `claude` ในเครื่อง (`claude-sonnet-4-6`, `claude-opus-4-6`, `claude-sonnet-4-5`, `claude-opus-4-5`, `claude-haiku-4-5`)
