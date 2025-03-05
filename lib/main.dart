import 'package:flutter/material.dart';
import './screens/home_screen.dart';
import './screens/anime_scraper_screen.dart';
import './screens/qbittorrent_add_screen.dart';
import './screens/qbittorrent_dashboard_screen.dart';
import './screens/settings_screen.dart';
import './services/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'Anime Tracker',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness:
                  appState.isDarkMode ? Brightness.dark : Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MainNavigationScreen(),
          routes: {
            '/anime_library':
                (context) =>
                    const HomeScreen(), // Update this to the correct screen
            '/anime_scraper': (context) => const AnimeScraperScreen(),
            '/qbittorrent_add': (context) => const QBittorrentAddScreen(),
            '/qbittorrent_dashboard':
                (context) => const QBittorrentDashboardScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    const HomeScreen(),
    const AnimeScraperScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
