import 'package:flutter/material.dart';
import '/service/api_service.dart';
import '/widgets/app_tab_scaffold.dart';
import 'home_tab/trip_creation_city_screen.dart';
import 'home_tab/trip_creation_custom_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService api;
  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Join with Friend
  final _joinFormKey = GlobalKey<FormState>();
  final _joinCodeController = TextEditingController();
  bool _joinLoading = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinGroup() async {
    final valid = _joinFormKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _joinLoading = true);
    try {
      final code = _joinCodeController.text.trim().toUpperCase();

      // POST /api/groups/join (ตาม ApiService ที่ปรับแล้ว)
      final data = await widget.api.joinGroup(code: code);

      // รองรับหลายรูปแบบ response
      final gid = (data['groupId'] ??
              (data['group'] is Map ? data['group']['_id'] : null) ??
              data['_id'])
          ?.toString();

      if (gid != null) {
        await widget.api.setMyGroupId(gid);
      }

      if (!mounted) return;
      _joinCodeController.clear();
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined group successfully.')),
      );

      Navigator.of(context).pushNamed('/room');
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 404
          ? 'Invalid room ID.'
          : (e.message.isNotEmpty
              ? e.message
              : 'Join failed (HTTP ${e.statusCode})');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _joinLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppTabScaffold(
      currentIndex: 2, // Home tab
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Start playing',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Join with Friend
              Text(
                'Join with Friend',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Form(
                key: _joinFormKey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _joinCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Enter room ID',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter room ID';
                          }
                          if (v.trim().length != 6) {
                            return '6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _joinLoading ? null : _joinGroup,
                        child: _joinLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Join'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Create a trip
              Text(
                'Create a trip',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Grid 2x2 ของ Custom / Bangkok / Chiang Mai / Phuket
              _TripTemplateGrid(api: widget.api),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== Trip grid 2x2 ==================

class _TripTemplateGrid extends StatelessWidget {
  final ApiService api;
  const _TripTemplateGrid({required this.api});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        const double spacing = 16;
        // 2 คอลัมน์ → (ความกว้างทั้งหมด - ช่องว่างระหว่างคอลัมน์) / 2
        final double itemWidth = (maxWidth - spacing) / 2;

        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              SizedBox(
                width: itemWidth,
                child: _PlaceCard(
                  title: 'Custom',
                  subtitle: 'Your options, your choice!',
                  assetPath: 'assets/places/custom.png',
                  location: 'Custom',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomTripCreationScreen(api: api),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _PlaceCard(
                  title: 'Salaya/Mahidol',
                  subtitle: 'Cafes, chill spots, hidden bars',
                  assetPath: 'assets/places/Mahidol.jpg',
                  location: 'Nakhon Pathom',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CityTripCreationScreen(
                          api: api,
                          city: 'Salaya-Mahidol',
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _PlaceCard(
                  title: 'Bangkok',
                  subtitle: 'Cafes, chill spots, hidden bars',
                  assetPath: 'assets/places/bangkok.png',
                  location: 'Bangkok',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CityTripCreationScreen(
                          api: api,
                          city: 'Bangkok',
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _PlaceCard(
                  title: 'Chiang Mai',
                  subtitle: 'Coffee & mountains await!',
                  assetPath: 'assets/places/chiang_mai.png',
                  location: 'Chiang Mai',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CityTripCreationScreen(
                          api: api,
                          city: 'Chiang Mai',
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _PlaceCard(
                  title: 'Phuket',
                  subtitle: 'Sea, cafes, all here!',
                  assetPath: 'assets/places/phuket.png',
                  location: 'Phuket',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CityTripCreationScreen(
                          api: api,
                          city: 'Phuket',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String assetPath;
  final String location;
  final VoidCallback? onTap;

  const _PlaceCard({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.location,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
