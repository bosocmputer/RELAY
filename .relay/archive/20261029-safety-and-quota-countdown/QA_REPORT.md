# QA_REPORT — 20261029-safety-and-quota-countdown

VERDICT: PASS

## ผลทดสอบอัตโนมัติ (ไม่ใช้โควต้า AI จริง)
| เกณฑ์ | วิธีทดสอบ | ผล |
| :-- | :-- | :-- |
| AC-1 commit ไฟล์ค้างแล้วผสาน | `tests/test_phase5_merge.sh` (git repo ชั่วคราว) | ✅ ไฟล์เข้า main, มี merge commit, `.relay/` ไม่ถูก commit, Worktree/กิ่งถูกลบ, ใบงานเข้า archive พร้อม QA_REPORT จาก Worktree |
| AC-2 merge conflict | เดียวกัน | ✅ ยกเลิก merge, ไม่ค้าง `MERGE_HEAD`, main ไม่เปลี่ยน, Worktree และใบงานยังอยู่, แสดงข้อความ conflict จริง |
| AC-3 กิ่งไม่มี commit ใหม่ | เดียวกัน | ✅ ไม่ลบ Worktree/กิ่ง และแจ้งเตือน |
| AC-4 FAIL ➔ PASS | `tests/test_auto_loop.sh` (agy/codex จำลอง) | ✅ ผ่านรอบ 2, มี `QA_REPORT.before-round-2.md`, ทำงานใน Worktree, เพิ่ม `.relay/worktrees/` ใน `.gitignore`, เรียก `agy --mode auto`, main ไม่ถูกแก้ |
| AC-5 ไม่มี VERDICT | เดียวกัน | ✅ ไม่นับว่าผ่าน, บันทึกเหตุผล, หยุดเมื่อครบ 3 รอบ |
| AC-6 เกินเวลา | เดียวกัน (`RELAY_STEP_TIMEOUT=3`, agent ค้าง 30 วินาที) | ✅ หยุดใน 4 วินาที, agent ได้รับ SIGTERM จริง, ไม่เรียก @qa ต่อ |
| เพิ่มเติม | เดียวกัน | ✅ หยุดเมื่อ @qa ไม่เขียนรายงาน และเมื่อ @dev คืน exit 1 |
| AC-7 นับถอยหลัง | แคชจำลอง (เวลาอนาคต/เลยแล้ว/ไม่มี epoch) + รันกับ CLI จริง | ✅ `อีก 4ชม.02น. (23:08)`, `อีก 1วัน 13ชม.`, `↻ รีเซ็ตแล้ว` แสดง 100%, แคชเก่าที่ไม่มี epoch แสดง `รีเซ็ต <เวลา>`, อายุข้อมูลแสดงถูกต้อง |
| AC-8 | `bash -n relay.sh` | ✅ |

## ข้อจำกัดที่ทราบ
- ยังไม่ได้ทดสอบ Auto-Loop กับ CLI จริงทั้ง 3 ค่าย (ทดสอบด้วย CLI จำลองเพื่อไม่ใช้โควต้า) — โหมด `agy --mode auto` ยืนยันจาก `agy --help`, ส่วน `claude --permission-mode acceptEdits` อาจต้องเพิ่ม allow rule เพื่อให้รันคำสั่งทดสอบได้
- การจัดแนวคอลัมน์ภาษาไทยคำนวณจาก Unicode (ไม่นับสระ/วรรณยุกต์ที่ซ้อน) ซึ่งตรงกับ Terminal ส่วนใหญ่ แต่บาง Terminal อาจแสดงสระอำต่างออกไปเล็กน้อย
- Windows (`relay.ps1`) ยังไม่ได้รับการแก้ไขในรอบนี้ (นอกขอบเขต — ระบุใน README แล้ว)

## ความปลอดภัย
- ไม่มีการอ่าน/บันทึกไฟล์ความลับ; auto-commit ใน Worktree ตัด `.relay/` ออก และผ่าน global pre-commit hook
- ไม่ใช้โหมดข้ามสิทธิ์ทั้งหมด (`--dangerously-skip-permissions`) ใน Auto-Loop
