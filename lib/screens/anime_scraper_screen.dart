import 'package:flutter/material.dart';
import 'package:malapp/constants.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/anime_scraper_service.dart';
import '../models/scraped_anime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
    final appState = Provider.of<AppState>(context, listen: false);
    // Include preferred fansubber in the list name
    return '${season}_${_selectedYear}_${appState.preferredFansubber}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}';
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
                child: const Text(
                  'Save',
                ), // Fixed: Added the missing 'child' parameter
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

  // Handle single entry deletion
  Future<void> _deleteAnimeEntry(int index) async {
    // Show confirmation dialog
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Confirm Delete'),
                content: Text(
                  'Are you sure you want to delete "${_scrapedAnime[index].title}"?',
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
      _scrapedAnime.removeAt(index);

      // Update the saved list if we're working with one
      if (_selectedListName != null) {
        _savedLists[_selectedListName!] = List.from(_scrapedAnime);
        _saveUpdatedLists();
      }
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry deleted')));
  }

  // Helper method to save updated lists to SharedPreferences
  Future<void> _saveUpdatedLists() async {
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
  }

  Future<void> _fetchAnime(AppState appState) async {
    if (!mounted) return; // Check if widget is still mounted

    setState(() {
      _isLoading = true;
      _progressText = 'Scraping anime...';
      _scrapedAnime = [];
      _selectedItems = [];
      _isMultiSelectMode = false;
    });

    try {
      // Create a flag to track if operation was canceled
      bool canceled = false;

      // Use the selected season and year instead of the app state
      final scrapedAnime = await _scraperService.scrapeFromMALSeasonalPage(
        _selectedSeason,
        _selectedYear,
        minMembers: _minMembers,
        excludeChinese: _excludeChinese,
        progressCallback: (current, total) {
          if (!mounted) {
            canceled = true; // Mark as canceled if no longer mounted
            return;
          }
          setState(() {
            _progressText = 'Fetching page $current of $total...';
          });
        },
      );

      // If operation was canceled or widget is no longer mounted, exit early
      if (canceled || !mounted) return;

      setState(() {
        _scrapedAnime = scrapedAnime;

        // Apply the selected sort
        _sortAnimeList();

        if (_scrapedAnime.isEmpty) {
          _progressText = 'No anime found for the selected season.';
        } else {
          _progressText = 'Found ${_scrapedAnime.length} anime.';
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return; // Check if widget is still mounted

      setState(() {
        _progressText = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _validateAllRss() async {
    if (!mounted) return;

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
        // Check if widget is still mounted or if cancellation was requested
        if (!mounted || _shouldCancelValidation) {
          if (mounted) {
            setState(() {
              _progressText =
                  'Validation cancelled after $validated of $total RSS feeds';
              _isLoading = false;
              _isValidating = false;
            });
          }
          return;
        }

        final index = _scrapedAnime.indexOf(anime);
        final originalTitle = anime.title;
        final rssUrl = appState.getEditedRssUrl(
          originalTitle,
          index,
          anime.rssUrl,
        );

        if (mounted) {
          setState(() {
            _progressText = 'Validating RSS feeds (${validated + 1}/$total)...';
          });
        }

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

      if (mounted && !_shouldCancelValidation) {
        setState(() {
          _progressText =
              'RSS validation complete. Valid: ${results.values.where((v) => v).length}/${results.length}';
          _isLoading = false;
          _isValidating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progressText = 'Error validating RSS feeds: $e';
          _isLoading = false;
          _isValidating = false;
        });
      }
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
    // Show confirmation dialog
    showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text(
              'Are you sure you want to delete ${_selectedItems.length} selected items?',
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
    ).then((confirmed) {
      if (confirmed == true) {
        _performDeleteSelectedItems();
      }
    });
  }

  void _performDeleteSelectedItems() {
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

      // Update the saved list if we're working with one
      if (_selectedListName != null) {
        _savedLists[_selectedListName!] = List.from(_scrapedAnime);
        _saveUpdatedLists();
      }

      if (_scrapedAnime.isEmpty) {
        _progressText = 'All items deleted.';
      } else {
        _progressText = 'Selected items deleted.';
      }
    });
  }

  void _addAnimeManually() {
    final TextEditingController urlController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Anime from MAL URL'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'MyAnimeList URL',
                        hintText: 'https://myanimelist.net/anime/...',
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a URL';
                        }
                        if (!value.contains('myanimelist.net/anime/')) {
                          return 'Please enter a valid MyAnimeList anime URL';
                        }
                        return null;
                      },
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    if (isSubmitting)
                      const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Fetching anime data...'),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      isSubmitting
                          ? null
                          : () async {
                            if (formKey.currentState!.validate()) {
                              setDialogState(() {
                                isSubmitting = true;
                              });

                              // Extract MAL ID from URL
                              final url = urlController.text;
                              final RegExp regExp = RegExp(
                                r'myanimelist\.net/anime/(\d+)',
                              );
                              final match = regExp.firstMatch(url);

                              if (match != null && match.groupCount >= 1) {
                                final malId = int.parse(match.group(1)!);

                                try {
                                  // Fetch anime data using MAL ID
                                  await _fetchAnimeFromMalId(malId);
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Anime added successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setDialogState(() {
                                      isSubmitting = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                setDialogState(() {
                                  isSubmitting = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not extract MAL ID from URL',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      urlController.dispose();
    });
  }

  // Add this method to fetch anime data from MAL ID
  Future<void> _fetchAnimeFromMalId(int malId) async {
    if (!mounted) return;

    setState(() {
      _progressText = 'Fetching anime data from MAL...';
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      // Use Jikan API to get anime details
      final url = '$kJikanApiBaseUrl/anime/$malId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to load anime: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final animeData = data['data'];

      if (animeData == null) {
        throw Exception('Anime data not found');
      }

      // Create ScrapedAnime object from response
      final anime = ScrapedAnime(
        title: animeData['title'] ?? '',
        imageUrl:
            animeData['images']?['jpg']?['large_image_url'] ??
            animeData['images']?['jpg']?['image_url'] ??
            '',
        episodes: animeData['episodes']?.toString(),
        malId: animeData['mal_id'],
        synopsis: animeData['synopsis'],
        members: animeData['members'],
        releaseDate: animeData['aired']?['string'],
        score: animeData['score']?.toDouble(),
        type: animeData['type'],
        studio:
            animeData['studios'] != null &&
                    (animeData['studios'] as List).isNotEmpty
                ? animeData['studios'][0]['name']
                : null,
        genres:
            animeData['genres'] != null
                ? (animeData['genres'] as List)
                    .map<String>((g) => g['name'] as String)
                    .toList()
                : null,
        fansubber: appState.preferredFansubber, // Use preferred fansubber
      );

      // Generate RSS URL
      anime.rssUrl = _scraperService.generateRssUrl(
        anime.title,
        anime.fansubber,
      );

      // Add to list
      if (mounted) {
        setState(() {
          _scrapedAnime.add(anime);
          _progressText = 'Added ${anime.title} to the list';

          // If we have a selected list, update it
          if (_selectedListName != null) {
            _savedLists[_selectedListName!] = List.from(_scrapedAnime);
            _saveUpdatedLists();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progressText = 'Error adding anime: $e';
        });
      }
      throw e; // Rethrow to be caught by the calling method
    }
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

        // Update the saved list if we're working with one
        if (_selectedListName != null) {
          _savedLists[_selectedListName!] = List.from(_scrapedAnime);
          _saveUpdatedLists();
        }
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
          onDelete: () => _deleteAnimeEntry(index), // Use the delete function
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
              onAddAnimeManually: _addAnimeManually,
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
