import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
import '../constants.dart';

class JikanService {
  final String baseUrl = kJikanApiBaseUrl;
  
  Future<List<Anime>> searchAnime(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/anime?q=$query&sfw=false'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['data'] as List;
      return results.map((item) => Anime.fromJikan(item)).toList();
    } else {
      throw Exception('Failed to search anime');
    }
  }
  
  Future<Anime?> getAnimeDetails(int malId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/anime/$malId'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Anime.fromJikan(data['data']);
    } else {
      throw Exception('Failed to get anime details');
    }
  }
} 