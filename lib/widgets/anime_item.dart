import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/anime.dart';
import '../services/app_state.dart';
import '../services/rss_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class AnimeItem extends StatefulWidget {
  final Anime anime;
  final int index;
  
  const AnimeItem({
    super.key,
    required this.anime,
    required this.index,
  });

  @override
  State<AnimeItem> createState() => _AnimeItemState();
}

class _AnimeItemState extends State<AnimeItem> {
  late TextEditingController _titleController;
  late TextEditingController _rssController;
  late String _fansubber;
  bool _isValidating = false;
  
  @override
  void initState() {
    super.initState();
    _initControllers();
  }
  
  @override
  void didUpdateWidget(AnimeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers when the anime changes (e.g., after sorting)
    if (oldWidget.anime != widget.anime || oldWidget.index != widget.index) {
      _disposeControllers();
      _initControllers();
    }
  }
  
  void _initControllers() {
    final appState = Provider.of<AppState>(context, listen: false);
    _titleController = TextEditingController(
      text: appState.getEditedTitle(widget.anime.title, widget.index),
    );
    _rssController = TextEditingController(
      text: appState.getEditedRssUrl(widget.anime.title, widget.index, widget.anime.rssUrl),
    );
    _fansubber = appState.getFansubber(widget.anime.title, widget.index, widget.anime.fansubber);
  }
  
  void _disposeControllers() {
    _titleController.dispose();
    _rssController.dispose();
  }
  
  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }
  
  // Update RSS URL when fansubber changes
  void _updateRssUrlFromFansubber(String newFansubber, AppState appState) {
    final newRssUrl = RssUtils.formatRssUrl(_titleController.text, newFansubber);
    setState(() {
      _fansubber = newFansubber;
      _rssController.text = newRssUrl;
    });
    
    // Update in app state
    appState.updateAnimeFansubber(widget.anime.title, newFansubber, widget.index);
    appState.updateAnimeRssUrl(widget.anime.title, newRssUrl, widget.index);
  }
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate image dimensions while maintaining aspect ratio
    final imageWidth = screenWidth > 600 ? 200.0 : screenWidth * 0.35;
    final imageHeight = imageWidth * 1.42; // 423:600 aspect ratio
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and score row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.anime.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.black87),
                      const SizedBox(width: 4),
                      Text(
                        widget.anime.score > 0 ? widget.anime.score.toString() : 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Main content row with image and details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                if (widget.anime.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.network(
                      widget.anime.imageUrl,
                      width: imageWidth,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: imageWidth,
                          height: imageHeight,
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 50, color: Colors.white70),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(Icons.calendar_today, 'Aired', widget.anime.date),
                      _buildDetailRow(Icons.tv, 'Episodes', '${widget.anime.episodes} eps'),
                      _buildDetailRow(Icons.category, 'Type', widget.anime.type),
                      _buildDetailRow(Icons.source, 'Source', widget.anime.source),
                      _buildDetailRow(Icons.people, 'Members', widget.anime.members.toString()),
                      _buildDetailRow(Icons.movie_filter, 'Status', widget.anime.status),
                      
                      const SizedBox(height: 8),
                      
                      // Genres
                      if (widget.anime.genres.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.anime.genres.map((genre) {
                            return Chip(
                              label: Text(
                                genre,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            // Synopsis
            const Text(
              'Synopsis',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.anime.synopsis,
              style: const TextStyle(fontSize: 14),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(widget.anime.title),
                    content: SingleChildScrollView(
                      child: Text(widget.anime.synopsis),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Read More'),
            ),
            
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            
            // RSS Configuration
            const Text(
              'RSS Configuration',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            
            // Fansubber dropdown
            Row(
              children: [
                const Text('Fansubber: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _fansubber,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'asw', child: Text('ASW')),
                      DropdownMenuItem(value: 'ember', child: Text('Ember')),
                      DropdownMenuItem(value: 'judas', child: Text('Judas')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _updateRssUrlFromFansubber(value, appState);
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // RSS URL field
            TextField(
              controller: _rssController,
              decoration: InputDecoration(
                labelText: 'RSS URL',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Validate RSS',
                  onPressed: () => _validateRss(appState),
                ),
              ),
              onChanged: (value) {
                appState.updateAnimeRssUrl(
                  widget.anime.title,
                  value,
                  widget.index,
                );
              },
            ),
            
            const SizedBox(height: 8),
            _buildValidationStatus(appState),
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open RSS'),
                    onPressed: () => _launchUrl(_rssController.text),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                    onPressed: () {
                      final searchUrl = RssUtils.formatSearchUrl(
                        _titleController.text,
                        _fansubber,
                      );
                      _launchUrl(searchUrl);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Delete button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Delete Entry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  appState.deleteAnimeEntry(widget.anime.title, widget.index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.lightBlueAccent),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  Widget _buildValidationStatus(AppState appState) {
    final validationResult = appState.getRssValidationResult(_rssController.text);
    final episodeCount = appState.getRssEpisodeCount(_rssController.text);
    
    if (_isValidating) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
            ),
          ),
          SizedBox(width: 8),
          Text('Validating RSS feed...'),
        ],
      );
    }
    
    if (validationResult == null) {
      return const Text(
        'RSS feed not validated',
        style: TextStyle(color: Colors.grey),
      );
    }
    
    if (validationResult) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            'Valid RSS feed with $episodeCount episodes',
            style: const TextStyle(color: Colors.green),
          ),
        ],
      );
    } else {
      return const Row(
        children: [
          Icon(Icons.error, color: Colors.redAccent),
          SizedBox(width: 8),
          Text(
            'Invalid RSS feed',
            style: TextStyle(color: Colors.redAccent),
          ),
        ],
      );
    }
  }
  
  Future<void> _validateRss(AppState appState) async {
    setState(() {
      _isValidating = true;
    });
    
    try {
      final (isValid, episodeCount) = await RssUtils.validateRssFeed(_rssController.text);
      appState.setRssValidationResult(_rssController.text, isValid, episodeCount);
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }
  
  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 