import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

/// Shared HTTP client for all API calls.
///
/// - Automatically injects Bearer token from storage
/// - Parses JSON responses
/// - Throws [ApiException] on non-2xx responses
/// - On web (Chrome), flutter_secure_storage falls back to SharedPreferences
class ApiClient {
  ApiClient._();
  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  static const _tokenKey = 'cw_citizen_token';

  // ── Token storage ─────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> get hasToken async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  // ── GET ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> get(String url, {bool auth = true}) async {
    final headers = await _headers(auth);
    _log('GET', url);
    final response = await http.get(Uri.parse(url), headers: headers);
    return _parse(response);
  }

  // ── POST (JSON) ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final headers = await _headers(auth);
    headers['Content-Type'] = 'application/json';
    _log('POST', url, body: body);
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    return _parse(response);
  }

  // ── POST multipart (for photo uploads) ───────────────────────────────

  Future<Map<String, dynamic>> postMultipart(
    String url,
    Map<String, String> fields, {
    List<http.MultipartFile> files = const [],
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest('POST', Uri.parse(url));

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    request.fields.addAll(fields);
    request.files.addAll(files);

    _log('POST multipart', url, body: fields);
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _parse(response);
  }

  // ── DELETE ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> delete(String url) async {
    final headers = await _headers(true);
    _log('DELETE', url);
    final response = await http.delete(Uri.parse(url), headers: headers);
    return _parse(response);
  }

  // ── Private helpers ───────────────────────────────────────────────────

  Future<Map<String, String>> _headers(bool withAuth) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (withAuth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _parse(http.Response response) {
    _log('RESPONSE', response.request?.url.toString() ?? '',
        status: response.statusCode);

    final body = response.body.isEmpty ? '{}' : response.body;
    late Map<String, dynamic> json;

    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        message: 'Server returned invalid JSON.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    // Extract error message from Laravel's standard error shapes
    final message = json['message'] as String? ??
        _extractValidationError(json) ??
        'An error occurred (${response.statusCode})';

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }

  String? _extractValidationError(Map<String, dynamic> json) {
    final errors = json['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first as String;
    }
    return null;
  }

  void _log(String method, String url,
      {Map<String, dynamic>? body, int? status}) {
    if (kDebugMode) {
      final statusStr = status != null ? ' [$status]' : '';
      debugPrint('🌐 $method$statusStr $url');
      if (body != null) debugPrint('   body: $body');
    }
  }
}

// ── Exception ─────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? errors;

  const ApiException({
    required this.message,
    required this.statusCode,
    this.errors,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => statusCode == 422;
  bool get isNotFound => statusCode == 404;
  bool get isServer => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
