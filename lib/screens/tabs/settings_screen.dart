import 'package:flutter/material.dart';
import '../../service/api_service.dart';
import '../../widgets/app_tab_scaffold.dart';

/// ใช้ตัวนี้ได้เลย: มี BottomNav ในตัว
class SettingsTab extends StatelessWidget {
  final ApiService api;
  const SettingsTab({super.key, required this.api});

  Future<void> _logout(BuildContext context) async {
    try {
      await api.logout();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Logged out')));
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/onboarding2', (_) => false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTabScaffold(
      currentIndex: 4, // Setting tab
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profile'),
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  onTap: () => Navigator.pushNamed(context, '/privacy'),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms & Conditions'),
                  onTap: () => Navigator.pushNamed(context, '/terms'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}
