import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/dummy_data.dart';
import '../../core/utils/helpers.dart';
import '../../models/report.dart';
import '../../widgets/map/filter_chip.dart';

class CommunityMapScreen extends StatefulWidget {
  final bool embedded;
  const CommunityMapScreen({super.key, this.embedded = false});

  @override
  State<CommunityMapScreen> createState() => _CommunityMapScreenState();
}

class _CommunityMapScreenState extends State<CommunityMapScreen> {
  String _activeFilter = 'All';
  MapPin? _selectedPin;
  final MapController _mapController = MapController();

  // Digos City center
  static const LatLng _center = LatLng(6.7498, 125.3572);

  /// Convert community reports from AppState into MapPin objects
  List<MapPin> _toPins(List<IncidentReport> reports) {
    return reports
        .where((r) => r.latitude != 0 && r.longitude != 0)
        .map((r) => MapPin(
              id: 'pin-${r.id}',
              reportId: r.id,
              category: r.category,
              issue: r.issue,
              description: r.description,
              barangay: r.barangay,
              status: r.status,
              referenceNumber: r.referenceNumber,
              lat: r.latitude,
              lng: r.longitude,
              imageUrl: r.imageUrl,
            ))
        .toList();
  }

  List<MapPin> _filteredPins(List<MapPin> pins) {
    if (_activeFilter == 'All') return pins;
    return pins.where((p) => p.category == _activeFilter).toList();
  }

  void _onPinTap(MapPin pin) {
    setState(() => _selectedPin = _selectedPin?.id == pin.id ? null : pin);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final allPins = _toPins(AppState().communityReportsPublic);
        final filtered = _filteredPins(allPins);

        final infraCount =
            allPins.where((p) => p.category == 'Infrastructure').length;
        final envCount =
            allPins.where((p) => p.category == 'Environment').length;
        final othersCount =
            allPins.where((p) => p.category == 'Others').length;

        return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _MapHeader(embedded: widget.embedded),
            _FilterRow(
              activeFilter: _activeFilter,
              onChanged: (f) => setState(() {
                _activeFilter = f;
                _selectedPin = null;
              }),
            ),
            Expanded(
              child: Stack(
                children: [
                  // â”€â”€ OSM tile map â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 13.5,
                      onTap: (_, __) => setState(() => _selectedPin = null),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.civilwatch.app',
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: filtered.map((pin) {
                          final isSelected = _selectedPin?.id == pin.id;
                          final color = AppHelpers.getCategoryColor(
                            pin.category,
                          );
                          final icon = AppHelpers.getIssueIcon(pin.issue);

                          return Marker(
                            point: LatLng(pin.lat, pin.lng),
                            width: isSelected ? 58 : 48,
                            height: isSelected ? 70 : 58,
                            alignment: Alignment.bottomCenter,
                            child: GestureDetector(
                              onTap: () => _onPinTap(pin),
                              child: _TeardropPin(
                                color: color,
                                icon: icon,
                                isSelected: isSelected,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  // â”€â”€ Center / location button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Positioned(
                    right: 14,
                    bottom: _selectedPin != null ? 320 : 14,
                    child: GestureDetector(
                      onTap: () => _mapController.move(_center, 13.5),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          size: 20,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // â”€â”€ Bottom: either detail card or stats bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
              child: _selectedPin != null
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(context).size.height * 0.65,
                      ),
                      child: _PinDetailSheet(
                        key: ValueKey(_selectedPin!.id),
                        pin: _selectedPin!,
                        onClose: () => setState(() => _selectedPin = null),
                        mapController: _mapController,
                      ),
                    )
                  : _StatsBar(
                      key: const ValueKey('stats'),
                      total: allPins.length,
                      infraCount: infraCount,
                      envCount: envCount,
                      othersCount: othersCount,
                    ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}

// â”€â”€ Teardrop map pin â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TeardropPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool isSelected;

  const _TeardropPin({
    required this.color,
    required this.icon,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 58.0 : 48.0;
    final iconSize = isSelected ? 24.0 : 20.0;

    return SizedBox(
      width: size,
      height: size * 1.3,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Circle head
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: isSelected ? 14 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.white, size: iconSize),
          ),
          // Tail
          Positioned(
            bottom: 0,
            child: CustomPaint(
              size: Size(isSelected ? 14 : 10, isSelected ? 14 : 10),
              painter: _TailPainter(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MapHeader extends StatelessWidget {
  final bool embedded;
  const _MapHeader({required this.embedded});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!embedded) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.only(top: 2, right: 8),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Map',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Digos City, Davao del Sur',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Notification bell with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              Positioned(
                top: 6,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.environment,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Filter row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FilterRow extends StatelessWidget {
  final String activeFilter;
  final void Function(String) onChanged;
  const _FilterRow({required this.activeFilter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            MapFilterChip(
              label: 'All',
              isSelected: activeFilter == 'All',
              onTap: () => onChanged('All'),
              icon: Icons.grid_view_rounded,
            ),
            const SizedBox(width: 8),
            MapFilterChip(
              label: 'Infrastructure',
              isSelected: activeFilter == 'Infrastructure',
              onTap: () => onChanged('Infrastructure'),
              icon: Icons.construction_rounded,
              activeColor: AppColors.white,
              activeBg: AppColors.infrastructure,
            ),
            const SizedBox(width: 8),
            MapFilterChip(
              label: 'Environment',
              isSelected: activeFilter == 'Environment',
              onTap: () => onChanged('Environment'),
              icon: Icons.eco_rounded,
              activeColor: AppColors.white,
              activeBg: AppColors.environment,
            ),
            const SizedBox(width: 8),
            MapFilterChip(
              label: 'Others',
              isSelected: activeFilter == 'Others',
              onTap: () => onChanged('Others'),
              icon: Icons.more_horiz_rounded,
              activeColor: AppColors.white,
              activeBg: AppColors.statusSubmitted,
            ),
            const SizedBox(width: 8),
            MapFilterChip(
              label: 'Filters',
              isSelected: false,
              onTap: () {},
              icon: Icons.tune_rounded,
              isFiltersChip: true,
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Pin detail bottom sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PinDetailSheet extends StatelessWidget {
  final MapPin pin;
  final VoidCallback onClose;
  final MapController mapController;

  const _PinDetailSheet({
    super.key,
    required this.pin,
    required this.onClose,
    required this.mapController,
  });

  void _viewFullDetails(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.trackReport,
      arguments: {'reportId': pin.reportId, 'readOnly': true},
    );
  }

  void _viewOnMap(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.privateMap,
      arguments: {'reportId': pin.reportId},
    );
  }


  @override
  Widget build(BuildContext context) {
    final color = AppHelpers.getCategoryColor(pin.category);
    final catBg = AppHelpers.getCategoryBgColor(pin.category);
    final statusColor = AppHelpers.getStatusColor(pin.status);
    final statusBg = AppHelpers.getStatusBgColor(pin.status);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Scrollable content â€” prevents overflow when before/after photos
          // push the sheet taller than the available screen height
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // â”€â”€ Top row: image + info + close â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image placeholder
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 90,
                        height: 90,
                        color: const Color(0xFF1A1A2E),
                        child: pin.imageUrl != null
                            ? Image.network(pin.imageUrl!, fit: BoxFit.cover)
                            : const Icon(
                                Icons.image_not_supported_rounded,
                                color: Colors.white38,
                                size: 32,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title + status + ref
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category icon bubble
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: catBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  AppHelpers.getIssueIcon(pin.issue),
                                  color: color,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pin.issue,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              pin.status,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Reference number
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Ref. No.',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    pin.referenceNumber,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Close button
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // â”€â”€ Details section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Row(
                  children: [
                    const Icon(
                      Icons.article_outlined,
                      size: 15,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Details',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pin.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        pin.barangay,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // â”€â”€ Location preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 15,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Location Preview',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 110,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(pin.lat, pin.lng),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.civilwatch.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(pin.lat, pin.lng),
                                  width: 40,
                                  height: 50,
                                  alignment: Alignment.bottomCenter,
                                  child: _TeardropPin(
                                    color: AppHelpers.getCategoryColor(
                                      pin.category,
                                    ),
                                    icon: AppHelpers.getIssueIcon(pin.issue),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Expand icon
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: GestureDetector(
                            onTap: () => _viewOnMap(context),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.cardShadow,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.open_in_new_rounded,
                                size: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // â”€â”€ View Full Details button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _viewFullDetails(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View Full Details',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          ), // SingleChildScrollView
          ), // Flexible
        ],
      ),
    );
  }
}

// â”€â”€ Stats bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _StatsBar extends StatelessWidget {
  final int total;
  final int infraCount;
  final int envCount;
  final int othersCount;

  const _StatsBar({
    super.key,
    required this.total,
    required this.infraCount,
    required this.envCount,
    required this.othersCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          _StatTile(
            label: 'Total',
            count: total,
            color: AppColors.textPrimary,
            bg: AppColors.background,
            isActive: false,
          ),
          const SizedBox(width: 10),
          _StatTile(
            label: 'Infrastructure',
            count: infraCount,
            color: AppColors.infrastructure,
            bg: AppColors.infrastructureBg,
            isActive: true,
          ),
          const SizedBox(width: 10),
          _StatTile(
            label: 'Environment',
            count: envCount,
            color: AppColors.environment,
            bg: AppColors.environmentBg,
            isActive: true,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bg;
  final bool isActive;

  const _StatTile({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: color.withOpacity(0.15)) : null,
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Zoom button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: AppColors.cardShadow, blurRadius: 4),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

// â”€â”€ Pin tail painter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

