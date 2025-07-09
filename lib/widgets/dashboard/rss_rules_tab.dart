import 'package:flutter/material.dart';
import '../../services/qbittorrent_api.dart';

class RssRulesTab extends StatefulWidget {
  final Map<String, dynamic> rules;
  final QBittorrentAPI? client;
  final Function(String) onStatusUpdate;
  final Function(Map<String, dynamic>) onRulesUpdated;
  final Function(int)? onTabChanged;

  const RssRulesTab({
    super.key,
    required this.rules,
    required this.client,
    required this.onStatusUpdate,
    required this.onRulesUpdated,
    this.onTabChanged,
  });

  @override
  State<RssRulesTab> createState() => _RssRulesTabState();
}

class _RssRulesTabState extends State<RssRulesTab> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
      widget.onTabChanged?.call(_tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, List<String>> _organizeBySeasonPrefix() {
    final result = <String, List<String>>{
      'winter': [],
      'spring': [],
      'summer': [],
      'fall': [],
      'other': [],
    };

    for (final name in widget.rules.keys) {
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

  @override
  Widget build(BuildContext context) {
    if (widget.rules.isEmpty) {
      return const Center(
        child: Text('No RSS rules found', style: TextStyle(fontSize: 16)),
      );
    }

    final organizedRules = _organizeBySeasonPrefix();

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
          child: TabBarView(
            controller: _tabController,
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
        final ruleData = widget.rules[ruleName];

        final namePattern = RegExp(
          r'^(?:(WINTER|SPRING|SUMMER|FALL)_(\d{4})_)?(.*?)$',
          caseSensitive: false,
        );
        final match = namePattern.firstMatch(ruleName);

        final String season = match?.group(1)?.toLowerCase() ?? '';
        final String year = match?.group(2) ?? '';
        final String title = match?.group(3) ?? ruleName;

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
            side: BorderSide(
              color: seasonColor.withValues(alpha: 0.5),
              width: 1,
            ),
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
                      color: seasonColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: seasonColor.withValues(alpha: 0.3),
                      ),
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
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.8),
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

  Future<void> _deleteRule(String ruleName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    ) ?? false;

    if (!confirmed) return;

    widget.onStatusUpdate('Deleting rule...');

    try {
      final success = await widget.client!.deleteRule(ruleName);

      if (success) {
        final updatedRules = Map<String, dynamic>.from(widget.rules);
        updatedRules.remove(ruleName);
        widget.onRulesUpdated(updatedRules);
        widget.onStatusUpdate('Rule deleted successfully');
      } else {
        widget.onStatusUpdate('Failed to delete rule');
      }
    } catch (e) {
      widget.onStatusUpdate('Error deleting rule: $e');
    }
  }

}