#!/bin/bash
# scan-claudia-flags.sh — manual trigger for the Claudia emoji scan
#
# Usage: bash scripts/scan-claudia-flags.sh [YYYY-MM-DD]
#   (no arg = scan since yesterday)
#
# Thin wrapper that launches Claude CLI with a focused prompt. Use when the
# morning routine's verify check fails with "claudia_emoji checkpoint missing"
# or any time you want to force a re-scan.
#
# Config:
#   slack-monitor.json claudia_emoji.search_query (e.g. hasmy::claudia:)
#   slack-monitor.json claudia_emoji.routing (where each content type goes)
#   slack-monitor.json active_board.canvas_id (for commitment routing)
# If slack-monitor.json is missing, this script exits 0 with a log line -
# Slack integration isn't configured yet.

set -u

cd "$(dirname "$0")/.." || exit 1

SINCE="${1:-$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)}"
TODAY=$(date +%Y-%m-%d)
CONFIG="slack-monitor.json"

if [ ! -f "$CONFIG" ]; then
    echo "Skipping: $CONFIG not found - Slack integration not configured yet."
    echo "See docs/slack-monitor-setup.md to set up."
    exit 0
fi

# Build the prompt in a tempfile (avoids heredoc-in-subshell apostrophe parsing
# issues when prose contains contractions like don't / doesn't / user's).
PROMPT_FILE=$(mktemp /tmp/claudia-scan-XXXXXX.md)
trap 'rm -f "$PROMPT_FILE"' EXIT

cat > "$PROMPT_FILE" <<PROMPT_END
You are running headlessly. One job: scan for flagged Slack messages since ${SINCE} and process them.

1. Read slack-monitor.json claudia_emoji to get: search_query (e.g. hasmy::claudia:), routing (map of content-type to destination file), and active_board.canvas_id for commitment routing.

2. Slack search: use the search_query from the config with date filter after:${SINCE}. Call mcp__slack__slack_search_public_and_private.

3. For each result: read the thread via mcp__slack__slack_read_thread.

4. Figure out the user intent. Why would they flag THIS to you? Pick the most likely:
   - Action item for the user: extract commit, add to Active Board Canvas in the right section.
   - Cascade to directs: note which directs need to know, add to daily note Cascade-to-Team section.
   - Customer or deal intel: update the relevant customers/ or deals/ file.
   - Win, loss, or shoutout: route to team/shoutouts-log.md or the deal file outcome section.
   - Person intel (behavior, preference, role change): update the people/ file.
   - FYI worth keeping: route to the right KB file (products/, analysis/, etc.).

5. In today daily note (daily/${TODAY}.md), write ONE LINE per flag under "## Claudia Flags":
   - **[short subject]** ([source]) -> [what you did in one phrase] | [[path/to/file.md]]
   Do NOT paste the original post content. Do NOT write out timelines, tables, or quote summaries. The user saw the post. They want to know WHAT YOU DID.

6. If the flagged post has substantive reference content that does not fit an existing file (e.g. multi-paragraph process kickoff), create or append to a KB file in the right folder (team/playbooks/, team/planning/, etc.) and link from the one-line entry.

7. If zero flags found: write one line "## Claudia Flags - None since ${SINCE}" to daily/${TODAY}.md and exit.

Emit this exact line as your final output: CHECKPOINT step=claudia_emoji flags_found=N flags_processed=N routed_to_kb=N commits_added=N
PROMPT_END

# Model name: Salesforce Bedrock default. Override in your terminal with a
# different --model flag if running outside Salesforce.
claude --print --dangerously-skip-permissions --model us.anthropic.claude-opus-4-7 --max-turns 30 -p "$(cat "$PROMPT_FILE")"
