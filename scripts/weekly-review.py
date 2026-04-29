#!/usr/bin/env python3
"""
Weekly Review Script
Generates a weekly review by analyzing the week's daily notes.

Usage:
    python3 scripts/weekly-review.py                    # Review current week
    python3 scripts/weekly-review.py --week 2026-W04    # Review specific week
    python3 scripts/weekly-review.py --dry-run           # Print without saving
"""

import os
import re
from datetime import datetime, timedelta
from pathlib import Path
import argparse

DAILY_NOTES_DIR = Path(__file__).parent.parent / "daily"
WEEKLY_REVIEWS_DIR = Path(__file__).parent.parent / "team" / "weekly-reviews"


def get_week_dates(week_str=None):
    if week_str:
        year, week = week_str.split('-W')
        first_day = datetime.strptime(f'{int(year)}-W{int(week)}-1', '%G-W%V-%u').date()
    else:
        today = datetime.now().date()
        first_day = today - timedelta(days=today.weekday())
    return [first_day + timedelta(days=i) for i in range(5)]


def get_week_string(date):
    return date.strftime('%G-W%V')


def read_daily_note(date):
    note_path = DAILY_NOTES_DIR / f"{date.isoformat()}.md"
    if not note_path.exists():
        return None
    with open(note_path, 'r') as f:
        return f.read()


def extract_commitments(content):
    commitments = []
    lines = content.split('\n')
    in_commit_section = False
    for line in lines:
        if '⭐' in line or 'COMMIT:' in line.upper():
            in_commit_section = True
            if '⭐' in line and ':' in line:
                commitments.append(line.strip())
        elif in_commit_section:
            if line.strip().startswith('- [') or line.strip().startswith('- ⭐'):
                commitments.append(line.strip())
            elif line.strip().startswith('#') or line.strip().startswith('**⏳'):
                in_commit_section = False
    return commitments


def extract_waiting_on(content):
    waiting = []
    lines = content.split('\n')
    in_waiting_section = False
    for line in lines:
        if '⏳' in line or 'WAITING:' in line.upper():
            in_waiting_section = True
            if '⏳' in line and ':' in line:
                waiting.append(line.strip())
        elif in_waiting_section:
            if line.strip().startswith('- '):
                waiting.append(line.strip())
            elif line.strip().startswith('#') or line.strip().startswith('**'):
                in_waiting_section = False
    return waiting


def extract_meetings(content):
    meetings = []
    for line in content.split('\n'):
        if line.strip().startswith('### ') and (' - ' in line or 'AM' in line or 'PM' in line):
            meetings.append(line.replace('###', '').strip())
    return meetings


def extract_customer_mentions(content):
    customers = set()
    customers.update(re.findall(r'\[\[customers/([^\]]+)\.md\]\]', content))
    customers.update(re.findall(r'customers/([a-z\-]+)\.md', content))
    return list(customers)


def generate_weekly_review(week_dates):
    week_str = get_week_string(week_dates[0])
    all_commitments, all_waiting, all_meetings, all_customers = [], [], [], []
    days_with_notes = 0

    for date in week_dates:
        content = read_daily_note(date)
        if content:
            days_with_notes += 1
            all_commitments.extend(extract_commitments(content))
            all_waiting.extend(extract_waiting_on(content))
            all_meetings.extend(extract_meetings(content))
            all_customers.extend(extract_customer_mentions(content))

    all_customers = list(set(all_customers))

    review = f"""# Weekly Review: {week_str}
**Week of {week_dates[0].strftime('%B %d, %Y')}**

*Generated: {datetime.now().strftime('%Y-%m-%d %I:%M %p')}*

---

## Week at a Glance

- **Days with notes:** {days_with_notes}/5
- **Meetings captured:** {len(all_meetings)}
- **Commitments made:** {len(all_commitments)}
- **Waiting on others:** {len(all_waiting)}
- **Customers touched:** {len(all_customers)}

---

## Wins & Accomplishments

*Review the week and note what went well:*

- [ ]
- [ ]
- [ ]

---

## Challenges & Blockers

*What was difficult this week? What got in the way?*

- [ ]
- [ ]
- [ ]

---

## Commitments Made This Week

"""
    if all_commitments:
        for commit in all_commitments[:15]:
            review += f"{commit}\n"
    else:
        review += "*No commitments extracted*\n"

    review += """
---

## Waiting On Others

"""
    if all_waiting:
        for wait in all_waiting[:15]:
            review += f"{wait}\n"
    else:
        review += "*No waiting items extracted*\n"

    review += """
---

## Customer Touchpoints

"""
    if all_customers:
        for customer in sorted(all_customers):
            review += f"- [[customers/{customer}.md]]\n"
    else:
        review += "*No customer meetings this week*\n"

    review += """
---

## Key Themes & Patterns

*What patterns emerged this week? What should carry forward?*

-
-
-

---

## Priorities for Next Week

1.
2.
3.

---

## Meetings This Week

"""
    if all_meetings:
        for meeting in all_meetings[:25]:
            review += f"- {meeting}\n"
    else:
        review += "*No meetings captured*\n"

    review += f"""
---

*Source: Daily notes from {week_dates[0].isoformat()} to {week_dates[-1].isoformat()}*
"""
    return review, week_str


def main():
    parser = argparse.ArgumentParser(description='Generate weekly review from daily notes')
    parser.add_argument('--week', help='Week to review (YYYY-Wxx format)', default=None)
    parser.add_argument('--dry-run', action='store_true', help='Print review without saving')
    args = parser.parse_args()

    print("Generating weekly review...")
    week_dates = get_week_dates(args.week)
    week_str = get_week_string(week_dates[0])
    print(f"Week: {week_str} ({week_dates[0].isoformat()} to {week_dates[-1].isoformat()})")

    notes_found = []
    for date in week_dates:
        note_path = DAILY_NOTES_DIR / f"{date.isoformat()}.md"
        status = "found" if note_path.exists() else "missing"
        if note_path.exists():
            notes_found.append(date)
        print(f"  {date.isoformat()} — {status}")

    if not notes_found:
        print("\nNo daily notes found for this week.")
        return

    review_content, week_str = generate_weekly_review(week_dates)

    if args.dry_run:
        print("\n--- WEEKLY REVIEW (dry run) ---")
        print(review_content)
    else:
        WEEKLY_REVIEWS_DIR.mkdir(parents=True, exist_ok=True)
        review_path = WEEKLY_REVIEWS_DIR / f"{week_str}.md"
        with open(review_path, 'w') as f:
            f.write(review_content)
        print(f"\nSaved to: {review_path}")
        print("Next: fill in Wins, Challenges, Themes, and Next Week priorities.")


if __name__ == '__main__':
    main()
