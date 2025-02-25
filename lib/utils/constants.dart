class Constants {
  static const String baseUrl = 'https://api.jikan.moe/v4';
  static const String appName = 'MAL Anime App';
  
  // API rate limiting - Jikan API has rate limits
  static const int apiRequestDelay = 1000; // milliseconds
  
  // Seasons
  static const List<String> seasons = ['winter', 'spring', 'summer', 'fall'];
  
  // Years (current year and 10 years back)
  static List<int> getYears() {
    final currentYear = DateTime.now().year;
    return List.generate(11, (index) => currentYear - index);
  }
  
  // Get current season
  static String getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 1 && month <= 3) return 'winter';
    if (month >= 4 && month <= 6) return 'spring';
    if (month >= 7 && month <= 9) return 'summer';
    return 'fall';
  }
} 