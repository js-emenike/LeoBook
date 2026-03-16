"""
validate_prediction_names.py
Post-fix validation: measure how well predictions.home_team now aligns
with schedules.home_team_name (the fixture-specific canonical name).
Run after applying the prediction_pipeline.py COALESCE fix.
"""
import sqlite3, re, os

DB = os.path.join(os.path.dirname(__file__), '..', 'Data', 'Store', 'leobook.db')
DB = os.path.normpath(DB)

conn = sqlite3.connect(DB)
conn.row_factory = sqlite3.Row

print("=" * 60)
print("POST-FIX VALIDATION: prediction names vs fixture names")
print("=" * 60)

# 1. Compare predictions vs schedules names
rows = conn.execute("""
    SELECT p.fixture_id,
           p.home_team AS p_home, p.away_team AS p_away,
           s.home_team_name AS s_home, s.away_team_name AS s_away,
           COALESCE(NULLIF(s.home_team_name,''), h.name) AS canonical_home,
           COALESCE(NULLIF(s.away_team_name,''), a.name) AS canonical_away
    FROM predictions p
    JOIN schedules s ON p.fixture_id = s.fixture_id
    LEFT JOIN teams h ON s.home_team_id = h.team_id
    LEFT JOIN teams a ON s.away_team_id = a.team_id
    WHERE s.match_link IS NOT NULL AND s.match_link != ''
    LIMIT 3000
""").fetchall()

total = len(rows)
match_canonical_home = sum(1 for r in rows if (r['p_home'] or '') == (r['canonical_home'] or ''))
match_canonical_away = sum(1 for r in rows if (r['p_away'] or '') == (r['canonical_away'] or ''))
confirmed_swaps = sum(
    1 for r in rows
    if (r['p_home'] or '') == (r['s_away'] or '') and (r['p_away'] or '') == (r['s_home'] or '')
)

print(f"\nChecked {total} predictions")
print(f"p.home_team == canonical_home: {match_canonical_home}/{total} ({100*match_canonical_home/max(total,1):.1f}%)")
print(f"p.away_team == canonical_away: {match_canonical_away}/{total} ({100*match_canonical_away/max(total,1):.1f}%)")
print(f"Confirmed SWAPS (home<->away):  {confirmed_swaps} ({100*confirmed_swaps/max(total,1):.1f}%)")

print("\n[Before fix reference: home 24.6%, away ~25%, swaps 15.5%]")
print("[After COALESCE fix, new predictions should use schedules.home_team_name directly]")

# 2. Simulate what new predictions will see
print("\n--- Simulated new_fixtures JOIN (what pipeline now returns) ---")
sim = conn.execute("""
    SELECT
        COALESCE(NULLIF(s.home_team_name,''), h.name) AS home_team_name,
        COALESCE(NULLIF(s.away_team_name,''), a.name) AS away_team_name,
        s.home_team_id, s.away_team_id, s.fixture_id, s.match_link
    FROM schedules s
    LEFT JOIN teams h ON s.home_team_id = h.team_id
    LEFT JOIN teams a ON s.away_team_id = a.team_id
    WHERE s.match_status = 'scheduled'
      AND s.match_link IS NOT NULL AND s.match_link != ''
    ORDER BY s.date
    LIMIT 10
""").fetchall()

def parse_url(link):
    m = re.search(r'/match/football/([^/]+)/([^/?]+)', link or '')
    if not m: return '', ''
    h = m.group(1).rsplit('-', 1)
    a = m.group(2).rsplit('-', 1)
    return h[0].replace('-', ' ').title() if len(h)>1 else '', a[0].replace('-', ' ').title() if len(a)>1 else ''

correct = 0
for r in sim:
    url_h_approx, url_a_approx = parse_url(r['match_link'])
    print(f"  {r['fixture_id']}: home='{r['home_team_name']}' | away='{r['away_team_name']}'")
    correct += 1

print(f"\nSample scheduled fixtures pulled with new query: {correct}")
conn.close()
