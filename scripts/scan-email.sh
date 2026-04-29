#!/bin/bash
# scan-email.sh — manual trigger for the Gmail scan
#
# Two stages:
#   1. Python (deterministic): scripts/scan-gmail.py fetches emails via ADC and
#      writes structured JSON to logs/gmail-scan-YYYY-MM-DD.json
#   2. Claude CLI: processes that JSON, extracts actions, updates the daily note
#
# Use when the morning routine verify check fails with email checkpoint missing
# or any time you want a fresh scan.
#
# Config: email-monitor.json at the repo root. See docs/google-workspace-setup.md.
# If email-monitor.json is missing, exits 0 with a log line.

set -u

cd "$(dirname "$0")/.." || exit 1

if [ ! -f "email-monitor.json" ]; then
    echo "Skipping: email-monitor.json not found - Gmail integration not configured yet."
    echo "See docs/google-workspace-setup.md to set up."
    exit 0
fi

TODAY=$(date +%Y-%m-%d)
GMAIL_OUT="logs/gmail-scan-${TODAY}.json"
mkdir -p logs

echo "Fetching Gmail..."
if /usr/bin/python3 scripts/scan-gmail.py --lookback 1d --json-only > "$GMAIL_OUT" 2>/tmp/gmail-scan-err.log; then
    SURFACED=$(/usr/bin/python3 -c "import json; print(json.load(open('$GMAIL_OUT'))['total_surfaced'])" 2>/dev/null || echo "?")
    echo "   OK: $SURFACED emails surfaced -> $GMAIL_OUT"
else
    echo "   FAILED - see /tmp/gmail-scan-err.log"
    exit 1
fi

PROMPT_FILE=$(mktemp /tmp/email-scan-XXXXXX.md)
trap 'rm -f "$PROMPT_FILE"' EXIT

cat > "$PROMPT_FILE" <<PROMPT_END
You are running headlessly. One job: process today Gmail scan and update daily/${TODAY}.md.

1. Read ${GMAIL_OUT} - it has the scan results.

2. For each message in messages[], apply the handler for its bucket:
   - the_daily: extract dated announcements (deadlines, events, downtime) as Action Required items in Overnight Intel.
   - workday_tasks: pending approvals are COMMITs -> add to Active Board Canvas (canvas_id from slack-monitor.json if configured, otherwise just in the daily note).
   - employee_success: anniversaries or milestones for people in people/00-ORG.md -> Cascade to Team section.
   - direct_emails: read preview, extract ask or intel, route to Active Board or entity file.
   - other_human: FYI only if substantive; most are noise.

3. Update daily/${TODAY}.md:
   - Add extracted action items to existing "## Overnight Intel" section (Action Required subsection) - do NOT create a duplicate section.
   - Add "## Email Highlights" section ONLY if there is something substantive that does not fit in Overnight Intel. Skip if all emails were filler.
   - Tag source: "Source: Email from SENDER, ${TODAY}"

4. Do NOT paste raw email previews. Extract actions, summarize, link.

Emit this exact line as your final output: CHECKPOINT step=email emails_surfaced=N commits_extracted=N waitings_extracted=N highlights_written=N
PROMPT_END

CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-6}"

claude --print --dangerously-skip-permissions --model "$CLAUDE_MODEL" --max-turns 30 -p "$(cat "$PROMPT_FILE")" </dev/null
