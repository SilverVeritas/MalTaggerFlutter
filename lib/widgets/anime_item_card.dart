import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scraped_anime.dart';
import '../services/rss_utils.dart';
import '../services/app_state.dart';
import '../services/anime_scraper_service.dart';
import '../constants.dart';

class AnimeItemCard extends StatefulWidget {
  final ScrapedAnime anime;
  final int index;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final AnimeScraperService scraperService;
  final Function(String) onTitleChanged;
  final Function(String) onFansubberChanged;
  final Function(String) onRssUrlChanged;

  const AnimeItemCard({
    super.key,
    required this.anime,
    required this.index,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onSelect,
    required this.onDelete,
    required this.scraperService,
    required this.onTitleChanged,
    required this.onFansubberChanged,
    required this.onRssUrlChanged,
  });

  @override
  State<AnimeItemCard> createState() => _AnimeItemCardState();
}

class _AnimeItemCardState extends State<AnimeItemCard> {
  late TextEditingController _titleController;
  late TextEditingController _rssController;
  late TextEditingController _customFansubberController;
  bool _isValidating = false;
  bool _showCustomFansubber = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _customFansubberController = TextEditingController();

    // Get preferred fansubber when the card is first initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      if (widget.anime.fansubber.isEmpty) {
        // Only update if fansubber isn't already set
        widget.onFansubberChanged(appState.preferredFansubber);
        // Update RSS URL to match preferred fansubber
        widget.onRssUrlChanged(
          widget.scraperService.generateRssUrl(
            widget.anime.title,
            appState.preferredFansubber,
          ),
        );
      }
    });
  }

  @override
  void didUpdateWidget(AnimeItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anime != widget.anime) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: widget.anime.title);
    _rssController = TextEditingController(text: widget.anime.rssUrl);

    // Add listeners
    _titleController.addListener(_onTitleChanged);
    _rssController.addListener(_onRssUrlChanged);
  }

  void _disposeControllers() {
    _titleController.removeListener(_onTitleChanged);
    _rssController.removeListener(_onRssUrlChanged);
    _titleController.dispose();
    _rssController.dispose();
  }

  void _onTitleChanged() {
    widget.onTitleChanged(_titleController.text);
  }

  void _onRssUrlChanged() {
    widget.onRssUrlChanged(_rssController.text);
  }

  @override
  void dispose() {
    _disposeControllers();
    _customFansubberController.dispose();
    super.dispose();
  }

  Future<void> _validateRss() async {
    setState(() {
      _isValidating = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final (isValid, episodeCount) = await widget.scraperService
          .validateRssFeed(_rssController.text);
      appState.setRssValidationResult(
        _rssController.text,
        isValid,
        episodeCount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isValid
                  ? 'Valid RSS feed with $episodeCount episodes'
                  : 'Invalid RSS feed',
            ),
            backgroundColor: isValid ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppState>(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              widget.isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withAlpha(51),
          width: widget.isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: widget.isSelectionMode ? widget.onSelect : null,
        child: ExpansionTile(
          leading: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  // Show a larger image when tapped
                  showDialog(
                    context: context,
                    builder:
                        (context) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  Image.network(
                                    widget.anime.imageUrl,
                                    fit: BoxFit.contain,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.anime.imageUrl,
                    width: 70,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 70,
                        height: 100,
                        color: theme.colorScheme.primary.withAlpha(26),
                        child: Icon(
                          Icons.broken_image,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (widget.isSelectionMode)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          widget.isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surface.withAlpha(179),
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      widget.isSelected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color:
                          widget.isSelected
                              ? Colors.white
                              : theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            widget.anime.title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display important metadata in a row
              Row(
                children: [
                  if (widget.anime.episodes != null)
                    _buildTag(
                      theme,
                      '${widget.anime.episodes} ep',
                      theme.colorScheme.primary,
                    ),
                  if (widget.anime.type != null)
                    _buildTag(
                      theme,
                      widget.anime.type!,
                      theme.colorScheme.secondary,
                    ),
                  if (widget.anime.members != null)
                    _buildTag(
                      theme,
                      '${(widget.anime.members! / 1000).toStringAsFixed(1)}K',
                      theme.colorScheme.tertiary,
                    ),
                ],
              ),

              // Add synopsis with ellipsis for collapsed state
              if (widget.anime.synopsis != null &&
                  widget.anime.synopsis!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    widget.anime.synopsis!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(230),
                    ),
                  ),
                ),
            ],
          ),
          trailing:
              !widget.isSelectionMode
                  ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete entry',
                    color: Colors.red.shade600,
                    onPressed: widget.onDelete,
                  )
                  : null,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Detailed information
                  const SizedBox(height: 16),
                  if (widget.anime.synopsis != null &&
                      widget.anime.synopsis!.isNotEmpty) ...[
                    Text(
                      'Synopsis',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.primary.withAlpha(230),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.anime.synopsis!,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Add alternative titles section here
                  if (widget.anime.alternativeTitles != null &&
                      widget.anime.alternativeTitles!.isNotEmpty) ...[
                    Text(
                      'Alternative Titles',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.primary.withAlpha(230),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          widget.anime.alternativeTitles!.map((title) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $title',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.anime.releaseDate != null)
                              _buildInfoRow(
                                'Released:',
                                widget.anime.releaseDate!,
                                theme,
                              ),
                            if (widget.anime.episodes != null)
                              _buildInfoRow(
                                'Episodes:',
                                widget.anime.episodes!,
                                theme,
                              ),
                            if (widget.anime.type != null)
                              _buildInfoRow('Type:', widget.anime.type!, theme),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.anime.score != null)
                              _buildInfoRow(
                                'Score:',
                                widget.anime.score!.toString(),
                                theme,
                              ),
                            if (widget.anime.members != null)
                              _buildInfoRow(
                                'Members:',
                                widget.anime.members!.toString(),
                                theme,
                              ),
                            if (widget.anime.studio != null)
                              _buildInfoRow(
                                'Studio:',
                                widget.anime.studio!,
                                theme,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (widget.anime.genres != null &&
                      widget.anime.genres!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          widget.anime.genres!.map((genre) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withAlpha(
                                    77,
                                  ),
                                ),
                              ),
                              child: Text(
                                genre,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary.withAlpha(
                                    230,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],

                  // Add back the RSS functionality section
                  const SizedBox(height: 24),
                  Text(
                    'Edit Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color:
                          theme.brightness == Brightness.dark
                              ? Colors.white
                              : theme.colorScheme.primary.withAlpha(230),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title editing
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: theme.colorScheme.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Fansubber selection with custom option
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withAlpha(77),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surface,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Fansubber:',
                              style: TextStyle(
                                color:
                                    theme.brightness == Brightness.dark
                                        ? Colors.white.withAlpha(230)
                                        : theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<String>(
                                value:
                                    kFansubbers.contains(widget.anime.fansubber)
                                        ? widget.anime.fansubber
                                        : 'custom',
                                isExpanded: true,
                                underline: const SizedBox(),
                                dropdownColor: theme.cardColor,
                                items: [
                                  ...kFansubberOptions.map((fansubber) {
                                    return DropdownMenuItem(
                                      value: fansubber,
                                      child: Text(fansubber),
                                    );
                                  }),
                                  const DropdownMenuItem(
                                    value: 'custom',
                                    child: Text('Custom...'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      if (value == 'custom') {
                                        // Don't change fansubber yet, just show the text field
                                        _showCustomFansubber = true;
                                        // Initialize custom fansubber field with current value if not from standard list
                                        if (!kFansubbers.contains(
                                          widget.anime.fansubber,
                                        )) {
                                          _customFansubberController.text =
                                              widget.anime.fansubber;
                                        }
                                      } else {
                                        widget.onFansubberChanged(value);
                                        // Update RSS URL when fansubber changes
                                        _rssController.text = widget
                                            .scraperService
                                            .generateRssUrl(
                                              widget.anime.title,
                                              value,
                                            );
                                        _showCustomFansubber = false;
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_showCustomFansubber) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _customFansubberController,
                            decoration: InputDecoration(
                              labelText: 'Enter custom fansubber',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: () {
                                  final customValue =
                                      _customFansubberController.text.trim();
                                  if (customValue.isNotEmpty) {
                                    widget.onFansubberChanged(customValue);
                                    setState(() {
                                      _showCustomFansubber = false;
                                      // Update RSS URL when fansubber changes
                                      _rssController.text = widget
                                          .scraperService
                                          .generateRssUrl(
                                            widget.anime.title,
                                            customValue,
                                          );
                                    });
                                  }
                                },
                              ),
                            ),
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                widget.onFansubberChanged(value.trim());
                                setState(() {
                                  _showCustomFansubber = false;
                                  // Update RSS URL when fansubber changes
                                  _rssController.text = widget.scraperService
                                      .generateRssUrl(
                                        widget.anime.title,
                                        value.trim(),
                                      );
                                });
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // RSS URL field with better styling and functionality
                  TextField(
                    controller: _rssController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'RSS URL',
                      labelStyle: TextStyle(
                        color:
                            theme.brightness == Brightness.dark
                                ? Colors.white.withAlpha(230)
                                : theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon:
                                _isValidating
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.check_circle),
                            color: theme.colorScheme.primary,
                            tooltip: 'Validate RSS',
                            onPressed: _isValidating ? null : _validateRss,
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_browser),
                            color: theme.colorScheme.secondary,
                            tooltip: 'Open RSS in browser',
                            onPressed: () {
                              final url = _rssController.text;
                              if (url.isNotEmpty) {
                                _launchUrl(url);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            color: theme.colorScheme.tertiary,
                            tooltip: 'Open search page',
                            onPressed: () {
                              final rssUrl = _rssController.text;
                              if (rssUrl.isNotEmpty) {
                                final searchUrl =
                                    RssUtils.convertRssToSearchUrl(rssUrl);
                                _launchUrl(searchUrl);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Display validation status
                  const SizedBox(height: 8),
                  _buildValidationStatus(appState),

                  // Action buttons with better styling - Replaced "Add to Library" with "Delete Entry"
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[700],
                            side: BorderSide(
                              color: Colors.red[700]!,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () {
                            // Reset to auto-generated RSS
                            setState(() {
                              _rssController.text = widget.scraperService
                                  .generateRssUrl(
                                    widget.anime.title,
                                    widget.anime.fansubber,
                                  );
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Reset RSS',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[700],
                            side: BorderSide(
                              color: Colors.red[700]!,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete),
                          label: const Text(
                            'Delete Entry',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationStatus(AppState appState) {
    final validationResult = appState.getRssValidationResult(
      _rssController.text,
    );
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
          Text('Invalid RSS feed', style: TextStyle(color: Colors.redAccent)),
        ],
      );
    }
  }

  // Helper method to build tags (for better reuse)
  Widget _buildTag(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(right: 8, top: 4),
      decoration: BoxDecoration(
        color:
            theme.brightness == Brightness.dark
                ? color.withAlpha(77)
                : color.withAlpha(38),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(128), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color:
              theme.brightness == Brightness.dark
                  ? Colors.white.withAlpha(242)
                  : color.withAlpha(230),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Helper method to build info rows
  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color:
                    theme.brightness == Brightness.dark
                        ? Colors.white.withAlpha(230)
                        : theme.colorScheme.primary.withAlpha(204),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color:
                    theme.brightness == Brightness.dark
                        ? Colors.white
                        : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
