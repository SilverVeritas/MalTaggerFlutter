import 'package:flutter/foundation.dart';
import '../models/anime.dart';
import '../services/season_utils.dart';
import '../services/qbittorrent_api.dart';
import '../services/file_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../services/jikan_service.dart';

class AppState extends ChangeNotifier {
  final JikanService _jikanService = JikanService();

  // Current season and year
  String _season = '';
  int _year = 0;

  // Anime list
  List<Anime> _animeList = [];
  List<Anime> _filteredList = [];

  // Search text
  String _searchText = '';

  // Edited values
  final Map<String, String> _editedValues = {};
  final Map<String, String> _fansubberValues = {};
  final Map<String, bool> _manualRssEdit = {};

  // RSS validation results
  final Map<String, bool> _rssValidationResults = {};
  final Map<String, int> _rssEpisodeCounts = {};

  // qBittorrent connection state
  bool _qbConnected = false;

  // qBittorrent client
  QBittorrentAPI? _qbClient;

  // Settings
  bool _isDarkMode = false;
  String _preferredFansubber = kDefaultFansubber;
  bool _showAdult = false;

  // Getters
  String get season => _season;
  int get year => _year;
  List<Anime> get animeList => _animeList;
  bool get qbConnected => _qbConnected;
  QBittorrentAPI? get qbClient => _qbClient;
  List<Anime> get filteredList => _filteredList;
  bool get isDarkMode => _isDarkMode;
  String get preferredFansubber => _preferredFansubber;
  bool get showAdult => _showAdult;

  AppState() {
    // Initialize with current season
    final seasonData = SeasonUtils.getCurrentSeason();
    _season = seasonData.season;
    _year = seasonData.year;
    _loadSettings();
    _loadAnimeList();
  }

  // Methods to update state
  void setSeason(String season) {
    _season = season;
    notifyListeners();
  }

  void setYear(int year) {
    _year = year;
    notifyListeners();
  }

  void setAnimeList(List<Anime> animeList) {
    _animeList = animeList;
    notifyListeners();
  }

  void resetToCurrentSeason() {
    final seasonData = SeasonUtils.getCurrentSeason();
    _season = seasonData.season;
    _year = seasonData.year;
    notifyListeners();
  }

  // Methods for editing anime entries
  String getEditedTitle(String originalTitle, int index) {
    final key = _getStateKey(originalTitle, 'title', index);
    return _editedValues[key] ?? originalTitle;
  }

  String getEditedRssUrl(String originalTitle, int index, String defaultUrl) {
    final key = _getStateKey(originalTitle, 'rss', index);
    return _editedValues[key] ?? defaultUrl;
  }

  String getFansubber(
    String originalTitle,
    int index,
    String defaultFansubber,
  ) {
    final key = _getStateKey(originalTitle, 'fansubber', index);
    return _fansubberValues[key] ?? defaultFansubber;
  }

  void setEditedTitle(String originalTitle, int index, String newTitle) {
    final key = _getStateKey(originalTitle, 'title', index);
    _editedValues[key] = newTitle;
    notifyListeners();
  }

  void setEditedRssUrl(String originalTitle, int index, String newUrl) {
    final key = _getStateKey(originalTitle, 'rss', index);
    _editedValues[key] = newUrl;
    _manualRssEdit[originalTitle] = true;
    notifyListeners();
  }

  void setFansubber(String originalTitle, int index, String newFansubber) {
    final key = _getStateKey(originalTitle, 'fansubber', index);
    _fansubberValues[key] = newFansubber;
    notifyListeners();
  }

  bool isManualRssEdit(String originalTitle) {
    return _manualRssEdit[originalTitle] ?? false;
  }

  // Helper method to generate state keys
  String _getStateKey(String animeTitle, String fieldType, int index) {
    return '${index}_${animeTitle}_$fieldType';
  }

  // qBittorrent connection methods
  void setQbConnected(bool connected) {
    _qbConnected = connected;
    notifyListeners();
  }

  void setQbClient(QBittorrentAPI? client) {
    _qbClient = client;
    notifyListeners();
  }

  // RSS validation methods
  void setRssValidationResult(String url, bool isValid, int? episodeCount) {
    _rssValidationResults[url] = isValid;
    if (episodeCount != null) {
      _rssEpisodeCounts[url] = episodeCount;
    }
    notifyListeners();
  }

  bool? getRssValidationResult(String url) {
    return _rssValidationResults[url];
  }

  int? getRssEpisodeCount(String url) {
    return _rssEpisodeCounts[url];
  }

  // Delete anime entry
  void deleteAnimeEntry(String originalTitle, int index) {
    // Remove from edited values
    final titleKey = _getStateKey(originalTitle, 'title', index);
    final rssKey = _getStateKey(originalTitle, 'rss', index);
    final fansubberKey = _getStateKey(originalTitle, 'fansubber', index);

    _editedValues.remove(titleKey);
    _editedValues.remove(rssKey);
    _fansubberValues.remove(fansubberKey);
    _manualRssEdit.remove(originalTitle);

    // Remove from anime list
    _animeList.removeWhere((anime) => anime.title == originalTitle);

    notifyListeners();
  }

  void updateAnimeTitle(String originalTitle, String newTitle, int index) {
    setEditedTitle(originalTitle, index, newTitle);
  }

  void updateAnimeFansubber(
    String originalTitle,
    String newFansubber,
    int index,
  ) {
    setFansubber(originalTitle, index, newFansubber);
  }

  void updateAnimeRssUrl(String originalTitle, String newUrl, int index) {
    setEditedRssUrl(originalTitle, index, newUrl);
  }

  bool isRssManuallyEdited(String originalTitle) {
    return _manualRssEdit[originalTitle] ?? false;
  }

  // Setters
  set isDarkMode(bool value) {
    _isDarkMode = value;
    _saveSettings();
    notifyListeners();
  }

  set preferredFansubber(String value) {
    _preferredFansubber = value;
    _saveSettings();
    notifyListeners();
  }

  set showAdult(bool value) {
    _showAdult = value;
    _saveSettings();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    _preferredFansubber =
        prefs.getString('preferred_fansubber') ?? kDefaultFansubber;
    _showAdult = prefs.getBool('show_adult') ?? false;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    await prefs.setString('preferred_fansubber', _preferredFansubber);
    await prefs.setBool('show_adult', _showAdult);
  }

  // Load anime list from storage
  Future<void> _loadAnimeList() async {
    try {
      _animeList = await FileUtils.readAnimeList();
      _filterAnimeList();
    } catch (e) {
      print('Error loading anime list: $e');
    }
  }

  // Filter anime list based on search text
  void _filterAnimeList() {
    if (_searchText.isEmpty) {
      _filteredList = List.from(_animeList);
    } else {
      _filteredList =
          _animeList
              .where(
                (anime) =>
                    anime.title.toLowerCase().contains(
                      _searchText.toLowerCase(),
                    ) ||
                    (anime.alternativeTitles != null &&
                        anime.alternativeTitles!.any(
                          (title) => title.toLowerCase().contains(
                            _searchText.toLowerCase(),
                          ),
                        )),
              )
              .toList();
    }

    // Hide adult content if setting is off
    if (!_showAdult) {
      _filteredList =
          _filteredList.where((anime) => anime.isAdult != true).toList();
    }

    notifyListeners();
  }

  // Set search text and filter anime list
  void setSearchText(String searchText) {
    _searchText = searchText;
    _filterAnimeList();
  }

  // Add an anime to the list
  Future<void> addAnime(Anime anime) async {
    if (!_animeList.any((element) => element.malId == anime.malId)) {
      // Create a copy with the preferred fansubber if needed
      final animeToAdd =
          anime.fansubber.isEmpty
              ? anime.copyWith(fansubber: _preferredFansubber)
              : anime;

      _animeList.add(animeToAdd);
      _filterAnimeList();

      await FileUtils.saveAnimeList(_animeList);
      notifyListeners();
    }
  }

  // Update an anime in the list
  Future<void> updateAnime(Anime updatedAnime) async {
    final index = _animeList.indexWhere(
      (element) => element.malId == updatedAnime.malId,
    );

    if (index != -1) {
      _animeList[index] = updatedAnime;
      _filterAnimeList();

      await FileUtils.saveAnimeList(_animeList);
      notifyListeners();
    }
  }

  // Remove an anime from the list
  Future<void> removeAnime(Anime anime) async {
    _animeList.removeWhere((element) => element.malId == anime.malId);
    _filterAnimeList();

    await FileUtils.saveAnimeList(_animeList);
    notifyListeners();
  }

  // Search for anime using the Jikan API
  Future<List<Anime>> searchAnime(String query) async {
    try {
      final results = await _jikanService.searchAnime(query);

      // Filter adult content based on settings
      if (!_showAdult) {
        return results.where((anime) => anime.isAdult != true).toList();
      }

      return results;
    } finally {
      notifyListeners();
    }
  }

  // Get anime details from the Jikan API
  Future<Anime?> getAnimeDetails(int malId) async {
    try {
      return await _jikanService.getAnimeDetails(malId);
    } finally {
      notifyListeners();
    }
  }

  // Test qBittorrent connection
  Future<Map<String, dynamic>> testQBittorrentConnection({
    required String host,
    required String username,
    required String password,
  }) async {
    final qbClient = QBittorrentAPI(
      host: host,
      username: username,
      password: password,
    );

    try {
      return await qbClient.testConnection();
    } finally {
      qbClient.dispose();
    }
  }

  Future<void> refreshAnimeList() async {
    isLoading = true;
    notifyListeners();

    try {
      // Reload anime list from storage or API
      final animeList = await FileUtils.readAnimeList();

      // Update your internal list
      _animeList = animeList;
      _filterAnimeList();
    } catch (e) {
      print('Error refreshing anime list: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  bool isLoading = false;
}
