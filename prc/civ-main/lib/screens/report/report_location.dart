import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/navigation/app_bar.dart';
import '_report_stepper.dart';

// Default centre: Digos City, Davao del Sur
const _kDefaultLat = 6.7498;
const _kDefaultLng = 125.3572;

// ── Official 26 barangays of Digos City (PhilAtlas / PSA 2020) ───────────────
const _kDigosBarangays = [
  'Aplaya',
  'Balabag',
  'Binaton',
  'Cogon',
  'Colorado',
  'Dawis',
  'Dulangan',
  'Goma',
  'Igpit',
  'Kapatagan',
  'Kiagot',
  'Lungag',
  'Mahayahay',
  'Matti',
  'Ruparan',
  'San Agustin',
  'San Jose',
  'San Miguel',
  'San Roque',
  'Sinawilan',
  'Soong',
  'Tiguman',
  'Tres de Mayo',
  'Zone 1 (Pob.)',
  'Zone 2 (Pob.)',
  'Zone 3 (Pob.)',
];

class ReportLocationScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  const ReportLocationScreen({super.key, required this.reportData});

  @override
  State<ReportLocationScreen> createState() => _ReportLocationScreenState();
}

class _ReportLocationScreenState extends State<ReportLocationScreen> {
  // ── location state ────────────────────────────────────────────────────────
  LatLng? _pickedLatLng;
  bool _isGeocoding = false;
  bool _geocodeFailed = false;

  // ── address fields (auto-filled via reverse geocoding) ────────────────────
  final _addressCtrl = TextEditingController();
  final _purokCtrl = TextEditingController();
  String? _selectedBarangay;
  final _cityCtrl = TextEditingController(text: 'Digos City');
  final _provinceCtrl = TextEditingController(text: 'Davao del Sur');

  // ── user-entered fields ───────────────────────────────────────────────────
  final _landmarkCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  String _severity = 'Medium';

  // ── map controller ────────────────────────────────────────────────────────
  final _mapController = MapController();
  bool _showMap = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _purokCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _landmarkCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  // ── reverse geocoding via Nominatim ──────────────────────────────────────
  Future<void> _reverseGeocode(LatLng latlng) async {
    setState(() {
      _isGeocoding = true;
      _geocodeFailed = false;
    });
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${latlng.latitude}&lon=${latlng.longitude}'
        '&format=json&addressdetails=1',
      );
      final resp = await http.get(url, headers: {
        'User-Agent': 'CivilWatchApp/1.0',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        // Build a readable street address
        final road = addr['road'] as String? ?? '';
        final suburb = addr['suburb'] as String? ?? '';
        final display = data['display_name'] as String? ?? '';
        final shortAddr = road.isNotEmpty
            ? road
            : (suburb.isNotEmpty ? suburb : display.split(',').first);

        // Purok / neighbourhood
        final purok = addr['neighbourhood'] as String? ??
            addr['hamlet'] as String? ??
            addr['quarter'] as String? ??
            '';

        // Barangay — try multiple OSM fields and pick the first that
        // matches the official Digos City list
        final barangayCandidates = [
          addr['village'] as String? ?? '',
          addr['suburb'] as String? ?? '',
          addr['quarter'] as String? ?? '',
          addr['city_district'] as String? ?? '',
        ];
        final barangay = barangayCandidates
            .map((c) => _matchBarangay(c))
            .firstWhere((m) => m != null, orElse: () => null);

        // City / municipality
        final city = addr['city'] as String? ??
            addr['town'] as String? ??
            addr['municipality'] as String? ??
            'Digos City';

        // Province / state
        final province = addr['province'] as String? ??
            addr['state'] as String? ??
            'Davao del Sur';

        setState(() {
          _addressCtrl.text = _toTitleCase(shortAddr);
          _purokCtrl.text = _toTitleCase(purok);
          // barangay is already matched to official list via _matchBarangay
          _selectedBarangay = barangay;
          _cityCtrl.text = _toTitleCase(city);
          _provinceCtrl.text = _toTitleCase(province);
          _geocodeFailed = false;
        });
      } else {
        setState(() => _geocodeFailed = true);
      }
    } catch (_) {
      setState(() => _geocodeFailed = true);
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  /// Fuzzy-match a raw geocoded barangay string to the official Digos City list.
  /// Returns the best match, or null if no reasonable match is found.
  String? _matchBarangay(String raw) {
    if (raw.isEmpty) return null;
    final q = raw.toLowerCase().trim();
    // Exact match first
    for (final b in _kDigosBarangays) {
      if (b.toLowerCase() == q) return b;
    }
    // Contains match (e.g. "Dawis Norte" → "Dawis")
    for (final b in _kDigosBarangays) {
      if (q.contains(b.toLowerCase()) || b.toLowerCase().contains(q)) return b;
    }
    return null; // no match — user picks from dropdown
  }

  /// Converts a string to Title Case — first letter of each word capitalized.
  static String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  void _useCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location services are disabled. Please enable GPS.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: AppColors.navy,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // ── Step 2: Check / request permission ────────────────────────────
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location permission denied. Tap the map to pick a location.',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              backgroundColor: const Color(0xFFF59E0B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location permission permanently denied. Enable it in app settings.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              textColor: AppColors.white,
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    // ── Step 3: Get real GPS coordinates ──────────────────────────────
    setState(() {
      _isGeocoding = true; // show spinner while getting position
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final latlng = LatLng(position.latitude, position.longitude);

      setState(() {
        _pickedLatLng = latlng;
        _showMap = true; // open map so user can see their position
      });

      // Move map camera to the real location
      _mapController.move(latlng, 16.0);

      // Reverse geocode the real coordinates
      await _reverseGeocode(latlng);
    } catch (e) {
      setState(() => _isGeocoding = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not get location. Try again or tap the map.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: AppColors.navy,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onMapTap(TapPosition _, LatLng latlng) async {
    setState(() => _pickedLatLng = latlng);
    await _reverseGeocode(latlng);
  }

  bool get _canProceed => _pickedLatLng != null;

  void _next() {
    if (!_canProceed) return;
    Navigator.pushNamed(context, AppRoutes.reportReview, arguments: {
      ...widget.reportData,
      'latitude': _pickedLatLng!.latitude,
      'longitude': _pickedLatLng!.longitude,
      'address': _addressCtrl.text.trim(),
      'purok': _purokCtrl.text.trim(),
      'barangay': (_selectedBarangay ?? '').isEmpty
          ? 'Unknown Barangay'
          : _selectedBarangay!,
      'city': _cityCtrl.text.trim(),
      'province': _provinceCtrl.text.trim(),
      'landmark': _landmarkCtrl.text.trim(),
      'additionalDetails': _detailsCtrl.text.trim(),
      'description': _detailsCtrl.text.trim(), // backward-compat
      'severity': _severity,
    });
  }

  @override
  Widget build(BuildContext context) {
    final category =
        widget.reportData['category'] as String? ?? 'Infrastructure';
    final catColor = AppHelpers.getCategoryColor(category);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CivilWatchAppBar(
        title: 'Report Concern',
        subtitle: 'Step 4 of 5',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: ReportStepper(currentStep: 3),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section header ────────────────────────────────────
                  _SectionLabel(
                    icon: Icons.location_on_rounded,
                    label: 'Report Location',
                    color: catColor,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Don't know the exact address? Just pick the spot on the map.",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Location action buttons ────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _LocationActionButton(
                          icon: Icons.my_location_rounded,
                          label: 'Use Current\nLocation',
                          color: AppColors.primary,
                          onTap: _useCurrentLocation,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LocationActionButton(
                          icon: Icons.map_rounded,
                          label: 'Pick Location\non Map',
                          color: AppColors.navy,
                          onTap: () =>
                              setState(() => _showMap = !_showMap),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Inline map ─────────────────────────────────────────
                  if (_showMap) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 260,
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _pickedLatLng ??
                                    const LatLng(
                                        _kDefaultLat, _kDefaultLng),
                                initialZoom: 15.0,
                                onTap: _onMapTap,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.civilwatch.app',
                                ),
                                if (_pickedLatLng != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _pickedLatLng!,
                                        width: 40,
                                        height: 40,
                                        child: GestureDetector(
                                          onPanUpdate: (d) {
                                            // basic drag simulation
                                          },
                                          child: const Icon(
                                            Icons.location_pin,
                                            color: Color(0xFFDC2626),
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            // Tap-to-select hint
                            if (_pickedLatLng == null)
                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Tap the map to place a marker',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Geocoding spinner overlay
                            if (_isGeocoding)
                              Container(
                                color: Colors.black.withOpacity(0.3),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Selected address card ──────────────────────────────
                  if (_pickedLatLng != null) ...[
                    _AddressCard(
                      isLoading: _isGeocoding,
                      geocodeFailed: _geocodeFailed,
                      addressCtrl: _addressCtrl,
                      purokCtrl: _purokCtrl,
                      selectedBarangay: _selectedBarangay,
                      onBarangayChanged: (val) =>
                          setState(() => _selectedBarangay = val),
                      cityCtrl: _cityCtrl,
                      provinceCtrl: _provinceCtrl,
                      catColor: catColor,
                    ),
                    const SizedBox(height: 8),
                    // Hint: address is auto-detected and editable
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 13, color: AppColors.textHint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Address is auto-detected and may not be 100% accurate. '
                            'Please verify and correct the Barangay and Purok fields if needed.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textHint,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Landmark ───────────────────────────────────────────
                  _SectionLabel(
                    icon: Icons.place_rounded,
                    label: 'Landmark (Optional)',
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _landmarkCtrl,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textPrimary),
                    decoration: _inputDecoration(
                      hintText:
                          'e.g. Near Barangay Hall, Near Church, Beside School',
                      prefixIcon: Icons.place_outlined,
                      catColor: catColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Additional details ─────────────────────────────────
                  _SectionLabel(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Additional Details (Optional)',
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Maximum 300 characters.',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _detailsCtrl,
                    maxLines: 4,
                    maxLength: 300,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textPrimary),
                    decoration: _inputDecoration(
                      hintText: 'Describe the concern in more detail...',
                      catColor: catColor,
                    ).copyWith(
                      alignLabelWithHint: true,
                      counterStyle: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textHint),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Severity ───────────────────────────────────────────
                  _SectionLabel(
                    icon: Icons.shield_outlined,
                    label: 'Severity',
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'How serious is this concern?',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SeverityChip(
                        label: 'Low',
                        color: const Color(0xFF16A34A),
                        isSelected: _severity == 'Low',
                        onTap: () => setState(() => _severity = 'Low'),
                      ),
                      const SizedBox(width: 10),
                      _SeverityChip(
                        label: 'Medium',
                        color: const Color(0xFFF59E0B),
                        isSelected: _severity == 'Medium',
                        onTap: () => setState(() => _severity = 'Medium'),
                      ),
                      const SizedBox(width: 10),
                      _SeverityChip(
                        label: 'High',
                        color: const Color(0xFFDC2626),
                        isSelected: _severity == 'High',
                        onTap: () => setState(() => _severity = 'High'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Bottom navigation ─────────────────────────────────────────
          _LocationNavBar(
            onNext: _canProceed ? _next : null,
            catColor: catColor,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    required Color catColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle:
          GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: AppColors.textHint, size: 20)
          : null,
      filled: true,
      fillColor: AppColors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: catColor, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location action button
// ─────────────────────────────────────────────────────────────────────────────

class _LocationActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LocationActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-filled address card
// ─────────────────────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final bool isLoading;
  final bool geocodeFailed;
  final TextEditingController addressCtrl;
  final TextEditingController purokCtrl;
  final String? selectedBarangay;
  final ValueChanged<String?> onBarangayChanged;
  final TextEditingController cityCtrl;
  final TextEditingController provinceCtrl;
  final Color catColor;

  const _AddressCard({
    required this.isLoading,
    required this.geocodeFailed,
    required this.addressCtrl,
    required this.purokCtrl,
    required this.selectedBarangay,
    required this.onBarangayChanged,
    required this.cityCtrl,
    required this.provinceCtrl,
    required this.catColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: geocodeFailed
              ? const Color(0xFFF59E0B)
              : AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Selected Address',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    if (geocodeFailed)
                      Text(
                        'Edit manually',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 12),
                _AddressField(
                    label: 'Street / Area', ctrl: addressCtrl),
                _AddressField(label: 'Purok', ctrl: purokCtrl),

                // ── Barangay dropdown (official Digos City list) ───────
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text(
                          'Barangay',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedBarangay != null
                                  ? AppColors.primary
                                  : AppColors.inputBorder,
                              width: selectedBarangay != null ? 1.5 : 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedBarangay,
                              hint: Text(
                                'Select barangay',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textHint,
                                ),
                              ),
                              isExpanded: true,
                              isDense: true,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              icon: const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: AppColors.textSecondary,
                              ),
                              onChanged: onBarangayChanged,
                              items: _kDigosBarangays
                                  .map((b) => DropdownMenuItem(
                                        value: b,
                                        child: Text(b),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                _AddressField(label: 'City', ctrl: cityCtrl),
                _AddressField(
                    label: 'Province',
                    ctrl: provinceCtrl,
                    isLast: true),
              ],
            ),
    );
  }
}

class _AddressField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool isLast;

  const _AddressField({
    required this.label,
    required this.ctrl,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.words,
              style:
                  GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Severity chip
// ─────────────────────────────────────────────────────────────────────────────

class _SeverityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SeverityChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                label == 'Low'
                    ? Icons.arrow_downward_rounded
                    : label == 'Medium'
                        ? Icons.remove_rounded
                        : Icons.arrow_upward_rounded,
                color: isSelected ? color : AppColors.textHint,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _LocationNavBar extends StatelessWidget {
  final VoidCallback? onNext;
  final Color catColor;

  const _LocationNavBar({this.onNext, required this.catColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onNext == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    'Please select a location to continue',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.divider),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        onNext != null ? catColor : AppColors.textDisabled,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: onNext != null ? 2 : 0,
                    shadowColor: catColor.withOpacity(0.3),
                    textStyle: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Next'),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
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
