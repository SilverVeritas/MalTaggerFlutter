import 'dart:convert';
import 'package:http/http.dart' as http;

class QBittorrentAPI {
  final String host;
  final String username;
  final String password;
  final http.Client _client = http.Client();
  String? _sessionCookie;

  QBittorrentAPI({
    required this.host,
    required this.username,
    required this.password,
  });

  // Clean up the host URL to ensure proper formatting
  String get _baseUrl {
    if (host.isEmpty) return '';

    String normalizedHost = host;
    if (normalizedHost.endsWith('/')) {
      normalizedHost = normalizedHost.substring(0, normalizedHost.length - 1);
    }
    return normalizedHost;
  }

  Future<bool> login() async {
    try {
      final url = '$_baseUrl/api/v2/auth/login';
      print('Attempting to login to qBittorrent at $url');

      final response = await _client
          .post(
            Uri.parse(url),
            body: {'username': username, 'password': password},
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Referer': _baseUrl, // Required according to docs
            },
          )
          .timeout(const Duration(seconds: 10));

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200 && response.body == 'Ok.') {
        if (response.headers.containsKey('set-cookie')) {
          _sessionCookie = response.headers['set-cookie'];
          print('Session cookie received: $_sessionCookie');
          return true;
        } else {
          print('Warning: No set-cookie header in response');
          // Some qBittorrent versions might not return a cookie
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Login failed with error: $e');
      return false;
    }
  }

  // Add this method inside the QBittorrentAPI class
  Future<bool> addRuleWithSavePath(
    String name,
    String feedTitle,
    String? savePath,
  ) async {
    try {
      // Ensure we have a valid session
      if (_sessionCookie == null) {
        if (!await login()) return false;
      }

      // Get the actual RSS feeds to find the URL
      final feeds = await getRssFeeds();

      // Find the feed URL based on the feed title
      String? feedUrl;
      for (var key in feeds.keys) {
        if (key == feedTitle || key.contains(feedTitle)) {
          feedUrl = feeds[key]['url'];
          break;
        }
      }

      // If we can't find the feed URL, we can't create the rule
      if (feedUrl == null) {
        print('Could not find URL for feed: $feedTitle');
        return false;
      }

      // Create rule definition with the actual feed URL
      final ruleDefinition = jsonEncode({
        'enabled': true,
        'mustContain': '',
        'mustNotContain': '',
        'useRegex': false,
        'episodeFilter': '',
        'smartFilter': false,
        'previouslyMatchedEpisodes': [],
        'affectedFeeds': [feedUrl], // Use the actual feed URL
        'ignoreDays': 0,
        'lastMatch': '',
        'addPaused': false,
        'assignedCategory': '',
        'savePath': savePath ?? '',
      });

      print('Adding rule: $name for feed URL: $feedUrl');

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/v2/rss/setRule'),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'ruleName': name, 'ruleDef': ruleDefinition},
      );

      // If unauthorized, try to login again
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (await login()) {
          return addRuleWithSavePath(name, feedTitle, savePath);
        }
        return false;
      }

      print('Add rule response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to add rule: $e');
      return false;
    }
  }

  Future<String?> getExactFeedPath(String feedName) async {
    try {
      // Ensure we have a valid session
      if (_sessionCookie == null) {
        if (!await login()) return null;
      }

      // Get all RSS feeds
      final feeds = await getRssFeeds();

      // Look for our feed by name
      for (var key in feeds.keys) {
        // Check if this key is our feed or contains our feed name
        if (key == feedName || key.endsWith('/$feedName')) {
          return key; // Return the exact feed path as used by qBittorrent
        }
      }

      // If we couldn't find an exact match, return the original name
      // (it might be hierarchical in qBittorrent's structure)
      return feedName;
    } catch (e) {
      print('Error finding feed path: $e');
      return feedName; // Return original as fallback
    }
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Referer': _baseUrl, // Required according to docs
    };

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    return headers;
  }

  Future<String> getAppVersion() async {
    try {
      final url = '$_baseUrl/api/v2/app/version';
      final response = await _client.get(Uri.parse(url), headers: _headers);

      return response.statusCode == 200
          ? response.body
          : 'Error: ${response.statusCode}';
    } catch (e) {
      print('Failed to get app version: $e');
      return 'Error: $e';
    }
  }

  Future<bool> addFeed(String url, String title) async {
    try {
      // Ensure we have a valid session
      if (_sessionCookie == null) {
        if (!await login()) return false;
      }

      final apiUrl = '$_baseUrl/api/v2/rss/addFeed';
      final response = await _client.post(
        Uri.parse(apiUrl),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'url': url, 'path': title},
      );

      // If unauthorized, try to login again
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (await login()) {
          return addFeed(url, title); // Retry with new session
        }
        return false;
      }

      print('Add feed response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to add feed: $e');
      return false;
    }
  }

  Future<bool> addRule(
    String name,
    String mustContain,
    String episode,
    String feedTitle,
  ) async {
    try {
      // Ensure we have a valid session
      if (_sessionCookie == null) {
        if (!await login()) return false;
      }

      final apiUrl = '$_baseUrl/api/v2/rss/setRule';

      // Create rule definition with must contain field and episode filter
      final ruleDefinition = jsonEncode({
        'enabled': true,
        'mustContain': mustContain,
        'mustNotContain': '',
        'useRegex': false,
        'episodeFilter': episode,
        'smartFilter': false,
        'previouslyMatchedEpisodes': [],
        'affectedFeeds': [feedTitle],
        'ignoreDays': 0,
        'lastMatch': '',
        'addPaused': false,
        'assignedCategory': '',
        'savePath': '',
      });

      final response = await _client.post(
        Uri.parse(apiUrl),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'ruleName': name, 'ruleDef': ruleDefinition},
      );

      // If unauthorized, try to login again
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (await login()) {
          return addRule(
            name,
            mustContain,
            episode,
            feedTitle,
          ); // Retry with new session
        }
        return false;
      }

      print('Add rule response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to add rule: $e');
      return false;
    }
  }

  Future<bool> deleteFeed(String feedPath) async {
    try {
      // Ensure we have a valid session
      if (_sessionCookie == null) {
        if (!await login()) return false;
      }

      final apiUrl = '$_baseUrl/api/v2/rss/removeItem';
      final response = await _client.post(
        Uri.parse(apiUrl),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'path': feedPath},
      );

      // If unauthorized, try to login again
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (await login()) {
          return deleteFeed(feedPath); // Retry with new session
        }
        return false;
      }

      print('Delete feed response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to delete feed: $e');
      return false;
    }
  }

  Future<bool> deleteRule(String ruleName) async {
    try {
      // Ensure we have a valid session
      if (_sessionCookie == null) {
        if (!await login()) return false;
      }

      final apiUrl = '$_baseUrl/api/v2/rss/removeRule';
      final response = await _client.post(
        Uri.parse(apiUrl),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'ruleName': ruleName},
      );

      // If unauthorized, try to login again
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (await login()) {
          return deleteRule(ruleName); // Retry with new session
        }
        return false;
      }

      print('Delete rule response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to delete rule: $e');
      return false;
    }
  }

  Future<bool> refreshFeed(String feedPath) async {
    try {
      // Ensure we have a valid session
      if (_sessionCookie == null) {
        if (!await login()) return false;
      }

      final apiUrl = '$_baseUrl/api/v2/rss/refreshItem';
      final response = await _client.post(
        Uri.parse(apiUrl),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'itemPath': feedPath},
      );

      // If unauthorized, try to login again
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (await login()) {
          return refreshFeed(feedPath); // Retry with new session
        }
        return false;
      }

      print('Refresh feed response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to refresh feed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getRssFeeds() async {
    try {
      final url = '$_baseUrl/api/v2/rss/items';
      final response = await _client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print(
          'Failed to get RSS feeds: ${response.statusCode} - ${response.body}',
        );
        return {};
      }
    } catch (e) {
      print('Error getting RSS feeds: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getRssRules() async {
    try {
      final url = '$_baseUrl/api/v2/rss/rules';
      final response = await _client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print(
          'Failed to get RSS rules: ${response.statusCode} - ${response.body}',
        );
        return {};
      }
    } catch (e) {
      print('Error getting RSS rules: $e');
      return {};
    }
  }

  // Test connection method for debugging
  Future<Map<String, dynamic>> testConnection() async {
    try {
      if (await login()) {
        final version = await getAppVersion();

        return {
          'status': 'Success',
          'version': version,
          'message': 'Connected successfully, version: $version',
          'cookie': _sessionCookie != null ? 'Cookie received' : 'No cookie',
        };
      } else {
        return {'status': 'Failed', 'message': 'Login failed'};
      }
    } catch (e) {
      return {'status': 'Error', 'message': e.toString()};
    }
  }

  void dispose() {
    _client.close();
  }
}

// Helper function to get the minimum of two integers
int min(int a, int b) => a < b ? a : b;
