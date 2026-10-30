# แผนการดำเนินงาน (PLAN — 20261030-menu-back-and-custom-agents)

- [ ] 1. แยก Git Worktree ที่ `.relay/worktrees/20261030-menu-back-and-custom-agents` (กิ่ง `feat/20261030-menu-back-and-custom-agents`)
- [ ] 2. อัปเกรด `interactive_menu`, `prompt_input_with_back`, `choose_provider_interactive`, `choose_model_interactive`, และ `configure_roles_menu` ใน `relay.sh` ให้รองรับ `[b] ย้อนกลับ` และปุ่ม `ESC` ครบทุกจุด พร้อมปรับถ้อยคำเป็นทางการ
- [ ] 3. พัฒนาโมดูลจัดการบทบาท Agent, คำสั่ง Prompt และทักษะ (`run_agents_manager_menu`, `run_custom_agent_task`, การปรับแต่ง 4 ตำแหน่งหลัก และการเพิ่ม/แก้ไข/ลบ Agent ตำแหน่งใหม่) พร้อมเชื่อมกับ Dashboard, `[t]` (`/test`), และ `[v]` (`relay stats`)
- [ ] 4. อัปเดต `README.md` และเขียนชุดทดสอบอัตโนมัติใน `tests/test_custom_agents_and_back_nav.sh` รันทดสอบครบทุกชุด ติดตั้งลง `~/.agents/bin/relay` ผสานเข้า `main` และ Push ขึ้น GitHub
