# คู่มือการติดตั้งระบบ `RELAY` ตั้งแต่เริ่มต้น, การเชื่อมโควต้า Google AI Ultra (`agy`) และการเชื่อมต่อโปรแกรม Obsidian

เอกสารฉบับนี้ออกแบบมาสำหรับผู้ใช้งานทุกระดับ โดยอธิบายขั้นตอนการติดตั้งตั้งแต่เครื่องคอมพิวเตอร์ที่ยังไม่มีเครื่องมือพัฒนาซอฟต์แวร์มาก่อน รองรับทั้งระบบปฏิบัติการ **Windows** และ **macOS** พร้อมวิธีการเชื่อมโควต้า **Google AI Ultra (`agy`)**, **Claude**, **Codex** และการเชื่อมต่อโปรแกรม **Obsidian**

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

## ส่วนที่ 2: การเปิดดูเอกสารด้วยโปรแกรม Obsidian (ทางเลือกเสริม — ไม่บังคับติดตั้ง)

### ทำไมจึงอาจใช้โปรแกรม Obsidian ร่วมกับระบบ `RELAY`? (ใช้หรือไม่ใช้ก็ได้)
ไฟล์เอกสารทั้งหมดในโฟลเดอร์ `.relay/` (`PROJECT_STATE.md`, `SPEC.md`, `ARCH.md`, `PLAN.md`, `QA_REPORT.md`) เป็นไฟล์ Markdown มาตรฐานที่ **ระบบ `RELAY` อ่านและเขียนลงดิสก์โดยตรงโดยไม่พึ่งพาโปรแกรมภายนอก** คุณสามารถเปิดอ่านใน VS Code, Cursor หรือโปรแกรมแก้ไขโค้ดใดก็ได้

อย่างไรก็ตาม หากต้องการแยกหน้าต่างดูเอกสารออกจากหน้าต่างเขียนโค้ด การติดตั้งโปรแกรม **Obsidian (ทางเลือกเสริม ใช้งานฟรีสำหรับบุคคลทั่วไป)** จะช่วยให้คุณอ่านแผนภาพสถาปัตยกรรม (Mermaid Diagram) ตรวจเช็กรายการงาน (Checklist) และดูภาพหน้าจอผลการทดสอบใน `QA_REPORT.md` แบบเรียลไทม์ได้อย่างสะดวก

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

## ส่วนที่ 3: การติดตั้ง Official CLI และการเชื่อมโควต้า Google AI Ultra (`agy`)

### 3.1 สำหรับผู้ที่มีแพ็กเกจ **Google AI Ultra** (ผ่าน Antigravity CLI `agy`)
เนื่องจาก Google ยกเลิกการ Login ด้วยบัญชีส่วนบุคคลบน `@google/gemini-cli` รุ่นเก่า ระบบ `RELAY` จึงรองรับ **Antigravity CLI (`~/.gemini/bin/agy`)** เป็นค่ายหลัก (`agy`) ทำให้คุณสามารถใช้โควต้า **Google AI Ultra** ได้ครบทั้ง 2 ก้อนในแพ็กเกจเดียว:
- **โควต้า Gemini Models:** `gemini-4-argon-high`, `gemini-4-argon-medium`, `gemini-4-argon-low`, `gemini-3.8-flash-high`, `gemini-3.8-flash-medium`, `gemini-3.8-flash-low`
- **โควต้า Claude & GPT Models:** `claude-opus-5-5-high`, `claude-opus-5-5-medium`, `claude-opus-5-5-low`, `claude-sonnet-5-5-high`, `claude-sonnet-5-5-medium`, `claude-sonnet-5-5-low`, `gpt-oss-120b-medium`

### 3.2 การติดตั้ง CLI เสริม (`claude`, `codex`)
```bash
# 1. Claude Code CLI (สำหรับผู้มีแพ็กเกจ Anthropic Claude Pro/Max)
npm install -g @anthropic-ai/claude-code

# 2. OpenAI Codex CLI (สำหรับผู้มีแพ็กเกจ ChatGPT Plus/Pro)
npm install -g @openai/codex
```

**การยืนยันตัวตนครั้งแรก (Authentication):**
คุณสามารถพิมพ์คำสั่ง `relay` แล้วกดเลือกเมนู **`[d] จัดการ CLI & เชื่อมต่อบัญชี Login`** เพื่อให้ระบบช่วยเปิดหน้า Login ของ `agy` (`agy auth login`), `claude` (`claude auth login`), หรือ `codex` (`codex login`) ได้ทันทีจากในโปรแกรม `relay`

---

## ส่วนที่ 4: การติดตั้งการตั้งค่าส่วนกลางของระบบ `RELAY` (ทำเพียงครั้งเดียวสำหรับทุกโครงการ)

ขั้นตอนนี้จะทำการติดตั้งไฟล์กฎการทำงานส่วนกลาง (`GLOBAL_AGENTS.md`), คำสั่งควบคุมกลาง (`relay`), สคริปต์เริ่มต้นโครงการ (`relay-init`), กลไกตรวจสอบความปลอดภัยก่อนบันทึกโค้ด (`pre-commit`), เชื่อม Symlink `~/.agents/bin/agy -> ~/.gemini/bin/agy` และติดตั้งชุดทักษะมาตรฐานทั้ง 4 ขั้นตอนไว้ที่โฟลเดอร์ผู้ใช้ของเครื่อง

> **หมายเหตุ (macOS / Linux):** ถ้าเครื่องมี `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md` หรือ `~/.agents/GLOBAL_AGENTS.md` ที่แก้ไว้เองอยู่แล้ว สคริปต์จะสำรองเป็น `*.bak.<วันเวลา>` ก่อนแทนที่ • สคริปต์ตั้ง `git config --global core.hooksPath ~/.agents/hooks` เฉพาะเมื่อยังไม่มีค่านี้ และ hook เดิมใน `.git/hooks/` ของแต่ละ repo ยังทำงานต่อผ่านตัวส่งต่อของ RELAY

### 🍎 สำหรับระบบปฏิบัติการ macOS / Linux:
```bash
git clone https://github.com/bosocmputer/RELAY.git
cd RELAY
chmod +x setup-mac.sh relay.sh relay-init.sh relay-skills.sh
./setup-mac.sh
source ~/.zshrc
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
