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
  int _currentTabIndex = 0;
  int _feedsTabIndex = 0;
  int _rulesTabIndex = 0;

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
            onTap: (index) {
              setState(() {
                _currentTabIndex = index;
              });
            },
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
                  onTabChanged: (index) {
                    setState(() {
                      _feedsTabIndex = index;
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
                  onTabChanged: (index) {
                    setState(() {
                      _rulesTabIndex = index;
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
          if (_isConnected && !_isLoading)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: _deleteAllInCurrentSeason,
              tooltip: 'Delete All in Current Season',
            ),
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

  Map<String, List<String>> _organizeBySeasonPrefix(Map<String, dynamic> items) {
    final result = <String, List<String>>{
      'winter': [],
      'spring': [],
      'summer': [],
      'fall': [],
      'other': [],
    };

    for (final name in items.keys) {
      bool matched = false;
      for (final season in ['winter', 'spring', 'summer', 'fall']) {
        final pattern = RegExp(
          '^${season.toUpperCase()}_\\d{4}_',
          caseSensitive: false,
        );
        if (pattern.hasMatch(name)) {
          result[season]!.add(name);
          matched = true;
          break;
        }
      }

      if (!matched) {
        result['other']!.add(name);
      }
    }

    // Sort by year (descending) and then alphabetically within each season
    for (final season in result.keys) {
      result[season]!.sort((a, b) {
        final yearPatternA = RegExp(r'_(\d{4})_').firstMatch(a);
        final yearPatternB = RegExp(r'_(\d{4})_').firstMatch(b);

        if (yearPatternA != null && yearPatternB != null) {
          final yearA = int.parse(yearPatternA.group(1)!);
          final yearB = int.parse(yearPatternB.group(1)!);

          if (yearA != yearB) {
            return yearB.compareTo(yearA);
          }
        }

        return a.compareTo(b);
      });
    }

    return result;
  }

  Future<void> _deleteAllInCurrentSeason() async {
    if (_qbClient == null) return;
    
    final seasonNames = ['winter', 'spring', 'summer', 'fall', 'other'];
    final String currentSeasonName;
    final Map<String, dynamic> items;
    final String itemType;
    
    if (_currentTabIndex == 0) {
      // RSS Feeds tab
      currentSeasonName = seasonNames[_feedsTabIndex];
      items = _rssFeeds;
      itemType = 'RSS FEEDS';
    } else {
      // RSS Rules tab
      currentSeasonName = seasonNames[_rulesTabIndex];
      items = _rssRules;
      itemType = 'RSS RULES';
    }
    
    final organizedItems = _organizeBySeasonPrefix(items);
    final itemsInSeason = organizedItems[currentSeasonName]!;
    
    if (itemsInSeason.isEmpty) {
      setState(() {
        _statusMessage = 'No ${itemType.toLowerCase()} to delete in this season';
      });
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete All'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete all ${itemsInSeason.length} ${itemType.toLowerCase()} in the ${currentSeasonName.toUpperCase()} season?'),
            const SizedBox(height: 16),
            Text(
              'ALL ${currentSeasonName.toUpperCase()} $itemType',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            Text('${itemType.toLowerCase().substring(0, itemType.length - 1)} to be deleted:'),
            const SizedBox(height: 8),
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView(
                children: itemsInSeason.map((item) => Text('• $item')).toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    // Delete all items in the current season
    setState(() {
      _isLoading = true;
      _statusMessage = 'Deleting ${itemsInSeason.length} ${itemType.toLowerCase()}...';
    });
    
    int deletedCount = 0;
    int failedCount = 0;
    
    for (final itemName in itemsInSeason) {
      try {
        bool success;
        if (_currentTabIndex == 0) {
          // Delete feed
          success = await _qbClient!.deleteFeed(itemName);
        } else {
          // Delete rule
          success = await _qbClient!.deleteRule(itemName);
        }
        
        if (success) {
          deletedCount++;
        } else {
          failedCount++;
        }
      } catch (e) {
        failedCount++;
        print('Error deleting ${itemType.toLowerCase().substring(0, itemType.length - 1)} $itemName: $e');
      }
    }
    
    // Refresh the data
    if (_currentTabIndex == 0) {
      _rssFeeds = await _qbClient!.getRssFeeds();
    } else {
      _rssRules = await _qbClient!.getRssRules();
    }
    
    setState(() {
      _isLoading = false;
      _statusMessage = 'Deleted $deletedCount ${itemType.toLowerCase()}, failed: $failedCount';
    });
  }

  @override
  void dispose() {
    _qbClient?.dispose();
    super.dispose();
  }
}
