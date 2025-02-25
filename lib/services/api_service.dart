import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
import '../utils/constants.dart';

class ApiService {
  Future<List<Anime>> getSeasonalAnime({
    required String season,
    required int year,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/seasons/$year/$season'),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> animeList = data['data'];
        
        return animeList.map((anime) => Anime.fromJson(anime)).toList();
      } else {
        throw Exception('Failed to load seasonal anime: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching seasonal anime: $e');
    }
  }
} 