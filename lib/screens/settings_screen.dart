import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _qbHostController = TextEditingController();
  final _qbUsernameController = TextEditingController();
  final _qbPasswordController = TextEditingController();
  String _selectedFansubber = '';
  bool _isDarkMode = false;
  bool _showAdult = false;
  bool _isSettingsChanged = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _qbHostController.text = prefs.getString('qb_host') ?? '';
      _qbUsernameController.text = prefs.getString('qb_username') ?? '';
      _qbPasswordController.text = prefs.getString('qb_password') ?? '';
      _selectedFansubber = prefs.getString('preferred_fansubber') ?? kDefaultFansubber;
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _showAdult = prefs.getBool('show_adult') ?? false;
    });
  }
  
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final appState = Provider.of<AppState>(context, listen: false);
    
    await prefs.setString('qb_host', _qbHostController.text);
    await prefs.setString('qb_username', _qbUsernameController.text);
    await prefs.setString('qb_password', _qbPasswordController.text);
    await prefs.setString('preferred_fansubber', _selectedFansubber);
    await prefs.setBool('dark_mode', _isDarkMode);
    await prefs.setBool('show_adult', _showAdult);
    
    appState.preferredFansubber = _selectedFansubber;
    appState.isDarkMode = _isDarkMode;
    appState.showAdult = _showAdult;
    
    setState(() {
      _isSettingsChanged = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isSettingsChanged)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Save Settings',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // App Appearance Section
          const Text(
            'App Appearance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() {
                _isDarkMode = value;
                _isSettingsChanged = true;
              });
            },
          ),
          
          const SizedBox(height: 24),
          
          // Anime Settings
          const Text(
            'Anime Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Preferred Fansubber',
            ),
            value: _selectedFansubber,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedFansubber = newValue;
                  _isSettingsChanged = true;
                });
              }
            },
            items: kFansubbers.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          
          SwitchListTile(
            title: const Text('Show Adult Content'),
            subtitle: const Text('Include adult anime in search results'),
            value: _showAdult,
            onChanged: (value) {
              setState(() {
                _showAdult = value;
                _isSettingsChanged = true;
              });
            },
          ),
          
          const SizedBox(height: 24),
          
          // qBittorrent Settings
          const Text(
            'qBittorrent Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          TextField(
            controller: _qbHostController,
            decoration: const InputDecoration(
              labelText: 'qBittorrent Host URL',
              hintText: 'http://localhost:8080',
            ),
            onChanged: (_) => setState(() => _isSettingsChanged = true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qbUsernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
            ),
            onChanged: (_) => setState(() => _isSettingsChanged = true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qbPasswordController,
            decoration: const InputDecoration(
              labelText: 'Password',
            ),
            obscureText: true,
            onChanged: (_) => setState(() => _isSettingsChanged = true),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.connect_without_contact),
            label: const Text('Test qBittorrent Connection'),
            onPressed: _testQBittorrentConnection,
          ),
          
          const SizedBox(height: 24),
          
          // Save Button
          ElevatedButton(
            onPressed: _isSettingsChanged ? _saveSettings : null,
            child: const Text('Save All Settings'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _testQBittorrentConnection() async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    try {
      final result = await appState.testQBittorrentConnection(
        host: _qbHostController.text,
        username: _qbUsernameController.text,
        password: _qbPasswordController.text,
      );
      
      if (mounted) {
        if (result['status'] == 'Success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection successful: ${result['version']}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection failed: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _qbHostController.dispose();
    _qbUsernameController.dispose();
    _qbPasswordController.dispose();
    super.dispose();
  }
} 