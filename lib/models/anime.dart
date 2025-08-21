class Anime {
  final String title;
  final String date;
  final String synopsis;
  final List<String> genres;
  final double score;
  final int members;
  final String episodes;
  final String status;
  final String imageUrl;
  final String type;
  final String source;
  final int? malId;
  final String rssUrl;
  final String fansubber;
  final List<String>? alternativeTitles;
  final bool? isAdult;

  Anime({
    required this.title,
    required this.date,
    required this.synopsis,
    required this.genres,
    required this.score,
    required this.members,
    required this.episodes,
    required this.status,
    required this.imageUrl,
    required this.type,
    required this.source,
    this.malId,
    required this.rssUrl,
    required this.fansubber,
    this.alternativeTitles,
    this.isAdult,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      title: json['title'] ?? '',
      date: json['date'] ?? 'TBA',
      synopsis: json['synopsis'] ?? 'No synopsis available.',
      genres: List<String>.from(json['genres'] ?? []),
      score: (json['score'] ?? 0).toDouble(),
      members: json['members'] ?? 0,
      episodes: json['episodes']?.toString() ?? '?',
      status: json['status'] ?? 'Unknown',
      imageUrl: json['image_url'] ?? '',
      type: json['type'] ?? 'Unknown',
      source: json['source'] ?? 'Unknown',
      malId: json['mal_id'],
      rssUrl: json['rssUrl'] ?? '',
      fansubber: json['fansubber'] ?? 'ember',
      alternativeTitles:
          json['alternative_titles'] != null
              ? List<String>.from(json['alternative_titles'].values)
              : null,
      isAdult: json['rating']?.toString().contains('Rx') ?? false,
    );
  }

  factory Anime.fromJikan(Map<String, dynamic> json) {
    final titles = <String>[];
    if (json['title_english'] != null) titles.add(json['title_english']);
    if (json['title_japanese'] != null) titles.add(json['title_japanese']);
    
    // Extract genres
    final genresList = <String>[];
    if (json['genres'] != null) {
      for (var genre in json['genres']) {
        genresList.add(genre['name'] ?? '');
      }
    }
    
    // Extract aired date
    String airedDate = 'TBA';
    if (json['aired'] != null && json['aired']['string'] != null) {
      airedDate = json['aired']['string'];
    }

    return Anime(
      malId: json['mal_id'],
      title: json['title'] ?? '',
      alternativeTitles: titles,
      imageUrl: json['images']?['jpg']?['large_image_url'] ?? json['images']?['jpg']?['image_url'] ?? '',
      synopsis: json['synopsis'] ?? 'No synopsis available',
      isAdult: json['rating']?.toString().contains('Rx') ?? false,
      fansubber: '',
      rssUrl: '',
      genres: genresList,
      date: airedDate,
      episodes: json['episodes']?.toString() ?? '?',
      status: json['status'] ?? 'Unknown',
      type: json['type'] ?? 'Unknown',
      source: json['source'] ?? 'Unknown',
      score: (json['score'] ?? 0.0).toDouble(),
      members: json['members'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'date': date,
      'synopsis': synopsis,
      'genres': genres,
      'score': score,
      'members': members,
      'episodes': episodes,
      'status': status,
      'image_url': imageUrl,
      'type': type,
      'source': source,
      'mal_id': malId,
      'rssUrl': rssUrl,
      'fansubber': fansubber,
      'alternative_titles': alternativeTitles?.asMap().map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'isAdult': isAdult,
    };
  }

  Anime copyWith({
    String? title,
    String? date,
    String? synopsis,
    List<String>? genres,
    double? score,
    int? members,
    String? episodes,
    String? status,
    String? imageUrl,
    String? type,
    String? source,
    int? malId,
    String? rssUrl,
    String? fansubber,
    List<String>? alternativeTitles,
    bool? isAdult,
  }) {
    return Anime(
      title: title ?? this.title,
      date: date ?? this.date,
      synopsis: synopsis ?? this.synopsis,
      genres: genres ?? this.genres,
      score: score ?? this.score,
      members: members ?? this.members,
      episodes: episodes ?? this.episodes,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      source: source ?? this.source,
      malId: malId ?? this.malId,
      rssUrl: rssUrl ?? this.rssUrl,
      fansubber: fansubber ?? this.fansubber,
      alternativeTitles: alternativeTitles ?? this.alternativeTitles,
      isAdult: isAdult ?? this.isAdult,
    );
  }
}
