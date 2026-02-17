import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:url_launcher/url_launcher.dart'; // Import for opening links
import '../../../service/api_service.dart';

// Static cache to preserve swipe position across navigation
class _SwipeCache {
  static final Map<String, int> _indexCache = {};

  static int getIndex(String groupId) => _indexCache[groupId] ?? 0;
  static void setIndex(String groupId, int index) =>
      _indexCache[groupId] = index;
  static void clear(String groupId) => _indexCache.remove(groupId);
}

class SwipeScreen extends StatefulWidget {
  final String groupId;

  const SwipeScreen({super.key, required this.groupId});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  ApiService get _api => globalApi;

  List<dynamic> _places = [];
  int _index = 0;
  bool _loading = true;
  String? _error;
  bool _sending = false;
  double _drag = 0;
  int _matchCount = 0;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    // Restore swipe position from cache if available
    _index = _SwipeCache.getIndex(widget.groupId);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When returning from back navigation, only reload if it was the first load
    // Otherwise keep the current state
  }

  Future<void> _load() async {
    // Only reset index if this is the first load
    setState(() {
      _loading = true;
      _error = null;
      if (_isFirstLoad) {
        _places = [];
        _index = _SwipeCache.getIndex(widget.groupId);
      }
      _matchCount = 0;
    });

    try {
      // 0) โหลดจำนวน matches ก่อน
      try {
        final matchData = await _api.getGroupMatch(widget.groupId);
        final matches = (matchData['matches'] as List?) ?? [];
        if (!mounted) return;
        setState(() {
          _matchCount = matches.length;
        });
      } catch (_) {
        // ถ้าโหลด matches ไม่ได้ก็ค่อยไป
      }

      // 1) โหลดข้อมูล group เพื่อนำ city/filters มาใช้
      final group = await _api.getGroup(widget.groupId);
      final city = (group['city'] ?? '').toString().trim();
      final filters =
          (group['filters'] as Map?) ?? (group['groupFilters'] as Map?) ?? {};
      final categories =
          (filters['categories'] as List?)?.map((e) => e.toString()).toList();
      final minRating = (filters['minRating'] as num?)?.toDouble() ?? 0.0;
      final priceLevel = (filters['priceLevel'] as num?)?.toInt();
      final maxDistanceKm =
          (filters['maxDistanceKm'] as num?)?.toDouble() ?? 10.0;
      final openNow = (filters['openNow'] as bool?) ?? false;

      // 1.5) Get User Location
      double? lat, lng;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            final pos = await Geolocator.getCurrentPosition();
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (e) {
        // Location failed, ignore and proceed without distance score
        debugPrint('Location error: $e');
      }

      List<dynamic> places = [];

      // 2) ลองเรียก endpoint เฉพาะกลุ่ม ถ้ามี
      try {
        final query = <String, dynamic>{};
        if (lat != null && lng != null) {
          query['lat'] = lat;
          query['lng'] = lng;
        }

        final resp = await _api.rawGet(
          '/api/groups/${widget.groupId}/places',
          query: query,
        );
        if (resp is List) {
          places = resp;
        }
      } catch (_) {
        // ถ้า 404 หรือ error อื่นใน endpoint นี้ ค่อย fallback
      }

      // 3) ถ้า endpoint เฉพาะกลุ่มไม่มี/ว่าง → fallback ไป /api/places
      if (places.isEmpty) {
        final loc = city.isNotEmpty ? city : 'Bangkok';
        try {
          places = await _api.getPlaces(
            location: loc,
            types: categories,
            minRating: minRating,
            priceLevel: priceLevel,
            maxDistanceKm: maxDistanceKm,
            openNow: openNow,
          );
        } catch (_) {
          // ถ้า /api/places ก็พัง ค่อยไปแสดง error ด้านล่าง
        }
      }

      if (!mounted) return;

      if (places.isEmpty) {
        setState(() {
          _places = [];
          _loading = false;
          _error =
              'No candidate places available for this group.\nPlease check backend / seed data.';
          _isFirstLoad = false;
        });
      } else {
        setState(() {
          // Only set index to 0 if this is the first load
          if (_isFirstLoad) {
            _places = places;
            _index = 0;
          } else {
            // If returning to screen, keep current index but update places if needed
            if (_places.isEmpty) {
              _places = places;
            }
          }
          _loading = false;
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _isFirstLoad = false;
      });
    }
  }

  Future<void> _launchMaps(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch maps: $url')),
          );
        }
      }
    }
  }

  Future<void> _sendSwipe(bool liked) async {
    if (_index >= _places.length) return;
    final place = _places[_index];
    final placeId =
        (place['_id'] ?? place['id'] ?? place['placeId']).toString();

    setState(() => _sending = true);
    try {
      await _api.saveSwipe(
        groupId: widget.groupId,
        placeId: placeId,
        liked: liked,
      );
      if (!mounted) return;
      setState(() {
        _index++;
        _drag = 0;
        // Save the current index to cache
        _SwipeCache.setIndex(widget.groupId, _index);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _drag = 0);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _drag += d.delta.dx;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    const threshold = 120.0;
    if (_drag > threshold) {
      _sendSwipe(true); // ขวา = Like
    } else if (_drag < -threshold) {
      _sendSwipe(false); // ซ้าย = Skip
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _places.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Swipe Places')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_index >= _places.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Swipe Places')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You have swiped all available places for this session.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    '/results',
                    arguments: {'groupId': widget.groupId},
                  );
                },
                child: const Text('View Group Matches'),
              ),
            ],
          ),
        ),
      );
    }

    final place = _places[_index];
    final likeOpacity = _drag > 0 ? (_drag / 150).clamp(0.0, 1.0) : 0.0;
    final skipOpacity = _drag < 0 ? (-_drag / 150).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Swipe Places'),
        actions: [
          Stack(
            children: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    '/results',
                    arguments: {'groupId': widget.groupId},
                  );
                },
                icon: const Icon(Icons.emoji_events),
                label: const Text('See matches'),
              ),
              if (_matchCount > 0)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _matchCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: GestureDetector(
                onHorizontalDragUpdate: _sending ? null : _onDragUpdate,
                onHorizontalDragEnd: _sending ? null : _onDragEnd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(_drag, 0, 0)
                    ..rotateZ(_drag * 0.0008),
                  width: MediaQuery.of(context).size.width * 0.86,
                  height: MediaQuery.of(context).size.height * 0.56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 18,
                        offset: Offset(0, 10),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _buildPlaceCard(
                    context: context,
                    place: place,
                    likeOpacity: likeOpacity,
                    skipOpacity: skipOpacity,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Action buttons: dislike (left) and like (right)
          Transform.translate(
            offset: const Offset(0, -40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Dislike
                GestureDetector(
                  onTap: _sending ? null : () => _sendSwipe(false),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.shade400, width: 3),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.close, size: 36, color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 126),
                // Like
                GestureDetector(
                  onTap: _sending ? null : () => _sendSwipe(true),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.green.shade400, width: 3),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.favorite_border,
                          size: 36, color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPlaceCard({
    required BuildContext context,
    required Map place,
    required double likeOpacity,
    required double skipOpacity,
  }) {
    final priceLevel =
        (place['priceLevel'] ?? place['price_level'] ?? 1) as int;
    final rating = (place['rating'] ?? '-')?.toString();
    final openHours = place['openHours'] ?? place['open_hours'] ?? '';
    final categories =
        (place['categories'] ?? place['category'] ?? []) as List?;
    final priceText = '฿' * priceLevel;
    final address = (place['address'] ?? place['city'] ?? '') as String;
    final name = (place['name'] ?? '') as String;
    final image = place['image'];
    final mapsUrl = place['mapsUrl'] ?? place['maps_url'] ?? '';

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (image != null)
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.network(
                            _api.getProxyImageUrl(image),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),

                        // Top-right favorite button
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isFavorited(place)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: _isFavorited(place)
                                    ? Colors.amber
                                    : Colors.blueAccent,
                                size: 32,
                              ),
                              onPressed: () => _toggleFavorite(place),
                            ),
                          ),
                        ),

                        // Bottom overlay with name, address, and badges
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(18),
                                bottomRight: Radius.circular(18),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.6),
                                  Colors.black.withOpacity(0.15),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (address.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      address,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.white70),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (categories != null &&
                                        categories.isNotEmpty)
                                      _pill(categories.join(', '),
                                          background: Colors.white70,
                                          textColor: Colors.black87),
                                    if (place['distKm'] != null)
                                      _pill(
                                          '${(place['distKm'] as num).toStringAsFixed(1)} km',
                                          background: Colors.white70,
                                          textColor: Colors.black87,
                                          icon: Icons.location_on),
                                    _pill('Rating: $rating',
                                        background: Colors.black54,
                                        textColor: Colors.white,
                                        icon: Icons.star),
                                    _pill('Price: $priceText',
                                        background: Colors.white70,
                                        textColor: Colors.black87),
                                    if (openHours != null &&
                                        openHours.toString().isNotEmpty)
                                      _pill(openHours.toString(),
                                          background: Colors.white70,
                                          textColor: Colors.black87),
                                  ],
                                ),
                                if (mapsUrl != null &&
                                    mapsUrl.toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: GestureDetector(
                                      onTap: () =>
                                          _launchMaps(mapsUrl.toString()),
                                      child: Text(
                                        'Maps : $mapsUrl',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.blueAccent,
                                              fontWeight: FontWeight.bold,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor:
                                                  Colors.blueAccent,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // No image: show name/address and badges as before
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (address.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 8),
                          child: Text(
                            address,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (categories != null && categories.isNotEmpty)
                            Chip(
                              label: Text(categories.join(', ')),
                              backgroundColor: Colors.white70,
                            ),
                          Chip(
                            avatar: const Icon(Icons.star,
                                size: 18, color: Colors.white),
                            label: Text('Rating: $rating'),
                            backgroundColor: Colors.black.withOpacity(0.25),
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                          Chip(
                            label: Text('Price: $priceText'),
                            backgroundColor: Colors.white70,
                          ),
                          if (openHours != null &&
                              openHours.toString().isNotEmpty)
                            Chip(
                              label: Text(openHours.toString()),
                              backgroundColor: Colors.white70,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (mapsUrl != null && mapsUrl.toString().isNotEmpty)
                        GestureDetector(
                          onTap: () => _launchMaps(mapsUrl.toString()),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Maps : $mapsUrl',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Like/Skip badges (optional, can be removed if not needed)
        Positioned(
          top: 24,
          right: 24,
          child: Opacity(
            opacity: likeOpacity,
            child: _badge('LIKE', Colors.greenAccent),
          ),
        ),
        Positioned(
          top: 24,
          left: 24,
          child: Opacity(
            opacity: skipOpacity,
            child: _badge('SKIP', Colors.redAccent),
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _pill(String text,
      {Color background = Colors.white70,
      Color textColor = Colors.black87,
      IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getPlaceId(Map place) {
    return (place['_id'] ?? place['id'] ?? place['placeId'] ?? '').toString();
  }

  bool _isFavorited(Map place) {
    return _api.favorites.contains(_getPlaceId(place));
  }

  void _toggleFavorite(Map place) {
    final placeId = _getPlaceId(place);
    setState(() {
      if (_api.favorites.contains(placeId)) {
        _api.favorites.remove(placeId);
      } else {
        _api.favorites.add(placeId);
      }
    });
  }

  @override
  void dispose() {
    // Persist the current swipe index so returning users resume where they left off
    try {
      _SwipeCache.setIndex(widget.groupId, _index);
    } catch (_) {}
    super.dispose();
  }
}
