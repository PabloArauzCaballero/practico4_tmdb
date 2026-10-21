import 'package:flutter/material.dart';

import '../data/movie_database.dart';
import '../models/movie.dart';
import '../widgets/common.dart';
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

  /// Borra un elemento del historial y ofrece deshacerlo.
  Future<void> _delete(MovieDetail movie) async {
    await MovieDatabase.instance.delete(movie.id, movie.mediaType);
    reload();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('«${movie.title}» se borró del historial.'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            await MovieDatabase.instance.restore(movie);
            reload();
          },
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(MovieDetail movie) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('¿Borrar del historial?'),
        content: Text('Se eliminará «${movie.title}» del historial.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    return confirm == true;
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
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
                prefixIcon: Icon(Icons.filter_list),
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
                  return _filterController.text.isEmpty
                      ? const EmptyState(
                          icon: Icons.history,
                          title: 'Todavía no buscaste ninguna película.',
                          message:
                              'Las películas y series que abras aparecerán aquí.',
                        )
                      : const EmptyState(
                          icon: Icons.filter_list_off,
                          title: 'Nada coincide con el filtro.',
                        );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: movies.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                        child: Text(
                          '${movies.length} ${movies.length == 1 ? 'guardada' : 'guardadas'} · desliza o toca la papelera para borrar',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final movie = movies[index - 1];
                    return Dismissible(
                      key: ValueKey('${movie.mediaType.apiPath}-${movie.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      onDismissed: (_) => _delete(movie),
                      child: MediaCard(
                        leading: PosterImage(
                          bytes: movie.posterBytes,
                          width: 56,
                          height: 84,
                          radius: 8,
                        ),
                        title: movie.title,
                        year: movie.year,
                        extra: movie.mediaType == MediaType.tv
                            ? 'Serie'
                            : 'Película',
                        rating: movie.voteAverage,
                        trailing: IconButton(
                          tooltip: 'Borrar del historial',
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () async {
                            if (await _confirmDelete(movie)) _delete(movie);
                          },
                        ),
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
