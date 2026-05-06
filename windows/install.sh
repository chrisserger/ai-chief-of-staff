#!/bin/bash
# windows/install.sh — One-time setup for Windows (Git Bash)
#
# Copies the Windows-compatible script variants into scripts/, backing up
# the macOS originals. Safe to run multiple times (idempotent).
#
# Usage: bash windows/install.sh

set -euo pipefail

# Detect platform
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" && -z "${MINGW_PREFIX:-}" ]]; then
    echo "⚠  This installer is for Windows (Git Bash) only."
    echo "   Detected OSTYPE=$OSTYPE"
    echo "   On macOS/Linux, the scripts in scripts/ already work natively."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_DIR/scripts/.bak-originals"
WINDOWS_SCRIPTS="$SCRIPT_DIR/scripts"

# Files to replace
FILES=(
    "session-brief.sh"
    "run-morning-routine.sh"
    "scan-email.sh"
    "phase2a-scans.sh"
    "memory-sweep.sh"
)

echo "AI Chief of Staff — Windows Install"
echo "===================================="
echo ""
echo "Project: $PROJECT_DIR"
echo "Source:  $WINDOWS_SCRIPTS"
echo ""

# Back up originals (only on first run)
if [ ! -d "$BACKUP_DIR" ]; then
    echo "▸ Backing up original macOS scripts to scripts/.bak-originals/..."
    mkdir -p "$BACKUP_DIR"
    echo "*" > "$BACKUP_DIR/.gitignore"
    for f in "${FILES[@]}"; do
        if [ -f "$PROJECT_DIR/scripts/$f" ]; then
            cp "$PROJECT_DIR/scripts/$f" "$BACKUP_DIR/$f"
        fi
    done
    echo "  Done — ${#FILES[@]} files backed up."
else
    echo "▸ Backup already exists (scripts/.bak-originals/) — skipping backup."
fi
echo ""

# Copy Windows variants into scripts/
echo "▸ Installing Windows-compatible scripts..."
for f in "${FILES[@]}"; do
    if [ -f "$WINDOWS_SCRIPTS/$f" ]; then
        cp "$WINDOWS_SCRIPTS/$f" "$PROJECT_DIR/scripts/$f"
        echo "  ✓ scripts/$f"
    else
        echo "  ⚠ Missing: windows/scripts/$f — skipped"
    fi
done
echo ""

# Smoke test
echo "▸ Smoke test: running scripts/session-brief.sh..."
RESULT=$(bash "$PROJECT_DIR/scripts/session-brief.sh" 2>&1) || true
echo "  Output: $RESULT"
echo ""

if [ -n "$RESULT" ]; then
    echo "✅ Install complete!"
else
    echo "⚠  Install complete but smoke test produced no output — check scripts/session-brief.sh"
fi

echo ""
echo "Next steps:"
echo "  1. Copy .env.example to .env and fill in your API keys"
echo "  2. Create a Python venv: python -m venv .venv && .venv/Scripts/pip install -r requirements.txt"
echo "  3. Schedule morning routine: powershell windows/setup-task-scheduler.ps1 (run as admin)"
echo "  4. See windows/README.md for full details"
echo ""
echo "To restore original macOS scripts: cp scripts/.bak-originals/* scripts/"
