# SPEC: ออกแบบหน้าจอ CLI ใหม่สไตล์ Hermes พร้อม Braille Apple Logo และศัพท์มาตรฐานนักพัฒนา

## 1. เป้าหมาย (Objective)
ปรับโฉมหน้าจอหลักของ `RELAY CLI` (`relay.sh`) ให้เป็นระเบียบ สากล ไม่รกตา โดยใช้โครงสร้าง **Hermes-Style Split-Header Card** คู่กับ **Braille Apple Logo** (แยกฟังก์ชันโลโก้อิสระเพื่อให้เปลี่ยนรูปได้ง่ายในอนาคต), ระบบสี 4 ระดับ (Quiet Frame, Sharp Focus), ศัพท์มาตรฐานสำหรับนักพัฒนา และแยกเมนู `Workflow` ออกจากแถบ `Shortcuts` ด้านล่าง

## 2. ขอบเขตงาน (Scope)
1. **Hermes-Style Split-Header Card & Modular Braille Apple Logo:**
   - กรอบเดียว `╭─── RELAY v1.0.0 ───╮` โทนสีเทาหม่น (`C_MUTED`) ไม่มีเส้นคั่นแนวนอนซ้อนหลายชั้น
   - คอลัมน์ซ้าย: แสดง **Braille Apple Logo** (`render_relay_logo_lines` / `RELAY_LOGO_STYLE="apple"`) พร้อมข้อมูล `Account · Provider`, `Project Path (Branch)`, และ `Task: <slug>` ด้านล่างโลโก้
   - คอลัมน์ขวา: แบ่งหมวด `Agent Roles` (รวม Custom Agents เช่น `@ux`, `@devops`), `Quota (5h / 7d)`, และ `Pipeline & Telemetry`
2. **4-Level Color Hierarchy & Clean Developer Terminology:**
   - ใช้สีเด่น (`C_ACCENT` / `C_SEL`) เฉพาะหัวข้อหมวดหมู่และบรรทัดที่เลือก (`❯`) ส่วนเส้นกรอบและ Key ใช้ `C_MUTED`
   - แทนที่คำแปลก (`ใบงาน`, `สถานะงาน`, `โครงการ`, `กิ่ง`, `ศูนย์จัดการ`, `Real-Time Quota`) ด้วยคำมาตรฐาน (`Task`, `Project`, `Pipeline`, `Branch / Merge`, `Quota (5h / 7d)`) โดยไม่ Over-claim
3. **Focused Workflow Menu + Bottom Shortcuts Bar:**
   - เมนูหลักแสดงเฉพาะ `Workflow` (7 คำสั่งหลัก `[1]`..`[5]`, `[a] Auto Loop`, `[x] Fast Track`) และแสดง `Shortcuts` (`[c]`, `[g]`, `[u]`, `[v]`, `[l]`, `[n]`, `[f]`, `[t]`, `[d]`, `[s]`, `[q]`) เป็นแถบสรุปด้านล่างที่กดคีย์ลัดเรียกได้ทันที

## 3. เกณฑ์ตรวจรับ (Acceptance Criteria)
- **AC-1:** `relay status` และหน้าจอหลักแสดง Hermes-Style Split-Header Card พร้อม Braille Apple Logo (`render_relay_logo_lines`), หมวด `Agent Roles`, `Quota (5h / 7d)`, และ `Pipeline & Telemetry`
- **AC-2:** `interactive_menu` รองรับแถบ `Shortcuts` ด้านล่างที่กดคีย์ลัด (`c`, `g`, `u`, `v`, `l`, `n`, `f`, `t`, `d`, `s`, `q`) ได้โดยไม่ต้องเลื่อนลูกศรผ่าน 18 บรรทัด
- **AC-3:** ผ่านชุดทดสอบเดิมทั้งหมด (`test_quota_display.sh`, `test_custom_agents_and_back_nav.sh`, `test_token_telemetry.sh`, `test_phase5_merge.sh`, `test_auto_loop.sh`, `test_quota_failover_and_handoff.sh`) และชุดทดสอบใหม่ `tests/test_hermes_cli_redesign.sh` ครบ 100%
