import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/dummy_data.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/common/section_title.dart';
import '../../widgets/navigation/bottom_nav.dart';
import '../../screens/my_reports/my_reports_screen.dart';
import '../../screens/community_map/community_map_screen.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../screens/profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  final List<Widget> _pages = [
    const _HomeTab(),
    const MyReportsScreen(embedded: true),
    const CommunityMapScreen(embedded: true),
    const NotificationScreen(embedded: true),
    const ProfileScreen(embedded: true),
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _navIndex, children: _pages),
      bottomNavigationBar: CivilWatchBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Tab Content
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final state = AppState();
        final user = state.currentUser;
        final pending = state.pendingCount;
        final inProgress = state.inProgressCount;
        final resolvedCount = state.resolvedCount;
        final unreadCount = state.unreadCount;

        return SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _HomeAppBar(
                  userName: user?.firstName ?? 'Citizen',
                  unreadCount: unreadCount,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GreetingSection(firstName: user?.firstName ?? 'Citizen'),
                      const SizedBox(height: 20),
                      _ReportCtaBanner(
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.reportCategory),
                      ),
                      const SizedBox(height: 28),
                      SectionTitle(
                        title: 'My Reports',
                        actionLabel: 'View All',
                        onAction: () => Navigator.pushNamed(
                            context, AppRoutes.myReports),
                      ),
                      const SizedBox(height: 14),
                      _ReportSummaryRow(
                        pending: pending,
                        inProgress: inProgress,
                        resolved: resolvedCount,
                        total: state.totalCount,
                      ),
                      const SizedBox(height: 28),
                      SectionTitle(
                        title: 'Community Map',
                        actionLabel: 'View Map',
                        onAction: () => Navigator.pushNamed(
                            context, AppRoutes.communityMap),
                      ),
                      const SizedBox(height: 14),
                      _MiniMapCard(
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.communityMap),
                      ),
                      const SizedBox(height: 28),
                      SectionTitle(
                        title: 'Latest Announcements',
                        actionLabel: 'View All',
                        onAction: () {},
                      ),
                      const SizedBox(height: 14),
                      ...state.announcements
                          .map((a) => _AnnouncementCard(announcement: a)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Home App Bar ──────────────────────────────────────────────────────────────
class _HomeAppBar extends StatelessWidget {
  final String userName;
  final int unreadCount;

  const _HomeAppBar({required this.userName, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.shield_rounded,
                    color: AppColors.white.withOpacity(0.15), size: 30),
                const Icon(Icons.location_on_rounded,
                    color: AppColors.white, size: 14),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'CIVILWATCH',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          // Notification bell
          GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary, size: 26),
                if (unreadCount > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.statusResolved,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Greeting Section ──────────────────────────────────────────────────────────
class _GreetingSection extends StatelessWidget {
  final String firstName;
  const _GreetingSection({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                AppHelpers.getGreeting(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$firstName!',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Help make Digos City a better place.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // City illustration
        SizedBox(
          width: 120,
          height: 90,
          child: CustomPaint(painter: _MiniCityPainter()),
        ),
      ],
    );
  }
}

// ── Report CTA Banner ─────────────────────────────────────────────────────────
class _ReportCtaBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ReportCtaBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report a Concern',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tap to report infrastructure or\nenvironmental concerns.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.white.withOpacity(0.75),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Report Summary Row ────────────────────────────────────────────────────────
class _ReportSummaryRow extends StatelessWidget {
  final int pending;
  final int inProgress;
  final int resolved;
  final int total;

  const _ReportSummaryRow({
    required this.pending,
    required this.inProgress,
    required this.resolved,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryTile(
          count: pending,
          label: 'Pending\nValidation',
          icon: Icons.hourglass_empty_rounded,
          color: AppColors.statusPending,
          bg: AppColors.statusPendingBg,
        ),
        const SizedBox(width: 10),
        _SummaryTile(
          count: inProgress,
          label: 'In Progress',
          icon: Icons.construction_rounded,
          color: AppColors.statusInProgress,
          bg: AppColors.statusInProgressBg,
        ),
        const SizedBox(width: 10),
        _SummaryTile(
          count: resolved,
          label: 'Resolved',
          icon: Icons.task_alt_rounded,
          color: AppColors.statusResolved,
          bg: AppColors.statusResolvedBg,
        ),
        const SizedBox(width: 10),
        _SummaryTile(
          count: total,
          label: 'Total\nReports',
          icon: Icons.summarize_rounded,
          color: AppColors.statusAssigned,
          bg: AppColors.statusAssignedBg,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const _SummaryTile({
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini Map Card ─────────────────────────────────────────────────────────────
class _MiniMapCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MiniMapCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 8,
                offset: Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Map background
              CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, 170),
                  painter: _HomeMiniMapPainter()),

              // Pins
              Positioned(
                  top: 55, left: 90,
                  child: _MiniPin(color: AppColors.environment)),
              Positioned(
                  top: 35, left: 180,
                  child: _MiniPin(color: AppColors.infrastructure)),
              Positioned(
                  top: 80, left: 160,
                  child: _MiniPin(color: AppColors.infrastructure)),
              Positioned(
                  top: 90, left: 60,
                  child: _MiniPin(color: AppColors.environment)),
              Positioned(
                  top: 50, left: 250,
                  child: _MiniPin(color: AppColors.environment)),

              // Legend overlay
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendItem(
                          color: AppColors.statusAssigned,
                          label: 'Infrastructure'),
                      const SizedBox(height: 3),
                      _LegendItem(
                          color: AppColors.environment,
                          label: 'Environment'),
                      const SizedBox(height: 3),
                      _LegendItem(
                          color: AppColors.statusPending, label: 'Others'),
                    ],
                  ),
                ),
              ),

              // City label
              Positioned(
                top: 65,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Digos City',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPin extends StatelessWidget {
  final Color color;
  const _MiniPin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Icon(Icons.construction_rounded,
          color: AppColors.white, size: 12),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Announcement Card ─────────────────────────────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  announcement.body,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppHelpers.formatDate(announcement.date),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────
class _MiniCityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final buildPaint = Paint()..color = const Color(0xFFD0DFE8);
    final treePaint = Paint()..color = const Color(0xFFA8D5B5);
    final groundPaint = Paint()..color = const Color(0xFFCADCE4);

    // Ground strip
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
        groundPaint);

    // Buildings
    final bs = [
      [0.0, 0.3, 0.22, 0.42],
      [0.24, 0.1, 0.18, 0.62],
      [0.44, 0.22, 0.2, 0.5],
      [0.66, 0.35, 0.16, 0.37],
      [0.84, 0.15, 0.16, 0.57],
    ];
    for (final b in bs) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            size.width * b[0] + 2,
            size.height * b[1],
            size.width * b[2] - 4,
            size.height * b[3],
          ),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        buildPaint,
      );
    }

    // Trees at bottom
    for (var i = 0; i < 3; i++) {
      final tx = size.width * (0.1 + i * 0.38);
      final ty = size.height * 0.68;
      canvas.drawCircle(Offset(tx, ty), 9, treePaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _HomeMiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFEEF2F7));

    final roadPaint = Paint()
      ..color = AppColors.white
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    // roads
    canvas.drawLine(Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5), roadPaint);
    canvas.drawLine(Offset(size.width * 0.45, 0),
        Offset(size.width * 0.45, size.height), roadPaint);

    // river
    final riverPaint = Paint()
      ..color = const Color(0xFFB3D4E8)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.15, 0)
      ..quadraticBezierTo(
          size.width * 0.5, size.height * 0.45,
          size.width, size.height * 0.6);
    canvas.drawPath(path, riverPaint);

    // block fills
    final blockPaint = Paint()
      ..color = const Color(0xFFD8E2DC).withOpacity(0.5);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.06, 55, 35),
        blockPaint);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.55, size.height * 0.08, 65, 28),
        blockPaint);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.65, 48, 45),
        blockPaint);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.65, 60, 38),
        blockPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
