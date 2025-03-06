import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> _deleteFeed(String feedName) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Confirm Delete'),
                content: Text(
                  'Are you sure you want to delete feed "$feedName"?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Deleting feed...';
    });

    try {
      final success = await _qbClient!.deleteFeed(feedName);

      if (success) {
        setState(() {
          // Remove from local state
          _rssFeeds.remove(feedName);
          _statusMessage = 'Feed deleted successfully';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feed "$feedName" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _statusMessage = 'Failed to delete feed';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete feed "$feedName"'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting feed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRule(String ruleName) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Confirm Delete'),
                content: Text(
                  'Are you sure you want to delete rule "$ruleName"?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Deleting rule...';
    });

    try {
      final success = await _qbClient!.deleteRule(ruleName);

      if (success) {
        setState(() {
          // Remove from local state
          _rssRules.remove(ruleName);
          _statusMessage = 'Rule deleted successfully';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rule "$ruleName" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _statusMessage = 'Failed to delete rule';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete rule "$ruleName"'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting rule: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to organize items by season prefix
  Map<String, List<String>> _organizeBySeasonPrefix(
    Map<String, dynamic> items,
  ) {
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
        // Try to extract year for season-based sorting
        final yearPatternA = RegExp(r'_(\d{4})_').firstMatch(a);
        final yearPatternB = RegExp(r'_(\d{4})_').firstMatch(b);

        if (yearPatternA != null && yearPatternB != null) {
          final yearA = int.parse(yearPatternA.group(1)!);
          final yearB = int.parse(yearPatternB.group(1)!);

          if (yearA != yearB) {
            return yearB.compareTo(yearA); // Descending by year
          }
        }

        return a.compareTo(b); // Alphabetical
      });
    }

    return result;
  }

  Future<void> _refreshFeed(String feedName) async {
    setState(() {
      _statusMessage = 'Refreshing feed...';
    });

    try {
      // Changed refreshFeed to refreshItem to match the API method name
      final success = await _qbClient!.refreshItem(feedName);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feed "$feedName" refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh feed "$feedName"'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing feed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _statusMessage = 'Connected to qBittorrent';
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
          TabBar(
            tabs: const [Tab(text: 'RSS Feeds'), Tab(text: 'RSS Rules')],
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [_buildRssFeedsTab(), _buildRssRulesTab()],
            ),
          ),
          // Status bar at the bottom
          Container(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.2),
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

  Widget _buildRssFeedsTab() {
    if (_rssFeeds.isEmpty) {
      return const Center(
        child: Text('No RSS feeds found', style: TextStyle(fontSize: 16)),
      );
    }

    // Organize feeds by season
    final organizedFeeds = _organizeBySeasonPrefix(_rssFeeds);

    // Build tabs for each season and 'other'
    return DefaultTabController(
      length: 5, // winter, spring, summer, fall, other
      child: Column(
        children: [
          Container(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.2),
            child: TabBar(
              isScrollable: true,
              tabs: const [
                Tab(text: 'Winter'),
                Tab(text: 'Spring'),
                Tab(text: 'Summer'),
                Tab(text: 'Fall'),
                Tab(text: 'Other'),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFeedsListView(organizedFeeds['winter']!),
                _buildFeedsListView(organizedFeeds['spring']!),
                _buildFeedsListView(organizedFeeds['summer']!),
                _buildFeedsListView(organizedFeeds['fall']!),
                _buildFeedsListView(organizedFeeds['other']!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedsListView(List<String> feedNames) {
    if (feedNames.isEmpty) {
      return const Center(
        child: Text(
          'No feeds in this category',
          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      itemCount: feedNames.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final feedName = feedNames[index];
        final feedData = _rssFeeds[feedName];

        // Extract season, year and title for better display
        final namePattern = RegExp(
          r'^(?:(WINTER|SPRING|SUMMER|FALL)_(\d{4})_)?(.*?)$',
          caseSensitive: false,
        );
        final match = namePattern.firstMatch(feedName);

        final String season = match?.group(1)?.toLowerCase() ?? '';
        final String year = match?.group(2) ?? '';
        final String title = match?.group(3) ?? feedName;

        // Create a color based on the season
        Color seasonColor;
        switch (season) {
          case 'winter':
            seasonColor = Colors.lightBlue;
            break;
          case 'spring':
            seasonColor = Colors.green;
            break;
          case 'summer':
            seasonColor = Colors.orange;
            break;
          case 'fall':
            seasonColor = Colors.brown;
            break;
          default:
            seasonColor = Colors.grey;
            break;
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: seasonColor.withOpacity(0.5), width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (season.isNotEmpty && year.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: seasonColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: seasonColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${season.toUpperCase()} $year',
                      style: TextStyle(
                        fontSize: 12,
                        color: seasonColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'URL: ${feedData?['url'] ?? 'No URL'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Feed',
                  onPressed: () => _refreshFeed(feedName),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete Feed',
                  onPressed: () => _deleteFeed(feedName),
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
      return const Center(
        child: Text('No RSS rules found', style: TextStyle(fontSize: 16)),
      );
    }

    // Organize rules by season
    final organizedRules = _organizeBySeasonPrefix(_rssRules);

    // Build tabs for each season and 'other'
    return DefaultTabController(
      length: 5, // winter, spring, summer, fall, other
      child: Column(
        children: [
          Container(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.2),
            child: TabBar(
              isScrollable: true,
              tabs: const [
                Tab(text: 'Winter'),
                Tab(text: 'Spring'),
                Tab(text: 'Summer'),
                Tab(text: 'Fall'),
                Tab(text: 'Other'),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRulesListView(organizedRules['winter']!),
                _buildRulesListView(organizedRules['spring']!),
                _buildRulesListView(organizedRules['summer']!),
                _buildRulesListView(organizedRules['fall']!),
                _buildRulesListView(organizedRules['other']!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesListView(List<String> ruleNames) {
    if (ruleNames.isEmpty) {
      return const Center(
        child: Text(
          'No rules in this category',
          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      itemCount: ruleNames.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final ruleName = ruleNames[index];
        final ruleData = _rssRules[ruleName];

        // Extract season, year and title for better display
        final namePattern = RegExp(
          r'^(?:(WINTER|SPRING|SUMMER|FALL)_(\d{4})_)?(.*?)$',
          caseSensitive: false,
        );
        final match = namePattern.firstMatch(ruleName);

        final String season = match?.group(1)?.toLowerCase() ?? '';
        final String year = match?.group(2) ?? '';
        final String title = match?.group(3) ?? ruleName;

        // Create a color based on the season
        Color seasonColor;
        switch (season) {
          case 'winter':
            seasonColor = Colors.lightBlue;
            break;
          case 'spring':
            seasonColor = Colors.green;
            break;
          case 'summer':
            seasonColor = Colors.orange;
            break;
          case 'fall':
            seasonColor = Colors.brown;
            break;
          default:
            seasonColor = Colors.grey;
            break;
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: seasonColor.withOpacity(0.5), width: 1),
          ),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (season.isNotEmpty && year.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: seasonColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: seasonColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${season.toUpperCase()} $year',
                      style: TextStyle(
                        fontSize: 12,
                        color: seasonColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              'Must Contain: ${(ruleData?['mustContain'] ?? '').isEmpty ? 'Not specified' : ruleData!['mustContain']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Rule',
              onPressed: () => _deleteRule(ruleName),
            ),
            childrenPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            children: [
              // Rule details
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRuleDetailRow(
                    'Episode Filter:',
                    ruleData?['episodeFilter'] ?? 'All',
                  ),
                  if (ruleData?['savePath'] != null &&
                      ruleData!['savePath'].toString().isNotEmpty)
                    _buildRuleDetailRow('Save Path:', ruleData['savePath']),
                  if (ruleData?['assignedCategory'] != null &&
                      ruleData!['assignedCategory'].toString().isNotEmpty)
                    _buildRuleDetailRow(
                      'Category:',
                      ruleData['assignedCategory'],
                    ),
                  if (ruleData?['affectedFeeds'] != null)
                    _buildRuleDetailRow(
                      'Feeds:',
                      (ruleData!['affectedFeeds'] as List).join(', '),
                    ),
                  if (ruleData?['addPaused'] != null)
                    _buildRuleDetailRow(
                      'Add Paused:',
                      ruleData!['addPaused'] ? 'Yes' : 'No',
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRuleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _qbClient?.dispose();
    super.dispose();
  }
}
