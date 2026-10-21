import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Póster con esquinas redondeadas; usa los bytes guardados o la URL.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    this.bytes,
    this.url,
    required this.width,
    required this.height,
    this.radius = 10,
  });

  final Uint8List? bytes;
  final String? url;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: width,
      height: height,
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.movie_outlined,
        size: width * 0.4,
        color: scheme.onSurfaceVariant,
      ),
    );
    final Widget image;
    if (bytes != null) {
      image = Image.memory(
        bytes!,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } else if (url != null) {
      image = Image.network(
        url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
      );
    } else {
      image = placeholder;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image,
      ),
    );
  }
}

/// Puntuación compacta con estrella, coloreada según la nota.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.value});
  final double value;

  static Color colorFor(double value) {
    if (value >= 7) return const Color(0xFF21D07A);
    if (value >= 5) return const Color(0xFFF5C518);
    return const Color(0xFFDB2360);
  }

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();
    final color = colorFor(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío con icono grande y mensaje.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de lista con póster, título, año y puntuación dentro de una tarjeta.
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.leading,
    required this.title,
    required this.year,
    this.rating = 0,
    this.extra,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String year;
  final double rating;
  final String? extra;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              leading,
              Expanded(child: _tile(theme)),
            ],
          ),
        ),
      ),
    );
  }

  // ListTile sin leading: ListTile limita la altura del leading y
  // recortaría el póster.
  Widget _tile(ThemeData theme) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.only(left: 14),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(year, style: theme.textTheme.bodyMedium),
            if (extra != null)
              Text(
                extra!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            RatingBadge(value: rating),
          ],
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
    );
  }
}
