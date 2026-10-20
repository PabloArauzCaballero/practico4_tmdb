import 'package:flutter/material.dart';

import '../data/movie_database.dart';
import '../models/movie.dart';
import 'detail_screen.dart';

/// Historial de búsqueda: todo se lee de la base de datos local.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final _filterController = TextEditingController();
  late Future<List<MovieDetail>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<List<MovieDetail>> _load() =>
      MovieDatabase.instance.history(filter: _filterController.text.trim());

  /// Vuelve a leer la base (se llama al entrar a la pestaña).
  void reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _delete(MovieDetail movie) async {
    await MovieDatabase.instance.delete(movie.id, movie.mediaType);
    reload();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar el historial?'),
        content: const Text('Se eliminarán todas las búsquedas guardadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await MovieDatabase.instance.clear();
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de búsqueda'),
        actions: [
          IconButton(
            tooltip: 'Borrar historial',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _filterController,
              decoration: const InputDecoration(
                hintText: 'Filtrar por título o año',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => reload(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MovieDetail>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final movies = snapshot.data!;
                if (movies.isEmpty) {
                  return Center(
                    child: Text(
                      _filterController.text.isEmpty
                          ? 'Todavía no buscaste ninguna película.'
                          : 'Nada coincide con el filtro.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: movies.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return Dismissible(
                      key: ValueKey('${movie.mediaType.apiPath}-${movie.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: theme.colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline),
                      ),
                      onDismissed: (_) => _delete(movie),
                      child: ListTile(
                        leading: _StoredThumb(movie: movie),
                        title: Text(movie.title),
                        subtitle: Text(
                          '${movie.year} · ${movie.mediaType == MediaType.tv ? 'Serie' : 'Película'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                DetailScreen.fromHistory(stored: movie),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoredThumb extends StatelessWidget {
  const _StoredThumb({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final bytes = movie.posterBytes;
    if (bytes == null) {
      return Container(
        width: 40,
        height: 60,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.movie_outlined, size: 20),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.memory(bytes, width: 40, height: 60, fit: BoxFit.cover),
    );
  }
}
