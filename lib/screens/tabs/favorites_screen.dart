import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  List<Map<String, dynamic>> _getFavorites() {
    return _api.favorites.values.cast<Map<String, dynamic>>().toList();
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
      body: favorites.isEmpty
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
              : ListView.builder(
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
                                  child: CachedNetworkImage(
                                    imageUrl: _api.getProxyImageUrl(image),
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(width: 60, height: 60, color: Colors.grey.shade200),
                                    errorWidget: (context, url, err) => Container(width: 60, height: 60, color: Colors.grey.shade300, child: const Icon(Icons.broken_image, size: 20)),
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
                          onTap: () async {
                            await _api.toggleFavorite(place);
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
    );
  }
}
