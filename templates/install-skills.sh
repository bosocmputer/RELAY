#!/usr/bin/env bash
set -e

echo "🚀 [RELAY] กำลังติดตั้งชุด Skills ครบทั้ง 4 ไม้เข้าคลังกลางของเครื่อง Mac (-g)..."

# ── ไม้ที่ 1 (@po ซักถามโจทย์ & ปั้นธุรกิจใหม่) ──
npx -y skills add https://github.com/obra/superpowers --skill brainstorming -g
npx -y skills add https://github.com/Jakeschincariol/founder-skill -g

# ── ไม้ที่ 2 (@arch & @pm วางโครงสร้าง & แตกแผนงาน) ──
npx -y skills add https://github.com/obra/superpowers --skill writing-plans -g

# ── ไม้ที่ 3 (@dev ซอง Frontend: UI เนี๊ยบ + React/Next.js มาตรฐาน) ──
npx -y skills add https://github.com/pbakaus/impeccable --skill impeccable -g
npx -y skills add https://github.com/vercel-labs/agent-skills --skill vercel-react-best-practices -g

# ── ไม้ที่ 3 (@dev ซอง Backend & DB: PostgreSQL, API, Auth & RLS) ──
npx -y skills add https://github.com/supabase/agent-skills --skill supabase-postgres-best-practices -g

# ── ไม้ที่ 3 (@dev ซองวิศวกรรมหลัก: TDD & วิเคราะห์บั๊กอย่างเป็นระบบ) ──
npx -y skills add https://github.com/obra/superpowers --skill test-driven-development -g
npx -y skills add https://github.com/obra/superpowers --skill systematic-debugging -g

# ── ไม้ที่ 4 (@qa & @sec ซองตรวจรับงาน + ความปลอดภัย Security ระดับโลก) ──
npx -y skills add https://github.com/obra/superpowers --skill verification-before-completion -g
npx -y skills add https://github.com/trailofbits/skills --skill differential-review -g
npx -y skills add https://github.com/semgrep/skills -g

# ── ผูก Playwright MCP เข้ากับ CLI (หากติดตั้ง claude หรือ codex ไว้แล้ว) ──
if command -v claude >/dev/null 2>&1; then
  echo "🔌 ผูก Playwright MCP เข้ากับ Claude Code..."
  claude mcp add -s user playwright npx @playwright/mcp@latest || true
fi

if command -v codex >/dev/null 2>&1; then
  echo "🔌 ผูก Playwright MCP เข้ากับ Codex CLI..."
  codex mcp add playwright -- npx @playwright/mcp@latest || true
fi

echo "✅ [RELAY] ติดตั้ง Skills และ Playwright MCP เสร็จสมบูรณ์!"
