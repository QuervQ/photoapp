import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ar_room_page.dart';
import 'backend_api.dart';

class MultiplayerPage extends StatefulWidget {
  final BackendApi api;
  final AuthSession session;
  final VoidCallback onLogout;

  const MultiplayerPage({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
  });

  @override
  State<MultiplayerPage> createState() => _MultiplayerPageState();
}

class _MultiplayerPageState extends State<MultiplayerPage> {
  final _createRoomController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  List<Room> _rooms = [];
  List<Map<String, dynamic>> _placements = [];
  List<String> _events = [];
  String? _selectedRoomId;

  bool _loadingRooms = true;
  bool _actionLoading = false;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _loadingRooms = true;
    });

    try {
      final rooms = await widget.api.listRooms(widget.session.accessToken);
      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        if (_selectedRoomId != null &&
            !_rooms.any((room) => room.id == _selectedRoomId)) {
          _selectedRoomId = null;
          _placements = [];
        }
      });

      if (_selectedRoomId != null) {
        await _selectRoom(_selectedRoomId!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ルーム一覧の取得に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _loadingRooms = false;
        });
      }
    }
  }

  Future<void> _createRoom() async {
    final roomName = _createRoomController.text.trim();
    if (roomName.isEmpty) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final room = await widget.api.createRoom(
        widget.session.accessToken,
        roomName,
      );
      if (!mounted) return;
      _createRoomController.clear();
      await _loadRooms();
      await _selectRoom(room.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ルーム作成に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _joinByInvite() async {
    final inviteCode = _inviteCodeController.text.trim();
    if (inviteCode.isEmpty) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final joinedRoomId = await widget.api.joinRoom(
        widget.session.accessToken,
        inviteCode,
      );

      if (!mounted) return;

      _inviteCodeController.clear();
      await _loadRooms();
      await _selectRoom(joinedRoomId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('招待コード参加に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _showInvite() async {
    final roomId = _selectedRoomId;
    if (roomId == null) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final invite = await widget.api.createInvite(
        widget.session.accessToken,
        roomId,
      );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('招待コード'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(invite.inviteCode),
              const SizedBox(height: 8),
              Text('有効期限: ${invite.expiresAt.toLocal()}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('招待コード発行に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  void _openArRoom() {
    final roomId = _selectedRoomId;
    if (roomId == null) return;

    final room = _rooms.firstWhere((r) => r.id == roomId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArRoomPage(
          api: widget.api,
          session: widget.session,
          roomId: roomId,
          roomName: room.name,
        ),
      ),
    );
  }

  Future<void> _selectRoom(String roomId) async {
    await _unsubscribeWs();

    setState(() {
      _selectedRoomId = roomId;
      _events = [];
    });

    await _loadPlacements(roomId);
    _subscribeWs(roomId);
  }

  Future<void> _loadPlacements(String roomId) async {
    try {
      final placements = await widget.api.listPlacements(
        widget.session.accessToken,
        roomId,
      );
      if (!mounted) return;

      setState(() {
        _placements = placements;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('配置情報の取得に失敗しました: $e')));
    }
  }

  void _subscribeWs(String roomId) {
    final channel = widget.api.connectRoomWs(
      accessToken: widget.session.accessToken,
      roomId: roomId,
    );

    final subscription = channel.stream.listen(
      (event) {
        final text = event.toString();
        setState(() {
          _events.insert(0, text);
          if (_events.length > 30) {
            _events = _events.take(30).toList();
          }
        });

        _handleRealtimeEvent(text, roomId);
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('WS接続エラー: $error')));
      },
      onDone: () {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('WS接続が終了しました')));
      },
    );

    _channel = channel;
    _wsSubscription = subscription;

    final subscribeMessage = jsonEncode({
      'type': 'subscribe',
      'room_id': roomId,
    });
    channel.sink.add(subscribeMessage);
  }

  Future<void> _handleRealtimeEvent(String message, String roomId) async {
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type'];
      if (type == 'placement_created' || type == 'worldmap_updated') {
        await _loadPlacements(roomId);
      }
    } catch (_) {
      return;
    }
  }

  Future<void> _unsubscribeWs() async {
    await _wsSubscription?.cancel();
    await _channel?.sink.close();
    _wsSubscription = null;
    _channel = null;
  }

  @override
  void dispose() {
    _createRoomController.dispose();
    _inviteCodeController.dispose();
    unawaited(_unsubscribeWs());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multiplayer (${widget.session.email})'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _createRoomController,
                    decoration: const InputDecoration(labelText: '新規ルーム名'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _actionLoading ? null : _createRoom,
                  child: const Text('作成'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inviteCodeController,
                    decoration: const InputDecoration(labelText: '招待コードで参加'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _actionLoading ? null : _joinByInvite,
                  child: const Text('参加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _selectedRoomId == null || _actionLoading
                      ? null
                      : _showInvite,
                  child: const Text('招待コード発行'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedRoomId == null
                      ? null
                      : () => _loadPlacements(_selectedRoomId!),
                  child: const Text('配置更新'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _selectedRoomId == null ? null : _openArRoom,
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('ARで配置'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _loadingRooms
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _rooms.length,
                            itemBuilder: (context, index) {
                              final room = _rooms[index];
                              final selected = room.id == _selectedRoomId;
                              return ListTile(
                                selected: selected,
                                title: Text(room.name),
                                subtitle: Text(room.id),
                                onTap: () => _selectRoom(room.id),
                              );
                            },
                          ),
                  ),
                  const VerticalDivider(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Placements: ${_placements.length}'),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _placements.length,
                            itemBuilder: (context, index) {
                              final p = _placements[index];
                              return ListTile(
                                dense: true,
                                title: Text('asset: ${p['image_asset_id']}'),
                                subtitle: Text('id: ${p['id']}'),
                              );
                            },
                          ),
                        ),
                        const Divider(),
                        const Text('Realtime Events'),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _events.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                dense: true,
                                title: Text(
                                  _events[index],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
