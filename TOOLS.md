# Tools & Integrations

## Scripts (run from project root)

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/session-brief.sh` | Session start situational awareness | Auto-runs via SessionStart hook |
| `scripts/audit-entities.py` | Find stale/missing entity files | Direct run |
| `scripts/import-granola.py` | Import meeting transcripts to daily notes | `python3 scripts/import-granola.py [--date YYYY-MM-DD]` |

*Claude builds scripts for you as you need them. Add them here as the system grows.*

---

## MCP Servers (Model Context Protocol)

MCP servers extend what Claude can do. Add them with `claude mcp add`. See `docs/` for setup guides.

### Slack MCP (Core — set up first)

**Transport:** HTTP to `https://mcp.slack.com/mcp` | OAuth via `~/.claude.json`
**Setup guide:** [docs/slack-mcp-setup.md](docs/slack-mcp-setup.md) | Canvas `F09A59TJF08`

**What Claude can do with Slack:**
- Read messages from any channel you're in
- Search across public and private channels
- Read and write Slack Canvases (Active Board)
- Look up user profiles and channel info
- Send messages and schedule them (always asks first)
- Draft messages for your review before sending

### Active Board (Slack Canvas)

| Item | Detail |
|------|--------|
| **Canvas ID** | `{{ACTIVE_BOARD_CANVAS_ID}}` |
| **Purpose** | Interactive to-do list — single source of truth for commitments |
| **Sections** | This Week, People/Team, Operations, Deals/Accounts, Strategic/Longer Term, Waiting On |
| **Item format** | `- [ ] Action — by DUE_DATE \| Source: MEETING, DATE` |

**Timestamp rule:** ALWAYS calculate Unix timestamps before Slack queries. Never guess.
```bash
date -j -f "%Y-%m-%d %H:%M:%S %z" "2026-04-13 17:00:00 -0400" "+%s"
```

### User ID Registry

| Person | User ID | Role |
|--------|---------|------|
| {{USER_NAME}} | {{USER_SLACK_ID}} | Self |
{{SLACK_USER_REGISTRY}}

*Claude discovers user IDs during onboarding and adds them here.*

### Channel Registry (Monitored)

| Channel | ID | Tier | Scan |
|---------|-----|------|------|
{{SLACK_CHANNEL_REGISTRY}}

*Claude discovers your channels during onboarding. Tiers control scan frequency:*
- **Tier 1:** Direct leadership channels — scan every session
- **Tier 2:** Team/org channels — scan morning + debrief
- **Tier 3:** Cross-org/company channels — scan morning only
- **Tier 4+:** Informational — scan on demand

---

### Nano Banana MCP (Image Generation)

**Transport:** stdio via `uvx nanobanana`
**Setup:** `claude mcp add nanobanana --transport stdio -- uvx nanobanana`
**Setup guide:** [docs/mcp-extras-setup.md](docs/mcp-extras-setup.md)

**What it does:** Generate and edit images using Gemini models (Flash for speed, Pro for quality). 4K resolution, Google Search grounding, subject consistency. Claude can create diagrams, charts, visuals and save them directly into your Obsidian vault.

**Use cases:**
- Architecture diagrams for presentations
- Visual org charts
- Process flows
- Any image you'd normally create in a design tool

### Draw.io MCP (Diagramming)

**Transport:** HTTP to `https://mcp.draw.io/mcp` + stdio via `npx @drawio/mcp`
**Setup:** See [docs/mcp-extras-setup.md](docs/mcp-extras-setup.md)

**What it does:** Create and edit draw.io diagrams programmatically. Full CRUD — create diagrams, add shapes, connect nodes, export. Good for org charts, architecture diagrams, flow charts.

### Pinecone MCP (Semantic Search)

**Transport:** Built-in Claude Code plugin
**Setup:** See [docs/mcp-extras-setup.md](docs/mcp-extras-setup.md)

**What it does:** Vector search across your entire knowledge base. Instead of keyword search, you can ask "what do I know about competitive pricing concerns" and get semantically relevant results from daily notes, deal briefs, customer files, etc.

**Index config (once set up):**
- **Index name:** `{{PINECONE_INDEX_NAME}}`
- **Namespace:** `knowledge-base`
- **Embeddings:** `multilingual-e5-large` (server-side, cosine, 1024 dims)
- **Content:** All markdown files chunked by `##` headers

---

## Salesforce CLI (Org62 Access)

**Setup guide:** [docs/org62-setup.md](docs/org62-setup.md)
**Tool:** `sf` CLI | **Target org:** `{{ORG62_ALIAS}}`

**What Claude can do with Org62:**
- Run SOQL queries against Salesforce internal CRM
- Pull Analytics API dashboards (forecast pipeline, product ACV, DSR workload)
- Download reports for analysis
- Cross-reference deal data with your knowledge base

**Dashboards (configure after setup):**

| Dashboard | ID | What it shows |
|-----------|-----|-------------|
| Forecast Pipeline | `{{FORECAST_DASHBOARD_ID}}` | CW ACV, pipeline, SFRs, walk-up |
| Product Forecast | `{{PRODUCT_DASHBOARD_ID}}` | ACV by product, pipeline by product |
| DSR Workload | `{{DSR_DASHBOARD_ID}}` | DSRs by cloud, by SE owner, by product |

---

## Granola (Meeting Transcription)

**Setup guide:** [docs/granola-setup.md](docs/granola-setup.md)
**Cache location:** `~/Library/Application Support/Granola/cache-v6.json`

**How it works:** Granola runs in the background during your meetings and captures transcripts + notes. Claude reads the local cache file automatically — no API setup needed. Just install Granola and take meetings; Claude finds the transcripts.

**What Claude does with Granola data:**
- Import meeting transcripts to your daily note
- Extract commitments → Active Board
- File notes to customer/deal/people files
- Prep for upcoming meetings using past meeting context
- Build personality profiles from interaction patterns

---

## Google Workspace API (Phase 2)

**Setup guide:** [docs/google-workspace-setup.md](docs/google-workspace-setup.md) | Canvas `F0ASP7X0S5R`
**Auth:** Application Default Credentials (ADC) via `gcloud auth application-default login`

| Service | What You Can Do |
|---------|-----------------|
| Gmail | Read, send, and modify email |
| Calendar | Read and write calendar events |
| Drive | List, search, share files |
| Docs | Create, read, edit documents |
| Sheets | Create, read, edit spreadsheets |
| Slides | Create presentations from Salesforce corporate template |

*Configure after you're comfortable with the base system.*

---

## Data Sources

| Source | What | How to Access |
|--------|------|---------------|
| Granola cache | Meeting transcripts + notes | Local file — auto-discovered |
| Slack MCP | Channel messages, DMs, Canvases | MCP server — OAuth |
| Google APIs | Email, Calendar, Drive, Docs, Sheets, Slides | ADC credentials |
| Org62 | Forecasts, DSRs, pipeline, reports | Salesforce CLI |
| Pinecone | Semantic search over knowledge base | MCP plugin |

## Environment

- Python: Use project venv (`.venv/bin/python3`) for all scripts
- For Gmail scripts: use system Python (`/usr/bin/python3`) which has `google-auth` pre-installed
- `.env` at repo root for API keys. Never commit.
- Salesforce CLI: `/opt/homebrew/bin/sf` (installed via Homebrew)
