# Connecting Claude Code to Slack

This guide walks you through setting up the Slack MCP (Model Context Protocol) integration so Claude can read your Slack channels, DMs, and Canvases.

## What You Get

Once connected, Claude can:
- Read messages from any channel you're in
- Search across channels and DMs
- Read and write Slack Canvases (used for your Active Board)
- Look up user profiles and channel info
- Monitor channels overnight and synthesize intel for your morning brief

## Setup Steps

### 1. Add the Slack MCP server to Claude Code

Run this in your terminal:

```bash
claude mcp add slack --transport http https://mcp.slack.com/mcp
```

### 2. Authenticate

The first time Claude tries to use a Slack tool, it will prompt you to authenticate via OAuth in your browser. Follow the prompts to authorize Claude Code to access your Slack workspace.

### 3. Verify it works

Open Claude Code in your project folder and ask:

```
Search Slack for my name
```

If it returns results, you're connected. Claude will automatically discover your channels and user ID during onboarding.

## What Claude Can Do with Slack

| Tool | What It Does |
|------|-------------|
| `slack_search_public` | Search public channel messages |
| `slack_search_public_and_private` | Search all channels you're in |
| `slack_read_channel` | Read recent messages from a channel |
| `slack_read_thread` | Read a full thread |
| `slack_read_user_profile` | Look up someone's profile |
| `slack_search_channels` | Find channels by name |
| `slack_search_users` | Find users by name |
| `slack_read_canvas` | Read a Slack Canvas |
| `slack_create_canvas` | Create a new Canvas |
| `slack_update_canvas` | Update an existing Canvas |
| `slack_send_message` | Send a message (Claude always asks first) |

## Troubleshooting

**"Slack MCP not available"**
- Make sure you ran the `claude mcp add` command above
- Restart Claude Code after adding the server
- Check `~/.claude.json` to verify the server entry exists

**Authentication expired**
- Re-run any Slack tool — it will re-prompt for OAuth

**Can't see private channels**
- You must be a member of the channel for Claude to read it
- Use `slack_search_public_and_private` instead of `slack_search_public`

## Privacy Notes

- Claude only reads channels you're already a member of
- Claude never sends messages without asking you first
- All Slack data stays in your local project — nothing is uploaded to external services
