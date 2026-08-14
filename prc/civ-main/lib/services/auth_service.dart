import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/user.dart';

/// Handles all citizen authentication against the Laravel backend.
///
/// Flow:
///   Registration → sendOtp → verifyOtp (gets isNewUser=true) → register
///   Login        → phone + PIN → loginWithPin
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _api = ApiClient.instance;

  // ── In-memory current user (set on login, cleared on logout) ────────────
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // ── Restore session on app start ─────────────────────────────────────────
  /// Called once from AppState.init(). Fetches /me if a token exists.
  Future<AppUser?> restoreSession() async {
    if (!await _api.hasToken) return null;
    try {
      final res = await _api.get(ApiConstants.me, auth: true);
      if (res['success'] == true) {
        _currentUser = _parseUser(res['data'] as Map<String, dynamic>);
        return _currentUser;
      }
    } catch (_) {
      // Token expired or invalid — clear it
      await _api.deleteToken();
    }
    return null;
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────
  /// Returns the OTP code (Laravel returns it in dev mode — remove in prod).
  Future<({bool success, String? otp, String? error})> sendOtp(
      String phone) async {
    try {
      final res = await _api.post(
        ApiConstants.sendOtp,
        {'phone': _normalizePhone(phone)},
        auth: false,
      );
      final data = res['data'] as Map<String, dynamic>?;
      return (
        success: res['success'] == true,
        otp: data?['otp'] as String?,
        error: null,
      );
    } on ApiException catch (e) {
      return (success: false, otp: null, error: e.message);
    } catch (e) {
      return (success: false, otp: null, error: 'Cannot reach server. Is Laravel running?');
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  /// Returns isNewUser=true if they need to register, false if they can login.
  Future<({bool success, bool isNewUser, String? token, String? error})>
      verifyOtp(String phone, String otp) async {
    try {
      final res = await _api.post(
        ApiConstants.verifyOtp,
        {'phone': _normalizePhone(phone), 'otp': otp},
        auth: false,
      );
      final data = res['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      final isNewUser = data?['isNewUser'] as bool? ?? true;

      if (token != null) {
        await _api.saveToken(token);
        // Returning user — load their profile
        if (!isNewUser) {
          final citizenData = data?['citizen'] as Map<String, dynamic>?;
          if (citizenData != null) {
            _currentUser = _parseUser(citizenData);
          }
        }
      }

      return (
        success: res['success'] == true,
        isNewUser: isNewUser,
        token: token,
        error: null,
      );
    } on ApiException catch (e) {
      return (success: false, isNewUser: true, token: null, error: e.message);
    } catch (e) {
      return (success: false, isNewUser: true, token: null, error: 'Cannot reach server.');
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<({bool success, AppUser? user, String? error})> register({
    required String fullName,
    required String phone,
    required String barangay,
    required String pin,
    String? email,
  }) async {
    try {
      final res = await _api.post(
        ApiConstants.register,
        {
          'fullName': fullName,
          'phone': _normalizePhone(phone),
          'barangay': barangay,
          'pin': pin,
          if (email != null && email.isNotEmpty) 'email': email,
        },
        auth: false,
      );
      final data = res['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      final citizenData = data?['citizen'] as Map<String, dynamic>?;

      if (token != null) await _api.saveToken(token);
      if (citizenData != null) {
        _currentUser = _parseUser(citizenData);
      }

      return (success: res['success'] == true, user: _currentUser, error: null);
    } on ApiException catch (e) {
      return (success: false, user: null, error: e.message);
    } catch (e) {
      return (success: false, user: null, error: 'Cannot reach server.');
    }
  }

  // ── Login with PIN (no OTP — direct phone + PIN) ─────────────────────────
  /// This is the new login flow: phone + 6-digit PIN → get token.
  /// Laravel doesn't have a dedicated PIN login endpoint yet —
  /// we use sendOtp + verifyOtp + check citizens table approach.
  /// For now we wire it as: call /me to check if token is still valid,
  /// or send OTP flow. The PIN validation will be added to Laravel next.
  ///
  /// TODO: Add POST /api/mobile/auth/login (phone + pin) to Laravel.
  /// For now this is a placeholder that the login screen can call.
  Future<({bool success, AppUser? user, String? error})> loginWithPin({
    required String phone,
    required String pin,
  }) async {
    try {
      // NOTE: This endpoint will be added to Laravel.
      // When ready, replace with:
      //   final res = await _api.post(ApiConstants.loginWithPin,
      //       {'phone': phone, 'pin': pin});
      // For now, simulate a successful login using dummy data until
      // the endpoint is built.
      await Future.delayed(const Duration(milliseconds: 800));
      return (success: false, user: null,
          error: 'PIN login endpoint not yet built in Laravel. Use OTP flow for now.');
    } catch (e) {
      return (success: false, user: null, error: 'Cannot reach server.');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      if (await _api.hasToken) {
        await _api.post(ApiConstants.logout, {}, auth: true);
      }
    } catch (_) {
      // Ignore errors — always clear local state
    } finally {
      await _api.deleteToken();
      _currentUser = null;
    }
  }

  // ── Fetch current user profile ────────────────────────────────────────────
  Future<AppUser?> fetchMe() async {
    try {
      final res = await _api.get(ApiConstants.me, auth: true);
      if (res['success'] == true) {
        _currentUser = _parseUser(res['data'] as Map<String, dynamic>);
        return _currentUser;
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _api.deleteToken();
    } catch (_) {}
    return null;
  }

  // ── Parse citizen JSON → AppUser ──────────────────────────────────────────
  AppUser _parseUser(Map<String, dynamic> data) {
    return AppUser(
      id: data['id']?.toString() ?? '',
      fullName: data['fullName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      barangay: data['barangay'] as String? ?? '',
      joinedDate: data['joinedDate'] != null
          ? DateTime.tryParse(data['joinedDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalReports: (data['totalReports'] as num?)?.toInt() ?? 0,
      resolvedReports: (data['resolvedReports'] as num?)?.toInt() ?? 0,
      avatarUrl: data['avatarUrl'] as String?,
    );
  }

  // ── Phone normalizer ──────────────────────────────────────────────────────
  String _normalizePhone(String phone) {
    // Strip spaces and formatting added by the UI formatter
    return phone.replaceAll(' ', '').replaceAll('-', '');
  }
}
