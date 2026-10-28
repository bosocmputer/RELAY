# 🐣 คู่มือติดตั้ง `RELAY` เริ่มตั้งแต่ 0 (Zero-to-Hero) สำหรับ Windows และ macOS

คู่มือนี้ออกแบบมาสำหรับ **ผู้เริ่มต้นตั้งแต่ 0 (เครื่องเปล่า)** แม้คุณจะไม่เคยลง Git หรือ Node.js มาก่อน ก็สามารถทำตามทีละขั้นตอนจนใช้งานระบบ `RELAY` ได้ครบ 100% ทั้งบน **Windows** และ **macOS**

---

## ส่วนที่ 1: เตรียมโปรแกรมพื้นฐานลงเครื่อง (ทำแค่ครั้งเดียว)

ระบบ `RELAY` ใช้โปรแกรมพื้นฐานฟรี 3 ตัว ได้แก่ **Git** (จัดการเวอร์ชันโค้ดและแยกห้องทดลอง), **Node.js** (รันตัว CLI ของ AI และดึง Skills), และ **Obsidian** (เปิดอ่าน/แก้ไขใบสั่งงาน `.relay/` แบบสวยงาม)

### 🍎 สำหรับผู้ใช้เครื่อง Mac (macOS)
1. กดปุ่ม `Command (⌘) + Spacebar` พิมพ์คำว่า **`Terminal`** แล้วกด Enter
2. ก๊อปปี้คำสั่งด้านล่างไปวางในหน้าต่าง Terminal เพื่อติดตั้งโปรแกรมพื้นฐานผ่าน Homebrew (หากยังไม่มี Homebrew ให้รันคำสั่งบรรทัดแรกก่อน):
```bash
# (ถ้าเครื่องยังไม่มี Homebrew ให้รันบรรทัดนี้ก่อน)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# ลง Git, Node.js, pnpm และโปรแกรม Obsidian
brew install git node pnpm
brew install --cask obsidian
```

### 🪟 สำหรับผู้ใช้เครื่อง Windows (Windows 10 / 11)
1. กดปุ่ม `Windows` ที่คีย์บอร์ด พิมพ์คำว่า **`PowerShell`** ➔ คลิกขวาเลือก **"Run as Administrator"**
2. ก๊อปปี้คำสั่งด้านล่างไปวางในหน้าต่าง PowerShell เพื่อติดตั้ง Git, Node.js และ Obsidian อัตโนมัติผ่าน `winget` (ตัวติดตั้งมาตรฐานของ Windows):
```powershell
# 1. ติดตั้ง Git, Node.js (LTS) และ Obsidian
winget install --id Git.Git -e --source winget
winget install --id OpenJS.NodeJS.LTS -e --source winget
winget install --id Obsidian.Obsidian -e --source winget

# 2. อนุญาตให้ PowerShell รันสคริปต์ในเครื่องได้
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```
*(หมายเหตุ: หลังรันเสร็จ ให้ **ปิดหน้าต่าง PowerShell แล้วเปิดใหม่** 1 ครั้ง เพื่อให้เครื่องรู้จักคำสั่ง `git` และ `npm`)*

---

## ส่วนที่ 2: ติดตั้ง Official CLI ของค่าย AI ที่คุณใช้งาน

คุณมีแพ็กเกจรายเดือน (Subscription) ของค่ายไหน สามารถเลือกติดตั้งเฉพาะค่ายนั้น หรือลงครบทั้ง 3 ค่ายได้เลย (รันคำสั่งเดียวกันทั้งบน Mac และ Windows):

```bash
# 1. Claude Code (แนะนำสำหรับเป็น @dev เขียนโค้ด และรองรับ --worktree ในตัว)
npm install -g @anthropic-ai/claude-code

# 2. OpenAI Codex CLI (แนะนำสำหรับเป็น @qa / @sec ตรวจรับงานและรีวิวโค้ด)
npm install -g @openai/codex

# 3. Google Gemini CLI (แนะนำสำหรับเป็น @po ซักถามโจทย์และวางแผน)
npm install -g @google/gemini-cli
```

**การเข้าสู่ระบบครั้งแรก (Login):**
- พิมพ์ `claude` แล้วกด Enter ➔ ล็อกอินผ่านเบราว์เซอร์ด้วยบัญชี Claude Pro/Max ของคุณ แล้วพิมพ์ `/exit` ออกมาก่อน
- พิมพ์ `codex` แล้วกด Enter ➔ ล็อกอินด้วยบัญชี ChatGPT Plus/Pro ของคุณ แล้วกดออก
- พิมพ์ `gemini` แล้วกด Enter ➔ ล็อกอินด้วยบัญชี Google ของคุณ แล้วกดออก

---

## ส่วนที่ 3: โคลนโปรเจกต์ `RELAY` และติดตั้งสมองส่วนกลาง (ทำครั้งเดียว ใช้ได้ทุกโปรเจกต์!)

การตั้งค่านี้จะสร้างโฟลเดอร์ `.agents` ที่ส่วนกลางของเครื่องคุณ ทำให้ไม่ว่าคุณจะมี 10 โปรเจกต์เดิม หรือสร้างโปรเจกต์ใหม่อีกกี่อัน AI ทุกตัวจะรู้จักระบบ `RELAY` ทันทีโดยไม่ต้องลงซ้ำ!

### 🍎 คำสั่งติดตั้งบนเครื่อง Mac / Linux (รันใน Terminal)
```bash
# 1. ดาวน์โหลด RELAY ลงเครื่อง
git clone https://github.com/bosocmputer/RELAY.git
cd RELAY

# 2. รันสคริปต์ตั้งค่าสมองส่วนกลาง (~/.agents/) + เกราะป้องกันไฟล์ความลับ .env
chmod +x setup-mac.sh relay-skills.sh
./setup-mac.sh

# 3. ดึงชุด Skills มาตรฐานครบทั้ง 4 ไม้ + ผูก Playwright MCP
./relay-skills.sh install
```

### 🪟 คำสั่งติดตั้งบนเครื่อง Windows (รันใน PowerShell)
```powershell
# 1. ดาวน์โหลด RELAY ลงเครื่อง
git clone https://github.com/bosocmputer/RELAY.git
cd RELAY

# 2. รันสคริปต์ตั้งค่าสมองส่วนกลาง (%USERPROFILE%\.agents\) + เกราะป้องกันไฟล์ความลับ .env
.\setup-win.ps1

# 3. ดึงชุด Skills มาตรฐานครบทั้ง 4 ไม้ + ผูก Playwright MCP
.\relay-skills.ps1 install
```

---

## ส่วนที่ 4: ทดสอบรันโปรเจกต์ตัวอย่างในเครื่องของคุณทันที!

ในโฟลเดอร์ `RELAY` ที่คุณเพิ่งดาวน์โหลดมา มีโปรเจกต์ตัวอย่าง 2 ตัวพร้อมให้คุณทดสอบทันที:

```bash
# 1. ทดสอบรัน Unit Test ของระบบคิดเงินร้านกาแฟ (ใช้สคริปต์ตรวจคำตอบด้วย 0 Token!)
node --test examples/cafe-pos/pos-core.test.js
```
คุณจะเห็นผลลัพธ์ `✔ pass 4 / fail 0` ภายในเสี้ยววินาทีโดยไม่เสียค่า Token ของ AI แม้แต่บาทเดียว!

**เปิดดูหน้าเว็บตัวอย่างบนเบราว์เซอร์:**
- **บน Mac:** รัน `open dashboard/index.html` และ `open examples/cafe-pos/index.html`
- **บน Windows:** รัน `start dashboard\index.html` และ `start examples\cafe-pos\index.html`

---

## ส่วนที่ 5: วิธีเริ่มใช้งานจริงกับโปรเจกต์ของคุณเอง

เมื่อคุณต้องการเริ่มงานในโปรเจกต์ใดก็ตาม (เช่น `my-app`):
1. เปิด Terminal / PowerShell เข้าไปที่โฟลเดอร์โปรเจกต์นั้น (`cd my-app`)
2. สร้างโฟลเดอร์ `.relay/tasks/` และ `.relay/archive/` (หรือเปิดโฟลเดอร์โปรเจกต์ด้วยแอป **Obsidian**)
3. **เริ่มไม้ที่ 1 (`@po`):** เปิด `gemini` หรือ `claude` แล้วพิมพ์ว่า:
   > `"@po ช่วยซักถามความต้องการเพื่อทำฟีเจอร์ [ชื่อฟีเจอร์] แล้วสรุปลงไฟล์ .relay/tasks/20261028-my-feature/SPEC.md"`
4. เมื่อได้ไฟล์ `SPEC.md` ที่พอใจแล้ว ให้พิมพ์ `/clear` เพื่อล้างแชต แล้วส่งไม้ต่อให้ **`@arch/@pm` (ไม้ที่ 2)** ➔ **`@dev` (ไม้ที่ 3)** ➔ และ **`@qa` (ไม้ที่ 4)** ตามลำดับ!
