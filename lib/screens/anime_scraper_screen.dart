import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/scraped_anime.dart';
import '../widgets/anime_item_card.dart';
import '../widgets/json_editor_widget.dart';
import '../widgets/scraper_control_panel.dart';
import '../widgets/anime_search_dialog.dart';
import '../controllers/anime_scraper_controller.dart';

class AnimeScraperScreen extends StatefulWidget {
  const AnimeScraperScreen({super.key});

  @override
  State<AnimeScraperScreen> createState() => _AnimeScraperScreenState();
}

class _AnimeScraperScreenState extends State<AnimeScraperScreen> {
  // Controller instance
  late AnimeScraperController _controller;

  // UI state variables
  bool _isLoading = false;
  bool _isValidating = false;
  bool _shouldCancelValidation = false;
  bool _showJsonEditor = false;
  bool _isMultiSelectMode = false;

  // Data state variables
  List<ScrapedAnime> _scrapedAnime = [];
  Map<String, List<ScrapedAnime>> _savedLists = {};
  List<int> _selectedItems = [];
  String? _selectedListName;
  String _jsonText = '';
  String _progressText = '';

  // Filter and sort state
  String _sortBy = 'members_high';
  int _minMembers = 5000;
  bool _excludeChinese = true;
  int _selectedYear = DateTime.now().year;
  String _selectedSeason = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimeScraperController();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Initialize season to current season
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

    // Load saved lists
    await _loadSavedLists();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Load saved anime lists from shared preferences
  Future<void> _loadSavedLists() async {
    try {
      final loadedLists = await _controller.loadSavedLists();
      setState(() {
        _savedLists = loadedLists;
      });
    } catch (e) {
      // Handle error
      setState(() {
        _progressText = 'Error loading saved lists: $e';
      });
    }
  }

  // Save current anime list with a user-provided name
  Future<void> _saveCurrentList() async {
    if (_scrapedAnime.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No anime to save')));
      return;
    }

    final listName = await _controller.promptForListName(
      context,
      _selectedSeason,
      _selectedYear,
    );
    if (listName == null || listName.isEmpty) return;

    try {
      await _controller.saveAnimeList(listName, _scrapedAnime);

      setState(() {
        _savedLists[listName] = List.from(_scrapedAnime);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('List "$listName" saved')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving list: $e')));
    }
  }

  // Load a previously saved list
  void _loadList(String listName) {
    if (_savedLists.containsKey(listName)) {
      setState(() {
        // Create deep copies to avoid modifying the saved list directly
        _scrapedAnime = _controller.createDeepCopy(_savedLists[listName]!);
        _selectedListName = listName;
        _selectedItems = [];
        _isMultiSelectMode = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Loaded list "$listName"')));
    }
  }

  // Delete a saved list
  Future<void> _deleteList(String listName) async {
    // Show confirmation dialog
    final confirmed = await _controller.confirmAction(
      context,
      'Confirm Delete',
      'Are you sure you want to delete the list "$listName"?',
      'Delete',
    );

    if (!confirmed) return;

    try {
      await _controller.deleteAnimeList(listName);

      setState(() {
        _savedLists.remove(listName);

        if (_selectedListName == listName) {
          _selectedListName = null;
          _scrapedAnime = [];
          _progressText = 'List "$listName" deleted. Screen cleared.';
        } else {
          _progressText = 'List "$listName" deleted.';
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('List "$listName" deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting list: $e')));
    }
  }

  // Delete a single anime entry
  Future<void> _deleteAnimeEntry(int index) async {
    final confirmed = await _controller.confirmAction(
      context,
      'Confirm Delete',
      'Are you sure you want to delete "${_scrapedAnime[index].title}"?',
      'Delete',
    );

    if (!confirmed) return;

    setState(() {
      _scrapedAnime.removeAt(index);

      // Update the saved list if we're working with one
      if (_selectedListName != null) {
        _savedLists[_selectedListName!] = List.from(_scrapedAnime);
        _controller.saveUpdatedLists(_savedLists);
      }
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry deleted')));
  }

  // Fetch anime for the selected season/year
  Future<void> _fetchAnime(AppState appState) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _progressText = 'Scraping anime...';
      _scrapedAnime = [];
      _selectedItems = [];
      _isMultiSelectMode = false;
    });

    try {
      final scrapedAnime = await _controller.fetchAnimeForSeason(
        _selectedSeason,
        _selectedYear,
        minMembers: _minMembers,
        excludeChinese: _excludeChinese,
        preferredFansubber: appState.preferredFansubber,
        progressCallback: (current, total) {
          if (!mounted) return;
          setState(() {
            _progressText = 'Fetching page $current of $total...';
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _scrapedAnime = scrapedAnime;
        _sortAnimeList();

        if (_scrapedAnime.isEmpty) {
          _progressText = 'No anime found for the selected season.';
        } else {
          _progressText = 'Found ${_scrapedAnime.length} anime.';
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _progressText = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Validate all RSS feeds
  Future<void> _validateAllRss() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isValidating = true;
      _shouldCancelValidation = false;
      _progressText = 'Validating RSS feeds...';
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      final results = await _controller.validateAllRssFeeds(
        _scrapedAnime,
        appState,
        onProgress: (validated, total) {
          if (mounted) {
            setState(() {
              _progressText = 'Validating RSS feeds ($validated/$total)...';
            });
          }
        },
        shouldCancel: () => _shouldCancelValidation || !mounted,
      );

      if (mounted && !_shouldCancelValidation) {
        setState(() {
          _progressText =
              'RSS validation complete. Valid: ${results['valid']}/${results['total']}';
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

  // Selection management
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
    _controller
        .confirmAction(
          context,
          'Confirm Delete',
          'Are you sure you want to delete ${_selectedItems.length} selected items?',
          'Delete',
        )
        .then((confirmed) {
          if (confirmed) {
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
        _controller.saveUpdatedLists(_savedLists);
      }

      if (_scrapedAnime.isEmpty) {
        _progressText = 'All items deleted.';
      } else {
        _progressText = 'Selected items deleted.';
      }
    });
  }

  // Add anime manually via dialog
  void _addAnimeManually() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AnimeSearchDialog(
          onAnimeSelected: (int malId) async {
            try {
              await _fetchAnimeFromMalId(malId);
              if (mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Anime added successfully')),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
            }
          },
        );
      },
    );
  }

  // Fetch anime details from MAL ID
  Future<void> _fetchAnimeFromMalId(int malId) async {
    if (!mounted) return;

    setState(() {
      _progressText = 'Fetching anime data from MAL...';
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final anime = await _controller.fetchAnimeById(
        malId,
        appState.preferredFansubber,
      );

      if (mounted) {
        setState(() {
          _scrapedAnime.add(anime);
          _progressText = 'Added ${anime.title} to the list';

          // If we have a selected list, update it
          if (_selectedListName != null) {
            _savedLists[_selectedListName!] = List.from(_scrapedAnime);
            _controller.saveUpdatedLists(_savedLists);
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

  // Sort the anime list
  void _sortAnimeList() {
    setState(() {
      _controller.sortAnimeList(_scrapedAnime, _sortBy);
    });
  }

  // JSON Editor functions
  Widget _buildJsonEditor() {
    // Convert ScrapedAnime list to JSON string with indentation
    final jsonString = _controller.animeListToJson(_scrapedAnime);

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
      final newAnimeList = _controller.jsonToAnimeList(_jsonText);

      setState(() {
        _scrapedAnime = newAnimeList;
        _showJsonEditor = false;

        // Update the saved list if we're working with one
        if (_selectedListName != null) {
          _savedLists[_selectedListName!] = List.from(_scrapedAnime);
          _controller.saveUpdatedLists(_savedLists);
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

  // Build anime list widget
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
          onDelete: () => _deleteAnimeEntry(index),
          scraperService: _controller.scraperService,
          onTitleChanged: (newValue) {
            setState(() {
              anime.title = newValue;
            });
          },
          onFansubberChanged: (newValue) {
            setState(() {
              anime.fansubber = newValue;
              // Update RSS URL when fansubber changes
              anime.rssUrl = _controller.scraperService.generateRssUrl(
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
        title: const Text('Anime Finder'),
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
