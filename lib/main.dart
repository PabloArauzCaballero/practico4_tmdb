import 'package:flutter/material.dart';

import 'screens/history_screen.dart';
import 'screens/search_screen.dart';
import 'services/tmdb_service.dart';

void main() {
  runApp(const MovieApp());
}

class MovieApp extends StatelessWidget {
  const MovieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buscador TMDB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF01B4E4)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF01B4E4),
          brightness: Brightness.dark,
        ),
      ),
      home: HomeScreen(service: TmdbService()),
    );
  }
}

/// Pantalla principal con dos pestañas: Buscar e Historial.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.service});
  final TmdbService service;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _historyKey = GlobalKey<HistoryScreenState>();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          SearchScreen(service: widget.service),
          HistoryScreen(key: _historyKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 1) _historyKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Historial de búsqueda',
          ),
        ],
      ),
    );
  }
}
