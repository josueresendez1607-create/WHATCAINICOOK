import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
import 'package:whatcanicook/core/config.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/preference_toggle.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull ?? UserProfile.empty;
    final hiddenCount =
        ref.watch(hiddenRecipesProvider).valueOrNull?.length ?? 0;
    final favoritesCount =
        ref.watch(favoritesProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            const SectionHeader(
              title: 'Preferencias',
              subtitle: 'Se aplican al buscar y ordenar tus recetas.',
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  PreferenceToggle(
                    icon: Icons.eco_outlined,
                    title: 'Vegetariano',
                    subtitle: 'Prioriza recetas sin carne ni pescado.',
                    value: profile.vegetarian,
                    onChanged: (value) => _save(
                      ref,
                      profile,
                      profile.copyWith(vegetarian: value),
                    ),
                  ),
                  const Divider(height: 1),
                  PreferenceToggle(
                    icon: Icons.grain_outlined,
                    title: 'Sin gluten',
                    subtitle: 'Evita ingredientes con gluten conocido.',
                    value: profile.glutenFree,
                    onChanged: (value) => _save(
                      ref,
                      profile,
                      profile.copyWith(glutenFree: value),
                    ),
                  ),
                  const Divider(height: 1),
                  PreferenceToggle(
                    icon: Icons.fitness_center_outlined,
                    title: 'Alto en proteínas',
                    subtitle: 'Prefiere recetas con más proteína.',
                    value: profile.highProtein,
                    onChanged: (value) => _save(
                      ref,
                      profile,
                      profile.copyWith(highProtein: value),
                    ),
                  ),
                  const Divider(height: 1),
                  PreferenceToggle(
                    icon: Icons.local_fire_department_outlined,
                    title: 'Bajo en calorías',
                    subtitle: 'Prioriza opciones ligeras.',
                    value: profile.lowCalorie,
                    onChanged: (value) => _save(
                      ref,
                      profile,
                      profile.copyWith(lowCalorie: value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'No son recomendaciones médicas.',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),

            const SectionHeader(
              title: 'Datos locales',
              subtitle: 'Todo se guarda únicamente en este dispositivo.',
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
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.favorite_border_rounded,
                    title: 'Borrar favoritos',
                    subtitle: favoritesCount == 0
                        ? 'Aún no tienes platillos guardados.'
                        : 'Elimina $favoritesCount platillos guardados.',
                    onTap: favoritesCount == 0
                        ? null
                        : () async {
                            final confirmed = await _confirm(
                              context,
                              '¿Borrar favoritos?',
                              'Se eliminarán todos los platillos guardados.',
                            );
                            if (confirmed != true) return;
                            final items =
                                ref.read(favoritesProvider).valueOrNull ??
                                const [];
                            for (final item in items) {
                              await ref
                                  .read(favoritesProvider.notifier)
                                  .remove(item.recipeId);
                            }
                          },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.visibility_off_outlined,
                    title: 'Platillos ocultos',
                    subtitle: hiddenCount == 0
                        ? 'No has ocultado ningún platillo.'
                        : 'Tienes $hiddenCount platillo(s) oculto(s).',
                    trailing: hiddenCount == 0
                        ? null
                        : _CountBadge(count: hiddenCount),
                    onTap: () => _showHiddenDialog(context, ref),
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
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const SectionHeader(
              title: 'Información',
              subtitle: 'Sobre WHATCANICOOK y sus fuentes.',
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
                      'Nuestras recetas vienen de MyPlate, el sitio oficial '
                      'del USDA. Cada detalle muestra la fuente original.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Cómo funciona',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'La inteligencia artificial puede reconocer ingredientes '
                      'en tus fotos y elegir entre recetas ya verificadas. '
                      'Siempre puedes revisar, corregir y decidir qué cocinar.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'WHATCANICOOK · versión ${AppConfig.appVersion}',
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

  Future<void> _save(
    WidgetRef ref,
    UserProfile profile,
    UserProfile updated,
  ) async {
    await ref.read(profileProvider.notifier).save(updated);
  }

  Future<void> _showHiddenDialog(BuildContext context, WidgetRef ref) async {
    final items = ref.read(hiddenRecipesProvider).valueOrNull ?? const [];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Platillos ocultos'),
        content: items.isEmpty
            ? const Text(
                'No has ocultado ningún platillo. Puedes hacerlo '
                'desde cualquier tarjeta o detalle de receta.',
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          await ref
                              .read(hiddenRecipesProvider.notifier)
                              .unhide(item.recipeId);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        child: const Text('Restaurar'),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          if (items.isNotEmpty)
            FilledButton(
              onPressed: () async {
                final confirmed = await _confirm(
                  dialogContext,
                  '¿Restaurar todos?',
                  'Todos los platillos ocultos volverán a aparecer.',
                );
                if (confirmed != true) return;
                await ref.read(hiddenRecipesProvider.notifier).clear();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Restaurar todos'),
            ),
        ],
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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.goldBright,
        ),
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
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

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
      trailing:
          trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
      onTap: onTap,
    );
  }
}
