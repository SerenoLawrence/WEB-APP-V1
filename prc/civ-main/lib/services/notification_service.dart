import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/notification_model.dart';

/// Handles all notification API calls against the Laravel backend.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _api = ApiClient.instance;

  // ── Get Notifications ─────────────────────────────────────────────────────
  Future<({List<AppNotification> notifications, int unreadCount, String? error})>
      getNotifications() async {
    try {
      final res = await _api.get(ApiConstants.notifications, auth: true);
      final list = (res['data'] as List<dynamic>? ?? [])
          .map((e) => _parse(e as Map<String, dynamic>))
          .toList();
      final unread = (res['unreadCount'] as num?)?.toInt() ??
          list.where((n) => !n.isRead).length;
      return (notifications: list, unreadCount: unread, error: null);
    } on ApiException catch (e) {
      return (notifications: <AppNotification>[], unreadCount: 0, error: e.message);
    } catch (_) {
      return (notifications: <AppNotification>[], unreadCount: 0, error: 'Cannot reach server.');
    }
  }

  // ── Mark All Read ─────────────────────────────────────────────────────────
  Future<String?> markAllRead() async {
    try {
      await _api.post(ApiConstants.markAllRead, {}, auth: true);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Cannot reach server.';
    }
  }

  // ── Mark One Read ─────────────────────────────────────────────────────────
  Future<String?> markRead(int id) async {
    try {
      await _api.post(ApiConstants.markOneRead(id), {}, auth: true);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Cannot reach server.';
    }
  }

  // ── Parse API JSON → AppNotification ─────────────────────────────────────
  AppNotification _parse(Map<String, dynamic> d) {
    return AppNotification(
      id: d['id']?.toString() ?? '',
      title: d['title'] as String? ?? 'Notification',
      message: d['message'] as String? ?? '',
      referenceNumber: d['referenceNumber'] as String? ?? '',
      status: d['status'] as String? ?? '',
      timestamp: d['createdAt'] != null
          ? DateTime.tryParse(d['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isRead: d['isRead'] as bool? ?? false,
    );
  }
}
