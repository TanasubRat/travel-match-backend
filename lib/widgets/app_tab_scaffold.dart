import 'package:flutter/material.dart';

class AppTabScaffold extends StatelessWidget {
  final int currentIndex;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final EdgeInsetsGeometry padding;
  final Map<int, WidgetBuilder>? fallbackBuilders;

  const AppTabScaffold({
    super.key,
    required this.currentIndex,
    required this.body,
    this.appBar,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 24),
    this.fallbackBuilders,
  });

  static const _routeByIndex = <int, String>{
    0: '/friends',
    1: '/room',
    2: '/home',
    3: '/favorite',
    4: '/setting',
  };

  void _onNavTap(BuildContext context, int i) {
    if (i == currentIndex) return;
    final route = _routeByIndex[i]!;
    try {
      Navigator.pushReplacementNamed(context, route);
    } catch (_) {
      final builder = fallbackBuilders?[i];
      if (builder != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: builder));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: (i) => _onNavTap(context, i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined), label: 'Friends'),
          BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_outlined), label: 'Room'),
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border), label: 'Favorite'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: 'Setting'),
        ],
      ),
      body: SafeArea(child: Padding(padding: padding, child: body)),
    );
  }
}
