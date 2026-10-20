import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
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
                          border: const OutlineInputBorder(),
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
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
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
      return Center(
        child: Text(
          widget.service.hasApiKey
              ? 'Busca una película o serie.'
              : 'Falta la clave de TMDB.\nEjecuta con --dart-define=TMDB_API_KEY=…',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return const Center(child: Text('No se encontraron resultados.'));
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          leading: _Thumb(path: item.posterPath),
          title: Text(item.title),
          subtitle: Text(item.year.isEmpty ? 'Año desconocido' : item.year),
          trailing: const Icon(Icons.chevron_right),
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

class _Thumb extends StatelessWidget {
  const _Thumb({this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 40,
      height: 60,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.movie_outlined, size: 20),
    );
    if (path == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        '${tmdbImageBaseUrl.replaceFirst('w500', 'w92')}$path',
        width: 40,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
