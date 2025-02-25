class SeasonData {
  final String season;
  final int year;
  
  SeasonData({required this.season, required this.year});
}

class SeasonUtils {
  static SeasonData getCurrentSeason() {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;
    
    String season;
    if (month >= 1 && month <= 3) {
      season = 'winter';
    } else if (month >= 4 && month <= 6) {
      season = 'spring';
    } else if (month >= 7 && month <= 9) {
      season = 'summer';
    } else {
      season = 'fall';
    }
    
    return SeasonData(season: season, year: year);
  }
} 