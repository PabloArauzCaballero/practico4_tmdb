/// Credencial de The Movie Database.
///
/// Se pasa al ejecutar, sin guardarla en el código:
///   flutter run --dart-define=TMDB_API_KEY=tu_clave
///
/// Sirve tanto la "API Key" (v3) como el "API Read Access Token" (v4)
/// que aparecen en https://www.themoviedb.org/settings/api
const String tmdbApiKey = String.fromEnvironment('TMDB_API_KEY');

const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/w500';
const String tmdbLanguage = 'es-ES';
