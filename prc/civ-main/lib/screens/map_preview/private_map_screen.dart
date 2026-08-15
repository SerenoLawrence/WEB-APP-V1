import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../core/constants/app_colors.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/helpers.dart';
import '../../models/report.dart';

class PrivateMapScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;
  const PrivateMapScreen({super.key, required this.reportData});

  IncidentReport? _getReport() {
    final id = reportData['reportId'] as String?;
    if (id != null) return AppState().getById(id);
    return AppState().reports.isNotEmpty ? AppState().reports.first : null;
  }

  bool get _isReadOnly => reportData['readOnly'] == true;

  @override
  Widget build(BuildContext context) {
    final report = _getReport();
    if (report == null) {
      return const Scaffold(body: Center(child: Text('Report not found.')));
    }

    final pinColor = AppHelpers.getStatusColor(report.status);
    final pinIcon = AppHelpers.getIssueIcon(report.issue);
    final reportLatLng = LatLng(report.latitude, report.longitude);

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
          'Report Location',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          // â”€â”€ Pending warning banner (own reports only)
          if (!_isReadOnly &&
              (report.status == 'Pending Validation' ||
                  report.status == 'Submitted'))
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.statusPendingBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.statusPendingBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.statusPending.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: AppColors.statusPending,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pending Validation',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.statusPending,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Only you can see this report until it has been validated.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.lock_rounded,
                    color: AppColors.statusPending.withOpacity(0.4),
                    size: 26,
                  ),
                ],
              ),
            ),

         
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: reportLatLng,
                initialZoom: 15.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.civilwatch.app',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: reportLatLng,
                      width: 60,
                      height: 70,
                      child: GestureDetector(
                        onTap: report.isResolved
                            ? () => showDialog(
                                  context: context,
                                  builder: (_) =>
                                      _BeforeAfterDialog(report: report),
                                )
                            : null,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Popup bubble
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.cardShadow,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                report.issue,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Pin circle
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: pinColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: pinColor.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                pinIcon,
                                color: AppColors.white,
                                size: 20,
                              ),
                            ),
                            // Tail
                            CustomPaint(
                              size: const Size(10, 7),
                              painter: _TailPainter(color: pinColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Info sheet ────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _InfoRow(
                  icon: Icons.location_on_rounded,
                  label: 'Barangay ${report.barangay}',
                  subtitle: 'Digos City',
                ),
                const Divider(
                  height: 1,
                  color: AppColors.divider,
                  indent: 20,
                  endIndent: 20,
                ),
                _InfoRow(
                  icon: Icons.my_location_rounded,
                  label: 'Coordinates',
                  subtitle:
                      '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                ),
                const Divider(
                  height: 1,
                  color: AppColors.divider,
                  indent: 20,
                  endIndent: 20,
                ),
                _InfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Submitted',
                  subtitle: AppHelpers.formatDateTime(report.submittedAt),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          //Back button 
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            color: AppColors.white,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to Report'),
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
          ),
        ],
      ),
    );
  }
}

// Info row widget 
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pin tail painter ─────────────────────────────────────────────────────────
class _TailPainter extends CustomPainter {
  final Color color;
  const _TailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}


// ── Photo tile for before/after ───────────────────────────────────────────────
class _MapPhotoTile extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Color labelBg;
  final String? imageUrl;
  final VoidCallback onTap;

  const _MapPhotoTile({
    required this.label,
    required this.labelColor,
    required this.labelBg,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: imageUrl != null ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: labelBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 1.3,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined,
                color: AppColors.textHint, size: 22),
            const SizedBox(height: 4),
            Text('No photo',
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

// ── Fullscreen photo viewer ───────────────────────────────────────────────────
class _FullscreenPhotoViewer extends StatelessWidget {
  final String imageUrl;
  final String title;
  const _FullscreenPhotoViewer(
      {required this.imageUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
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


// ── Before & After modal dialog (shown when pin is tapped) ───────────────────
class _BeforeAfterDialog extends StatelessWidget {
  final dynamic report; // IncidentReport

  const _BeforeAfterDialog({required this.report});

  void _openPhoto(BuildContext context, String? url, String title) {
    if (url == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) =>
            _FullscreenPhotoViewer(imageUrl: url, title: title),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.compare_rounded,
                    size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'Before & After',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Resolved',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusResolved,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Issue name + barangay
            Text(
              report.issue,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Barangay ${report.barangay}, Digos City',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Before & After photos side by side
            Row(
              children: [
                Expanded(
                  child: _MapPhotoTile(
                    label: 'Before',
                    labelColor: AppColors.statusPending,
                    labelBg: const Color(0xFFFEF3C7),
                    imageUrl: report.imageUrl,
                    onTap: () =>
                        _openPhoto(context, report.imageUrl, 'Before Photo'),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.compare_arrows_rounded,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: _MapPhotoTile(
                    label: 'After',
                    labelColor: AppColors.statusResolved,
                    labelBg: const Color(0xFFDCFCE7),
                    imageUrl: report.afterImageUrl,
                    onTap: () => _openPhoto(
                        context, report.afterImageUrl, 'After Photo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
