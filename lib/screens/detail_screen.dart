import 'package:flutter/material.dart';

import '../data/movie_database.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';

/// Detalle de una película o serie.
///
/// Con [summary] la trae de TMDB y la guarda en la base local.
/// Con [stored] la muestra directo desde la base local, sin internet.
class DetailScreen extends StatefulWidget {
  const DetailScreen.fromSearch({
    super.key,
    required MovieSummary this.summary,
    required this.service,
  }) : stored = null;

  const DetailScreen.fromHistory({super.key, required MovieDetail this.stored})
    : summary = null,
      service = null;

  final MovieSummary? summary;
  final MovieDetail? stored;
  final TmdbService? service;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<MovieDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MovieDetail> _load() async {
    final stored = widget.stored;
    if (stored != null) return stored;

    final service = widget.service!;
    final summary = widget.summary!;
    final detail = await service.getDetail(summary.id, summary.mediaType);
    final poster = await service.downloadPoster(detail.posterUrl);
    final complete = detail.copyWith(posterBytes: poster);
    await MovieDatabase.instance.save(complete);
    return complete;
  }

  @override
  Widget build(BuildContext context) {
    final fromHistory = widget.stored != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(fromHistory ? 'Detalle del historial' : 'Detalle'),
      ),
      body: FutureBuilder<MovieDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () => setState(() {
                _future = _load();
              }),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _DetailBody(movie: snapshot.data!, fromHistory: fromHistory);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.movie, required this.fromHistory});

  final MovieDetail movie;
  final bool fromHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTv = movie.mediaType == MediaType.tv;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(child: _Poster(movie: movie)),
        const SizedBox(height: 20),
        Text(
          movie.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Center(child: _Rating(movie: movie)),
        const SizedBox(height: 20),
        _InfoRow(icon: Icons.calendar_today, label: 'Año', value: movie.year),
        _InfoRow(
          icon: Icons.schedule,
          label: isTv ? 'Duración por episodio' : 'Duración',
          value: movie.runtimeLabel,
        ),
        _InfoRow(icon: Icons.category, label: 'Género', value: movie.genres),
        _InfoRow(
          icon: Icons.movie_creation_outlined,
          label: isTv ? 'Director / Creador' : 'Director',
          value: movie.director,
        ),
        const SizedBox(height: 16),
        Text('Sinopsis', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(movie.overview, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(
              fromHistory ? Icons.storage : Icons.check_circle_outline,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fromHistory
                    ? 'Datos leídos de la base de datos local.'
                    : 'Guardada en el historial de búsqueda.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final bytes = movie.posterBytes;
    final placeholder = Container(
      width: 220,
      height: 330,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.image_not_supported_outlined, size: 48),
    );
    final Widget image;
    if (bytes != null) {
      image = Image.memory(bytes, width: 220, fit: BoxFit.cover);
    } else if (movie.posterUrl != null) {
      image = Image.network(
        movie.posterUrl!,
        width: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      image = placeholder;
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber),
          const SizedBox(width: 6),
          Text(
            '${movie.voteAverage.toStringAsFixed(1)} / 10',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text('(${movie.voteCount} votos)', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
