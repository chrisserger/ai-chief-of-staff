#!/bin/bash
# Morning Auto-Routine — runs daily (typically 6 AM local time) via launchd/cron
#
# Phase 0: Wait for network (macOS launchd fires before wifi connects)
# Phase 1: Bash/Python automated steps (Granola sync, calendar, contacts, Gmail, etc.)
# Phase 1.5: Compute Friday nudge flags
# Phase 2: Claude CLI — three focused sub-scripts (scans, Active Board, daily note)
# Phase 3: Verify forcing function (red banner in daily note if anything incomplete)
#
# Secrets are loaded from macOS Keychain if available — never store them in the plist.
# If you're not on macOS, set the env vars directly in your launcher.

set -euo pipefail

# Secrets (optional — only needed if you use Pinecone / Gemini / other APIs)
if command -v security >/dev/null 2>&1; then
    export PINECONE_API_KEY=$(security find-generic-password -a "aicos" -s "PINECONE_API_KEY" -w 2>/dev/null || echo "")
    export GEMINI_API_KEY=$(security find-generic-password -a "aicos" -s "GEMINI_API_KEY" -w 2>/dev/null || echo "")
fi

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${HOME}/.local/bin"

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
# PHASE 0: Wait for network.
# Fixes launchd-fires-before-wifi failure on macOS.
# ─────────────────────────────────────────────────────────────────
if [ -f scripts/wait-for-network.sh ]; then
    bash scripts/wait-for-network.sh || echo "⚠ Network wait timed out — Phase 1 may have failures"
fi

# ─────────────────────────────────────────────────────────────────
# PHASE 1: Automated bash/python steps
# ─────────────────────────────────────────────────────────────────

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
# PHASE 1.5: Compute Friday nudge flags (consumed by Phase 2 prompt)
# ─────────────────────────────────────────────────────────────────

# Day of week: 1=Mon ... 5=Fri, 6=Sat, 7=Sun
DAY_OF_WEEK=$(date +%u)
IS_FRIDAY="false"
[ "$DAY_OF_WEEK" = "5" ] && IS_FRIDAY="true"

# Memory staleness check — any memory file older than 14 days?
MEMORY_DIR=$(find ~/.claude/projects/ -path "*/memory" -type d 2>/dev/null | head -1)
MEMORY_STALE="false"
if [ -n "$MEMORY_DIR" ] && [ -d "$MEMORY_DIR" ]; then
    STALE_COUNT=$(find "$MEMORY_DIR" -name "*.md" -type f -mtime +14 2>/dev/null | wc -l | tr -d ' ')
    [ "$STALE_COUNT" -gt 0 ] && MEMORY_STALE="true"
fi

export FRIDAY_NUDGE_IS_FRIDAY="$IS_FRIDAY"
export FRIDAY_NUDGE_MEMORY_STALE="$MEMORY_STALE"

# ─────────────────────────────────────────────────────────────────
# PHASE 2: Claude CLI — three focused sub-scripts
# ─────────────────────────────────────────────────────────────────

if ! command -v claude >/dev/null 2>&1; then
    echo "⏭  Claude CLI not found on PATH — skipping Phase 2."
    echo "   Install Claude Code to enable AI-powered brief generation."
    echo ""
else
    echo "▸ Phase 2: Invoking Claude CLI for AI work..."
    echo ""

    BEFORE_MTIME=$(stat -f %m "$DAILY_NOTE" 2>/dev/null || stat -c %Y "$DAILY_NOTE" 2>/dev/null || echo 0)

    echo ""
    echo "▸ Phase 2a — Scans (emoji flags + user messages + email)..."
    bash scripts/phase2a-scans.sh
    PHASE2A_EXIT=$?
    echo "  Phase 2a exit: $PHASE2A_EXIT"

    echo ""
    echo "▸ Phase 2b — Active Board cleanup..."
    bash scripts/phase2b-active-board.sh
    PHASE2B_EXIT=$?
    echo "  Phase 2b exit: $PHASE2B_EXIT"

    echo ""
    echo "▸ Phase 2c — Daily note brief..."
    bash scripts/phase2c-daily-note.sh
    PHASE2C_EXIT=$?
    echo "  Phase 2c exit: $PHASE2C_EXIT"

    # Verify by artifact: did the daily note get updated?
    AFTER_MTIME=$(stat -f %m "$DAILY_NOTE" 2>/dev/null || stat -c %Y "$DAILY_NOTE" 2>/dev/null || echo 0)
    if [ "$AFTER_MTIME" -gt "$BEFORE_MTIME" ]; then
        echo "✓ Phase 2 complete — daily note updated"
    else
        echo "⚠ Phase 2 did not update the daily note"
        echo "  Phase 2a exit=$PHASE2A_EXIT, 2b=$PHASE2B_EXIT, 2c=$PHASE2C_EXIT"
        echo "  Phase 1 automated steps completed successfully regardless."
    fi
fi

# ─────────────────────────────────────────────────────────────────
# PHASE 3: Verify — forcing function
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
