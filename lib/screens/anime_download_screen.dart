import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/qbittorrent_api.dart';
import '../services/app_state.dart';
import '../services/jikan_api_service.dart';
import '../services/rss_utils.dart';
import '../widgets/anime_search_dialog.dart';
import '../models/anime.dart';
import '../config/env_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnimeDownloadScreen extends StatefulWidget {
  const AnimeDownloadScreen({super.key});

  @override
  State<AnimeDownloadScreen> createState() => _AnimeDownloadScreenState();
}

class _AnimeDownloadScreenState extends State<AnimeDownloadScreen> {
  final _jikanService = JikanApiService();
  final _fansubberController = TextEditingController();
  
  // Connection settings controllers
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isConnecting = false;
  bool _isProcessing = false;
  String _connectionStatus = 'Not connected';
  
  // Selected anime
  Anime? _selectedAnime;
  
  @override
  void initState() {
    super.initState();
    _hostController.text = EnvConfig.defaultHost;
    _usernameController.text = EnvConfig.defaultUsername;
    _passwordController.text = EnvConfig.defaultPassword;
    _loadConnectionSettings();
  }
  
  @override
  void dispose() {
    _fansubberController.dispose();
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _loadConnectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostController.text = prefs.getString('qb_host') ?? 'http://localhost:8080';
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
            content: Text('Failed to connect to qBittorrent. Check credentials and URL.'),
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
  
  void _searchAnime() {
    showDialog(
      context: context,
      builder: (context) => AnimeSearchDialog(
        onAnimeSelected: (malId) async {
          Navigator.of(context).pop();
          await _fetchAnimeDetails(malId);
        },
      ),
    );
  }
  
  Future<void> _fetchAnimeDetails(int malId) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final anime = await _jikanService.getAnimeDetails(malId);
      if (anime != null) {
        setState(() {
          _selectedAnime = anime;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not fetch anime details'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching anime details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String sanitizeDirectoryName(String name) {
    String sanitized = name
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
    
    if (sanitized.endsWith('.')) {
      sanitized = '${sanitized.substring(0, sanitized.length - 1)}_';
    }
    
    return sanitized;
  }
  
  Future<void> _downloadAnime() async {
    if (_selectedAnime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an anime first'),
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
    });
    
    try {
      final qbClient = QBittorrentAPI(
        host: _hostController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
      
      final loggedIn = await qbClient.login();
      if (!loggedIn) {
        throw Exception('Failed to login to qBittorrent');
      }
      
      // Get app state for custom directory settings
      final appState = Provider.of<AppState>(context, listen: false);
      final useCustomDir = appState.useCustomDir;
      final customDirPath = appState.customDirPath;
      
      // Create RSS URL
      final rssUrl = RssUtils.formatRssUrl(_selectedAnime!.title, _fansubberController.text);
      
      // Create sanitized anime title for directory name
      final sanitizedTitle = sanitizeDirectoryName(_selectedAnime!.title);
      
      // Add RSS feed
      final feedName = _selectedAnime!.title;
      final feedResult = await qbClient.addFeedWithDetails(rssUrl, feedName);
      
      if (!feedResult['success'] && feedResult['alreadyExists'] != true) {
        throw Exception('Failed to add RSS feed: ${feedResult['error']}');
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
      
      // Add RSS rule
      final ruleName = _selectedAnime!.title;
      final ruleResult = await qbClient.addRuleWithSavePathDetails(
        ruleName,
        feedName,
        savePath,
      );
      
      if (ruleResult['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added ${_selectedAnime!.title} for download'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (ruleResult['alreadyExists'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedAnime!.title} is already configured'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        throw Exception('Failed to add RSS rule: ${ruleResult['error']}');
      }
      
      setState(() {
        _isProcessing = false;
        _selectedAnime = null;
        _fansubberController.clear();
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding anime: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Anime'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'qBittorrent Connection',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Host URL',
                          hintText: 'http://localhost:8080',
                          prefixIcon: Icon(Icons.computer),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                        ),
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
                          color: _connectionStatus.startsWith('Connected')
                              ? Colors.green
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Anime selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Anime',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_selectedAnime == null)
                        Center(
                          child: Column(
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.search),
                                label: const Text('Search Anime'),
                                onPressed: _isProcessing ? null : _searchAnime,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Search for an anime to download',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            // Anime info
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _selectedAnime!.imageUrl,
                                    width: 100,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => 
                                        Container(
                                          width: 100,
                                          height: 140,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.broken_image),
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedAnime!.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${_selectedAnime!.type} • ${_selectedAnime!.episodes ?? "?"} episodes',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Status: ${_selectedAnime!.status}',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.search, size: 18),
                                        label: const Text('Change Anime'),
                                        onPressed: _isProcessing ? null : _searchAnime,
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(0, 36),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            
                            // Fansubber input
                            TextField(
                              controller: _fansubberController,
                              decoration: const InputDecoration(
                                labelText: 'Fansubber (Optional)',
                                hintText: 'e.g., SubsPlease, Erai-raws',
                                prefixIcon: Icon(Icons.group),
                                helperText: 'Leave empty to get results from all fansubbers',
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Download button
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.download),
                                    label: const Text('Add to qBittorrent'),
                                    onPressed: _isProcessing ? null : _downloadAnime,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      
                      if (_isProcessing)
                        const Padding(
                          padding: EdgeInsets.only(top: 16.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Custom directory info
              const SizedBox(height: 16),
              Consumer<AppState>(
                builder: (context, appState, _) {
                  if (appState.useCustomDir) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
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
                                  'Custom Save Directory',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Anime will be saved to: ${appState.customDirPath}/{animeName}',
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}