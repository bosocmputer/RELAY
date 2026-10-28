# 🏗️ แผนสถาปัตยกรรม (ARCH.md) — ไม้ที่ 2 (`@arch`)
- **รหัสใบงาน:** `20261028-public-community-edition`
- **อ้างอิง:** `.relay/PROJECT_STATE.md` และ `SPEC.md`

## 1. โครงสร้างไฟล์ทั้งระบบของ `RELAY (Public Community Edition)`
```text
RELAY/
├── README.md                                  # คู่มือหลักฉบับสมบูรณ์ (อ่านจบเข้าใจทั้งระบบในหน้าเดียว)
├── LICENSE                                    # MIT License สำหรับเปิดเป็น Open-Source สาธารณะ
├── CONTRIBUTING.md                            # คู่มือการมีส่วนร่วมสำหรับชุมชน (ส่ง Skill / Domain Pack ใหม่)
├── setup-mac.sh                               # สคริปต์ติดตั้งส่วนกลางสำหรับ macOS / Linux
├── setup-win.ps1                              # สคริปต์ติดตั้งส่วนกลางสำหรับ Windows (PowerShell)
├── relay-skills.sh                            # ตัวจัดการ/อัปเดต/เพิ่ม Skills สำหรับ macOS / Linux
├── relay-skills.ps1                           # ตัวจัดการ/อัปเดต/เพิ่ม Skills สำหรับ Windows (PowerShell)
├── skills-manifest.txt                        # รายการคลัง Skills มาตรฐานที่รองรับการสั่งอัปเดตอัตโนมัติ
├── templates/                                 # แม่แบบไฟล์กฎกลางและเกราะความปลอดภัย
│   ├── GLOBAL_AGENTS.md                       # กฎกลางเชื่อมไปยัง Claude, Codex, Gemini
│   ├── playwright-qa-SKILL.md                 # สกิลตรวจหน้าเว็บด้วย Playwright MCP
│   ├── pre-commit                             # Global Git Hook ป้องกันไฟล์ความลับหลุด
│   └── install-skills.sh                      # สคริปต์เรียก relay-skills.sh install (คงไว้เพื่อความเข้ากันได้)
├── docs/                                      # คู่มือเจาะลึกแยกหมวดหมู่
│   ├── INSTALL_ZERO_TO_HERO.md                # คู่มือติดตั้งเริ่มจาก 0 สำหรับมือใหม่ (Windows & macOS)
│   ├── ARCHITECTURE_DEEP_DIVE.md              # เจาะลึกสถาปัตยกรรมและหลักการทำงานของ RELAY
│   ├── SKILLS_AND_UPDATES.md                  # วิธีอัปเดตสกิลเดิม เพิ่มสกิลใหม่ และเขียนสกิลเอง
│   └── CUSTOM_DOMAINS_GUIDE.md                # วิธีดัดแปลง RELAY ไปใช้กับสายงานอื่นๆ
├── domains/                                   # แม่แบบพร้อมใช้สำหรับดัดแปลงไปใช้สายงานอื่น
│   ├── film-video-production/
│   │   ├── AGENTS.md                          # บทบาท 4 ไม้สำหรับสายสร้างหนัง/วิดีโอ (@writer, @director, @creator, @editor)
│   │   └── EXAMPLE_STORY_SPEC.md              # ตัวอย่างใบสั่งงานสร้างวิดีโอ/หนังสั้น
│   └── business-accounting/
│       ├── AGENTS.md                          # บทบาท 4 ไม้สำหรับสายบัญชี/ธุรกิจ (@analyst, @planner, @operator, @auditor)
│       └── EXAMPLE_POLICY_SPEC.md             # ตัวอย่างใบสั่งงานตรวจสอบบัญชีและภาษี
├── dashboard/
│   └── index.html                             # โปรเจกต์ตัวอย่างที่ 1: RELAY Board & Token Saver
├── examples/
│   └── cafe-pos/                              # โปรเจกต์ตัวอย่างที่ 2: Mini Cafe POS + PromptPay QR + Unit Tests
└── .relay/                                    # โฟลเดอร์สัญญาของโปรเจกต์นี้
    ├── PROJECT_STATE.md
    ├── tasks/
    └── archive/
```

## 2. การออกแบบระบบจัดการและอัปเดต Skills (`relay-skills`)
- เก็บรายชื่อ GitHub Repo และชื่อสกิลไว้ในไฟล์ข้อความ `skills-manifest.txt` ที่อ่านและแก้ไขง่าย
- คำสั่ง `./relay-skills.sh update` (Mac) หรือ `.\relay-skills.ps1 update` (Windows) จะอ่าน `skills-manifest.txt` แล้วรัน `npx -y skills add <repo> [--skill <name>] -g` ซ้ำเพื่อดึงโค้ดเวอร์ชันล่าสุดจากผู้พัฒนาต้นทางบน GitHub มาทับในเครื่องทันที
- คำสั่ง `./relay-skills.sh add <repo> [skill-name]` จะติดตั้งสกิลใหม่ลงเครื่องพร้อมบันทึกต่อท้ายลงใน `skills-manifest.txt` อัตโนมัติ เพื่อให้การกด `update` ครั้งหน้าอัปเดตสกิลใหม่นี้ไปด้วย!
