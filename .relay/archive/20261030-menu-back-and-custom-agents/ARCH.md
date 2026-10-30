# สถาปัตยกรรมทางเทคนิค (ARCH — 20261030-menu-back-and-custom-agents)

## 1. ระบบนำทางย้อนกลับทุกเมนู (`Universal Back Navigation`)
- **`interactive_menu` (`relay.sh`):** เมื่อกด `ESC` เดี่ยว (`$k1 = $'\x1b'` และไม่มีลำดับลูกศร `$k23`) ให้คืนค่า `MENU_RESULT="b"` ทันที
- **`prompt_input_with_back`:** ฟังก์ชันมาตรฐานแทน `read -r -p` ที่แสดงคำแนะนำ `(พิมพ์ b เพื่อย้อนกลับ)` และคืนค่า `1` หากผู้ใช้พิมพ์ `b` หรือ `B`
- **`choose_provider_interactive` & `choose_model_interactive`:**
  - เพิ่มตัวเลือก `b|ย้อนกลับ (ใช้ค่าเดิม: ...)` ในทั้งสองเมนู และตั้งตัวแปร `PROVIDER_CHOICE_CANCELLED=1` / `MODEL_CHOICE_CANCELLED=1` เมื่อผู้ใช้กดย้อนกลับ เพื่อไม่ให้เขียนทับค่าเดิมหรือบังคับไปเมนูถัดไป

## 2. ระบบจัดการบทบาท Agent, คำสั่ง Prompt และทักษะ (`Agent Roles & Skills Manager`)
- **โครงสร้างไฟล์ JSON (`~/.agents/custom-agents.json` หรือ `.relay/custom-agents.json`):**
  - `"overrides"`: เก็บค่าปรับแต่งของ 4 ตำแหน่งหลัก (`po`, `arch`, `dev`, `qa`) ได้แก่ `title`, `prompt`, `skills`
  - `"agents"`: รายการ Agent ตำแหน่งที่เพิ่มใหม่ (`slug`, `title`, `provider`, `model`, `work_mode` [`project`|`worktree`], `skills`, `prompt`)
- **การเชื่อมต่อกับระบบหลัก:**
  - `get_role_effective_prompt` / `get_role_effective_skills` / `get_role_effective_title`: ผสานค่าจาก `overrides` เข้ากับ `run_phase_1_po`..`run_phase_4_qa` และ `run_agent_readiness_test` (`[t]`)
  - `run_custom_agent_task`: สั่งรัน Agent ตำแหน่งใหม่ใน `PROJECT_DIR` หรือ `Git Worktree` พร้อมวัดเวลา + Token จริงลง `RUN_LOG.jsonl`
  - `run_agents_manager_menu` (`[g]` / `/agents` / `relay agents`): เมนูภาษาทางการสำหรับสั่งรัน เพิ่ม แก้ไข ลบ และสลับขอบเขตการบันทึก Global/Project
