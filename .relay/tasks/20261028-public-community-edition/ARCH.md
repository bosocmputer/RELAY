# เอกสารสถาปัตยกรรมระบบ (ARCH.md) — ขั้นตอนที่ 2 (`@arch`)
- **รหัสใบงาน:** `20261028-public-community-edition`
- **อ้างอิง:** `.relay/PROJECT_STATE.md` และ `SPEC.md`

## 1. โครงสร้างไฟล์ของโครงการ `RELAY (v1.0 Official Public Edition)`
```text
RELAY/
├── README.md                                  # คู่มือหลักฉบับสมบูรณ์ (สถาปัตยกรรม การติดตั้ง การใช้งาน 2 กรณีศึกษา และ Obsidian)
├── LICENSE                                    # สัญญาอนุญาตเปิดเสรี MIT License
├── CONTRIBUTING.md                            # แนวทางการมีส่วนร่วมพัฒนาสำหรับชุมชน
├── setup-mac.sh                               # สคริปต์ติดตั้งการตั้งค่าส่วนกลางสำหรับ macOS / Linux
├── setup-win.ps1                              # สคริปต์ติดตั้งการตั้งค่าส่วนกลางสำหรับ Windows (PowerShell)
├── relay-init.sh                              # สคริปต์สร้างโครงสร้าง .relay/ สำหรับโครงการใหม่และโครงการเดิม (macOS / Linux)
├── relay-init.ps1                             # สคริปต์สร้างโครงสร้าง .relay/ สำหรับโครงการใหม่และโครงการเดิม (Windows)
├── relay-skills.sh                            # สคริปต์จัดการ ติดตั้ง และอัปเดตทักษะ (Skills) สำหรับ macOS / Linux
├── relay-skills.ps1                           # สคริปต์จัดการ ติดตั้ง และอัปเดตทักษะ (Skills) สำหรับ Windows
├── skills-manifest.txt                        # รายการคลังทักษะมาตรฐานสำหรับทั้ง 4 ขั้นตอนการทำงาน
├── templates/                                 # แม่แบบไฟล์กฎการทำงานส่วนกลางและสคริปต์ตรวจสอบความปลอดภัย
│   ├── GLOBAL_AGENTS.md                       # กฎการทำงานส่วนกลางสำหรับเชื่อมต่อไปยัง Claude, Codex และ Gemini
│   ├── playwright-qa-SKILL.md                 # ทักษะการตรวจสอบส่วนติดต่อผู้ใช้ด้วย Playwright MCP
│   ├── pre-commit                             # สคริปต์ Global Git Hook ป้องกันการบันทึกไฟล์ความลับ (.env, *.key)
│   └── install-skills.sh                      # สคริปต์เรียกใช้งาน relay-skills.sh install
├── docs/                                      # เอกสารคู่มือเชิงลึกแยกตามหัวข้อ
│   ├── INSTALL_ZERO_TO_HERO.md                # คู่มือการติดตั้งตั้งแต่เริ่มต้น (Windows & macOS) และการใช้งาน Obsidian
│   ├── USE_CASES_NEW_AND_EXISTING.md          # คู่มือการใช้งานจริง 2 กรณีศึกษา: โครงการใหม่ (Greenfield) และโครงการเดิม (Brownfield)
│   ├── ARCHITECTURE_DEEP_DIVE.md              # รายละเอียดสถาปัตยกรรมและหลักการทำงานของระบบ RELAY
│   ├── SKILLS_AND_UPDATES.md                  # คู่มือการอัปเดตทักษะ การเพิ่มทักษะใหม่ และการสร้าง SKILL.md
│   └── CUSTOM_DOMAINS_GUIDE.md                # คู่มือการประยุกต์ใช้ RELAY กับสายงานอื่นนอกเหนือจากงานพัฒนาซอฟต์แวร์
├── domains/                                   # แม่แบบกฎการทำงานสำหรับสายงานอื่น
│   ├── film-video-production/
│   │   ├── AGENTS.md                          # กฎการทำงานสำหรับสายงานผลิตภาพยนตร์และวิดีโอ
│   │   └── EXAMPLE_STORY_SPEC.md              # ตัวอย่างเอกสารกำหนดความต้องการด้านการผลิตสื่อวิดีโอ
│   └── business-accounting/
│       ├── AGENTS.md                          # กฎการทำงานสำหรับสายงานบริหารธุรกิจและบัญชี
│       └── EXAMPLE_POLICY_SPEC.md             # ตัวอย่างเอกสารกำหนดความต้องการด้านการคำนวณภาษีและบัญชี
└── .relay/                                    # โฟลเดอร์เก็บเอกสารสถานะและประวัติใบงานของโครงการนี้
    ├── PROJECT_STATE.md
    ├── tasks/
    └── archive/
```
