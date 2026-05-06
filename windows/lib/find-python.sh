#!/bin/bash
# Shared Python discovery for Windows (Git Bash).
# Source this file — it sets $PYTHON to the best available interpreter.
#
# Usage:
#   source "$(dirname "$0")/../windows/lib/find-python.sh"
#   $PYTHON scripts/some-script.py
#
# Falls back through: Windows venv → Unix venv → system python3 → system python
# Exits 1 with error message if nothing found.

if [ -f ".venv/Scripts/python.exe" ]; then
    PYTHON=".venv/Scripts/python.exe"
elif [ -f ".venv/bin/python3" ]; then
    PYTHON=".venv/bin/python3"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON="python"
else
    echo "ERROR: Python not found. Install Python 3 and ensure it's on PATH." >&2
    PYTHON=""
fi
