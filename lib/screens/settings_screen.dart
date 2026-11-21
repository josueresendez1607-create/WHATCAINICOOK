import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/config.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            'INTELIGENCIA ARTIFICIAL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.orangeDark,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppConfig.visionConfigured
                            ? Icons.check_circle
                            : Icons.info_outline,
                        color: AppConfig.visionConfigured
                            ? AppColors.green
                            : AppColors.orange,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppConfig.visionConfigured
                            ? 'Backend de IA configurado'
                            : 'Backend de IA no configurado',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConfig.visionConfigured
                        ? 'URL: ${AppConfig.visionBaseUrl}\nLa clave de Gemini nunca se incluye en la app.'
                        : 'Para activarlo, compila con:\n'
                              '--dart-define=WHATCANICOOK_API_BASE_URL=http://10.0.2.2:5000',
                    style: const TextStyle(fontSize: 13, color: AppColors.gray),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'DATOS LOCALES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.orangeDark,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.cleaning_services_outlined,
                    color: AppColors.orange,
                  ),
                  title: const Text('Vaciar lista de ingredientes'),
                  onTap: () async {
                    await ref.read(ingredientsProvider.notifier).clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lista vaciada.')),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.history_toggle_off,
                    color: AppColors.orange,
                  ),
                  title: const Text('Borrar historial'),
                  onTap: () async {
                    await ref.read(historyProvider.notifier).clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Historial borrado.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'FUENTES Y TRANSPARENCIA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.orangeDark,
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Las recetas incluidas proceden de MyPlate, sitio oficial del '
                'USDA. Cada detalle muestra el enlace original. La IA se usa '
                'solo para identificar ingredientes en imágenes; nunca inventa '
                'recetas ni datos nutricionales. '
                'Versión ${AppConfig.appVersion}.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.gray,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
