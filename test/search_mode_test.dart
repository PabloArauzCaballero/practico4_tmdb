import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:practico4_tmdb/screens/search_screen.dart';
import 'package:practico4_tmdb/services/tmdb_service.dart';

void main() {
  testWidgets('cambiar de "Por año" a "Por título" acepta letras',
      (tester) async {
    final service = TmdbService(
      apiKey: 'k',
      client: MockClient((_) async => http.Response('{"results":[{"id":1,"title":"Matrix","release_date":"1999-03-30"}]}', 200)),
    );
    await tester.pumpWidget(MaterialApp(home: SearchScreen(service: service)));
    await tester.tap(find.text('Por año'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchField')), '1999');
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Matrix'), findsOneWidget);
    await tester.tap(find.text('Series'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Por título'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchField')), 'Breaking Bad');
    await tester.pump();
    expect(find.text('Breaking Bad'), findsOneWidget);
  });
}
