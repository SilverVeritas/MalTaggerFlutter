import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/anime.dart';
import '../services/anime_scraper_service.dart';
import '../models/scraped_anime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/anime_item_card.dart';
import '../widgets/json_editor_widget.dart';
import '../utils/string_extensions.dart';
import '../widgets/scraper_control_panel.dart';

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
  String _sortBy = 'members_high';
  Map<String, List<ScrapedAnime>> _savedLists = {};
  String? _selectedListName;
  int _minMembers = 5000;
  bool _excludeChinese = true;
  bool _showJsonEditor = false;
  int _selectedYear = DateTime.now().year;
  String _selectedSeason = '';
  bool _isValidating = false;
  bool _shouldCancelValidation = false;
  List<int> _selectedItems = [];
  bool _isMultiSelectMode = false;
  String _jsonText = '';

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

  @override
  void dispose() {
    _urlController.dispose();
    _saveListNameController.dispose();
    super.dispose();
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

  String _generateDefaultListName() {
    final now = DateTime.now();
    final season = _selectedSeason.capitalize();
    return '${season}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveCurrentList() async {
    if (_scrapedAnime.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No anime to save')));
      return;
    }

    // Set default list name
    _saveListNameController.text = _generateDefaultListName();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Save List'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _saveListNameController,
                  decoration: const InputDecoration(
                    labelText: 'List Name',
                    hintText: 'Enter a name for this list',
                  ),
                  autofocus: true,
                  onChanged: (value) {
                    // Validate input to only allow alphanumeric, underscore, and dash
                    if (!RegExp(r'^[a-zA-Z0-9_-]*$').hasMatch(value)) {
                      _saveListNameController.text = value.replaceAll(
                        RegExp(r'[^a-zA-Z0-9_-]'),
                        '',
                      );
                      _saveListNameController
                          .selection = TextSelection.fromPosition(
                        TextPosition(
                          offset: _saveListNameController.text.length,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only letters, numbers, underscores, and dashes are allowed.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
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
                  await prefs.setString(
                    'scraped_anime_lists',
                    jsonEncode(savedListsMap),
                  );

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
        _selectedItems = [];
        _isMultiSelectMode = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Loaded list "$listName"')));
    }
  }

  Future<void> _deleteList(String listName) async {
    // Show confirmation dialog
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Confirm Delete'),
                content: Text(
                  'Are you sure you want to delete the list "$listName"?',
                ),
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
        ) ??
        false;

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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('List "$listName" deleted')));
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
        appState.preferredFansubber,
      );

      // Validate RSS feed
      final (isValid, episodeCount) = await _scraperService.validateRssFeed(
        rssUrl,
      );

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
        _progressText =
            'Added ${anime!.title} to library${isValid ? ' (RSS valid)' : ' (RSS invalid)'}';
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
      _selectedItems = [];
      _isMultiSelectMode = false;
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
            _progressText =
                'Validation cancelled after $validated of $total RSS feeds';
          });
          break;
        }

        final index = _scrapedAnime.indexOf(anime);
        final originalTitle = anime.title;
        final rssUrl = appState.getEditedRssUrl(
          originalTitle,
          index,
          anime.rssUrl,
        );

        setState(() {
          _progressText = 'Validating RSS feeds (${validated + 1}/$total)...';
        });

        final (isValid, episodeCount) = await _scraperService.validateRssFeed(
          rssUrl,
        );
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
          _progressText =
              'RSS validation complete. Valid: ${results.values.where((v) => v).length}/${results.length}';
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

  void _toggleSelectItem(int index) {
    setState(() {
      if (_selectedItems.contains(index)) {
        _selectedItems.remove(index);
        if (_selectedItems.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedItems.add(index);
      }
    });
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedItems.clear();
      }
    });
  }

  void _deleteSelectedItems() {
    // Sort indices in descending order to avoid issues with shifting indices
    _selectedItems.sort((a, b) => b.compareTo(a));

    setState(() {
      for (final index in _selectedItems) {
        if (index < _scrapedAnime.length) {
          _scrapedAnime.removeAt(index);
        }
      }
      _selectedItems.clear();
      _isMultiSelectMode = false;

      if (_scrapedAnime.isEmpty) {
        _progressText = 'All items deleted.';
      } else {
        _progressText = 'Selected items deleted.';
      }
    });
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
          _scrapedAnime.sort(
            (a, b) => (b.members ?? 0).compareTo(a.members ?? 0),
          );
          break;
        case 'members_low':
          _scrapedAnime.sort(
            (a, b) => (a.members ?? 0).compareTo(b.members ?? 0),
          );
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

  // JSON Editor management
  Widget _buildJsonEditor() {
    // Convert ScrapedAnime list to JSON string with indentation
    final jsonString = JsonEncoder.withIndent(
      '  ',
    ).convert(_scrapedAnime.map((anime) => anime.toJson()).toList());

    return JsonEditorWidget(
      initialJson: jsonString,
      onJsonChanged: (newJson) {
        _jsonText = newJson;
      },
      onApply: _applyJsonChanges,
    );
  }

  void _applyJsonChanges() {
    try {
      final jsonData = json.decode(_jsonText) as List;
      final newAnimeList =
          jsonData.map((item) => ScrapedAnime.fromJson(item)).toList();

      setState(() {
        _scrapedAnime = newAnimeList;
        _showJsonEditor = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JSON changes applied successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error parsing JSON: $e')));
    }
  }

  // Anime list building
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
        final isSelected = _selectedItems.contains(index);

        return AnimeItemCard(
          anime: anime,
          index: index,
          isSelected: isSelected,
          isSelectionMode: _isMultiSelectMode,
          onSelect: () => _toggleSelectItem(index),
          onAddToLibrary: () => _addToLibrary(anime),
          scraperService: _scraperService,
          onTitleChanged: (newValue) {
            setState(() {
              anime.title = newValue;
            });
          },
          onFansubberChanged: (newValue) {
            setState(() {
              anime.fansubber = newValue;
              // Update RSS URL when fansubber changes
              anime.rssUrl = _scraperService.generateRssUrl(
                anime.title,
                newValue,
              );
            });
          },
          onRssUrlChanged: (newValue) {
            setState(() {
              anime.rssUrl = newValue;
            });
          },
        );
      },
    );
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
          // Multi-select mode toggle
          if (_scrapedAnime.isNotEmpty && !_showJsonEditor)
            IconButton(
              icon: Icon(_isMultiSelectMode ? Icons.cancel : Icons.select_all),
              tooltip: _isMultiSelectMode ? 'Cancel Selection' : 'Select Items',
              onPressed: _toggleMultiSelectMode,
            ),
          IconButton(
            icon: Icon(_showJsonEditor ? Icons.view_list : Icons.code),
            tooltip: _showJsonEditor ? 'Show List View' : 'Show JSON Editor',
            onPressed: () {
              setState(() {
                _showJsonEditor = !_showJsonEditor;
                if (_isMultiSelectMode) {
                  _isMultiSelectMode = false;
                  _selectedItems.clear();
                }
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
          // Top controls
          Container(
            color: theme.cardColor,
            padding: const EdgeInsets.all(16.0),
            child: ScraperControlPanel(
              isLoading: _isLoading,
              isValidating: _isValidating,
              isMultiSelectMode: _isMultiSelectMode,
              selectedItems: _selectedItems.length,
              progressText: _progressText,
              sortBy: _sortBy,
              minMembers: _minMembers,
              excludeChinese: _excludeChinese,
              selectedSeason: _selectedSeason,
              selectedYear: _selectedYear,
              savedLists: _savedLists,
              selectedListName: _selectedListName,
              onFetchAnime: () => _fetchAnime(appState),
              onSortChanged: (value) {
                setState(() {
                  _sortBy = value;
                  _sortAnimeList();
                });
              },
              onMinMembersChanged: (value) {
                setState(() {
                  _minMembers = value.toInt();
                });
              },
              onExcludeChineseChanged: (value) {
                setState(() {
                  _excludeChinese = value;
                });
              },
              onSeasonChanged: (value) {
                setState(() {
                  _selectedSeason = value;
                });
              },
              onYearChanged: (value) {
                setState(() {
                  _selectedYear = value;
                });
              },
              onDeleteSelected: _deleteSelectedItems,
              onValidateAllRss: _validateAllRss,
              onCancelValidation: _cancelValidation,
              onLoadList: _loadList,
              onDeleteList: _deleteList,
              hasAnimeList: _scrapedAnime.isNotEmpty,
            ),
          ),

          // Main content
          Expanded(
            child: _showJsonEditor ? _buildJsonEditor() : _buildAnimeList(),
          ),
        ],
      ),
    );
  }
}
