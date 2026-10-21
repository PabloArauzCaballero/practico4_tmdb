import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

enum SearchMode { title, year }

/// Buscador de películas o series por título o por año de estreno.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.service});
  final TmdbService service;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  final _yearController = TextEditingController();

  SearchMode _mode = SearchMode.title;
  MediaType _type = MediaType.movie;
  bool _loading = false;
  String? _error;
  List<MovieSummary>? _results;

  @override
  void dispose() {
    _queryController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  int? _parseYear(String text) {
    final year = int.tryParse(text.trim());
    if (year == null || year < 1874 || year > DateTime.now().year + 5) {
      return null;
    }
    return year;
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    final query = _queryController.text.trim();

    String? validation;
    int? year;
    if (_mode == SearchMode.title) {
      if (query.isEmpty) validation = 'Escribe un título para buscar.';
      final yearText = _yearController.text.trim();
      if (yearText.isNotEmpty) {
        year = _parseYear(yearText);
        if (year == null) validation = 'El año no es válido.';
      }
    } else {
      year = _parseYear(query);
      if (year == null) validation = 'Escribe un año válido, por ejemplo 2002.';
    }
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = _mode == SearchMode.title
          ? await widget.service.searchByTitle(query, _type, year: year)
          : await widget.service.searchByYear(year!, _type);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMode(SearchMode mode) {
    setState(() {
      _mode = mode;
      _queryController.clear();
      _yearController.clear();
      _results = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final byTitle = _mode == SearchMode.title;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<MediaType>(
                  segments: [
                    for (final t in MediaType.values)
                      ButtonSegment(
                        value: t,
                        label: Text(t.label),
                        icon: Icon(
                          t == MediaType.movie ? Icons.movie : Icons.tv,
                        ),
                      ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() {
                    _type = s.first;
                    _results = null;
                  }),
                ),
                const SizedBox(height: 8),
                SegmentedButton<SearchMode>(
                  segments: const [
                    ButtonSegment(
                      value: SearchMode.title,
                      label: Text('Por título'),
                      icon: Icon(Icons.title),
                    ),
                    ButtonSegment(
                      value: SearchMode.year,
                      label: Text('Por año'),
                      icon: Icon(Icons.calendar_month),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => _changeMode(s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        key: const Key('searchField'),
                        controller: _queryController,
                        textInputAction: TextInputAction.search,
                        keyboardType: byTitle
                            ? TextInputType.text
                            : TextInputType.number,
                        inputFormatters: byTitle
                            ? null
                            : [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                        decoration: InputDecoration(
                          labelText: byTitle ? 'Título' : 'Año de estreno',
                          hintText: byTitle ? 'Ej: Spider-Man' : 'Ej: 2002',
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    if (byTitle) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _yearController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Año',
                            hintText: 'Opcional',
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    final results = _results;
    if (results == null) {
      return widget.service.hasApiKey
          ? const EmptyState(
              icon: Icons.local_movies_outlined,
              title: 'Busca una película o serie.',
              message: 'Por título o por año de estreno.',
            )
          : const EmptyState(
              icon: Icons.key_off_outlined,
              title: 'Falta la clave de TMDB.',
              message: 'Ejecuta con --dart-define=TMDB_API_KEY=…',
            );
    }
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No se encontraron resultados.',
        message: 'Prueba con otro título o año.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              '${results.length} resultados',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final item = results[index - 1];
        return MediaCard(
          leading: PosterImage(
            url: item.posterPath == null
                ? null
                : '${tmdbImageBaseUrl.replaceFirst('w500', 'w185')}${item.posterPath}',
            width: 56,
            height: 84,
            radius: 8,
          ),
          title: item.title,
          year: item.year.isEmpty ? 'Año desconocido' : item.year,
          rating: item.voteAverage,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetailScreen.fromSearch(
                summary: item,
                service: widget.service,
              ),
            ),
          ),
        );
      },
    );
  }
}
