# เอกสารกำหนดความต้องการ (SPEC.md)
**รหัสใบงาน:** `20261029-agy-google-ai-ultra`
**วันที่:** 2026-10-29
**สถานะ:** ยืนยันโดยผู้ใช้แล้ว (Confirmed — แนวทาง A1)

## 1. ที่มาและปัญหาที่พบ (Problem Statement)
ผู้ใช้มีแพ็กเกจ **Google AI Ultra** ซึ่งมีโควตาทั้ง **Gemini Models** และ **Claude & GPT Models (100%)** แต่เมื่อพยายามเข้าสู่ระบบผ่าน `@google/gemini-cli` (`gemini`) ตัวเก่า ระบบแจ้งว่า `"This client is no longer supported for Gemini Code Assist for individuals. To continue using Gemini, please migrate to the Antigravity suite of products"` เนื่องจาก Google ย้ายการเข้าถึงโควตา Google AI Ultra ไปอยู่ที่ตัว **Antigravity CLI (`~/.gemini/bin/agy`)** ซึ่งติดตั้งและ Login อยู่ในเครื่องของผู้ใช้เรียบร้อยแล้ว

## 2. เป้าหมายและขอบเขตงาน (Scope of Work)
1. **เชื่อมต่อ `agy` (`~/.gemini/bin/agy` — Google AI Ultra / Antigravity CLI) เข้ากับ RELAY เต็มรูปแบบ:**
   - เพิ่ม `~/.gemini/bin` เข้าสู่ `PATH` ของระบบและสร้างลิงก์ที่ `~/.agents/bin/agy`
   - ตรวจสอบสถานะการ Login ของ `agy` จากไฟล์โทเค็น `~/.gemini/jetski-standalone-oauth-token` หรือ `~/.gemini/config/config.json`
2. **ดึงรายชื่อโมเดลทั้งหมดในแพ็กเกจ Google AI Ultra มาให้เลือกใช้ได้ในทุกตำแหน่ง (`@po`, `@arch`, `@dev`, `@qa`):**
   - **โควตา Gemini Models:** `gemini-4-argon-high`, `gemini-4-argon-medium`, `gemini-4-argon-low`, `gemini-3.8-flash-high`, `gemini-3.8-flash-medium`, `gemini-3.8-flash-low`
   - **โควตา Claude & GPT Models ใน Google AI Ultra:** `claude-opus-5-5-high`, `claude-opus-5-5-medium`, `claude-opus-5-5-low`, `claude-sonnet-5-5-high`, `claude-sonnet-5-5-medium`, `claude-sonnet-5-5-low`, `gpt-oss-120b-medium`
   - รองรับการดึงอัปเดตรายชื่อโมเดลสดผ่านคำสั่ง `agy models`
3. **ตั้งค่าเริ่มต้นให้พร้อมใช้งานครบทั้ง 4 ตำแหน่ง (4/4 Ready) ทันทีโดยใช้โควตา Google AI Ultra + Codex ของผู้ใช้:**
   - `1. @po (Product)` ➔ `agy` (`gemini-4-argon-high`)
   - `2. @arch & @pm` ➔ `agy` (`claude-opus-5-5-high`)
   - `3. @dev (Worktree)` ➔ `agy` (`claude-sonnet-5-5-high`)
   - `4. @qa & @sec` ➔ `codex` (`gpt-6.1-terra`)

## 3. เกณฑ์การตรวจรับงาน (Acceptance Criteria)
- [x] AC1: หน้าจอ `relay` ตรวจพบค่าย `agy` (`● agy (Google AI Ultra)`) พร้อมสถานะพร้อมใช้งานครบทั้ง 4/4 ตำแหน่งทันที
- [x] AC2: สามารถเลือกโมเดลจาก `agy` ได้ทั้งตระกูล Gemini 4 Argon / 3.8 Flash และ Claude Opus 5.5 / Sonnet 5.5
- [x] AC3: การรันคำสั่งจริง (`agy --model <model> -i "<prompt>"`) และการยิงทดสอบ `[t]` (`agy --model <model> -p "<prompt>"`) ทำงานผ่านโควตา Google AI Ultra ได้สำเร็จ 100%
