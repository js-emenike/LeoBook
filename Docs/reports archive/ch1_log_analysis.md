# Ch1 Log Analysis — Errors, Failures & Bugs

**Logs:** [leo_chapter1_132525.log](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/docs/leo_chapter1_132525.log) (2346 lines) + [leo_chapter1_145138.log](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/docs/leo_chapter1_145138.log) (17 lines)
**Runtime:** 17m31s (P1) + instant crash (P3)

---

## Cascade Summary

The entire session is a **cascade failure**: P1's zero resolution → P2 zero predictions → P3 crash on null data.

```
P1: 907 fixtures → 0 resolved (BUGS 1-5)
      ↓
P2: 3827 fixtures → 0 predictions, 3827 skipped
      ↓
P3: AIGO loads 5522 historical predictions → hits None team name → FATAL crash (BUG 6)
```

---

## BUG 1 — `NameError`: `all_resolved` crashes Supabase sync

**Log:** `132525.log:L2329`
```
[Sync] [Warning] Supabase push failed: name 'all_resolved' is not defined
```

**Source:** [fb_manager.py:L678](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Modules/FootballCom/fb_manager.py#L678)
```diff
- print(f"  [Sync] Complete: {len(all_resolved)} matches, ...")
+ print(f"  [Sync] Complete: {len(all_resolved_matches)} matches, ...")
```

Variable declared as `all_resolved_matches` at [L544](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Modules/FootballCom/fb_manager.py#L544). Only L678 uses the wrong name. The sync itself (L676-677) likely completed — the crash happens on the success print *after* `_sync_table` returns.

**Fix:** 1-line rename.

---

## BUG 2 — 0/907 fixtures resolved

**Log:** `132525.log:L2331-2338`
```
Fixtures processed  : 907
Resolved            : 0
Unresolved          : 361
```

**Root cause:** The batch phase revisits football.com URLs that had fixtures in Phase 0, but now returns **"no matches on page"** (the page state changed between Phase 0 and batch execution). Examples from the log:

| League | Phase 0 result | Batch phase |
|--------|---------------|-------------|
| Botola Pro D1 | No fixtures | [(4 fixtures)](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/docs/fixtures_table.html#3623-3644) expected → empty page |
| I-League | No fixtures | [(5 fixtures)](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/docs/fixtures_table.html#3623-3644) expected → empty page |
| Philippines FL | No fixtures | [(3 fixtures)](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/docs/fixtures_table.html#3623-3644) expected → empty page |

The `batch_pairs` list stays empty → resolver never called for most batches. The 361 that did reach the resolver all failed (team name mismatch).

---

## BUG 3 — Race condition: shared browser context

**Log:** `132525.log:L2150-2157`
```
[League] MSFL (9 fixtures)     → navigating...
[League] K-League 1 (1 fix)    → navigating...  ← DIFFERENT league, same context
[Harvest] Sequence for MSFL
[Harvest] Sequence for K-League 1
[Extractor] 10/8 cards hydrated.               ← 10 found but 8 expected
```

**Source:** [fb_manager.py:L568-585](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Modules/FootballCom/fb_manager.py#L568-L585) — all league workers share **one browser context**. When `MAX_CONCURRENCY > 1`, tabs interleave and cross-contaminate DOM reads.

---

## BUG 4 — Partial hydration drops fixtures silently

**Log:** [132525.log](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/docs/leo_chapter1_132525.log) — L2118: `1/3 cards`, L2139: `8/9 cards`, L2210: `6/9 cards`

The extractor detects incomplete lazy-loading but proceeds anyway. Lost fixtures are never retried.

---

## BUG 5 — 60% of pages yield nothing (Performance)

~140 of 232 league URLs navigated in Phase 0 returned "No fixtures found" (off-season). ~10 minutes wasted per run with no caching of off-season status.

---

## BUG 6 — `NoneType.lower()` crashes P3 recommendations

**Log:** `145138.log:L9-16`
```
[AIGO Retry] Attempt 1/4 failed: 'NoneType' object has no attribute 'lower'. Retrying...
[AIGO Retry] Attempt 2/4 failed: ...
[AIGO Retry] Attempt 3/4 failed: ...
[AIGO FATAL] Operation failed after 4 attempts.
[Error] Chapter 1 Page 3 failed: 'NoneType' object has no attribute 'lower'
```

**Source:** [prediction_accuracy.py:L49-51](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Data/Access/prediction_accuracy.py#L49-L51)
```python
pred_lower = prediction.lower()   # L27-28 guards this ✓
home_lower = home_team.lower()    # ← NO GUARD — crashes when home_team is None
away_lower = away_team.lower()    # ← NO GUARD — crashes when away_team is None
```

Called from [recommend_bets.py:L118-120](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Scripts/recommend_bets.py#L118-L120):
```python
market = get_market_option(
    p.get('prediction', ''), p.get('home_team', ''), p.get('away_team', '')
)
```

The callers at L118 *do* pass `''` defaults, but other callers (like [calculate_market_reliability](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Scripts/recommend_bets.py#318-362) at [L338](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Scripts/recommend_bets.py#L338)) use `p.get('home_team', '')` too. The issue is that **some prediction records in the DB have `home_team` or `away_team` stored as explicit SQL `NULL`** — and `p.get('home_team', '')` only returns `''` if the key is missing, **not if the key exists with value `None`**.

```diff
  # prediction_accuracy.py:L49-51
- pred_lower = prediction.lower()
- home_lower = home_team.lower()
- away_lower = away_team.lower()
+ pred_lower = (prediction or '').lower()
+ home_lower = (home_team or '').lower()
+ away_lower = (away_team or '').lower()
```

Additionally, `145138.log:L2` shows **P2 produced 0 predictions from 3827 fixtures** — this is the direct downstream consequence of P1's BUG 2 (0 resolved matches). Without resolved fb_matches, there are no odds, so the prediction engine has nothing to generate predictions for.

---

## Priority Fix Order

| # | Bug | Severity | Effort | File |
|---|-----|----------|--------|------|
| 6 | `NoneType.lower()` in [get_market_option](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Data/Access/prediction_accuracy.py#22-108) | 🔴 CRITICAL | Trivial | `prediction_accuracy.py:L49-51` |
| 1 | `all_resolved` typo | 🔴 CRITICAL | Trivial | `fb_manager.py:L678` |
| 3 | Race condition: shared browser context | 🔴 CRITICAL | Medium | `fb_manager.py:L568` |
| 2 | Zero resolution (page state drift) | 🔴 CRITICAL | Investigation | [fb_manager.py](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Modules/FootballCom/fb_manager.py) / [_league_worker](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Modules/FootballCom/fb_manager.py#366-459) |
| 4 | Partial hydration data loss | 🟠 HIGH | Medium | [extractor.py](file:///c:/Users/Admin/Desktop/ProProjection/LeoBook/Modules/FootballCom/extractor.py) |
| 5 | Off-season league waste | 🟡 MEDIUM | Low | Calendar cache |
