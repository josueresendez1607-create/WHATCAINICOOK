import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/config.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            const SectionHeader(
              title: 'Inteligencia artificial',
              subtitle: 'Estado de la conexión con el backend seguro.',
            ),
            const SizedBox(height: 12),
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
                              ? Icons.verified_rounded
                              : Icons.info_outline,
                          color: AppConfig.visionConfigured
                              ? AppColors.success
                              : AppColors.gold,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppConfig.visionConfigured
                                ? 'Backend de IA configurado'
                                : 'Backend de IA no configurado',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppConfig.visionConfigured
                          ? 'URL: ${AppConfig.visionBaseUrl}\n'
                                'La clave de Gemini permanece solo en el servidor.'
                          : 'Para activarlo, compila con:\n'
                                '--dart-define=WHATCANICOOK_API_BASE_URL=http://10.0.2.2:5000',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const SectionHeader(
              title: 'Datos locales',
              subtitle: 'Información guardada únicamente en este dispositivo.',
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.cleaning_services_outlined,
                    title: 'Vaciar lista de ingredientes',
                    subtitle: 'Elimina todos los ingredientes guardados.',
                    onTap: () async {
                      final confirmed = await _confirm(
                        context,
                        '¿Vaciar ingredientes?',
                        'Se eliminarán todos los ingredientes de tu lista.',
                      );
                      if (confirmed != true) return;
                      await ref.read(ingredientsProvider.notifier).clear();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lista vaciada.')),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.history_toggle_off,
                    title: 'Borrar historial',
                    subtitle: 'Elimina búsquedas, escaneos y recetas vistas.',
                    onTap: () async {
                      final confirmed = await _confirm(
                        context,
                        '¿Borrar historial?',
                        'Se eliminarán todos los eventos guardados.',
                      );
                      if (confirmed != true) return;
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
            const SizedBox(height: 24),

            const SectionHeader(
              title: 'Fuentes y transparencia',
              subtitle: 'Cómo se construyen las recomendaciones.',
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recetas verificadas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Las recetas proceden de MyPlate, sitio oficial del USDA. '
                      'Cada detalle muestra el enlace original.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Uso de IA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gemini identifica ingredientes en fotos y selecciona IDs '
                      'del catálogo verificado. Nunca inventa recetas, '
                      'ingredientes ni datos nutricionales.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Versión ${AppConfig.appVersion}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.goldBright,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context, String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      onTap: onTap,
    );
  }
}
