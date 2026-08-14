import 'package:flutter/material.dart';
import '../../models/report.dart';
import '../../models/notification_model.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../services/notification_service.dart';
import '../../services/announcement_service.dart';
import '../utils/dummy_data.dart';
import '../utils/helpers.dart';

/// Central app state — ChangeNotifier singleton.
///
/// Data sources:
///   - When logged in:  real API data from Laravel backend
///   - When guest:      community reports from API (public endpoint)
///   - Fallback:        DummyData (if API is unreachable)
class AppState extends ChangeNotifier {

  // ── Singleton ─────────────────────────────────────────────────────────────
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // ── Services ──────────────────────────────────────────────────────────────
  final _auth      = AuthService.instance;
  final _reportSvc = ReportService.instance;
  final _notifSvc  = NotificationService.instance;
  final _annSvc    = AnnouncementService.instance;

  // ── Init — called once from main.dart ─────────────────────────────────────
  bool _initialized = false;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Always load community reports (public endpoint — no auth needed)
    await _loadCommunityReports();

    // Try to restore session from saved token
    final user = await _auth.restoreSession();
    if (user != null) {
      _currentUser = user;
      _isGuest = false;
      await Future.wait([
        _loadMyReports(),
        _loadNotifications(),
        _loadAnnouncements(),
      ]);
    } else {
      // Not logged in — seed personal data with dummy fallback
      _reports = List.from(DummyData.myReports);
      _notifications = List.from(DummyData.notifications);
    }
    notifyListeners();
  }

  // ── Auth / session ────────────────────────────────────────────────────────
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  bool _isGuest = false;
  bool get isGuest => _isGuest;

  void enterAsGuest() {
    _isGuest = true;
    notifyListeners();
  }

  void exitGuest() {
    _isGuest = false;
    notifyListeners();
  }

  /// Called after successful login/register from auth screens.
  Future<void> onLoginSuccess(AppUser user) async {
    _currentUser = user;
    _isGuest = false;
    await _loadAllData();
    notifyListeners();
  }

  /// Called on logout.
  Future<void> logout() async {
    await _auth.logout();
    _currentUser = null;
    _reports = List.from(DummyData.myReports);
    _notifications = List.from(DummyData.notifications);
    // Community reports stay loaded (public data)
    notifyListeners();
  }

  // ── Load all data from API ────────────────────────────────────────────────
  Future<void> _loadAllData() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      _loadMyReports(),
      _loadCommunityReports(),
      _loadNotifications(),
      _loadAnnouncements(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  /// Reload everything — call this to refresh (e.g. pull-to-refresh).
  Future<void> refresh() => _loadAllData();

  // ── Reports ───────────────────────────────────────────────────────────────
  List<IncidentReport> _reports = [];
  List<IncidentReport> _communityReports = [];

  List<IncidentReport> get reports => List.unmodifiable(_reports);
  List<IncidentReport> get communityReportsPublic =>
      List.unmodifiable(_communityReports);

  Future<void> _loadMyReports() async {
    final result = await _reportSvc.getMyReports();
    if (result.error == null) {
      _reports = result.reports;
    } else {
      // Fallback to dummy data if API fails
      if (_reports.isEmpty) _reports = List.from(DummyData.myReports);
    }
  }

  Future<void> _loadCommunityReports() async {
    final result = await _reportSvc.getCommunityReports();
    if (result.error == null) {
      _communityReports = result.reports;
    } else {
      // Fallback to dummy data if API is unreachable
      if (_communityReports.isEmpty) {
        _communityReports = List.from(DummyData.communityReports);
      }
    }
    notifyListeners();
  }

  /// Submit a report — calls API then reloads list on success.
  Future<({bool success, IncidentReport? report, String? error})>
      submitReport(Map<String, dynamic> data) async {
    final result = await _reportSvc.submitReport(data);
    if (result.error == null && result.report != null) {
      _reports.insert(0, result.report!);
      _addSubmissionNotifications(result.report!);
      notifyListeners();
    }
    return (
      success: result.error == null && result.report != null,
      report: result.report,
      error: result.error,
    );
  }

  /// Fetch a fresh copy of a single report from API.
  Future<IncidentReport?> fetchReport(String id) async {
    final idInt = int.tryParse(id);
    if (idInt == null) return getById(id);
    final result = await _reportSvc.getReportById(idInt);
    if (result.report != null) {
      final idx = _reports.indexWhere((r) => r.id == id);
      if (idx != -1) {
        _reports[idx] = result.report!;
        notifyListeners();
      }
      return result.report;
    }
    return getById(id);
  }

  /// Look up by ID across both lists (local cache).
  IncidentReport? getById(String id) {
    try { return _reports.firstWhere((r) => r.id == id); } catch (_) {}
    try { return _communityReports.firstWhere((r) => r.id == id); } catch (_) {
      return null;
    }
  }

  /// Look up by reference number (case-insensitive).
  IncidentReport? getByReference(String refNumber) {
    final q = refNumber.trim().toUpperCase();
    try {
      return _reports.firstWhere((r) => r.referenceNumber.toUpperCase() == q);
    } catch (_) {}
    try {
      return _communityReports.firstWhere(
          (r) => r.referenceNumber.toUpperCase() == q);
    } catch (_) { return null; }
  }

  // ── Announcements ─────────────────────────────────────────────────────────
  List<Announcement> _announcements = [];
  List<Announcement> get announcements => List.unmodifiable(_announcements);

  Future<void> _loadAnnouncements() async {
    final result = await _annSvc.getAnnouncements();
    if (result.error == null) {
      _announcements = result.announcements;
    } else {
      if (_announcements.isEmpty) {
        _announcements = List.from(DummyData.announcements);
      }
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;

  Future<void> _loadNotifications() async {
    final result = await _notifSvc.getNotifications();
    if (result.error == null) {
      _notifications = result.notifications;
      _unreadCount = result.unreadCount;
    } else {
      if (_notifications.isEmpty) {
        _notifications = List.from(DummyData.notifications);
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      }
    }
  }

  Future<void> markAllRead() async {
    await _notifSvc.markAllRead();
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    final idInt = int.tryParse(id);
    if (idInt != null) await _notifSvc.markRead(idInt);
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  // ── Local report manipulation (kept for optimistic UI updates) ────────────
  void addReport(IncidentReport report) {
    _reports.insert(0, report);
    _addSubmissionNotifications(report);
    notifyListeners();
  }

  void updateStatus(String reportId, String newStatus) {
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx == -1) return;
    final report = _reports[idx];
    final newLog = List<ActivityEntry>.from(report.activityLog)
      ..add(ActivityEntry(
        title: newStatus,
        description: _statusDescription(newStatus),
        timestamp: DateTime.now(),
        status: newStatus,
      ));
    _reports[idx] = report.copyWith(
      status: newStatus,
      activityLog: newLog,
      resolvedAt: newStatus == 'Resolved' ? DateTime.now() : report.resolvedAt,
    );
    _notifications.insert(0, AppNotification(
      id: 'n-${DateTime.now().millisecondsSinceEpoch}',
      title: newStatus,
      message: '${report.referenceNumber} — ${_statusDescription(newStatus)}',
      referenceNumber: report.referenceNumber,
      status: newStatus,
      timestamp: DateTime.now(),
      isRead: false,
    ));
    _unreadCount++;
    notifyListeners();
  }

  // ── Summary counts ────────────────────────────────────────────────────────
  int get pendingCount   => _reports.where((r) => r.isPending).length;
  int get inProgressCount => _reports.where((r) => r.status == 'In Progress').length;
  int get resolvedCount  => _reports.where((r) => r.status == 'Resolved').length;
  int get totalCount     => _reports.length;

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _addSubmissionNotifications(IncidentReport report) {
    final now = DateTime.now();
    _notifications.insertAll(0, [
      AppNotification(
        id: 'n-${now.millisecondsSinceEpoch}-b',
        title: 'Pending Validation',
        message: '${report.referenceNumber} is now under review.',
        referenceNumber: report.referenceNumber,
        status: 'Pending Validation',
        timestamp: now.add(const Duration(minutes: 1)),
        isRead: false,
      ),
      AppNotification(
        id: 'n-${now.millisecondsSinceEpoch}-a',
        title: 'Concern Submitted',
        message: 'Your concern ${report.referenceNumber} was submitted.',
        referenceNumber: report.referenceNumber,
        status: 'Submitted',
        timestamp: now,
        isRead: false,
      ),
    ]);
    _unreadCount += 2;
  }

  String _statusDescription(String status) {
    switch (status) {
      case 'Pending Validation': return 'Your report is now waiting for validation.';
      case 'Assigned to Office': return 'Assigned to the appropriate government office.';
      case 'In Progress':        return 'Work is currently in progress.';
      case 'Resolved':           return 'The issue has been successfully resolved.';
      default:                   return 'Status updated.';
    }
  }

  static IncidentReport buildFromFormData(Map<String, dynamic> data) {
    final now = DateTime.now();
    final issue = data['concern'] as String? ?? data['issue'] as String? ?? 'Others';
    final description = data['additionalDetails'] as String? ?? data['description'] as String? ?? '';
    final barangay = data['barangay'] as String? ?? 'Unknown Barangay';
    final severity = AppHelpers.normaliseSeverity(data['severity'] as String? ?? 'Medium');
    final lat = (data['latitude'] as num?)?.toDouble() ?? 6.7498;
    final lng = (data['longitude'] as num?)?.toDouble() ?? 125.3572;

    return IncidentReport(
      id: 'r-${now.millisecondsSinceEpoch}',
      referenceNumber: data['referenceNumber'] as String? ?? AppHelpers.generateRefNumber(),
      category: data['category'] as String? ?? 'Infrastructure',
      issue: issue,
      description: description,
      barangay: barangay,
      status: 'Pending Validation',
      severity: severity,
      submittedAt: now,
      imageUrl: null,
      latitude: lat,
      longitude: lng,
      assignedOffice: null,
      activityLog: [
        ActivityEntry(title: 'Concern Submitted', description: 'Your concern has been successfully submitted.', timestamp: now, status: 'Submitted'),
        ActivityEntry(title: 'Pending Validation', description: 'Your concern is now waiting for validation.', timestamp: now.add(const Duration(minutes: 1)), status: 'Pending Validation'),
      ],
    );
  }
}
