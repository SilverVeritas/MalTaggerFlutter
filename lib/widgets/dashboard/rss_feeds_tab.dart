import 'package:flutter/material.dart';
import '../../services/qbittorrent_api.dart';
import 'feed_list_view.dart';

class RssFeedsTab extends StatefulWidget {
  final Map<String, dynamic> feeds;
  final QBittorrentAPI? client;
  final Function(String) onStatusUpdate;
  final Function(Map<String, dynamic>) onFeedsUpdated;

  const RssFeedsTab({
    super.key,
    required this.feeds,
    required this.client,
    required this.onStatusUpdate,
    required this.onFeedsUpdated,
  });

  @override
  State<RssFeedsTab> createState() => _RssFeedsTabState();
}

class _RssFeedsTabState extends State<RssFeedsTab>
    with TickerProviderStateMixin {
  int _currentTab = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: _currentTab,
    );
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Organize feeds by season prefix
  Map<String, List<String>> _organizeBySeasonPrefix() {
    final result = <String, List<String>>{
      'winter': [],
      'spring': [],
      'summer': [],
      'fall': [],
      'other': [],
    };

    for (final name in widget.feeds.keys) {
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

  @override
  Widget build(BuildContext context) {
    if (widget.feeds.isEmpty) {
      return const Center(
        child: Text('No RSS feeds found', style: TextStyle(fontSize: 16)),
      );
    }

    // Organize feeds by season
    final organizedFeeds = _organizeBySeasonPrefix();

    return Column(
      children: [
        Container(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.2),
          child: TabBar(
            controller: _tabController,
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
          child: IndexedStack(
            index: _currentTab,
            children: [
              FeedListView(
                category: 'winter',
                feedNames: organizedFeeds['winter']!,
                feeds: widget.feeds,
                client: widget.client,
                onStatusUpdate: widget.onStatusUpdate,
                onFeedsUpdated: widget.onFeedsUpdated,
              ),
              FeedListView(
                category: 'spring',
                feedNames: organizedFeeds['spring']!,
                feeds: widget.feeds,
                client: widget.client,
                onStatusUpdate: widget.onStatusUpdate,
                onFeedsUpdated: widget.onFeedsUpdated,
              ),
              FeedListView(
                category: 'summer',
                feedNames: organizedFeeds['summer']!,
                feeds: widget.feeds,
                client: widget.client,
                onStatusUpdate: widget.onStatusUpdate,
                onFeedsUpdated: widget.onFeedsUpdated,
              ),
              FeedListView(
                category: 'fall',
                feedNames: organizedFeeds['fall']!,
                feeds: widget.feeds,
                client: widget.client,
                onStatusUpdate: widget.onStatusUpdate,
                onFeedsUpdated: widget.onFeedsUpdated,
              ),
              FeedListView(
                category: 'other',
                feedNames: organizedFeeds['other']!,
                feeds: widget.feeds,
                client: widget.client,
                onStatusUpdate: widget.onStatusUpdate,
                onFeedsUpdated: widget.onFeedsUpdated,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
