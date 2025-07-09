import 'package:flutter/material.dart';
import '../../services/qbittorrent_api.dart';

class FeedListView extends StatelessWidget {
  final String category;
  final List<String> feedNames;
  final Map<String, dynamic> feeds;
  final QBittorrentAPI? client;
  final Function(String) onStatusUpdate;
  final Function(Map<String, dynamic>) onFeedsUpdated;

  const FeedListView({
    super.key,
    required this.category,
    required this.feedNames,
    required this.feeds,
    required this.client,
    required this.onStatusUpdate,
    required this.onFeedsUpdated,
  });

  @override
  Widget build(BuildContext context) {
    if (feedNames.isEmpty) {
      return Center(
        child: Text(
          'No ${category == 'other' ? 'other' : category} feeds found',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: feedNames.length,
      itemBuilder: (context, index) {
        final feedName = feedNames[index];
        final feedData = feeds[feedName] as Map<String, dynamic>;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            title: Text(
              feedName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('URL: ${feedData['url'] ?? 'N/A'}'),
                Text('Last Build Date: ${feedData['lastBuildDate'] ?? 'N/A'}'),
                Text('Articles: ${feedData['articles']?.length ?? 0}'),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'refresh':
                    await _refreshFeed(feedName);
                    break;
                  case 'delete':
                    await _deleteFeed(feedName);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Refresh'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () {
              _showFeedDetails(context, feedName, feedData);
            },
          ),
        );
      },
    );
  }

  Future<void> _refreshFeed(String feedName) async {
    if (client == null) return;
    
    try {
      onStatusUpdate('Refreshing feed: $feedName');
      await client!.refreshItem(feedName);
      
      // Refresh the feeds list
      final updatedFeeds = await client!.getRssFeeds();
      onFeedsUpdated(updatedFeeds);
      
      onStatusUpdate('Feed refreshed successfully');
    } catch (e) {
      onStatusUpdate('Error refreshing feed: $e');
    }
  }

  Future<void> _deleteFeed(String feedName) async {
    if (client == null) return;
    
    try {
      onStatusUpdate('Deleting feed: $feedName');
      await client!.deleteFeed(feedName);
      
      // Refresh the feeds list
      final updatedFeeds = await client!.getRssFeeds();
      onFeedsUpdated(updatedFeeds);
      
      onStatusUpdate('Feed deleted successfully');
    } catch (e) {
      onStatusUpdate('Error deleting feed: $e');
    }
  }

  void _showFeedDetails(BuildContext context, String feedName, Map<String, dynamic> feedData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feedName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('URL: ${feedData['url'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Last Build Date: ${feedData['lastBuildDate'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Articles: ${feedData['articles']?.length ?? 0}'),
              const SizedBox(height: 16),
              const Text('Recent Articles:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...((feedData['articles'] as List?)?.take(5).map((article) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${article['title'] ?? 'No title'}'),
                )
              ) ?? [const Text('No articles')]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}