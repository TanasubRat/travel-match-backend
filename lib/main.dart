import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'service/api_service.dart';

// Tabs / screens อื่น ๆ
import 'screens/tabs/favorites_screen.dart';
import 'screens/tabs/friends_screen.dart';
import 'screens/tabs/settings_screen.dart';
import 'screens/tabs/home_screen.dart';

// Home tab
import 'screens/tabs/home_tab/trip_creation_city_screen.dart';
import 'screens/tabs/home_tab/trip_creation_custom_screen.dart';

// Room tab
import 'screens/tabs/room_tab/room_screen.dart';
import 'screens/tabs/room_tab/results_screen.dart';
import 'screens/tabs/room_tab/swipe_screen.dart' as room_swipe;

// Auth / onboarding
import 'screens/onboarding1.dart';
import 'screens/onboarding2.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/invite_friend_screen.dart';

String _defaultBaseUrl() {
  const port = 3000;
  if (kIsWeb) return 'http://localhost:$port';
  if (Platform.isAndroid) return 'http://10.0.2.2:$port';
  return 'http://localhost:$port';
}

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  late final ApiService api;

  api = ApiService(
    baseUrl: _defaultBaseUrl(),
    onUnauthorized: () async {
      await api.clearToken();
      final nav = _navKey.currentState;
      if (nav != null && nav.mounted) {
        nav.pushNamedAndRemoveUntil('/onboarding1', (_) => false);
      }
    },
  );

  await api.init();
  registerApiService(api);

  runApp(Swipetrip(api: api, navigatorKey: _navKey));
}

class Swipetrip extends StatelessWidget {
  final ApiService api;
  final GlobalKey<NavigatorState>? navigatorKey;

  const Swipetrip({
    super.key,
    required this.api,
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swipetrip',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007AFF),
          secondary: Color(0xFF5AA9FF),
          surface: Colors.white,
          background: Colors.white,
          onPrimary: Colors.white,
          onSurface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.white,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF007AFF),
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: AuthGate(api: api),
      routes: {
        // main tab (bottom nav ข้างใน)
        '/home': (_) => HomeScreen(api: api),

        // room / group overview
        '/room': (_) => const RoomScreen(),

        // อื่น ๆ ใน bottom nav
        '/friends': (_) => const FriendsScreen(),
        '/favorite': (_) => const FavoritesScreen(),
        '/setting': (_) => SettingsTab(api: api),

        // auth & onboarding
        '/onboarding1': (_) => const Onboarding1(),
        '/onboarding2': (_) => const Onboarding2(),
        '/login': (_) => LoginScreen(api: api),
        '/register': (_) => RegisterScreen(api: api),
        '/invite': (_) => InviteFriendScreen(api: api),

        '/trip_create_city': (_) => CityTripCreationScreen(
              api: api,
              city: 'Bangkok', // หรือค่า default ที่อยากให้ใช้
            ),
        '/trip_create_custom': (_) => CustomTripCreationScreen(api: api),

        // swipe: ต้องส่ง groupId ผ่าน arguments เช่นกัน
        // Navigator.pushNamed(context, '/start_swipe', arguments: {'groupId': gid});
        '/start_swipe': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final gid = args?['groupId']?.toString();
          if (gid == null || gid.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Missing groupId for SwipeScreen')),
            );
          }
          return room_swipe.SwipeScreen(groupId: gid);
        },

        // results: ResultsScreen ดึง groupId จาก arguments เช่นกัน (ไฟล์เราทำรองรับแล้ว)
        '/results': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final gid = args?['groupId']?.toString();
          return ResultsScreen(groupId: gid);
        },
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  final ApiService api;
  const AuthGate({super.key, required this.api});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _authed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final u = await widget.api.me();
      _authed = u != null;
    } catch (_) {
      _authed = false;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return _authed ? HomeScreen(api: widget.api) : const Onboarding2();
  }
}
