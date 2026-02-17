import 'package:flutter/material.dart';
import '../../../service/api_service.dart';

class CityTripCreationScreen extends StatefulWidget {
  final ApiService api;
  final String city;

  const CityTripCreationScreen({
    Key? key,
    required this.api,
    required this.city,
  }) : super(key: key);

  @override
  State<CityTripCreationScreen> createState() => _TripCreationScreenState();
}

class _TripCreationScreenState extends State<CityTripCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late String _city;
  double _minRating = 0;
  int _selectedPrice = 2;
  bool _openNow = false;
  double _maxDistanceKm = 10;
  final Set<String> _selectedCategories = {'Food & Drink', 'Attraction'};

  bool _submitting = false;

  ApiService get _api => widget.api;

  @override
  void initState() {
    super.initState();
    // Normalize city name to match DropdownMenuItem values
    if (widget.city == 'Salaya-Mahidol' || widget.city == 'Mahidol/Salaya') {
      _city = 'Salaya';
    } else {
      _city = widget.city;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final filters = {
        'minRating': _minRating,
        'priceLevel': _selectedPrice,
        'categories': _selectedCategories.toList(),
        'maxDistanceKm': _maxDistanceKm,
        'openNow': _openNow,
      };

      final group = await _api.createGroupWithFilters(
        name: _nameController.text.trim(),
        city: _city,
        filters: filters,
      );

      if (!mounted) return;

      final gid = group['_id']?.toString() ?? group['id']?.toString();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room created. Share the code with friends!'),
        ),
      );

      Navigator.of(context).pushReplacementNamed(
        '/room',
        arguments: {'groupId': gid},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Trip Room'),
      ),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room Name
                Text('Room Name', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Ex. Bangkok Food Trip with Friends',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // City (default จากการ์ด, ยังเปลี่ยนได้ถ้าต้องการ)
                Text('City', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _city,
                  items: const [
                    DropdownMenuItem(
                      value: 'Salaya',
                      child: Text('Salaya'),
                    ),
                    DropdownMenuItem(
                      value: 'Bangkok',
                      child: Text('Bangkok'),
                    ),
                    DropdownMenuItem(
                      value: 'Chiang Mai',
                      child: Text('Chiang Mai'),
                    ),
                    DropdownMenuItem(
                      value: 'Phuket',
                      child: Text('Phuket'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _city = v);
                  },
                ),
                const SizedBox(height: 24),

                // Categories
                Text('Categories', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    'Food & Drink',
                    'Attraction',
                    'Shopping',
                    'Nightlife',
                    'Cafe',
                  ].map((c) {
                    final selected = _selectedCategories.contains(c);
                    return ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (on) {
                        setState(() {
                          if (on) {
                            _selectedCategories.add(c);
                          } else {
                            _selectedCategories.remove(c);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Minimum rating
                Text('Minimum rating :', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 18),
                    tickMarkShape:
                        const RoundSliderTickMarkShape(tickMarkRadius: 4),
                    activeTickMarkColor:
                        Theme.of(context).colorScheme.onPrimary,
                    inactiveTickMarkColor: Colors.grey.shade400,
                    valueIndicatorShape:
                        const PaddleSliderValueIndicatorShape(),
                    showValueIndicator: ShowValueIndicator.always,
                  ),
                  child: Slider(
                    value: _minRating,
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: _minRating.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _minRating = v),
                  ),
                ),
                const SizedBox(height: 6),
                // Labeled ticks 0..5 under the slider
                Row(
                  children: List.generate(6, (i) {
                    return Expanded(
                      child: Text(
                        i.toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Price
                Text('Price :', style: theme.textTheme.titleMedium),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (i) {
                    final priceStr = '฿' * (i + 1);
                    return ChoiceChip(
                      label: Text(priceStr),
                      selected: _selectedPrice == i,
                      onSelected: (on) {
                        if (on) setState(() => _selectedPrice = i);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Open now
                Row(
                  children: [
                    Switch(
                      value: _openNow,
                      onChanged: (v) => setState(() => _openNow = v),
                    ),
                    const SizedBox(width: 8),
                    const Text('Open now'),
                  ],
                ),
                const SizedBox(height: 24),

                // Max distance
                Text('Max Distance (km)', style: theme.textTheme.titleMedium),
                Slider(
                  value: _maxDistanceKm,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${_maxDistanceKm.round()} km',
                  onChanged: (v) => setState(() => _maxDistanceKm = v),
                ),
                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onCreate,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create & Invite Friends'),
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
