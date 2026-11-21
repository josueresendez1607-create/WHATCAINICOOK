# Compilación y distribución

## Requisitos verificados en este entorno

- Flutter 3.47.9 / Dart 3.13.7
- Android SDK 36 con licencias aceptadas
- JDK 25 de Android Studio JBR
- Git 2.56

## Verificación antes de compilar

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Estado actual: `flutter analyze` sin issues y `flutter test` con 10 pruebas superadas.

## APK de release

```powershell
flutter build apk --release
Copy-Item build\app\outputs\flutter-apk\app-release.apk releases\WHATCANICOOK.apk -Force
```

Salida: `releases/WHATCANICOOK.apk`.

Si vas a usar escaneo con IA en esa APK, compila con la URL real del backend:

```powershell
flutter build apk --release --dart-define=WHATCANICOOK_API_BASE_URL=https://tu-dominio-seguro.example
```

> La clave de Gemini **no** se pasa como `--dart-define`. Solo el backend la conoce.

## Íconos

Los íconos se generan desde `assets/icons/app_icon.png` y `assets/icons/app_icon_foreground.png`:

```powershell
dart run flutter_launcher_icons:main
```

Si necesitas regenerar también el logo/splash a partir de las fuentes SVG del repo:

```powershell
powershell -ExecutionPolicy Bypass -File tools\generate_assets.ps1
```

## AAB para Google Play

```powershell
flutter build appbundle --release --dart-define=WHATCANICOOK_API_BASE_URL=https://tu-dominio-seguro.example
```

Salida: `build\app\outputs\bundle\release\app-release.aab`.

El AAB debe estar firmado con tu clave de **upload** antes de subirlo a Play Console.

## Firma (documentación, no ejecutada aquí)

No se creó ningún keystore en este repositorio por seguridad. Para publicar:

1. Crea la clave fuera del repo:

   ```powershell
   keytool -genkey -v -keystore android\app\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Crea `android/key.properties` (ignorado por Git):

   ```properties
   storePassword=TU_PASSWORD
   keyPassword=TU_PASSWORD
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```

3. Configura `signingConfigs` en `android/app/build.gradle.kts` leyendo esas propiedades.

4. Compila:

   ```powershell
   flutter build appbundle --release
   ```

Nunca subas `*.jks`, `*.keystore` ni `android/key.properties`.

## Versión

Cambia `version:` en `pubspec.yaml` antes de cada publicación, por ejemplo:

```yaml
version: 1.0.1+2
```

## Prueba en dispositivo

No se realizó ninguna prueba en dispositivo físico ni emulador durante esta sesión: el entorno no tenía ninguno conectado. Antes de publicar, instala la APK y verifica:

- permisos de cámara/galería;
- escaneo real con backend configurado;
- corrección de ingredientes detectados;
- generación de recetas, favoritos e historial;
- navegación completa y estados vacíos.
