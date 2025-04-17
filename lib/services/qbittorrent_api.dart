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

      // Get all RSS feeds
      final feedsResponse = await _client.get(
        Uri.parse('$_baseUrl/api/v2/rss/items'),
        headers: _headers,
      );

      if (feedsResponse.statusCode != 200) {
        print('Failed to get RSS feeds: ${feedsResponse.statusCode}');
        return false;
      }

      final feedsData = json.decode(feedsResponse.body);

      // Extract the feed URL from the feedsData
      String? feedUrl;

      // The feed info is structured as {feedTitle: {uid: {...}, url: "..."}}
      if (feedsData is Map && feedsData.containsKey(feedTitle)) {
        final feedInfo = feedsData[feedTitle];
        if (feedInfo is Map && feedInfo.containsKey('url')) {
          feedUrl = feedInfo['url'];
          print('Found URL for feed: $feedTitle, URL: $feedUrl');
        }
      }

      if (feedUrl == null) {
        print(
          'Could not find URL for feed: $feedTitle, using feed title directly',
        );
        return false;
      }

      // First, check if any rules already exist for this feed
      final rulesResponse = await _client.get(
        Uri.parse('$_baseUrl/api/v2/rss/rules'),
        headers: _headers,
      );

      Map<String, dynamic> existingRules = {};
      if (rulesResponse.statusCode == 200) {
        existingRules = json.decode(rulesResponse.body);
      }

      // Create a rule with explicit matching for this feed
      final ruleDefinition = jsonEncode({
        'enabled': true,
        'mustContain': '', // Empty means match everything
        'mustNotContain': '',
        'useRegex': false,
        'episodeFilter': '',
        'smartFilter': false,
        'previouslyMatchedEpisodes': [],
        'affectedFeeds': [feedUrl], // Use the actual feed URL here
        'ignoreDays': 0,
        'lastMatch': '',
        'addPaused': false,
        'assignedCategory': '',
        'savePath': savePath ?? '',
      });

      print('Adding rule: $name with URL: $feedUrl and savePath: $savePath');

      // Set the rule
      final ruleResponse = await _client.post(
        Uri.parse('$_baseUrl/api/v2/rss/setRule'),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'ruleName': name, 'ruleDef': ruleDefinition},
      );

      if (ruleResponse.statusCode != 200) {
        print(
          'Failed to set rule: ${ruleResponse.statusCode} - ${ruleResponse.body}',
        );

        if (ruleResponse.statusCode == 401 || ruleResponse.statusCode == 403) {
          if (await login()) {
            return addRuleWithSavePath(name, feedTitle, savePath);
          }
        }
        return false;
      }

      print(
        'Add rule response: ${ruleResponse.statusCode} - ${ruleResponse.body}',
      );

      // Force refresh ALL feeds to ensure rules are applied
      final refreshResponse = await _client.post(
        Uri.parse('$_baseUrl/api/v2/rss/refreshItem'),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'itemPath': ''}, // Empty path refreshes all feeds
      );

      print(
        'Refresh response: ${refreshResponse.statusCode} - ${refreshResponse.body}',
      );

      return true;
    } catch (e) {
      print('Failed to add rule: $e');
      return false;
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

  Future<bool> refreshAllFeeds() async {
    try {
      if (_sessionCookie == null) {
        if (!await login()) return false;
      }

      // Refresh all feeds
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/v2/rss/refreshItem'),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'itemPath': ''}, // Empty path refreshes all feeds
      );

      print(
        'Refresh all feeds response: ${response.statusCode} - ${response.body}',
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error refreshing feeds: $e');
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

  Future<bool> refreshItem(String feedPath) async {
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
          return refreshItem(feedPath); // Retry with new session
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
      // Ensure we have a valid session
      if (_sessionCookie == null) {
        if (!await login()) return {};
      }

      final url = '$_baseUrl/api/v2/rss/items';
      final response = await _client.get(Uri.parse(url), headers: _headers);

      // If unauthorized, try to login again
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (await login()) {
          return getRssFeeds(); // Retry after login
        }
        return {};
      }

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
