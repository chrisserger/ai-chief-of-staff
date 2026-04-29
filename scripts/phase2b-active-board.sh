#!/bin/bash
# Phase 2b — Active Board cleanup
# Remove completed items, clean up headers, ensure format compliance.
# Runs AFTER Phase 2a has added new commits — this step tidies the result.
#
# Requires: slack-monitor.json with active_board.canvas_id configured.
# If not configured, exits 0 — Active Board not wired yet.

set -u
cd "$(dirname "$0")/.." || exit 1

LOG_FILE="logs/morning-routine.log"
mkdir -p logs

if [ ! -f "slack-monitor.json" ]; then
    echo "Skipping Phase 2b: slack-monitor.json not found." | tee -a "$LOG_FILE"
    exit 0
fi

echo "" >> "$LOG_FILE"
echo "=== Phase 2b — Active Board cleanup (started $(date +%H:%M:%S)) ===" >> "$LOG_FILE"

PROMPT_FILE=$(mktemp /tmp/aicos-phase2b-XXXXXX.md)
trap 'rm -f "$PROMPT_FILE"' EXIT

cat > "$PROMPT_FILE" <<'PROMPT_END'
You are running HEADLESSLY. No human. Your job: clean up the Active Board Canvas.

1. Read slack-monitor.json to get active_board.canvas_id. Read the Canvas via `slack_read_canvas`.

2. Remove all items that are completed:
   - `[x]` checked items — remove from the Canvas entirely (they are done).
   - Items that were present yesterday but gone today — already removed by the user.

3. Validate format:
   - Function buckets only (People/Team, Operations, Deals/Accounts, Skills/Learning, Strategic/Longer Term, Waiting On). Delete any date-scoped headers you find.
   - Plain text + single link per cell in tables. Bold + stacked `<br>` links in table cells break the parser.

4. If Phase 2a (earlier in the same morning routine) added items, they are already there. Do NOT re-add or duplicate.

5. Use `slack_update_canvas` with `section_id` for targeted edits. NEVER blind-replace the entire Canvas.

Emit: `CHECKPOINT step=active_board items_removed=N stale_headers_deleted=N format_fixes=N`
Final line: `PHASE_2B_COMPLETE`
PROMPT_END

CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-6}"

echo "▸ Phase 2b — invoking Claude CLI (budget: 3 min)..." >> "$LOG_FILE"
claude --print --dangerously-skip-permissions --model "$CLAUDE_MODEL" --max-turns 15 -p "$(cat "$PROMPT_FILE")" </dev/null >> "$LOG_FILE" 2>&1 &
CLAUDE_PID=$!

(sleep 180 && kill "$CLAUDE_PID" 2>/dev/null) &
TIMER_PID=$!

wait "$CLAUDE_PID" 2>/dev/null
CLAUDE_EXIT=$?
kill "$TIMER_PID" 2>/dev/null

echo "▸ Phase 2b done (exit ${CLAUDE_EXIT})" >> "$LOG_FILE"
exit 0
