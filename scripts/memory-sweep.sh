#!/bin/bash
# Memory sweep — check health of Claude memory files
# Run during weekly review or ad-hoc to find stale/broken memory entries

# Find the memory directory for this project
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Claude stores memory in ~/.claude/projects/<path-hash>/memory/
MEMORY_DIR=$(find ~/.claude/projects/ -path "*/memory" -type d 2>/dev/null | head -1)

if [ -z "$MEMORY_DIR" ]; then
    echo "No memory directory found. Claude memory hasn't been used yet."
    exit 0
fi

echo "MEMORY SWEEP"
echo "============"
echo "Directory: $MEMORY_DIR"
echo ""

TOTAL=0
STALE=0

for f in "$MEMORY_DIR"/*.md; do
    [ -f "$f" ] || continue
    BASENAME=$(basename "$f")
    # Cross-platform file age
    if stat -f %m "$f" >/dev/null 2>&1; then
        AGE_DAYS=$(( ( $(date +%s) - $(stat -f %m "$f") ) / 86400 ))
    else
        AGE_DAYS=$(( ( $(date +%s) - $(stat -c %Y "$f") ) / 86400 ))
    fi
    LINES=$(wc -l < "$f" | tr -d ' ')
    TOTAL=$((TOTAL + 1))

    if [ "$AGE_DAYS" -gt 14 ]; then
        echo "  !!  $BASENAME — ${AGE_DAYS} days old, ${LINES} lines — REVIEW"
        STALE=$((STALE + 1))
    else
        echo "  OK  $BASENAME — ${AGE_DAYS} days old, ${LINES} lines"
    fi
done

echo ""
echo "Total: $TOTAL files, $STALE need review"

# Check for broken file references in MEMORY.md
if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
    echo ""
    echo "Checking file references in MEMORY.md..."
    grep -oE '\([a-z/._-]+\.md\)' "$MEMORY_DIR/MEMORY.md" 2>/dev/null | tr -d '()' | while read -r ref; do
        if [ ! -f "$MEMORY_DIR/$ref" ]; then
            echo "  !!  Referenced file missing: $ref"
        fi
    done

    MEMORY_LINES=$(wc -l < "$MEMORY_DIR/MEMORY.md" | tr -d ' ')
    echo ""
    echo "MEMORY.md: ${MEMORY_LINES} lines (target: <200)"
    if [ "${MEMORY_LINES:-0}" -gt 200 ]; then
        echo "  !!  MEMORY.md exceeds 200 lines — consolidate"
    fi
fi
