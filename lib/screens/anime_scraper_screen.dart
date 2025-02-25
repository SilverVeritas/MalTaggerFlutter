import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/anime.dart';
import '../services/anime_scraper_service.dart';
import '../models/scraped_anime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';

class AnimeScraperScreen extends StatefulWidget {
  const AnimeScraperScreen({super.key});

  @override
  State<AnimeScraperScreen> createState() => _AnimeScraperScreenState();
}

class _AnimeScraperScreenState extends State<AnimeScraperScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _saveListNameController = TextEditingController();
  final AnimeScraperService _scraperService = AnimeScraperService();
  List<ScrapedAnime> _scrapedAnime = [];
  bool _isLoading = false;
  String _progressText = '';
  String _sortBy = 'members_high';  // Changed from 'alpha' to 'members_high'
  Map<String, List<ScrapedAnime>> _savedLists = {};
  String? _selectedListName;
  int _minMembers = 5000; // Default minimum member count
  bool _excludeChinese = true; // Default to exclude Chinese animation
  bool _showJsonEditor = false; // Toggle for JSON editor
  int _selectedYear = DateTime.now().year;
  String _selectedSeason = ''; // Will be initialized in initState
  bool _isValidating = false;
  bool _shouldCancelValidation = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLists();
    
    // Initialize the season to current season
    final now = DateTime.now();
    final month = now.month;
    if (month >= 1 && month <= 3) {
      _selectedSeason = 'winter';
    } else if (month >= 4 && month <= 6) {
      _selectedSeason = 'spring';
    } else if (month >= 7 && month <= 9) {
      _selectedSeason = 'summer';
    } else {
      _selectedSeason = 'fall';
    }
  }

  Future<void> _loadSavedLists() async {
    final prefs = await SharedPreferences.getInstance();
    final savedListsJson = prefs.getString('scraped_anime_lists');
    
    if (savedListsJson != null) {
      final Map<String, dynamic> savedListsMap = jsonDecode(savedListsJson);
      
      setState(() {
        _savedLists = Map.fromEntries(
          savedListsMap.entries.map((entry) {
            return MapEntry(
              entry.key,
              (entry.value as List)
                  .map((item) => ScrapedAnime.fromJson(item))
                  .toList(),
            );
          }),
        );
      });
    }
  }

  Future<void> _saveCurrentList() async {
    if (_scrapedAnime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No anime to save')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save List'),
        content: TextField(
          controller: _saveListNameController,
          decoration: const InputDecoration(
            labelText: 'List Name',
            hintText: 'Enter a name for this list',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final listName = _saveListNameController.text.trim();
              if (listName.isEmpty) {
                return;
              }
              
              // Save the list
              _savedLists[listName] = List.from(_scrapedAnime);
              
              // Save to shared preferences
              final prefs = await SharedPreferences.getInstance();
              final savedListsMap = Map.fromEntries(
                _savedLists.entries.map((entry) {
                  return MapEntry(
                    entry.key,
                    entry.value.map((anime) => anime.toJson()).toList(),
                  );
                }),
              );
              await prefs.setString('scraped_anime_lists', jsonEncode(savedListsMap));
              
              _saveListNameController.clear();
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('List "$listName" saved')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _loadList(String listName) {
    if (_savedLists.containsKey(listName)) {
      setState(() {
        _scrapedAnime = List.from(_savedLists[listName]!);
        _selectedListName = listName;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded list "$listName"')),
      );
    }
  }

  Future<void> _deleteList(String listName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete the list "$listName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() {
      _savedLists.remove(listName);
      if (_selectedListName == listName) {
        _selectedListName = null;
      }
    });

    // Save updated lists to shared preferences
    final prefs = await SharedPreferences.getInstance();
    final savedListsMap = Map.fromEntries(
      _savedLists.entries.map((entry) {
        return MapEntry(
          entry.key,
          entry.value.map((anime) => anime.toJson()).toList(),
        );
      }),
    );
    await prefs.setString('scraped_anime_lists', jsonEncode(savedListsMap));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('List "$listName" deleted')),
    );
  }

  Future<void> _scrapeAnime() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _progressText = 'Please enter a URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _progressText = 'Scraping anime...';
    });

    try {
      final results = await _scraperService.scrapeAnimeFromUrl(url);
      setState(() {
        _scrapedAnime = results;
        _isLoading = false;
        _selectedListName = null; // Clear selected list when new scraping is done
      });
    } catch (e) {
      setState(() {
        _progressText = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _addToLibrary(ScrapedAnime scrapedAnime) async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    setState(() {
      _isLoading = true;
      _progressText = 'Adding ${scrapedAnime.title} to library...';
    });
    
    try {
      // Get details from MyAnimeList if possible
      Anime? anime;
      if (scrapedAnime.malId != null) {
        anime = await appState.getAnimeDetails(scrapedAnime.malId!);
      }
      
      // Generate RSS URL
      final rssUrl = _scraperService.generateRssUrl(
        scrapedAnime.title, 
        appState.preferredFansubber
      );
      
      // Validate RSS feed
      final (isValid, episodeCount) = await _scraperService.validateRssFeed(rssUrl);
      
      // If not found on MAL, create a basic entry
      anime ??= Anime(
        malId: scrapedAnime.malId ?? 0,
        title: scrapedAnime.title,
        imageUrl: scrapedAnime.imageUrl,
        episodes: scrapedAnime.episodes ?? '?',
        status: 'plan_to_watch',
        fansubber: appState.preferredFansubber,
        date: 'TBA',
        synopsis: 'No synopsis available',
        genres: [],
        score: 0.0,
        members: 0,
        type: 'Unknown',
        source: 'Unknown',
        rssUrl: rssUrl,
      );
      
      // If we have an anime from MAL, update its RSS URL
      if (anime.rssUrl.isEmpty) {
        anime = anime.copyWith(rssUrl: rssUrl);
      }
      
      await appState.addAnime(anime);
      
      setState(() {
        _isLoading = false;
        _progressText = 'Added ${anime!.title} to library${isValid == true ? ' (RSS valid)' : ' (RSS invalid)'}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _progressText = 'Error adding anime: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchAnime(AppState appState) async {
    setState(() {
      _isLoading = true;
      _progressText = 'Scraping anime...';
      _scrapedAnime = [];
    });

    try {
      // Use the selected season and year instead of the app state
      _scrapedAnime = await _scraperService.scrapeFromMALSeasonalPage(
        _selectedSeason, 
        _selectedYear,
        minMembers: _minMembers,
        excludeChinese: _excludeChinese,
        progressCallback: (current, total) {
          setState(() {
            _progressText = 'Fetching page $current of $total...';
          });
        },
      );
      
      // Apply the selected sort
      _sortAnimeList();

      if (_scrapedAnime.isEmpty) {
        setState(() {
          _progressText = 'No anime found for the selected season.';
        });
      } else {
        setState(() {
          _progressText = 'Found ${_scrapedAnime.length} anime.';
        });
      }
    } catch (e) {
      setState(() {
        _progressText = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _validateAllRss() async {
    setState(() {
      _isLoading = true;
      _isValidating = true;
      _shouldCancelValidation = false;
      _progressText = 'Validating RSS feeds...';
    });
    
    try {
      final results = <String, bool>{};
      final episodeCounts = <String, int>{};
      final appState = Provider.of<AppState>(context, listen: false);
      
      int validated = 0;
      final total = _scrapedAnime.length;
      
      for (final anime in _scrapedAnime) {
        // Check if cancellation was requested
        if (_shouldCancelValidation) {
          setState(() {
            _progressText = 'Validation cancelled after $validated of $total RSS feeds';
          });
          break;
        }
        
        // Rest of the validation code remains the same
        final index = _scrapedAnime.indexOf(anime);
        final originalTitle = anime.title;
        final rssUrl = appState.getEditedRssUrl(originalTitle, index, anime.rssUrl ?? '');
        
        setState(() {
          _progressText = 'Validating RSS feeds (${validated + 1}/$total)...';
        });
        
        final (isValid, episodeCount) = await _scraperService.validateRssFeed(rssUrl);
        results[rssUrl] = isValid;
        if (episodeCount != null) {
          episodeCounts[rssUrl] = episodeCount;
        }
        
        appState.setRssValidationResult(rssUrl, isValid, episodeCount);
        
        validated++;
        
        // Add a small delay to avoid overloading servers
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (!_shouldCancelValidation) {
        setState(() {
          _progressText = 'RSS validation complete. Valid: ${results.values.where((v) => v).length}/${results.length}';
        });
      }
    } catch (e) {
      setState(() {
        _progressText = 'Error validating RSS feeds: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isValidating = false;
      });
    }
  }

  void _cancelValidation() {
    setState(() {
      _shouldCancelValidation = true;
      _progressText = 'Cancelling validation...';
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anime Scraper'),
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(_showJsonEditor ? Icons.view_list : Icons.code),
            tooltip: _showJsonEditor ? 'Show List View' : 'Show JSON Editor',
            onPressed: () {
              setState(() {
                _showJsonEditor = !_showJsonEditor;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save List',
            onPressed: _saveCurrentList,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top controls in a card with better contrast
          Container(
            color: theme.cardColor,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isLoading ? null : () => _fetchAnime(appState),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: Text(
                          _isLoading ? 'Fetching...' : 'Fetch Anime',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DropdownButton<String>(
                        value: _sortBy,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.sort),
                        dropdownColor: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        items: const [
                          DropdownMenuItem(value: 'alpha', child: Text('A-Z')),
                          DropdownMenuItem(value: 'alpha_reverse', child: Text('Z-A')),
                          DropdownMenuItem(value: 'members_high', child: Text('Members ↓')),
                          DropdownMenuItem(value: 'members_low', child: Text('Members ↑')),
                          DropdownMenuItem(value: 'date_newest', child: Text('Newest First')),
                          DropdownMenuItem(value: 'date_oldest', child: Text('Oldest First')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _sortBy = value!;
                            _sortAnimeList();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Filter options with improved styling
                Text('Filter Options', 
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : theme.colorScheme.primary
                    )),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Min Members: $_minMembers', 
                              style: theme.textTheme.bodyMedium),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: theme.colorScheme.primary,
                              inactiveTrackColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
                              thumbColor: theme.colorScheme.primary,
                            ),
                            child: Slider(
                              value: _minMembers.toDouble(),
                              min: 0,
                              max: 50000,
                              divisions: 10,
                              onChanged: (value) {
                                setState(() {
                                  _minMembers = value.toInt();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Exclude Chinese', style: theme.textTheme.bodyMedium),
                        Switch(
                          value: _excludeChinese,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (value) {
                            setState(() {
                              _excludeChinese = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Add season and year selection
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Season:',
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.9)
                                    : theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              )),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(8),
                              color: theme.colorScheme.surface,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: DropdownButton<String>(
                              value: _selectedSeason,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: theme.cardColor,
                              items: const [
                                DropdownMenuItem(value: 'winter', child: Text('Winter')),
                                DropdownMenuItem(value: 'spring', child: Text('Spring')),
                                DropdownMenuItem(value: 'summer', child: Text('Summer')),
                                DropdownMenuItem(value: 'fall', child: Text('Fall')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedSeason = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Year:',
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.9)
                                    : theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              )),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(8),
                              color: theme.colorScheme.surface,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: DropdownButton<int>(
                              value: _selectedYear,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: theme.cardColor,
                              items: List.generate(
                                DateTime.now().year - 1959, // From current year to 1960
                                (index) {
                                  final year = DateTime.now().year - index;
                                  return DropdownMenuItem(
                                    value: year,
                                    child: Text(year.toString()),
                                  );
                                },
                              ),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedYear = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // Add some space before the next section
                
                if (_scrapedAnime.isNotEmpty && !_showJsonEditor)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isValidating ? Colors.red[700] : Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : (_isValidating ? _cancelValidation : _validateAllRss),
                      icon: Icon(_isValidating ? Icons.stop : Icons.check_circle, color: Colors.white),
                      label: Text(
                        _isValidating ? 'Stop Validation' : 'Validate All RSS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Status text with better visibility
                if (_progressText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _progressText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onBackground,
                        ),
                      ),
                    ),
                  ),
                
                // Saved lists with better styling
                if (_savedLists.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.folder_open, 
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButton<String>(
                              underline: const SizedBox(),
                              isExpanded: true,
                              value: _selectedListName,
                              hint: Text('Load saved list',
                                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                              dropdownColor: theme.cardColor,
                              items: _savedLists.keys.map((name) {
                                return DropdownMenuItem(
                                  value: name,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                                      IconButton(
                                        icon: Icon(Icons.delete, 
                                            size: 20, color: theme.colorScheme.error),
                                        onPressed: () => _deleteList(name),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedListName = value;
                                    _scrapedAnime = _savedLists[value] ?? [];
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Main content with improved scrolling
          Expanded(
            child: _showJsonEditor ? _buildJsonEditor() : _buildAnimeList(),
          ),
        ],
      ),
    );
  }

  void _sortAnimeList() {
    setState(() {
      switch (_sortBy) {
        case 'alpha':
          _scrapedAnime.sort((a, b) => a.title.compareTo(b.title));
          break;
        case 'alpha_reverse':
          _scrapedAnime.sort((a, b) => b.title.compareTo(a.title));
          break;
        case 'members_high':
          _scrapedAnime.sort((a, b) => (b.members ?? 0).compareTo(a.members ?? 0));
          break;
        case 'members_low':
          _scrapedAnime.sort((a, b) => (a.members ?? 0).compareTo(b.members ?? 0));
          break;
        case 'date_newest':
          _scrapedAnime.sort((a, b) {
            if (a.releaseDate == null) return 1;
            if (b.releaseDate == null) return -1;
            return b.releaseDate!.compareTo(a.releaseDate!);
          });
          break;
        case 'date_oldest':
          _scrapedAnime.sort((a, b) {
            if (a.releaseDate == null) return 1;
            if (b.releaseDate == null) return -1;
            return a.releaseDate!.compareTo(b.releaseDate!);
          });
          break;
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _saveListNameController.dispose();
    super.dispose();
  }

  // Add JSON editor widget
  Widget _buildJsonEditor() {
    // Convert ScrapedAnime list to JSON string with indentation
    final jsonString = JsonEncoder.withIndent('  ').convert(
      _scrapedAnime.map((anime) => anime.toJson()).toList()
    );
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyJsonChanges,
                  child: const Text('Apply JSON Changes'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: TextEditingController(text: jsonString),
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Edit JSON here',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
              onChanged: (value) {
                _jsonText = value;
              },
            ),
          ),
        ),
      ],
    );
  }
  
  // Add variable to store JSON text
  String _jsonText = '';
  
  // Add method to apply JSON changes
  void _applyJsonChanges() {
    try {
      final jsonData = json.decode(_jsonText) as List;
      final newAnimeList = jsonData.map((item) => ScrapedAnime.fromJson(item)).toList();
      
      setState(() {
        _scrapedAnime = newAnimeList;
        _showJsonEditor = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JSON changes applied successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing JSON: $e')),
      );
    }
  }
  
  Widget _buildAnimeList() {
    if (_scrapedAnime.isEmpty) {
      return const Center(
        child: Text('No anime found. Try fetching from a season.'),
      );
    }
    
    return ListView.builder(
      itemCount: _scrapedAnime.length,
      itemBuilder: (context, index) {
        final anime = _scrapedAnime[index];
        return _buildAnimeItem(anime, Theme.of(context));
      },
    );
  }
  
  Widget _buildAnimeItem(ScrapedAnime anime, ThemeData theme) {
    final titleController = TextEditingController(text: anime.title);
    final rssController = TextEditingController(text: anime.rssUrl);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        leading: GestureDetector(
          onTap: () {
            // Show a larger image when tapped
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.network(
                          anime.imageUrl,
                          fit: BoxFit.contain,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
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
              anime.imageUrl,
              width: 70,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 70,
                  height: 100,
                  color: theme.colorScheme.primary.withOpacity(0.1),
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
        title: Text(
          anime.title,
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
                if (anime.episodes != null)
                  _buildTag(theme, '${anime.episodes} ep', theme.colorScheme.primary),
                if (anime.type != null)
                  _buildTag(theme, anime.type!, theme.colorScheme.secondary),
                if (anime.members != null)
                  _buildTag(theme, '${(anime.members! / 1000).toStringAsFixed(1)}K', 
                    theme.colorScheme.tertiary ?? theme.colorScheme.primary),
              ],
            ),
            
            // Add synopsis with ellipsis for collapsed state
            if (anime.synopsis != null && anime.synopsis!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  anime.synopsis!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    // Improve readability with higher contrast
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                  ),
                ),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detailed information
                const SizedBox(height: 16),
                if (anime.synopsis != null && anime.synopsis!.isNotEmpty) ...[
                  Text(
                    'Synopsis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      // Improve contrast
                      color: theme.colorScheme.primary.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    anime.synopsis!,
                    style: TextStyle(
                      // Improve readability with higher contrast
                      color: theme.colorScheme.onSurface,
                    ),
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
                          if (anime.releaseDate != null)
                            _buildInfoRow('Released:', anime.releaseDate!, theme),
                          if (anime.episodes != null)
                            _buildInfoRow('Episodes:', anime.episodes!, theme),
                          if (anime.type != null)
                            _buildInfoRow('Type:', anime.type!, theme),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (anime.score != null)
                            _buildInfoRow('Score:', anime.score!.toString(), theme),
                          if (anime.members != null)
                            _buildInfoRow('Members:', anime.members!.toString(), theme),
                          if (anime.studio != null)
                            _buildInfoRow('Studio:', anime.studio!, theme),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (anime.genres != null && anime.genres!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: anime.genres!.map((genre) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          genre,
                          style: TextStyle(
                            fontSize: 12,
                            // Improved contrast for readability
                            color: theme.colorScheme.primary.withOpacity(0.9),
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
                    color: theme.brightness == Brightness.dark
                        ? Colors.white 
                        : theme.colorScheme.primary.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),

                // Title editing
                TextField(
                  controller: titleController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: theme.colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    anime.title = value;
                    // Update RSS URL when title changes
                    anime.rssUrl = _scraperService.generateRssUrl(value, anime.fansubber);
                    rssController.text = anime.rssUrl;
                  },
                ),
                const SizedBox(height: 12),

                // Fansubber selection with better styling
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.surface,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Fansubber:',
                        style: TextStyle(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.9)
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          value: anime.fansubber,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: theme.cardColor,
                          items: kFansubbers.map((fansubber) {
                            return DropdownMenuItem(
                              value: fansubber,
                              child: Text(fansubber),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                anime.fansubber = value;
                                // Update RSS URL when fansubber changes
                                anime.rssUrl = _scraperService.generateRssUrl(anime.title, value);
                                rssController.text = anime.rssUrl;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // RSS URL field with better styling and functionality
                TextField(
                  controller: rssController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'RSS URL',
                    labelStyle: TextStyle(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.9)
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle),
                          color: theme.colorScheme.primary,
                          tooltip: 'Validate RSS',
                          onPressed: () async {
                            final (isValid, episodeCount) = await _scraperService.validateRssFeed(rssController.text);
                            setState(() {
                              anime.rssUrl = rssController.text;
                            });
                            // Show validation result
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isValid 
                                      ? 'Valid RSS feed with $episodeCount episodes' 
                                      : 'Invalid RSS feed'
                                ),
                                backgroundColor: isValid ? Colors.green : Colors.red,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_browser),
                          color: theme.colorScheme.secondary,
                          tooltip: 'Open RSS in browser',
                          onPressed: () {
                            final url = rssController.text;
                            if (url.isNotEmpty) {
                              launchUrl(Uri.parse(url));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  onChanged: (value) {
                    anime.rssUrl = value;
                  },
                ),

                // Action buttons with better styling
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[700]!, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () {
                          // Reset to auto-generated RSS
                          setState(() {
                            anime.rssUrl = _scraperService.generateRssUrl(anime.title, anime.fansubber);
                            rssController.text = anime.rssUrl;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset RSS', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  // Helper method to build tags (for better reuse)
  Widget _buildTag(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(right: 8, top: 4),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? color.withOpacity(0.3)
            : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.95)
              : color.withOpacity(0.9),
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
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.9)
                    : theme.colorScheme.primary.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: theme.brightness == Brightness.dark
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