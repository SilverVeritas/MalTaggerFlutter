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
  
  ScrapedAnime({
    required this.title,
    required this.imageUrl,
    this.episodes,
    this.malId,
    this.rssUrl = '',
    this.fansubber = 'ember',
    this.synopsis,
    this.members,
    this.releaseDate,
    this.score,
    this.type,
    this.studio,
    this.genres,
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
    };
  }
  
  factory ScrapedAnime.fromJson(Map<String, dynamic> json) {
    return ScrapedAnime(
      title: json['title'],
      imageUrl: json['imageUrl'],
      episodes: json['episodes'],
      malId: json['malId'],
      rssUrl: json['rssUrl'] ?? '',
      fansubber: json['fansubber'] ?? 'ember',
      synopsis: json['synopsis'],
      members: json['members'],
      releaseDate: json['releaseDate'],
      score: json['score'],
      type: json['type'],
      studio: json['studio'],
      genres: json['genres'] != null ? List<String>.from(json['genres']) : null,
    );
  }
} 