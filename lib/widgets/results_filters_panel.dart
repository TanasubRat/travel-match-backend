import 'package:flutter/material.dart';

class ResultsFilters {
  final String sort; // 'best', 'distance', 'price'
  final Set<String> types; // e.g., ['cafe','restaurant','park']

  const ResultsFilters({this.sort = 'best', this.types = const {}});

  ResultsFilters copyWith({String? sort, Set<String>? types}) =>
      ResultsFilters(sort: sort ?? this.sort, types: types ?? this.types);
}

Future<ResultsFilters?> showResultsFiltersSheet(
  BuildContext context, {
  ResultsFilters initial = const ResultsFilters(),
  List<String> availableTypes = const ['cafe','restaurant','park'],
}) {
  return showModalBottomSheet<ResultsFilters>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ResultsFiltersSheet(initial: initial, availableTypes: availableTypes),
  );
}

class _ResultsFiltersSheet extends StatefulWidget {
  final ResultsFilters initial;
  final List<String> availableTypes;
  const _ResultsFiltersSheet({required this.initial, required this.availableTypes});

  @override
  State<_ResultsFiltersSheet> createState() => _ResultsFiltersSheetState();
}

class _ResultsFiltersSheetState extends State<_ResultsFiltersSheet> {
  late ResultsFilters _filters = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sort by', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in ['best','distance','price'])
                ChoiceChip(
                  selected: _filters.sort == s,
                  label: Text(s.capitalize()),
                  onSelected: (_) => setState(() => _filters = _filters.copyWith(sort: s)),
                )
            ],
          ),
          const SizedBox(height: 16),
          Text('Types', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in widget.availableTypes)
                FilterChip(
                  selected: _filters.types.contains(t),
                  label: Text(t.capitalize()),
                  onSelected: (on) {
                    final next = Set<String>.from(_filters.types);
                    on ? next.add(t) : next.remove(t);
                    setState(() => _filters = _filters.copyWith(types: next));
                  },
                )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, const ResultsFilters()),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _filters),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

extension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}