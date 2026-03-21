// recommendation_card.dart: Match prediction card for Top Predictions.
// Part of LeoBook App — Widgets
//
// Inspired by Type3.png (scheduled) and Type4.png (finished).
// Features: countdown timer (1hr before), football.com badge, reliability pill.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:leobookapp/core/constants/app_colors.dart';
import 'package:leobookapp/core/constants/responsive_constants.dart';
import 'package:leobookapp/core/constants/spacing_constants.dart';
import 'package:leobookapp/core/theme/leo_typography.dart';
import 'package:leobookapp/data/models/recommendation_model.dart';
import 'package:leobookapp/data/repositories/data_repository.dart';
import '../../screens/team_screen.dart';
import '../../screens/league_screen.dart';

class RecommendationCard extends StatefulWidget {
  final RecommendationModel recommendation;
  final VoidCallback? onTap;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.onTap,
  });

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  Timer? _countdownTimer;
  Duration? _timeToKickoff;

  RecommendationModel get rec => widget.recommendation;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    final kickoff = _parseKickoffTime();
    if (kickoff == null) return;

    _updateCountdown(kickoff);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown(kickoff);
    });
  }

  void _updateCountdown(DateTime kickoff) {
    final now = DateTime.now();
    final diff = kickoff.difference(now);

    // Only show countdown if within 1 hour
    if (diff.isNegative || diff.inHours >= 1) {
      if (_timeToKickoff != null) {
        setState(() => _timeToKickoff = null);
      }
      return;
    }

    setState(() => _timeToKickoff = diff);
  }

  DateTime? _parseKickoffTime() {
    try {
      final dateParts = rec.date.split('-');
      if (dateParts.length != 3) return null;

      final timeParts = rec.time.split(':');
      if (timeParts.length < 2) return null;

      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLive = rec.confidence.toLowerCase().contains('live') ||
        rec.league.toLowerCase().contains('live');

    // Parse country/league
    String country = '';
    String leagueDisplay = rec.league;
    if (rec.league.contains(':')) {
      final parts = rec.league.split(':');
      if (parts.length >= 2) {
        country = parts[0].trim();
        leagueDisplay = parts[1].trim();
      }
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.neutral800,
          borderRadius: BorderRadius.circular(SpacingScale.cardRadius),
          border: Border.all(
            color: isLive
                ? AppColors.liveRed.withValues(alpha: 0.3)
                : AppColors.neutral700,
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header: League + Date/Time ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.sp(context, 12),
                Responsive.sp(context, 10),
                Responsive.sp(context, 12),
                Responsive.sp(context, 6),
              ),
              child: Row(
                children: [
                  // League crest
                  if (rec.leagueCrestUrl != null &&
                      rec.leagueCrestUrl!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(right: Responsive.sp(context, 5)),
                      child: CachedNetworkImage(
                        imageUrl: rec.leagueCrestUrl!,
                        width: Responsive.sp(context, 12),
                        height: Responsive.sp(context, 12),
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  // League name
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LeagueScreen(
                              leagueId: rec.league,
                              leagueName: rec.league,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        country.isNotEmpty
                            ? '$country: $leagueDisplay'
                            : leagueDisplay,
                        style: LeoTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Date/time
                  Text(
                    '${rec.date}  ${rec.time}',
                    style: LeoTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Teams Row ──
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.sp(context, 12),
                vertical: Responsive.sp(context, 8),
              ),
              child: Row(
                children: [
                  // Home team
                  Expanded(
                    child: _TeamLabel(
                      name: rec.homeTeam,
                      shortName: rec.homeShort,
                      crestUrl: rec.homeCrestUrl,
                      alignment: CrossAxisAlignment.start,
                      onTap: () => _navigateToTeam(context, rec.homeTeam),
                    ),
                  ),
                  // Home crest
                  _TeamCrest(
                    crestUrl: rec.homeCrestUrl,
                    shortName: rec.homeShort,
                    size: Responsive.sp(context, 28),
                  ),
                  // VS or countdown
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.sp(context, 8),
                    ),
                    child: _buildCenter(context, isLive),
                  ),
                  // Away crest
                  _TeamCrest(
                    crestUrl: rec.awayCrestUrl,
                    shortName: rec.awayShort,
                    size: Responsive.sp(context, 28),
                  ),
                  // Away team
                  Expanded(
                    child: _TeamLabel(
                      name: rec.awayTeam,
                      shortName: rec.awayShort,
                      crestUrl: rec.awayCrestUrl,
                      alignment: CrossAxisAlignment.end,
                      onTap: () => _navigateToTeam(context, rec.awayTeam),
                    ),
                  ),
                ],
              ),
            ),

            // ── Countdown row (only when within 1hr) ──
            if (_timeToKickoff != null)
              Padding(
                padding: EdgeInsets.only(bottom: Responsive.sp(context, 6)),
                child: _buildCountdownRow(context),
              ),

            // ── Prediction Bar ──
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.sp(context, 12),
                vertical: Responsive.sp(context, 8),
              ),
              decoration: BoxDecoration(
                color: isLive
                    ? AppColors.liveRed.withValues(alpha: 0.08)
                    : AppColors.neutral700.withValues(alpha: 0.5),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(SpacingScale.cardRadius),
                ),
              ),
              child: Row(
                children: [
                  // Prediction text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.prediction,
                          style: LeoTypography.labelLarge.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Reliability badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.sp(context, 6),
                      vertical: Responsive.sp(context, 2),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(SpacingScale.chipRadius),
                    ),
                    child: Text(
                      '${rec.reliabilityScore.toStringAsFixed(0)}%',
                      style: LeoTypography.labelSmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Odds + football.com logo
                  if (rec.marketOdds > 0) ...[
                    SizedBox(width: Responsive.sp(context, 8)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.sp(context, 8),
                        vertical: Responsive.sp(context, 3),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(SpacingScale.chipRadius),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/footballcom_logo.svg',
                            width: Responsive.sp(context, 12),
                            height: Responsive.sp(context, 12),
                            colorFilter: const ColorFilter.mode(
                              AppColors.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(width: Responsive.sp(context, 4)),
                          Text(
                            rec.marketOdds.toStringAsFixed(2),
                            style: LeoTypography.labelLarge.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Availability indicator
                  if (rec.isAvailable) ...[
                    SizedBox(width: Responsive.sp(context, 6)),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenter(BuildContext context, bool isLive) {
    if (isLive) {
      return _LivePulse();
    }
    return Text(
      'VS',
      style: LeoTypography.titleLarge.copyWith(
        color: AppColors.textTertiary,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildCountdownRow(BuildContext context) {
    final d = _timeToKickoff!;
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.timer_outlined,
          size: Responsive.sp(context, 10),
          color: AppColors.warning,
        ),
        SizedBox(width: Responsive.sp(context, 4)),
        Text(
          '$mm : $ss',
          style: LeoTypography.labelLarge.copyWith(
            color: AppColors.warning,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  void _navigateToTeam(BuildContext context, String teamName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamScreen(
          teamName: teamName,
          repository: context.read<DataRepository>(),
        ),
      ),
    );
  }
}

// ─── Team Crest Circle ──────────────────────────────────────
class _TeamCrest extends StatelessWidget {
  final String? crestUrl;
  final String shortName;
  final double size;

  const _TeamCrest({
    required this.crestUrl,
    required this.shortName,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.neutral700,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.neutral600,
          width: 0.5,
        ),
      ),
      child: ClipOval(
        child: crestUrl != null && crestUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: crestUrl!,
                fit: BoxFit.contain,
                placeholder: (_, __) => Center(
                  child: Text(
                    shortName,
                    style: LeoTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Center(
                  child: Text(
                    shortName,
                    style: LeoTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  shortName,
                  style: LeoTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
      ),
    );
  }
}

// ─── Team Name Label ────────────────────────────────────────
class _TeamLabel extends StatelessWidget {
  final String name;
  final String shortName;
  final String? crestUrl;
  final CrossAxisAlignment alignment;
  final VoidCallback? onTap;

  const _TeamLabel({
    required this.name,
    required this.shortName,
    this.crestUrl,
    required this.alignment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        name,
        textAlign:
            alignment == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: LeoTypography.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Live Pulse Indicator ───────────────────────────────────
class _LivePulse extends StatefulWidget {
  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 0.4).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.sp(context, 8),
          vertical: Responsive.sp(context, 3),
        ),
        decoration: BoxDecoration(
          color: AppColors.liveRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(SpacingScale.chipRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.liveRed,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: Responsive.sp(context, 4)),
            Text(
              'LIVE',
              style: LeoTypography.labelSmall.copyWith(
                color: AppColors.liveRed,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
