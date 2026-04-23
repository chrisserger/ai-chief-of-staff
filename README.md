# AI Chief of Staff

Your AI-powered executive operating system. An AI partner that runs as your EA, pattern-spotter, and career coach — built on [Claude Code](https://claude.ai/claude-code) and [Obsidian](https://obsidian.md/).

> **Note:** This is a private repo for Salesforce employees. If you're outside Salesforce and somehow have access, the system is generic enough to work anywhere — but the setup guides reference internal tools.

---

## What You Get

**Core system (Day 1):**
- **Daily briefs** — Morning prep with fires, schedule, overnight intel
- **Meeting capture** — Auto-imports [Granola](https://granola.ai/) transcripts, extracts commitments
- **Active Board** — Slack Canvas as your interactive to-do list
- **Commitment tracking** — "I'll do X" automatically goes on your board
- **Entity tracking** — Customer, deal, and people files updated automatically
- **Memory** — Persistent context across conversations

**With integrations (Week 1+):**
- **Slack monitoring** — Synthesized overnight intel from your channels
- **Gmail scanning** — Actionable items surfaced, noise filtered
- **Org62 dashboards** — Forecast data, DSR workload, pipeline — pulled live
- **Google Slides** — Build on-brand presentations from conversation
- **Image generation** — Claude creates diagrams and visuals directly in your vault
- **Pinecone search** — Semantic search across your entire knowledge base
- **Personality profiles** — DISC/MBTI/Working Genius for your directs, built from meeting data

---

## Setup (3 steps, ~5 minutes)

### 1. Install prerequisites

**Required:**
- **Claude Code CLI** — Install using the [Global Solutions installer](https://salesforce.enterprise.slack.com/docs/T3X1CSHRN/F0AU8DXM71R) (Canvas `F0AU8DXM71R`). One command, one Google sign-in, done. You use Claude Code in a **terminal** (not the Claude desktop app). Any terminal works: [Warp](https://www.warp.dev/) (recommended, approved IDE), VS Code terminal, iTerm, or the built-in macOS Terminal.
- **Obsidian** — [obsidian.md](https://obsidian.md/) — this is where you VIEW everything Claude builds. Connected wiki with backlinks, graph view, and search.

**Recommended:**
- **Granola** — [granola.ai](https://granola.ai/) — Meeting transcription. Already standard at Salesforce. If installed, Claude auto-imports your meeting transcripts — no setup required, it just finds them.

### 2. Clone this repo

```bash
git clone https://github.com/chrisserger/ai-chief-of-staff.git my-chief-of-staff
```

### 3. Open it

**In Obsidian:** Open folder as vault → select `my-chief-of-staff/`

**In your terminal:**
```bash
cd my-chief-of-staff && claude
```

Claude detects it's a fresh install, interviews you about your org, fills in everything, and walks you through the rest. Just answer its questions.

> **Important:** You work with Claude in the **Claude Code CLI** in your terminal. This is different from the Claude desktop app or claude.ai chat. Claude Code has access to your file system, can read/write files, run scripts, and connect to external services via MCP servers. That's what makes this system work.

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
- **Win/loss themes** — deal outcomes get tagged and tracked for pattern analysis

### You Never Have To
- Organize your notes
- Remember what you committed to
- Search for context before a meeting
- Write a weekly summary from scratch
- Prep for a 1:1 from scratch — Claude knows what you discussed last time

---

## What Claude Can Do

Beyond the core daily workflow, here's what's possible once integrations are connected:

| Capability | What It Does | Requires |
|-----------|-------------|----------|
| **Read Slack channels** | Scan overnight messages, extract action items, flag things for your team | Slack MCP |
| **Send Slack messages** | Draft and send messages (always asks first), schedule messages | Slack MCP |
| **Read/write Slack Canvases** | Manage your Active Board, update shared docs | Slack MCP |
| **Scan Gmail** | Surface actionable emails, skip noise, extract commitments | Google Workspace API |
| **Read/write Google Docs** | Create documents, read shared docs | Google Workspace API |
| **Read/write Google Sheets** | Pull forecast data, create spreadsheets | Google Workspace API |
| **Build Google Slides** | Create on-brand presentations from conversation | Google Workspace API |
| **Pull Org62 dashboards** | Forecast pipeline, product ACV, DSR workload — live data | Salesforce CLI |
| **Generate images** | Create diagrams, charts, visuals — saved directly to your vault | Nano Banana MCP |
| **Create diagrams** | Architecture diagrams, org charts, flow diagrams | Draw.io MCP |
| **Semantic search** | Search your entire knowledge base by meaning, not just keywords | Pinecone |
| **Import meetings** | Pull Granola transcripts, extract commitments, file notes | Granola (local) |
| **Build personality profiles** | DISC, MBTI, Working Genius, temperament from meeting data | Granola transcripts |
| **Ghost-write** | Draft Slack messages, all-hands scripts, emails in your voice | Voice profile (built over time) |
| **Automate morning routine** | Auto-generate daily brief at 6 AM every weekday | launchd + Slack + Gmail |

---

## Progressive Rollout

Don't try to do everything at once:

| Phase | What | When |
|-------|------|------|
| **Day 1** | Daily notes + meeting capture + commitment tracking | Setup day |
| **Week 1** | Slack monitoring + Active Board + entity extraction | After Slack MCP is connected |
| **Month 1** | Morning routine automation + personality profiles + weekly reviews | When comfortable |
| **Phase 2** | Gmail scan + Org62 dashboards + Pinecone search + Google Slides | When you want more |

---

## Scope Variants

The system scales to your role:

- **VP / Sr Dir (30+ people):** Full system — multiple product lines, forecast readouts, cross-org stakeholders, Monday business readout
- **Director (10-20 people):** Focused system — single product/team, simpler forecast, fewer channels, tactical focus

Claude asks about your scope during onboarding and configures accordingly.

---

## Integrations — Setup Guides

### Core (set up first)

| Integration | What It Does | Setup Guide |
|-------------|-------------|-------------|
| **Slack MCP** | Read channels, send messages, manage Canvases (Active Board) | [docs/slack-mcp-setup.md](docs/slack-mcp-setup.md) |
| **Granola** | Auto-import meeting transcripts — no config needed if installed | [docs/granola-setup.md](docs/granola-setup.md) |

### Salesforce-specific

| Integration | What It Does | Setup Guide |
|-------------|-------------|-------------|
| **Salesforce CLI (Org62)** | Pull forecast dashboards, DSR reports, pipeline data | [docs/org62-setup.md](docs/org62-setup.md) |

Internal Slack Canvas guides:
- **Installing Claude Code:** Canvas [`F0AU8DXM71R`](https://salesforce.enterprise.slack.com/docs/T3X1CSHRN/F0AU8DXM71R) — Global Solutions installer (macOS / Linux / Windows)
- **Slack MCP:** Canvas [`F09A59TJF08`](https://salesforce.enterprise.slack.com/docs/T3X1CSHRN/F09A59TJF08) — "Connect Claude Code to Slack"
- **Google Workspace API:** Canvas [`F0ASP7X0S5R`](https://salesforce.enterprise.slack.com/docs/T3X1CSHRN/F0ASP7X0S5R) — "Connect Claude Code to Google Workspace"

### Phase 2 (add when ready)

| Integration | What It Does | Setup Guide |
|-------------|-------------|-------------|
| **Google Workspace API** | Gmail, Calendar, Drive, Docs, Sheets, Slides | [docs/google-workspace-setup.md](docs/google-workspace-setup.md) |
| **Nano Banana (image gen)** | Generate images and diagrams via Gemini models | [docs/mcp-extras-setup.md](docs/mcp-extras-setup.md) |
| **Draw.io** | Create/edit diagrams programmatically | [docs/mcp-extras-setup.md](docs/mcp-extras-setup.md) |
| **Pinecone** | Semantic vector search across your knowledge base | [docs/mcp-extras-setup.md](docs/mcp-extras-setup.md) |
| **Morning Routine Automation** | Auto-generates your daily brief at 6 AM | Ask Claude to set it up once Slack + Gmail are connected |
| **Personality Profiles** | DISC/MBTI/Working Genius for your directs | Ask Claude: "build a personality profile for [name]" |

---

## Pre-fill Files (Optional)

If someone is setting this up for you, they can drop a pre-fill file in the project root with your org details (name, title, directs, product lines). Claude detects it during onboarding and skips the questions it already knows the answers to.

See `examples/` for the format.

---

## What's in the Repo

```
ai-chief-of-staff/
├── CLAUDE.md              — The operating system (onboarding + standing orders)
├── USER.md                — Personal context template
├── TOOLS.md               — Toolkit reference (MCPs, scripts, data sources)
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

- **Use the CLI, not the desktop app.** Open your terminal (Warp, VS Code, iTerm), `cd` into this folder, type `claude`. That's your interface.
- **Talk, don't type.** Voice-to-text is the intended input method. Claude handles the cleanup.
- **Don't organize.** That's Claude's job. Just dump context and move on.
- **Check your Active Board.** That's your to-do list. Check things off in Slack when done.
- **Ask Claude anything.** "What do I know about [customer]?" / "Prep me for my 1:1 with [name]" / "What did I commit to this week?"
- **Claude builds scripts for you.** Need something automated? Describe it. Claude writes the script, tests it, and wires it in.

---

## Questions?

- Ask Claude — it knows the system inside and out
- Talk to Chris Serger — he built it and uses it every day
- Full guide with architecture and demo: ask Chris for the link

---

## License

MIT — see [LICENSE](LICENSE).
