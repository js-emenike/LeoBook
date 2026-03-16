"""
fix_swapped_schedules.py — One-off backfill migration

Identifies schedules rows where home_team_name/away_team_name are stored
in the WRONG order relative to the canonical match_link URL, then swaps them.

The Flashscore match_link URL is the ground truth:
  /match/football/home-slug-HOMEID/away-slug-AWAYID/?mid=FIXID
  → first segment = home team, second segment = away team

Safe to re-run: each swap is idempotent (second run finds 0 swaps).

Usage:
  python Scripts/fix_swapped_schedules.py
"""

import sqlite3
import re
import sys
import os

DB = os.path.join(os.path.dirname(__file__), '..', 'Data', 'Store', 'leobook.db')
DB = os.path.normpath(DB)


def parse_match_link(link: str):
    """Extract (url_home_id, url_away_id) from Flashscore match_link."""
    if not link:
        return None, None
    m = re.search(r'/match/football/([^/]+)/([^/?]+)', link)
    if not m:
        return None, None
    h_seg, a_seg = m.group(1), m.group(2)
    h_id = h_seg.rsplit('-', 1)[-1] if '-' in h_seg else ''
    a_id = a_seg.rsplit('-', 1)[-1] if '-' in a_seg else ''
    return h_id, a_id


def main():
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")

    # ── BEFORE count ────────────────────────────────────────────────────────────
    rows = conn.execute(
        "SELECT fixture_id, home_team_id, away_team_id, home_team_name, away_team_name, "
        "home_crest, away_crest, match_link "
        "FROM schedules WHERE match_link IS NOT NULL AND match_link != '' AND home_team_id != ''"
    ).fetchall()

    swapped = []
    for r in rows:
        url_h_id, url_a_id = parse_match_link(r['match_link'])
        if not url_h_id or not url_a_id:
            continue
        db_h_id = r['home_team_id'] or ''
        db_a_id = r['away_team_id'] or ''
        # Detect swap: URL says home should be url_h_id, but DB has it as away
        if url_h_id == db_a_id and url_a_id == db_h_id:
            swapped.append(dict(r))

    print(f"Before backfill: {len(swapped)} swapped schedule rows detected")

    if not swapped:
        print("Nothing to fix. Exiting.")
        conn.close()
        return

    # ── Show sample ─────────────────────────────────────────────────────────────
    print("\nSample fixes (up to 5):")
    for ex in swapped[:5]:
        print(f"  {ex['fixture_id']}: "
              f"'{ex['home_team_name']}' ({ex['home_team_id']}) ↔ "
              f"'{ex['away_team_name']}' ({ex['away_team_id']})")
        print(f"    link: {ex['match_link'][:80]}")

    # ── Apply fixes ─────────────────────────────────────────────────────────────
    fixed = 0
    for r in swapped:
        conn.execute("""
            UPDATE schedules SET
                home_team_id   = :new_h_id,
                home_team_name = :new_h_name,
                home_crest     = :new_h_crest,
                away_team_id   = :new_a_id,
                away_team_name = :new_a_name,
                away_crest     = :new_a_crest
            WHERE fixture_id = :fixture_id
        """, {
            'fixture_id':  r['fixture_id'],
            # Swap home ↔ away
            'new_h_id':    r['away_team_id'],
            'new_h_name':  r['away_team_name'],
            'new_h_crest': r['away_crest'],
            'new_a_id':    r['home_team_id'],
            'new_a_name':  r['home_team_name'],
            'new_a_crest': r['home_crest'],
        })
        fixed += 1

    conn.commit()

    # ── AFTER count ─────────────────────────────────────────────────────────────
    # Re-scan to confirm 0 remaining
    rows_after = conn.execute(
        "SELECT fixture_id, home_team_id, away_team_id, match_link "
        "FROM schedules WHERE match_link IS NOT NULL AND match_link != '' AND home_team_id != ''"
    ).fetchall()

    still_swapped = 0
    for r in rows_after:
        url_h_id, url_a_id = parse_match_link(r['match_link'])
        if not url_h_id or not url_a_id:
            continue
        if url_h_id == (r['away_team_id'] or '') and url_a_id == (r['home_team_id'] or ''):
            still_swapped += 1

    print(f"\nAfter backfill:  {still_swapped} swapped rows remaining")
    print(f"Fixed:           {fixed} rows")

    # ── Show 10 corrected rows ───────────────────────────────────────────────────
    print("\n10 corrected rows (post-fix):")
    for r in swapped[:10]:
        corrected = conn.execute(
            "SELECT fixture_id, home_team_id, home_team_name, away_team_id, away_team_name, match_link "
            "FROM schedules WHERE fixture_id=?", (r['fixture_id'],)
        ).fetchone()
        if corrected:
            c = dict(corrected)
            print(f"  {c['fixture_id']}: home='{c['home_team_name']}' ({c['home_team_id']}) | "
                  f"away='{c['away_team_name']}' ({c['away_team_id']})")

    conn.close()
    print("\n[OK] Backfill complete.")


if __name__ == '__main__':
    main()
