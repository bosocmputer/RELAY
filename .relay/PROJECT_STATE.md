# สถานะปัจจุบันของโครงการ (PROJECT_STATE.md)
*อัปเดตล่าสุด: 2026-10-28 • ความยาวไม่เกิน 2 หน้าเพื่อให้ `@arch` และ `@pm` เข้าใจโครงสร้างล่าสุดของระบบได้ทันทีโดยไม่ต้องอ่านใบงานเก่าทั้งหมด*

## 1. ภาพรวมของโครงการ (`RELAY v1.0 Official Public Edition`)
คลังโค้ดมาตรฐานสาธารณะ (`https://github.com/bosocmputer/RELAY.git` • โฟลเดอร์หลัก `/Users/nontawatwongnuk/dev_bos/RELAY`) สำหรับเผยแพร่สถาปัตยกรรมการทำงานร่วมกับตัวแทน AI หลายค่ายแบบแบ่ง 4 ขั้นตอนผ่านหน้าจอควบคุมกลางใน Terminal (`relay`) และเอกสารส่งมอบงานในโฟลเดอร์ `.relay/` รองรับทั้งระบบปฏิบัติการ **Windows** และ **macOS**

## 2. โครงสร้างโมดูลและไฟล์สำคัญล่าสุด
- **หน้าจอควบคุมกลางและการตั้งค่าจับคู่ค่าย AI (`relay.sh`, `relay.ps1`, `templates/relay-roles.conf`):**
  - คำสั่ง `relay` เปิดหน้าจอ Interactive Terminal Hub สำหรับควบคุมขั้นตอนที่ 1–5 ในหน้าต่าง Terminal เดียว
  - อ่านค่าการจับคู่ตำแหน่ง (`@po`, `@arch/@pm`, `@dev`, `@qa/@sec`) กับค่ายผู้ให้บริการ (`claude`, `codex`, `gemini`) และโมเดล (`MODEL_PO`, `MODEL_ARCH`, `MODEL_DEV`, `MODEL_QA`) จากไฟล์ส่วนกลาง `~/.agents/relay-roles.conf` และรองรับการเขียนทับเฉพาะโครงการที่ `.relay/roles.conf`
  - มีเมนู `[t]` (`relay test`) สำหรับตรวจสอบทักษะประจำตำแหน่งและยิงทดสอบให้ตัวแทน AI แต่ละตำแหน่งรายงานบทบาทและทักษะของตนเองผ่าน CLI และ Model ที่ตั้งไว้จริง รวมถึงเมนู `[d]` (`relay doctor`) สำหรับตรวจสอบและติดตั้ง CLI
  - จัดการสร้างและลบ `Git Worktree` แยกอิสระอัตโนมัติที่ `.relay/worktrees/<task-id>` ในขั้นตอนที่ 3 และผสานโค้ดพร้อมจัดเก็บใบงานเข้า `.relay/archive/` ในขั้นตอนที่ 5
- **สคริปต์ติดตั้งส่วนกลางและสร้างโครงสร้างโครงการ (`setup-mac.sh`, `setup-win.ps1`, `relay-init.sh`, `relay-init.ps1`):**
  - ติดตั้ง `~/.agents/GLOBAL_AGENTS.md`, `~/.agents/bin/relay`, `~/.agents/bin/relay-init`, `~/.agents/bin/relay-skills` พร้อมเพิ่มเข้าสู่ `PATH` อัตโนมัติ และเปิดใช้งาน Global Git `pre-commit` Hook
- **ระบบจัดการและอัปเดตทักษะ (`relay-skills.sh`, `relay-skills.ps1` และ `skills-manifest.txt`):**
  - รองรับคำสั่ง `install`, `update` (ดึงอัปเดตเวอร์ชันล่าสุดจาก GitHub ของผู้พัฒนาต้นทาง), `add <repo>` และ `list`
- **เอกสารคู่มือมาตรฐาน (`README.md`, `docs/` และ `domains/`):**
  - ครอบคลุมการติดตั้งตั้งแต่ศูนย์ การเชื่อมต่อโปรแกรม **Obsidian** การใช้งานทั้งในโครงการใหม่ (Greenfield) และโครงการเดิม (Brownfield) รวมถึงแม่แบบสำหรับสายงานผลิตภาพยนตร์/วิดีโอ และสายงานบริหารธุรกิจ/บัญชี
