# Connecting Claude Code to Google Workspace

This guide walks you through setting up Google Workspace API access so Claude can read your Gmail, Calendar, Drive, Docs, Sheets, and Slides.

## What You Get

Once connected, Claude can:
- Scan your Gmail for actionable items (morning routine)
- Read your Google Calendar for meeting prep
- Access Google Drive files, Docs, Sheets, and Slides
- Never send emails or modify calendar events without asking first

## Prerequisites

- A Google Cloud project (free tier works)
- `gcloud` CLI installed ([install guide](https://cloud.google.com/sdk/docs/install))
- Your Google Workspace account

## Setup Steps

### 1. Create a Google Cloud project

Go to [console.cloud.google.com](https://console.cloud.google.com/) and create a new project (or use an existing one).

### 2. Enable the APIs

Enable these APIs in your project:

- Gmail API
- Google Calendar API
- Google Drive API
- Google Docs API
- Google Sheets API
- Google Slides API

You can do this via the API Library in the Cloud Console, or run:

```bash
gcloud services enable gmail.googleapis.com calendar-json.googleapis.com drive.googleapis.com docs.googleapis.com sheets.googleapis.com slides.googleapis.com
```

### 3. Configure OAuth consent screen

1. Go to **APIs & Services → OAuth consent screen**
2. Choose **Internal** (if using a Workspace account) or **External**
3. Fill in the app name (e.g., "AI Chief of Staff")
4. Add the scopes for Gmail, Calendar, Drive, Docs, Sheets, Slides
5. Add yourself as a test user (if External)

### 4. Create OAuth credentials

1. Go to **APIs & Services → Credentials**
2. Click **Create Credentials → OAuth client ID**
3. Choose **Desktop app**
4. Download the JSON file
5. Save it as `~/.config/gcloud/application_default_credentials.json`

Or use the gcloud CLI:

```bash
gcloud auth application-default login \
  --scopes="https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/calendar.readonly,https://www.googleapis.com/auth/drive.readonly,https://www.googleapis.com/auth/documents.readonly,https://www.googleapis.com/auth/spreadsheets.readonly,https://www.googleapis.com/auth/presentations.readonly"
```

### 5. Install Python dependencies

Claude uses Python scripts to access Google APIs. From your project folder:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install google-auth google-auth-oauthlib google-api-python-client
```

### 6. Verify it works

Ask Claude:

```
Check my email
```

If it reads your Gmail successfully, you're connected.

## What Claude Can Access

| Service | Read | Write | Notes |
|---------|------|-------|-------|
| Gmail | Yes | Ask first | Scans for actionable items, skips noise |
| Calendar | Yes | Ask first | Meeting prep, schedule awareness |
| Drive | Yes | Ask first | File search, document access |
| Docs | Yes | Ask first | Read and create documents |
| Sheets | Yes | Ask first | Read and create spreadsheets |
| Slides | Yes | Ask first | Read and create presentations |

## Troubleshooting

**"Google API not configured"**
- Make sure you ran `gcloud auth application-default login` with the correct scopes
- Check that the APIs are enabled in your Cloud project
- Verify credentials exist at `~/.config/gcloud/application_default_credentials.json`

**Permission denied**
- Re-run `gcloud auth application-default login` with the scopes listed above
- Make sure your Google Cloud project has the APIs enabled

**Wrong Python version**
- Use the project venv: `.venv/bin/python3`
- If on macOS, system Python (`/usr/bin/python3`) may work but venv is recommended

## Privacy Notes

- All Google data stays in your local project files
- Claude never sends emails or modifies events without explicit permission
- Read-only scopes are sufficient for most features — write scopes are optional
