import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_state.dart';
import '../services/qbittorrent_api.dart';

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
          const TabBar(tabs: [Tab(text: 'RSS Feeds'), Tab(text: 'RSS Rules')]),
          Expanded(
            child: TabBarView(
              children: [_buildRssFeedsTab(), _buildRssRulesTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRssFeedsTab() {
    if (_rssFeeds.isEmpty) {
      return const Center(child: Text('No RSS feeds found'));
    }

    return ListView.builder(
      itemCount: _rssFeeds.length,
      itemBuilder: (context, index) {
        final feedName = _rssFeeds.keys.elementAt(index);
        final feedData = _rssFeeds[feedName];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(feedName),
            subtitle: Text('URL: ${feedData?['url'] ?? 'No URL'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Feed',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Refreshing feed: $feedName')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Feed',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete feed: $feedName')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRssRulesTab() {
    if (_rssRules.isEmpty) {
      return const Center(child: Text('No RSS rules found'));
    }

    return ListView.builder(
      itemCount: _rssRules.length,
      itemBuilder: (context, index) {
        final ruleName = _rssRules.keys.elementAt(index);
        final ruleData = _rssRules[ruleName];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(ruleName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Must Contain: ${ruleData?['mustContain'] ?? 'Not specified'}',
                ),
                Text('Episodes: ${ruleData?['episodeFilter'] ?? 'All'}'),
                if (ruleData?['affectedFeeds'] != null)
                  Text(
                    'Feed: ${(ruleData!['affectedFeeds'] as List).join(', ')}',
                  ),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Rule',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Delete rule: $ruleName')),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _qbClient?.dispose();
    super.dispose();
  }
}
