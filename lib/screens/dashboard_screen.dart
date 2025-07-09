import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/qbittorrent_api.dart';
import '../widgets/dashboard/rss_feeds_tab.dart';
import '../widgets/dashboard/rss_rules_tab.dart';

class QBittorrentDashboardScreen extends StatefulWidget {
  const QBittorrentDashboardScreen({super.key});

  @override
  State<QBittorrentDashboardScreen> createState() =>
      _QBittorrentDashboardScreenState();
}

class _QBittorrentDashboardScreenState
    extends State<QBittorrentDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _rssFeeds = {};
  Map<String, dynamic> _rssRules = {};
  String _statusMessage = 'Loading...';
  bool _isConnected = false;
  QBittorrentAPI? _qbClient;

  @override
  void initState() {
    super.initState();
    _initializeQBittorrent();
  }

  Future<void> _initializeQBittorrent() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('qb_host') ?? '';
    final username = prefs.getString('qb_username') ?? '';
    final password = prefs.getString('qb_password') ?? '';

    if (host.isEmpty) {
      setState(() {
        _isLoading = false;
        _statusMessage =
            'qBittorrent host not configured. Please check settings.';
        _isConnected = false;
      });
      return;
    }

    _qbClient = QBittorrentAPI(
      host: host,
      username: username,
      password: password,
    );

    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to qBittorrent...';
    });

    try {
      if (_qbClient == null) {
        await _initializeQBittorrent();
        return;
      }

      // Login
      final loggedIn = await _qbClient!.login();
      if (!loggedIn) {
        setState(() {
          _isLoading = false;
          _statusMessage =
              'Failed to authenticate with qBittorrent. Please check your credentials.';
          _isConnected = false;
        });
        return;
      }

      // Get version to confirm connection
      final version = await _qbClient!.getAppVersion();

      // Fetch RSS feeds
      setState(() {
        _statusMessage = 'Loading RSS feeds...';
      });
      _rssFeeds = await _qbClient!.getRssFeeds();

      // Fetch RSS rules
      setState(() {
        _statusMessage = 'Loading RSS rules...';
      });
      _rssRules = await _qbClient!.getRssRules();

      setState(() {
        _isLoading = false;
        _statusMessage = 'Connected to qBittorrent $version';
        _isConnected = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
        _isConnected = false;
      });
    }
  }

  Widget _buildConnectionError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 72, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            onPressed: _refreshData,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [Tab(text: 'RSS Feeds'), Tab(text: 'RSS Rules')],
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                RssFeedsTab(
                  feeds: _rssFeeds,
                  client: _qbClient,
                  onStatusUpdate: (message) {
                    setState(() {
                      _statusMessage = message;
                    });
                  },
                  onFeedsUpdated: (feeds) {
                    setState(() {
                      _rssFeeds = feeds;
                    });
                  },
                ),
                RssRulesTab(
                  rules: _rssRules,
                  client: _qbClient,
                  onStatusUpdate: (message) {
                    setState(() {
                      _statusMessage = message;
                    });
                  },
                  onRulesUpdated: (rules) {
                    setState(() {
                      _rssRules = rules;
                    });
                  },
                ),
              ],
            ),
          ),
          // Status bar at the bottom
          Container(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('qBittorrent Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_statusMessage),
                  ],
                ),
              )
              : _isConnected
              ? _buildDashboardContent()
              : _buildConnectionError(),
    );
  }

  @override
  void dispose() {
    _qbClient?.dispose();
    super.dispose();
  }
}
