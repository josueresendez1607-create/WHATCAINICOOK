/// Configuración de la app que se inyecta en tiempo de compilación.
///
/// Ejemplo:
/// flutter run --dart-define=WHATCANICOOK_API_BASE_URL=http://10.0.2.2:5000
///
/// La clave de Gemini NUNCA se coloca aquí: vive únicamente en el backend.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'WHATCANICOOK_API_BASE_URL',
    defaultValue: '',
  );

  static const String appName = 'WHATCANICOOK';
  static const String appVersion = '1.0.0';

  static bool get visionConfigured => apiBaseUrl.trim().isNotEmpty;

  static String get visionBaseUrl =>
      apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
}
