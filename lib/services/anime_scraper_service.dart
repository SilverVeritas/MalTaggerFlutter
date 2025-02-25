import '../models/scraped_anime.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/rss_utils.dart';
import '../constants.dart';

class AnimeScraperService {
  // Use the constant from constants.dart
  final String jikanBaseUrl = kJikanApiBaseUrl;
  
  // Add a delay between requests to avoid rate limiting
  Future<void> _delay() async {
    await Future.delayed(const Duration(milliseconds: 1000));
  }
  
  // This function is now unused and can be removed
  Future<List<ScrapedAnime>> scrapeAnimeFromUrl(String url) async {
    return [];
  }
  
  // Updated to support filtering and progress tracking
  Future<List<ScrapedAnime>> scrapeFromMALSeasonalPage(
    String season, 
    int year, {
    int minMembers = 5000,
    bool excludeChinese = true,
    Function(int, int)? progressCallback,
  }) async {
    final List<ScrapedAnime> filteredAnime = [];
    int currentPage = 1;
    int totalPages = 1;
    
    try {
      while (true) {
        await _delay();
        final response = await http.get(
          Uri.parse('$jikanBaseUrl/seasons/$year/$season?page=$currentPage'),
        );
        
        if (response.statusCode != 200) {
          throw Exception('Failed to load seasonal anime: ${response.statusCode}');
        }
        
        final data = json.decode(response.body);
        final pagination = data['pagination'] ?? {};
        totalPages = pagination['last_visible_page'] ?? 1;
        
        // Update progress
        if (progressCallback != null) {
          progressCallback(currentPage, totalPages);
        }
        
        final animeList = data['data'] as List;
        
        for (final anime in animeList) {
          // Apply filters
          if (_filterAnime(anime, minMembers, excludeChinese)) {
            final scrapedAnime = ScrapedAnime(
              title: anime['title'] ?? '',
              imageUrl: anime['images']?['jpg']?['large_image_url'] ?? 
                        anime['images']?['jpg']?['image_url'] ?? '',
              episodes: anime['episodes']?.toString(),
              malId: anime['mal_id'],
              synopsis: anime['synopsis'],
              members: anime['members'],
              releaseDate: anime['aired']?['string'],
              score: anime['score']?.toDouble(),
              type: anime['type'],
              studio: anime['studios'] != null && (anime['studios'] as List).isNotEmpty 
                  ? anime['studios'][0]['name'] 
                  : null,
              genres: anime['genres'] != null 
                  ? (anime['genres'] as List).map<String>((g) => g['name'] as String).toList() 
                  : null,
            );
            
            // Generate initial RSS URL
            scrapedAnime.rssUrl = generateRssUrl(scrapedAnime.title, scrapedAnime.fansubber);
            
            filteredAnime.add(scrapedAnime);
          }
        }
        
        // Check if there are more pages
        if (!(pagination['has_next_page'] ?? false)) {
          break;
        }
        
        currentPage++;
      }
      
      // Remove duplicates
      return _removeDuplicates(filteredAnime);
    } catch (e) {
      print('Error scraping seasonal anime: $e');
      throw Exception('Failed to load seasonal anime: $e');
    }
  }
  
  // Add filtering method
  bool _filterAnime(Map<String, dynamic> anime, int minMembers, bool excludeChinese) {
    // Check member count
    if ((anime['members'] ?? 0) < minMembers) {
      return false;
    }
    
    // Check if Chinese animation and we want to exclude it
    if (excludeChinese && _isChineseAnimation(anime)) {
      return false;
    }
    
    return true;
  }
  
  // Add method to detect Chinese animation
  bool _isChineseAnimation(Map<String, dynamic> anime) {
    final animeType = (anime['type'] ?? '').toUpperCase();
    
    // Direct type matches
    if (animeType == 'ONA-CN' || animeType == 'DONGHUA') {
      return true;
    }
    
    // Check ONA types for Chinese producers
    if (animeType == 'ONA') {
      final producers = anime['producers'] as List? ?? [];
      final producerNames = producers
          .map((p) => (p['name'] ?? '').toLowerCase())
          .toList();
      
      final chineseKeywords = ['bilibili', 'tencent', 'iqiyi', 'youku'];
      
      for (var name in producerNames) {
        for (var keyword in chineseKeywords) {
          if (name.contains(keyword)) {
            return true;
          }
        }
      }
    }
    
    return false;
  }
  
  // Add method to remove duplicates
  List<ScrapedAnime> _removeDuplicates(List<ScrapedAnime> animeList) {
    final seenIds = <int>{};
    final seenTitles = <String>{};
    final uniqueList = <ScrapedAnime>[];
    
    for (var anime in animeList) {
      if ((anime.malId != null && seenIds.contains(anime.malId)) || 
          seenTitles.contains(anime.title)) {
        continue;
      }
      
      uniqueList.add(anime);
      if (anime.malId != null) {
        seenIds.add(anime.malId!);
      }
      seenTitles.add(anime.title);
    }
    
    return uniqueList;
  }
  
  // Generate RSS URL for an anime
  String generateRssUrl(String title, String fansubber) {
    return RssUtils.formatRssUrl(title, fansubber);
  }
  
  // Validate RSS feed
  Future<(bool, int?)> validateRssFeed(String url) async {
    return await RssUtils.validateRssFeed(url);
  }
} 