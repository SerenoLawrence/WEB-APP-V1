import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/helpers.dart';
import '../../models/report.dart';
import '../../widgets/cards/activity_card.dart';
import '../../widgets/cards/status_card.dart';

class TrackReportScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;
  const TrackReportScreen({super.key, required this.reportData});

  IncidentReport? _getReport() {
    final id = reportData['reportId'] as String?;
    if (id != null) return AppState().getById(id);
    return AppState().reports.isNotEmpty ? AppState().reports.first : null;
  }

  // True when opened from Community Map — hides private-only actions.
  bool get _isReadOnly => reportData['readOnly'] == true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final report = _getReport();

        if (report == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Track Report',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.article_outlined,
                    size: 56,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Report not found',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return _TrackReportBody(report: report, isReadOnly: _isReadOnly);
      },
    );
  }
}

// ── Separate stateless body widget so ListenableBuilder can rebuild it ────────
class _TrackReportBody extends StatelessWidget {
  final IncidentReport report;
  final bool isReadOnly;
  const _TrackReportBody({required this.report, this.isReadOnly = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track Report',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Track the latest progress of your report.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textPrimary,
                ),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.statusResolved,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status card ───────────────────────────────────────────
            StatusCard(
              status: report.status,
              message: _statusMessage(report.status),
              dateLabel:
                  'Submitted on ${AppHelpers.formatDateTime(report.submittedAt)}',
              showLock: report.isPending,
            ),
            const SizedBox(height: 14),

            // ── Before / After Photos ─────────────────────────────────
            _BeforeAfterPhotos(report: report),
            const SizedBox(height: 14),

            // ── Description ───────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Progress Timeline + Incident Location ─────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress Timeline',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _VerticalTimeline(report: report),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Incident Location (top-right, fixed height matching timeline)
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.privateMap,
                      arguments: {'reportId': report.id},
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Incident Location',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Fixed-height map — tall enough to match timeline
                          SizedBox(
                            height: 260,
                            child: _RealMiniMap(
                              lat: report.latitude,
                              lng: report.longitude,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Barangay ${report.barangay}, Digos City',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.map_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'View on Map',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Assigned Office + Activity Log ────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assigned office
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned Office',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (report.assignedOffice == null)
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: const Icon(
                                  Icons.business_rounded,
                                  size: 18,
                                  color: AppColors.textHint,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Not yet assigned',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'After validation.',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.business_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  report.assignedOffice!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Activity Log (bottom-right, small)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activity Log',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (report.activityLog.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.history_rounded,
                                    size: 14, color: AppColors.textHint),
                                const SizedBox(width: 6),
                                Text(
                                  'No activity yet.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          ...report.activityLog.take(2).map((e) {
                            final isLast =
                                e == report.activityLog.take(2).last;
                            return ActivityCard(
                              entry: e,
                              isCurrent: e == report.activityLog.last,
                              isLast: isLast,
                            );
                          }),
                        ],
                        GestureDetector(
                          onTap: () {},
                          child: Row(
                            children: [
                              Text(
                                'View All Activity',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Notification banner ───────────────────────────────────
            if (!isReadOnly)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You will be notified whenever there is an update on your report.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.settings_rounded,
                              size: 12,
                              color: AppColors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Manage',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // ── View on Map button ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.privateMap,
                  arguments: {'reportId': report.id},
                ),
                icon: const Icon(Icons.map_rounded, size: 20),
                label: const Text('View on Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  textStyle: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Back to My Reports ────────────────────────────────────
            if (!isReadOnly)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to My Reports'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _statusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending validation':
        return 'Your report is currently being reviewed by the Super Administrator. Please wait for updates.';
      case 'assigned to office':
        return 'Your report has been assigned to the appropriate government office.';
      case 'in progress':
        return 'The assigned office is currently working on resolving this issue.';
      case 'resolved':
        return 'This issue has been successfully resolved. Thank you for your report.';
      default:
        return 'Your report has been submitted successfully.';
    }
  }
}

class _VerticalTimeline extends StatelessWidget {
  final IncidentReport report;
  static const _steps = [
    'Submitted',
    'Pending Validation',
    'Assigned to Office',
    'In Progress',
    'Resolved',
  ];

  const _VerticalTimeline({required this.report});

  @override
  Widget build(BuildContext context) {
    final currentIdx = report.statusIndex;
    return Column(
      children: List.generate(_steps.length, (i) {
        final isDone = i <= currentIdx;
        final isCurrent = i == currentIdx;
        final isLast = i == _steps.length - 1;
        final color = isDone
            ? AppHelpers.getStatusColor(_steps[i])
            : AppColors.textDisabled;
        final icon = AppHelpers.getStatusIcon(_steps[i]);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppHelpers.getStatusBgColor(_steps[i])
                        : AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? color : AppColors.divider,
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 13,
                    color: isDone ? color : AppColors.textDisabled,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 22,
                    color: i < currentIdx
                        ? AppColors.primary
                        : AppColors.divider,
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _steps[i],
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isDone
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Current',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (i < report.activityLog.length)
                      Text(
                        AppHelpers.formatDateTime(
                          report.activityLog[i].timestamp,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _RealMiniMap extends StatelessWidget {
  final double lat;
  final double lng;
  const _RealMiniMap({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    final map = FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.civilwatch.app',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 32,
              height: 32,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.statusPending,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.statusPending.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: map,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Before / After Photos section
// ─────────────────────────────────────────────────────────────────────────────

class _BeforeAfterPhotos extends StatelessWidget {
  final IncidentReport report;
  const _BeforeAfterPhotos({required this.report});

  @override
  Widget build(BuildContext context) {
    final hasAfter = report.afterImageUrl != null;
    final catColor = AppHelpers.getCategoryColor(report.category);
    final catBg = AppHelpers.getCategoryBgColor(report.category);
    final catIcon = AppHelpers.getCategoryIcon(report.category);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: catBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(catIcon, color: catColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.issue,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 11, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              'Barangay ${report.barangay}, Digos City',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Reference number pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    report.referenceNumber,
                    style: GoogleFonts.robotoMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ── Photo panels ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: hasAfter
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Before photo
                      Expanded(
                        child: _PhotoPanel(
                          label: 'Before',
                          labelColor: AppColors.statusPending,
                          labelBg: const Color(0xFFFEF3C7),
                          imageUrl: report.imageUrl,
                          fallbackIcon: catIcon,
                          fallbackColor: catColor,
                          onTap: () => _openFullscreen(
                              context, report.imageUrl, 'Before Photo'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Swap arrow
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primary
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.compare_arrows_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // After photo
                      Expanded(
                        child: _PhotoPanel(
                          label: 'After',
                          labelColor: AppColors.statusResolved,
                          labelBg: const Color(0xFFDCFCE7),
                          imageUrl: report.afterImageUrl,
                          fallbackIcon: Icons.check_circle_outline_rounded,
                          fallbackColor: AppColors.statusResolved,
                          onTap: () => _openFullscreen(
                              context, report.afterImageUrl, 'After Photo'),
                        ),
                      ),
                    ],
                  )
                // Only before photo (not yet resolved)
                : _PhotoPanel(
                    label: 'Before',
                    labelColor: AppColors.statusPending,
                    labelBg: const Color(0xFFFEF3C7),
                    imageUrl: report.imageUrl,
                    fallbackIcon: catIcon,
                    fallbackColor: catColor,
                    fullWidth: true,
                    onTap: () => _openFullscreen(
                        context, report.imageUrl, 'Incident Photo'),
                    afterPending: report.status != 'Resolved',
                  ),
          ),

          // ── Resolved timestamp (if resolved) ─────────────────────────
          if (report.isResolved && report.resolvedAt != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      color: AppColors.statusResolved, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'Resolved on ${AppHelpers.formatDateTime(report.resolvedAt!)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusResolved,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openFullscreen(
      BuildContext context, String? url, String title) {
    if (url == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) =>
            _FullscreenPhotoView(imageUrl: url, title: title),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single photo panel (before or after)
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoPanel extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Color labelBg;
  final String? imageUrl;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final bool fullWidth;
  final bool afterPending;
  final VoidCallback onTap;

  const _PhotoPanel({
    required this.label,
    required this.labelColor,
    required this.labelBg,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.fallbackColor,
    required this.onTap,
    this.fullWidth = false,
    this.afterPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = fullWidth ? 180.0 : 150.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label badge
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                label == 'After'
                    ? Icons.check_circle_rounded
                    : Icons.camera_alt_rounded,
                size: 11,
                color: labelColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),

        // Photo or placeholder
        GestureDetector(
          onTap: imageUrl != null ? onTap : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: height,
              color: const Color(0xFF1A2A3A),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Actual image
                  if (imageUrl != null)
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => _FallbackPhoto(
                        icon: fallbackIcon,
                        color: fallbackColor,
                        label: 'Photo unavailable',
                      ),
                    )
                  else if (afterPending)
                    // After photo not yet uploaded
                    _FallbackPhoto(
                      icon: Icons.hourglass_top_rounded,
                      color: AppColors.textHint,
                      label: 'After photo pending\nresolution',
                    )
                  else
                    _FallbackPhoto(
                      icon: fallbackIcon,
                      color: fallbackColor,
                      label: 'No photo attached',
                    ),

                  // Tap to expand overlay (only if image loaded)
                  if (imageUrl != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fullscreen_rounded,
                                color: AppColors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'View',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback placeholder when no image
// ─────────────────────────────────────────────────────────────────────────────

class _FallbackPhoto extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _FallbackPhoto({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color.withValues(alpha: 0.5), size: 36),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.white.withValues(alpha: 0.5),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fullscreen photo viewer (tap to dismiss)
// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenPhotoView extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _FullscreenPhotoView({
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Image centered
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.white,
                    size: 64,
                  ),
                ),
              ),
            ),

            // Header bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.white, size: 26),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tap to close hint
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tap anywhere to close  •  Pinch to zoom',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
