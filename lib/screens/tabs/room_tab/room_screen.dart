import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  void _showQRCode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Invite Friends',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan to join the room instantly!',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: QrImageView(
                data: _joinCode,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Code: ',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  _joinCode,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _copyCode();
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Code Link'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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

    if (_error != null || _group == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.flight_takeoff_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ready for an Adventure?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Create a room to start swiping and planning \nthe perfect trip with your friends.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                width: 250,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/home'),
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text(
                    'Create / Join Room',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
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

    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero Header Image
          Stack(
            children: [
              Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  image: const DecorationImage(
                    // Default beautiful travel placeholder image to satisfy "pictures of place" vibe
                    image: NetworkImage(
                        'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?q=80&w=1000&auto=format&fit=crop'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Gradient Overlay for text readability
              Container(
                height: 240,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary, // Tropical orange
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            city.isNotEmpty ? city.toUpperCase() : 'TRIP ROOM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Main Content Card
          Transform.translate(
            offset: const Offset(0, -20),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Menu & QR
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '${members.length} Explorers',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _showQRCode,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        color: theme.colorScheme.primary,
                        tooltip: 'Show QR Code',
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
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
                        itemBuilder: (context) => [
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
                              child: Text('Delete room',
                                  style: TextStyle(color: Colors.red)),
                            )
                          else
                            const PopupMenuItem(
                              value: 'leave',
                              child: Text('Leave room',
                                  style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Room Code Big Display
                  GestureDetector(
                    onTap: _showQRCode,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'JOIN CODE',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _joinCode,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Host
                  const Text(
                    'Host',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
                      child: Icon(Icons.star, color: theme.colorScheme.secondary, size: 20),
                    ),
                    title: Text(
                      _hostName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: _isHost ? const Text('You') : null,
                  ),

                  const SizedBox(height: 16),

                  // Members List
                  const Text(
                    'Members',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: members.isEmpty
                        ? [
                            const Text(
                              'Waiting for friends to join...',
                              style: TextStyle(
                                  color: Colors.grey, fontStyle: FontStyle.italic),
                            )
                          ]
                        : members.map((m) {
                            return Chip(
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.grey.shade300),
                              avatar: CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                child: Text(
                                  m[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                              ),
                              label: Text(m),
                            );
                          }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 56,
                          child: FilledButton.icon(
                            onPressed:
                                _busy ? null : (_isHost ? _startGame : _goToSwipe),
                            icon: Icon(
                              _isHost
                                  ? Icons.local_fire_department_rounded
                                  : Icons.swipe_rounded,
                            ),
                            label: Text(
                              _isHost ? 'Start Swiping' : 'Go to Swipe',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _seeMatches,
                            icon: const Icon(Icons.emoji_events_outlined, size: 20),
                            label: const Text('Matches\nResults', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
