import 'package:flutter/material.dart';
import '../../widgets/app_tab_scaffold.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppTabScaffold(
      currentIndex: 0, // Friends tab
      appBar: AppBar(
        title: const Text('Friends'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_outlined, size: 84),
              const SizedBox(height: 12),
              Text(
                'Find your friends',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create or join a room and start swiping together.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/invite'),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Invite your friends'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
