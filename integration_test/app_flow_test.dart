import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:practico4_tmdb/data/movie_database.dart';
import 'package:practico4_tmdb/main.dart';
import 'package:practico4_tmdb/models/movie.dart';

/// Recorre la app real contra TMDB:
/// buscar por título → detalle → guardado → historial → detalle desde la base.
/// Ejecutar con: flutter test integration_test --dart-define-from-file=tmdb.json
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .join(' | ');
  throw TestFailure('No apareció: $finder\nEn pantalla: $texts');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('buscar, ver detalle y revisarlo en el historial', (
    tester,
  ) async {
    await MovieDatabase.instance.clear();
    await tester.pumpWidget(const MovieApp());
    await tester.pumpAndSettle();

    // Búsqueda por título + año.
    await tester.enterText(find.byKey(const Key('searchField')), 'Spider-Man');
    await tester.enterText(find.byType(TextField).at(1), '2002');
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await pumpUntil(tester, find.widgetWithText(ListTile, 'Spider-Man'));

    await tester.tap(find.widgetWithText(ListTile, 'Spider-Man').first);
    await pumpUntil(tester, find.text('Sam Raimi'));
    expect(find.text('2002'), findsOneWidget);
    expect(find.text('2 h 1 min'), findsOneWidget);
    expect(find.textContaining('/ 10'), findsOneWidget);
    expect(await MovieDatabase.instance.find(557, MediaType.movie), isNotNull);

    // Volver y buscar por año.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Por año'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchField')), '1999');
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await pumpUntil(tester, find.byType(ListTile));
    expect(find.text('1999'), findsWidgets);

    // Series: el "director" son los creadores.
    await tester.tap(find.text('Series'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Por título'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('searchField')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('searchField')),
      'Breaking Bad',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await pumpUntil(tester, find.widgetWithText(ListTile, 'Breaking Bad'));
    await tester.tap(find.widgetWithText(ListTile, 'Breaking Bad').first);
    await pumpUntil(tester, find.text('Vince Gilligan'));
    expect(await MovieDatabase.instance.find(1396, MediaType.tv), isNotNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Historial: viene de la base local.
    await tester.tap(find.text('Historial de búsqueda'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Breaking Bad'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Spider-Man'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Spider-Man'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle del historial'), findsOneWidget);
    expect(find.text('Sam Raimi'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Datos leídos de la base de datos local.'),
      200,
    );
    expect(
      find.text('Datos leídos de la base de datos local.'),
      findsOneWidget,
    );
  });
}
