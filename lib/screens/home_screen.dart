import 'package:flutter/material.dart';
import 'anime_scraper_screen.dart';
import 'qbittorrent_add_screen.dart';
import 'settings_screen.dart';
import 'qbittorrent_dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate image size based on screen width
    // Min size of 120, max size of 200, with a scaling factor
    final imageSize = screenWidth * 0.25.clamp(120.0, 200.0);

    return Scaffold(
      appBar: AppBar(title: const Text('MAL Pal')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Using an asset image from your project with responsive sizing
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
                    'assets/images/malpal_logo.webp', // Your image path
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'MAL Pal',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Your anime management companion',
                style: TextStyle(
                  fontSize: 16,
                  color: isLightMode ? Colors.black54 : Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Main navigation buttons
              _buildNavigationButton(
                context,
                'Anime Scraper',
                Icons.search,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnimeScraperScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildNavigationButton(
                context,
                'qBittorrent',
                Icons.download,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QBittorrentAddScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildNavigationButton(
                context,
                'qBit Dashboard',
                Icons.dashboard,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QBittorrentDashboardScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
