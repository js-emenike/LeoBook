"""
fix_predictions_team_names.py — One-off backfill for predictions table.

For each prediction, replaces home_team/away_team with the fixture-specific
names from schedules.home_team_name / away_team_name
(= the canonical source, stored at scrape time).

Falls back to teams.name if schedules column is empty.
Only updates rows where the name actually differs.

Safe to re-run (idempotent — second run changes 0 rows).

Usage:
  python Scripts/fix_predictions_team_names.py
"""

import sqlite3, os

DB = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'Data', 'Store', 'leobook.db'))


def main():
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=15000")

    rows = conn.execute("""
        SELECT p.fixture_id,
               p.home_team AS old_home, p.away_team AS old_away,
               COALESCE(NULLIF(s.home_team_name,''), h.name) AS new_home,
               COALESCE(NULLIF(s.away_team_name,''), a.name) AS new_away
        FROM predictions p
        JOIN schedules s ON p.fixture_id = s.fixture_id
        LEFT JOIN teams h ON s.home_team_id = h.team_id
        LEFT JOIN teams a ON s.away_team_id = a.team_id
        WHERE p.fixture_id IS NOT NULL
    """).fetchall()

    needs_update = [r for r in rows
                    if (r['old_home'] or '') != (r['new_home'] or '')
                    or (r['old_away'] or '') != (r['new_away'] or '')]

    swaps = sum(1 for r in needs_update
                if (r['old_home'] or '') == (r['new_away'] or '')
                and (r['old_away'] or '') == (r['new_home'] or ''))

    print(f"Predictions checked:   {len(rows)}")
    print(f"Rows needing update:   {len(needs_update)}")
    print(f"  of which SWAPS:      {swaps}")

    if not needs_update:
        print("\nNothing to fix. Exiting.")
        conn.close()
        return

    print("\nSample fixes (up to 5):")
    for r in needs_update[:5]:
        arrow = "<-> SWAP" if (r['old_home'] or '') == (r['new_away'] or '') else "-> RENAME"
        print(f"  {r['fixture_id']} [{arrow}]: "
              f"'{r['old_home']}' -> '{r['new_home']}' | "
              f"'{r['old_away']}' -> '{r['new_away']}'")

    # Batch update
    for r in needs_update:
        conn.execute(
            "UPDATE predictions SET home_team=:h, away_team=:a WHERE fixture_id=:fid",
            {'h': r['new_home'], 'a': r['new_away'], 'fid': r['fixture_id']}
        )
    conn.commit()

    # Verify
    remaining = conn.execute("""
        SELECT COUNT(*) FROM predictions p
        JOIN schedules s ON p.fixture_id = s.fixture_id
        LEFT JOIN teams h ON s.home_team_id = h.team_id
        LEFT JOIN teams a ON s.away_team_id = a.team_id
        WHERE (p.home_team != COALESCE(NULLIF(s.home_team_name,''), h.name)
            OR p.away_team != COALESCE(NULLIF(s.away_team_name,''), a.name))
          AND COALESCE(NULLIF(s.home_team_name,''), h.name) IS NOT NULL
    """).fetchone()[0]

    print(f"\nAfter backfill: {remaining} predictions still mismatched")
    print(f"Fixed:          {len(needs_update)} rows")
    print("\n[OK] Predictions backfill complete.")
    conn.close()


if __name__ == '__main__':
    main()
