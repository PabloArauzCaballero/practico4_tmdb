import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:practico4_tmdb/data/movie_database.dart';
import 'package:practico4_tmdb/models/movie.dart';
import 'package:practico4_tmdb/services/tmdb_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('TmdbService', () {
    test('busca por título y año', () async {
      late Uri called;
      final service = TmdbService(
        apiKey: 'clave',
        client: MockClient((req) async {
          called = req.url;
          return _json({
            'results': [
              {'id': 557, 'title': 'Spider-Man', 'release_date': '2002-05-01'},
            ],
          });
        }),
      );
      final results = await service.searchByTitle(
        'Spider-Man',
        MediaType.movie,
        year: 2002,
      );
      expect(called.path, '/3/search/movie');
      expect(called.queryParameters['primary_release_year'], '2002');
      expect(called.queryParameters['api_key'], 'clave');
      expect(results.single.title, 'Spider-Man');
      expect(results.single.year, '2002');
    });

    test('busca por año usando discover', () async {
      late Uri called;
      final service = TmdbService(
        apiKey: 'eyJtoken',
        client: MockClient((req) async {
          called = req.url;
          expect(req.headers['Authorization'], 'Bearer eyJtoken');
          return _json({'results': []});
        }),
      );
      await service.searchByYear(1999, MediaType.movie);
      expect(called.path, '/3/discover/movie');
      expect(called.queryParameters['primary_release_year'], '1999');
      expect(called.queryParameters.containsKey('api_key'), isFalse);
    });

    test('arma el detalle con director, géneros y duración', () async {
      final service = TmdbService(
        apiKey: 'clave',
        client: MockClient(
          (req) async => _json({
            'id': 557,
            'title': 'Spider-Man',
            'release_date': '2002-05-01',
            'runtime': 121,
            'genres': [
              {'id': 1, 'name': 'Acción'},
              {'id': 2, 'name': 'Ciencia ficción'},
            ],
            'overview': 'Peter Parker...',
            'vote_average': 7.3,
            'vote_count': 18900,
            'poster_path': '/p.jpg',
            'credits': {
              'crew': [
                {'job': 'Producer', 'name': 'Otro'},
                {'job': 'Director', 'name': 'Sam Raimi'},
              ],
            },
          }),
        ),
      );
      final d = await service.getDetail(557, MediaType.movie);
      expect(d.director, 'Sam Raimi');
      expect(d.genres, 'Acción, Ciencia ficción');
      expect(d.runtimeLabel, '2 h 1 min');
      expect(d.year, '2002');
      expect(d.posterUrl, endsWith('/p.jpg'));
    });

    test('sin clave lanza un error claro', () {
      final service = TmdbService(apiKey: '');
      expect(
        service.searchByTitle('x', MediaType.movie),
        throwsA(isA<TmdbException>()),
      );
    });
  });

  group('MovieDatabase', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      MovieDatabase.pathOverride = inMemoryDatabasePath;
    });
    tearDown(() => MovieDatabase.instance.close());

    MovieDetail movie(int id, String title, String date) => MovieDetail(
      id: id,
      mediaType: MediaType.movie,
      title: title,
      releaseDate: date,
      runtimeMinutes: 100,
      genres: 'Acción',
      director: 'Alguien',
      overview: 'Sinopsis',
      voteAverage: 7.5,
      voteCount: 10,
    );

    test('guarda, ordena por reciente, filtra y no duplica', () async {
      final db = MovieDatabase.instance;
      await db.save(movie(1, 'Spider-Man', '2002-05-01'));
      await Future.delayed(const Duration(milliseconds: 5));
      await db.save(movie(2, 'The Platform 2', '2024-10-04'));
      await Future.delayed(const Duration(milliseconds: 5));
      await db.save(movie(1, 'Spider-Man', '2002-05-01'));

      final all = await db.history();
      expect(all.map((m) => m.title), ['Spider-Man', 'The Platform 2']);
      expect(all.first.director, 'Alguien');
      expect((await db.history(filter: '2024')).single.id, 2);
      expect((await db.history(filter: 'spider')).single.id, 1);

      await db.delete(1, MediaType.movie);
      expect((await db.history()).length, 1);
    });
  });
}
