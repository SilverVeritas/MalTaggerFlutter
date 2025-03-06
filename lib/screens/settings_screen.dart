// File: lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../utils/text_size_utils.dart';

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
  bool _useCustomDir = false;
  String _textSizePreference = 'small'; // New text size preference
  final TextEditingController _customDirController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final appState = Provider.of<AppState>(context, listen: false);

    // Get the preferred fansubber from SharedPreferences
    final preferredFansubber =
        prefs.getString('preferred_fansubber') ?? kDefaultFansubber;

    setState(() {
      _qbHostController.text = prefs.getString('qb_host') ?? '';
      _qbUsernameController.text = prefs.getString('qb_username') ?? '';
      _qbPasswordController.text = prefs.getString('qb_password') ?? '';

      // Make sure the selected fansubber is in the kFansubbers list
      _selectedFansubber =
          kFansubbers.contains(preferredFansubber)
              ? preferredFansubber
              : kDefaultFansubber;

      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _showAdult = prefs.getBool('show_adult') ?? false;

      // Load custom directory settings
      _useCustomDir = prefs.getBool('use_custom_dir') ?? false;
      _customDirController.text = prefs.getString('custom_dir_path') ?? '/dl';

      // Also ensure these match what's in AppState
      _useCustomDir = appState.useCustomDir;
      _customDirController.text = appState.customDirPath;

      // Load text size preference
      _textSizePreference = appState.textSizePreference;
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

    // Save custom directory settings
    await prefs.setBool('use_custom_dir', _useCustomDir);
    await prefs.setString('custom_dir_path', _customDirController.text);

    // Save text size preference
    await prefs.setString('text_size_preference', _textSizePreference);

    appState.preferredFansubber = _selectedFansubber;
    appState.isDarkMode = _isDarkMode;
    appState.showAdult = _showAdult;

    // Update AppState with custom directory settings
    appState.useCustomDir = _useCustomDir;
    appState.customDirPath = _customDirController.text;

    // Update AppState with text size preference
    appState.textSizePreference = _textSizePreference;

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
    final appState = Provider.of<AppState>(context);
    final textSizeAdjustment = context.getFontSizeAdjustment(
      appState.textSizePreference,
    );

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

          // Text Size Setting
          ListTile(
            title: const Text('Text Size'),
            subtitle: const Text('Change the size of text throughout the app'),
            trailing: DropdownButton<String>(
              value: _textSizePreference,
              underline: const SizedBox(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _textSizePreference = newValue;
                    _isSettingsChanged = true;
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: 'small', child: Text('Small')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'large', child: Text('Large')),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Anime Settings
          const Text(
            'Anime Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Preferred Fansubber'),
            value:
                kFansubberOptions.contains(_selectedFansubber)
                    ? _selectedFansubber
                    : kDefaultFansubber, // Ensure the value exists in items
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedFansubber = newValue;
                  _isSettingsChanged = true;
                });
              }
            },
            items:
                kFansubberOptions.map<DropdownMenuItem<String>>((String value) {
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
            decoration: const InputDecoration(labelText: 'Username'),
            onChanged: (_) => setState(() => _isSettingsChanged = true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qbPasswordController,
            decoration: const InputDecoration(labelText: 'Password'),
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

          const Text(
            'qBittorrent Download Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Use Custom Save Directory'),
            subtitle: const Text('Save to a specific base directory'),
            value: _useCustomDir,
            onChanged: (value) {
              setState(() {
                _useCustomDir = value;
                _isSettingsChanged = true;
              });
            },
          ),
          if (_useCustomDir) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customDirController,
              decoration: InputDecoration(
                labelText: 'Base Directory Path',
                hintText: '/dl',
                helperText:
                    'Anime will be saved to "${_customDirController.text}/{animeName}"',
              ),
              onChanged: (_) => setState(() => _isSettingsChanged = true),
            ),
          ],

          // Save Button
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSettingsChanged ? _saveSettings : null,
            child: const Text('Save All Settings'),
          ),

          // Information about how settings are applied
          if (_isSettingsChanged)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Remember to save your changes for them to take effect.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Preview of text sizes
          if (_isSettingsChanged &&
              _textSizePreference != appState.textSizePreference) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Text Size Preview',
                    style: TextStyle(
                      fontSize: 16 + textSizeAdjustment,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is how text will appear throughout the app.',
                    style: TextStyle(fontSize: 14 + textSizeAdjustment),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Small details and UI elements',
                    style: TextStyle(
                      fontSize: 12 + textSizeAdjustment,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _qbHostController.dispose();
    _qbUsernameController.dispose();
    _qbPasswordController.dispose();
    _customDirController.dispose();
    super.dispose();
  }
}
