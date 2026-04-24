#!/bin/bash
# scan-yesterdays-activity.sh — manual trigger for user-activity scan
#
# Scans all of the user own Slack messages from the previous business day.
# Extracts commits, waiting-on items, and entity intel. Updates Active Board
# and daily note.
#
# Use when the morning routine verify check fails with user_msgs checkpoint
# missing or returned messages_scanned=0 on a weekday.
#
# Config: slack-monitor.json (user Slack user ID and active_board canvas_id)
# If slack-monitor.json is missing, this script exits 0 - Slack not configured.

set -u

cd "$(dirname "$0")/.." || exit 1

CONFIG="slack-monitor.json"
if [ ! -f "$CONFIG" ]; then
    echo "Skipping: $CONFIG not found - Slack integration not configured yet."
    echo "See docs/slack-monitor-setup.md to set up."
    exit 0
fi

# Determine yesterday business day: Fri if today is Mon/Sun/Sat, else yesterday
DOW=$(date +%u)
case "$DOW" in
    1) YESTERDAY=$(date -v-3d +%Y-%m-%d 2>/dev/null || date -d "3 days ago" +%Y-%m-%d) ;;
    6) YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d) ;;
    7) YESTERDAY=$(date -v-2d +%Y-%m-%d 2>/dev/null || date -d "2 days ago" +%Y-%m-%d) ;;
    *) YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d) ;;
esac
TODAY=$(date +%Y-%m-%d)

PROMPT_FILE=$(mktemp /tmp/activity-scan-XXXXXX.md)
trap 'rm -f "$PROMPT_FILE"' EXIT

cat > "$PROMPT_FILE" <<PROMPT_END
You are running headlessly. One job: scan all of the user own Slack messages from ${YESTERDAY} and extract actionable intel.

1. Read slack-monitor.json for the user Slack user ID (chris_user_id or whatever the user-id field is named) AND active_board.canvas_id.

2. Slack search: from:<@USER_ID> on:${YESTERDAY} via mcp__slack__slack_search_public_and_private. Paginate until exhausted - cursor-next until empty.

3. For each substantive message:
   - Extract COMMIT if the user promised to do something -> add to Active Board Canvas in the appropriate section.
   - Extract WAITING if the user asked someone else to do something -> add to Active Board "Waiting On" section.
   - Extract entity intel (deal/customer/person mentions) -> update customers/, deals/, people/ files.

4. Update daily/${TODAY}.md:
   - Fires and Overdue: remove any items that are completed in yesterday messages.
   - Today Play: refine if yesterday work changes today priorities.
   - DO NOT add a standalone "yesterday activity" section - the data informs the brief, it does not get dumped in.

5. Clean speech-to-text garbage before writing any commitment.

Emit this exact line as your final output: CHECKPOINT step=user_messages messages_scanned=N commits_extracted=N waitings_extracted=N entities_updated=N
PROMPT_END

claude --print --dangerously-skip-permissions --model us.anthropic.claude-opus-4-7 --max-turns 50 -p "$(cat "$PROMPT_FILE")"
