# Windows Setup Guide

This directory contains everything needed to run ai-chief-of-staff on Windows 11 with Git Bash.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **Git for Windows** | Provides Git Bash (the shell environment) | [git-scm.com](https://git-scm.com/download/win) |
| **Python 3.10+** | Runs automation scripts | [python.org](https://www.python.org/downloads/) or `winget install Python.Python.3.12` |
| **Claude Code CLI** | AI-powered brief generation | [claude.ai/claude-code](https://claude.ai/claude-code) |
| **Obsidian** | Viewing your knowledge base | [obsidian.md](https://obsidian.md/) |

---

## Quick Start

Open Git Bash in the repo root and run:

```bash
bash windows/install.sh
```

This copies 5 Windows-compatible scripts into `scripts/`, backing up the macOS originals. That's it — the system works now.

---

## What the Installer Does

1. Backs up 5 macOS-specific scripts to `scripts/.bak-originals/`
2. Copies the Windows variants from `windows/scripts/` into `scripts/`
3. Runs a smoke test to verify `session-brief.sh` works

**Scripts replaced:**
- `session-brief.sh` — fixes Python venv path (`.venv/Scripts/` not `.venv/bin/`)
- `run-morning-routine.sh` — adds `.env` secret loading, fixes PATH for Windows
- `scan-email.sh` — cross-platform Python discovery
- `phase2a-scans.sh` — adds `taskkill` fallback for process timeouts
- `memory-sweep.sh` — included for path-convention safety

**Scripts that already work unmodified (not replaced):**
- `wait-for-network.sh`, `phase2b-active-board.sh`, `phase2c-daily-note.sh`, `scan-claudia-flags.sh`, `scan-yesterdays-activity.sh`, `verify-morning-run.sh`, `archive-daily-notes.sh`

---

## Secrets / API Keys

On macOS, secrets come from Keychain. On Windows, use a `.env` file:

```bash
cp .env.example .env
# Edit .env with your API keys
```

The `.env` file is already in `.gitignore` — it won't be committed.

**Optional: Windows Credential Manager**

If you prefer not to store keys in a plaintext file:

```powershell
# Store secrets
cmdkey /generic:aicos_PINECONE_API_KEY /user:aicos /pass:your-key-here
cmdkey /generic:aicos_GEMINI_API_KEY /user:aicos /pass:your-key-here

# Generate .env from stored credentials
powershell -ExecutionPolicy Bypass -File windows\env-from-credential-manager.ps1
```

---

## Python Virtual Environment

Windows Python venvs use a different directory structure:

```bash
python -m venv .venv

# Activate (Git Bash):
source .venv/Scripts/activate

# Install dependencies:
pip install -r requirements.txt
```

The Windows scripts look for `.venv/Scripts/python.exe` (not `.venv/bin/python3`).

---

## Scheduling the Morning Routine

The macOS version uses `launchd`. On Windows, use Task Scheduler.

**Automated setup (run as admin):**

```powershell
powershell -ExecutionPolicy Bypass -File windows\setup-task-scheduler.ps1
```

**Manual setup:**
1. Open Task Scheduler (`taskschd.msc`)
2. Create Basic Task: "AICOS Morning Routine"
3. Trigger: Daily at 6:00 AM
4. Action: Start a program
   - Program: `"C:\Program Files\Git\bin\bash.exe"`
   - Arguments: `-l -c "cd /c/Users/YOU/path/to/repo && bash scripts/run-morning-routine.sh >> logs/morning-routine.log 2>&1"`
5. Settings: check "Wake the computer to run this task"

**To test:** `schtasks /Run /TN "AICOS Morning Routine"`

**To remove:** `Unregister-ScheduledTask -TaskName "AICOS Morning Routine" -Confirm:$false`

---

## Timestamps

The macOS `date` command uses `-j -f` for parsing. Git Bash ships GNU `date` which uses `-d`:

```bash
# macOS (BSD date):
date -j -f "%Y-%m-%d %H:%M:%S %z" "2026-04-13 17:00:00 -0400" "+%s"

# Windows / Linux (GNU date):
date -d "2026-04-13 17:00:00 -0400" "+%s"
```

The scripts already handle this with fallback patterns (`date -v-1d ... || date -d "yesterday" ...`).

---

## Granola

Granola is a macOS-only app for meeting transcription. It's not available on Windows.

**Alternatives:**
- Manually paste meeting notes into your daily note
- Use another meeting transcription tool and import via the daily note
- Claude can still extract commitments from pasted notes — just talk to it

The `import-granola.py` script will simply report "cache file not found" and exit gracefully.

---

## Uninstall / Restore

To restore the original macOS scripts:

```bash
cp scripts/.bak-originals/* scripts/
rm -rf scripts/.bak-originals
```

---

## Known Limitations

| Feature | Status on Windows |
|---------|-------------------|
| Granola meeting import | Not available (macOS-only app) |
| macOS Keychain secrets | Use `.env` file or Credential Manager instead |
| `launchd` scheduling | Use Windows Task Scheduler instead |
| `date -j -f` (BSD) | Use `date -d` (GNU) — scripts handle this automatically |

---

## Troubleshooting

**"bash: command not found" in Task Scheduler**
- Ensure the full path to bash.exe is used: `"C:\Program Files\Git\bin\bash.exe"`

**Scripts produce Windows line-ending errors**
- Run: `git config --global core.autocrlf input`
- Or: `dos2unix scripts/*.sh`

**Python not found**
- Ensure Python is on your PATH: `python --version`
- Or create the venv: `python -m venv .venv`

**`kill` doesn't stop Claude CLI during timeouts**
- The Windows variant already includes a `taskkill` fallback
- If issues persist, manually kill via: `taskkill /IM node.exe /F`
