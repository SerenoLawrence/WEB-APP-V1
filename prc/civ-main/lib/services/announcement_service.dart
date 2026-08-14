import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/utils/dummy_data.dart';

/// Fetches city announcements from Laravel.
/// No auth required — public endpoint.
class AnnouncementService {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  final _api = ApiClient.instance;

  Future<({List<Announcement> announcements, String? error})>
      getAnnouncements() async {
    try {
      final res = await _api.get(ApiConstants.announcements, auth: false);
      final list = (res['data'] as List<dynamic>? ?? [])
          .map((e) => _parse(e as Map<String, dynamic>))
          .toList();
      return (announcements: list, error: null);
    } catch (_) {
      return (announcements: <Announcement>[], error: 'Cannot reach server.');
    }
  }

  Announcement _parse(Map<String, dynamic> d) {
    return Announcement(
      id: d['id']?.toString() ?? '',
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      date: d['publishedAt'] != null
          ? DateTime.tryParse(d['publishedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
