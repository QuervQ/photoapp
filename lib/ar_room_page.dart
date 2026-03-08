import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'backend_api.dart';

/// AR ルーム画面
///
/// 1. 画像を選択＆バックエンドにアップロード
/// 2. ARを開いて壁に配置（WorldMap復元による永続化対応）
/// 3. 配置データをサーバーに保存 + WS経由でリアルタイム同期
/// 4. 他ユーザーの配置をAR空間にリアルタイム描画
class ArRoomPage extends StatefulWidget {
  final BackendApi api;
  final AuthSession session;
  final String roomId;
  final String roomName;

  const ArRoomPage({
    super.key,
    required this.api,
    required this.session,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<ArRoomPage> createState() => _ArRoomPageState();
}

class _ArRoomPageState extends State<ArRoomPage> {
  static const _channel = MethodChannel('dev.quervq.photoapp/swift');

  String? _uploadedAssetId;
  String? _selectedImagePath;
  bool _isUploading = false;
  bool _arOpen = false;
  bool _isLoadingAr = false;
  final List<String> _events = [];

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;

  /// ダウンロード済みWorldMapデータ（AR起動時にSwiftに渡す）
  Uint8List? _worldMapData;

  /// 既存配置リスト（AR起動後にSwiftに送る）
  List<Map<String, dynamic>> _existingPlacements = [];

  /// 画像ダウンロードのキャッシュ（asset_id → ローカルパス）
  final Map<String, String> _imageCache = {};

  /// リローカライゼーション完了を待つCompleter（WorldMapありの場合のみ使用）
  Completer<bool>? _relocalizationCompleter;

  /// リローカライゼーション済みフラグ
  bool _isRelocalized = false;

  /// リローカライゼーション待ち中にWSで受信した配置をバッファリング
  final List<Map<String, dynamic>> _pendingRemotePlacements = [];

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeCall);
    _connectWs();
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_wsSub?.cancel());
    unawaited(_wsChannel?.sink.close());
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // WebSocket
  // ---------------------------------------------------------------------------

  void _connectWs() {
    _wsChannel = widget.api.connectRoomWs(
      accessToken: widget.session.accessToken,
      roomId: widget.roomId,
    );

    _wsSub = _wsChannel!.stream.listen(
      (event) {
        final text = event.toString();
        _addEvent('WS: $text');
        _handleWsEvent(text);
      },
      onError: (error) {
        _addEvent('WS エラー: $error');
      },
      onDone: () {
        _addEvent('WS 切断');
      },
    );
  }

  void _handleWsEvent(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type'];
      if (type == 'placement_created') {
        final placement = decoded['placement'] as Map<String, dynamic>?;
        if (placement == null) return;
        final createdBy = placement['created_by'] as String? ?? '';
        if (createdBy != widget.session.userId) {
          _addEvent('🆕 他ユーザーが配置を追加しました');
          if (_arOpen && (_isRelocalized || _worldMapData == null)) {
            // AR表示中 かつ リローカライゼーション済み → 即時描画
            _addRemotePlacementToAr(placement);
          } else if (_arOpen) {
            // AR表示中だがリローカライゼーション待ち → バッファに溜める
            _pendingRemotePlacements.add(placement);
            _addEvent('⏳ リローカライゼーション待ちのためバッファに追加');
          }
        }
      } else if (type == 'worldmap_updated') {
        _addEvent('🗺️ ワールドマップが更新されました');
      }
    } catch (_) {}
  }

  /// リモート配置をAR空間に追加する
  Future<void> _addRemotePlacementToAr(Map<String, dynamic> placement) async {
    try {
      final assetId = placement['image_asset_id'] as String;
      final transform = (placement['transform'] as List).cast<double>();
      final widthM = (placement['width_m'] as num).toDouble();
      final heightM = (placement['height_m'] as num).toDouble();

      // 画像ダウンロード
      final localPath = await _downloadImage(
        assetId,
        downloadUrl: placement['image_download_url'] as String?,
      );

      // Swiftに送信
      await _channel.invokeMethod('addRemotePlacement', {
        'transform': transform,
        'width_m': widthM,
        'height_m': heightM,
        'image_path': localPath,
      });

      _addEvent('📨 リモート配置をAR表示');
    } catch (e) {
      _addEvent('⚠️ リモート配置表示エラー: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MethodChannel (Swift → Flutter)
  // ---------------------------------------------------------------------------

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPlacementCreated':
        await _onNativePlacementCreated(
          Map<String, dynamic>.from(call.arguments as Map),
        );
        break;
      case 'onArDismissed':
        if (mounted) {
          setState(() => _arOpen = false);
        }
        break;
      case 'onWorldMapCaptured':
        await _onWorldMapCaptured(
          Map<String, dynamic>.from(call.arguments as Map),
        );
        break;
      case 'onRelocalized':
        _isRelocalized = true;
        _addEvent('✅ リローカライゼーション成功 — 配置を復元中...');
        // リローカライゼーション待ちを解除
        if (_relocalizationCompleter != null &&
            !_relocalizationCompleter!.isCompleted) {
          _relocalizationCompleter!.complete(true);
        }
        // バッファに溜まっていたリモート配置をフラッシュ
        _flushPendingRemotePlacements();
        break;
    }
  }

  Future<void> _onNativePlacementCreated(Map<String, dynamic> args) async {
    if (_uploadedAssetId == null) {
      _addEvent('❌ アセットIDが未設定です');
      return;
    }

    final transform = (args['transform'] as List).cast<double>();
    final widthM = (args['width_m'] as num).toDouble();
    final heightM = (args['height_m'] as num).toDouble();

    _addEvent('📤 配置をサーバーに送信中...');

    try {
      await widget.api.createPlacement(
        widget.session.accessToken,
        widget.roomId,
        imageAssetId: _uploadedAssetId!,
        transform: transform,
        widthM: widthM,
        heightM: heightM,
      );
      _addEvent('✅ 配置を保存しました');
    } catch (e) {
      _addEvent('❌ 配置保存エラー: $e');
    }
  }

  Future<void> _onWorldMapCaptured(Map<String, dynamic> args) async {
    final data = args['data'] as Uint8List?;
    final anchorCount = args['anchor_count'] as int? ?? 0;
    if (data == null) {
      _addEvent('⚠️ WorldMapデータが空です');
      return;
    }

    _addEvent('📤 WorldMap アップロード中... ($anchorCount アンカー, ${data.length}B)');

    try {
      // 1. アセットのアップロードURLを取得
      final uploadInfo = await widget.api.createUploadUrl(
        widget.session.accessToken,
        kind: 'worldmap',
        contentType: 'application/octet-stream',
        byteSize: data.length,
      );

      final assetId = uploadInfo['asset_id'] as String;
      final uploadUrl = uploadInfo['upload_url'] as String;

      // 2. アップロード
      await widget.api.uploadFile(uploadUrl, data, 'application/octet-stream');

      // 3. ルームのWorldMapとして設定
      await widget.api.setWorldmap(
        widget.session.accessToken,
        widget.roomId,
        assetId: assetId,
      );

      _addEvent('✅ WorldMap保存完了');
    } catch (e) {
      _addEvent('❌ WorldMap保存エラー: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 画像選択 & アップロード
  // ---------------------------------------------------------------------------

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _isUploading = true;
      _selectedImagePath = picked.path;
      _uploadedAssetId = null;
    });

    try {
      final bytes = await File(picked.path).readAsBytes();
      final contentType = lookupMimeType(picked.path) ?? 'image/jpeg';

      _addEvent('📤 画像アップロード中...');

      final uploadInfo = await widget.api.createUploadUrl(
        widget.session.accessToken,
        kind: 'image',
        contentType: contentType,
        byteSize: bytes.length,
      );

      final assetId = uploadInfo['asset_id'] as String;
      final uploadUrl = uploadInfo['upload_url'] as String;

      await widget.api.uploadFile(uploadUrl, bytes, contentType);

      if (!mounted) return;
      setState(() {
        _uploadedAssetId = assetId;
        _isUploading = false;
      });
      _addEvent('✅ アップロード完了 (asset: $assetId)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _addEvent('❌ アップロード失敗: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('画像アップロード失敗: $e')));
    }
  }

  // ---------------------------------------------------------------------------
  // AR 起動（WorldMap + 既存配置をロードしてから起動）
  // ---------------------------------------------------------------------------

  Future<void> _openAr() async {
    if (_selectedImagePath == null || _uploadedAssetId == null) return;

    setState(() => _isLoadingAr = true);
    _addEvent('🔄 AR準備中... WorldMap & 配置を取得');

    try {
      // 1. WorldMapをダウンロード（あれば）
      await _loadWorldMap();

      // 2. 既存配置をロード & 画像をプリダウンロード
      await _loadExistingPlacements();

      if (!mounted) return;
      setState(() {
        _isLoadingAr = false;
        _arOpen = true;
      });

      // 3. AR起動（WorldMapデータを渡す）
      final args = <String, dynamic>{
        'path': _selectedImagePath,
        'roomId': widget.roomId,
      };
      if (_worldMapData != null) {
        args['worldMapData'] = _worldMapData;
      }
      await _channel.invokeMethod('openArRoom', args);

      // 4. WorldMapありの場合、リローカライゼーション成功を待ってから配置を復元
      if (_worldMapData != null) {
        _relocalizationCompleter = Completer<bool>();
        _addEvent('⏳ リローカライゼーション待ち...');
        // 60秒でタイムアウト
        final success = await _relocalizationCompleter!.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () => false,
        );
        if (!success) {
          _addEvent('⚠️ リローカライゼーション失敗 — 別の部屋の可能性があります');
          _addEvent('💡 配置は復元されません。正しい部屋で再度お試しください');
          return;
        }
      } else {
        // WorldMapなし（初回）: すぐに表示可能
        _isRelocalized = true;
        await Future.delayed(const Duration(seconds: 2));
      }
      await _sendExistingPlacementsToAr();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAr = false;
        _arOpen = false;
      });
      _addEvent('❌ AR起動エラー: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AR起動エラー: $e')));
    }
  }

  Future<void> _loadWorldMap() async {
    try {
      final worldmapInfo = await widget.api.getWorldmap(
        widget.session.accessToken,
        widget.roomId,
      );
      if (worldmapInfo == null) {
        _addEvent('ℹ️ WorldMapなし（初回）');
        _worldMapData = null;
        return;
      }

      final downloadUrl = worldmapInfo['download_url'] as String;
      final version = worldmapInfo['version'];
      _addEvent('⬇️ WorldMap v$version ダウンロード中...');

      final bytes = await widget.api.downloadBytes(downloadUrl);
      _worldMapData = Uint8List.fromList(bytes);
      _addEvent('✅ WorldMap取得完了 (${_worldMapData!.length}B)');
    } catch (e) {
      _addEvent('⚠️ WorldMap取得失敗（新規セッションとして起動）: $e');
      _worldMapData = null;
    }
  }

  Future<void> _loadExistingPlacements() async {
    try {
      _existingPlacements = await widget.api.listPlacements(
        widget.session.accessToken,
        widget.roomId,
      );
      _addEvent('📋 既存配置: ${_existingPlacements.length}件');

      // 画像をプリダウンロード
      for (final p in _existingPlacements) {
        final assetId = p['image_asset_id'] as String;
        final downloadUrl = p['image_download_url'] as String?;
        await _downloadImage(assetId, downloadUrl: downloadUrl);
      }
    } catch (e) {
      _addEvent('⚠️ 既存配置の取得失敗: $e');
      _existingPlacements = [];
    }
  }

  Future<void> _sendExistingPlacementsToAr() async {
    for (final p in _existingPlacements) {
      final assetId = p['image_asset_id'] as String;
      final localPath = _imageCache[assetId];
      if (localPath == null) continue;

      final transform = (p['transform'] as List).cast<double>();
      final widthM = (p['width_m'] as num).toDouble();
      final heightM = (p['height_m'] as num).toDouble();

      try {
        await _channel.invokeMethod('addRemotePlacement', {
          'transform': transform,
          'width_m': widthM,
          'height_m': heightM,
          'image_path': localPath,
        });
      } catch (e) {
        _addEvent('⚠️ 配置復元エラー: $e');
      }
    }

    if (_existingPlacements.isNotEmpty) {
      _addEvent('📍 ${_existingPlacements.length}件の配置を復元');
    }
  }

  /// 画像をダウンロードしてローカルに保存（キャッシュ対応）
  Future<String> _downloadImage(String assetId, {String? downloadUrl}) async {
    if (_imageCache.containsKey(assetId)) {
      return _imageCache[assetId]!;
    }

    downloadUrl ??= await widget.api.getDownloadUrl(
      widget.session.accessToken,
      assetId,
    );

    final bytes = await widget.api.downloadBytes(downloadUrl);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/placement_$assetId.jpg');
    await file.writeAsBytes(bytes);

    _imageCache[assetId] = file.path;
    return file.path;
  }

  /// リローカライゼーション待ち中にバッファされたリモート配置をフラッシュ
  Future<void> _flushPendingRemotePlacements() async {
    if (_pendingRemotePlacements.isEmpty) return;
    _addEvent('📨 バッファ済み配置 ${_pendingRemotePlacements.length}件を描画中...');
    final pending = List<Map<String, dynamic>>.from(_pendingRemotePlacements);
    _pendingRemotePlacements.clear();
    for (final p in pending) {
      await _addRemotePlacementToAr(p);
    }
  }

  // ---------------------------------------------------------------------------
  // ヘルパー
  // ---------------------------------------------------------------------------

  void _addEvent(String msg) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, '${TimeOfDay.now().format(context)} $msg');
      if (_events.length > 50) {
        _events.removeRange(50, _events.length);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AR - ${widget.roomName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Step 1: 画像選択 ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '① 画像を選択',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedImagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_selectedImagePath!),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _pickAndUploadImage,
                      icon: const Icon(Icons.photo_library),
                      label: Text(_isUploading ? 'アップロード中...' : '画像を選択＆アップロード'),
                    ),
                    if (_isUploading) const LinearProgressIndicator(),
                    if (_uploadedAssetId != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '✅ アップロード完了',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Step 2: AR 起動 ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '② ARで壁に配置',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed:
                          (_uploadedAssetId != null &&
                              !_arOpen &&
                              !_isLoadingAr)
                          ? _openAr
                          : null,
                      icon: const Icon(Icons.view_in_ar),
                      label: Text(
                        _isLoadingAr
                            ? 'データ取得中...'
                            : _arOpen
                            ? 'AR起動中...'
                            : 'ARを開く',
                      ),
                    ),
                    if (_isLoadingAr) const LinearProgressIndicator(),
                    const SizedBox(height: 4),
                    const Text(
                      '壁をタップで画像配置 / 📍マップ保存で位置を永続化',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── イベントログ ──
            const Text('イベントログ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _events[index],
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
