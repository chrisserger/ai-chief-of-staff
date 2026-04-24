# Slack Monitor Setup

`slack-monitor.json` is the single source of truth for Slack scanning: which channels to watch, whose DMs to read, which emoji you use to flag messages for Claude, and where your Active Board lives. The morning routine, Claudia emoji scan, and Active Board sync all read from it.

**This file is NOT shipped in the repo** — it contains your org's real channel IDs and user IDs, which are specific to you. Build it during onboarding. Until you do, Slack-dependent scripts will detect it's missing and skip the Slack steps gracefully.

---

## Quick start

1. Ask Claude: **"help me build my slack-monitor.json"**
2. Claude will walk you through it interactively — asking which channels to scan in which tier, who your automated DM contacts are, what emoji you use to flag posts, and your Active Board Canvas ID.
3. Save to `slack-monitor.json` at the repo root.

That's it. If you'd rather build it by hand, the schema is below.

---

## Schema

```json
{
  "description": "Slack monitoring config. Single source of truth for channels, DMs, and scan behavior.",
  "chris_user_id": "<YOUR_SLACK_USER_ID>",

  "channels": {
    "tier1_org": { ... },
    "tier2_upward": { ... },
    "tier3_*": { ... },
    "tier4_ondemand": { ... },
    "tier5_*": { ... },
    "excluded": { ... }
  },

  "dm_contacts": {
    "automated": { "contacts": [ ... ] },
    "interactive": { "contacts": [ ... ] }
  },

  "active_board": {
    "canvas_id": "<YOUR_CANVAS_ID>",
    "canvas_url": "https://<workspace>.slack.com/docs/<team-id>/<canvas-id>",
    "sections": [ "This Week", "People / Team", "..." ],
    "rules": { ... }
  },

  "claudia_emoji": {
    "emoji_name": "claudia",
    "search_query": "hasmy::claudia:",
    "routing": { ... },
    "scan_frequency": "Every morning routine + every interactive session start"
  },

  "scan_settings": {
    "morning_lookback_hours": 16,
    "debrief_lookback_hours": 12
  }
}
```

---

## Tier model

Channels are bucketed by scan cadence and priority. Tiers aren't fixed — rename or add your own. The defaults match a VP workflow; directors may only need tier1 + tier2.

| Tier | What | Cadence |
|---|---|---|
| **tier1_org** | Your own org channels — directs, extended team, shoutouts | Every morning |
| **tier2_upward** | Your boss's channel + any peer/leadership channels | Every morning |
| **tier3_*** | Active projects you own — create one per initiative | Every morning |
| **tier4_ondemand** | Things you look at when asked, not proactively | Only when requested |
| **tier5_*** | Weekly or scheduled scans (competitive intel, wins, AI-tooling) | Weekly / scheduled |
| **excluded** | Glob patterns to always skip | N/A |

Each channel entry looks like:
```json
{
  "name": "#my-team-channel",
  "id": "C0ABCDEF123",
  "purpose": "Directs + extended leaders — cascade items land here"
}
```

To find a channel ID: in Slack, right-click the channel → Copy link → ID is the last path segment.

---

## DM contacts

Two buckets:

- **`automated`** — DMs that get scanned as part of the 6 AM morning routine. Keep this tight: your boss, your skip-level, your top cross-functional partner, any AI meeting-notes bot you use (e.g. Gemini, Otter, Fireflies).
- **`interactive`** — DMs that only get scanned when you explicitly ask (e.g. "what did Brooks say to me this week?"). Typical entries: direct reports, key stakeholders you see regularly.

Each contact entry:
```json
{ "name": "Kate McCardle", "user_id": "U01ABCDEF", "role": "Boss" }
```

For AI meeting-notes bots (Gemini, etc.) that live in a DM channel rather than a user, use `channel_id` instead of `user_id`. The DM IDs starting with `D` go in the `channel_id` arg of `slack_read_channel`.

```json
{
  "name": "Employee Agent (Gemini)",
  "channel_id": "D0ABC123DEF",
  "role": "Corporate meeting-notes bot — PRIMARY INTEL for meetings you can't attend"
}
```

---

## Active Board

`active_board` points the system at your Slack Canvas that serves as your interactive to-do list. Every commitment Claude extracts goes here.

To set up:
1. In Slack, create a new Canvas (any channel you own, or DM yourself)
2. Add the section headers you want — e.g. "This Week", "People / Team", "DSR / Operations", "Deals / Accounts", "Strategic / Longer Term", "Waiting On"
3. Right-click the Canvas → Copy link → the ID is the last path segment (starts with `F`)
4. Paste into `active_board.canvas_id`

The `sections` array must match the section headers in your Canvas exactly (case-sensitive). Claude uses them to route items.

---

## Claudia emoji

You react to any Slack message with a custom emoji to flag it for Claude to process. Common choices: `:claudia:`, `:robot_face:`, or a custom org-specific emoji.

To set one up:
1. In Slack, add a custom emoji (Admin → Customize → Emoji) — any image of a brain / robot / your avatar works
2. Put the emoji name (without colons) in `claudia_emoji.emoji_name`
3. Set `claudia_emoji.search_query` to `hasmy::<emoji-name>:` (Slack search syntax)

The routing block tells Claude where to file content based on type:
```json
"routing": {
  "shoutout_praise": "team/shoutouts-log.md",
  "deal_intel": "deals/ or customers/ file",
  "product_info": "products/ file",
  "commitment_action": "Active Board Canvas",
  "person_context": "people/ file",
  "foundational_project": "relevant pillar canvas",
  "general_intel": "daily note with tags"
}
```

---

## Starter file

Here's a minimal working `slack-monitor.json`. Save to repo root, replace the placeholders, and you're live:

```json
{
  "description": "Slack monitoring config.",
  "chris_user_id": "U_REPLACE_ME",

  "channels": {
    "tier1_org": {
      "description": "My org channels — daily scan, extract commitments",
      "scan": "automated",
      "channels": [
        { "name": "#my-directs-channel", "id": "C_REPLACE_ME", "purpose": "My direct reports" }
      ]
    },
    "tier2_upward": {
      "description": "My boss + leadership channels",
      "scan": "automated",
      "channels": []
    }
  },

  "dm_contacts": {
    "automated": {
      "description": "DMs scanned in morning routine",
      "contacts": [
        { "name": "<Boss Name>", "user_id": "U_REPLACE_ME", "role": "Boss" }
      ]
    },
    "interactive": {
      "description": "DMs scanned on demand",
      "contacts": []
    }
  },

  "active_board": {
    "canvas_id": "F_REPLACE_ME",
    "canvas_url": "https://<workspace>.slack.com/docs/<team>/F_REPLACE_ME",
    "description": "Interactive to-do list Canvas in Slack.",
    "sections": ["This Week", "People / Team", "Deals / Accounts", "Waiting On"],
    "rules": {
      "item_format": "- [ ] Action description — by DUE_DATE | Source: MEETING_NAME, DATE",
      "waiting_format": "- **Person** — what they owe — since DATE",
      "never_replace_all": "Always read Canvas first, then use section_id to append or replace specific sections. Never blind-replace the entire Canvas."
    }
  },

  "claudia_emoji": {
    "emoji_name": "claudia",
    "search_query": "hasmy::claudia:",
    "description": "React to any Slack message with :claudia: to flag it for Claude to ingest.",
    "routing": {
      "shoutout_praise": "team/shoutouts-log.md",
      "deal_intel": "deals/ or customers/ file",
      "product_info": "products/ file",
      "commitment_action": "Active Board Canvas",
      "person_context": "people/ file",
      "general_intel": "daily note with tags"
    },
    "scan_frequency": "Every morning routine + every interactive session start"
  },

  "scan_settings": {
    "morning_lookback_hours": 16,
    "debrief_lookback_hours": 12,
    "notes": "Morning scan covers 5 PM previous day to 6 AM. Always compute timestamps with: date -j -f '%Y-%m-%d %H:%M:%S %z' 'YYYY-MM-DD HH:MM:SS -0400' '+%s'"
  }
}
```

---

## What happens if this file is missing?

Scripts detect it and skip gracefully:
- **`scripts/scan-claudia-flags.sh`** — logs "slack-monitor.json not found — skipping Claudia scan" and exits 0
- **Morning routine Phase 2** — omits Slack channel scans, DM scans, Claudia flag scan, Active Board sync; still runs everything else (calendar, Gmail, daily brief, entity audit)
- **Active Board sync** — skipped; commitments go into the daily note only

The system degrades gracefully. You can run it Day 1 without Slack; add it when ready.
