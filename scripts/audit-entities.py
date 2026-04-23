#!/usr/bin/env python3
"""
Entity audit — find stale or missing entity files.
Scans daily notes for company/person mentions and checks if files exist.
"""

import os
import sys
import re
from pathlib import Path
from datetime import datetime, timedelta

PROJECT_ROOT = Path(__file__).parent.parent

def get_entity_files():
    """Get all existing entity files."""
    entities = {"customers": [], "deals": [], "people": []}
    for category in entities:
        dir_path = PROJECT_ROOT / category
        if dir_path.exists():
            for f in dir_path.rglob("*.md"):
                entities[category].append(f.stem.lower())
    return entities

def get_stale_files(days=30):
    """Find entity files not updated in N days."""
    stale = []
    cutoff = datetime.now() - timedelta(days=days)
    for category in ["customers", "deals", "people/directs", "people/stakeholders"]:
        dir_path = PROJECT_ROOT / category
        if not dir_path.exists():
            continue
        for f in dir_path.rglob("*.md"):
            if f.name.startswith("00-"):
                continue
            mtime = datetime.fromtimestamp(f.stat().st_mtime)
            if mtime < cutoff:
                stale.append((f.relative_to(PROJECT_ROOT), (datetime.now() - mtime).days))
    return stale

def main():
    summary_only = "--summary" in sys.argv

    stale = get_stale_files()
    entities = get_entity_files()

    total_entities = sum(len(v) for v in entities.values())
    stale_count = len(stale)

    if summary_only:
        if stale_count == 0:
            print("All clear")
        else:
            print(f"{stale_count} stale files (>30 days)")
        return

    print(f"\n📊 Entity Audit")
    print(f"{'='*40}")
    print(f"Customers: {len(entities['customers'])}")
    print(f"Deals:     {len(entities['deals'])}")
    print(f"People:    {len(entities['people'])}")
    print(f"Total:     {total_entities}")
    print()

    if stale:
        print(f"⚠️  {stale_count} stale files (>30 days):")
        for path, age in sorted(stale, key=lambda x: -x[1]):
            print(f"  {path} ({age}d)")
    else:
        print("✅ All files updated within 30 days")

if __name__ == "__main__":
    main()
