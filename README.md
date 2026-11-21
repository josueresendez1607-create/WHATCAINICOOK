# WHATCANICOOK

**Descubre qué puedes cocinar con los ingredientes que ya tienes.**

WHATCANICOOK es una app Flutter para Android que:

- toma una foto (cámara o galería) y usa IA para proponer ingredientes detectados;
- permite corregir, agregar o quitar ingredientes antes de buscar recetas;
- permite seleccionar ingredientes manualmente desde un catálogo local;
- recomienda **recetas verificadas de fuentes oficiales** (MyPlate / USDA), con enlace a la fuente;
- filtra y ordena recetas por coincidencia, tiempo, tipo de comida y preferencias del perfil;
- guarda favoritos, historial y preferencias en SQLite local;
- usa Material 3 con identidad visual propia (naranja/crema/verde).

## Estado real del proyecto

| Funcionalidad | Estado |
| --- | --- |
| Interfaz, navegación, SQLite, catálogo, filtros, favoritos e historial | Implementado y verificado con `flutter analyze` y `flutter test` |
| Escaneo con IA | Implementado en el cliente y el backend, pero **requiere configurar `GEMINI_API_KEY`** y una URL de backend accesible |
| Recetas | 13 recetas transcritas de páginas oficiales de MyPlate (USDA); la app **no inventa recetas** |
| Prueba en dispositivo físico | **No realizada**: no hay dispositivo/emulador conectado en el entorno de desarrollo |
| APK de release | Generable con `flutter build apk --release`; se distribuye en `releases/WHATCANICOOK.apk` |

## Seguridad

- La clave de Gemini **nunca se incluye en el APK ni en GitHub**.
- La app Flutter solo conoce la URL del backend mediante `--dart-define=WHATCANICOOK_API_BASE_URL=...`.
- El backend Flask lee `GEMINI_API_KEY` desde variables de entorno locales.
- `.env`, `backend/.env`, keystores y APK/AAB generados están excluidos por `.gitignore`.

## Estructura

```text
WHATCANICOOK/
├─ android/                  Configuración nativa Android
├─ assets/
│  ├─ data/                  Catálogo de ingredientes y recetas verificadas
│  ├─ icons/                 Icono adaptive y launcher
│  ├─ images/                Splash
│  └─ logos/                 Logo original
├─ backend/                  Proxy Flask seguro para Gemini
├─ docs/                     Guías de API, build y fuentes
├─ legacy/practica_dart/     Proyecto original conservado (no se usa)
├─ lib/                      Código Flutter (core, models, database, services, providers, screens, widgets)
├─ releases/                 APK generado para distribución
├─ test/                     Pruebas unitarias y de widget
└─ tools/                    Generación reproducible de assets
```

## Inicio rápido

### 1. Dependencias Flutter

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Requiere Flutter 3.47+ / Dart 3.13+ y Android SDK 36 con licencias aceptadas.

### 2. Activar el escaneo con IA (opcional pero necesario para esa función)

```powershell
copy .env.example .env
# Edita .env y pega tu GEMINI_API_KEY real.
```

Luego, desde `backend/`:

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

Verifica:

```powershell
curl http://127.0.0.1:5000/api/health
```

Debe devolver `"aiConfigured": true`.

Finalmente ejecuta la app apuntando al backend:

```powershell
# Emulador Android
flutter run --dart-define=WHATCANICOOK_API_BASE_URL=http://10.0.2.2:5000

# Dispositivo físico en la misma red (sustituye la IP)
flutter run --dart-define=WHATCANICOOK_API_BASE_URL=http://192.168.1.10:5000
```

Si no configuras el backend o la clave, la app sigue funcionando: el escaneo muestra un mensaje claro y la selección manual de ingredientes sigue disponible.

Consulta [docs/API_SETUP.md](docs/API_SETUP.md) para el detalle completo.

### 3. Generar el APK

```powershell
flutter build apk --release
Copy-Item build\app\outputs\flutter-apk\app-release.apk releases\WHATCANICOOK.apk -Force
```

Consulta [docs/BUILD.md](docs/BUILD.md) para AAB, firma y Play Store.

## Fuentes de las recetas

Las 13 recetas incluidas proceden de [MyPlate (USDA)](https://www.myplate.gov/recipes). Cada una conserva `sourceUrl`, `originalSource`, tiempos y valores nutricionales **cuando la fuente oficial los publica**. Las etiquetas y la dificultad son estimaciones de la app y están marcadas como tales.

Listado completo: [docs/RECIPE_SOURCES.md](docs/RECIPE_SOURCES.md).

## Repositorio

- Remoto: `https://github.com/josueresendez1607-create/WHATCANICOOK.git`
- Rama principal: `main`
- El proyecto original `practica_dart` se conserva en `legacy/practica_dart/` y está excluido del analizador.
