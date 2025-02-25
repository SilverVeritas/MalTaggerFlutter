import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/qbittorrent_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';

class QBittorrentDashboardScreen extends StatefulWidget {
  const QBittorrentDashboardScreen({super.key});

  @override
  State<QBittorrentDashboardScreen> createState() => _QBittorrentDashboardScreenState();
}

class _QBittorrentDashboardScreenState extends State<QBittorrentDashboardScreen> {
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isConnecting = false;
  String _connectionStatus = 'Not connected';
  DateTime? _lastRefresh;
  
  Map<String, dynamic> _rssFeeds = {};
  Map<String, dynamic> _rssRules = {};
  
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
          _connectionStatus = 'Connected to qBittorrent ${version ?? "unknown version"}';
          _isConnecting = false;
        });
        
        // Save connection settings
        await _saveConnectionSettings();
        
        // Update app state
        final appState = Provider.of<AppState>(context, listen: false);
        appState.setQbConnected(true);
        
        // Fetch initial data
        await _refreshData(qbClient);
      } else {
        setState(() {
          _connectionStatus = 'Connection failed. Check credentials.';
          _isConnecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: $e';
        _isConnecting = false;
      });
    }
  }
  
  Future<void> _refreshData(QBittorrentAPI qbClient) async {
    try {
      final feeds = await qbClient.getRssFeeds();
      final rules = await qbClient.getRssRules();
      
      setState(() {
        _rssFeeds = feeds;
        _rssRules = rules;
        _lastRefresh = DateTime.now();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('qBittorrent Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionPanel(),
            const SizedBox(height: 16),
            if (appState.qbConnected) _buildDashboardContent(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectionPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'qBittorrent Connection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Host URL',
                hintText: 'http://localhost:8080',
                border: OutlineInputBorder(),
              ),
              enabled: !_isConnecting,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
              enabled: !_isConnecting,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              enabled: !_isConnecting,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : _connectToQBittorrent,
                    child: _isConnecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _connectionStatus,
              style: TextStyle(
                color: _connectionStatus.contains('Connected')
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDashboardContent() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                onPressed: () {
                  final qbClient = QBittorrentAPI(
                    host: _hostController.text,
                    username: _usernameController.text,
                    password: _passwordController.text,
                  );
                  
                  qbClient.login().then((success) {
                    if (success) {
                      _refreshData(qbClient);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to reconnect. Please check your credentials.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  });
                },
              ),
            ],
          ),
          if (_lastRefresh != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Last refreshed: ${_lastRefresh!.hour.toString().padLeft(2, '0')}:${_lastRefresh!.minute.toString().padLeft(2, '0')}:${_lastRefresh!.second.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'RSS Feeds'),
                      Tab(text: 'RSS Rules'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRssFeedsTab(),
                        _buildRssRulesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRssFeedsTab() {
    if (_rssFeeds.isEmpty) {
      return const Center(
        child: Text('No RSS feeds found'),
      );
    }
    
    return ListView.builder(
      itemCount: _rssFeeds.length,
      itemBuilder: (context, index) {
        final feedName = _rssFeeds.keys.elementAt(index);
        final feedData = _rssFeeds[feedName];
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ExpansionTile(
            title: Text(feedName),
            subtitle: Text('${feedData['articles']?.length ?? 0} articles'),
            children: [
              if (feedData['articles'] != null)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: min(5, feedData['articles'].length),
                  itemBuilder: (context, articleIndex) {
                    final article = feedData['articles'][articleIndex];
                    return ListTile(
                      title: Text(article['title'] ?? 'No title'),
                      subtitle: Text(article['date'] ?? 'No date'),
                      dense: true,
                    );
                  },
                ),
              if (feedData['articles']?.length > 5)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('... and ${feedData['articles'].length - 5} more'),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildRssRulesTab() {
    if (_rssRules.isEmpty) {
      return const Center(
        child: Text('No RSS rules found'),
      );
    }
    
    return ListView.builder(
      itemCount: _rssRules.length,
      itemBuilder: (context, index) {
        final ruleName = _rssRules.keys.elementAt(index);
        final ruleData = _rssRules[ruleName];
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ExpansionTile(
            title: Text(ruleName),
            subtitle: Text('${ruleData['affectedFeeds']?.length ?? 0} feeds'),
            children: [
              ListTile(
                title: const Text('Rule Definition'),
                subtitle: Text(ruleData['ruleDefinition'] ?? 'No definition'),
                dense: true,
              ),
              if (ruleData['affectedFeeds'] != null)
                ListTile(
                  title: const Text('Affected Feeds'),
                  subtitle: Text(
                    (ruleData['affectedFeeds'] as List).join(', '),
                  ),
                  dense: true,
                ),
            ],
          ),
        );
      },
    );
  }
}

// Helper function to get the minimum of two integers
int min(int a, int b) => a < b ? a : b; 