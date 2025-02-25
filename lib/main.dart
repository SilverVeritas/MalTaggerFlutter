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
    final isDarkMode = Provider.of<AppState>(context).isDarkMode;
    
    return MaterialApp(
      title: 'Anime Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E), // Indigo 900
          brightness: Brightness.dark,
          primary: const Color(0xFF3949AB),   // Indigo 600
          secondary: const Color(0xFF5C6BC0), // Indigo 400
          surface: const Color(0xFF0D1B2A),  // Dark blue surface
          background: const Color(0xFF0D1B2A), // Dark blue background
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        cardColor: const Color(0xFF1E293B),  // Slightly lighter dark blue
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
      routes: {
        '/anime_scraper': (context) => const AnimeScraperScreen(),
        '/qbittorrent_add': (context) => const QBittorrentAddScreen(),
        '/qbittorrent_dashboard': (context) => const QBittorrentDashboardScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
