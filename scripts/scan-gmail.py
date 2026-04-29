#!/usr/bin/env python3
"""scan-gmail.py — Gmail scan for the morning routine.

Fetches emails matching the query filter in email-monitor.json at the repo root,
applies the surface and skip rules, and emits structured JSON to stdout. Phase 2
of the morning routine reads this output and synthesizes the daily-note email
highlights section — or skips it entirely if nothing substantive landed.

Usage:
    python3 scripts/scan-gmail.py                  # scan last 24h
    python3 scripts/scan-gmail.py --lookback 2d    # scan last 2 days
    python3 scripts/scan-gmail.py --write-daily    # also append to today's daily note

Auth: uses ADC at ~/.config/gcloud/application_default_credentials.json. No tokens
stored in the repo. If ADC needs refresh, run `gcloud auth application-default login`.
"""
import argparse
import base64
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

# Suppress the Python 3.9 EOL warning from google-auth — it's noisy and not actionable
import warnings
warnings.filterwarnings("ignore", category=FutureWarning, module="google")

from google.auth import default as adc_default
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

PROJECT_DIR = Path(__file__).resolve().parent.parent
CONFIG_PATH = PROJECT_DIR / "email-monitor.json"
DAILY_DIR = PROJECT_DIR / "daily"

GMAIL_SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]


def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)


def build_gmail_service():
    """Build a Gmail API client using ADC."""
    creds, _ = adc_default(scopes=GMAIL_SCOPES)
    # Gmail API requires a user subject when using ADC — falls back to the
    # authenticated user automatically when impersonation isn't set.
    return build("gmail", "v1", credentials=creds, cache_discovery=False)


def _header(headers, name):
    for h in headers:
        if h.get("name", "").lower() == name.lower():
            return h.get("value", "")
    return ""


def _extract_body(payload):
    """Pull the plain-text body out of a Gmail message payload. Falls back to
    HTML with tags stripped if plain text is unavailable (e.g. The Daily)."""
    text_body = ""
    html_body = ""

    def walk(part):
        nonlocal text_body, html_body
        mime = part.get("mimeType", "")
        body = part.get("body", {})
        data = body.get("data")
        if data:
            try:
                decoded = base64.urlsafe_b64decode(data.encode("ASCII")).decode("utf-8", errors="replace")
            except Exception:
                decoded = ""
            if mime == "text/plain" and not text_body:
                text_body = decoded
            elif mime == "text/html" and not html_body:
                html_body = decoded
        for sub in part.get("parts", []) or []:
            walk(sub)

    walk(payload)

    if text_body.strip():
        return _clean_text(text_body)
    if html_body.strip():
        return _clean_text(_strip_html(html_body))
    return ""


def _strip_html(html):
    """Minimal HTML → text. Good enough for newsletter-style emails."""
    # Remove <style> and <script> blocks first
    html = re.sub(r"<(style|script)[^>]*>.*?</\1>", "", html, flags=re.DOTALL | re.IGNORECASE)
    # Convert common block elements to newlines
    html = re.sub(r"</?(br|p|div|tr|h[1-6]|li)[^>]*>", "\n", html, flags=re.IGNORECASE)
    # Drop all other tags
    html = re.sub(r"<[^>]+>", "", html)
    # HTML entities (bare-minimum)
    html = (
        html.replace("&nbsp;", " ")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", '"')
            .replace("&#39;", "'")
            .replace("&ldquo;", '"')
            .replace("&rdquo;", '"')
            .replace("&rsquo;", "'")
            .replace("&lsquo;", "'")
            .replace("&mdash;", "—")
            .replace("&ndash;", "–")
            .replace("&hellip;", "…")
    )
    return _clean_text(html)


def _clean_text(text):
    """Collapse whitespace, cap truncation-protecting length, strip zero-width."""
    text = text.replace("‌", "").replace("​", "").replace("﻿", "")
    # Collapse runs of blank lines
    text = re.sub(r"\n{3,}", "\n\n", text)
    # Trim trailing whitespace on each line
    text = "\n".join(line.rstrip() for line in text.splitlines())
    return text.strip()


def _sender_email(from_header):
    """Extract just the email address from a "Name <addr@domain>" header."""
    m = re.search(r"<([^>]+)>", from_header)
    if m:
        return m.group(1).lower()
    return from_header.strip().lower()


def classify(msg, config):
    """Decide which surface rule this message hits. Returns bucket name or None
    if the message should be skipped."""
    headers = msg.get("payload", {}).get("headers", [])
    from_addr = _sender_email(_header(headers, "From"))
    subject = _header(headers, "Subject")
    subject_lower = subject.lower()

    # Skip by sender
    for skip in config.get("skip_senders", {}).get("senders", []):
        if skip.lower() in from_addr:
            return None, from_addr, subject

    # Skip by subject pattern
    for pat in config.get("skip_subjects", {}).get("patterns", []):
        if pat.lower() in subject_lower:
            return None, from_addr, subject

    # Apply surface rules in priority order
    rules = config.get("surface_rules", {})

    # The Daily — corp newsletter
    the_daily = rules.get("the_daily", {})
    if (the_daily.get("from", "").lower() in from_addr and
        the_daily.get("subject_contains", "").lower() in subject_lower):
        return "the_daily", from_addr, subject

    # Workday tasks
    workday = rules.get("workday_tasks", {})
    if workday.get("from", "").lower() in from_addr:
        return "workday_tasks", from_addr, subject

    # Employee Success — milestones/anniversaries
    es = rules.get("employee_success", {})
    if es.get("from", "").lower() in from_addr:
        return "employee_success", from_addr, subject

    # Direct emails — from a real person whose body mentions org/products/people keywords
    direct = rules.get("direct_emails", {})
    keywords = direct.get("keywords", [])
    home_domain = config.get("home_domain", "")
    # If it's from the home domain and not a known system sender → likely a real human
    if from_addr and home_domain and f"@{home_domain}" in from_addr and not any(
        corp in from_addr for corp in [
            "employeecomms", "myworkday", "employeesuccess",
            "noreply", "no-reply", "okta", "notifications", "donotreply"
        ]
    ):
        # This is someone at the home domain — likely a real human
        body_lower = (_extract_body(msg.get("payload", {})) or "").lower()
        if any(kw.lower() in body_lower or kw.lower() in subject_lower for kw in keywords):
            return "direct_emails", from_addr, subject
        # No keyword match — but still a human email, keep with lower priority
        return "other_human", from_addr, subject

    # Doesn't fit any surface rule — skip
    return None, from_addr, subject


def fetch_messages(service, query, max_results=50):
    """Fetch message IDs matching query, then hydrate each."""
    try:
        resp = service.users().messages().list(
            userId="me", q=query, maxResults=max_results
        ).execute()
    except HttpError as e:
        print(f"ERROR: Gmail list failed: {e}", file=sys.stderr)
        return []

    ids = [m["id"] for m in resp.get("messages", [])]
    messages = []
    for mid in ids:
        try:
            msg = service.users().messages().get(
                userId="me", id=mid, format="full"
            ).execute()
            messages.append(msg)
        except HttpError as e:
            print(f"WARN: failed to fetch {mid}: {e}", file=sys.stderr)
            continue
    return messages


def summarize(msg, bucket, from_addr, subject, body_text):
    """Build the structured summary object for one message."""
    headers = msg.get("payload", {}).get("headers", [])
    date_header = _header(headers, "Date")
    # Keep the body to a reasonable preview — Phase 2 Claude reads this
    preview = body_text[:1500] if body_text else ""
    return {
        "bucket": bucket,
        "from": from_addr,
        "subject": subject,
        "date": date_header,
        "preview": preview,
        "message_id": msg.get("id"),
        "thread_id": msg.get("threadId"),
    }


def main():
    ap = argparse.ArgumentParser(description="Scan Gmail for the morning routine")
    ap.add_argument("--lookback", default=None, help="Override lookback (e.g. 1d, 2d, 6h)")
    ap.add_argument("--max", type=int, default=None, help="Override max results")
    ap.add_argument("--json-only", action="store_true", help="Emit only JSON, no human-readable summary")
    args = ap.parse_args()

    config = load_config()
    query = config["query_filter"]
    if args.lookback:
        query = re.sub(r"newer_than:\S+", f"newer_than:{args.lookback}", query)
    max_results = args.max or config.get("scan_settings", {}).get("max_results", 50)

    service = build_gmail_service()
    raw_messages = fetch_messages(service, query, max_results=max_results)

    results = []
    skipped = 0
    for msg in raw_messages:
        bucket, from_addr, subject = classify(msg, config)
        if bucket is None:
            skipped += 1
            continue
        body = _extract_body(msg.get("payload", {}))
        results.append(summarize(msg, bucket, from_addr, subject, body))

    # Group by bucket for the JSON output
    grouped = {}
    for r in results:
        grouped.setdefault(r["bucket"], []).append(r)

    output = {
        "scanned_at": datetime.now().isoformat(timespec="seconds"),
        "query": query,
        "total_fetched": len(raw_messages),
        "total_surfaced": len(results),
        "total_skipped": skipped,
        "by_bucket": {k: len(v) for k, v in grouped.items()},
        "messages": results,
    }

    if not args.json_only:
        print("=" * 60, file=sys.stderr)
        print(f"GMAIL SCAN — {output['scanned_at']}", file=sys.stderr)
        print(f"Query: {query}", file=sys.stderr)
        print(f"Fetched: {output['total_fetched']}  |  Surfaced: {output['total_surfaced']}  |  Skipped: {skipped}", file=sys.stderr)
        print(f"By bucket: {output['by_bucket']}", file=sys.stderr)
        print("=" * 60, file=sys.stderr)

    # Emit structured JSON to stdout — this is what Phase 2 reads
    print(json.dumps(output, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
