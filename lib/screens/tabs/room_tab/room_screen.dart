import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../service/api_service.dart';
import '../../../widgets/app_tab_scaffold.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  ApiService get _api => globalApi;

  Map<String, dynamic>? _group;
  String? _meId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = await _api.me();

      // เก็บ id ของเรา
      _meId = (me?['id'] ?? me?['_id'])?.toString();

      // --- หา groupId แบบไม่ใช้ expression ซ้อน ---
      String? gid;
      if (me != null) {
        if (me['groupId'] != null) {
          gid = me['groupId'].toString();
        } else if (me['group'] is Map && me['group']['_id'] != null) {
          gid = me['group']['_id'].toString();
        } else if (me['group'] != null) {
          gid = me['group'].toString();
        }
      }

      if (gid == null) {
        if (!mounted) return;
        setState(() {
          _group = null;
          _loading = false;
        });
        return;
      }

      final resp = await _api.rawGet('/api/groups/$gid');
      if (!mounted) return;
      setState(() {
        _group = Map<String, dynamic>.from(resp as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? get _groupId {
    if (_group == null) return null;
    return (_group!['_id'] ?? _group!['id'])?.toString();
  }

  String get _joinCode =>
      (_group?['joinCode'] ?? _group?['code'] ?? '------').toString();

  bool get _isHost {
    if (_group == null || _meId == null) return false;
    final hostField =
        _group!['host'] ?? _group!['hostUserId'] ?? _group!['host_user_id'];
    final hostId = hostField is Map ? hostField['_id'] : hostField;
    return hostId?.toString() == _meId;
  }

  List<String> get _memberNames {
    if (_group == null) return [];
    final members = _group!['members'] as List? ?? [];
    return members.map<String>((m) {
      final u = (m['user'] ?? m) as Map? ?? {};
      return (u['displayName'] ?? u['name'] ?? u['email'] ?? 'Member')
          as String;
    }).toList();
  }

  String get _hostName {
    if (_group == null) return '-';
    final host =
        (_group!['hostUser'] ?? _group!['host'] ?? _group!['host_user']) ?? {};
    if (host is Map) {
      return (host['displayName'] ?? host['name'] ?? host['email'] ?? 'Host')
          as String;
    }
    return host.toString();
  }

  // ---------- actions ----------

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _joinCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied room code')),
    );
  }

  Future<void> _shareCode() async {
    await Clipboard.setData(ClipboardData(text: _joinCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code $_joinCode copied. Share it with friends!'),
      ),
    );
  }

  Future<void> _deleteGroup() async {
    if (_groupId == null) return;
    final ok = await _confirm(
      title: 'Delete Room',
      message: 'Are you sure you want to delete this room?',
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _api.deleteGroup(_groupId!);
      await _api.setMyGroupId(null);
      if (!mounted) return;
      setState(() {
        _group = null;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _leaveGroup() async {
    if (_groupId == null) return;
    final ok = await _confirm(
      title: 'Leave Room',
      message: 'Are you sure you want to leave this room?',
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      try {
        await _api.leaveGroup(_groupId!);
      } catch (_) {
        // เผื่อ backend ไม่มี endpoint /:id/leave ก็ไม่ให้แอปล่ม
      }
      await _api.setMyGroupId(null);
      if (!mounted) return;
      setState(() {
        _group = null;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left room')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave failed: $e')),
      );
    }
  }

  Future<void> _startGame() async {
    if (_groupId == null || _busy) return;
    if (_memberNames.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 members to start')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      try {
        await _api.startGroupSession(_groupId!);
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
        // ถ้า 404 แปลว่า backend ไม่มี start endpoint → ข้าม
      }

      if (!mounted) return;
      setState(() => _busy = false);

      Navigator.of(context).pushNamed(
        '/start_swipe',
        arguments: {'groupId': _groupId},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot start: $e')),
      );
    }
  }

  void _goToSwipe() {
    if (_groupId == null || _busy) return;
    Navigator.of(context).pushNamed(
      '/start_swipe',
      arguments: {'groupId': _groupId},
    );
  }

  void _seeMatches() {
    if (_groupId == null) return;
    Navigator.of(context).pushNamed(
      '/results',
      arguments: {'groupId': _groupId},
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return AppTabScaffold(
      currentIndex: 1, // index ของ Room tab ใน bottom nav
      appBar: AppBar(
        title: const Text('Room'),
        automaticallyImplyLeading: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show empty state when no group (either error or null group)
    if (_error != null || _group == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.meeting_room_outlined,
                size: 56,
                color: Colors.black,
              ),
              const SizedBox(height: 16),
              const Text(
                'Create a room',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a room and start swiping together with friends',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/home'),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Create / Join Room'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final name = (_group!['name'] ?? '') as String;
    final city = (_group!['city'] ?? '') as String;
    final members = _memberNames;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                  color: Colors.black.withOpacity(0.06),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // top row: city/name + code + menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city.isNotEmpty ? city : 'Trip Room',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (name.isNotEmpty)
                            Text(
                              name,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Code:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _joinCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'copy':
                            await _copyCode();
                            break;
                          case 'share':
                            await _shareCode();
                            break;
                          case 'delete':
                            await _deleteGroup();
                            break;
                          case 'leave':
                            await _leaveGroup();
                            break;
                        }
                      },
                      itemBuilder: (context) {
                        return <PopupMenuEntry<String>>[
                          const PopupMenuItem(
                            value: 'copy',
                            child: Text('Copy code'),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Text('Share code'),
                          ),
                          const PopupMenuDivider(),
                          if (_isHost)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete room',
                                style: TextStyle(color: Colors.red),
                              ),
                            )
                          else
                            const PopupMenuItem(
                              value: 'leave',
                              child: Text(
                                'Leave room',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ];
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // host
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'Host :',
                      style:
                          TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _hostName,
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (_isHost) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '(me)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // members
                const Text(
                  'Member :',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: members.isEmpty
                      ? [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Waiting for members...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ]
                      : members
                          .map(
                            (m) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),

                // buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _busy ? null : (_isHost ? _startGame : _goToSwipe),
                        icon: Icon(
                          _isHost
                              ? Icons.play_arrow_rounded
                              : Icons.swipe_rounded,
                          size: 20,
                        ),
                        label: Text(_isHost ? 'Start Game' : 'Go to Swipe'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _seeMatches,
                        icon: const Icon(
                          Icons.emoji_events_outlined,
                          size: 18,
                        ),
                        label: const Text('See matches'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
