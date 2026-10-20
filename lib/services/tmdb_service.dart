import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/movie.dart';

class TmdbException implements Exception {
  TmdbException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cliente de la API de The Movie Database.
class TmdbService {
  TmdbService({http.Client? client, this._apiKey = tmdbApiKey})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String _apiKey;

  bool get hasApiKey => _apiKey.isNotEmpty;

  // El token v4 es un JWT (empieza con "eyJ") y va en la cabecera;
  // la clave v3 va como parámetro de la URL.
  bool get _isBearerToken => _apiKey.startsWith('eyJ');

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String> params = const {},
  ]) async {
    if (!hasApiKey) {
      throw TmdbException(
        'Falta la clave de TMDB. Ejecuta la app con '
        '--dart-define=TMDB_API_KEY=tu_clave',
      );
    }
    final query = {
      'language': tmdbLanguage,
      ...params,
      if (!_isBearerToken) 'api_key': _apiKey,
    };
    final uri = Uri.parse('$tmdbBaseUrl$path').replace(queryParameters: query);
    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'accept': 'application/json',
              if (_isBearerToken) 'Authorization': 'Bearer $_apiKey',
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw TmdbException('No se pudo conectar con TMDB. Revisa tu conexión.');
    }
    if (response.statusCode == 401) {
      throw TmdbException('La clave de TMDB no es válida.');
    }
    if (response.statusCode != 200) {
      throw TmdbException('TMDB respondió con error ${response.statusCode}.');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Busca por título; si se indica año, filtra por año de estreno.
  Future<List<MovieSummary>> searchByTitle(
    String title,
    MediaType type, {
    int? year,
  }) async {
    final data = await _get('/search/${type.apiPath}', {
      'query': title,
      'include_adult': 'false',
      if (year != null)
        type == MediaType.movie
                ? 'primary_release_year'
                : 'first_air_date_year':
            '$year',
    });
    return _parseResults(data, type);
  }

  /// Lista las más populares de un año de estreno.
  Future<List<MovieSummary>> searchByYear(int year, MediaType type) async {
    final data = await _get('/discover/${type.apiPath}', {
      'sort_by': 'popularity.desc',
      'include_adult': 'false',
      if (type == MediaType.movie)
        'primary_release_year': '$year'
      else
        'first_air_date_year': '$year',
    });
    return _parseResults(data, type);
  }

  List<MovieSummary> _parseResults(Map<String, dynamic> data, MediaType type) {
    final results = (data['results'] as List).cast<Map<String, dynamic>>();
    return results.map((json) => MovieSummary.fromJson(json, type)).toList();
  }

  /// Trae el detalle completo, incluido el director desde los créditos.
  Future<MovieDetail> getDetail(int id, MediaType type) async {
    final data = await _get('/${type.apiPath}/$id', {
      'append_to_response': 'credits',
    });

    var overview = (data['overview'] as String?)?.trim() ?? '';
    if (overview.isEmpty) {
      // Muchas fichas no tienen sinopsis en español: se usa la de inglés.
      final english = await _get('/${type.apiPath}/$id', {'language': 'en-US'});
      overview = (english['overview'] as String?)?.trim() ?? '';
    }

    final genres = ((data['genres'] as List?) ?? [])
        .map((g) => g['name'] as String)
        .join(', ');

    final posterPath = data['poster_path'] as String?;

    return MovieDetail(
      id: data['id'] as int,
      mediaType: type,
      title: (data['title'] ?? data['name'] ?? 'Sin título') as String,
      releaseDate:
          (data['release_date'] ?? data['first_air_date'] ?? '') as String,
      runtimeMinutes: _runtime(data, type),
      genres: genres.isEmpty ? 'Sin dato' : genres,
      director: _director(data, type),
      overview: overview.isEmpty ? 'Sin sinopsis disponible.' : overview,
      voteAverage: (data['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: (data['vote_count'] as num?)?.toInt() ?? 0,
      posterUrl: posterPath == null ? null : '$tmdbImageBaseUrl$posterPath',
    );
  }

  int? _runtime(Map<String, dynamic> data, MediaType type) {
    if (type == MediaType.movie) return (data['runtime'] as num?)?.toInt();
    // Las series traen la duración por episodio.
    final episodes = data['episode_run_time'] as List?;
    if (episodes != null && episodes.isNotEmpty) {
      return (episodes.first as num).toInt();
    }
    final last = data['last_episode_to_air'] as Map<String, dynamic>?;
    return (last?['runtime'] as num?)?.toInt();
  }

  String _director(Map<String, dynamic> data, MediaType type) {
    final crew = ((data['credits']?['crew'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final directors = crew
        .where((c) => c['job'] == 'Director')
        .map((c) => c['name'] as String)
        .toSet()
        .toList();
    if (directors.isEmpty && type == MediaType.tv) {
      // Las series no tienen director único: se muestran sus creadores.
      directors.addAll(
        ((data['created_by'] as List?) ?? []).map((c) => c['name'] as String),
      );
    }
    if (directors.isEmpty) return 'Sin dato';
    return directors.take(3).join(', ');
  }

  /// Descarga el póster para guardarlo en la base local.
  Future<Uint8List?> downloadPoster(String? url) async {
    if (url == null) return null;
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200 ? response.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }
}
