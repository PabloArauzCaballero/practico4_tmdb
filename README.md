# Práctico 4 — Cliente de The Movie Database en Flutter

Buscador de **películas o series** que usa la API de [TMDB](https://developers.themoviedb.org/).

## Qué hace

- **Buscar** por **título** (con año opcional) o por **año de estreno**, en películas o series.
- **Detalle** con: título, año, duración, género, director, sinopsis, imagen (póster) y
  rating de usuarios en TMDB (puntuación sobre 10 y cantidad de votos).
  En series, “Director” muestra a los creadores y la duración es por episodio.
- **Cada película que se abre se guarda en la base de datos local** (SQLite con `sqflite`),
  incluida la imagen, para poder verla sin internet.
- **Historial de búsqueda**: lista lo buscado, leído **directo de la base de datos**,
  con filtro por título o año, deslizar para borrar uno y botón para borrar todo.
  Al tocar uno se muestra su detalle completo desde la base.

## Cómo ejecutarlo

1. Conseguir una credencial en <https://www.themoviedb.org/settings/api>
   (sirve la “API Key” o el “API Read Access Token”).
2. Copiar `tmdb.example.json` como `tmdb.json` y pegar la credencial:

   ```json
   { "TMDB_API_KEY": "tu_clave_o_token" }
   ```

3. Ejecutar:

   ```bash
   flutter pub get
   flutter run --dart-define-from-file=tmdb.json
   ```

   En VS Code basta con F5 (la configuración ya pasa `tmdb.json`).

`tmdb.json` está en `.gitignore` para que la clave no quede publicada en el repositorio.

## Pruebas

```bash
flutter test                                                    # servicio, base de datos y buscador
flutter test integration_test --dart-define-from-file=tmdb.json # flujo completo en emulador
```

La prueba de integración recorre la app real contra TMDB: busca *Spider-Man (2002)*,
abre el detalle (director Sam Raimi, 2 h 1 min), busca por año, busca la serie
*Breaking Bad* y luego revisa ambas en el historial leyendo desde la base local.
Probada en simulador de iPhone (iOS 26.5) y emulador de Android (API 37).

## Estructura

```
lib/
├── main.dart                  # App y navegación (Buscar / Historial de búsqueda)
├── config.dart                # URL de la API y lectura de la clave
├── models/movie.dart          # Modelos de resultado y detalle
├── services/tmdb_service.dart # Llamadas a TMDB (búsqueda, detalle, créditos, póster)
├── data/movie_database.dart   # Base de datos local SQLite
└── screens/
    ├── search_screen.dart     # Buscador
    ├── detail_screen.dart     # Detalle (desde la API o desde la base)
    └── history_screen.dart    # Historial de búsqueda
```
