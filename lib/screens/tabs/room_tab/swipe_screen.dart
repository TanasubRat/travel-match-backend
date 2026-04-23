import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:url_launcher/url_launcher.dart'; // Import for opening links
import '../../../service/api_service.dart';

import 'package:cached_network_image/cached_network_image.dart';

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
  Timer? _pollingTimer;
  final Set<String> _knownMatchIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollMatches();
    });
  }

  Future<void> _pollMatches() async {
    if (!mounted) return;
    try {
      final matchData = await _api.getGroupMatch(widget.groupId);
      final matches = (matchData['matches'] as List?) ?? [];
      
      if (!mounted) return;
      
      bool hasNewMatch = false;
      Map? firstNewMatch;
      for (var m in matches) {
        final pid = (m['placeId'] ?? m['_id'])?.toString();
        if (pid != null && !_knownMatchIds.contains(pid)) {
          _knownMatchIds.add(pid);
          if (!hasNewMatch) {
            firstNewMatch = m;
          }
          hasNewMatch = true;
        }
      }

      if (firstNewMatch != null) {
        // Show popup for the first new match to prevent dialog spam
        _showMatchDialog(firstNewMatch);
      }
      
      if (hasNewMatch || _matchCount != matches.length) {
        setState(() {
          _matchCount = matches.length;
        });
      }
    } catch (_) {
      // ignore
    }
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
        _index = 0; // Fresh list always unswiped now due to backend filter
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
          // Populate known matches so we don't trigger dialogs for past matches!
          for (var m in matches) {
             final pid = (m['placeId'] ?? m['_id'])?.toString();
             if (pid != null) _knownMatchIds.add(pid);
          }
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

      // Removed fallback to /api/places because it bypasses the backend $nin swipe filter,
      // causing the user to see cards they've already swiped infinitely!

      if (!mounted) return;

      if (places.isEmpty) {
        setState(() {
          _places = [];
          _loading = false;
          _error = 'No new places left to discover for this group!\nTry relaxing your group filters or switching cities.';
          _isFirstLoad = false;
        });
      } else {
        setState(() {
          if (_isFirstLoad) {
            _places = places;
            // The _index is already set to the cached value at the top of _load()
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
      final resp = await _api.saveSwipe(
        groupId: widget.groupId,
        placeId: placeId,
        liked: liked,
      );

      final isMatch = resp['isMatch'] == true;
      
      // Safely parse place to avoid TypeError if the backend returns an ObjectId string
      final matchPlace = (resp['place'] is Map) ? resp['place'] as Map : null;

      if (!mounted) return;

      if (isMatch && matchPlace != null) {
        final pid = (matchPlace['_id'] ?? matchPlace['id'] ?? matchPlace['placeId'])?.toString();
        if (pid != null) {
          _knownMatchIds.add(pid);
        }
        setState(() {
          _matchCount++;
        });
        _showMatchDialog(matchPlace);
      }

      setState(() {
        _index++;
        _drag = 0;

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

  void _showMatchDialog(Map place) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: Theme.of(context).colorScheme.secondary, size: 28),
              const SizedBox(width: 8),
              const Text("It's a Match!", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Everyone agreed on ${place['name'] ?? 'this place'}!",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (place['image'] != null && place['image'].toString().isNotEmpty)
                 ClipRRect(
                   borderRadius: BorderRadius.circular(12),
                   child: CachedNetworkImage(
                     imageUrl: _api.getProxyImageUrl(place['image']), 
                     height: 120, 
                     width: 280, 
                     fit: BoxFit.cover,
                     placeholder: (context, url) => Container(
                       height: 120, 
                       width: 280, 
                       color: Colors.grey[200]
                     ),
                     errorWidget: (context, url, error) => Container(
                       height: 120, 
                       width: 280, 
                       color: Colors.grey[300],
                       child: const Icon(Icons.image_not_supported)
                     ),
                   ),
                 ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text("Keep Swiping", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamed(
                  '/results',
                  arguments: {'groupId': widget.groupId},
                );
              },
              child: const Text("View Results", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
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
        appBar: AppBar(
          title: const Text('Swipe Places'),
          actions: _buildAppBarActions(),
        ),
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
        actions: _buildAppBarActions(),
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
                  duration: _drag == 0 ? const Duration(milliseconds: 180) : Duration.zero,
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
            offset: const Offset(0, -30),
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
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.close_rounded, size: 36, color: Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
                
                // Matches Button (Center)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      '/results',
                      arguments: {'groupId': widget.groupId},
                    );
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                        ]
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.emoji_events_rounded,
                        size: 28,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 48),
                // Like
                GestureDetector(
                  onTap: _sending ? null : () => _sendSwipe(true),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B4D8), Color(0xFF0096C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00B4D8).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.favorite_rounded, size: 36, color: Colors.white),
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
                          child: CachedNetworkImage(
                            imageUrl: _api.getProxyImageUrl(image),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            ),
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
    return _api.favorites.containsKey(_getPlaceId(place));
  }

  void _toggleFavorite(Map place) async {
    await _api.toggleFavorite(place);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();

    super.dispose();
  }

  List<Widget> _buildAppBarActions() {
    return [
      Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
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
                top: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary, // Tropical orange
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _matchCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }
}
