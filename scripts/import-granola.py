#!/usr/bin/env python3
"""
Granola Import Script
Automatically import Granola meeting notes into your daily notes.

Usage:
    python3 scripts/import-granola.py                    # Import today's meetings
    python3 scripts/import-granola.py --date 2026-01-21  # Import specific date
    python3 scripts/import-granola.py --all              # Import all meetings from last 7 days
    python3 scripts/import-granola.py --no-api           # Skip Granola API fallback (local cache only)
"""

import json
import os
import re
import subprocess
import time
import concurrent.futures
from datetime import datetime, timedelta
from pathlib import Path
import argparse

# Paths
REPO_ROOT = Path(__file__).parent.parent
GRANOLA_CACHE_V6 = Path.home() / "Library/Application Support/Granola/cache-v6.json"
GRANOLA_CACHE_V4 = Path.home() / "Library/Application Support/Granola/cache-v4.json"
GRANOLA_CACHE_V3 = Path.home() / "Library/Application Support/Granola/cache-v3.json"
GRANOLA_CACHE = GRANOLA_CACHE_V6 if GRANOLA_CACHE_V6.exists() else (GRANOLA_CACHE_V4 if GRANOLA_CACHE_V4.exists() else GRANOLA_CACHE_V3)
GRANOLA_SUPABASE = Path.home() / "Library/Application Support/Granola/supabase.json"
DAILY_NOTES_DIR = REPO_ROOT / "daily"
CUSTOMERS_DIR = REPO_ROOT / "customers"
PEOPLE_DIRECTS_DIR = REPO_ROOT / "people" / "directs"
PEOPLE_STAKEHOLDERS_DIR = REPO_ROOT / "people" / "stakeholders"
PRODUCTS_DIR = REPO_ROOT / "products"
TRANSCRIPT_CACHE_PATH = REPO_ROOT / ".transcript_cache.json"
COMMITMENT_CACHE_PATH = REPO_ROOT / ".commitment_cache.json"

# API endpoints
GRANOLA_TRANSCRIPT_API = "https://api.granola.ai/v1/get-document-transcript"
GRANOLA_DOCUMENTS_API = "https://api.granola.ai/v1/get-documents"
GRANOLA_REFRESH_API = "https://api.granola.ai/v1/refresh-access-token"

# Source values that indicate the local user is speaking (the one who owns this vault).
# Add your local username if different — e.g. if your macOS username is 'alex', add 'alex'.
USER_SOURCES = {'me', 'you', 'self', 'user', 'host', 'microphone'}


def load_granola_auth_token():
    """Load and validate the Granola WorkOS auth token from supabase.json.

    Checks token expiry. If expired, attempts a refresh via the Granola API.
    Saves refreshed token back to supabase.json.

    Returns the access token string, or None if unavailable/expired-and-unrefreshable.
    """
    if not GRANOLA_SUPABASE.exists():
        print("🌐 Granola supabase.json not found — API fallback unavailable.")
        return None

    try:
        sb = json.loads(GRANOLA_SUPABASE.read_text())
        raw_tokens = sb.get('workos_tokens')
        if not raw_tokens:
            print("🌐 No workos_tokens in supabase.json — API fallback unavailable.")
            return None

        tokens = json.loads(raw_tokens) if isinstance(raw_tokens, str) else raw_tokens
        access_token = tokens.get('access_token')
        expires_in = tokens.get('expires_in', 0)      # seconds
        obtained_at = tokens.get('obtained_at', 0)     # epoch ms

        if not access_token:
            print("🌐 No access_token in workos_tokens — API fallback unavailable.")
            return None

        # Check expiry: obtained_at is in ms, expires_in is in seconds
        current_time_ms = int(time.time() * 1000)
        expiry_ms = obtained_at + (expires_in * 1000)

        if current_time_ms < expiry_ms:
            # Token is still valid
            return access_token

        # Token is expired — try to refresh
        refresh_token = tokens.get('refresh_token')
        if not refresh_token:
            print("🌐 Access token expired and no refresh_token available — API fallback unavailable.")
            return None

        print("🌐 Access token expired, attempting refresh...")
        try:
            result = subprocess.run(
                [
                    'curl', '-s', '--compressed', '-X', 'POST',
                    GRANOLA_REFRESH_API,
                    '-H', 'Content-Type: application/json',
                    '-d', json.dumps({'refresh_token': refresh_token}),
                    '--max-time', '15',
                ],
                capture_output=True,
                timeout=20,
            )
            if result.returncode != 0 or not result.stdout:
                print("🌐 Token refresh failed (empty response) — API fallback unavailable.")
                return None

            new_tokens = json.loads(result.stdout)
            new_access_token = new_tokens.get('access_token')
            if not new_access_token:
                print("🌐 Token refresh response missing access_token — API fallback unavailable.")
                return None

            # Persist refreshed tokens back to supabase.json
            new_tokens['obtained_at'] = int(time.time() * 1000)
            sb['workos_tokens'] = json.dumps(new_tokens)
            GRANOLA_SUPABASE.write_text(json.dumps(sb))
            print("🌐 Token refreshed and saved successfully.")
            return new_access_token

        except Exception as e:
            print(f"🌐 Token refresh error: {e} — API fallback unavailable.")
            return None

    except Exception as e:
        print(f"🌐 Failed to load Granola auth token: {e} — API fallback unavailable.")
        return None


def fetch_transcript_from_api(doc_id, access_token):
    """Fetch a single meeting transcript from the Granola API.

    Converts API segment format to the local cache format:
      API:   {document_id, start_timestamp, text, source, id, is_final, end_timestamp}
      Cache: {text, startTimestamp, endTimestamp, speaker, isUser}

    Returns a list of converted segments, or an empty list on any error.
    """
    try:
        result = subprocess.run(
            [
                'curl', '-s', '--compressed', '-X', 'POST',
                GRANOLA_TRANSCRIPT_API,
                '-H', f'Authorization: Bearer {access_token}',
                '-H', 'Content-Type: application/json',
                '-d', json.dumps({'document_id': doc_id}),
                '--max-time', '15',
            ],
            capture_output=True,
            timeout=20,
        )
        if result.returncode != 0 or not result.stdout:
            return []

        raw = json.loads(result.stdout)

        # API may return a dict with an error field
        if isinstance(raw, dict):
            if 'error' in raw or 'message' in raw:
                return []
            # Some responses may wrap segments in a key
            raw = raw.get('segments', raw.get('transcript', []))

        if not isinstance(raw, list):
            return []

        # Convert API format -> cache format
        segments = []
        for seg in raw:
            if not isinstance(seg, dict):
                continue
            text = seg.get('text', '').strip()
            if not text:
                continue
            source = str(seg.get('source', '')).lower()
            is_user = source in USER_SOURCES
            segments.append({
                'text': text,
                'startTimestamp': seg.get('start_timestamp', ''),
                'endTimestamp': seg.get('end_timestamp', ''),
                'speaker': seg.get('source', 'unknown'),
                'isUser': is_user,
            })

        return segments

    except Exception:
        return []


def fetch_documents_from_api(access_token):
    """Fetch all documents from the Granola API.

    The local cache (cache-v6.json) is often incomplete — meetings that exist
    in Granola's UI may be missing from the cache. This function fetches the
    full document list from the API to fill those gaps.

    Returns a dict of {doc_id: doc} or empty dict on error.
    """
    try:
        result = subprocess.run(
            [
                'curl', '-s', '--compressed', '-X', 'POST',
                GRANOLA_DOCUMENTS_API,
                '-H', f'Authorization: Bearer {access_token}',
                '-H', 'Content-Type: application/json',
                '-d', '{}',
                '--max-time', '30',
            ],
            capture_output=True,
            timeout=35,
        )
        if result.returncode != 0 or not result.stdout:
            return {}

        docs = json.loads(result.stdout)
        if not isinstance(docs, list):
            return {}

        return {d['id']: d for d in docs if isinstance(d, dict) and 'id' in d}

    except Exception as e:
        print(f"🌐 Failed to fetch documents from API: {e}")
        return {}


def merge_api_documents_into_state(state, api_docs, target_date):
    """Merge API-discovered documents into the local state for a target date.

    Only adds documents that:
    1. Are not already in the local state
    2. Fall on the target_date (via google_calendar_event or created_at)
    3. Have the vault owner as an attendee/organizer

    The vault owner email is read from the AICOS_USER_EMAIL env var. If unset,
    this filter is disabled and all calendar-matched docs for the date are merged.

    Returns count of documents added.
    """
    user_email = os.environ.get('AICOS_USER_EMAIL', '').strip().lower()
    documents = state.setdefault('documents', {})
    added = 0

    for doc_id, doc in api_docs.items():
        if doc_id in documents:
            continue

        event = doc.get('google_calendar_event') or {}
        start_info = event.get('start') or {}
        event_start = start_info.get('dateTime', '') or doc.get('created_at', '')
        if not event_start:
            continue

        try:
            dt = datetime.fromisoformat(event_start.replace('Z', '+00:00'))
            if dt.date() != target_date:
                continue
        except Exception:
            continue

        # Only filter by user presence on the invite if AICOS_USER_EMAIL is set.
        # This lets the script work out of the box before the user configures their email.
        if user_email and event:
            attendees = event.get('attendees') or []
            organizer_email = (event.get('organizer') or {}).get('email', '').lower()
            user_on_invite = (
                user_email in organizer_email or
                any(user_email in (a.get('email', '') or '').lower() for a in attendees)
            )
            if not user_on_invite:
                continue

        documents[doc_id] = doc
        added += 1

    return added


def fetch_missing_transcripts_from_api(state, target_date, transcripts, access_token, transcript_cache):
    """Fetch transcripts for all meetings on target_date that have no local content.

    Checks transcript_cache first to avoid redundant API calls.
    Uses a thread pool (max 5 workers) for parallel fetching.

    Returns dict of {doc_id: [segments]} for newly fetched transcripts.
    """
    documents = state.get('documents', {})
    to_fetch = []

    for doc_id, doc in documents.items():
        # Only consider docs for target_date
        event = doc.get('google_calendar_event') or {}
        start_info = event.get('start') or {}
        event_start = start_info.get('dateTime', '') or doc.get('created_at', '')
        if not event_start:
            continue
        try:
            dt = datetime.fromisoformat(event_start.replace('Z', '+00:00'))
            if dt.date() != target_date:
                continue
        except Exception:
            continue

        # Skip if local cache already has a transcript
        has_local = (
            transcripts and
            doc_id in transcripts and
            isinstance(transcripts[doc_id], list) and
            len(transcripts[doc_id]) > 0
        )
        if has_local:
            continue

        # Skip if already in transcript_cache
        if doc_id in transcript_cache:
            continue

        to_fetch.append(doc_id)

    if not to_fetch:
        return {}

    print(f"🌐 Fetching {len(to_fetch)} transcript(s) from Granola API...")

    results = {}

    def fetch_one(doc_id):
        segs = fetch_transcript_from_api(doc_id, access_token)
        return doc_id, segs

    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = {executor.submit(fetch_one, doc_id): doc_id for doc_id in to_fetch}
        for future in concurrent.futures.as_completed(futures):
            try:
                doc_id, segs = future.result()
                if segs:
                    results[doc_id] = segs
                    print(f"🌐   {doc_id[:8]}... — {len(segs)} segments fetched")
                else:
                    print(f"🌐   {doc_id[:8]}... — no transcript available")
            except Exception as e:
                doc_id = futures[future]
                print(f"🌐   {doc_id[:8]}... — error: {e}")

    return results


def _resolve_transcript(meeting_id, transcripts, api_transcripts):
    """Return the best available transcript segment list for a meeting.

    Prefers local cache; falls back to API-fetched transcripts.
    Always returns a list (possibly empty).
    """
    if transcripts and meeting_id in transcripts:
        local = transcripts[meeting_id]
        if isinstance(local, list) and len(local) > 0:
            return local

    if api_transcripts and meeting_id in api_transcripts:
        api = api_transcripts[meeting_id]
        if isinstance(api, list) and len(api) > 0:
            return api

    return []


def load_granola_data():
    """Load Granola's local cache"""
    if not GRANOLA_CACHE.exists():
        print(f"❌ Granola cache not found at: {GRANOLA_CACHE}")
        print("Make sure Granola is installed and has been run at least once.")
        return None, None, None

    with open(GRANOLA_CACHE, 'r') as f:
        data = json.load(f)

    raw_cache = data['cache']
    cache = json.loads(raw_cache) if isinstance(raw_cache, str) else raw_cache
    state = cache['state']

    # Return documents state, document panels, and transcripts
    return state, state.get('documentPanels', {}), state.get('transcripts', {})

def extract_text_from_tiptap(node, depth=0):
    """Recursively extract text from TipTap JSON structure"""
    if not isinstance(node, dict):
        return ''

    node_type = node.get('type')

    # Base case: text node
    if node_type == 'text':
        return node.get('text', '')

    # Process content array
    if 'content' not in node:
        return ''

    text_parts = []

    # Handle different node types
    if node_type == 'doc':
        # Root document node
        for child in node['content']:
            text_parts.append(extract_text_from_tiptap(child, depth))

    elif node_type == 'heading':
        level = node.get('attrs', {}).get('level', 1)
        prefix = '#' * level
        heading_text = ''.join(extract_text_from_tiptap(child, depth) for child in node['content'])
        return f'{prefix} {heading_text}\n\n'

    elif node_type == 'paragraph':
        para_text = ''.join(extract_text_from_tiptap(child, depth) for child in node['content'])
        if para_text.strip():
            return f'{para_text}\n'
        return ''

    elif node_type == 'bulletList':
        # Process list items
        for child in node['content']:
            text_parts.append(extract_text_from_tiptap(child, depth))
        return ''.join(text_parts)

    elif node_type == 'listItem':
        # Extract text from paragraphs in list item
        indent = '  ' * depth
        item_parts = []

        for child in node['content']:
            if child.get('type') == 'paragraph':
                para_text = ''.join(extract_text_from_tiptap(c, depth) for c in child.get('content', []))
                if para_text.strip():
                    item_parts.append(f'{indent}- {para_text}')
            elif child.get('type') == 'bulletList':
                # Nested list
                nested = extract_text_from_tiptap(child, depth + 1)
                item_parts.append(nested)

        return '\n'.join(item_parts) + '\n'

    else:
        # Default: just process children
        for child in node['content']:
            text_parts.append(extract_text_from_tiptap(child, depth))

    return ''.join(text_parts)

def format_transcript(transcript_segments):
    """Format transcript segments into readable text.

    Handles both local cache format (source field with 'microphone'/'system')
    and API-converted format (isUser boolean + speaker field).
    """
    if not transcript_segments:
        return None

    lines = []
    for segment in transcript_segments:
        text = segment.get('text', '').strip()
        if text:
            # Get timestamp — support both field name conventions
            start_ts = segment.get('startTimestamp', '') or segment.get('start_timestamp', '')
            if start_ts:
                try:
                    dt = datetime.fromisoformat(start_ts.replace('Z', '+00:00'))
                    timestamp = dt.strftime('%H:%M:%S')
                except Exception:
                    timestamp = ''
            else:
                timestamp = ''

            # Determine speaker label
            # API-converted segments have isUser boolean
            if 'isUser' in segment:
                speaker = 'You' if segment['isUser'] else 'Other'
            else:
                # Local cache format: source == 'microphone' means the user
                source = segment.get('source', 'unknown')
                speaker = 'You' if source == 'microphone' else 'Other'

            if timestamp:
                lines.append(f'[{timestamp}] {speaker}: {text}')
            else:
                lines.append(f'{speaker}: {text}')

    return '\n'.join(lines)

def extract_meeting_commitments(doc, panels, transcripts, api_transcripts=None):
    """Extract commitments and waiting-on items from a single meeting's content.

    Only extracts from structured content (notes_markdown, panels) — NOT raw transcripts.
    Raw transcript text is too noisy for reliable commitment extraction.

    Returns (commitments, waiting_on) where each is a list of extracted lines.
    """
    meeting_id = doc.get('id')
    commitments = []
    waiting_on = []

    # Only use structured content — skip transcript-only meetings
    has_structured = bool(doc.get('notes_markdown')) or bool(panels and panels.get(meeting_id))
    if not has_structured:
        return commitments, waiting_on

    # Collect all text from this meeting
    text_blocks = []
    notes = doc.get('notes_markdown', '')
    if notes:
        text_blocks.append(notes)

    meeting_panels = panels.get(meeting_id, {}) if panels and meeting_id else {}
    for panel_id, panel in meeting_panels.items():
        panel_data = panel.get('content', {})
        if panel_data:
            text = extract_text_from_tiptap(panel_data)
            if text.strip():
                text_blocks.append(text)

    # NOTE: Transcripts are intentionally excluded — raw transcript text is too noisy
    # for reliable commitment extraction (picks up "Them: I need to go", casual chat, etc.)
    # Only structured notes and panels are scanned.

    full_text = '\n'.join(text_blocks)

    # Scan for commitments — structured notes only
    for line in full_text.split('\n'):
        line_stripped = line.strip()
        if not line_stripped or len(line_stripped) < 10:
            continue
        # Skip lines that look like transcript speaker prefixes
        if re.match(r'^(Them:|Other:|\[Other\]|\[Them\])', line_stripped):
            continue
        for pattern in COMMITMENT_PATTERNS:
            if re.search(pattern, line_stripped, re.IGNORECASE):
                commitments.append(line_stripped[:150])
                break

    # Scan for waiting-on — structured notes only
    for line in full_text.split('\n'):
        line_stripped = line.strip()
        if not line_stripped or len(line_stripped) < 10:
            continue
        if re.match(r'^(Them:|Other:|\[Other\]|\[Them\])', line_stripped):
            continue
        for pattern in WAITING_ON_PATTERNS:
            if re.search(pattern, line_stripped, re.IGNORECASE):
                waiting_on.append(line_stripped[:150])
                break

    return commitments, waiting_on


def _slugify(text, max_len=40):
    """Lowercase, keep alnum + dashes. Used for transcript sidecar filenames."""
    import re
    text = text.lower().strip()
    text = re.sub(r'[^a-z0-9]+', '-', text).strip('-')
    return text[:max_len] or 'meeting'


def _write_transcript_sidecar(target_date, meeting_time, title, full_transcript,
                                segment_count, source_label):
    """Write transcript to daily/transcripts/YYYY-MM-DD/HH-MM-slug.md and return
    a relative path for the daily note to link to. Skips if transcript is empty.
    Returns None if nothing was written.
    """
    if not full_transcript or not full_transcript.strip():
        return None

    # Normalize meeting_time (e.g. "09:30 AM") -> filename-safe "09-30-am"
    import re
    time_slug = re.sub(r'[^a-zA-Z0-9]+', '-', meeting_time).strip('-').lower() or 'notime'
    title_slug = _slugify(title)
    filename = f"{time_slug}-{title_slug}.md"

    date_dir = DAILY_NOTES_DIR / 'transcripts' / target_date.isoformat()
    date_dir.mkdir(parents=True, exist_ok=True)
    out_path = date_dir / filename

    header = (
        f"# Transcript — {title}\n"
        f"**Date:** {target_date.isoformat()}  |  "
        f"**Time:** {meeting_time}  |  "
        f"**Segments:** {segment_count}{source_label}\n\n"
        f"*Auto-written by import-granola.py — source of truth lives in Granola.*\n\n---\n\n"
    )
    out_path.write_text(header + full_transcript)

    # Return wiki-style link for the daily note to use
    return f"daily/transcripts/{target_date.isoformat()}/{filename}"


def format_meeting_for_daily_note(doc, panels, transcripts, has_content=True,
                                    api_transcripts=None, target_date=None):
    """Format a Granola document for insertion into daily note.

    If has_content=False, renders a skeleton entry (title + time only, no notes section)
    so the meeting at least appears in the daily note even when no notes were taken.

    api_transcripts: optional dict of {doc_id: [segments]} from the Granola API fallback.
    target_date: date the meeting occurred on — required to write transcript sidecar files.
        If None, falls back to inline transcript (legacy behavior).
    """
    title = doc.get('title', 'Untitled Meeting')
    notes_md = doc.get('notes_markdown', '')
    summary = doc.get('summary', '')

    # Get event details
    event = doc.get('google_calendar_event') or {}
    start_info = event.get('start') or {}
    event_start = start_info.get('dateTime', '')
    attendees = event.get('attendees') or []

    # Parse time
    if event_start:
        try:
            dt = datetime.fromisoformat(event_start.replace('Z', '+00:00'))
            meeting_time = dt.strftime('%I:%M %p')
        except Exception:
            meeting_time = 'TIME'
    else:
        meeting_time = 'TIME'

    # Format attendees
    attendee_emails = [a.get('email', '') for a in attendees if a.get('email')]
    attendee_names = [email.split('@')[0] for email in attendee_emails[:5]]
    attendees_str = ', '.join(attendee_names) if attendee_names else 'Not recorded'

    # Build the note section
    output = f"""
### {meeting_time} - {title}
**From Granola** | **Attendees:** {attendees_str}

"""

    # Fix #3: Skeleton mode — calendar event with no notes taken
    # Return a minimal placeholder so the meeting appears in the daily note timeline.
    if not has_content:
        output += "*No notes taken in Granola for this meeting.*\n\n---\n\n"
        return output, dt if event_start else None

    # Get panels for this meeting
    meeting_id = doc.get('id')
    meeting_panels = panels.get(meeting_id, {}) if panels and meeting_id else {}

    # Extract panel content
    panel_content = {}
    for panel_id, panel in meeting_panels.items():
        panel_title = panel.get('title', 'Unknown')
        panel_data = panel.get('content', {})
        if panel_data:
            text = extract_text_from_tiptap(panel_data)
            if text.strip():
                panel_content[panel_title] = text.strip()

    # Get full transcript — prefer local cache, fall back to API-fetched
    transcript_data = _resolve_transcript(meeting_id, transcripts, api_transcripts)
    full_transcript = format_transcript(transcript_data) if transcript_data else None

    # Show Summary panel if it exists
    if 'Summary' in panel_content:
        output += f"""**AI Summary:**
{panel_content['Summary']}

"""

    # Show your own notes if they exist
    if notes_md and notes_md.strip():
        output += f"""**My Notes:**
{notes_md}

"""

    # Show other panels (Action Items, Key Decisions, etc.)
    for panel_title, content in panel_content.items():
        if panel_title not in ['Summary']:  # Already shown above
            output += f"""**{panel_title}:**
{content}

"""

    # Transcript handling: write to sidecar file, link from daily note.
    # This keeps the daily note short and scannable (~150 lines instead of 2000+).
    if full_transcript:
        segment_count = len(transcript_data)
        source_label = ""
        local_segs = transcripts.get(meeting_id, []) if transcripts else []
        if api_transcripts and meeting_id in api_transcripts and not (
            isinstance(local_segs, list) and len(local_segs) > 0
        ):
            source_label = " — via Granola API"

        sidecar_path = None
        if target_date is not None:
            sidecar_path = _write_transcript_sidecar(
                target_date, meeting_time, title, full_transcript,
                segment_count, source_label
            )

        if sidecar_path:
            output += f"📝 **Full transcript:** [[{sidecar_path}]] ({segment_count} segments{source_label})\n\n"
        else:
            # Fallback: legacy inline collapsible (only when target_date not provided)
            output += f"""<details>
<summary>📝 Full Transcript ({segment_count} segments{source_label}) - Click to expand</summary>

{full_transcript}

</details>

"""

    # Auto-extract commitments and waiting-on from this meeting's content
    meeting_commitments, meeting_waiting = extract_meeting_commitments(
        doc, panels, transcripts, api_transcripts=api_transcripts
    )

    # Replace static [WHO] placeholders with actual extracted items
    if meeting_commitments or meeting_waiting:
        output += "**⭐ My Commitments (auto-detected):**\n"
        if meeting_commitments:
            for item in meeting_commitments[:5]:
                output += f"- [ ] {item}\n"
        else:
            output += "*None detected*\n"

        output += "\n**⏳ Waiting On (auto-detected):**\n"
        if meeting_waiting:
            for item in meeting_waiting[:5]:
                output += f"- {item}\n"
        else:
            output += "*None detected*\n"
    else:
        output += "*No commitments or waiting-on items detected — review transcript if needed*\n"

    output += "\n---\n\n"

    return output, dt if event_start else None

def get_meetings_for_date(state, target_date, panels=None, transcripts=None, include_empty=False, api_transcripts=None):
    """Get all meetings for a specific date.

    include_empty=True also returns calendar-linked docs that have no notes/transcript,
    so they appear as skeleton entries in the daily note.

    api_transcripts: optional dict of {doc_id: [segments]} from the Granola API fallback.
    """
    documents = state.get('documents', {})
    meetings = []

    for doc_id, doc in documents.items():
        # Check if meeting has any content (notes, summary, panels, OR transcript segments)
        has_notes = bool(doc.get('notes_markdown'))
        has_summary = bool(doc.get('summary'))
        has_panels = panels and doc_id in panels and len(panels.get(doc_id, {})) > 0
        has_transcript = (
            (
                transcripts and
                doc_id in transcripts and
                isinstance(transcripts[doc_id], list) and
                len(transcripts[doc_id]) > 0
            ) or
            (
                api_transcripts and
                doc_id in api_transcripts and
                len(api_transcripts[doc_id]) > 0
            )
        )
        has_content = has_notes or has_summary or has_panels or has_transcript

        # Fix #3: Without --include-empty, only include meetings that have content.
        # With --include-empty, also include calendar-linked shells (no notes taken)
        # so the meeting title/time still appears in the daily note as a placeholder.
        # We never include docs that have neither content NOR a calendar event — those
        # are truly orphaned records with no useful information.
        if not has_content:
            if not include_empty:
                continue
            # Only include calendar-linked shells (must have a cal event to know the date/time)
            event = doc.get('google_calendar_event') or {}
            start_info = event.get('start') or {}
            if not start_info.get('dateTime', ''):
                continue  # No calendar link and no content — skip entirely

        # Get event date
        event = doc.get('google_calendar_event') or {}

        # Filter: only import meetings where the vault owner is an attendee
        # or organizer. Granola workspaces sync metadata for all workspace
        # members — without this filter, other people's meetings leak in.
        # Set AICOS_USER_EMAIL to enable; if unset, the filter is disabled.
        user_email = os.environ.get('AICOS_USER_EMAIL', '').strip().lower()
        if user_email and event:
            attendees = event.get('attendees') or []
            organizer_email = (event.get('organizer') or {}).get('email', '').lower()
            user_on_invite = (
                user_email in organizer_email or
                any(user_email in (a.get('email', '') or '').lower() for a in attendees)
            )
            if not user_on_invite:
                continue

        start_info = event.get('start') or {}
        event_start = start_info.get('dateTime', '')

        if not event_start:
            # Try created_at
            event_start = doc.get('created_at', '')

        if event_start:
            try:
                dt = datetime.fromisoformat(event_start.replace('Z', '+00:00'))
                event_date = dt.date()

                if event_date == target_date:
                    meetings.append((dt, doc, has_content))
            except Exception:
                continue

    # Sort by time; for meetings with same time, content-bearing ones first
    meetings.sort(key=lambda x: (x[0], not x[2]))
    return meetings

def import_to_daily_note(target_date, meetings, panels, transcripts, force=False, api_transcripts=None):
    """Import meetings into daily note"""
    daily_note_path = DAILY_NOTES_DIR / f"{target_date.isoformat()}.md"

    if not daily_note_path.exists():
        print(f"⚠️  Daily note doesn't exist: {daily_note_path}")
        print(f"Creating from template...")
        # Could create from template here, but for now just skip
        return False

    # Read existing content
    with open(daily_note_path, 'r') as f:
        content = f.read()

    # Check if Granola section already exists
    if '## 🎙️ Meetings from Granola' in content:
        # Auto-overwrite if --force or non-interactive (e.g. called from morning routine)
        import sys
        is_interactive = sys.stdin.isatty()
        if force or not is_interactive:
            print(f"   ↻  Refreshing existing Granola section for {target_date}")
        else:
            print(f"⚠️  Granola meetings already imported to {target_date}")
            response = input("Overwrite? (y/n): ")
            if response.lower() != 'y':
                return False

        # Remove old Granola section
        parts = content.split('## 🎙️ Meetings from Granola')
        if len(parts) > 1:
            # Find the next ## section
            remaining = parts[1]
            next_section = remaining.find('\n##')
            if next_section != -1:
                content = parts[0] + remaining[next_section:]
            else:
                content = parts[0]

    # Defensive cleanup: strip any ORPHAN meeting blocks that aren't inside a
    # `## 🎙️ Meetings from Granola` umbrella. An orphan is a top-level H3 block
    # matching a Granola meeting pattern ("### HH:MM [AP]M - TITLE" immediately
    # followed by "**From Granola**") appearing outside a Granola section.
    # This can happen when Phase 2 AI writes meeting-looking headings in the
    # daily-note body, or when an older import's umbrella was stripped manually.
    import re
    orphan_pattern = re.compile(
        r'\n### \d{1,2}:\d{2}\s*(?:AM|PM)?\s*-[^\n]+\n\*\*From Granola\*\*[^\n]*\n'
        r'(?:.*?\n)*?(?=\n### \d{1,2}:\d{2}|\n## |\Z)',
        re.DOTALL
    )
    # Split into pre-meetings-section and meetings-section so we only strip orphans
    # BEFORE the umbrella. Anything inside the umbrella is legitimate.
    if '## 🎙️ Meetings from Granola' in content:
        before, _, after = content.partition('## 🎙️ Meetings from Granola')
        before = orphan_pattern.sub('\n', before)
        content = before + '## 🎙️ Meetings from Granola' + after
    else:
        content = orphan_pattern.sub('\n', content)

    # Build Granola section
    granola_section = "\n## 🎙️ Meetings from Granola\n"
    granola_section += f"*Auto-imported {datetime.now().strftime('%Y-%m-%d %I:%M %p')}*\n"

    for entry in meetings:
        dt, meeting = entry[0], entry[1]
        has_content = entry[2] if len(entry) > 2 else True
        note_section, _ = format_meeting_for_daily_note(
            meeting, panels, transcripts,
            has_content=has_content,
            api_transcripts=api_transcripts,
            target_date=target_date,
        )
        granola_section += note_section

    # Insert before "## ✅ End of Day Processing" if it exists
    if '## ✅ End of Day Processing' in content:
        parts = content.split('## ✅ End of Day Processing')
        content = parts[0] + granola_section + '\n## ✅ End of Day Processing' + parts[1]
    else:
        # Just append
        content += '\n' + granola_section

    # Write back
    with open(daily_note_path, 'w') as f:
        f.write(content)

    return True

def get_existing_entities():
    """Build sets of known entity names from existing files"""
    entities = {
        'customers': set(),
        'directs': set(),
        'stakeholders': set(),
        'products': set(),
    }

    for d, key in [(CUSTOMERS_DIR, 'customers'), (PEOPLE_DIRECTS_DIR, 'directs'),
                   (PEOPLE_STAKEHOLDERS_DIR, 'stakeholders'), (PRODUCTS_DIR, 'products')]:
        if d.exists():
            for f in d.glob('*.md'):
                entities[key].add(f.stem.lower())

    return entities


# Known company names -> customer file slugs.
# Add your own accounts here — this maps common names that appear in meetings
# to the file slugs you use in customers/. Examples commented out below.
#
# Format: 'common name': 'file-slug'  (value = None means mention but no file yet)
COMPANY_ALIASES = {
    # 'acme': 'acme', 'acme corp': 'acme',
    # 'globex': 'globex', 'globex industries': 'globex',
    # 'initech': 'initech',
}

# Product names to detect in meeting transcripts. Add your product and
# competitor terms. The importer counts mentions and surfaces them in the
# daily-note Entity Gaps section (if any are detected but missing a customer file).
PRODUCT_NAMES = [
    # 'your-product-1',
    # 'your-product-2',
    # 'competitor-a',
]

# Commitment language patterns
COMMITMENT_PATTERNS = [
    r"\bI'll\b", r"\bI will\b", r"\bI need to\b", r"\bI committed\b",
    r"\bI'm going to\b", r"\bI promised\b", r"\baction item\b",
    r"\bfollow up\b", r"\bfollow-up\b", r"\bI owe\b",
]

# Waiting-on language patterns
WAITING_ON_PATTERNS = [
    r"\bthey will\b", r"\bhe will\b", r"\bshe will\b",
    r"\bwaiting for\b", r"\bwaiting on\b", r"\bexpecting from\b",
    r"\bthey committed\b", r"\bthey'll\b", r"\bthey promised\b",
    r"\bowes us\b", r"\bowe us\b",
]


DASHBOARD_PATH = REPO_ROOT / "00-DASHBOARD.md"


def load_gemini_key():
    """Load Gemini API key from .env file or environment."""
    env_file = REPO_ROOT / '.env'
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith('GEMINI_API_KEY='):
                return line.split('=', 1)[1].strip()
    return os.environ.get('GEMINI_API_KEY', '')


def call_gemini(prompt_text, api_key, model='gemini-2.0-flash'):
    """Call Gemini API using urllib (no external packages needed)."""
    import urllib.request
    import urllib.error
    url = f'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}'
    payload = json.dumps({
        'contents': [{'parts': [{'text': prompt_text}], 'role': 'user'}],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 500}
    }).encode('utf-8')
    req = urllib.request.Request(
        url, data=payload,
        headers={'Content-Type': 'application/json'}
    )
    with urllib.request.urlopen(req, timeout=25) as resp:
        data = json.loads(resp.read().decode('utf-8'))
    text = data['candidates'][0]['content']['parts'][0]['text'].strip()
    text = re.sub(r'^```(?:json)?\n?', '', text)
    text = re.sub(r'\n?```$', '', text)
    return json.loads(text)
def extract_commitments_with_ai(meeting_title, transcript_segments, gemini_api_key):
    """Use Gemini to extract things Chris specifically committed to do from a transcript.

    Formats segments as "Me: {text}" or "Them: {text}", takes first 400 segments,
    skips segments shorter than 5 chars.

    Returns a list of strings (0-5 items). Returns [] on any error.
    """
    try:
        lines = []
        count = 0
        for seg in transcript_segments:
            if count >= 400:
                break
            text = seg.get('text', '').strip()
            if len(text) < 5:
                continue
            # Determine speaker
            if 'isUser' in seg:
                speaker = 'Me' if seg['isUser'] else 'Them'
            else:
                source = seg.get('source', 'unknown')
                speaker = 'Me' if source == 'microphone' else 'Them'
            lines.append(f'{speaker}: {text}')
            count += 1

        if not lines:
            return []

        transcript_text = '\n'.join(lines)

        prompt = f"""You are analyzing a meeting transcript for the vault owner.

Your job: extract ONLY things the vault owner ("Me") specifically committed or agreed to do.

Rules:
- Only extract from "Me:" lines (the vault owner speaking)
- Format each as a short, specific action starting with a verb ("Follow up with X on renewal", "Send seat count to Y", "Review the draft and respond")
- Be specific — include WHO and WHAT where clear from context
- Skip: small talk, pleasantries, vague statements like "I'll think about it", casual "I'll check" with no context
- Skip anything a "Them" speaker committed to
- Return 0-5 items max — only genuine, specific commitments
- Respond ONLY with a JSON array of strings, e.g.: ["Follow up with X on Y", "Send Y to Z by Friday"]
- If no real commitments, return: []

Meeting: {meeting_title}

Transcript:
{transcript_text}"""

        result = call_gemini(prompt, gemini_api_key)
        if isinstance(result, list):
            return [str(item) for item in result if item and str(item).strip()]
        return []

    except Exception:
        return []


def extract_waiting_on_with_ai(meeting_title, transcript_segments, gemini_api_key):
    """Use Gemini to extract things OTHER people committed to deliver to Chris.

    Same transcript formatting as extract_commitments_with_ai.

    Returns a list of strings (0-3 items). Returns [] on any error.
    """
    try:
        lines = []
        count = 0
        for seg in transcript_segments:
            if count >= 400:
                break
            text = seg.get('text', '').strip()
            if len(text) < 5:
                continue
            if 'isUser' in seg:
                speaker = 'Me' if seg['isUser'] else 'Them'
            else:
                source = seg.get('source', 'unknown')
                speaker = 'Me' if source == 'microphone' else 'Them'
            lines.append(f'{speaker}: {text}')
            count += 1

        if not lines:
            return []

        transcript_text = '\n'.join(lines)

        prompt = f"""You are analyzing a meeting transcript for the vault owner.

Your job: extract ONLY things OTHER people ("Them") specifically committed or agreed to deliver to the vault owner.

Rules:
- Only extract from "Them:" lines (other speakers)
- Format each as a specific deliverable: "Person/role committed to X" or just "X from [context]" — be specific
- Skip vague statements, pleasantries, or things with no clear deliverable
- Return 0-3 items max — only genuine, specific commitments from others
- Respond ONLY with a JSON array of strings, e.g.: ["Person to send pilot results by EOW", "Legal team reviewing NDA"]
- If no real commitments from others, return: []

Meeting: {meeting_title}

Transcript:
{transcript_text}"""

        result = call_gemini(prompt, gemini_api_key)
        if isinstance(result, list):
            return [str(item) for item in result if item and str(item).strip()]
        return []

    except Exception:
        return []



def extract_and_write_commitments(meetings, panels, transcripts, target_date, api_transcripts=None):
    """Extract commitments from all meetings using AI and write to Dashboard.

    Uses Gemini to extract genuine commitments from meeting transcripts.
    Skips meetings already processed (keyed by doc_id in commitment cache).
    Only processes meetings from the last 3 days.
    """
    gemini_key = load_gemini_key()
    if not gemini_key:
        print("  \u26a0\ufe0f  No Gemini API key \u2014 skipping AI commitment extraction")
        return

    # Load commitment cache
    commitment_cache = {}
    if COMMITMENT_CACHE_PATH.exists():
        try:
            commitment_cache = json.loads(COMMITMENT_CACHE_PATH.read_text())
        except Exception:
            commitment_cache = {}

    # Only process meetings from last 3 days
    cutoff = target_date - timedelta(days=3)

    all_commitments = []  # (meeting_title, commitment_text)
    all_waiting = []      # (meeting_title, waiting_text)
    meetings_with_transcripts = 0

    for entry in meetings:
        dt, meeting = entry[0], entry[1]
        doc_id = meeting.get('id', '')
        title = meeting.get('title', 'Untitled')

        # Skip if meeting is too old
        if dt.date() < cutoff:
            continue

        # Skip if already extracted
        if doc_id and doc_id in commitment_cache:
            continue

        segments = _resolve_transcript(doc_id, transcripts, api_transcripts)
        if not segments:
            # Mark as processed even with no transcript so we don't retry
            if doc_id:
                commitment_cache[doc_id] = {
                    'processed_at': target_date.isoformat(),
                    'commits': [],
                    'waiting': [],
                }
            continue

        meetings_with_transcripts += 1

        commits = extract_commitments_with_ai(title, segments, gemini_key)
        waits = extract_waiting_on_with_ai(title, segments, gemini_key)

        for c in commits:
            all_commitments.append((title, c))
        for w in waits:
            all_waiting.append((title, w))

        # Cache result
        if doc_id:
            commitment_cache[doc_id] = {
                'processed_at': target_date.isoformat(),
                'commits': commits,
                'waiting': waits,
            }

    print(f"  \U0001f916 AI extracting commitments from {meetings_with_transcripts} meetings...")
    print(f"  \U0001f916 Found {len(all_commitments)} commitments, {len(all_waiting)} waiting-on items")

    # Persist updated commitment cache
    try:
        COMMITMENT_CACHE_PATH.write_text(json.dumps(commitment_cache, indent=2))
    except Exception as e:
        print(f"  \u26a0\ufe0f  Could not save commitment cache: {e}")

    if not all_commitments and not all_waiting:
        print("  No commitments or waiting-on items to write to Dashboard.")
        return

    if not DASHBOARD_PATH.exists():
        print("  \u26a0\ufe0f  Dashboard not found, skipping commitment write.")
        return

    dashboard = DASHBOARD_PATH.read_text()
    date_str = target_date.isoformat()
    date_label = target_date.strftime('%b %-d')
    modified = False

    # Remove any previous auto-extracted block for this date (idempotent re-runs)
    auto_section_marker = f"### From Today's Meetings ({date_label}) \u2014 AI Extracted"
    if auto_section_marker in dashboard:
        parts = dashboard.split(auto_section_marker)
        after = parts[1]
        next_header = re.search(r'\n###? ', after)
        if next_header:
            dashboard = parts[0] + after[next_header.start():]
        else:
            dashboard = parts[0]

    # Build the new AI-extracted block for commitments
    if all_commitments:
        new_block = f"\n### From Today's Meetings ({date_label}) \u2014 AI Extracted\n"
        for mtitle, line in all_commitments[:15]:
            new_block += f"- [ ] **{line}** \u2014 Source: {mtitle[:40]} [[daily/{date_str}.md]]\n"

        # Find insertion point before "### This Quarter" marker
        insert_marker = "### This Quarter"
        if insert_marker not in dashboard:
            insert_marker = "### This Year"
        if insert_marker not in dashboard:
            insert_marker = "---\n\n## \u23f3 Waiting On"

        if insert_marker in dashboard:
            dashboard = dashboard.replace(insert_marker, new_block + "\n" + insert_marker, 1)
            modified = True
            print(f"  \u2705 Added {len(all_commitments[:15])} commitments to Dashboard")

    # Write waiting-on items to the Waiting On table
    if all_waiting:
        table_end_markers = [
            "\n*Mike Hecker:",
            "\n\n---\n\n## \U0001f465",
        ]
        insert_pos = None
        for end_marker in table_end_markers:
            pos = dashboard.find(end_marker)
            if pos != -1:
                insert_pos = pos
                break

        if insert_pos is None:
            waiting_section_start = dashboard.find("## \u23f3 Waiting On")
            if waiting_section_start != -1:
                next_section = dashboard.find("\n---", waiting_section_start + 20)
                if next_section != -1:
                    insert_pos = next_section

        if insert_pos is not None:
            new_rows = ""
            for mtitle, line in all_waiting[:10]:
                short_title = mtitle[:25].strip()
                since = target_date.strftime('%b %-d')
                new_rows += f"| **{short_title}** | {line[:80]} | {since} | AI-EXTRACTED |\n"

            dashboard = dashboard[:insert_pos] + new_rows + dashboard[insert_pos:]
            modified = True
            print(f"  \u2705 Added {len(all_waiting[:10])} waiting-on items to Dashboard")

    if modified:
        DASHBOARD_PATH.write_text(dashboard)


def generate_import_report(meetings, panels, transcripts, target_date=None, api_transcripts=None):
    """Generate a post-import intelligence report analyzing imported meetings.

    Scans meeting content for:
    - Entities (companies, products) and whether they have files
    - Commitment language (things Chris said he'd do)
    - Waiting-on language (things others committed to)
    - External attendees and customer file status
    - Suggested file updates based on mention frequency

    Writes report to daily note AND prints to stdout.
    """
    existing = get_existing_entities()

    # Collectors
    company_mentions = {}   # slug -> count
    product_mentions = {}   # name -> count
    commitments = []        # (meeting_title, line)
    waiting_on = []         # (meeting_title, line)
    external_attendees = {} # company -> [emails]
    companies_without_files = set()

    for entry in meetings:
        dt, meeting = entry[0], entry[1]
        title = meeting.get('title', 'Untitled')
        meeting_id = meeting.get('id')

        # Collect all text from this meeting
        text_blocks = []

        # User notes
        notes = meeting.get('notes_markdown', '')
        if notes:
            text_blocks.append(notes)

        # Panel content
        meeting_panels = panels.get(meeting_id, {}) if panels and meeting_id else {}
        for panel_id, panel in meeting_panels.items():
            panel_data = panel.get('content', {})
            if panel_data:
                text = extract_text_from_tiptap(panel_data)
                if text.strip():
                    text_blocks.append(text)

        # Transcript (sample first 200 segments) — prefer local cache, fall back to API
        transcript_data = _resolve_transcript(meeting_id, transcripts, api_transcripts)
        for seg in transcript_data[:200]:
            seg_text = seg.get('text', '')
            if seg_text:
                text_blocks.append(seg_text)

        full_text = '\n'.join(text_blocks)
        full_text_lower = full_text.lower()

        # 1. Detect company mentions
        for alias, slug in COMPANY_ALIASES.items():
            if alias in full_text_lower:
                if slug:
                    company_mentions[slug] = company_mentions.get(slug, 0) + 1
                    if slug not in existing['customers']:
                        companies_without_files.add(slug)

        # 2. Detect product mentions
        for product in PRODUCT_NAMES:
            if product in full_text_lower:
                product_mentions[product] = product_mentions.get(product, 0) + 1

        # 3. Detect commitments (scan line by line)
        for line in full_text.split('\n'):
            line_stripped = line.strip()
            if not line_stripped or len(line_stripped) < 10:
                continue
            for pattern in COMMITMENT_PATTERNS:
                if re.search(pattern, line_stripped, re.IGNORECASE):
                    commitments.append((title, line_stripped[:120]))
                    break

        # 4. Detect waiting-on
        for line in full_text.split('\n'):
            line_stripped = line.strip()
            if not line_stripped or len(line_stripped) < 10:
                continue
            for pattern in WAITING_ON_PATTERNS:
                if re.search(pattern, line_stripped, re.IGNORECASE):
                    waiting_on.append((title, line_stripped[:120]))
                    break

        # 5. External attendees — anyone whose email isn't at the user's company domain.
        # Configure via AICOS_HOME_DOMAIN env var (e.g. "salesforce.com"). If unset,
        # every attendee counts as "external" — not ideal, but it won't break anything.
        home_domain = os.environ.get('AICOS_HOME_DOMAIN', '').strip().lower()
        event = meeting.get('google_calendar_event') or {}
        attendees = event.get('attendees') or []
        for attendee in attendees:
            email = attendee.get('email', '')
            if not email:
                continue
            if home_domain and home_domain in email.lower():
                continue
            domain = email.split('@')[-1] if '@' in email else 'unknown'
            company = domain.split('.')[0].title()
            if company not in external_attendees:
                external_attendees[company] = []
            external_attendees[company].append(email)

    # 6. Check for stale customer files that were mentioned
    stale_suggestions = []
    for slug, count in sorted(company_mentions.items(), key=lambda x: -x[1]):
        customer_file = CUSTOMERS_DIR / f"{slug}.md"
        if customer_file.exists():
            mtime = datetime.fromtimestamp(customer_file.stat().st_mtime)
            days_old = (datetime.now() - mtime).days
            if days_old > 7 and count >= 2:
                stale_suggestions.append((slug, count, days_old))

    # Build both stdout (verbose — useful during manual runs for full context)
    # and markdown report (terse — only actionable gaps go into the daily note).
    stdout_lines = []
    md_lines = []

    stdout_lines.append("\n" + "=" * 60)
    stdout_lines.append("POST-IMPORT INTELLIGENCE REPORT")
    stdout_lines.append("=" * 60)

    # ── stdout (verbose — for operator running the script manually) ──
    if company_mentions:
        stdout_lines.append(f"\nCOMPANIES DETECTED ({len(company_mentions)}):")
        for slug, count in sorted(company_mentions.items(), key=lambda x: -x[1]):
            has_file = slug in existing['customers']
            marker = "  " if has_file else "!!"
            status = "HAS FILE" if has_file else "NO FILE"
            stdout_lines.append(f"  {marker} {slug} ({count}x) — {status}")

    if companies_without_files:
        stdout_lines.append(f"\n!! COMPANIES WITHOUT FILES ({len(companies_without_files)}):")
        for slug in sorted(companies_without_files):
            stdout_lines.append(f"  -> customers/{slug}.md needs to be created")

    if product_mentions:
        stdout_lines.append(f"\nPRODUCTS MENTIONED ({len(product_mentions)}):")
        for name, count in sorted(product_mentions.items(), key=lambda x: -x[1]):
            stdout_lines.append(f"  - {name} ({count}x)")

    if commitments:
        stdout_lines.append(f"\nCOMMITMENTS DETECTED (regex — for review, not final): {len(commitments)}")
        for title, line in commitments[:10]:
            stdout_lines.append(f"  [{title[:30]}] {line}")
        if len(commitments) > 10:
            stdout_lines.append(f"  ... and {len(commitments) - 10} more")

    if waiting_on:
        stdout_lines.append(f"\nWAITING-ON DETECTED (regex — for review, not final): {len(waiting_on)}")
        for title, line in waiting_on[:10]:
            stdout_lines.append(f"  [{title[:30]}] {line}")
        if len(waiting_on) > 10:
            stdout_lines.append(f"  ... and {len(waiting_on) - 10} more")

    if external_attendees:
        total_contacts = sum(len(v) for v in external_attendees.values())
        stdout_lines.append(f"\nEXTERNAL ATTENDEES ({total_contacts} contacts, {len(external_attendees)} companies):")
        for company, emails in sorted(external_attendees.items()):
            slug = company.lower().replace(' ', '-')
            has_file = slug in existing['customers'] or any(
                slug in alias_slug for alias, alias_slug in COMPANY_ALIASES.items()
                if alias_slug and alias_slug in existing['customers'] and slug in alias
            )
            status = "" if has_file else " [NO CUSTOMER FILE]"
            stdout_lines.append(f"  {company}{status}: {', '.join(emails[:3])}")
            if len(emails) > 3:
                stdout_lines.append(f"    + {len(emails) - 3} more")

    if stale_suggestions:
        stdout_lines.append(f"\nSTALE FILE SUGGESTIONS:")
        for slug, count, days_old in stale_suggestions:
            stdout_lines.append(f"  -> customers/{slug}.md mentioned {count}x but last updated {days_old} days ago")

    # ── markdown (terse — only true gaps, skipped entirely if nothing ──
    # Terse because raw regex commitment dumps are noise — Phase 2 AI does the
    # real commitment extraction into the Active Board Canvas. The daily-note
    # report only flags entity-tracking gaps the AI wouldn't catch.
    external_gaps = []
    if external_attendees:
        for company, emails in sorted(external_attendees.items()):
            slug = company.lower().replace(' ', '-')
            has_file = slug in existing['customers'] or any(
                slug in alias_slug for alias, alias_slug in COMPANY_ALIASES.items()
                if alias_slug and alias_slug in existing['customers'] and slug in alias
            )
            if not has_file:
                external_gaps.append((company, emails))

    has_gaps = bool(companies_without_files) or bool(external_gaps) or bool(stale_suggestions)

    if has_gaps:
        md_lines.append("\n## 📋 Entity Gaps")
        md_lines.append("*From Granola import — entities mentioned today that need attention.*\n")

        if companies_without_files:
            md_lines.append(f"**Missing customer files ({len(companies_without_files)}):**")
            for slug in sorted(companies_without_files):
                md_lines.append(f"- `customers/{slug}.md` needs to be created")
            md_lines.append("")

        if external_gaps:
            md_lines.append(f"**External attendees without customer files ({len(external_gaps)}):**")
            for company, emails in external_gaps:
                md_lines.append(f"- **{company}**: {', '.join(emails[:3])}")
            md_lines.append("")

        if stale_suggestions:
            md_lines.append(f"**Stale files mentioned today:**")
            for slug, count, days_old in stale_suggestions:
                md_lines.append(f"- `customers/{slug}.md` — mentioned {count}x, last updated {days_old} days ago")
            md_lines.append("")

    # Summary for stdout only
    total_signals = len(commitments) + len(waiting_on) + len(companies_without_files)
    if total_signals > 0:
        stdout_lines.append(
            f"\nACTION NEEDED: {len(commitments)} commitments (regex), {len(waiting_on)} waiting-on (regex), "
            f"{len(companies_without_files)} missing customer files"
        )
    else:
        stdout_lines.append("\nAll clear — no gaps detected.")
    stdout_lines.append("=" * 60)

    # Print to stdout
    print('\n'.join(stdout_lines))

    # Write to daily note — only if there are actual gaps worth flagging.
    # If nothing's missing, don't clutter the note with an empty "all clear"
    # section — silence is better than noise.
    if target_date:
        daily_note_path = DAILY_NOTES_DIR / f"{target_date.isoformat()}.md"
        if daily_note_path.exists():
            content = daily_note_path.read_text()

            # Remove any prior report section (old "📊 Post-Import Intelligence
            # Report" OR new "📋 Entity Gaps"). Strip whichever we find.
            for header in ('## 📊 Post-Import Intelligence Report', '## 📋 Entity Gaps'):
                if header in content:
                    parts = content.split(header)
                    remaining = parts[1]
                    next_section = remaining.find('\n## ')
                    if next_section != -1:
                        content = parts[0] + remaining[next_section:]
                    else:
                        content = parts[0]

            if has_gaps:
                report_md = '\n'.join(md_lines)
                # Insert before End of Day section if present, else append.
                if '## ✅ End of Day Processing' in content:
                    parts = content.split('## ✅ End of Day Processing')
                    content = parts[0] + report_md + '\n## ✅ End of Day Processing' + parts[1]
                elif '## ✅ End of Day' in content:
                    parts = content.split('## ✅ End of Day')
                    content = parts[0] + report_md + '\n## ✅ End of Day' + parts[1]
                else:
                    content += '\n' + report_md
                print(f"  ✅ Entity gaps written to daily/{target_date.isoformat()}.md")
            else:
                print(f"  ✓ No entity gaps — daily note kept clean")

            daily_note_path.write_text(content)


def main():
    parser = argparse.ArgumentParser(description='Import Granola meetings to daily notes')
    parser.add_argument('--date', help='Date to import (YYYY-MM-DD)', default=None)
    parser.add_argument('--all', action='store_true', help='Import all meetings from last 7 days')
    parser.add_argument('--force', action='store_true', help='Overwrite existing Granola section without prompting')
    parser.add_argument('--include-empty', action='store_true', help='Include calendar meetings that have no notes/transcript as skeleton entries')
    parser.add_argument('--no-api', action='store_true', help='Skip Granola API fallback (local cache only)')
    args = parser.parse_args()

    # Load Granola data
    print("Loading Granola data...")
    state, panels, transcripts = load_granola_data()
    if not state:
        return

    # Load transcript cache and auth token (unless --no-api)
    transcript_cache_path = TRANSCRIPT_CACHE_PATH
    transcript_cache = {}
    access_token = None

    if not args.no_api:
        # Load persistent transcript cache
        if transcript_cache_path.exists():
            try:
                transcript_cache = json.loads(transcript_cache_path.read_text())
                print(f"🌐 Loaded transcript cache ({len(transcript_cache)} entries)")
            except Exception as e:
                print(f"🌐 Could not read transcript cache: {e} — starting fresh")
                transcript_cache = {}

        # Load auth token
        access_token = load_granola_auth_token()
        if access_token:
            print("🌐 Granola API available — will fetch missing transcripts")
        else:
            print("🌐 Granola API unavailable — local cache only")
    else:
        print("Skipping Granola API fallback (--no-api)")

    # Determine dates to process
    if args.all:
        dates = [(datetime.now() - timedelta(days=i)).date() for i in range(7)]
        print(f"Importing meetings from last 7 days...")
    elif args.date:
        dates = [datetime.strptime(args.date, '%Y-%m-%d').date()]
        print(f"Importing meetings for {args.date}...")
    else:
        dates = [datetime.now().date()]
        print(f"Importing meetings for today ({dates[0]})...")

    # Fetch full document list from API to fill local cache gaps
    api_docs = {}
    if access_token:
        api_docs = fetch_documents_from_api(access_token)
        if api_docs:
            print(f"🌐 Fetched {len(api_docs)} documents from Granola API")

    # Process each date
    total_imported = 0
    all_imported_meetings = []
    # Track api_transcripts across loop so it's available after for report/commits
    api_transcripts = {}
    for date in dates:
        # Merge API-discovered documents into local state for this date
        if api_docs:
            added = merge_api_documents_into_state(state, api_docs, date)
            if added > 0:
                print(f"  🌐 Added {added} meeting(s) from API that were missing from local cache for {date}")

        # Fetch missing transcripts from API for this date (if enabled)
        if access_token:
            api_transcripts_new = fetch_missing_transcripts_from_api(
                state, date, transcripts, access_token, transcript_cache
            )
            if api_transcripts_new:
                transcript_cache.update(api_transcripts_new)
                # Persist updated cache to disk
                try:
                    transcript_cache_path.write_text(json.dumps(transcript_cache))
                except Exception as e:
                    print(f"🌐 Warning: could not save transcript cache: {e}")

        # Merge full transcript_cache into api_transcripts so downstream functions
        # can use both newly-fetched and previously-cached API transcripts
        if not args.no_api:
            api_transcripts = transcript_cache

        meetings = get_meetings_for_date(
            state, date, panels, transcripts,
            include_empty=args.include_empty,
            api_transcripts=api_transcripts,
        )

        if not meetings:
            print(f"  {date}: No meetings found")
            continue

        print(f"  {date}: Found {len(meetings)} meeting(s)")

        if import_to_daily_note(
            date, meetings, panels, transcripts,
            force=args.force,
            api_transcripts=api_transcripts,
        ):
            print(f"    ✅ Imported {len(meetings)} meeting(s)")
            total_imported += len(meetings)
            all_imported_meetings.extend(meetings)
        else:
            print(f"    ⏭️  Skipped")

    print(f"\n✨ Done! Imported {total_imported} meeting(s) total.")

    # Generate post-import intelligence report and write to daily note
    if all_imported_meetings:
        # Use the most recent date for the report
        report_date = dates[0] if dates else datetime.now().date()
        generate_import_report(
            all_imported_meetings, panels, transcripts,
            target_date=report_date,
            api_transcripts=api_transcripts if api_transcripts else None,
        )

        # AI-powered commitment extraction — writes clean action items to Dashboard
        extract_and_write_commitments(
            all_imported_meetings, panels, transcripts, report_date,
            api_transcripts=api_transcripts if api_transcripts else None,
        )
    else:
        print("\nNo meetings imported — nothing to process.")

if __name__ == '__main__':
    main()
