#!/bin/bash
# Phase 2a — Scans: orchestrates three focused standalone scans.
# Each scan is its own script with its own Claude CLI invocation and timer.
# Failures in one don't cascade — each has its own budget.
#
# This replaces the monolithic prompt that kept timing out at 12 min.

set -u
cd "$(dirname "$0")/.." || exit 1

TODAY=$(date +%Y-%m-%d)
LOG_FILE="logs/morning-routine.log"
mkdir -p logs

echo "" >> "$LOG_FILE"
echo "=== Phase 2a — Scans (started $(date +%H:%M:%S)) ===" >> "$LOG_FILE"

# Sub-scan 1: Claudia emoji flags (most critical, runs first)
echo "  ▸ Scanning emoji flags..." | tee -a "$LOG_FILE"
timeout_kill() {
  local pid=$1
  local secs=$2
  (sleep "$secs" && kill "$pid" 2>/dev/null) &
  echo $!
}

bash scripts/scan-claudia-flags.sh >> "$LOG_FILE" 2>&1 &
CLAUDIA_PID=$!
TIMER=$(timeout_kill $CLAUDIA_PID 300)  # 5 min
wait $CLAUDIA_PID 2>/dev/null
CLAUDIA_EXIT=$?
kill $TIMER 2>/dev/null
echo "  ▸ Emoji scan done (exit $CLAUDIA_EXIT)" | tee -a "$LOG_FILE"

# Sub-scan 2: User's yesterday activity
echo "  ▸ Scanning yesterday's messages..." | tee -a "$LOG_FILE"
bash scripts/scan-yesterdays-activity.sh >> "$LOG_FILE" 2>&1 &
ACTIVITY_PID=$!
TIMER=$(timeout_kill $ACTIVITY_PID 420)  # 7 min — users often have 50+ messages/day
wait $ACTIVITY_PID 2>/dev/null
ACTIVITY_EXIT=$?
kill $TIMER 2>/dev/null
echo "  ▸ Activity scan done (exit $ACTIVITY_EXIT)" | tee -a "$LOG_FILE"

# Sub-scan 3: Email
echo "  ▸ Processing email..." | tee -a "$LOG_FILE"
bash scripts/scan-email.sh >> "$LOG_FILE" 2>&1 &
EMAIL_PID=$!
TIMER=$(timeout_kill $EMAIL_PID 300)  # 5 min
wait $EMAIL_PID 2>/dev/null
EMAIL_EXIT=$?
kill $TIMER 2>/dev/null
echo "  ▸ Email scan done (exit $EMAIL_EXIT)" | tee -a "$LOG_FILE"

echo "=== Phase 2a done (emoji=$CLAUDIA_EXIT activity=$ACTIVITY_EXIT email=$EMAIL_EXIT) ===" >> "$LOG_FILE"
exit 0
