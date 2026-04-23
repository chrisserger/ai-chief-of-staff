# Granola — Meeting Transcription

[Granola](https://granola.ai/) captures meeting transcripts and notes automatically. Claude reads the local cache — no API keys or configuration needed.

## What You Get

Once Granola is installed and running, Claude can:
- Import meeting transcripts into your daily notes
- Extract commitments from meetings → Active Board
- File meeting notes to customer, deal, and people files automatically
- Prep for upcoming meetings using context from past meetings
- Build personality profiles from interaction patterns over time

## Setup

### 1. Install Granola

Download from [granola.ai](https://granola.ai/). It's already standard at Salesforce — you may already have it.

### 2. That's it

Seriously. Granola stores meeting data in a local cache file:
```
~/Library/Application Support/Granola/cache-v6.json
```

Claude reads this file directly. No API keys, no auth, no configuration.

## How It Works

1. **You take a meeting.** Granola runs in the background and captures the transcript + any notes you take.
2. **You talk to Claude.** Say "import meetings" or "what happened in my meeting with [name]?" Claude reads the Granola cache and finds the transcript.
3. **Claude processes it.** Transcripts get imported to your daily note. Commitments get extracted to your Active Board. Customer/deal/people intel gets filed to the right places.

## Granola at Salesforce

Salesforce has a shared Granola workspace. This means:
- Meeting metadata (title, attendees, time) syncs across all workspace members
- **Transcripts and notes do NOT sync** — only the person who recorded them has access
- Claude filters to only your meetings (by your email address)

## Tips

- **Let Granola run for every meeting.** Even if you don't take notes, the transcript alone is valuable. Claude extracts commitments and context you'd otherwise forget.
- **Don't worry about organizing.** Claude handles routing — customer intel to customer files, people notes to people files, commitments to your Active Board.
- **Ask Claude to prep you.** Before a meeting, say "prep me for my meeting with [name]." Claude searches past Granola transcripts for context.

## Troubleshooting

**"No meetings found"**
- Check that Granola is running (look for the icon in your menu bar)
- Verify the cache exists: `ls ~/Library/Application\ Support/Granola/cache-v6.json`
- If the cache doesn't exist, Granola may not have recorded any meetings yet

**Meetings from other people showing up**
- This is normal — Salesforce workspace syncs metadata across members
- Claude filters by your email address and only imports your meetings
- Other people's transcripts/notes are NOT accessible — only metadata (title, attendees, time)
