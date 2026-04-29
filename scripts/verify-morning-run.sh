#!/bin/bash
# verify-morning-run.sh — forcing function for the morning routine
#
# Runs AFTER Phase 2 Claude CLI exits. Parses logs/morning-routine.log for
# the FINAL_CHECKPOINT line emitted by the Phase 2 prompt, verifies today's
# daily note has the required section headers, and — if anything is missing
# — prepends a RED BANNER to today's daily note so the user immediately sees
# the automation failed. If all checks pass, appends a quiet VERIFY:passed
# HTML comment so future sessions can confirm the routine ran clean.
#
# Exit codes:
#   0 = all checks passed
#   1 = one or more checks failed (banner written to daily note)

set -u

cd "$(dirname "$0")/.." || exit 1

TODAY=$(date +%Y-%m-%d)
DAILY_NOTE="daily/${TODAY}.md"
LOG_FILE="logs/morning-routine.log"

FAILURES=()

# ─────────────────────────────────────────────────────────────────
# 1. Daily note exists and has required sections
# ─────────────────────────────────────────────────────────────────

if [ ! -f "$DAILY_NOTE" ]; then
    FAILURES+=("Daily note missing: $DAILY_NOTE")
else
    grep -q "^## 🔥 Fires" "$DAILY_NOTE"       || FAILURES+=("Missing section: 🔥 Fires & Overdue")
    grep -q "^## 🎯 Today's Play" "$DAILY_NOTE" || FAILURES+=("Missing section: 🎯 Today's Play")
    grep -q "^## 📅 Schedule" "$DAILY_NOTE"    || FAILURES+=("Missing section: 📅 Schedule")
    # Claudia flags section is only expected if slack-monitor.json exists
    if [ -f "slack-monitor.json" ]; then
        grep -qE "^## 🔔 Claudia" "$DAILY_NOTE" || FAILURES+=("Missing section: 🔔 Claudia Flags — scan didn't run")
    fi
fi

# ─────────────────────────────────────────────────────────────────
# 2. Parse the last FINAL_CHECKPOINT for TODAY's date
# ─────────────────────────────────────────────────────────────────

if [ ! -f "$LOG_FILE" ]; then
    FAILURES+=("Log file missing: $LOG_FILE")
else
    # Primary signal: PHASE_2C_COMPLETE (from the Phase 2 split architecture)
    # or FINAL_CHECKPOINT (from legacy monolithic Phase 2). Accept either.
    FINAL_LINE=$(grep -E "^(FINAL_CHECKPOINT|PHASE_2C_COMPLETE) date=${TODAY}" "$LOG_FILE" | tail -1)

    if [ -z "$FINAL_LINE" ]; then
        FAILURES+=("Missing PHASE_2C_COMPLETE for ${TODAY} — Phase 2c did not finish writing the daily note")
    else
        # Parse FINAL_CHECKPOINT fields and apply sanity checks
        CLAUDIA=$(echo "$FINAL_LINE" | grep -oE "claudia=[0-9]+" | cut -d= -f2)
        USER_MSGS=$(echo "$FINAL_LINE" | grep -oE "user_msgs=[0-9]+" | cut -d= -f2)
        CHANNELS_OK=$(echo "$FINAL_LINE" | grep -oE "channels_ok=[0-9]+" | cut -d= -f2)
        EMAILS=$(echo "$FINAL_LINE" | grep -oE "emails_surfaced=[0-9]+" | cut -d= -f2)
        DAILY_SECTIONS=$(echo "$FINAL_LINE" | grep -oE "daily_note_sections=[0-9]+" | cut -d= -f2)

        # Email scan should have produced JSON output in Phase 1
        # (only check if email-monitor.json is configured)
        if [ -f "email-monitor.json" ]; then
            EMAIL_JSON="logs/gmail-scan-${TODAY}.json"
            if [ ! -f "$EMAIL_JSON" ]; then
                FAILURES+=("Gmail scan output missing: $EMAIL_JSON")
            fi
            if [ -z "${EMAILS:-}" ]; then
                FAILURES+=("emails_surfaced missing from FINAL_CHECKPOINT — Phase 2 skipped email processing")
            fi
        fi

        DOW=$(date +%u)  # 1=Mon..7=Sun
        IS_WEEKDAY=0
        [ "$DOW" -ge 1 ] && [ "$DOW" -le 5 ] && IS_WEEKDAY=1

        # Weekday sanity: if slack-monitor is configured, the user should have
        # sent Slack messages yesterday on a normal business day
        if [ -f "slack-monitor.json" ] && [ "$IS_WEEKDAY" -eq 1 ] \
           && [ -n "${USER_MSGS:-}" ] && [ "$USER_MSGS" -eq 0 ]; then
            FAILURES+=("user_msgs=0 on a weekday — likely a scan failure, not a quiet day")
        fi

        # At least some channels should scan OK if slack-monitor is configured
        if [ -f "slack-monitor.json" ] && [ -n "${CHANNELS_OK:-}" ] && [ "$CHANNELS_OK" -lt 3 ]; then
            FAILURES+=("channels_ok=${CHANNELS_OK} — too few channels returned data, scan likely broken")
        fi

        # Daily note must have at least 3 real sections (Fires, Today's Play, Schedule minimum)
        if [ -n "${DAILY_SECTIONS:-}" ] && [ "$DAILY_SECTIONS" -lt 3 ]; then
            FAILURES+=("daily_note_sections=${DAILY_SECTIONS} — brief missing required sections")
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────
# 3. Timestamp the verification run regardless
# ─────────────────────────────────────────────────────────────────

VERIFY_TS=$(date '+%Y-%m-%d %H:%M:%S')

# ─────────────────────────────────────────────────────────────────
# 4. If failures: prepend a red banner to the daily note
# ─────────────────────────────────────────────────────────────────

if [ ${#FAILURES[@]} -gt 0 ]; then
    BANNER=$(cat <<EOF
> 🚨 **MORNING ROUTINE VERIFICATION FAILED** — ${VERIFY_TS}
>
> The automated morning routine did not complete all required steps. Things may have fallen through the cracks.
>
EOF
)
    for F in "${FAILURES[@]}"; do
        BANNER="${BANNER}
> - ${F}"
    done
    BANNER="${BANNER}
>
> Check \`logs/morning-routine.log\` for details. Run \`bash scripts/scan-claudia-flags.sh\`, \`bash scripts/scan-yesterdays-activity.sh\`, and/or \`bash scripts/scan-email.sh\` to backfill manually.

"

    # Prepend to daily note (keep existing content)
    if [ -f "$DAILY_NOTE" ]; then
        TMP=$(mktemp)
        echo "$BANNER" > "$TMP"
        cat "$DAILY_NOTE" >> "$TMP"
        mv "$TMP" "$DAILY_NOTE"
    fi

    echo "VERIFY: FAILED — ${#FAILURES[@]} issues. Banner written to $DAILY_NOTE"
    for F in "${FAILURES[@]}"; do echo "  - $F"; done
    exit 1
else
    # Success — append a quiet footer so sessions can confirm verification ran
    if [ -f "$DAILY_NOTE" ] && ! grep -q "VERIFY:passed" "$DAILY_NOTE"; then
        echo "" >> "$DAILY_NOTE"
        echo "<!-- VERIFY:passed ${VERIFY_TS} -->" >> "$DAILY_NOTE"
    fi
    echo "VERIFY: PASSED — all checkpoints present, all sections written (${VERIFY_TS})"
    exit 0
fi
