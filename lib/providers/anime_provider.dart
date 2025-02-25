import 'package:flutter/foundation.dart';
import '../models/anime.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

enum LoadingStatus { initial, loading, loaded, error }

class AnimeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Anime> _seasonalAnime = [];
  LoadingStatus _status = LoadingStatus.initial;
  String _errorMessage = '';
  
  // Current season and year
  String _currentSeason = Constants.getCurrentSeason();
  int _currentYear = DateTime.now().year;
  
  List<Anime> get seasonalAnime => _seasonalAnime;
  LoadingStatus get status => _status;
  String get errorMessage => _errorMessage;
  String get currentSeason => _currentSeason;
  int get currentYear => _currentYear;
  
  // Set season and year
  void setSeason(String season) {
    _currentSeason = season;
    notifyListeners();
    fetchSeasonalAnime();
  }
  
  void setYear(int year) {
    _currentYear = year;
    notifyListeners();
    fetchSeasonalAnime();
  }
  
  Future<void> fetchSeasonalAnime() async {
    try {
      _status = LoadingStatus.loading;
      notifyListeners();
      
      final animeList = await _apiService.getSeasonalAnime(
        season: _currentSeason,
        year: _currentYear,
      );
      _seasonalAnime = animeList;
      _status = LoadingStatus.loaded;
    } catch (e) {
      _status = LoadingStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }
} 