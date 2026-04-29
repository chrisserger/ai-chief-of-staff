#!/bin/bash
# Phase 2c — Daily note brief
# Read Active Board + Phase 1 outputs (Granola, calendar, meeting prep, entity audit)
# and write the user's EA-quality morning brief.
#
# Runs AFTER Phase 2a (commits extracted) and Phase 2b (Active Board clean).

set -u
cd "$(dirname "$0")/.." || exit 1

TODAY=$(date +%Y-%m-%d)
DOW=$(date +%A)
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
LOG_FILE="logs/morning-routine.log"
mkdir -p logs

# Friday nudge env vars (set by run-morning-routine.sh Phase 1.5)
IS_FRIDAY="${FRIDAY_NUDGE_IS_FRIDAY:-false}"
MEMORY_STALE="${FRIDAY_NUDGE_MEMORY_STALE:-false}"

echo "" >> "$LOG_FILE"
echo "=== Phase 2c — Daily note (started $(date +%H:%M:%S)) ===" >> "$LOG_FILE"

# Build prompt in a temp file — quoted heredoc for the body (no shell expansion),
# then sed in the dynamic values. Avoids apostrophe/quoting issues entirely.
PROMPT_FILE=$(mktemp /tmp/aicos-phase2c-XXXXXX.md)
trap 'rm -f "$PROMPT_FILE"' EXIT

cat > "$PROMPT_FILE" <<'PROMPT_BODY'
You are running HEADLESSLY. No human. Your job: write the user's morning brief to `daily/__TODAY__.md`.

Today is __TODAY__ (__DOW__). Yesterday was __YESTERDAY__. FRIDAY_NUDGE_IS_FRIDAY=__IS_FRIDAY__. FRIDAY_NUDGE_MEMORY_STALE=__MEMORY_STALE__.

## Sources to read — IN ORDER, MANDATORY

1. **Active Board Canvas** via `slack_read_canvas` (get canvas_id from `slack-monitor.json` → `active_board.canvas_id`) — THE ONLY SOURCE FOR FIRES. If an item is not on the Canvas right now, it is done. Period. If slack-monitor.json does not exist, skip Canvas reads and build fires from yesterday's daily note carry-forward only.
2. **Today's daily note** `daily/__TODAY__.md` — read the template/current state. Preserve Phase 1 auto-written content (schedule, meeting prep, Granola imports, 1:1 prep). Overwrite only the sections listed below.
3. **Yesterday's Granola meeting imports** — check `daily/__YESTERDAY__.md` for the `## Meetings from Granola` section (the exact header may vary). List every meeting title and attendee set. This is your RESOLUTION EVIDENCE — if the user met with someone about a topic yesterday, that topic was addressed.
4. **Phase 2a scan artifacts** — `logs/gmail-scan-__TODAY__.json`, checkpoint lines in `logs/morning-routine.log`. These feed Overnight Intel and Email Highlights.
5. **Yesterday's daily note** `daily/__YESTERDAY__.md` — for context only (what happened yesterday). NEVER copy fires from here. The Active Board is the sole fire source.

## CRITICAL: Cross-Reference Gate (execute BEFORE writing any section)

Before writing Fires, Today's Play, Overnight Intel, or Cascade to Team, build a RESOLUTION LIST by scanning these three sources:

**Source A — Granola meetings yesterday:** Read the Meetings from Granola section in yesterday's daily note. For each meeting, note the attendee names and meeting title. Any topic involving those people is presumed DISCUSSED.

**Source B — User's outbound messages:** Phase 2a (scan-yesterdays-activity.sh) already processed these and updated the Active Board. Trust the Active Board state — if Phase 2a removed something, it's resolved.

**Source C — Active Board Canvas (current state):** Read it NOW via `slack_read_canvas`. This is the LIVE source of truth. Checked items (`[x]`) are done. Deleted items are done. Only UNCHECKED items on the Canvas are open.

**THE GATE:** For every fire, action item, cascade item, or "today's move" you are about to write:
1. Is it on the Active Board Canvas RIGHT NOW as an unchecked item? If NO → do not write it.
2. Did the user have a Granola meeting yesterday with the person involved? If YES → check if the Active Board item still exists. If it's gone, the meeting resolved it. If it's still there, mention the meeting happened but note what's still open.
3. Does yesterday's daily note show this was completed? If YES → do not write it.

If you cannot confirm an item is still open on the Canvas, DO NOT include it.

## Sections to write (in this order) — all go in `daily/__TODAY__.md`

### Friday Focus (only if FRIDAY_NUDGE_IS_FRIDAY=true)
Inject at TOP above Fires. Content:
- `- Ready for weekly review? Run: \`python3 scripts/weekly-review.py\``
- `- Memory sweep due — run: \`bash scripts/memory-sweep.sh\`` — only if FRIDAY_NUDGE_MEMORY_STALE=true

### Fires & Overdue
**SOURCE: Active Board Canvas ONLY.** Read the Canvas. Pick the 3-5 most urgent unchecked items. Each: what's at stake + age in business days + ONE move today.

**MANDATORY CHECK for each fire before writing it:**
- Verify it is an unchecked item on the Canvas RIGHT NOW
- If the fire involves a person the user met with yesterday (check Granola imports), acknowledge the meeting happened and state only what remains unresolved per the Canvas
- If the fire references a Slack post or email the user already replied to (Phase 2a data), note progress and state only the remaining action

Do NOT carry fires forward from yesterday's daily note. Do NOT re-surface items checked off or deleted from the Canvas. The Canvas is the single source of truth.

### Today's Play
Top 3 priorities. For each: prep + watchout + ONE action. Max 2 lines each.
- Apply the same cross-reference gate: if a "priority" was resolved in yesterday's meetings or outbound messages, do not list it. Promote the next real priority.
- Include a watch-for list below the three priorities (double-books, optional meetings, overlaps).
- End with Energy line.

### Schedule
Clean markdown table from Phase 1's calendar pull (already in daily note). Names not emails. No personal events, no Reclaim blocks, no duplicates. For 1:1s with directs/boss/key partners: one-line personality reminder from their people/ file.

### Claudia Flags
Phase 2a wrote commits to Active Board. Read Phase 2a checkpoint output from log to know what was routed. ONE LINE per flag: `- **[subject]** ([source]) → [what was done] | [[link/to/file]]`. If zero flags: `## Claudia Flags — None since yesterday`.

### Overnight Intel
Synthesized, ACTION-ORGANIZED. Lead with headline ("Quiet overnight" or "3 things to know"). Subsections only if populated:
- `Action Required` — deadlines/asks with dates. **Apply the gate:** only include items still unresolved per the Canvas.
- `Cascade to Team` — what directs need to know. **Apply the gate:** if the user already cascaded something yesterday (check outbound messages), do not re-list it.
- `Direct Asks` — from boss/skip-level/key partners
- `FYI` — 2-3 items max, ruthlessly curated
One line, one action per bullet. No provenance unless essential.

### Email Highlights
Only if substantive. Skip entire section if nothing. Read `logs/gmail-scan-__TODAY__.json` to identify actionable items. Extract asks, paraphrase, link source. Do NOT paste email previews.

### Meeting Notes from Agent
Only if Phase 2a processed new meeting-agent notes. Link the transcript. Summarize decisions + next steps.

### System Notes (optional, HTML comment if possible)
If Phase 1 flagged sync failures, skips, etc — note here or in HTML comment. Keep out of reading path unless actionable.

## Ground rules

- The daily note is the USER's BRIEFING, not a log. Every line must help them act today.
- **FIRES COME FROM THE ACTIVE BOARD CANVAS ONLY.** Not from yesterday's daily note. Not from Slack messages. Not from email. If it is not an unchecked item on the Canvas right now, it is not a fire.
- **If a Granola meeting exists with a person, the topic was discussed.** Check the Canvas — if the item is gone, it is resolved. If the item is still there, note progress from the meeting but keep it as a fire with the REMAINING action only.
- **If the user checked off or deleted a Canvas item, it is done forever.** Never re-add it from any source.
- DO NOT paste Slack messages. DO NOT dump channel recaps.
- Dates: use `date` — never guess.
- Read today's daily note BEFORE writing. Merge sections — do not clobber Phase 1 schedule/meeting prep/1:1 prep.
- If Claudia flags section already exists from Phase 2a or earlier session, leave it alone.
- If 1:1 Prep Today section exists from an earlier phase, leave it alone.

Emit: `CHECKPOINT step=daily_note sections_written=N fires_count=N plays_count=N schedule_rows=N email_section=Y|N granola_meetings_checked=N canvas_items_checked=N`
Add the VERIFY:passed marker at the bottom as an HTML comment: `<!-- VERIFY:passed -->`
Final line: `PHASE_2C_COMPLETE date=__TODAY__`
PROMPT_BODY

# Replace placeholders with actual values
sed -i '' "s|__TODAY__|${TODAY}|g" "$PROMPT_FILE" 2>/dev/null || sed -i "s|__TODAY__|${TODAY}|g" "$PROMPT_FILE"
sed -i '' "s|__YESTERDAY__|${YESTERDAY}|g" "$PROMPT_FILE" 2>/dev/null || sed -i "s|__YESTERDAY__|${YESTERDAY}|g" "$PROMPT_FILE"
sed -i '' "s|__DOW__|${DOW}|g" "$PROMPT_FILE" 2>/dev/null || sed -i "s|__DOW__|${DOW}|g" "$PROMPT_FILE"
sed -i '' "s|__IS_FRIDAY__|${IS_FRIDAY}|g" "$PROMPT_FILE" 2>/dev/null || sed -i "s|__IS_FRIDAY__|${IS_FRIDAY}|g" "$PROMPT_FILE"
sed -i '' "s|__MEMORY_STALE__|${MEMORY_STALE}|g" "$PROMPT_FILE" 2>/dev/null || sed -i "s|__MEMORY_STALE__|${MEMORY_STALE}|g" "$PROMPT_FILE"

PROMPT=$(cat "$PROMPT_FILE")
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-6}"

echo "▸ Phase 2c — invoking Claude CLI (budget: 7 min)..." >> "$LOG_FILE"
claude --print --dangerously-skip-permissions --model "$CLAUDE_MODEL" --max-turns 30 -p "$PROMPT" </dev/null >> "$LOG_FILE" 2>&1 &
CLAUDE_PID=$!

(sleep 420 && kill "$CLAUDE_PID" 2>/dev/null) &
TIMER_PID=$!

wait "$CLAUDE_PID" 2>/dev/null
CLAUDE_EXIT=$?
kill "$TIMER_PID" 2>/dev/null

echo "▸ Phase 2c done (exit ${CLAUDE_EXIT})" >> "$LOG_FILE"
exit 0
