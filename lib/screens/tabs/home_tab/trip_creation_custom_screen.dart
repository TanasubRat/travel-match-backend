import 'package:flutter/material.dart';
import '../../../service/api_service.dart';

class CustomTripCreationScreen extends StatefulWidget {
  final ApiService api;

  const CustomTripCreationScreen({
    super.key,
    required this.api,
  });

  @override
  State<CustomTripCreationScreen> createState() =>
      _CustomTripCreationScreenState();
}

class _CustomTripCreationScreenState extends State<CustomTripCreationScreen> {
  final _titleController = TextEditingController(text: 'Lets go!!!');
  final _optionController = TextEditingController();

  final List<String> _cities = const [
    'Mahidol/Salaya',
    'Bangkok',
    'Chiang Mai',
    'Phuket',
  ];

  String? _selectedCity = 'Mahidol/Salaya';

  List<Map<String, dynamic>> _places = [];
  final List<String> _selectedOptions = [];

  bool _loadingPlaces = false;
  bool _creating = false;

  ApiService get _api => globalApi;

  @override
  void initState() {
    super.initState();
    _loadPlacesForCity(_selectedCity!);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _optionController.dispose();
    super.dispose();
  }

  // ---------- Load places by city (province) ----------

  Future<void> _loadPlacesForCity(String city) async {
    setState(() {
      _loadingPlaces = true;
      _places = [];
    });

    try {
      // Normalize some alternate names to the canonical city used in DB
      final queryCity = (city == 'Mahidol/Salaya' || city == 'Salaya-Mahidol')
          ? 'Salaya'
          : city;

      // Use helper from ApiService if available
      List<dynamic> resp;
      try {
        resp = await _api.getPlaces(location: queryCity);
      } catch (_) {
        // fallback: call raw endpoint if helper fails
        resp = await _api.rawGet('/api/places', query: {'location': queryCity});
      }

      final list = resp
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (e) => Map<String, dynamic>.from(e),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _places = list;
        _loadingPlaces = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPlaces = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load places: $e')),
      );
    }
  }

  // ---------- Manage options list ----------

  void _addOption(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_selectedOptions.contains(trimmed)) return;

    setState(() {
      _selectedOptions.add(trimmed);
    });
  }

  void _removeOptionAt(int index) {
    if (index < 0 || index >= _selectedOptions.length) return;
    setState(() {
      _selectedOptions.removeAt(index);
    });
  }

  void _onTapPlace(Map<String, dynamic> place) {
    final name = (place['name'] ??
            place['title'] ??
            place['placeName'] ??
            place['display_name'] ??
            '')
        .toString();
    if (name.isEmpty) return;
    _addOption(name);
  }

  // ---------- Create Trip ----------

  Future<void> _createTrip() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter trip title.')),
      );
      return;
    }
    if (_selectedOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one option.')),
      );
      return;
    }

    setState(() => _creating = true);

    try {
      // ส่งตามโครงเล่ม: name + city + options
      final body = {
        'name': title,
        if (_selectedCity != null) 'city': _selectedCity,
        'options': _selectedOptions,
      };

      final resp = await _api.rawPost('/api/groups', body: body);
      final map = Map<String, dynamic>.from(resp as Map);

      final gid = (map['groupId'] ??
              map['_id'] ??
              (map['group'] is Map ? map['group']['_id'] : null))
          ?.toString();

      if (gid != null) {
        await _api.setMyGroupId(gid);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip created.')),
      );

      // ไปหน้า Room ดูการ์ด group ตาม flow
      Navigator.of(context).pushNamedAndRemoveUntil('/room', (route) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.isNotEmpty
                ? e.message
                : 'Create failed (HTTP ${e.statusCode})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Custom'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Custom Swipetrip',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your options, yours choice!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Title',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Trip title',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFF007AFF),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // City / Province selector
                    Text(
                      'Select city / province',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCity,
                          isExpanded: true,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedCity = value;
                            });
                            _loadPlacesForCity(value);
                          },
                          items: _cities
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info text
                    Text(
                      'Add swiping options',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'For an optimal experience, choose places below or add your own.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Manual add option row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _optionController,
                            decoration: InputDecoration(
                              hintText: 'Option',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final text = _optionController.text.trim();
                            if (text.isEmpty) return;
                            _addOption(text);
                            _optionController.clear();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Suggested places from selected city
                    if (_loadingPlaces)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: LinearProgressIndicator(),
                      )
                    else if (_places.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Places in ${_selectedCity ?? ''}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _places.map((p) {
                              final name = (p['name'] ??
                                      p['title'] ??
                                      p['placeName'] ??
                                      '')
                                  .toString();
                              if (name.isEmpty) return const SizedBox.shrink();
                              final selected = _selectedOptions.contains(name);
                              return ChoiceChip(
                                label: Text(name),
                                selected: selected,
                                onSelected: (_) => _onTapPlace(p),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Selected options list
                    if (_selectedOptions.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your swiping options',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_selectedOptions.length, (index) {
                            final label = _selectedOptions[index];
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${index + 1}. ',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _removeOptionAt(index),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 8),
                              ],
                            );
                          }),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Create Trip button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _creating ? null : _createTrip,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _creating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create Trip'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
