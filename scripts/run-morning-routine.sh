#!/bin/bash
# Morning Auto-Routine — runs daily (typically 6 AM local time) via launchd/cron
#
# Phase 1: Bash/Python automated steps (Granola sync, calendar, contacts, Gmail, etc.)
# Phase 2: Claude CLI completes the AI work (Slack synthesis, daily brief generation)
# Phase 3: Verify forcing function (red banner in daily note if anything incomplete)
#
# Secrets are loaded from macOS Keychain if available — never store them in the plist.
# If you're not on macOS, set the env vars directly in your launcher.

set -euo pipefail

# Secrets (optional — only needed if you use Pinecone / Gemini / other APIs)
# Comment these out if you don't have them configured yet; scripts degrade gracefully.
if command -v security >/dev/null 2>&1; then
    export PINECONE_API_KEY=$(security find-generic-password -a "aicos" -s "PINECONE_API_KEY" -w 2>/dev/null || echo "")
    export GEMINI_API_KEY=$(security find-generic-password -a "aicos" -s "GEMINI_API_KEY" -w 2>/dev/null || echo "")
fi

# Path setup — launchd strips PATH by default, so set it explicitly here.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${HOME}/.local/bin"

# PROJECT_DIR: the directory containing this script's parent (i.e. the vault root).
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="${PROJECT_DIR}/logs/morning-routine.log"
TODAY=$(date +%Y-%m-%d)
DAILY_NOTE="${PROJECT_DIR}/daily/${TODAY}.md"

mkdir -p "${PROJECT_DIR}/logs"

cd "$PROJECT_DIR"

echo ""
echo "==============================================================="
echo "MORNING AUTO-ROUTINE — ${TODAY}"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==============================================================="
echo ""

# ─────────────────────────────────────────────────────────────────
# PHASE 1: Automated bash/python steps
# ─────────────────────────────────────────────────────────────────
#
# Runs scripts/morning-routine.sh (the deterministic pipeline). This is where
# Granola sync, calendar fetch, entity audit, Gmail scan (if configured), etc.
# happen. Phase 1 should NEVER require a Claude session.

echo "▸ Phase 1: Running automated steps..."
echo ""

if [ -f scripts/morning-routine.sh ]; then
    PHASE1_OUTPUT=$(bash scripts/morning-routine.sh 2>&1) || true
    PHASE1_EXIT=$?
    echo "$PHASE1_OUTPUT"
else
    PHASE1_OUTPUT="(no scripts/morning-routine.sh found — Phase 1 skipped)"
    PHASE1_EXIT=0
    echo "$PHASE1_OUTPUT"
fi
echo ""

if [ $PHASE1_EXIT -ne 0 ]; then
    echo "⚠ Phase 1 exited with code ${PHASE1_EXIT} — continuing to Phase 2"
fi

echo ""
echo "▸ Phase 1 complete."
echo ""

# ─────────────────────────────────────────────────────────────────
# PHASE 2: Claude CLI — AI-powered daily brief + Slack synthesis
# ─────────────────────────────────────────────────────────────────
#
# This phase requires Claude CLI to be on your PATH (`claude` command).
# If it isn't, skip Phase 2 and still run the verify step.

if ! command -v claude >/dev/null 2>&1; then
    echo "⏭  Claude CLI not found on PATH — skipping Phase 2."
    echo "   Install Claude Code to enable AI-powered brief generation."
    echo ""
else
    echo "▸ Phase 2: Invoking Claude CLI for AI work..."
    echo ""

    # Write the prompt to a temp file to avoid quoting issues with Phase 1 output
    PROMPT_FILE=$(mktemp /tmp/aicos-morning-XXXXXX.md)
    trap 'rm -f "$PROMPT_FILE"' EXIT

    cat > "$PROMPT_FILE" <<'PROMPT_HEADER'
You are running HEADLESSLY as the morning auto-routine. There is no human in this conversation. You are the user's AI Chief of Staff. Your job is to ensure nothing falls through the cracks.

## Execution order — execute in this exact sequence

Every step below is MANDATORY (unless its required integration isn't configured — see skip rules). Every step emits a checkpoint line to stdout. A verification script runs after you finish and will post a RED BANNER to the user's daily note if any checkpoint is missing or zero-when-it-should-be-nonzero. Do not skip steps to save time — verification will catch it.

**Integration prerequisites** (gracefully skip steps whose integration isn't wired):
- Steps that use Slack MCP require `slack-monitor.json` at the repo root. If missing, skip silently and still emit the checkpoint with `skipped=true`.
- Gmail processing requires `email-monitor.json` at the repo root and `logs/gmail-scan-YYYY-MM-DD.json` from Phase 1.
- Active Board sync requires `slack-monitor.json` → `active_board.canvas_id`.

### Step 1 — Claudia emoji flags (always first, if Slack configured)

**Mindset:** When the user hits the configured flag emoji on a post, they're telling YOU to deal with it — they already read it. Your job is to do the work and report what you did, NOT quote the post back.

Read `slack-monitor.json` → `claudia_emoji.search_query` and `claudia_emoji.emoji_name`. Example: `hasmy::claudia:`. Compute yesterday with `date -v-1d +%Y-%m-%d` (or `date -d "yesterday" +%Y-%m-%d` on Linux) and add `after:YESTERDAY_DATE` to the search.

Call `mcp__slack__slack_search_public_and_private` with that query.

For each flag:
1. Read the thread with `mcp__slack__slack_read_thread` for full context.
2. Figure out the user's intent. Pick the most likely:
   - Action item for the user → extract commit, add to Active Board Canvas.
   - Cascade to directs → note which directs need to know; add to daily note's Cascade-to-Team section.
   - Customer or deal intel → update the relevant `customers/` or `deals/` file.
   - Win, loss, or shoutout → route to `team/shoutouts-log.md` or the deal file's outcome section.
   - Person intel → update the `people/` file.
   - FYI worth keeping → route to the right KB file (`products/`, `analysis/`, etc.).
3. In today's daily note, write ONE LINE per flag under `## 🔔 Claudia Flags`:
   `- **[short subject]** ([source]) → [what I did in one phrase] | [[path/to/file.md]]`
4. DO NOT paste the original message content. DO NOT write out timelines, tables, or quote summaries. The user saw the post. They want to know WHAT YOU DID.
5. If the flagged post has substantive reference content that doesn't fit an existing file, create or append to a KB file (`team/playbooks/`, `team/planning/`, etc.) and link from the one-liner.

If zero flags: write one line `## 🔔 Claudia Flags — None since yesterday` and move on.

**Emit checkpoint:** `CHECKPOINT step=claudia_emoji flags_found=N flags_processed=N routed_to_kb=N commits_added=N`

### Step 2 — User's own messages yesterday

Read `slack-monitor.json` for the user's own Slack user ID field (e.g., `chris_user_id` or whatever is named there).

Search `from:<@USER_ID> on:YESTERDAY_DATE` (use Friday's date if today is Monday). Paginate until exhausted.
- Purpose: understand what the user did, committed to, delegated, and discussed. This is THE single best signal of active workload.
- For each message with substantive content: extract `⭐ COMMIT` (user committed to do X) → Active Board; extract `⏳ WAITING` (user asked someone else) → Active Board; extract entity intel → customer/deal/people files; update existing Fires so nothing already completed reappears.
- Do NOT write a standalone "yesterday's activity" section in the daily note. Use the data to make Fires, Today's Play, and entity files accurate.

**Emit checkpoint:** `CHECKPOINT step=user_messages messages_scanned=N commits_extracted=N waitings_extracted=N entities_updated=N`

### Step 3 — Automated DMs (config-driven)

Read `slack-monitor.json` → `dm_contacts.automated.contacts[]`. Scan EVERY contact in that list — do not hardcode a subset. If the config changes, this step changes with it — never skip a listed contact.

For each contact, read DM history since yesterday 5 PM local time. Use `user_id` for human DMs, `channel_id` for DMs that are really DM channel IDs (anything starting with `D`).

**Extraction rules by contact type:**
- Human DMs: Extract asks and commitments. Anything >24h unanswered from the user's boss or skip-level → flag prominently in Fires.
- Meeting-notes bot DMs (e.g., Gemini, Otter, Fireflies): For each meeting post, extract title, summary (1-2 lines), ALIGNED decisions (commitments for whoever owns them), NEEDS-FURTHER-DISCUSSION items (open questions), next steps by owner. Surface items owned by the user's directs. Link the transcript. Write synthesized output under `## 🤖 Meeting Notes from Agent`.

**Emit checkpoint:** `CHECKPOINT step=dms dms_scanned=N messages_read=N asks_extracted=N agent_meetings_processed=N`

### Step 4a — Gmail scan (process Phase 1 output)

Phase 1 wrote Gmail scan results to `logs/gmail-scan-YYYY-MM-DD.json`. If that file doesn't exist, skip this step with `skipped=true`.

Read the file. For each message in `messages[]`:
- Apply the handler for its `bucket`:
  - `the_daily` → corp newsletter content. Extract dated announcements (deadlines, events, downtime) as action items in Overnight Intel. Skip generic recognition filler.
  - `workday_tasks` → pending approvals = ⭐ COMMIT → Active Board.
  - `employee_success` → anniversaries/milestones for people in `people/00-ORG.md` → Cascade to Team ("reach out to X for 5-year anniversary").
  - `direct_emails` → real human email mentioning your org/products. Read the preview, extract the ask or intel. Commit/waiting → Active Board. Entity intel → customer/deal/people file.
  - `other_human` → briefly note in FYI only if substantive; most are noise.
- Extract commitments the same as Slack: `⭐ COMMIT:` → Active Board, `⏳ WAITING:` → Active Board.
- Tag source: `Source: Email from SENDER, YYYY-MM-DD`.

Output goes into `## 📡 Overnight Intel` (action items) and/or `## 📧 Email Highlights` only if there's something substantive worth pulling out of the narrative flow. Skip `📧 Email Highlights` entirely if the only emails were filler. DO NOT paste email previews — extract the action, summarize, link.

**Emit checkpoint:** `CHECKPOINT step=email emails_surfaced=N commits_extracted=N waitings_extracted=N highlights_written=N`

### Step 4b — Channel scan

Read `slack-monitor.json` and scan all channels with `"scan": "automated"` — iterate across every tier (tier1_org, tier2_upward, tier3_*, etc.). Use the channel IDs from the JSON.

- For each channel: read messages since yesterday 5 PM local time. If the channel errors or returns nothing, add the channel name to the checkpoint's `channels_failed` list.
- Deduplicate across channels — the same announcement often shows up in multiple places. Synthesize into actionable intel — do NOT write per-channel recaps.

**Emit checkpoint:** `CHECKPOINT step=channels channels_scanned=N channels_failed=[comma,sep,list] messages_read=N`

### Step 5 — Write daily note sections

**Mindset:** The daily note is the USER's BRIEFING, not YOUR LOG. Every line must help them act today. If a line is "system telemetry" (channels scanned, checkpoints hit, what tools you ran), it does NOT belong in the daily note — it goes in the log or an HTML comment.

**The test:** If the user can't do anything with a line at 9 AM on their phone between meetings, cut it.

Required sections in this order:
- `## 🔥 Fires & Overdue` — from Active Board Canvas only. 3-5 items max. Each item = what's at stake + age + the ONE move today. No provenance metadata.
- `## 🎯 Today's Play` — top 3 priorities. For each: prep + watchout + the ONE action. Keep each bullet to ≤2 lines.
- `## 📅 Schedule` — clean table. Names not emails. No personal events, no Reclaim blocks, no duplicates. For 1:1s with directs/boss/key partners: one-line personality reminder pulled from their `people/` file.
- `## 🔔 Claudia Flags` — ONE LINE per flag. Format: `- **[subject]** ([source]) → [what I did] | [[link to real file]]`. No pasted content. No timelines.
- `## 📡 Overnight Intel` — headline first ("Quiet night" or "3 things to know") + action-organized bullets. Subsections only if they have content: `🔴 Action Required`, `📢 Cascade to Team`, `💬 Direct Asks`, `📌 FYI` (2-3 items max — be ruthless). Each bullet: one line, one action.
- `## 📧 Email Highlights` — only if something substantive landed. Skip the whole section if nothing.

**What NEVER goes in the daily note:**
- Full Slack message copy-paste.
- Timelines/tables that were already in the source post (the source exists; link to it).
- Channel-scan reports ("scanned X, failed Y").
- "Auto-generated at HH:MM" timestamps.
- Regex-extracted commitments.
- Any content that duplicates something on the Active Board Canvas.

**Date integrity:** any day-of-week + date pair (e.g., "Friday Apr 25") MUST be computed with `date`. Never parrot.

**Emit checkpoint:** `CHECKPOINT step=daily_note sections_written=N fires_count=N plays_count=N schedule_rows=N`

### Step 6 — Active Board Canvas sync

Read `slack-monitor.json` → `active_board.canvas_id`. Use `slack_read_canvas` first.
- Checked items (`[x]`) → remove (they're done).
- Items that were on yesterday's Canvas but are gone today → also done.
- Add new commitments from Steps 1-4 to the appropriate sections (use `active_board.sections` from the config).
- Update "This Week" header to current week dates.
- Item format: `- [ ] Action — by DUE_DATE | Source: TYPE, DATE`
- Waiting format: `- **Person** — what they owe | since DATE`
- Use `section_id` for targeted append/replace. NEVER blind-replace the entire Canvas.
- Clean up speech-to-text before adding. Only add items that are actually the user's responsibility.

**Emit checkpoint:** `CHECKPOINT step=active_board items_removed=N items_added=N`

### Step 7 — Entity audit check

Phase 1 ran the entity audit. Only surface an entity gap in the daily note if it affects TODAY'S MEETINGS (external contact with no customer file). Everything else stays out of the note.

**Emit checkpoint:** `CHECKPOINT step=entity_audit gaps_surfaced=N`

### Step 8 — Final checkpoint summary

Emit a final line in this exact format (one line, no wrapping):
`FINAL_CHECKPOINT date=YYYY-MM-DD claudia=N user_msgs=N dms=N channels_ok=N channels_failed=N emails_surfaced=N commits_added=N waitings_added=N daily_note_sections=N active_board_added=N active_board_removed=N`

## Ground rules
- Every Slack read operation that fails: log it in the appropriate `channels_failed` list. Never skip silently.
- Never guess dates. Always run `date` when you need a date or day of week.
- Never re-add an Active Board item the user deleted or checked off.
- If a meeting has a daily-note transcript, it's done — don't flag it as a fire.
- If Phase 1 reported failures (DSR sync failed, index skipped, etc.): flag them in today's daily note at the bottom in a `## ⚠️ System Notes` section so the user knows what didn't run.
- Read today's daily note BEFORE writing. Merge, don't overwrite.

## Phase 1 Output
PROMPT_HEADER

    # Append phase 1 output (may contain special chars — safe in file, not in shell args)
    echo "$PHASE1_OUTPUT" >> "$PROMPT_FILE"

    # Run Claude CLI non-interactively. Model is pinned to a known Bedrock ID
    # for Salesforce employees; override via env or edit this line for other providers.
    CLAUDE_PROMPT=$(cat "$PROMPT_FILE")
    CLAUDE_MODEL="${CLAUDE_MODEL:-us.anthropic.claude-opus-4-7}"

    claude --print --dangerously-skip-permissions --model "$CLAUDE_MODEL" --max-turns 50 -p "$CLAUDE_PROMPT" >> "$LOG_FILE" 2>&1 &
    CLAUDE_PID=$!

    # Kill after 12 minutes if still running
    (sleep 720 && kill "$CLAUDE_PID" 2>/dev/null) &
    TIMER_PID=$!

    if wait "$CLAUDE_PID" 2>/dev/null; then
        kill "$TIMER_PID" 2>/dev/null
        echo "✓ Phase 2 complete — daily brief and daily note updated"
    else
        CLAUDE_EXIT=$?
        kill "$TIMER_PID" 2>/dev/null
        if [ $CLAUDE_EXIT -eq 137 ] || [ $CLAUDE_EXIT -eq 143 ]; then
            echo "⚠ Phase 2 timed out after 12 minutes — daily brief may be stale"
        else
            echo "⚠ Phase 2 failed (exit code ${CLAUDE_EXIT}) — daily brief may be stale"
        fi
        echo "  Phase 1 automated steps completed successfully regardless."
    fi
fi

# ─────────────────────────────────────────────────────────────────
# PHASE 3: Verify — forcing function. Posts red banner to daily note if
# any mandatory checkpoint is missing.
# ─────────────────────────────────────────────────────────────────

echo ""
echo "▸ Phase 3: Verifying morning run..."
bash scripts/verify-morning-run.sh
VERIFY_EXIT=$?

echo ""
echo "==============================================================="
if [ $VERIFY_EXIT -eq 0 ]; then
    echo "MORNING AUTO-ROUTINE COMPLETE ✅ — $(date '+%H:%M:%S')"
else
    echo "MORNING AUTO-ROUTINE COMPLETE ⚠️  WITH FAILURES — $(date '+%H:%M:%S')"
    echo "See banner at top of today's daily note."
fi
echo "==============================================================="
