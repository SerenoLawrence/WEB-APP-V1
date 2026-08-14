import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/helpers.dart';
import '../../core/state/app_state.dart';
import '../../models/user.dart';

class ProfileScreen extends StatelessWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    // Use the real logged-in user from AppState.
    // Falls back to a blank placeholder if somehow called without a session.
    final state = AppState();
    final user = state.currentUser ?? AppUser(
      id: '',
      fullName: 'Loading...',
      phoneNumber: '',
      barangay: '',
      joinedDate: DateTime.now(),
      totalReports: 0,
      resolvedReports: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (!embedded) ...[
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text('Profile',
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.edit_rounded,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text('Edit',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary, width: 2.5),
                          ),
                          child: Center(
                            child: Text(
                              user.initials,
                              style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.white),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: AppColors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(user.fullName,
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text('Barangay ${user.barangay}, Digos City',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Resident',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Activity Stats ────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Activity',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                    _StatTile(
                          count: state.totalCount,
                          label: 'Total\nReports',
                          icon: Icons.summarize_rounded,
                          color: AppColors.statusAssigned,
                          bg: AppColors.statusAssignedBg,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          count: state.resolvedCount,
                          label: 'Resolved',
                          icon: Icons.task_alt_rounded,
                          color: AppColors.statusResolved,
                          bg: AppColors.statusResolvedBg,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          count: state.pendingCount,
                          label: 'Pending',
                          icon: Icons.hourglass_empty_rounded,
                          color: AppColors.statusPending,
                          bg: AppColors.statusPendingBg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: AppColors.divider),
                    const SizedBox(height: 12),
                    _ProfileInfoRow(
                        icon: Icons.phone_rounded,
                        label: 'Mobile Number',
                        value: _formatPhone(user.phoneNumber)),
                    const SizedBox(height: 8),
                    _ProfileInfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Member Since',
                        value: AppHelpers.formatDate(user.joinedDate)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Menu ──────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.article_rounded,
                      iconBg: AppColors.statusAssignedBg,
                      iconColor: AppColors.statusAssigned,
                      label: 'My Reports',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.myReports),
                    ),
                    const Divider(height: 1, color: AppColors.divider, indent: 56),
                    _MenuTile(
                      icon: Icons.notifications_rounded,
                      iconBg: AppColors.statusPendingBg,
                      iconColor: AppColors.statusPending,
                      label: 'Notifications',
      badge: AppState().unreadCount,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.notifications),
                    ),
                    const Divider(height: 1, color: AppColors.divider, indent: 56),
                    _MenuTile(
                      icon: Icons.help_outline_rounded,
                      iconBg: AppColors.primarySurface,
                      iconColor: AppColors.primary,
                      label: 'Help Center',
                      onTap: () {},
                    ),
                    const Divider(height: 1, color: AppColors.divider, indent: 56),
                    _MenuTile(
                      icon: Icons.info_outline_rounded,
                      iconBg: AppColors.background,
                      iconColor: AppColors.textSecondary,
                      label: 'About CIVILWATCH',
                      onTap: () => _showAbout(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Logout ────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: _MenuTile(
                  icon: Icons.logout_rounded,
                  iconBg: const Color(0xFFFEF2F2),
                  iconColor: const Color(0xFFDC2626),
                  label: 'Logout',
                  labelColor: const Color(0xFFDC2626),
                  onTap: () => _confirmLogout(context),
                  showArrow: false,
                ),
              ),
              const SizedBox(height: 20),

              Text('CIVILWATCH v1.0.0',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textHint)),
              Text('Digos City, Davao del Sur',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textHint)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Call real logout — clears token + resets AppState
              await AppState().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.landing, (r) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Logout',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  /// Format 639XXXXXXXXX → +63 9XX XXX XXXX
  String _formatPhone(String raw) {
    if (raw.isEmpty) return '';
    // Normalise: strip leading country code
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length == 12) {
      digits = digits.substring(2); // → 9XXXXXXXXX
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1); // → 9XXXXXXXXX
    }
    if (digits.length != 10) return raw; // can't format — return as-is
    return '+63 ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppColors.navy, shape: BoxShape.circle),
            child: const Icon(Icons.shield_rounded,
                color: AppColors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text('CIVILWATCH',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(
              'Community Infrastructure & Environmental Incident Reporting, Management, and Monitoring System for Digos City.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Close',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: AppColors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatTile({
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text('$count',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  height: 1.3),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textHint)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ]),
    ]);
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  final int? badge;
  final bool showArrow;

  const _MenuTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.labelColor,
    required this.onTap,
    this.badge,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor ?? AppColors.textPrimary)),
          ),
          if (badge != null && badge! > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$badge',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white)),
            ),
          if (showArrow)
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20),
        ]),
      ),
    );
  }
}
