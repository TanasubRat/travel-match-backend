import 'package:flutter/material.dart';
import '../../service/api_service.dart';
import '../../widgets/app_tab_scaffold.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with WidgetsBindingObserver {
  ApiService get _api => globalApi;
  List<dynamic> _allPlaces = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllPlaces();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  Future<void> _loadAllPlaces() async {
    setState(() => _loading = true);
    try {
      // Load places from multiple cities to get all favorited ones
      final cities = ['Bangkok', 'Chiang Mai', 'Phuket', 'Salaya'];
      final allPlaces = <dynamic>[];

      for (final city in cities) {
        try {
          final places = await _api.getPlaces(location: city);
          allPlaces.addAll(places);
        } catch (_) {
          // Skip if city has no places
        }
      }

      if (!mounted) return;
      setState(() {
        _allPlaces = allPlaces;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getFavorites() {
    return _allPlaces
        .whereType<Map>()
        .where((p) {
          final placeId =
              (p['_id'] ?? p['id'] ?? p['placeId'] ?? '').toString();
          return _api.favorites.contains(placeId);
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  String _getPlaceId(Map place) {
    return (place['_id'] ?? place['id'] ?? place['placeId'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _getFavorites();

    return AppTabScaffold(
      currentIndex: 3, // Favorite tab
      appBar: AppBar(
        title: Text(
            'Favorite${favorites.isEmpty ? '' : ' (${favorites.length})'}'),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : favorites.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite_border, size: 84),
                        const SizedBox(height: 12),
                        Text(
                          'No favorites yet',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Save places you like and they will appear here.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/home'),
                          icon: const Icon(Icons.explore_outlined),
                          label: const Text('Explore trips'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAllPlaces,
                  child: ListView.builder(
                    itemCount: favorites.length,
                    itemBuilder: (ctx, idx) {
                      final place = favorites[idx];
                      final name = place['name'] ?? '';
                      final image = place['image'];
                      final rating = place['rating'] ?? '-';
                      final priceLevel =
                          place['priceLevel'] ?? place['price_level'] ?? 1;
                      final priceText = '฿' * priceLevel;
                      final address = place['address'] ?? place['city'] ?? '';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 0),
                        child: ListTile(
                          leading: image != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _api.getProxyImageUrl(image),
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.place),
                          title: Text(name),
                          subtitle: Text(address),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('★ $rating',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              Text(priceText,
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _api.favorites.remove(_getPlaceId(place));
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
