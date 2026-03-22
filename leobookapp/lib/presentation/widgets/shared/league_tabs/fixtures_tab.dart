// fixtures_tab.dart: fixtures_tab.dart: Widget/screen for App — League Tab Widgets.
// Part of LeoBook App — League Tab Widgets
//
// Classes: LeagueFixturesTab, _LeagueFixturesTabState

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:leobookapp/data/models/match_model.dart';
import 'package:leobookapp/data/repositories/data_repository.dart';
import 'package:leobookapp/core/constants/app_colors.dart';
import 'package:leobookapp/core/widgets/leo_shimmer.dart';
import '../match_card.dart';

class LeagueFixturesTab extends StatefulWidget {
  final String leagueId;
  final String leagueName;
  const LeagueFixturesTab({
    super.key,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  State<LeagueFixturesTab> createState() => _LeagueFixturesTabState();
}

class _LeagueFixturesTabState extends State<LeagueFixturesTab> {
  late Future<List<MatchModel>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _loadFixtures();
  }

  Future<List<MatchModel>> _loadFixtures() async {
    final repo = context.read<DataRepository>();
    final allMatches = await repo.fetchFixturesByLeague(widget.leagueId);
    // Only upcoming/scheduled (exclude finished)
    return allMatches
        .where((m) =>
            m.status != 'Finished' &&
            m.displayStatus != 'FINISHED' &&
            !m.isFinished)
        .toList()
      ..sort((a, b) {
        try {
          return DateTime.parse(a.date).compareTo(DateTime.parse(b.date));
        } catch (_) {
          return 0;
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MatchModel>>(
      future: _matchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MatchListSkeleton();
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final matches = snapshot.data ?? [];

        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_soccer, size: 48, color: AppColors.textGrey),
                const SizedBox(height: 16),
                Text(
                  "No fixtures found",
                  style: GoogleFonts.lexend(
                    color: AppColors.textGrey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: MatchCard(match: matches[index]),
            );
          },
        );
      },
    );
  }
}
