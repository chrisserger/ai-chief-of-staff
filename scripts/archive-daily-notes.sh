#!/bin/bash
# Archive daily notes older than 7 days into daily/archive/YYYY-MM/ subfolders.
# Runs as part of morning routine. Safe to run multiple times (idempotent).

set -euo pipefail

DAILY_DIR="$(cd "$(dirname "$0")/.." && pwd)/daily"
ARCHIVE_DIR="$DAILY_DIR/archive"
CUTOFF_DATE=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d)
MOVED=0

for file in "$DAILY_DIR"/????-??-??.md; do
    [ -f "$file" ] || continue
    basename=$(basename "$file" .md)

    if [[ "$basename" < "$CUTOFF_DATE" || "$basename" == "$CUTOFF_DATE" ]]; then
        month_dir="$ARCHIVE_DIR/${basename:0:7}"
        mkdir -p "$month_dir"
        mv "$file" "$month_dir/"
        MOVED=$((MOVED + 1))
    fi
done

if [ $MOVED -gt 0 ]; then
    echo "Archived $MOVED daily notes older than $CUTOFF_DATE"
else
    echo "No daily notes to archive (cutoff: $CUTOFF_DATE)"
fi
