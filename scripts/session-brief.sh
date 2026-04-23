#!/bin/bash
# Session start brief — gives Claude instant situational awareness
# Output: one-line summary (Claude Code truncates multi-line hook output)
cd "$(dirname "$0")/.." || exit 1
TODAY=$(date +%Y-%m-%d)
DOW=$(date +%A)

# Daily note check
if [ -f "daily/${TODAY}.md" ]; then
    DAILY_STATUS="exists"
else
    DAILY_STATUS="MISSING"
fi

# Entity audit (if script exists)
if [ -f "scripts/audit-entities.py" ] && [ -f ".venv/bin/python3" ]; then
    ENTITY_SUMMARY=$(.venv/bin/python3 scripts/audit-entities.py --summary 2>/dev/null)
    if echo "$ENTITY_SUMMARY" | grep -q "All clear"; then
        ENTITY_STATUS="clean"
    else
        ENTITY_STATUS=$(echo "$ENTITY_SUMMARY" | tr '\n' ' ')
    fi
else
    ENTITY_STATUS="n/a"
fi

# Stale memory check
MEMORY_DIR=$(find ~/.claude/projects/ -path "*/memory" -type d 2>/dev/null | head -1)
if [ -n "$MEMORY_DIR" ]; then
    STALE_MEMORY=$(find "$MEMORY_DIR" -name "*.md" -mtime +30 2>/dev/null | wc -l | tr -d ' ')
else
    STALE_MEMORY=0
fi

# Build status line — only output red flags
FLAGS=""
[ "$DAILY_STATUS" = "MISSING" ] && FLAGS+="daily:MISSING "
[ "$STALE_MEMORY" -gt 0 ] && FLAGS+="memory-stale:$STALE_MEMORY "
[ "$ENTITY_STATUS" != "clean" ] && [ "$ENTITY_STATUS" != "n/a" ] && FLAGS+="entities:GAPS "

if [ -z "$FLAGS" ]; then
    echo "$DOW $TODAY — ALL CLEAR"
else
    echo "$DOW $TODAY — ${FLAGS}"
fi
