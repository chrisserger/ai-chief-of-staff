# Tools & Integrations

## Scripts (run from project root)

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/session-brief.sh` | Session start situational awareness | Auto-runs via SessionStart hook |
| `scripts/audit-entities.py` | Find stale/missing entity files | Direct run |
| `scripts/import-granola.py` | Import meeting transcripts to daily notes | `python3 scripts/import-granola.py [--date YYYY-MM-DD]` |

*Add scripts here as you build them. The system grows with you.*

## Slack MCP

**Transport:** HTTP to `https://mcp.slack.com/mcp` | OAuth via `~/.claude.json`
**Setup guide:** [docs/slack-mcp-setup.md](docs/slack-mcp-setup.md)

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

### Channel Registry (Monitored)

| Channel | ID | Tier | Scan |
|---------|-----|------|------|
{{SLACK_CHANNEL_REGISTRY}}

## Google Workspace API (Phase 2)

**Setup guide:** [docs/google-workspace-setup.md](docs/google-workspace-setup.md)
**Auth:** Application Default Credentials (ADC) via `gcloud auth application-default login`

| Service | What You Can Do |
|---------|-----------------|
| Gmail | Read, send, and modify email |
| Calendar | Read and write calendar events |
| Drive | List, search, share files |
| Docs | Create, read, edit documents |
| Sheets | Create, read, edit spreadsheets |
| Slides | Create, read, edit presentations |

*Configure after you're comfortable with the base system.*

## Data Sources

| Source | What | How to Access |
|--------|------|---------------|
| Granola cache | Meeting transcripts + notes | `~/Library/Application Support/Granola/cache-v6.json` |
| Slack MCP | Channel messages, DMs, Canvases | Built-in Claude Code MCP |
| Google APIs | Email, Calendar, Drive (Phase 2) | ADC credentials |

## Environment

- Python: Use project venv (`.venv/bin/python3`) for all scripts
- `.env` at repo root for API keys. Never commit.
