import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
import './rss_utils.dart';

class JikanApiService {
  final int minMembers;
  
  JikanApiService({this.minMembers = 5000});
  
  Future<List<Anime>> fetchSeasonalAnime(
    String season, 
    int year, 
    Function(int, int)? progressCallback
  ) async {
    List<Anime> filteredAnime = [];
    int currentPage = 1;
    int totalPages = 1;
    
    while (true) {
      final url = 'https://api.jikan.moe/v4/seasons/$year/$season?page=$currentPage';
      
      try {
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode != 200) {
          break;
        }
        
        final data = jsonDecode(response.body);
        
        if (!data.containsKey('data')) {
          break;
        }
        
        // Update total pages
        final pagination = data['pagination'] ?? {};
        totalPages = pagination['last_visible_page'] ?? 1;
        
        // Call progress callback
        if (progressCallback != null) {
          progressCallback(currentPage, totalPages);
        }
        
        // Process anime entries
        final animeList = data['data'] as List;
        
        for (var animeData in animeList) {
          if (_filterAnime(animeData)) {
            final anime = _parseAnimeData(animeData);
            filteredAnime.add(anime);
          }
        }
        
        // Check for more pages
        if (!(pagination['has_next_page'] ?? false)) {
          break;
        }
        
        currentPage++;
        await Future.delayed(const Duration(seconds: 1)); // Respect API rate limit
        
      } catch (e) {
        print('Error fetching anime data: $e');
        break;
      }
    }
    
    // Remove duplicates
    return _removeDuplicates(filteredAnime);
  }
  
  bool _filterAnime(Map<String, dynamic> anime) {
    // Check member count
    if ((anime['members'] ?? 0) < minMembers) {
      return false;
    }
    
    // Check if Chinese animation
    if (_isChineseAnimation(anime)) {
      return false;
    }
    
    return true;
  }
  
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
  
  Anime _parseAnimeData(Map<String, dynamic> anime) {
    // Extract genres
    final genresList = <String>[];
    if (anime['genres'] != null) {
      for (var genre in anime['genres']) {
        genresList.add(genre['name']);
      }
    }
    
    // Generate initial RSS URL
    final initialRss = RssUtils.formatRssUrl(anime['title'] ?? '');
    
    return Anime(
      title: anime['title'] ?? '',
      date: anime['aired']?['string'] ?? 'Unknown',
      synopsis: anime['synopsis'] ?? 'No synopsis available',
      genres: genresList,
      score: anime['score']?.toDouble() ?? 0.0,
      members: anime['members'] ?? 0,
      episodes: anime['episodes']?.toString() ?? '?',
      status: anime['status'] ?? 'Unknown',
      // Use large image URL instead of standard one
      imageUrl: anime['images']?['jpg']?['large_image_url'] ?? '',
      type: anime['type'] ?? 'Unknown',
      source: anime['source'] ?? 'Unknown',
      malId: anime['mal_id'],
      rssUrl: initialRss,
      fansubber: 'ember',
    );
  }
  
  List<Anime> _removeDuplicates(List<Anime> animeList) {
    final seenIds = <int>{};
    final seenTitles = <String>{};
    final uniqueList = <Anime>[];
    
    for (var anime in animeList) {
      if ((anime.malId != null && seenIds.contains(anime.malId)) || 
          seenTitles.contains(anime.title)) {
        continue;
      }
      
      uniqueList.add(anime);
      if (anime.malId != null) {
        seenIds.add(anime.malId!);
      }
      if (anime.title.isNotEmpty) {
        seenTitles.add(anime.title);
      }
    }
    
    return uniqueList;
  }
} 