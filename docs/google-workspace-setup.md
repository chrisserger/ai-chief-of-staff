# Connecting Claude Code to Google Workspace

This guide walks you through setting up Google Workspace access so Claude can read your Gmail, Calendar, Drive, Docs, Sheets, and Slides — and, depending on the path you choose, draft emails, edit docs, and create slide decks too.

**Two options.** Option 1 is recommended if you're a Salesforce employee. Option 2 works for everyone else and also for headless automation (cron jobs) where an interactive Claude Code session isn't available.

You can use both. The morning routine uses Option 2 for the deterministic Phase 1 Gmail fetch, and interactive sessions can use whichever is configured.

---

## Option 1 (recommended for Salesforce employees): Google Workspace MCP

The Salesforce AI Stack Marketplace publishes an officially security-approved Google Workspace MCP plugin — 70+ tools across Gmail, Calendar, Drive, Docs, Sheets, and Slides, with **read + write** support. Single OAuth flow via the MCP Gateway. This supersedes the ADC/Python approach for most interactive work.

**What it unlocks:**
- Gmail: search, read, send, manage labels and filters
- Calendar: view, create, update, delete events
- Drive: search, read, create, share files (including shared drives)
- Docs: create, read, edit — batch updates, tables, images, headers/footers
- Sheets: read, write, format, conditional formatting
- Slides: create presentations, batch update slides, build decks on the 2026 corp template directly from a Claude session

### Install

1. Make sure the Salesforce AI Stack Marketplace is installed (internal doc: `docs.internal.salesforce.com/ai/aihub/ai-marketplace/getting-started/`)
2. Add the Google Workspace plugin/MCP from the marketplace. Short URL: `https://www.sfdc.co/official-google-mcp`
3. Authenticate in your terminal:
   ```bash
   ~/.mcp-adaptor/bin/mcp-adaptor auth --provider google-workspace-rw --env prod
   ```
   Your browser opens for OAuth. One flow covers all six services.
4. Verify:
   ```bash
   claude mcp list | grep google-workspace
   ```
   Should return `✓ Connected`.

### Gotcha

If you get `fatal: could not read Username for git.soma.salesforce.com` during install, your local git.soma SSH key isn't set up. Fix that first, then retry the plugin install.

### Internal Slack reference

Newton Wong's announcement of this plugin: [post in #ai-builder-community-mcp](https://salesforce-internal.slack.com/archives/C09BGJDQPAR/p1777014918275559) — good source of truth for the latest capability list and any install updates.

---

## Option 2 (non-Salesforce users / headless automation): Python + Google ADC

> **Salesforce employees:** You do NOT need this for interactive work. The Google Workspace MCP (Option 1 above) handles Gmail, Calendar, Drive, Docs, Sheets, and Slides without any Google Cloud project setup. Option 2 is only needed if you want to run the automated morning routine's Phase 1 Gmail scan (headless cron job), or if you're not at Salesforce.

Uses Google Application Default Credentials and a small Python wrapper (`scripts/scan-gmail.py`) that reads `email-monitor.json` at the repo root.

### Prerequisites

- A Google Cloud project with an **OAuth client ID** you own (free tier works) — see "Why your own client ID?" below
- `gcloud` CLI installed — [install guide](https://cloud.google.com/sdk/docs/install)
- Your Google Workspace account

### Why your own client ID?

Google is [deprecating several scopes for the default `gcloud` client ID](https://cloud.google.com/docs/authentication/troubleshoot-adc#access_blocked_when_using_scopes). Gmail, Calendar, Drive, and Sheets scopes will be blocked unless you supply your own OAuth client. Creating one takes 2 minutes and is free.

### Setup Steps

**1. Create a Google Cloud project** (skip if you already have one). [console.cloud.google.com](https://console.cloud.google.com/) — new project or reuse an existing one.

**2. Enable the APIs.**

```bash
gcloud services enable \
  gmail.googleapis.com \
  calendar-json.googleapis.com \
  drive.googleapis.com \
  docs.googleapis.com \
  sheets.googleapis.com \
  slides.googleapis.com
```

**3. Create an OAuth client ID.**
- Go to **APIs & Services → Credentials → Create Credentials → OAuth client ID**
- Application type: **Desktop app**
- Name it anything (e.g., "AI Chief of Staff CLI")
- Download the JSON — save it somewhere safe (e.g., `~/.config/gcloud/client_secret.json`)

**4. Configure the OAuth consent screen.**
- Go to **APIs & Services → OAuth consent screen**
- Choose **Internal** (if using a Workspace account) or **External**
- Fill in the app name (e.g., "AI Chief of Staff")
- Add the scopes for Gmail, Calendar, Drive, Docs, Sheets, Slides
- Add yourself as a test user (if External)

**5. Authenticate with ADC using your own client ID.**

```bash
gcloud auth application-default login \
  --client-id-file="$HOME/.config/gcloud/client_secret.json" \
  --scopes="https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/calendar.readonly,https://www.googleapis.com/auth/drive.readonly,https://www.googleapis.com/auth/documents.readonly,https://www.googleapis.com/auth/spreadsheets.readonly,https://www.googleapis.com/auth/presentations.readonly"
```

The `cloud-platform` scope is required by `gcloud` itself — without it the command errors out. Credentials land at `~/.config/gcloud/application_default_credentials.json`.

**6. Install Python dependencies.**

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install google-auth google-auth-oauthlib google-api-python-client
```

Alternatively, use system Python if it already has `google-auth` and `google-api-python-client` installed (the morning routine uses `/usr/bin/python3` by default on macOS).

**7. Configure `email-monitor.json`.**

Edit `email-monitor.json` at the repo root:
- `gmail_user`: your email
- `surface_rules.the_daily.from`: your corporate internal comms sender (or leave as placeholder if you don't have one)
- `surface_rules.workday_tasks.from`: your HR system sender
- `surface_rules.employee_success.from`: your HR announcements sender
- `surface_rules.direct_emails.keywords`: products and org terms you care about
- `skip_senders.senders`: noise sources to ignore

**8. Verify it works.**

```bash
/usr/bin/python3 scripts/scan-gmail.py --lookback 1d --json-only | head -30
```

Should print a JSON block with `total_fetched`, `total_surfaced`, and a `messages[]` array. If you get `ADC not found`, re-run step 5.

---

## Which one does the morning routine use?

- **Phase 1** of `scripts/run-morning-routine.sh` is deterministic (bash/python) and calls `scripts/scan-gmail.py` directly — **Option 2 (ADC) is required for Phase 1.** It produces `logs/gmail-scan-YYYY-MM-DD.json` that Phase 2 then reads.
- **Phase 2** is the Claude CLI run. If you have Option 1 installed, Claude can additionally use the MCP tools for interactive write operations (drafting replies, managing labels, creating docs/slides). If you only have Option 2 configured, Phase 2 just reads the JSON Phase 1 wrote.

**Recommendation for Salesforce employees:** Start with Option 1 only — it covers all interactive work. Add Option 2 later only if you set up the automated morning routine (Phase 1 needs headless Python access to Gmail).

**Recommendation for everyone else:** Option 2 is your path. Everything the morning routine does works with it.

---

## What Claude Can Access

| Service | Read | Write | Notes |
|---------|------|-------|-------|
| Gmail | Yes | Option 1 only | Scans for actionable items, skips noise |
| Calendar | Yes | Option 1 only | Meeting prep, schedule awareness |
| Drive | Yes | Option 1 only | File search, document access |
| Docs | Yes | Option 1 only | Read and edit documents |
| Sheets | Yes | Option 1 only | Read/write values, format cells |
| Slides | Yes | Option 1 only | Build presentations from templates |

Option 2 (ADC) is read-only by default — if you need write, add the `.compose` / `.send` / `.file` scopes to step 4 and re-auth. Option 1 has write on by default.

---

## Troubleshooting

**"Google API not configured" (Option 2)**
- Run `gcloud auth application-default login` with the scopes in step 4
- Check that the APIs are enabled in your Cloud project
- Verify credentials exist at `~/.config/gcloud/application_default_credentials.json`

**MCP shows "Needs authentication" (Option 1)**
- Run the auth command: `~/.mcp-adaptor/bin/mcp-adaptor auth --provider google-workspace-rw --env prod`
- Then retry the failing operation

**Wrong Python version (Option 2)**
- Use `/usr/bin/python3` if system Python has the deps, otherwise use `.venv/bin/python3`
- Do NOT use homebrew Python 3.13 if google-auth isn't installed there

**"Permission denied"**
- Option 1: re-run the mcp-adaptor auth flow
- Option 2: re-run `gcloud auth application-default login` with scopes

---

## Privacy Notes

- All Google data stays in your local project files
- Read-only scopes are sufficient for most features — write scopes only needed for Option 1's interactive use
- `logs/gmail-scan-*.json` files contain email body previews — `.gitignore` excludes them by default, do not check them in
- `.transcript_cache.json` and `.commitment_cache.json` also stay local
