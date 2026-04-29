#!/bin/bash
# Block until network is ready, or time out.
# Fixes the "launchd fires before wifi is ready" failure on macOS.
#
# Usage:  bash scripts/wait-for-network.sh
# Exit 0 if ready, 1 if timed out.

WAIT_SECS_MAX="${WAIT_SECS_MAX:-300}"     # 5 min default cap
CHECK_HOST="${CHECK_HOST:-oauth2.googleapis.com}"
ELAPSED=0
SLEEP_INTERVAL=5

echo "[net] waiting up to ${WAIT_SECS_MAX}s for ${CHECK_HOST}..."

while [ "$ELAPSED" -lt "$WAIT_SECS_MAX" ]; do
  if curl -sS -o /dev/null --max-time 5 --connect-timeout 3 "https://${CHECK_HOST}/" 2>/dev/null; then
    echo "[net] ready after ${ELAPSED}s"
    exit 0
  fi
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

echo "[net] timed out after ${WAIT_SECS_MAX}s — ${CHECK_HOST} unreachable" >&2
exit 1
