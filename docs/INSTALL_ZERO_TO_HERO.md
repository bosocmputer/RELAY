# คู่มือการติดตั้งระบบ `RELAY` ตั้งแต่เริ่มต้น (Zero-to-Hero) และการเชื่อมต่อโปรแกรม Obsidian

เอกสารฉบับนี้ออกแบบมาสำหรับผู้ใช้งานทุกระดับ โดยอธิบายขั้นตอนการติดตั้งตั้งแต่เครื่องคอมพิวเตอร์ที่ยังไม่มีเครื่องมือพัฒนาซอฟต์แวร์มาก่อน รองรับทั้งระบบปฏิบัติการ **Windows** และ **macOS** พร้อมวิธีการติดตั้งและเชื่อมต่อโปรแกรม **Obsidian**

---

## ส่วนที่ 1: การติดตั้งโปรแกรมพื้นฐาน (Git และ Node.js)

ระบบ `RELAY` อาศัยเครื่องมือพื้นฐานมาตรฐาน 2 รายการ ได้แก่ **Git** (สำหรับการควบคุมเวอร์ชันและสร้างสภาพแวดล้อมการทำงานแยกอิสระ `Git Worktree`) และ **Node.js** (สำหรับการรัน CLI ของผู้ให้บริการ AI และชุดทักษะ)

### 🍎 สำหรับระบบปฏิบัติการ macOS
1. กดปุ่ม `Command (⌘) + Spacebar` พิมพ์คำว่า **`Terminal`** แล้วกด Enter
2. รันคำสั่งต่อไปนี้เพื่อติดตั้ง Homebrew (หากยังไม่มี) ตามด้วย Git, Node.js และ pnpm:
```bash
# ติดตั้ง Homebrew (ข้ามขั้นตอนนี้หากติดตั้งไว้แล้ว)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# ติดตั้ง Git, Node.js และ pnpm
brew install git node pnpm
```

### 🪟 สำหรับระบบปฏิบัติการ Windows (Windows 10 / 11)
1. กดปุ่ม `Windows` บนคีย์บอร์ด พิมพ์คำว่า **`PowerShell`** คลิกขวาแล้วเลือก **"Run as Administrator"**
2. รันคำสั่งต่อไปนี้เพื่อติดตั้ง Git และ Node.js (LTS) ผ่านระบบจัดการแพ็กเกจมาตรฐาน `winget`:
```powershell
# 1. ติดตั้ง Git และ Node.js (LTS)
winget install --id Git.Git -e --source winget
winget install --id OpenJS.NodeJS.LTS -e --source winget

# 2. ตั้งค่าสิทธิ์การรันสคริปต์ PowerShell สำหรับผู้ใช้ปัจจุบัน
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```
*(หมายเหตุ: หลังจากรันคำสั่งเสร็จสิ้น ให้ปิดหน้าต่าง PowerShell แล้วเปิดใหม่อีกครั้งเพื่อให้ระบบรับรู้คำสั่ง `git` และ `npm`)*

---

## ส่วนที่ 2: การติดตั้งและการเชื่อมต่อโปรแกรม Obsidian (แนะนำอย่างยิ่ง)

### ทำไมจึงควรติดตั้งโปรแกรม Obsidian ร่วมกับระบบ `RELAY`?
แม้ว่าไฟล์เอกสารในโฟลเดอร์ `.relay/` (`PROJECT_STATE.md`, `SPEC.md`, `ARCH.md`, `PLAN.md`, `QA_REPORT.md`) จะเป็นไฟล์ Markdown มาตรฐานที่สามารถเปิดอ่านในโปรแกรมแก้ไขโค้ดทั่วไปได้ แต่ **การติดตั้งโปรแกรม Obsidian (ใช้งานฟรี 100%)** จะช่วยให้คุณมี **"หน้าต่างจัดการเอกสารสัญญาและฐานความรู้ของโครงการ"** แยกออกจากหน้าต่างเขียนโค้ด สามารถอ่านแผนภาพสถาปัตยกรรม (Mermaid Diagram) ตรวจเช็กรายการงาน (Checklist) และดูภาพหน้าจอผลการทดสอบใน `QA_REPORT.md` ได้อย่างชัดเจน

### 2.1 วิธีติดตั้งโปรแกรม Obsidian (สำหรับผู้ที่ยังไม่มีโปรแกรม)
- **วิธีที่ 1: ดาวน์โหลดจากเว็บไซต์ทางการ (รองรับทั้ง Windows และ macOS)**
  - เข้าไปที่เว็บไซต์ **[https://obsidian.md](https://obsidian.md)** แล้วดาวน์โหลดตัวติดตั้งตามระบบปฏิบัติการของท่าน
- **วิธีที่ 2: ติดตั้งผ่านคำสั่ง Terminal / PowerShell**
  - **บน macOS:** `brew install --cask obsidian`
  - **บน Windows:** `winget install --id Obsidian.Obsidian -e --source winget`

### 2.2 วิธีเชื่อมต่อโปรแกรม Obsidian เข้ากับโฟลเดอร์ `.relay/` ของโครงการ
เมื่อคุณสร้างโฟลเดอร์ `.relay/` ในโครงการใดๆ แล้ว คุณสามารถเชื่อมต่อกับ Obsidian ได้ 2 รูปแบบตามความถนัด:

- **รูปแบบที่ 1 (แนะนำ — เปิดโฟลเดอร์ `.relay` เป็นคลังข้อมูลโดยตรง):**
  1. เปิดโปรแกรม **Obsidian**
  2. คลิกปุ่ม **"Open folder as vault"** (เปิดโฟลเดอร์เป็นคลังข้อมูล)
  3. เลือกเข้าไปที่โฟลเดอร์ **`.relay`** ภายในโครงการของคุณ (เช่น `my-project/.relay`) แล้วกด **Open**
     *(บน macOS หากไม่เห็นโฟลเดอร์ `.relay` ในหน้าต่างเลือกไฟล์ ให้กดปุ่มลัด `Command (⌘) + Shift + .` เพื่อแสดงโฟลเดอร์ที่ขึ้นต้นด้วยจุด)*
  4. คุณจะเห็นไฟล์ `PROJECT_STATE.md`, โฟลเดอร์ `tasks/` และ `archive/` แสดงผลอย่างเป็นระเบียบทันที

- **รูปแบบที่ 2 (กรณีเปิดโฟลเดอร์หลักของโครงการเป็น Vault):**
  1. หากคุณเลือกเปิดโฟลเดอร์หลักของโครงการ (`my-project`) ใน Obsidian ให้ไปที่เมนู **Settings (ไอคอนฟันเฟืองมุมซ้ายล่าง) ➔ Files and links**
  2. เปิดใช้งานตัวเลือก **"Detect all file extensions"** เพื่อให้ค้นหาและเปิดไฟล์เอกสารได้ครบถ้วน

---

## ส่วนที่ 3: การติดตั้ง Official CLI ของผู้ให้บริการ AI

เลือกติดตั้งเฉพาะ CLI ของผู้ให้บริการที่คุณมีแพ็กเกจสมาชิกรายเดือน (Subscription) หรือติดตั้งครบทั้ง 3 ค่าย (ใช้คำสั่งเดียวกันทั้งบน macOS และ Windows):

```bash
# 1. Claude Code (เหมาะสำหรับขั้นตอนที่ 3 @dev และรองรับคำสั่ง --worktree)
npm install -g @anthropic-ai/claude-code

# 2. OpenAI Codex CLI (เหมาะสำหรับขั้นตอนที่ 4 @qa และ @sec)
npm install -g @openai/codex

# 3. Google Gemini CLI (เหมาะสำหรับขั้นตอนที่ 1 @po และขั้นตอนที่ 2 @arch/@pm)
npm install -g @google/gemini-cli
```

**การยืนยันตัวตนครั้งแรก (Authentication):**
รันคำสั่ง `claude`, `codex` หรือ `gemini` ใน Terminal / PowerShell เพื่อเข้าสู่ระบบผ่านเบราว์เซอร์ตามสิทธิ์บัญชีรายเดือนของคุณ จากนั้นพิมพ์ `/exit` เพื่อออกจากโปรแกรม

---

## ส่วนที่ 4: การติดตั้งการตั้งค่าส่วนกลางของระบบ `RELAY` (ทำเพียงครั้งเดียวสำหรับทุกโครงการ)

ขั้นตอนนี้จะทำการติดตั้งไฟล์กฎการทำงานส่วนกลาง (`GLOBAL_AGENTS.md`), สคริปต์เริ่มต้นโครงการ (`relay-init`), กลไกตรวจสอบความปลอดภัยก่อนบันทึกโค้ด (`pre-commit`), และชุดทักษะมาตรฐานทั้ง 4 ขั้นตอนไว้ที่โฟลเดอร์ผู้ใช้ของเครื่อง ทำให้สามารถใช้งานได้กับทุกโครงการทันทีโดยไม่ต้องติดตั้งซ้ำ

### 🍎 สำหรับระบบปฏิบัติการ macOS / Linux:
```bash
git clone https://github.com/bosocmputer/RELAY.git
cd RELAY
chmod +x setup-mac.sh relay-init.sh relay-skills.sh
./setup-mac.sh
./relay-skills.sh install
```

### 🪟 สำหรับระบบปฏิบัติการ Windows (PowerShell):
```powershell
git clone https://github.com/bosocmputer/RELAY.git
cd RELAY
.\setup-win.ps1
.\relay-skills.ps1 install
```

เมื่อติดตั้งเสร็จสมบูรณ์แล้ว โปรดศึกษาวิธีการนำไปใช้งานกับ **โครงการใหม่** และ **โครงการเดิม** ต่อได้ที่เอกสาร **[`docs/USE_CASES_NEW_AND_EXISTING.md`](./USE_CASES_NEW_AND_EXISTING.md)**
