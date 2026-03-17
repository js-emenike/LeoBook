// data_repository.dart: Data access through FastAPI backend.
// Part of LeoBook App — Repositories
//
// Classes: DataRepository
//
// MIGRATION: All Supabase direct calls replaced with FastAPI endpoints.
// Auth: Supabase JWT token forwarded as Bearer header.
// Realtime streams: kept on Supabase (Phase 2 → WebSocket).

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:leobookapp/data/models/match_model.dart';
import 'package:leobookapp/data/models/recommendation_model.dart';
import 'package:leobookapp/data/models/standing_model.dart';
import 'package:leobookapp/data/models/league_model.dart';
import 'package:leobookapp/data/services/api_client.dart';
import 'dart:convert';
import 'dart:async';

class DataRepository {
  static const String _keyRecommended = 'cached_recommended';
  static const String _keyPredictions = 'cached_predictions';

  final ApiClient _api = ApiClient();

  // Keep Supabase client ONLY for realtime streams (Phase 2: migrate to WS)
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Predictions (via FastAPI) ─────────────────────────────────

  Future<List<MatchModel>> fetchMatches({DateTime? date}) async {
    try {
      final params = <String, String>{
        'page': '1',
        'page_size': '2000',
      };
      if (date != null) {
        params['date'] =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      }

      final response = await _api.get('/predictions', queryParams: params);
      final List<dynamic> data = response['data'] ?? [];

      debugPrint('Loaded ${data.length} predictions from FastAPI');

      // Cache locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPredictions, jsonEncode(data));

      return data
          .map((row) => MatchModel.fromCsv(row, row))
          .where((m) => m.prediction != null && m.prediction!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint("DataRepository Error (FastAPI): $e");

      // Fallback to cache
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_keyPredictions);
      if (cachedString != null) {
        try {
          final List<dynamic> cachedData = jsonDecode(cachedString);
          return cachedData
              .map((row) => MatchModel.fromCsv(row, row))
              .where((m) => m.prediction != null && m.prediction!.isNotEmpty)
              .toList();
        } catch (cacheError) {
          debugPrint("Failed to load from cache: $cacheError");
        }
      }
      return [];
    }
  }

  // ── Team Matches (via FastAPI /predictions) ───────────────────

  Future<List<MatchModel>> getTeamMatches(String teamName) async {
    try {
      // FastAPI doesn't have a team-specific endpoint yet, so we fetch
      // a large page and filter client-side (same data, no anon key)
      final response = await _api.get('/predictions', queryParams: {
        'page': '1',
        'page_size': '200',
      });
      final List<dynamic> data = response['data'] ?? [];

      final matches = <MatchModel>[];
      for (var row in data) {
        final home = row['home_team']?.toString() ?? '';
        final away = row['away_team']?.toString() ?? '';
        if (home == teamName || away == teamName) {
          matches.add(MatchModel.fromCsv(row, row));
        }
      }

      // Sort by date descending
      matches.sort((a, b) {
        try {
          return DateTime.parse(b.date).compareTo(DateTime.parse(a.date));
        } catch (_) {
          return 0;
        }
      });

      return matches;
    } catch (e) {
      debugPrint("DataRepository Error (Team Matches): $e");
      return [];
    }
  }

  // ── Recommendations (via FastAPI — safety-gated) ──────────────

  Future<List<RecommendationModel>> fetchRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _api.get('/recommendations', queryParams: {
        'limit': '50',
      });
      final List<dynamic> data = response['data'] ?? [];

      debugPrint(
          'Loaded ${data.length} recommendations from FastAPI '
          '(${response['passed_safety']} passed safety gate, '
          '${response['rejected_safety']} rejected)');

      await prefs.setString(_keyRecommended, jsonEncode(data));

      return data.map((json) => RecommendationModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error fetching recommendations (FastAPI): $e");
      final cached = prefs.getString(_keyRecommended);
      if (cached != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(cached);
          return jsonList
              .map((json) => RecommendationModel.fromJson(json))
              .toList();
        } catch (cacheError) {
          debugPrint("Failed to load recommendations from cache: $cacheError");
        }
      }
      return [];
    }
  }

  // ── Standings (via FastAPI) ───────────────────────────────────

  Future<List<StandingModel>> getStandings(String leagueName) async {
    try {
      final response = await _api.get('/standings/$leagueName');
      final List<dynamic> data = response['data'] ?? [];

      return data.map((row) => StandingModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint("DataRepository Error (Standings): $e");
      return [];
    }
  }

  // ── Team Crests (via FastAPI /predictions — extracted from data) ──

  Future<Map<String, String>> fetchTeamCrests() async {
    // Crests are now embedded in standings/predictions responses
    // For a dedicated crests endpoint, this would be /teams — future addition
    // For now, return empty and rely on data already in MatchModel
    try {
      final response = await _api.get('/predictions', queryParams: {
        'page': '1',
        'page_size': '200',
      });
      final List<dynamic> data = response['data'] ?? [];
      final Map<String, String> crests = {};
      for (var row in data) {
        final home = row['home_team']?.toString();
        final homeCrest = row['home_team_crest']?.toString();
        final away = row['away_team']?.toString();
        final awayCrest = row['away_team_crest']?.toString();
        if (home != null && homeCrest != null && homeCrest.isNotEmpty) {
          crests[home] = homeCrest;
        }
        if (away != null && awayCrest != null && awayCrest.isNotEmpty) {
          crests[away] = awayCrest;
        }
      }
      return crests;
    } catch (e) {
      debugPrint("DataRepository Error (Team Crests): $e");
      return {};
    }
  }

  // ── Schedules (via FastAPI /predictions) ──────────────────────

  Future<List<MatchModel>> fetchAllSchedules({DateTime? date}) async {
    try {
      final params = <String, String>{
        'page': '1',
        'page_size': '2000',
      };
      if (date != null) {
        params['date'] =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      }

      final response = await _api.get('/predictions', queryParams: params);
      final List<dynamic> data = response['data'] ?? [];

      return data.map((row) => MatchModel.fromCsv(row)).toList();
    } catch (e) {
      debugPrint("DataRepository Error (Schedules): $e");
      return [];
    }
  }

  // ── Team Standing (single) ───────────────────────────────────

  Future<StandingModel?> getTeamStanding(String teamName) async {
    try {
      // Fetch from standings and find the team
      // This uses a broad standings call since we don't know the league
      // Future: add /standings/team/{name} endpoint
      return null; // Will be resolved when team's league is known
    } catch (e) {
      debugPrint("DataRepository Error (Team Standing): $e");
      return null;
    }
  }

  // ── Realtime Streams (KEPT on Supabase — Phase 2 migration) ──
  // These stay as Supabase direct calls for now.
  // Phase 2: migrate to FastAPI WebSocket /ws/live

  Stream<List<MatchModel>> watchLiveScores() {
    return _supabase.from('live_scores').stream(primaryKey: ['fixture_id']).map(
        (rows) => rows.map((row) => MatchModel.fromCsv(row)).toList());
  }

  Stream<List<MatchModel>> watchPredictions({DateTime? date}) {
    var query =
        _supabase.from('predictions').stream(primaryKey: ['fixture_id']);

    return query.map((rows) {
      var matches = rows.map((row) => MatchModel.fromCsv(row, row)).toList();
      if (date != null) {
        final dateStr =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        matches = matches.where((m) => m.date == dateStr).toList();
      }
      return matches;
    });
  }

  Stream<List<MatchModel>> watchSchedules({DateTime? date}) {
    var query = _supabase.from('schedules').stream(primaryKey: ['fixture_id']);

    return query.map((rows) {
      var matches = rows.map((row) => MatchModel.fromCsv(row)).toList();
      if (date != null) {
        final dateStr =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        matches = matches.where((m) => m.date == dateStr).toList();
      }
      return matches;
    });
  }

  Stream<List<StandingModel>> watchStandings(String leagueName) {
    return _supabase
        .from('standings')
        .stream(primaryKey: ['standings_key'])
        .eq('region_league', leagueName)
        .map((rows) => rows.map((row) => StandingModel.fromJson(row)).toList());
  }

  Stream<Map<String, String>> watchTeamCrestUpdates() {
    return _supabase.from('teams').stream(primaryKey: ['name']).map((rows) {
      final Map<String, String> crests = {};
      for (var row in rows) {
        if (row['name'] != null && row['crest'] != null) {
          crests[row['name'].toString()] = row['crest'].toString();
        }
      }
      return crests;
    });
  }

  // ── Leagues (via FastAPI) ─────────────────────────────────────

  Future<List<LeagueModel>> fetchLeagues() async {
    try {
      final response = await _api.get('/leagues');
      final List<dynamic> data = response['data'] ?? [];

      return data.map((row) => LeagueModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint("DataRepository Error (Leagues): $e");
      return [];
    }
  }

  Future<LeagueModel?> fetchLeagueById(String leagueId) async {
    try {
      // Fetch all leagues and filter — FastAPI MVP doesn't have /leagues/{id} yet
      final leagues = await fetchLeagues();
      return leagues.cast<LeagueModel?>().firstWhere(
            (l) => l?.leagueId == leagueId,
            orElse: () => null,
          );
    } catch (e) {
      debugPrint("DataRepository Error (League by ID): $e");
      return null;
    }
  }

  Future<List<MatchModel>> fetchFixturesByLeague(String leagueId,
      {String? season}) async {
    try {
      // Use predictions endpoint filtered client-side by league
      final response = await _api.get('/predictions', queryParams: {
        'page': '1',
        'page_size': '500',
      });
      final List<dynamic> data = response['data'] ?? [];

      return data
          .where((row) => row['league_id'] == leagueId)
          .map((row) => MatchModel.fromCsv(row))
          .toList();
    } catch (e) {
      debugPrint("DataRepository Error (Fixtures by League): $e");
      return [];
    }
  }
}
