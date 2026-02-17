import 'package:flutter/material.dart';
import '../../../service/api_service.dart';

class ResultsScreen extends StatefulWidget {
  final String? groupId;

  const ResultsScreen({super.key, this.groupId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  ApiService get _api => globalApi;

  late String _groupId;
  bool _initialized = false;

  bool _loading = true;
  String? _error;
  bool _hasMatch = false;
  List<dynamic> _matches = [];
  Map<String, dynamic>? _group;
  String? _meId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    String? gid = widget.groupId;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (gid == null && args is Map && args['groupId'] != null) {
      gid = args['groupId'].toString();
    }

    if (gid == null) {
      throw StateError('ResultsScreen requires a groupId.');
    }

    _groupId = gid;
    _initialized = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _api.me();
      _meId = me?['id'] ?? me?['_id'];

      final g = await _api.getGroup(_groupId);
      final m = await _api.getGroupMatch(_groupId);

      if (!mounted) return;
      setState(() {
        _group = g;
        _hasMatch = m['hasMatch'] ?? false;
        _matches = (m['matches'] as List? ?? []);
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

  bool get _isHost {
    if (_group == null || _meId == null) return false;
    final host = _group!['host'];
    final hostId = host is Map ? host['_id'] : host?.toString();
    return hostId == _meId;
  }

  Future<void> _confirm(String placeId) async {
    try {
      await _api.confirmFinalPlace(groupId: _groupId, placeId: placeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Final destination confirmed')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matches')),
        body: Center(child: Text('Error: $_error')),
      );
    }
    if (!_hasMatch || _matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matches')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No common match found for this session.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Try adjusting filters or starting a new swipe session.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Room'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exact Matches'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _matches.length,
        itemBuilder: (context, index) {
          final m = _matches[index];
          final placeId = m['placeId']?.toString() ?? m['_id']?.toString();
          final image = m['image']?.toString() ?? '';
          final title = m['name'] ?? 'Unknown Place';
          final address = m['address']?.toString() ?? '';
          final rating = m['rating'] ?? 0;
          final price = m['priceLevel']?.toString() ?? '';
          final likesCount = m['likesCount'] ?? 0;
          final membersCount = _group?['members'] is List
              ? (_group!['members'] as List).length
              : 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                if (image.isNotEmpty)
                  Stack(
                    children: [
                      Image.network(
                        _api.getProxyImageUrl(image),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                      // Match badge
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$likesCount/$membersCount matched',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      // Rating and Price
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (price.isNotEmpty)
                            Row(
                              children: [
                                Text(
                                  price,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Action Button
                      if (_isHost && placeId != null)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _confirm(placeId),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Set as Final Destination'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
