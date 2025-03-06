import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/scraped_anime.dart';
import '../services/anime_scraper_service.dart';
import '../services/app_state.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

/// Controller for anime scraping functionality
/// Handles business logic and data processing
class AnimeScraperController {
  final AnimeScraperService scraperService = AnimeScraperService();

  // Load saved lists from SharedPreferences
  Future<Map<String, List<ScrapedAnime>>> loadSavedLists() async {
    final prefs = await SharedPreferences.getInstance();
    final savedListsJson = prefs.getString('scraped_anime_lists');

    if (savedListsJson == null) {
      return {};
    }

    try {
      final Map<String, dynamic> savedListsMap = jsonDecode(savedListsJson);

      return Map.fromEntries(
        savedListsMap.entries.map((entry) {
          return MapEntry(
            entry.key,
            (entry.value as List)
                .map((item) => ScrapedAnime.fromJson(item))
                .toList(),
          );
        }),
      );
    } catch (e) {
      throw Exception('Failed to load saved lists: $e');
    }
  }

  // Generate default list name based on season and year
  String generateDefaultListName(
    String season,
    int year,
    String preferredFansubber,
  ) {
    final now = DateTime.now();
    final capitalizedSeason =
        season.isNotEmpty
            ? season[0].toUpperCase() + season.substring(1)
            : 'Unknown';

    return '${capitalizedSeason}_${year}_${preferredFansubber}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}';
  }

  // Show dialog to prompt for list name
  Future<String?> promptForListName(
    BuildContext context,
    String season,
    int year,
  ) async {
    final TextEditingController controller = TextEditingController();
    final appState =
        AppState(); // This is simplified, in real app you'd use Provider

    // Set default list name
    controller.text = generateDefaultListName(
      season,
      year,
      appState.preferredFansubber,
    );

    try {
      return await showDialog<String>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Save List'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'List Name',
                      hintText: 'Enter a name for this list',
                    ),
                    autofocus: true,
                    onChanged: (value) {
                      // Validate input to only allow alphanumeric, underscore, and dash
                      if (!RegExp(r'^[a-zA-Z0-9_-]*$').hasMatch(value)) {
                        controller.text = value.replaceAll(
                          RegExp(r'[^a-zA-Z0-9_-]'),
                          '',
                        );
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
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
                  onPressed: () {
                    final listName = controller.text.trim();
                    if (listName.isEmpty) {
                      return;
                    }
                    Navigator.pop(context, listName);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
      );
    } finally {
      controller.dispose();
    }
  }

  // Save a list of anime to SharedPreferences
  Future<void> saveAnimeList(
    String listName,
    List<ScrapedAnime> animeList,
  ) async {
    if (listName.isEmpty || animeList.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Get existing saved lists
    final savedListsJson = prefs.getString('scraped_anime_lists');
    Map<String, dynamic> savedListsMap = {};

    if (savedListsJson != null) {
      savedListsMap = jsonDecode(savedListsJson);
    }

    // Add or update the list
    savedListsMap[listName] = animeList.map((anime) => anime.toJson()).toList();

    // Save back to SharedPreferences
    await prefs.setString('scraped_anime_lists', jsonEncode(savedListsMap));
  }

  // Delete an anime list
  Future<void> deleteAnimeList(String listName) async {
    final prefs = await SharedPreferences.getInstance();

    // Get existing saved lists
    final savedListsJson = prefs.getString('scraped_anime_lists');
    if (savedListsJson == null) return;

    Map<String, dynamic> savedListsMap = jsonDecode(savedListsJson);

    // Remove the list
    savedListsMap.remove(listName);

    // Save back to SharedPreferences
    await prefs.setString('scraped_anime_lists', jsonEncode(savedListsMap));
  }

  // Create a deep copy of a list of ScrapedAnime
  List<ScrapedAnime> createDeepCopy(List<ScrapedAnime> sourceList) {
    return sourceList
        .map((anime) => ScrapedAnime.fromJson(anime.toJson()))
        .toList();
  }

  // Show confirmation dialog
  Future<bool> confirmAction(
    BuildContext context,
    String title,
    String message,
    String confirmText,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(confirmText),
                  ),
                ],
              ),
        ) ??
        false;
  }

  // Save the current state of all lists
  Future<void> saveUpdatedLists(Map<String, List<ScrapedAnime>> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final savedListsMap = Map.fromEntries(
      lists.entries.map((entry) {
        return MapEntry(
          entry.key,
          entry.value.map((anime) => anime.toJson()).toList(),
        );
      }),
    );
    await prefs.setString('scraped_anime_lists', jsonEncode(savedListsMap));
  }

  // Fetch anime for a specific season and year
  Future<List<ScrapedAnime>> fetchAnimeForSeason(
    String season,
    int year, {
    required int minMembers,
    required bool excludeChinese,
    required String preferredFansubber,
    Function(int, int)? progressCallback,
  }) async {
    try {
      // This calls the scraper service's method to fetch anime
      final scrapedAnime = await scraperService.scrapeFromMALSeasonalPage(
        season,
        year,
        minMembers: minMembers,
        excludeChinese: excludeChinese,
        preferredFansubber: preferredFansubber,
        progressCallback: progressCallback,
      );

      return scrapedAnime;
    } catch (e) {
      throw Exception('Failed to fetch anime: $e');
    }
  }

  // Validate all RSS feeds for a list of anime
  Future<Map<String, int>> validateAllRssFeeds(
    List<ScrapedAnime> animeList,
    AppState appState, {
    required Function(int, int) onProgress,
    required bool Function() shouldCancel,
  }) async {
    final results = <String, bool>{};
    final episodeCounts = <String, int>{};

    int validated = 0;
    final total = animeList.length;

    for (final anime in animeList) {
      // Check if operation should be cancelled
      if (shouldCancel()) {
        return {
          'valid': results.values.where((v) => v).length,
          'total': results.length,
        };
      }

      final index = animeList.indexOf(anime);
      final originalTitle = anime.title;
      final rssUrl = appState.getEditedRssUrl(
        originalTitle,
        index,
        anime.rssUrl,
      );

      // Update progress
      onProgress(validated + 1, total);

      final (isValid, episodeCount) = await scraperService.validateRssFeed(
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

    return {
      'valid': results.values.where((v) => v).length,
      'total': results.length,
    };
  }

  // Fetch anime details by MAL ID
  Future<ScrapedAnime> fetchAnimeById(
    int malId,
    String preferredFansubber,
  ) async {
    try {
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

      // Extract alternative titles
      final alternativeTitles = <String>[];

      // Check for English title first
      if (animeData['title_english'] != null &&
          animeData['title_english'] != animeData['title']) {
        alternativeTitles.add(animeData['title_english']);
      }

      // Check titles array for additional titles
      if (animeData['titles'] != null) {
        for (var titleObj in animeData['titles']) {
          String titleType = titleObj['type'] ?? '';
          String title = titleObj['title'] ?? '';

          // Skip if it's the same as main title or already in our list
          if (title.isNotEmpty &&
              title != animeData['title'] &&
              !alternativeTitles.contains(title)) {
            // Prioritize English titles and Synonyms
            if (titleType == 'English' && alternativeTitles.isEmpty) {
              // Add English title at the beginning if not already added
              alternativeTitles.insert(0, title);
            } else if (titleType == 'Synonym') {
              alternativeTitles.add(title);
            }
          }
        }
      }

      // Add Japanese title last if available and not already added
      if (animeData['title_japanese'] != null &&
          !alternativeTitles.contains(animeData['title_japanese'])) {
        alternativeTitles.add(animeData['title_japanese']);
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
        fansubber: preferredFansubber,
        alternativeTitles:
            alternativeTitles.isNotEmpty ? alternativeTitles : null,
      );

      // Generate RSS URL
      anime.rssUrl = scraperService.generateRssUrl(
        anime.title,
        anime.fansubber,
      );

      return anime;
    } catch (e) {
      throw Exception('Error fetching anime data: $e');
    }
  }

  // Sort anime list based on criteria
  void sortAnimeList(List<ScrapedAnime> animeList, String sortBy) {
    switch (sortBy) {
      case 'alpha':
        animeList.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'alpha_reverse':
        animeList.sort((a, b) => b.title.compareTo(a.title));
        break;
      case 'members_high':
        animeList.sort((a, b) => (b.members ?? 0).compareTo(a.members ?? 0));
        break;
      case 'members_low':
        animeList.sort((a, b) => (a.members ?? 0).compareTo(b.members ?? 0));
        break;
      case 'date_newest':
        animeList.sort((a, b) {
          if (a.releaseDate == null) return 1;
          if (b.releaseDate == null) return -1;
          return b.releaseDate!.compareTo(a.releaseDate!);
        });
        break;
      case 'date_oldest':
        animeList.sort((a, b) {
          if (a.releaseDate == null) return 1;
          if (b.releaseDate == null) return -1;
          return a.releaseDate!.compareTo(b.releaseDate!);
        });
        break;
    }
  }

  // Convert anime list to JSON string
  String animeListToJson(List<ScrapedAnime> animeList) {
    return JsonEncoder.withIndent(
      '  ',
    ).convert(animeList.map((anime) => anime.toJson()).toList());
  }

  // Convert JSON string to anime list
  List<ScrapedAnime> jsonToAnimeList(String json) {
    final jsonData = jsonDecode(json) as List;
    return jsonData.map((item) => ScrapedAnime.fromJson(item)).toList();
  }
}
