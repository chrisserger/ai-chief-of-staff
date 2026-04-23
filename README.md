# AI Chief of Staff

Your AI-powered executive operating system. An AI partner that runs as your EA, pattern-spotter, and career coach — built on [Claude Code](https://claude.ai/claude-code) and [Obsidian](https://obsidian.md/).

**What you get:**
- **Daily briefs** — Morning prep with fires, schedule, overnight intel
- **Meeting capture** — Auto-imports [Granola](https://granola.ai/) transcripts, extracts commitments
- **Active Board** — Slack Canvas as your interactive to-do list
- **Entity tracking** — Customer, deal, and people files updated automatically
- **Slack monitoring** — Synthesized overnight intel from your channels
- **Gmail scanning** — Actionable items surfaced, noise filtered
- **Memory** — Persistent context across conversations

---

## Setup (3 steps, ~5 minutes)

### 1. Install prerequisites

- [Claude Code](https://claude.ai/claude-code) — your AI partner (desktop app or CLI)
- [Obsidian](https://obsidian.md/) — where you VIEW everything Claude builds

### 2. Clone this repo

```bash
git clone https://github.com/chrisserger/ai-chief-of-staff.git my-chief-of-staff
```

### 3. Open it

**In Obsidian:** Open folder as vault → select `my-chief-of-staff/`

**In Claude Code:** Point it at the same folder:
```bash
cd my-chief-of-staff && claude
```

Claude detects it's a fresh install, interviews you about your org, fills in everything, and walks you through the rest. Just answer its questions.

---

## How It Works Day-to-Day

### Morning
- Open Obsidian → today's daily note has your brief (fires, schedule, overnight intel)
- Check your Active Board in Slack (your to-do list with checkboxes)

### During the Day
- Talk to Claude about anything — meetings, deals, people stuff, ideas
- Voice-to-text works great, don't worry about grammar — Claude cleans it up
- Claude captures everything and routes it to the right files automatically

### What Claude Tracks Automatically
- **Commitments** — when you say "I'll do X," it goes on your Active Board
- **Waiting on** — when someone owes you something, it goes on Waiting On
- **Customer/deal intel** — mentioned a customer? Claude creates or updates their file
- **People notes** — talked about a direct report? Goes in their 1:1 doc

### You Never Have To
- Organize your notes
- Remember what you committed to
- Search for context before a meeting
- Write a weekly summary from scratch

---

## Progressive Rollout

Don't try to do everything at once:

| Phase | What | When |
|-------|------|------|
| **Day 1** | Daily notes + meeting capture + commitment tracking | Setup day |
| **Week 1** | Entity extraction + Slack monitoring + Active Board | After a few conversations |
| **Month 1** | Morning routine automation + personality profiles + weekly reviews | When comfortable |
| **Phase 2** | Gmail scan + Google Workspace API + Pinecone search | When you want more |

---

## Scope Variants

The system scales to your role:

- **VP / Sr Dir (30+ people):** Full system — multiple product lines, forecast readouts, cross-org stakeholders, Monday business readout
- **Director (10-20 people):** Focused system — single product/team, simpler forecast, fewer channels, tactical focus

Claude asks about your scope during onboarding and configures accordingly.

---

## Pre-fill Files (Optional)

If someone is setting this up for you, they can drop a pre-fill file in the project root with your org details (name, title, directs, product lines). Claude detects it during onboarding and skips the questions it already knows the answers to.

See `examples/` for the format.

---

## Add-on Integrations

| Integration | What It Does | Setup Guide |
|-------------|-------------|-------------|
| **Slack MCP** | Claude reads your Slack channels — overnight intel, commitment extraction | [docs/slack-mcp-setup.md](docs/slack-mcp-setup.md) |
| **Google Workspace API** | Claude reads your Gmail and Calendar directly | [docs/google-workspace-setup.md](docs/google-workspace-setup.md) |
| **Morning Routine** | Auto-generates your daily brief at 6 AM | Ask Claude to set it up once Slack + Gmail are connected |
| **Personality Profiles** | DISC/MBTI/Working Genius profiles for your directs | Ask Claude: "build a personality profile for [name]" |

<details>
<summary><strong>Salesforce employees:</strong> Internal setup guides</summary>

- **Slack MCP:** Canvas `F09A59TJF08` — "Connect Claude Code to Slack"
- **Google Workspace API:** Canvas `F0ASP7X0S5R` — "Connect Claude Code to Google Workspace"

</details>

---

## What's in the Repo

```
ai-chief-of-staff/
├── CLAUDE.md              — The operating system (onboarding + standing orders)
├── USER.md                — Personal context template
├── TOOLS.md               — Toolkit reference
├── daily/                 — One note per day (source of truth)
├── people/                — Org chart, 1:1 docs, stakeholders
├── deals/                 — Deal context and tracking
├── customers/             — Customer account files
├── products/              — Product/team overviews
├── projects/              — Initiatives and special projects
├── team/                  — Weekly reviews, planning
├── templates/             — File templates (Claude copies these)
├── scripts/               — Automation scripts
├── examples/              — Sample pre-fill files
└── docs/                  — Integration setup guides
```

---

## Tips

- **Talk, don't type.** Voice-to-text is the intended input method. Claude handles the cleanup.
- **Don't organize.** That's Claude's job. Just dump context and move on.
- **Check your Active Board.** That's your to-do list. Check things off in Slack when done.
- **Ask Claude anything.** "What do I know about [customer]?" / "Prep me for my 1:1 with [name]" / "What did I commit to this week?"

---

## License

MIT — see [LICENSE](LICENSE).
