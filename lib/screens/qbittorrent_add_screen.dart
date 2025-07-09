import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/qbittorrent_api.dart';
import '../services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';
import '../models/scraped_anime.dart';
import 'dart:convert';
import '../services/season_utils.dart';

class QBittorrentAddScreen extends StatefulWidget {
  const QBittorrentAddScreen({super.key});

  @override
  State<QBittorrentAddScreen> createState() => _QBittorrentAddScreenState();
}

class _QBittorrentAddScreenState extends State<QBittorrentAddScreen> {
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _seasonController = TextEditingController();
  final _yearController = TextEditingController();
  final _animeListController = TextEditingController();

  bool _isConnecting = false;
  bool _isProcessing = false;
  String _connectionStatus = 'Not connected';
  String? _selectedListName;
  List<String> _availableLists = [];
  Map<String, List<ScrapedAnime>> _savedLists = {};
  Map<String, dynamic> _processingResults = {};
  
  // Progress tracking variables
  String _currentAnime = '';
  int _currentIndex = 0;
  int _totalAnime = 0;

  // Season and year
  String _selectedSeason = '';
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _hostController.text = EnvConfig.defaultHost;
    _usernameController.text = EnvConfig.defaultUsername;
    _passwordController.text = EnvConfig.defaultPassword;
    _loadConnectionSettings();
    _loadScrapedLists();
    _initializeSeasonAndYear();
  }

  void _initializeSeasonAndYear() {
    // Get current season information
    final seasonData = SeasonUtils.getCurrentSeason();

    setState(() {
      _selectedSeason = seasonData.season;
      _selectedYear = seasonData.year;
      _seasonController.text = seasonData.season;
      _yearController.text = seasonData.year.toString();
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _seasonController.dispose();
    _yearController.dispose();
    _animeListController.dispose();
    super.dispose();
  }

  Future<void> _loadConnectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostController.text =
          prefs.getString('qb_host') ?? 'http://localhost:8080';
      _usernameController.text = prefs.getString('qb_username') ?? '';
      _passwordController.text = prefs.getString('qb_password') ?? '';
    });
  }

  Future<void> _saveConnectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qb_host', _hostController.text);
    await prefs.setString('qb_username', _usernameController.text);
    await prefs.setString('qb_password', _passwordController.text);
  }

  // Load saved scraped anime lists
  Future<void> _loadScrapedLists() async {
    try {
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
          _availableLists = _savedLists.keys.toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading saved lists: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _connectToQBittorrent() async {
    if (_hostController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a host URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Connecting...';
    });

    try {
      final qbClient = QBittorrentAPI(
        host: _hostController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );

      final success = await qbClient.login();

      if (success) {
        final version = await qbClient.getAppVersion();

        setState(() {
          _connectionStatus = 'Connected to qBittorrent $version';
          _isConnecting = false;
        });

        // Save settings on successful connection
        await _saveConnectionSettings();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully connected to qBittorrent $version'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _connectionStatus = 'Connection failed';
          _isConnecting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to connect to qBittorrent. Check credentials and URL.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: $e';
        _isConnecting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to qBittorrent: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Sanitizes a directory name for safe use across operating systems
  String sanitizeDirectoryName(String name) {
    // First, replace problematic characters
    String sanitized =
        name
            .replaceAll(':', '_')
            .replaceAll('/', '_')
            .replaceAll('\\', '_')
            .replaceAll('<', '_')
            .replaceAll('>', '_')
            .replaceAll('"', '_')
            .replaceAll('\'', '_')
            .replaceAll('|', '_')
            .replaceAll('?', '_')
            .replaceAll('*', '_')
            .replaceAll('&', 'and')
            .trim();

    // If the name ends with a period, remove it or replace it
    if (sanitized.endsWith('.')) {
      sanitized = '${sanitized.substring(0, sanitized.length - 1)}_';
    }

    return sanitized;
  }

  Future<void> _processAnimeList() async {
    if (_selectedListName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a list first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_connectionStatus.startsWith('Not connected') ||
        _connectionStatus.startsWith('Connection failed') ||
        _connectionStatus.startsWith('Error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to qBittorrent first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingResults = {
        'success': <Map<String, String>>[],
        'failed': <Map<String, String>>[],
        'skipped': <Map<String, String>>[],
      };
      _currentAnime = '';
      _currentIndex = 0;
      _totalAnime = 0;
    });

    try {
      // Get the selected list of anime
      final animeList = _savedLists[_selectedListName!] ?? [];

      if (animeList.isEmpty) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected list contains no anime'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Initialize progress tracking
      setState(() {
        _totalAnime = animeList.length;
        _currentIndex = 0;
      });

      final qbClient = QBittorrentAPI(
        host: _hostController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );

      // Login
      final loggedIn = await qbClient.login();
      if (!loggedIn) {
        setState(() {
          _isProcessing = false;
          _processingResults['failed'] = [{'anime': 'Login', 'reason': 'Failed to login to qBittorrent'}];
        });
        return;
      }

      // Get app state for custom directory settings
      final appState = Provider.of<AppState>(context, listen: false);
      final useCustomDir = appState.useCustomDir;
      final customDirPath = appState.customDirPath;

      // Create season prefix for feed/rule names
      final seasonPrefix = '${_selectedSeason.toUpperCase()}_${_selectedYear}_';

      // Process each anime
      for (int i = 0; i < animeList.length; i++) {
        final anime = animeList[i];
        
        // Update progress
        setState(() {
          _currentIndex = i + 1;
          _currentAnime = anime.title;
        });
        
        // Skip entries without valid RSS URL
        if (anime.rssUrl.isEmpty || !anime.rssUrl.startsWith('http')) {
          _processingResults['skipped'].add({
            'anime': anime.title,
            'reason': 'No valid RSS URL'
          });
          setState(() {});
          continue;
        }

        // Create sanitized anime title for directory name
        final sanitizedTitle = sanitizeDirectoryName(anime.title);

        // Create feed name with season prefix
        final feedName = '$seasonPrefix${anime.title}';

        // Add RSS feed with detailed error handling
        final feedResult = await qbClient.addFeedWithDetails(anime.rssUrl, feedName);
        
        if (!feedResult['success']) {
          if (feedResult['alreadyExists'] == true) {
            // Feed already exists, continue to check rule
            print('Feed already exists for ${anime.title}, checking rule...');
          } else {
            // Feed failed to add for another reason
            _processingResults['failed'].add({
              'anime': anime.title,
              'reason': 'Failed to add RSS feed: ${feedResult['error']}'
            });
            setState(() {});
            continue;
          }
        }

        // Wait a moment to ensure the feed is registered
        await Future.delayed(const Duration(milliseconds: 1000));

        // Determine save path
        String? savePath;
        if (useCustomDir) {
          final basePath = customDirPath.trim();
          savePath = '$basePath/$sanitizedTitle';
        } else {
          savePath = sanitizedTitle;
        }

        // Create the rule name
        final ruleName = '$seasonPrefix${anime.title}';

        // Add RSS rule with detailed error handling
        final ruleResult = await qbClient.addRuleWithSavePathDetails(
          ruleName, // Rule name
          feedName, // Feed title - our modified function will find the URL
          savePath, // Save path
        );

        if (ruleResult['success']) {
          _processingResults['success'].add({
            'anime': anime.title,
            'reason': 'Successfully added (Save path: $savePath)'
          });
        } else {
          if (ruleResult['alreadyExists'] == true) {
            // Both feed and rule already exist
            if (feedResult['alreadyExists'] == true) {
              _processingResults['skipped'].add({
                'anime': anime.title,
                'reason': 'Feed and rule already exist (already configured)'
              });
            } else {
              _processingResults['skipped'].add({
                'anime': anime.title,
                'reason': 'Rule already exists (already configured)'
              });
            }
          } else {
            // Rule failed to add for another reason
            _processingResults['failed'].add({
              'anime': anime.title,
              'reason': 'Failed to add RSS rule: ${ruleResult['error']}'
            });
          }
        }

        // Update UI
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing anime list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Anime to qBittorent')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connection Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host URL',
                  hintText: 'http://localhost:8080',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.link),
                      label: const Text('Connect'),
                      onPressed: _isConnecting ? null : _connectToQBittorrent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                'Status: $_connectionStatus',
                style: TextStyle(
                  color:
                      _connectionStatus.startsWith('Connected')
                          ? Colors.green
                          : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Divider(height: 32),

              const Text(
                'Season Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Season and Year selection
              Row(
                children: [
                  Expanded(
                    child: DropdownMenu<String>(
                      controller: _seasonController,
                      label: const Text('Anime Season'),
                      initialSelection: _selectedSeason,
                      onSelected: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSeason = value;
                          });
                        }
                      },
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'winter', label: 'Winter'),
                        DropdownMenuEntry(value: 'spring', label: 'Spring'),
                        DropdownMenuEntry(value: 'summer', label: 'Summer'),
                        DropdownMenuEntry(value: 'fall', label: 'Fall'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownMenu<int>(
                      controller: _yearController,
                      label: const Text('Year'),
                      initialSelection: _selectedYear,
                      menuHeight: 250,
                      onSelected: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedYear = value;
                          });
                        }
                      },
                      dropdownMenuEntries: List.generate(
                        DateTime.now().year - 1959, // From current year to 1960
                        (index) {
                          final year = DateTime.now().year - index;
                          return DropdownMenuEntry(
                            value: year,
                            label: year.toString(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Information about custom directory settings
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Consumer<AppState>(
                  builder: (context, appState, _) {
                    if (appState.useCustomDir) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Custom Save Directory Enabled',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'All anime will be saved to: ${appState.customDirPath}/{animeName}',
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This setting can be changed in the App Settings page.',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              color: Colors.grey,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Using default save location (no custom directory)',
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),

              const Divider(height: 32),

              Text(
                'Process Anime List',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              DropdownMenu<String>(
                controller: _animeListController,
                label: const Text('Select Scraped Anime List'),
                hintText: 'Choose a list',
                width:
                    MediaQuery.of(context).size.width -
                    32, // Account for padding
                initialSelection: _selectedListName,
                onSelected: (value) {
                  setState(() {
                    _selectedListName = value;
                  });
                },
                dropdownMenuEntries:
                    _availableLists.map((listName) {
                      return DropdownMenuEntry(
                        value: listName,
                        label:
                            listName.length > 40
                                ? '...${listName.substring(listName.length - 40)}'
                                : listName,
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Add Selected List to qBittorrent'),
                      onPressed:
                          _isProcessing || _selectedListName == null
                              ? null
                              : _processAnimeList,
                    ),
                  ),
                ],
              ),

              if (_isProcessing)
                _buildProcessingProgress(),

              if (_processingResults.isNotEmpty && !_isProcessing)
                _buildResultsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingProgress() {
    if (_totalAnime == 0) return const SizedBox.shrink();
    
    final progress = _currentIndex / _totalAnime;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Processing Anime List',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            
            // Current anime and progress info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Currently Processing:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentAnime.isNotEmpty ? _currentAnime : 'Initializing...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '$_currentIndex/$_totalAnime',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Percentage
            Text(
              '${(progress * 100).toStringAsFixed(1)}% Complete',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Processing Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildResultSection(
              'Successful',
              _processingResults['success'] ?? [],
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildResultSection(
              'Failed',
              _processingResults['failed'] ?? [],
              Colors.red,
            ),
            const SizedBox(height: 8),
            _buildResultSection(
              'Skipped',
              _processingResults['skipped'] ?? [],
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection(String title, List<dynamic> items, Color color) {
    return ExpansionTile(
      title: Text('$title (${items.length})', style: TextStyle(color: color)),
      children: [
        if (items.isEmpty)
          const Padding(padding: EdgeInsets.all(8.0), child: Text('None'))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is Map<String, String>) {
                return ListTile(
                  title: Text(item['anime'] ?? 'Unknown'),
                  subtitle: Text(
                    item['reason'] ?? 'No reason provided',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  dense: true,
                );
              } else {
                // Fallback for old string format
                return ListTile(title: Text(item.toString()), dense: true);
              }
            },
          ),
      ],
    );
  }
}
