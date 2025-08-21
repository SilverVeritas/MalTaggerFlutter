// File: lib/main.dart
import 'package:flutter/material.dart';
import './screens/home_screen.dart';
import './screens/anime_scraper_screen.dart';
import './screens/qbittorrent_add_screen.dart';
import './screens/qbittorrent_dashboard_screen.dart';
import './screens/anime_download_screen.dart';
import './screens/settings_screen.dart';
import './services/app_state.dart';
import 'package:provider/provider.dart';
import './utils/text_size_utils.dart';

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
        // Define custom colors
        const primaryColor = Color(0xFF2e51a2);
        final darkBgColor = const Color(0xFF1a1f2e);
        final lightBgColor = const Color(0xFFf0f2f7);

        return MaterialApp(
          title: 'MAL Pal', // Updated app name
          // Apply text scaling based on user preference
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: context.getTextScaler(appState.textSizePreference),
              ),
              child: child!,
            );
          },
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              brightness: Brightness.light,
              primary: primaryColor,
              primaryContainer: primaryColor.withValues(alpha: 0.2),
              secondary: const Color(0xFF2e6ea2),
              background: lightBgColor,
              surface: Colors.white,
            ),
            scaffoldBackgroundColor: lightBgColor,
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              brightness: Brightness.dark,
              primary: primaryColor,
              primaryContainer: primaryColor.withValues(alpha: 0.2),
              secondary: const Color(0xFF2e6ea2),
              background: darkBgColor,
              surface: const Color(0xFF252b3d),
              onBackground: Colors.white.withValues(alpha: 0.9),
              onSurface: Colors.white.withValues(alpha: 0.9),
            ),
            scaffoldBackgroundColor: darkBgColor,
            cardColor: const Color(0xFF252b3d),
            appBarTheme: AppBarTheme(
              backgroundColor: primaryColor.withValues(alpha: 0.8),
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            useMaterial3: true,
          ),
          themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MainNavigationScreen(),
          routes: {
            '/anime_scraper': (context) => const AnimeScraperScreen(),
            '/qbittorrent_add': (context) => const QBittorrentAddScreen(),
            '/qbittorrent_dashboard':
                (context) => const QBittorrentDashboardScreen(),
            '/anime_download': (context) => const AnimeDownloadScreen(),
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
    // Get the primary color from theme
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF252b3d)
                : Colors.white,
        indicatorColor: primaryColor.withValues(alpha: 0.2),
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
            ),
            selectedIcon: Icon(Icons.home, color: primaryColor),
            label: 'Home', // Changed from 'Library' to 'Home'
          ),
          NavigationDestination(
            icon: Icon(
              Icons.search_outlined,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
            ),
            selectedIcon: Icon(Icons.search, color: primaryColor),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
            ),
            selectedIcon: Icon(Icons.settings, color: primaryColor),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
