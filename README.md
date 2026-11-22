# WHATCANICOOK

**Descubre qué puedes cocinar con los ingredientes que ya tienes.**

WHATCANICOOK es una app Flutter para Android con identidad **Dark Premium** (grafito `#161618`, superficies elevadas y acento dorado). Conserva la arquitectura original y añade fotografías reales de comida, un logotipo propio y una integración segura con Gemini.

## Qué hace

- Escanea ingredientes con la cámara o galería y permite corregir la lista detectada.
- Permite ingresar ingredientes manualmente desde un catálogo local.
- Busca, filtra, ordena y guarda recetas verificadas de **MyPlate (USDA)**.
- Usa Gemini para **seleccionar** recetas del catálogo oficial; **nunca inventa recetas**.
- Muestra fotos reales descargadas localmente, con fallback elegante si falla una imagen.
- Guarda ingredientes, favoritos, historial y perfil en SQLite local.
- Comparte recetas, abre la fuente original y muestra errores, carga y estados vacíos.
- Mantiene la clave de Gemini **solo en el backend**.

## Estado real del proyecto

| Funcionalidad | Estado |
| --- | --- |
| Interfaz Dark Premium, navegación, SQLite, catálogo, filtros, favoritos e historial | Implementado; `flutter analyze` sin problemas y pruebas Flutter en verde |
| Escaneo con IA | Implementado; usa `gemini-3.8-flash` y requiere backend accesible con clave configurada |
| Recetas | 13 recetas verificadas de MyPlate/USDA con foto local y enlace a la fuente |
| Generación asistida | Gemini solo devuelve IDs del catálogo; el backend valida y devuelve recetas oficiales |
| Pruebas backend | `unittest` con Gemini simulado; ninguna clave real en las pruebas |
| APK de release | Generable; ver la sección «Generar el APK» |

## Seguridad

- La clave de Gemini **nunca se incluye en el APK, Flutter, GitHub ni logs**.
- Flutter solo recibe la URL del backend mediante `--dart-define=WHATCANICOOK_API_BASE_URL=...`.
- El backend Flask lee `GEMINI_API_KEY` desde `backend/.env` (o `.env` local).
- `.env`, `backend/.env`, entornos virtuales, keystores y APK/AAB generados están excluidos por `.gitignore`.
- `backend/.env.example` y `.env.example` contienen **solo marcadores de posición**.
- El manifiesto permite HTTP solo para `10.0.2.2`, `127.0.0.1` y `localhost`; cualquier backend remoto debe usar HTTPS.

## Estructura

```text
WHATCANICOOK/
├─ android/                  Configuración nativa Android e iconos launcher
├─ assets/
│  ├─ data/                  Catálogo de ingredientes y 13 recetas verificadas
│  ├─ icons/                 Icono original dark y adaptive foreground
│  ├─ images/recipes/        13 fotografías reales locales
│  ├─ images/splash.png      Recurso splash
│  └─ logos/                 Logotipo original (SVG/PNG)
├─ backend/                  Proxy Flask seguro para Gemini y endpoints REST
├─ docs/                     API, build, fuentes de recetas e imágenes
├─ legacy/practica_dart/     Proyecto original conservado (no se usa)
├─ lib/                      Código Flutter (core, models, database, services, providers, screens, widgets)
├─ releases/                 APK generado para distribución (ignorado por Git)
├─ test/                     Pruebas Flutter
└─ tools/                    Generación reproducible de assets
```

## Inicio rápido (Windows / PowerShell)

### 1. Dependencias y calidad

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Requiere Flutter 3.47+ / Dart 3.13+ y Android SDK con licencias aceptadas.

Pruebas del backend, con Gemini simulado:

```powershell
.\backend\.venv\Scripts\python.exe -m unittest discover -s backend -p "test_*.py" -v
```

### 2. Activar IA

```powershell
copy .env.example .env
# Edita .env y pega tu GEMINI_API_KEY real solo en tu máquina.
```

Backend:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

Verificación (no muestra la clave):

```powershell
curl http://127.0.0.1:5000/api/health
```

Debe devolver `"aiConfigured": true`, `"model": "gemini-3.8-flash"` y los endpoints disponibles.

### 3. Ejecutar la app

Emulador Android:

```powershell
flutter run --dart-define=WHATCANICOOK_API_BASE_URL=http://10.0.2.2:5000
```

Dispositivo físico en la misma red (sustituye la IP; consulta `ipconfig`):

```powershell
flutter run --dart-define=WHATCANICOOK_API_BASE_URL=http://192.168.1.10:5000
```

> El emulador usa `10.0.2.2` para hablar con tu PC. Un dispositivo físico **no** puede usar esa IP. Para producción, publica el backend detrás de HTTPS.

Si no configuras backend o clave, la app sigue funcionando: muestra un mensaje claro y mantiene disponible la selección manual y el catálogo verificado.

Detalle completo: [docs/API_SETUP.md](docs/API_SETUP.md).

## Endpoints

| Método | Ruta | Descripción |
| --- | --- | --- |
| `GET` | `/api/health` | Estado, modelo, catálogo y endpoints |
| `POST` | `/api/vision/ingredients` | Imagen → ingredientes detectados por Gemini |
| `POST` | `/api/recipes/generate` | Ingredientes + filtros → recetas verificadas seleccionadas |
| `GET` | `/api/recipes` | Catálogo, con `q`, `category` y `limit` |
| `GET` | `/api/recipes/{id}` | Detalle de una receta verificada |

La respuesta de `/api/recipes/generate` incluye `mode` (`gemini` o `local`), `selected`, `recipes`, `reasons`, `filledLocally`, `totalCandidates`, `verifiedOnly` y `warning`.

## Generar el APK

```powershell
flutter build apk --release --dart-define=WHATCANICOOK_API_BASE_URL=http://10.0.2.2:5000
Copy-Item build\app\outputs\flutter-apk\app-release.apk releases\WHATCANICOOK.apk -Force
```

Ese APK está orientado al **emulador Android**. Para un dispositivo físico o producción, reconstruye con la IP/localidad o URL HTTPS correcta. El APK se guarda en `releases/WHATCANICOOK.apk` y está ignorado por Git deliberadamente.

Más detalles: [docs/BUILD.md](docs/BUILD.md).

## Fuentes

- Recetas: [docs/RECIPE_SOURCES.md](docs/RECIPE_SOURCES.md)
- Fotografías y licencias: [docs/IMAGE_SOURCES.md](docs/IMAGE_SOURCES.md)
- Las fotos son representaciones visuales de Wikimedia Commons; **no fueron verificadas por Gemini** y no alteran los datos oficiales.

## Repositorio

- Remoto: `https://github.com/josueresendez1607-create/WHATCAINICOOK.git`
- Rama principal: `main`
- El proyecto original `practica_dart` se conserva en `legacy/practica_dart/` y está excluido del analizador.
