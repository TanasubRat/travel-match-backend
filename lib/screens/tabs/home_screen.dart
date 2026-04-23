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
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.flight_takeoff_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where to next?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Start playing',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Join Room Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.05),
                      theme.colorScheme.secondary.withOpacity(0.05)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join with Friend',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Got a room code? Enter it below!',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _joinFormKey,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _joinCodeController,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2),
                              decoration: InputDecoration(
                                hintText: 'ENTER CODE',
                                hintStyle: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    letterSpacing: 0,
                                    color: Colors.grey[400]),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.qr_code_scanner),
                                  color: theme.colorScheme.primary,
                                  onPressed: () async {
                                    final code = await Navigator.pushNamed(context, '/qr_scan');
                                    if (code != null && code is String && code.isNotEmpty) {
                                      _joinCodeController.text = code;
                                      _joinGroup();
                                    }
                                  },
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: theme.colorScheme.primary, width: 2),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter room ID';
                                }
                                if (v.trim().length != 6) {
                                  return 'Must be 6 chars';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 56,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _joinLoading ? null : _joinGroup,
                              child: _joinLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Create a trip Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Explore Destinations',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 0.85, // Taller aesthetic card
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          location.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
