class ScrapedAnime {
  String title;
  final String imageUrl;
  final String? episodes;
  final int? malId;
  String rssUrl;
  String fansubber;
  String? synopsis;
  int? members;
  String? releaseDate;
  double? score;
  String? type;
  String? studio;
  List<String>? genres;
  List<String>? alternativeTitles; // Add this field

  ScrapedAnime({
    required this.title,
    required this.imageUrl,
    this.episodes,
    this.malId,
    this.rssUrl = '',
    this.fansubber = '',
    this.synopsis,
    this.members,
    this.releaseDate,
    this.score,
    this.type,
    this.studio,
    this.genres,
    this.alternativeTitles,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'episodes': episodes,
      'malId': malId,
      'rssUrl': rssUrl,
      'fansubber': fansubber,
      'synopsis': synopsis,
      'members': members,
      'releaseDate': releaseDate,
      'score': score,
      'type': type,
      'studio': studio,
      'genres': genres,
      'alternativeTitles': alternativeTitles, // Add this to JSON
    };
  }

  factory ScrapedAnime.fromJson(Map<String, dynamic> json) {
    return ScrapedAnime(
      title: json['title'],
      imageUrl: json['imageUrl'],
      episodes: json['episodes'],
      malId: json['malId'],
      rssUrl: json['rssUrl'] ?? '',
      fansubber: json['fansubber'] ?? '',
      synopsis: json['synopsis'],
      members: json['members'],
      releaseDate: json['releaseDate'],
      score: json['score'],
      type: json['type'],
      studio: json['studio'],
      genres: json['genres'] != null ? List<String>.from(json['genres']) : null,
      alternativeTitles:
          json['alternativeTitles'] != null
              ? List<String>.from(json['alternativeTitles'])
              : null, // Parse from JSON
    );
  }
}
