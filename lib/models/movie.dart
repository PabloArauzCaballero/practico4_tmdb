import 'dart:typed_data';

/// Tipo de contenido en TMDB.
enum MediaType {
  movie('movie', 'Películas'),
  tv('tv', 'Series');

  const MediaType(this.apiPath, this.label);
  final String apiPath;
  final String label;

  static MediaType fromApiPath(String value) =>
      value == 'tv' ? MediaType.tv : MediaType.movie;
}

/// Resultado de una búsqueda: lo mínimo para mostrar la lista.
class MovieSummary {
  const MovieSummary({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.releaseDate,
    this.posterPath,
  });

  final int id;
  final MediaType mediaType;
  final String title;
  final String releaseDate;
  final String? posterPath;

  String get year => releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';

  factory MovieSummary.fromJson(Map<String, dynamic> json, MediaType type) {
    return MovieSummary(
      id: json['id'] as int,
      mediaType: type,
      title: (json['title'] ?? json['name'] ?? 'Sin título') as String,
      releaseDate:
          (json['release_date'] ?? json['first_air_date'] ?? '') as String,
      posterPath: json['poster_path'] as String?,
    );
  }
}

/// Detalle completo de una película o serie.
class MovieDetail {
  const MovieDetail({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.releaseDate,
    required this.runtimeMinutes,
    required this.genres,
    required this.director,
    required this.overview,
    required this.voteAverage,
    required this.voteCount,
    this.posterUrl,
    this.posterBytes,
    this.searchedAt,
  });

  final int id;
  final MediaType mediaType;
  final String title;
  final String releaseDate;
  final int? runtimeMinutes;
  final String genres;
  final String director;
  final String overview;
  final double voteAverage;
  final int voteCount;
  final String? posterUrl;

  /// Imagen guardada en la base local para verla sin conexión.
  final Uint8List? posterBytes;
  final DateTime? searchedAt;

  String get year =>
      releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '—';

  String get runtimeLabel {
    final minutes = runtimeMinutes;
    if (minutes == null || minutes <= 0) return 'Sin dato';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  MovieDetail copyWith({Uint8List? posterBytes, DateTime? searchedAt}) {
    return MovieDetail(
      id: id,
      mediaType: mediaType,
      title: title,
      releaseDate: releaseDate,
      runtimeMinutes: runtimeMinutes,
      genres: genres,
      director: director,
      overview: overview,
      voteAverage: voteAverage,
      voteCount: voteCount,
      posterUrl: posterUrl,
      posterBytes: posterBytes ?? this.posterBytes,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'media_type': mediaType.apiPath,
    'title': title,
    'release_date': releaseDate,
    'runtime': runtimeMinutes,
    'genres': genres,
    'director': director,
    'overview': overview,
    'vote_average': voteAverage,
    'vote_count': voteCount,
    'poster_url': posterUrl,
    'poster_bytes': posterBytes,
    'searched_at': (searchedAt ?? DateTime.now()).millisecondsSinceEpoch,
  };

  factory MovieDetail.fromMap(Map<String, Object?> map) {
    return MovieDetail(
      id: map['id'] as int,
      mediaType: MediaType.fromApiPath(map['media_type'] as String),
      title: map['title'] as String,
      releaseDate: map['release_date'] as String,
      runtimeMinutes: map['runtime'] as int?,
      genres: map['genres'] as String,
      director: map['director'] as String,
      overview: map['overview'] as String,
      voteAverage: (map['vote_average'] as num).toDouble(),
      voteCount: map['vote_count'] as int,
      posterUrl: map['poster_url'] as String?,
      posterBytes: map['poster_bytes'] as Uint8List?,
      searchedAt: DateTime.fromMillisecondsSinceEpoch(
        map['searched_at'] as int,
      ),
    );
  }
}
