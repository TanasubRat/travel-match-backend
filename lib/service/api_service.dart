// lib/service/api_service.dart
// - FlutterSecureStorage เก็บ JWT
// - ติด Authorization: Bearer <token> อัตโนมัติ
// - rawGet/rawPost/rawPut/rawPatch/rawDelete + error handling
// - ใช้งานกับหน้าปัจจุบัน: me(), deleteGroup(), leaveGroup(), setMyGroupId()
// - เรียก await api.init() หนึ่งครั้งตอนสตาร์ทแอป

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic body;
  ApiException(this.message, {this.statusCode, this.body});
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final String baseUrl; // เช่น http://10.0.2.2:3000 (Android emulator)
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final Duration timeout;
  final void Function()? onUnauthorized; // optional: callback ตอน 401

  static const _tokenKey = 'auth_token';
  String? _token; // in-memory cache
  final Set<String> favorites = {}; // Shared favorites across app

  ApiService({
    required this.baseUrl,
    http.Client? client,
    FlutterSecureStorage? secureStorage,
    this.timeout = const Duration(seconds: 20),
    this.onUnauthorized,
  })  : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // ---- AUTH TOKEN ----
  Future<void> init() async {
    _token = await _secureStorage.read(key: _tokenKey);
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    _token ??= await _secureStorage.read(key: _tokenKey);
    return _token;
  }

  Future<void> clearToken() async {
    _token = null;
    await _secureStorage.delete(key: _tokenKey);
  }

  Map<String, String> _headers({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final u = Uri.parse('$base$path');
    if (query == null || query.isEmpty) return u;
    return u.replace(queryParameters: {
      ...u.queryParameters,
      ...query.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    });
  }

  // ---- LOW-LEVEL HELPERS ----
  Future<dynamic> rawGet(String path,
      {Map<String, dynamic>? query, Map<String, String>? headers}) async {
    await getToken(); // ensure _token loaded
    final res = await _client
        .get(_uri(path, query), headers: _headers(extra: headers))
        .timeout(timeout);
    return _handleResponse(res);
  }

  Future<dynamic> rawPost(String path,
      {Object? body, Map<String, String>? headers}) async {
    await getToken();
    final uri = _uri(path);
    final h = _headers(extra: headers);
    late http.Response res;
    if (body == null) {
      res = await _client.post(uri, headers: h).timeout(timeout);
    } else {
      res = await _client
          .post(uri, headers: h, body: body is String ? body : jsonEncode(body))
          .timeout(timeout);
    }
    return _handleResponse(res);
  }

  Future<dynamic> rawPut(String path,
      {Object? body, Map<String, String>? headers}) async {
    await getToken();
    final uri = _uri(path);
    final h = _headers(extra: headers);
    late http.Response res;
    if (body == null) {
      res = await _client.put(uri, headers: h).timeout(timeout);
    } else {
      res = await _client
          .put(uri, headers: h, body: body is String ? body : jsonEncode(body))
          .timeout(timeout);
    }
    return _handleResponse(res);
  }

  Future<dynamic> rawPatch(String path,
      {Object? body, Map<String, String>? headers}) async {
    await getToken();
    final uri = _uri(path);
    final h = _headers(extra: headers);
    late http.Response res;
    if (body == null) {
      res = await _client.patch(uri, headers: h).timeout(timeout);
    } else {
      res = await _client
          .patch(uri,
              headers: h, body: body is String ? body : jsonEncode(body))
          .timeout(timeout);
    }
    return _handleResponse(res);
  }

  Future<dynamic> rawDelete(String path,
      {Object? body, Map<String, String>? headers}) async {
    await getToken();
    final req = http.Request('DELETE', _uri(path))
      ..headers.addAll(_headers(extra: headers));
    // บางเซิร์ฟเวอร์ไม่รับ body ใน DELETE → ใส่เฉพาะเมื่อจำเป็น
    if (body != null) {
      req.body = body is String ? body : jsonEncode(body);
    }
    final streamed = await _client.send(req).timeout(timeout);
    final res = await http.Response.fromStream(streamed);
    return _handleResponse(res);
  }

  dynamic _handleResponse(http.Response res) {
    dynamic data;
    try {
      data = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } catch (_) {
      data = res.body; // non-JSON
    }

    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Unauthorized',
          statusCode: res.statusCode, body: data);
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (data is Map && data['error'] is String)
          ? data['error']
          : 'HTTP ${res.statusCode}';
      throw ApiException(msg, statusCode: res.statusCode, body: data);
    }

    return data;
  }

  // ---- CONVENIENCE METHODS ----

  // Auth
  Future<void> login({required String email, required String password}) async {
    final resp = await rawPost('/api/auth/login', body: {
      'email': email.trim(),
      'password': password,
    });
    final token = (resp is Map) ? resp['token'] as String? : null;
    if (token == null) throw ApiException('Token missing in response');
    await setToken(token);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String? betaCode,
  }) async {
    final resp = await rawPost('/api/auth/register', body: {
      'email': email.trim(),
      'password': password,
      'displayName': displayName.trim(),
      if (betaCode != null) 'betaCode': betaCode,
    });
    final token = (resp is Map) ? resp['token'] as String? : null;
    if (token == null) throw ApiException('Token missing in response');
    await setToken(token);
  }

  /// คืน user object (รองรับทั้ง `{ user: {...} }` และ `{...}`)
  Future<Map<String, dynamic>?> me() async {
    dynamic resp;
    try {
      resp = await rawGet('/api/auth/me');
    } catch (_) {
      // เผื่อโปรเจ็กต์บางตัวใช้ /api/users/me
      resp = await rawGet('/api/users/me');
    }
    if (resp is Map && resp['user'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(resp['user']);
    }
    if (resp is Map<String, dynamic>) {
      return Map<String, dynamic>.from(resp);
    }
    return null;
  }

  // Groups
  Future<Map<String, dynamic>> createGroup({
    required String name,
    int? expiresInMinutes,
    int? maxMembers,
  }) async {
    final resp = await rawPost('/api/groups', body: {
      'name': name,
      if (expiresInMinutes != null) 'expiresInMinutes': expiresInMinutes,
      if (maxMembers != null) 'maxMembers': maxMembers,
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  Future<Map<String, dynamic>> previewGroupByCode(String code) async {
    final resp = await rawGet('/api/groups/code/$code');
    return Map<String, dynamic>.from(resp as Map);
  }

  /// Join group by join code (ตาม backend: POST /api/groups/join)
  /// backend ส่วนใหญ่จะอ่าน field ว่า joinCode หรือ code
  Future<Map<String, dynamic>> joinGroup({
    required String code,
  }) async {
    final resp = await rawPost('/api/groups/join', body: {
      'joinCode': code,
      'code': code, // เผื่อ backend ใช้ชื่อ field คนละแบบ
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  /// Start group session (มีใน backend: POST /api/groups/:id/start)
  Future<Map<String, dynamic>> startGroupSession(String groupId) async {
    final resp = await rawPost('/api/groups/$groupId/start');
    return Map<String, dynamic>.from(resp as Map);
  }

  /// Confirm final place (POST /api/groups/:id/confirm)
  Future<Map<String, dynamic>> confirmFinalPlace({
    required String groupId,
    required String placeId,
  }) async {
    final resp = await rawPost('/api/groups/$groupId/confirm', body: {
      'placeId': placeId,
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  // Invite friend by email
  Future<void> inviteFriend(String email) async {
    await rawPost('/api/groups/invite', body: {'email': email});
  }

  // Swipes
  Future<void> saveSwipe({
    required String groupId,
    required String placeId,
    required bool liked,
  }) async {
    await rawPost('/api/swipes', body: {
      'groupId': groupId,
      'placeId': placeId,
      'liked': liked,
    });
  }

  // --- Group detail ---
  Future<Map<String, dynamic>> getGroup(String groupId) async {
    final resp = await rawGet('/api/groups/$groupId');
    return Map<String, dynamic>.from(resp as Map);
  }

  // สร้าง group พร้อม city + filters (ใช้ใน TripCreationScreen)
  Future<Map<String, dynamic>> createGroupWithFilters({
    required String name,
    required String city,
    Map<String, dynamic>? filters,
    int? maxMembers,
  }) async {
    final resp = await rawPost('/api/groups', body: {
      'name': name,
      'city': city,
      if (maxMembers != null) 'maxMembers': maxMembers,
      if (filters != null) 'filters': filters,
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  // เข้าร่วมห้องด้วย joinCode อย่างเดียว (ตาม activity diagram)
  Future<Map<String, dynamic>> joinGroupByCode(String joinCode) async {
    final resp = await rawPost('/api/groups/join', body: {
      'joinCode': joinCode,
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  // ดึงผล match แบบเต็ม (ใช้ใน ResultsScreen)
  Future<Map<String, dynamic>> getGroupMatch(String groupId) async {
    final resp = await rawGet('/api/groups/$groupId/match');
    if (resp is Map<String, dynamic>) return resp;
    if (resp is List) {
      return {
        'hasMatch': (resp as List).isNotEmpty,
        'matches': resp,
      };
    }
    throw ApiException('Unexpected match response format');
  }

  // ---- GROUP HELPERS ----
  void close() => _client.close();

  Future<void> deleteGroup(String groupId) async {
    await rawDelete('/api/groups/$groupId');
  }

  Future<void> leaveGroup(String groupId) async {
    // ส่ง body ว่าง ป้องกันเซิร์ฟเวอร์บางตัวตอบ 415
    await rawPost('/api/groups/$groupId/leave', body: const {});
  }

  /// เคลียร์/ตั้ง groupId ฝั่ง server:
  /// - พยายาม PATCH /api/users/me ก่อน
  /// - ถ้าไม่มี endpoint นั้น ลอง /api/auth/me
  /// - ถ้ายังไม่มีก็เงียบ ๆ (ไม่ให้แอปล่ม)
  Future<void> setMyGroupId(String? groupId) async {
    try {
      await rawPatch('/api/users/me', body: {'groupId': groupId});
    } catch (_) {
      try {
        await rawPatch('/api/auth/me', body: {'groupId': groupId});
      } catch (_) {
        // ไม่มี endpoint นี้ในโปรเจ็กต์ก็ปล่อยผ่าน
      }
    }
  }

  // --- Compatibility helpers ---
  Future<void> loadToken() => init();
  Future<void> logout() => clearToken();
  Future<List<dynamic>> getPlaces({
    required String location,
    List<String>? types,
    double? minRating,
    int? priceLevel,
    double? maxDistanceKm,
    bool? openNow,
  }) async {
    final query = {
      'location': location,
      if (types != null && types.isNotEmpty) 'type': types.join(','),
      if (minRating != null) 'minRating': minRating.toString(),
      if (priceLevel != null) 'priceLevel': priceLevel.toString(),
      if (maxDistanceKm != null) 'maxDistanceKm': maxDistanceKm.toString(),
      if (openNow != null) 'openNow': openNow.toString(),
    };
    final resp = await rawGet('/api/places', query: query);
    return (resp as List).toList();
  }

  // Helper for CORS proxy images on Web
  String getProxyImageUrl(String originalUrl) {
    // Always use proxy to avoid Referer/CORS issues with Google Maps images
    if (originalUrl.isEmpty) return '';
    final encoded = Uri.encodeComponent(originalUrl);
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$base/api/proxy/image?url=$encoded';
  }
}

// ===== Global ApiService access =====

// instance กลางสำหรับใช้ใน screens ทั้งหมด
ApiService? _globalApi;

/// เรียกตอนเริ่มแอป (เช่นใน main.dart) หลังสร้าง ApiService แล้ว
void registerApiService(ApiService api) {
  _globalApi = api;
}

/// ใช้ในหน้าต่าง ๆ แทนการ new ApiService ซ้ำ
ApiService get globalApi {
  final api = _globalApi;
  if (api == null) {
    throw StateError(
      'Global ApiService is not initialized. Call registerApiService(api) in main.dart before runApp().',
    );
  }
  return api;
}
