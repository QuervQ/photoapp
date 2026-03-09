import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      userId: json['user_id'] as String,
      email: json['email'] as String,
    );
  }
}

class Room {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  const Room({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class InviteInfo {
  final String inviteCode;
  final DateTime expiresAt;

  const InviteInfo({required this.inviteCode, required this.expiresAt});

  factory InviteInfo.fromJson(Map<String, dynamic> json) {
    return InviteInfo(
      inviteCode: json['invite_code'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

class BackendApi {
  BackendApi({String? baseUrl})
    : _baseUri = Uri.parse(
        baseUrl ?? dotenv.env['BACKEND_BASE_URL'] ?? 'http://127.0.0.1:8080',
      );

  final Uri _baseUri;

  Future<AuthSession> signup({
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/signup', {
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(_asJsonMap(response.body));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(_asJsonMap(response.body));
  }

  Future<List<Room>> listRooms(String accessToken) async {
    final response = await _get('/rooms', accessToken: accessToken);
    final jsonList = _asJsonList(response.body);
    return jsonList
        .map((item) => Room.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Room> createRoom(String accessToken, String roomName) async {
    final response = await _post('/rooms', {
      'name': roomName,
    }, accessToken: accessToken);
    return Room.fromJson(_asJsonMap(response.body));
  }

  Future<String> joinRoom(String accessToken, String inviteCode) async {
    final response = await _post('/rooms/join', {
      'invite_code': inviteCode,
    }, accessToken: accessToken);
    final jsonMap = _asJsonMap(response.body);
    return jsonMap['room_id'] as String;
  }

  Future<InviteInfo> createInvite(String accessToken, String roomId) async {
    final response = await _post(
      '/rooms/$roomId/invite',
      const <String, dynamic>{},
      accessToken: accessToken,
    );
    return InviteInfo.fromJson(_asJsonMap(response.body));
  }

  Future<List<Map<String, dynamic>>> listPlacements(
    String accessToken,
    String roomId,
  ) async {
    final response = await _get(
      '/rooms/$roomId/placements',
      accessToken: accessToken,
    );
    final jsonList = _asJsonList(response.body);
    return jsonList.map((item) => item as Map<String, dynamic>).toList();
  }

  /// アセットのアップロード用署名付きURLを取得する
  Future<Map<String, dynamic>> createUploadUrl(
    String accessToken, {
    required String kind,
    required String contentType,
    required int byteSize,
  }) async {
    final response = await _post('/assets/upload-url', {
      'kind': kind,
      'content_type': contentType,
      'byte_size': byteSize,
    }, accessToken: accessToken);
    return _asJsonMap(response.body);
  }

  /// 署名付きURLにファイルをアップロードする
  Future<void> uploadFile(
    String uploadUrl,
    List<int> bytes,
    String contentType,
  ) async {
    final uri = Uri.parse(uploadUrl);
    final response = await http.put(
      uri,
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'file upload failed');
    }
  }

  /// アセットのダウンロード用署名付きURLを取得する
  Future<String> getDownloadUrl(String accessToken, String assetId) async {
    final response = await _get(
      '/assets/$assetId/download-url',
      accessToken: accessToken,
    );
    return (_asJsonMap(response.body))['download_url'] as String;
  }

  /// URLからバイトをダウンロードする
  Future<List<int>> downloadBytes(String url) async {
    final uri = Uri.parse(url);
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'download failed');
    }
    return response.bodyBytes;
  }

  /// ルームに配置を作成する
  Future<Map<String, dynamic>> createPlacement(
    String accessToken,
    String roomId, {
    required String imageAssetId,
    required List<double> transform,
    required double widthM,
    required double heightM,
  }) async {
    final response = await _post('/rooms/$roomId/placements', {
      'image_asset_id': imageAssetId,
      'transform': transform,
      'width_m': widthM,
      'height_m': heightM,
    }, accessToken: accessToken);
    return _asJsonMap(response.body);
  }

  /// ルームのWorldMapを設定する
  Future<Map<String, dynamic>> setWorldmap(
    String accessToken,
    String roomId, {
    required String assetId,
  }) async {
    final response = await _post('/rooms/$roomId/worldmap', {
      'asset_id': assetId,
    }, accessToken: accessToken);
    return _asJsonMap(response.body);
  }

  /// ルームの最新WorldMapを取得する
  Future<Map<String, dynamic>?> getWorldmap(
    String accessToken,
    String roomId,
  ) async {
    try {
      final response = await _get(
        '/rooms/$roomId/worldmap',
        accessToken: accessToken,
      );
      return _asJsonMap(response.body);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  WebSocketChannel connectRoomWs({
    required String accessToken,
    String? roomId,
  }) {
    final wsScheme = _baseUri.scheme == 'https' ? 'wss' : 'ws';
    final query = <String, String>{'token': accessToken};
    if (roomId != null && roomId.isNotEmpty) {
      query['room_id'] = roomId;
    }

    final wsUri = _baseUri.replace(
      scheme: wsScheme,
      path: '/ws',
      queryParameters: query,
    );

    return WebSocketChannel.connect(wsUri);
  }

  Future<http.Response> _get(String path, {String? accessToken}) async {
    final uri = _baseUri.replace(path: path);
    final response = await http
        .get(uri, headers: _headers(accessToken))
        .timeout(const Duration(seconds: 10));
    _throwIfError(response);
    return response;
  }

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final uri = _baseUri.replace(path: path);
    final response = await http
        .post(uri, headers: _headers(accessToken), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    _throwIfError(response);
    return response;
  }

  Map<String, String> _headers(String? accessToken) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final body = response.body.trim();
    throw ApiException(
      response.statusCode,
      body.isEmpty ? 'request failed' : body,
    );
  }

  Map<String, dynamic> _asJsonMap(String body) {
    final decoded = jsonDecode(body);
    return decoded as Map<String, dynamic>;
  }

  List<dynamic> _asJsonList(String body) {
    final decoded = jsonDecode(body);
    return decoded as List<dynamic>;
  }
}
