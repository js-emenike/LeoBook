// account_screen.dart: Grok-style settings/profile page.
// Part of LeoBook App — Screens
//
// Grouped sections with category headers, glass cards, version footer
// with in-app update availability check.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:leobookapp/core/constants/app_colors.dart';
import 'package:leobookapp/core/services/update_service.dart';
import 'package:leobookapp/logic/cubit/user_cubit.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral900,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Settings',
                    style: GoogleFonts.lexend(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // ── Profile Card ─────────────────────────────
                    _buildProfileCard(context),
                    const SizedBox(height: 28),

                    // ── General ──────────────────────────────────
                    _sectionLabel('General'),
                    const SizedBox(height: 8),
                    _glassGroup([
                      _settingsTile(
                        icon: Icons.brightness_6_outlined,
                        title: 'Appearance',
                        subtitle: 'Dark',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.language,
                        title: 'Language',
                        subtitle: 'English',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.tune_rounded,
                        title: 'Advanced',
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── Data & Information ───────────────────────
                    _sectionLabel('Data & Information'),
                    const SizedBox(height: 8),
                    _glassGroup([
                      _settingsTile(
                        icon: Icons.shield_outlined,
                        title: 'Data Controls',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.storage_outlined,
                        title: 'Cached Data',
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── Legal ────────────────────────────────────
                    _glassGroup([
                      _settingsTile(
                        icon: Icons.description_outlined,
                        title: 'Open Source Licenses',
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'LeoBook',
                          applicationVersion: UpdateService.appVersion,
                        ),
                      ),
                      _settingsTile(
                        icon: Icons.article_outlined,
                        title: 'Terms of Use',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.lock_outline,
                        title: 'Privacy Policy',
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── Actions ──────────────────────────────────
                    _glassGroup([
                      _settingsTile(
                        icon: Icons.bug_report_outlined,
                        title: 'Report a Problem',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign out',
                        titleColor: AppColors.liveRed,
                        onTap: () {
                          context.read<UserCubit>().logout();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Signed out')),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 32),

                    // ── Version Footer ───────────────────────────
                    _buildVersionFooter(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Profile Card
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildProfileCard(BuildContext context) {
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        final user = state.user;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.neutral800,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  user.id.length >= 2
                      ? user.id.substring(0, 2).toUpperCase()
                      : user.id.toUpperCase(),
                  style: GoogleFonts.lexend(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name & email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.isPro ? 'Pro Member' : 'LeoBook User',
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email ?? user.id,
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Pro badge or upgrade button
              if (user.isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PRO',
                    style: GoogleFonts.lexend(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Upgrade',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Section Label
  // ═══════════════════════════════════════════════════════════════════════

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: GoogleFonts.lexend(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Glass Group (list of tiles in a single rounded card)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _glassGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: Colors.white.withValues(alpha: 0.06),
                indent: 52,
              ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Settings Tile
  // ═══════════════════════════════════════════════════════════════════════

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: titleColor ?? AppColors.textTertiary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: titleColor ?? Colors.white,
                ),
              ),
            ),
            if (subtitle != null) ...[
              Text(
                subtitle,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (titleColor == null)
              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppColors.textDisabled,
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Version Footer with Update Check
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildVersionFooter(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, updateService, _) {
        final info = updateService.info;
        return Center(
          child: Column(
            children: [
              // App version
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_graph_rounded,
                    size: 16,
                    color: AppColors.textDisabled,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'v${UpdateService.appVersion}',
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textDisabled,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              // Update available
              if (info.updateAvailable) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    if (info.downloadUrl != null) {
                      launchUrl(
                        Uri.parse(info.downloadUrl!),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.lexend(fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'New Version is Available: ',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                        TextSpan(
                          text: 'Update',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
