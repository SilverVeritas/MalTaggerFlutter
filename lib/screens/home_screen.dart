import 'package:flutter/material.dart';
import '../models/anime.dart';
import 'anime_scraper_screen.dart';
import 'qbittorrent_add_screen.dart';
import 'settings_screen.dart';
import 'dashboard_screen.dart'; // Import the new dashboard screen

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anime Tracker')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or icon
              Icon(
                Icons.live_tv,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Anime Tracker',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),

              // Main navigation buttons
              _buildNavigationButton(
                context,
                'Anime Library',
                Icons.collections_bookmark,
                () => Navigator.pushNamed(context, '/anime_library'),
              ),
              const SizedBox(height: 16),
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

class AnimeListItem extends StatelessWidget {
  final Anime anime;

  const AnimeListItem({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: Image.network(
          anime.imageUrl,
          width: 50,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        ),
        title: Text(anime.title),
        subtitle: Text(
          'Episodes: ${anime.episodes}\n'
          'Status: ${anime.status}',
        ),
        isThreeLine: true,
      ),
    );
  }
}
