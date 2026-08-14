import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/report.dart';

/// Handles all report API calls against the Laravel backend.
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final _api = ApiClient.instance;

  // ── My Reports ────────────────────────────────────────────────────────────
  Future<({List<IncidentReport> reports, String? error})> getMyReports({
    String? status,
  }) async {
    try {
      final url = status != null
          ? '${ApiConstants.reports}?status=${Uri.encodeComponent(status)}'
          : ApiConstants.reports;

      final res = await _api.get(url, auth: true);
      final list = (res['data'] as List<dynamic>? ?? [])
          .map((e) => _parseReport(e as Map<String, dynamic>))
          .toList();
      return (reports: list, error: null);
    } on ApiException catch (e) {
      return (reports: <IncidentReport>[], error: e.message);
    } catch (_) {
      return (reports: <IncidentReport>[], error: 'Cannot reach server.');
    }
  }

  // ── Single Report ─────────────────────────────────────────────────────────
  Future<({IncidentReport? report, String? error})> getReportById(
      int id) async {
    try {
      final res = await _api.get(ApiConstants.reportById(id), auth: true);
      return (report: _parseReport(res['data'] as Map<String, dynamic>), error: null);
    } on ApiException catch (e) {
      return (report: null, error: e.message);
    } catch (_) {
      return (report: null, error: 'Cannot reach server.');
    }
  }

  // ── Community Map Reports ─────────────────────────────────────────────────
  Future<({List<IncidentReport> reports, String? error})>
      getCommunityReports() async {
    try {
      final res = await _api.get(ApiConstants.communityReports, auth: false);
      final list = (res['data'] as List<dynamic>? ?? [])
          .map((e) => _parseReport(e as Map<String, dynamic>))
          .toList();
      return (reports: list, error: null);
    } on ApiException catch (e) {
      return (reports: <IncidentReport>[], error: e.message);
    } catch (_) {
      return (reports: <IncidentReport>[], error: 'Cannot reach server.');
    }
  }

  // ── Submit Report ─────────────────────────────────────────────────────────
  /// Sends report data as multipart form (supports photo upload).
  Future<({IncidentReport? report, String? error})> submitReport(
      Map<String, dynamic> data) async {
    try {
      // Build string fields for multipart
      final fields = <String, String>{
        'category':    data['category']?.toString() ?? 'Infrastructure',
        'concern':     (data['concern'] ?? data['issue'] ?? '').toString(),
        'description': (data['additionalDetails'] ?? data['description'] ?? '').toString(),
        'barangay':    (data['barangay'] ?? '').toString(),
        'city':        'Digos City',
        'province':    'Davao del Sur',
        'severity':    (data['severity'] ?? 'Moderate').toString(),
        if (data['landmark'] != null)
          'landmark': data['landmark'].toString(),
        if (data['purok'] != null)
          'purok': data['purok'].toString(),
        if (data['latitude'] != null)
          'lat': data['latitude'].toString(),
        if (data['longitude'] != null)
          'lng': data['longitude'].toString(),
      };

      final res = await _api.postMultipart(
        ApiConstants.reports,
        fields,
        // Photo file support will be added when image_picker is wired
        // files: data['photo'] != null ? [await _buildPhotoFile(data['photo'])] : [],
      );

      return (
        report: _parseReport(res['data'] as Map<String, dynamic>),
        error: null,
      );
    } on ApiException catch (e) {
      return (report: null, error: e.message);
    } catch (_) {
      return (report: null, error: 'Cannot reach server.');
    }
  }

  // ── Parse API JSON → IncidentReport ───────────────────────────────────────
  IncidentReport _parseReport(Map<String, dynamic> d) {
    final activityLog = (d['activityLog'] as List<dynamic>? ?? [])
        .map((e) => _parseActivity(e as Map<String, dynamic>))
        .toList();

    return IncidentReport(
      id: d['id']?.toString() ?? '',
      referenceNumber: d['referenceNumber'] as String? ?? '',
      category: d['category'] as String? ?? 'Infrastructure',
      issue: d['issue'] as String? ?? d['concern'] as String? ?? '',
      description: d['description'] as String? ?? '',
      barangay: d['barangay'] as String? ?? '',
      status: d['status'] as String? ?? 'Submitted',
      severity: d['severity'] as String? ?? 'Moderate',
      submittedAt: d['submittedAt'] != null
          ? DateTime.tryParse(d['submittedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: d['resolvedAt'] != null
          ? DateTime.tryParse(d['resolvedAt'] as String)
          : null,
      imageUrl: d['imageUrl'] as String?,
      afterImageUrl: d['afterImageUrl'] as String?,
      latitude: (d['latitude'] as num?)?.toDouble() ?? 6.7498,
      longitude: (d['longitude'] as num?)?.toDouble() ?? 125.3572,
      assignedOffice: d['assignedOffice'] as String?,
      activityLog: activityLog,
    );
  }

  ActivityEntry _parseActivity(Map<String, dynamic> d) {
    return ActivityEntry(
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      timestamp: d['timestamp'] != null
          ? DateTime.tryParse(d['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: d['status'] as String? ?? '',
    );
  }
}
