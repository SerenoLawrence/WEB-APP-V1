/// All API endpoint constants for the CivilWatch Laravel backend.
///
/// Base URL targets Flutter Web on Chrome — both Flutter and Laravel
/// run on the same machine so 127.0.0.1 works directly.
///
/// When testing on a real Android device on the same WiFi, change
/// baseUrl to http://10.10.10.87:8000/api  (your machine's local IP).
class ApiConstants {
  ApiConstants._();

  // ── Base ────────────────────────────────────────────────────────────────
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // ── Health ──────────────────────────────────────────────────────────────
  static const String ping = '$baseUrl/ping';

  // ── Mobile Auth ─────────────────────────────────────────────────────────
  static const String login     = '$baseUrl/mobile/auth/login';
  static const String sendOtp   = '$baseUrl/mobile/auth/send-otp';
  static const String verifyOtp = '$baseUrl/mobile/auth/verify-otp';
  static const String register  = '$baseUrl/mobile/auth/register';
  static const String logout    = '$baseUrl/mobile/auth/logout';
  static const String me        = '$baseUrl/mobile/auth/me';

  // ── Mobile Reports ───────────────────────────────────────────────────────
  static const String reports          = '$baseUrl/mobile/reports';
  static const String communityReports = '$baseUrl/mobile/reports/community';
  static String reportById(int id)     => '$baseUrl/mobile/reports/$id';

  // ── Mobile Notifications ─────────────────────────────────────────────────
  static const String notifications        = '$baseUrl/mobile/notifications';
  static const String markAllRead          = '$baseUrl/mobile/notifications/mark-all-read';
  static String markOneRead(int id)        => '$baseUrl/mobile/notifications/$id/read';

  // ── Mobile Announcements ─────────────────────────────────────────────────
  static const String announcements = '$baseUrl/mobile/announcements';

  // ── HTTP headers ──────────────────────────────────────────────────────────
  static Map<String, String> jsonHeaders([String? token]) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Map<String, String> authHeaders(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };
}
