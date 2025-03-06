import 'package:flutter/material.dart';
import 'dart:async';
import 'anime_scraper_screen.dart';
import 'qbittorrent_add_screen.dart';
import 'settings_screen.dart';
import 'qbittorrent_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentMessageIndex = 0;
  late Timer _messageTimer;

  // List of kawaii messages
  final List<String> _messages = [
    "Mmm... So many new releases! Let's check the lineup together and add them to your queue.",
    "Otsukaresama desu! That batch download went smoothly. Need anything else, senpai?",
    "Sugoi! Your download is almost complete.",
    "Yay, a new request! I can't wait to download it for you.",
    "Konnichiwa! Let me help you find your next favorite series!",
    "Ganbatte! I'll make sure your anime collection is organized perfectly!",
    "Ara ara~ Your watchlist is growing nicely!",
    "Kawaii desu ne! This season has so many cute shows to track!",
    "Nani?! A new episode just dropped. Should I queue it up?",
    "Baka! Don't forget to check your downloads folder!",
  ];

  @override
  void initState() {
    super.initState();
    // Setup timer to cycle through messages every 10 seconds
    _messageTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      setState(() {
        _currentMessageIndex = (_currentMessageIndex + 1) % _messages.length;
      });
    });
  }

  @override
  void dispose() {
    _messageTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MAL Pal',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate if we're in a constrained height situation
          final bool isVerticallyConstrained = constraints.maxHeight < 600;

          // Calculate image size based on available space
          final imageSize =
              isVerticallyConstrained
                  ? constraints.maxHeight *
                      0.15 // Smaller image for constrained height
                  : (constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight) *
                      0.3;

          return SingleChildScrollView(
            child: Center(
              child: Container(
                width: constraints.maxWidth,
                padding: EdgeInsets.all(isVerticallyConstrained ? 12.0 : 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with responsive sizing
                    Container(
                      width: imageSize,
                      height: imageSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(imageSize / 2),
                        child: Image.asset(
                          'assets/images/malpal_logo.webp',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: isVerticallyConstrained ? 12 : 24),
                    const Text(
                      'MAL Pal',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isVerticallyConstrained ? 6 : 12),

                    // Kawaii message that cycles every 10 seconds
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Container(
                        key: ValueKey<int>(_currentMessageIndex),
                        constraints: BoxConstraints(maxWidth: 600),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isVerticallyConstrained ? 8 : 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isLightMode
                                  ? primaryColor.withOpacity(0.08)
                                  : primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _messages[_currentMessageIndex],
                          style: TextStyle(
                            fontSize: isVerticallyConstrained ? 14 : 16,
                            fontWeight: FontWeight.w500,
                            color:
                                isLightMode
                                    ? Colors.pink[700]
                                    : Colors.pink[300],
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    SizedBox(height: isVerticallyConstrained ? 24 : 48),

                    // Navigation buttons in a constrained container
                    Container(
                      constraints: BoxConstraints(maxWidth: 600),
                      child: Column(
                        children: [
                          _buildNavigationButton(
                            context,
                            'Anime Finder',
                            Icons.search,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const AnimeScraperScreen(),
                              ),
                            ),
                            isVerticallyConstrained,
                          ),
                          SizedBox(height: isVerticallyConstrained ? 8 : 16),
                          _buildNavigationButton(
                            context,
                            'qBittorrent',
                            Icons.download,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const QBittorrentAddScreen(),
                              ),
                            ),
                            isVerticallyConstrained,
                          ),
                          SizedBox(height: isVerticallyConstrained ? 8 : 16),
                          _buildNavigationButton(
                            context,
                            'Dashboard',
                            Icons.dashboard,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        const QBittorrentDashboardScreen(),
                              ),
                            ),
                            isVerticallyConstrained,
                          ),
                          SizedBox(height: isVerticallyConstrained ? 8 : 16),
                          _buildNavigationButton(
                            context,
                            'App Settings',
                            Icons.settings,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            ),
                            isVerticallyConstrained,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
    bool isCompact,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label, style: TextStyle(fontSize: isCompact ? 14 : 16)),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 16),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
