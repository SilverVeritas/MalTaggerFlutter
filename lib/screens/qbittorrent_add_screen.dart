import 'package:flutter/material.dart';
import '../services/file_utils.dart';
import '../services/qbittorrent_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';

class QBittorrentAddScreen extends StatefulWidget {
  const QBittorrentAddScreen({super.key});

  @override
  State<QBittorrentAddScreen> createState() => _QBittorrentAddScreenState();
}

class _QBittorrentAddScreenState extends State<QBittorrentAddScreen> {
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isConnecting = false;
  bool _isProcessing = false;
  String _connectionStatus = 'Not connected';
  String? _selectedFile;
  List<String> _savedFiles = [];
  Map<String, dynamic> _processingResults = {};
  
  @override
  void initState() {
    super.initState();
    _hostController.text = EnvConfig.defaultHost;
    _usernameController.text = EnvConfig.defaultUsername;
    _passwordController.text = EnvConfig.defaultPassword;
    _loadConnectionSettings();
    _loadSavedFiles();
  }
  
  @override
  void dispose() {
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
  
  Future<void> _loadSavedFiles() async {
    try {
      final files = await FileUtils.getSavedFiles();
      setState(() {
        _savedFiles = files;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading saved files: $e'),
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
  
  Future<void> _processAnimeList() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file first'),
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
        'success': <String>[],
        'failed': <String>[],
        'skipped': <String>[],
      };
    });
    
    try {
      // Load anime list from selected file
      final animeList = await FileUtils.loadAnimeList(_selectedFile!);
      
      if (animeList.isEmpty) {
        setState(() {
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected file contains no anime'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
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
          _processingResults['failed'] = ['Failed to login to qBittorrent'];
        });
        return;
      }
      
      // Process each anime
      for (final anime in animeList) {
        // Skip entries without valid RSS URL
        if (anime.rssUrl.isEmpty || !anime.rssUrl.startsWith('http')) {
          _processingResults['skipped'].add('${anime.title} (No valid RSS URL)');
          continue;
        }
        
        // Add RSS feed
        final feedAdded = await qbClient.addFeed(anime.rssUrl, anime.title);
        if (!feedAdded) {
          _processingResults['failed'].add('${anime.title} (Failed to add RSS feed)');
          continue;
        }
        
        // Add RSS rule
        final ruleAdded = await qbClient.addRule(
          anime.title,  // Rule name
          anime.title,  // Must contain
          '1-9999',    // Episode range
          anime.title,  // Feed title
        );
        
        if (ruleAdded) {
          _processingResults['success'].add(anime.title);
        } else {
          _processingResults['failed'].add('${anime.title} (Failed to add RSS rule)');
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
  
  Future<void> _testSimpleConnection() async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Testing connection...';
    });
    
    try {
      final qbClient = QBittorrentAPI(
        host: _hostController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
      
      final result = await qbClient.testConnection();
      
      setState(() {
        _connectionStatus = result['message'] as String? ?? 'Unknown result';
        _isConnecting = false;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection test error: $e';
        _isConnecting = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('qBittorrent Integration'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connection Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Username',
                ),
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
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
              
              const Divider(height: 32),
              
              const Text(
                'Process Anime List',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Saved Anime List',
                ),
                value: _selectedFile,
                items: _savedFiles.map((filename) {
                  return DropdownMenuItem(
                    value: filename,
                    child: Text(
                      filename.length > 40 
                          ? '...${filename.substring(filename.length - 40)}' 
                          : filename,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFile = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Process Selected List'),
                      onPressed: _isProcessing || _selectedFile == null 
                          ? null 
                          : _processAnimeList,
                    ),
                  ),
                ],
              ),
              
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              
              if (_processingResults.isNotEmpty && !_isProcessing)
                _buildResultsSection(),
              
              ElevatedButton(
                onPressed: _isConnecting ? null : _testSimpleConnection,
                child: const Text('Test Connection'),
              ),
            ],
          ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
      title: Text(
        '$title (${items.length})',
        style: TextStyle(color: color),
      ),
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('None'),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(items[index]),
                dense: true,
              );
            },
          ),
      ],
    );
  }
} 