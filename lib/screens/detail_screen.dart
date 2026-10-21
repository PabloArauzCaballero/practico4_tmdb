import 'package:flutter/material.dart';

import '../data/movie_database.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../widgets/common.dart';

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
    final scheme = theme.colorScheme;
    final isTv = movie.mediaType == MediaType.tv;
    final genres = movie.genres
        .split(',')
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PosterImage(
              bytes: movie.posterBytes,
              url: movie.posterUrl,
              width: 130,
              height: 195,
              radius: 14,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isTv ? 'SERIE' : 'PELÍCULA',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    movie.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Rating(movie: movie),
                ],
              ),
            ),
          ],
        ),
        if (genres.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in genres)
                Chip(
                  label: Text(g),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: scheme.outlineVariant),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                icon: Icons.calendar_today,
                label: 'Año',
                value: movie.year,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                icon: Icons.schedule,
                label: isTv ? 'Por episodio' : 'Duración',
                value: movie.runtimeLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _InfoTile(
          icon: Icons.movie_creation_outlined,
          label: isTv ? 'Director / Creador' : 'Director',
          value: movie.director,
        ),
        const SizedBox(height: 24),
        Text(
          'Sinopsis',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          movie.overview.isEmpty ? 'Sin sinopsis disponible.' : movie.overview,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              fromHistory ? Icons.storage : Icons.check_circle_outline,
              size: 16,
              color: scheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fromHistory
                    ? 'Datos leídos de la base de datos local.'
                    : 'Guardada en el historial de búsqueda.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = RatingBadge.colorFor(movie.voteAverage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: color, size: 26),
            const SizedBox(width: 4),
            Text(
              '${movie.voteAverage.toStringAsFixed(1)} / 10',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${movie.voteCount} votos',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
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
