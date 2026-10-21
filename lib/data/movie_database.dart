import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/movie.dart';

/// Base de datos local (SQLite) con el historial de búsqueda.
class MovieDatabase {
  MovieDatabase._();
  static final MovieDatabase instance = MovieDatabase._();

  static const _table = 'movies';
  Database? _db;

  /// Permite abrir otra ruta (por ejemplo, una base en memoria en los tests).
  static String? pathOverride;

  Future<Database> get database async {
    return _db ??= await openDatabase(
      pathOverride ?? join(await getDatabasesPath(), 'peliculas.db'),
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE $_table (
          id INTEGER NOT NULL,
          media_type TEXT NOT NULL,
          title TEXT NOT NULL,
          release_date TEXT NOT NULL,
          runtime INTEGER,
          genres TEXT NOT NULL,
          director TEXT NOT NULL,
          overview TEXT NOT NULL,
          vote_average REAL NOT NULL,
          vote_count INTEGER NOT NULL,
          poster_url TEXT,
          poster_bytes BLOB,
          searched_at INTEGER NOT NULL,
          PRIMARY KEY (id, media_type)
        )
      '''),
    );
  }

  /// Guarda la película; si ya existía, la actualiza y la sube al inicio.
  Future<void> save(MovieDetail movie) async {
    final db = await database;
    await db.insert(
      _table,
      movie.copyWith(searchedAt: DateTime.now()).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Historial, de la más reciente a la más antigua.
  Future<List<MovieDetail>> history({String filter = ''}) async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: filter.isEmpty ? null : 'title LIKE ? OR release_date LIKE ?',
      whereArgs: filter.isEmpty ? null : ['%$filter%', '$filter%'],
      orderBy: 'searched_at DESC',
    );
    return rows.map(MovieDetail.fromMap).toList();
  }

  Future<MovieDetail?> find(int id, MediaType type) async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'id = ? AND media_type = ?',
      whereArgs: [id, type.apiPath],
      limit: 1,
    );
    return rows.isEmpty ? null : MovieDetail.fromMap(rows.first);
  }

  Future<void> delete(int id, MediaType type) async {
    final db = await database;
    await db.delete(
      _table,
      where: 'id = ? AND media_type = ?',
      whereArgs: [id, type.apiPath],
    );
  }

  /// Vuelve a insertar una película borrada, conservando su fecha original.
  Future<void> restore(MovieDetail movie) async {
    final db = await database;
    await db.insert(
      _table,
      movie.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete(_table);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
